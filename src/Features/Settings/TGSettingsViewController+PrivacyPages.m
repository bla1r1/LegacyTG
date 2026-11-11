//
// TGSettingsViewController+PrivacyPages.m
// Settings pages for notifications, privacy, security, and blocked users.
//
#import "TGSettingsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGAlertSheet.h"
#import "TGPasscode.h"
#import "TGPasscodeViewController.h"
#import "TGCloseFriendsViewController.h"
#import "TGSessionsViewController.h"
#import "TGChatViewController.h"
#import "TGListViewController.h"
#import "TGAdminRightsViewController.h"
#import "TGNotificationCategoryViewController.h"
#import "TGUpdateStore.h"
#import "TGAccountStore.h"
#import "TGMessageStore.h"
#import "TGProfileStore.h"
#import "TGSessionsStore.h"
#import "TGSettingsStore.h"


static NSString *TGFreezeDetail(NSDictionary *state) {
	if (![state isKindOfClass:NSDictionary.class])
		return @"Unknown";
	return [state[@"is_frozen"] boolValue] ? @"Frozen" : @"Not frozen";
}

/// Subscription flags are not exclusive: a canceled subscription can also
/// carry a failed payment. The row names the one that changes what to do.
static NSString *TGSubscriptionDetail(NSDictionary *record) {
	if (![record isKindOfClass:NSDictionary.class])
		return @"None";
	if ([record[@"is_payment_failed"] boolValue])
		return @"Payment failed";
	if ([record[@"is_canceled"] boolValue])
		return @"Canceled";
	if ([record[@"is_restored"] boolValue])
		return @"Restored";
	return @"Active";
}

static NSString *TGAgeVerificationDetail(NSDictionary *parameters) {
	if (![parameters isKindOfClass:NSDictionary.class])
		return @"Not set";
	NSInteger minAge = [parameters[@"min_age"] integerValue];
	if (minAge <= 0)
		return @"No minimum";
	return [NSString stringWithFormat:@"Age %ld+", (long)minAge];
}

@implementation TGSettingsViewController (PrivacyPages)

static NSString *TGNotificationWhen(NSNumber *stamp) {
	if (![stamp isKindOfClass:NSNumber.class] || ![stamp longLongValue])
		return @"";
	return [NSDateFormatter localizedStringFromDate:
			[NSDate dateWithTimeIntervalSince1970:[stamp doubleValue]]
			dateStyle:NSDateFormatterShortStyle
			timeStyle:NSDateFormatterShortStyle];
}

static NSString *TGSoundName(NSDictionary *sound) {
	NSString *title = sound[@"title"];
	if (title.length)
		return title;
	return [NSString stringWithFormat:@"Sound %@", sound[@"id"] ?: @(0)];
}

static NSString *TGNotificationGroupLabel(NSString *type) {
	if ([type isEqualToString:@"notificationGroupTypeMessages"]) return @"Messages";
	if ([type isEqualToString:@"notificationGroupTypeMentions"]) return @"Mention";
	if ([type isEqualToString:@"notificationGroupTypeSecretChat"]) return @"Secret Chats";
	if ([type isEqualToString:@"notificationGroupTypeCalls"]) return @"Calls";
	return type.length ? type : @"Notifications";
}

- (NSArray *)notificationSections {
	__weak typeof(self) weakSelf = self;
	NSArray *scopes = @[@"private", @"groups", @"channels"];
	NSArray *titles = @[@"Private Chats", @"Groups", @"Channels"];

	NSMutableArray *show = [NSMutableArray array];
	for (NSUInteger i = 0; i < scopes.count; i++){
		NSString *scope = scopes[i];
		NSNumber *known = weakSelf.muted[scope];
		BOOL on = ![known boolValue];
		// Official's category row is a disclosure with the scope's On/Off
		// value; the switch and the per-chat exceptions live on the page.
		[show addObject:TGOpenRow(titles[i],
				known ? (on ? @"On" : @"Off") : nil, ^{
			TGNotificationCategoryViewController *category =
					[[TGNotificationCategoryViewController alloc]
							initWithScope:scope title:titles[i]];
			category.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:category animated:YES];
		})];
	}

	// In-App Preview is the one in-app switch TDLib has a field for: it maps
	// to show_preview on the three scopes. The other rows of the official
	// block have no store in this client, so they are not shown as controls
	// that would write keys nothing reads.
	BOOL preview = YES;
	for (NSString *scope in scopes)
		preview = preview && [weakSelf.previews[scope] boolValue];
	NSArray *inAppRows = @[
		TGSwitchRow(@"In-App Preview", preview, ^(BOOL on){
			for (NSString *scope in scopes){
				weakSelf.previews[scope] = @(on);
				[[TGSettingsStore shared] setScope:scope showPreview:on];
			}
			[weakSelf rebuild];
		}),
	];

	// Reactions are their own settings record in TDLib, not a scope. The
	// switch writes one field of it; the default and the recent list are the
	// two things the reaction bar reads before it draws.
	NSString *defaultEmoji = [TGMessageStore shared].defaultReactionEmoji ?: @"\U0001F44D";
	NSArray *reactionRows = @[
		TGSwitchRow(@"Reactions", [TGSettingsStore shared].reactionNotificationsEnabled,
				^(BOOL on){
			[[TGSettingsStore shared] setReactionNotificationsEnabled:on completion:^(BOOL ok){
				if (!ok)
					[TGAlertSheet showMessage:@"An error occurred."
										 title:@"Reactions"
										inView:weakSelf.view];
				[weakSelf loadForPage];
			}];
		}),
		TGTapRow(@"Quick Reaction", defaultEmoji, ^{
			NSArray *choices = [TGReactionPicker defaultReactions];
			[TGAlertSheet showChoices:choices
								title:@"Quick Reaction"
							  message:nil
					   destructiveIndex:-1
							   inView:weakSelf.view
							 onChoice:^(NSInteger index){
				NSString *emoji = choices[(NSUInteger)index];
				[[TGMessageStore shared] setDefaultReactionEmoji:emoji completion:^(BOOL ok){
					if (!ok)
						[TGAlertSheet showMessage:@"An error occurred."
											 title:@"Reactions"
											inView:weakSelf.view];
					[weakSelf loadForPage];
				}];
			}];
		}),
		TGRedRow(@"Clear Recent Emoji", ^{
			[TGAlertSheet showConfirm:nil
								title:@"Clear Recent Emoji"
							   action:@"Clear"
						  destructive:YES
							   inView:weakSelf.view
							onConfirm:^{
				[[TGSettingsStore shared] clearRecentReactionsWithCompletion:^(BOOL ok){
					if (ok)
						[TGAlertSheet showMessage:@"Done"
											 title:@"Reactions"
											inView:weakSelf.view];
				}];
			}];
		}),
	];

	NSUInteger activeGroups = [TGSettingsStore shared].activeNotificationGroups.count;
	(void)activeGroups;

	return @[
		TGSection(@"MESSAGE NOTIFICATIONS", nil, show),
		TGSection(@"IN-APP NOTIFICATIONS", nil, inAppRows),
		TGSection(@"REACTIONS", nil, reactionRows),

		TGSection(nil,
				@"Undo all custom notification settings for your contacts, groups and channels.",
				@[
			TGRedRow(@"Reset All Notifications", ^{
			[TGAlertSheet showConfirm:@"Are you sure you want to reset all notification settings to default?"
								title:@"Reset All Notifications"
							   action:@"Reset"
						  destructive:YES
							   inView:weakSelf.view
							onConfirm:^{
				[[TGSettingsStore shared] resetAllNotificationSettings];
				[weakSelf loadForPage];
			}];
		})]),
	];
}

- (NSArray *)soundSections {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *sound in self.savedSounds){
		NSString *when = TGNotificationWhen(sound[@"date"]);
		NSString *detail = [NSString stringWithFormat:@"%ld s%@%@",
				(long)[sound[@"duration"] integerValue],
				when.length ? @" · " : @"", when];
		[rows addObject:TGTapRow(TGSoundName(sound), detail, ^{
			[weakSelf showSavedSound:sound];
		})];
	}
	if (!rows.count){
		NSString *empty = self.savedSoundsLoaded
				? @"Empty"
				: @"Loading...";
		[rows addObject:TGRow(TGKindPlain, empty)];
	}

	// Official has one cloud section: the installed tones, then the upload
	// row. Adding a bundled sample or reading the sandbox's Documents folder
	// are developer tools, not a user's upload path.
	[rows addObject:TGActionRow(@"Upload Sound", ^{
		[weakSelf addSoundFromDocuments];
	})];

#if TG_DEV
	[rows addObject:TGActionRow(@"Add Bundled Sample", ^{
		[weakSelf addSoundFromBundle];
	})];
	[rows addObject:TGActionRow(@"Add MP3 from Documents", ^{
		[weakSelf addSoundFromDocuments];
	})];
#endif

	return @[
		TGSection(@"Telegram Tones", nil, rows),
	];
}

- (void)addSoundFromBundle {
	NSString *path = [[NSBundle mainBundle] pathForResource:@"notification-sample"
													 ofType:@"mp3"];
	if (!path.length){
		[TGAlertSheet showMessage:@"An error occurred."
							 title:@"Sound" inView:self.view];
		return;
	}
	[self addSavedSoundAtPath:path];
}

/// The only picker this OS gives a sandboxed app is its own Documents folder,
/// which iTunes file sharing exposes. MP3 only, because that is the format
/// addSavedNotificationSound accepts.
- (void)addSoundFromDocuments {
	NSString *documents = [NSSearchPathForDirectoriesInDomains(
			NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	NSArray *entries = [[NSFileManager defaultManager]
			contentsOfDirectoryAtPath:documents error:nil];
	NSMutableArray *names = [NSMutableArray array];
	for (NSString *entry in entries){
		if (![[entry pathExtension].lowercaseString isEqualToString:@"mp3"])
			continue;
		[names addObject:entry];
	}
	if (!names.count){
		[TGAlertSheet showMessage:@"An error occurred."
							 title:@"Sound" inView:self.view];
		return;
	}
	__weak typeof(self) weakSelf = self;
	if (names.count == 1){
		[self addSavedSoundAtPath:[documents stringByAppendingPathComponent:names[0]]];
		return;
	}
	[TGAlertSheet showChoices:names
						title:@"Upload Sound"
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		if (index < 0 || index >= (NSInteger)names.count)
			return;
		[weakSelf addSavedSoundAtPath:
				[documents stringByAppendingPathComponent:names[(NSUInteger)index]]];
	}];
}

- (void)addSavedSoundAtPath:(NSString *)path {
	__weak typeof(self) weakSelf = self;
	[[TGSettingsStore shared] addSavedNotificationSoundAtPath:path
											completion:^(NSDictionary *sound,
														 NSString *error){
		if (error || !sound){
			[TGAlertSheet showMessage:(error ?: @"An error occurred.")
								 title:@"Sound" inView:weakSelf.view];
			return;
		}
		[TGAlertSheet showMessage:@"Sound Added"
							 title:@"Sound" inView:weakSelf.view];
		[weakSelf loadForPage];
	}];
}

- (void)showSavedSound:(NSDictionary *)sound {
	__weak typeof(self) weakSelf = self;
	NSString *name = TGSoundName(sound);
	[TGAlertSheet showChoices:@[@"Sound", @"Remove"]
						title:name
			 destructiveIndex:1
					   inView:self.view
					 onChoice:^(NSInteger index){
		if (index == 1){
			[weakSelf removeSavedSound:sound];
			return;
		}
		[[TGSettingsStore shared] savedNotificationSound:[sound[@"id"] longLongValue]
									   completion:^(NSDictionary *fresh){
			if (!fresh){
				[TGAlertSheet showMessage:@"An error occurred."
									 title:@"Sound" inView:weakSelf.view];
				[weakSelf loadForPage];
				return;
			}
			NSString *when = TGNotificationWhen(fresh[@"date"]);
			NSMutableString *detail = [NSMutableString stringWithFormat:
					@"%@\n%ld s\n%@\n%@",
					TGSoundName(fresh),
					(long)[fresh[@"duration"] integerValue],
					when.length ? when : @"—",
					TGBytes([fresh[@"size"] longLongValue])];
			if ([fresh[@"data"] length])
				[detail appendFormat:@"\n%@", fresh[@"data"]];
			[TGAlertSheet showMessage:detail title:@"Sound"
									inView:weakSelf.view];
		}];
	}];
}

- (void)removeSavedSound:(NSDictionary *)sound {
	__weak typeof(self) weakSelf = self;
	NSString *name = TGSoundName(sound);
	[TGAlertSheet showConfirm:nil
						title:name
					   action:@"Remove"
				 destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGSettingsStore shared] removeSavedNotificationSound:[sound[@"id"] longLongValue]
										   completion:^(BOOL ok, NSString *error){
			if (!ok){
				[TGAlertSheet showMessage:(error ?: @"An error occurred.")
									 title:@"Sound" inView:weakSelf.view];
				return;
			}
			[TGAlertSheet showMessage:@"Done"
								 title:@"Sound" inView:weakSelf.view];
			[weakSelf loadForPage];
		}];
	}];
}

- (NSArray *)activeNotificationSections {
	NSArray *groups = [TGSettingsStore shared].activeNotificationGroups;
	if (!groups.count){
		return @[TGSection(nil, nil,
				@[TGRow(TGKindPlain, @"None")])];
	}

	__weak typeof(self) weakSelf = self;
	NSMutableArray *sections = [NSMutableArray array];
	for (NSDictionary *group in groups){
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *notification in group[@"notifications"]){
			NSString *when = TGNotificationWhen(notification[@"date"]);
			NSString *silent = [notification[@"isSilent"] boolValue]
					? @" · Silent" : @"";
			NSString *detail = [NSString stringWithFormat:@"%@%@",
					when.length ? when : @"—", silent];
			[rows addObject:TGTapRow(notification[@"text"] ?: @"Notifications",
					detail, ^{
				[weakSelf removeNotificationRow:notification inGroup:group];
			})];
		}
		if (!rows.count)
			[rows addObject:TGRow(TGKindPlain, @"Empty")];
		[rows addObject:TGRedRow(@"Remove", ^{
			[weakSelf removeNotificationGroup:group];
		})];

		NSString *chat = group[@"chatTitle"];
		NSString *header = chat.length ? chat
				: [NSString stringWithFormat:@"Group %@", group[@"id"] ?: @(0)];
		NSString *footer = [NSString stringWithFormat:@"%ld · %@",
				(long)[group[@"totalCount"] integerValue],
				TGNotificationGroupLabel(group[@"type"])];
		[sections addObject:TGSection(header, footer, rows)];
	}
	return sections;
}

- (void)removeNotificationRow:(NSDictionary *)notification
					  inGroup:(NSDictionary *)group {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:notification[@"text"] ?: @"Notifications"
					   action:@"Remove"
				 destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGSettingsStore shared] removeNotification:[notification[@"id"] intValue]
									  inGroup:[group[@"id"] intValue]
								   completion:^(BOOL ok, NSString *error){
			if (!ok){
				[TGAlertSheet showMessage:(error ?: @"An error occurred.")
									 title:@"Notifications"
									inView:weakSelf.view];
				return;
			}
			[weakSelf rebuild];
		}];
	}];
}

- (void)removeNotificationGroup:(NSDictionary *)group {
	int32_t maxId = 0;
	for (NSDictionary *notification in group[@"notifications"])
		maxId = MAX(maxId, [notification[@"id"] intValue]);
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:group[@"chatTitle"] ?: @"Notifications"
					   action:@"Remove"
				 destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGSettingsStore shared] removeNotificationGroup:[group[@"id"] intValue]
								maxNotificationId:maxId
									   completion:^(BOOL ok, NSString *error){
			if (!ok){
				[TGAlertSheet showMessage:(error ?: @"An error occurred.")
									 title:@"Notifications"
									inView:weakSelf.view];
				return;
			}
			[weakSelf rebuild];
		}];
	}];
}

- (NSArray *)privacySections {
	__weak typeof(self) weakSelf = self;

	NSMutableArray *rules = [NSMutableArray array];
	NSArray *settings = [TGSettingsViewController privacySettings];
	for (NSUInteger i = 0; i < settings.count; i++){
		NSString *setting = settings[i];
		NSUInteger index = i;
		[rules addObject:TGTapRow([TGSettingsViewController privacyTitles][index],
				TGPrivacyLabel(weakSelf.privacy[setting]), ^{
			[weakSelf askPrivacyRuleAtIndex:index];
		})];
	}

	NSString *passwordDetail = !weakSelf.passwordKnown ? @"Loading..."
			: (weakSelf.hasPassword ? @"On" : @"Off");

	NSInteger ttl = weakSelf.accountTtl;
	NSString *deleteLabel = TGSettingsAccountTtlLabel(ttl, weakSelf.accountTtlLoaded);

	NSString *autoDeleteLabel;
	NSInteger autoTtl = weakSelf.autoDeleteDefault;
	if (autoTtl < 0)            autoDeleteLabel = @"Loading...";
	else if (autoTtl == 0)      autoDeleteLabel = @"Off";
	else if (autoTtl == 86400)  autoDeleteLabel = @"1 day";
	else if (autoTtl == 604800) autoDeleteLabel = @"1 week";
	else if (autoTtl == 2592000) autoDeleteLabel =
			TGLocalizedPluralValue(@"%@ month", @"%@ months", @"1", 1);
	else                        autoDeleteLabel = TGLocalizedPluralValue(
			@"%@ day", @"%@ days",
			[NSString stringWithFormat:@"%ld", (long)(autoTtl / 86400)],
			autoTtl / 86400);

	// Official keeps one list: the general security rows, Auto-Delete, the
	// login email, then the privacy rules. The extra chat tools and cards
	// belonged to other screens and are not repeated here.
	return @[
		TGSection(nil,
			@"Automatically delete messages for everyone after a period of time in all new chats you start.",
			@[
			TGIconTapOpenRow(@"Blocked Users", nil,
					@"close", TGIconTileCoral(), ^{
				[weakSelf openPage:TGSettingsPageBlocked];
			}),
			TGIconTapOpenRow(@"Passcode Lock", [TGPasscode hasPasscode] ? @"On" : @"Off",
					@"privacy", TGIconTileSky(), ^{
				[weakSelf openPage:TGSettingsPagePasscode];
			}),
			TGIconTapRow(@"Two-Step Verification", passwordDetail,
					@"privacy", TGIconTileGrey(), ^{
				[weakSelf showTwoStepState];
			}),
			TGIconTapRow(@"Auto-Delete Messages", autoDeleteLabel,
					@"archive", TGIconTileGrey(), ^{
				[TGAlertSheet showChoices:@[@"Off", @"1 day", @"1 week",
						TGLocalizedPluralValue(@"%@ month", @"%@ months", @"1", 1)]
									title:@"Auto-Delete Messages"
						 destructiveIndex:-1
								   inView:weakSelf.view
								 onChoice:^(NSInteger index){
					static const NSInteger seconds[4] = {0, 86400, 604800, 2592000};
					[[TGSettingsStore shared] setDefaultMessageAutoDeleteTime:seconds[index]];
					weakSelf.autoDeleteDefault = seconds[index];
					[weakSelf rebuild];
				}];
			}),
		]),

		TGSection(nil,
			@"You will receive Telegram login codes via email and not SMS. Please enter an email address to which you have access.",
			@[
			TGIconTapRow(@"Login Email", nil,
					@"chat", TGIconTileSky(), ^{
				[weakSelf showLoginEmailFlow];
			}),
		]),

		TGSection(@"PRIVACY",
			@"You can restrict which users are allowed to add you to groups and channels.",
			rules),

		TGSection(nil,
			@"Automatically archive and mute new chats, groups and channels from non-contacts.",
			@[
			// Official's auto-archive row is a switch, and its section has
			// no icon tile.
			TGSwitchRow(@"Automatically Archive",
					[[TGSettingsStore shared].archiveSettings[@"archive_and_mute_new_chats_from_unknown_users"] boolValue],
					^(BOOL on){
				NSDictionary *settings = [TGSettingsStore shared].archiveSettings ?: @{};
				[[TGSettingsStore shared] setArchiveSettingsArchiveAndMute:on
												keepUnmutedArchived:
						[settings[@"keep_unmuted_chats_archived"] boolValue]
											  keepFolderChatsArchived:
						[settings[@"keep_chats_from_folders_archived"] boolValue]];
				[weakSelf rebuild];
			}),
		]),

		TGSection(@"AUTOMATICALLY DELETE MY ACCOUNT",
			@"If you do not come online at least once within this period, your account will be deleted along with all messages and contacts.",
			@[
			TGOpenRow(@"If Away For", deleteLabel, ^{
				NSArray *choices = @[
						TGLocalizedPluralValue(@"%@ month", @"%@ months", @"1", 1),
						TGLocalizedPluralValue(@"%@ month", @"%@ months", @"3", 3),
						TGLocalizedPluralValue(@"%@ month", @"%@ months", @"6", 6),
						TGLocalizedPluralValue(@"%@ month", @"%@ months", @"12", 12),
						TGLocalizedPluralValue(@"%@ month", @"%@ months", @"18", 18),
						TGLocalizedPluralValue(@"%@ month", @"%@ months", @"24", 24),
						@"Delete My Account"];
				[TGAlertSheet showChoices:choices
									title:@"If Away For"
						 destructiveIndex:6
								   inView:weakSelf.view
								 onChoice:^(NSInteger index){
					if (index == 6){
						[weakSelf askDeleteAccountNow];
						return;
					}
					static const NSInteger months[6] = {1, 3, 6, 12, 18, 24};
					NSInteger days = TGSettingsAccountTtlDaysForMonths(months[index]);
					[[TGSettingsStore shared] setAccountTtlDays:days];
					weakSelf.accountTtl = days;
					[weakSelf rebuild];
				}];
			}),
		]),

		TGSection(nil,
			@"Tools to set the default folder, auto-archive and hide new chats from non-contacts.",
			@[
			TGOpenRow(@"Data Settings", nil, ^{
				[weakSelf openPage:TGSettingsPageData];
			}),
		]),

		// The update check sends this to our bot; nothing else is shared.
		// "Share Statistics" is the pack's short label; the sentence that
		// explains what is sent stays in the footer, where it has the width.
		TGSection(nil,
			TGLocalized(@"Send anonymous usage statistics. The update check sends the app "
			@"version, iOS version, device model, device tier, jailbreak yes/no "
			@"and language. The bot stores a salted hash of your account id, "
			@"never the id itself. Turning this off sends stats=0 and update "
			@"checks still work."),
			@[
			TGSwitchRow(@"Share Statistics",
					[TGUpdateStore usageStatisticsEnabled], ^(BOOL on){
				[TGUpdateStore setUsageStatisticsEnabled:on];
				[weakSelf rebuild];
			}),
		]),
	];
}

- (NSArray *)blockedSections {
	__weak typeof(self) weakSelf = self;
	// The official list has Edit only when there is something to edit.
	self.navigationItem.rightBarButtonItem = self.blocked.count
			? self.editButtonItem : nil;
	if (!self.blocked.count)
		return @[TGSection(nil, nil, @[TGRow(TGKindPlain,
				@"Blocked users can't send you messages or add you to groups. They will not see your profile photos, stories, online and last seen status.")])];

	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *user in self.blocked){
		int64_t userId = [user[@"id"] longLongValue];
		// The shared person row: the photo through the peer store, the name
		// as the account has it (not a pack key).
		NSMutableDictionary *row = TGPeerRow(@(userId), user[@"name"] ?: @"", nil, ^{
			TGProfileViewController *profile = [[TGProfileViewController alloc]
					initWithChatId:userId userId:userId
							 title:user[@"name"] ?: @"Profile"];
			profile.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:profile animated:YES];
		});
		if (userId > 0)
			row[TGRowAvatarUser] = @YES;
		[rows addObject:row];
	}
	return @[TGSection(nil, nil, rows)];
}

/// Only real peer rows can be swiped. The empty-state sentence is a text
/// row, not a blocked user, and must not grow a delete control.
- (BOOL)canEditBlockedRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.row < (NSInteger)self.blocked.count;
}

- (void)commitBlockedEditingStyle:(UITableViewCellEditingStyle)editingStyle
				forRowAtIndexPath:(NSIndexPath *)indexPath
					  inTableView:(UITableView *)tableView {
	if (editingStyle != UITableViewCellEditingStyleDelete ||
		indexPath.row >= (NSInteger)self.blocked.count)
		return;
	NSDictionary *user = self.blocked[(NSUInteger)indexPath.row];
	[[TGAccountStore shared] setUser:[user[@"id"] longLongValue] blocked:NO];
	NSMutableArray *rest = [self.blocked mutableCopy];
	[rest removeObject:user];
	self.blocked = rest;
	[tableView deleteRowsAtIndexPaths:@[indexPath]
					 withRowAnimation:UITableViewRowAnimationFade];
	if (!self.blocked.count)
		[self rebuild];
}


/// The freeze record is four fields and a date each. The row says whether it
/// is on; the sheet says until when and where the appeal goes, and offers the
/// link the update named rather than only printing it.
- (void)showFreezeState {
	NSDictionary *state = [TGAccountStore shared].freezeState;
	if (![state isKindOfClass:NSDictionary.class]){
		[TGAlertSheet showMessage:@"Empty"
							title:@"Your Account is Frozen" inView:self.view];
		return;
	}
	NSString *appeal = state[@"appeal_link"];
	NSString *details = TGFreezeDetail(state);
	__weak typeof(self) weakSelf = self;
	if (!appeal.length){
		[TGAlertSheet showMessage:details title:@"Your Account is Frozen" inView:self.view];
		return;
	}
	[TGAlertSheet showChoices:@[@"Open Link"]
						title:@"Your Account is Frozen"
					  message:details
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		[weakSelf openURL:appeal];
	}];
}

- (void)showSubscriptionState {
	NSDictionary *record = [[TGAccountStore shared] subscriptionForUserId:
			[[TGProfileStore shared].me[@"id"] longLongValue]];
	if (![record isKindOfClass:NSDictionary.class]){
		[TGAlertSheet showMessage:@"Empty"
							title:@"Subscription" inView:self.view];
		return;
	}
	[TGAlertSheet showMessage:TGSubscriptionDetail(record)
						title:@"Subscription" inView:self.view];
}

/// The age gate names the country and the bot that answers it. Opening the
/// bot is the action the protocol names; there is no td_api call that solves
/// it on the app's behalf.
- (void)showAgeVerificationState {
	NSDictionary *parameters = [TGAccountStore shared].ageVerificationParameters;
	if (![parameters isKindOfClass:NSDictionary.class]){
		[TGAlertSheet showMessage:@"Empty"
							title:@"Age Verification" inView:self.view];
		return;
	}
	NSString *bot = parameters[@"verification_bot_username"];
	NSString *details = TGAgeVerificationDetail(parameters);
	__weak typeof(self) weakSelf = self;
	if (!bot.length){
		[TGAlertSheet showMessage:details title:@"Age Verification" inView:self.view];
		return;
	}
	[TGAlertSheet showChoices:@[[NSString stringWithFormat:@"@%@", bot]]
						title:@"Age Verification"
					  message:details
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		[weakSelf openURL:[NSString stringWithFormat:@"https://t.me/%@", bot]];
	}];
}

/// A reCAPTCHA cannot be drawn by this client: there is no web view in the
/// app and no td_api call that answers one. The sheet shows the exact request
/// (action, site key, verification id) and can copy the key for an official
/// client, instead of pretending the request was handled.
- (void)showRecaptchaVerification {
	NSDictionary *request = [TGAccountStore shared].recaptchaVerificationRequest;
	if (![request isKindOfClass:NSDictionary.class]){
		[TGAlertSheet showMessage:@"Empty"
							title:@"Verify" inView:self.view];
		return;
	}
	NSString *action = request[@"action"];
	NSString *key = request[@"recaptcha_key_id"];
	NSString *details = [NSString stringWithFormat:
			@"Verification id: %lld\nAction: %@\nreCAPTCHA key: %@\n\n"
			@"This client has no web view to solve it. Finish the check in an "
			@"official client; the key above is what the server named.",
			(long long)[request[@"verification_id"] longLongValue],
			action.length ? action : @"—",
			key.length ? key : @"—"];
	__weak typeof(self) weakSelf = self;
	if (!key.length){
		[TGAlertSheet showMessage:details title:@"Verify" inView:self.view];
		return;
	}
	[TGAlertSheet showChoices:@[@"Copy"]
						title:@"Verify"
					  message:details
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		[UIPasteboard generalPasteboard].string = key;
		[weakSelf toast:@"Text copied."];
	}];
}

- (void)choosePersonalChat {
	__weak typeof(self) weakSelf = self;
	[[TGSettingsStore shared] suitablePersonalChatsWithCompletion:^(NSArray *chats){
		TGSettingsViewController *me = weakSelf;
		if (!me)
			return;
		if (!chats.count){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Chat" inView:me.view];
			return;
		}
		NSMutableArray *titles = [NSMutableArray arrayWithObject:@"None"];
		for (NSDictionary *chat in chats)
			[titles addObject:chat[@"title"] ?: @"Channel"];
		[TGAlertSheet showChoices:titles title:@"Chat"
				destructiveIndex:-1 inView:me.view onChoice:^(NSInteger index){
			int64_t chatId = index == 0 ? 0 : [chats[index - 1][@"id"] longLongValue];
			[[TGSettingsStore shared] setPersonalChat:chatId completion:^(BOOL ok){
				if (!ok){
					[TGAlertSheet showMessage:@"An error occurred."
										title:@"Chat" inView:me.view];
					return;
				}
				me.personalChatId = chatId;
				[NSUserDefaults.standardUserDefaults setObject:@(chatId)
													   forKey:TGAccountStoreDefaultsKey(@"TGPersonalChatId")];
				[me rebuild];
			}];
		}];
	}];
}

- (void)showInactiveGroups {
	__weak typeof(self) weakSelf = self;
	[[TGSettingsStore shared] inactiveSupergroupChatsWithCompletion:^(NSArray *chats){
		TGSettingsViewController *me = weakSelf;
		if (!me)
			return;
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *chat in chats){
			[rows addObject:@{@"title" : chat[@"title"] ?: @"Group",
							  @"detail" : @"Open",
							  @"opens" : @YES,
							  @"tap" : ^{
				TGChatViewController *vc = [[TGChatViewController alloc] init];
				vc.chatId = [chat[@"id"] longLongValue];
				vc.chatTitle = chat[@"title"];
				vc.isGroup = YES;
				vc.hidesBottomBarWhenPushed = YES;
				[me.navigationController pushViewController:vc animated:YES];
			}}];
		}
		TGListViewController *list = [[TGListViewController alloc] init];
		list.listTitle = @"Groups";
		list.rows = rows;
		list.emptyText = @"Empty";
		list.listFooter = nil;
		list.hidesBottomBarWhenPushed = YES;
		[me.navigationController pushViewController:list animated:YES];
	}];
}

- (void)showPublicChats {
	__weak typeof(self) weakSelf = self;
	[[TGSettingsStore shared] createdPublicChatsOfType:@"username" completion:^(NSArray *chats){
		TGSettingsViewController *me = weakSelf;
		if (!me)
			return;
		[[TGSettingsStore shared] checkCreatedPublicChatsLimitForType:@"username"
				completion:^(BOOL ok, NSString *reason){
			NSMutableArray *rows = [NSMutableArray arrayWithObject:@{
				@"title" : @"Username",
				@"tap" : ^{ [me checkUsernameForChat:@{@"id" : @(0)}]; },
			}];
			for (NSDictionary *chat in chats){
				[rows addObject:@{@"title" : chat[@"title"] ?: @"Channel",
								  @"tap" : ^{ [me checkUsernameForChat:chat]; }}];
			}
			TGListViewController *list = [[TGListViewController alloc] init];
			list.listTitle = @"Public Chats";
			list.rows = rows;
			list.emptyText = @"Empty";
			list.listFooter = ok ? nil : reason;
			list.hidesBottomBarWhenPushed = YES;
			[me.navigationController pushViewController:list animated:YES];
		}];
	}];
}

- (void)checkUsernameForChat:(NSDictionary *)chat {
	__weak typeof(self) weakSelf = self;
	int64_t chatId = [chat[@"id"] longLongValue];
	[TGAlertSheet showInput:@"Username"
					message:nil
				placeholder:@"username" text:nil action:@"Check"
					 inView:self.view onSubmit:^(NSString *username){
		[[TGSettingsStore shared] checkUsername:username forChat:chatId
							  completion:^(NSString *result){
			NSString *say = nil;
			if ([result isEqualToString:@"ok"])
				say = @"Done";
			else if ([result isEqualToString:@"occupied"])
				say = @"Sorry, this username is already taken.";
			else if ([result isEqualToString:@"invalid"])
				say = @"Sorry, this username is invalid.";
			else
				say = @"An error occurred.";
			[TGAlertSheet showMessage:say title:@"Username"
							   inView:weakSelf.view];
		}];
	}];
}

- (void)hideCloseBirthdays {
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] hideContactCloseBirthdaysWithCompletion:^(BOOL ok, NSString *error){
		if (!ok){
			[TGAlertSheet showMessage:(error ?: @"An error occurred.")
								title:@"Birthday" inView:weakSelf.view];
			return;
		}
		weakSelf.closeBirthdayRows = @[];
		[weakSelf rebuild];
		[TGAlertSheet showMessage:@"Done"
							title:@"Birthday" inView:weakSelf.view];
	}];
}

/// The close-friends list is a contact picker, because Telegram accepts only
/// contacts in setCloseFriends. The controller behind it writes the whole
/// list back and reports the count that stuck.
- (void)showCloseFriends {
	__weak typeof(self) weakSelf = self;
	TGCloseFriendsViewController *friends = [[TGCloseFriendsViewController alloc] init];
	friends.onCountChanged = ^(NSInteger count){
		weakSelf.closeFriendsCount = count;
		[weakSelf rebuild];
	};
	friends.hidesBottomBarWhenPushed = YES;
	[weakSelf.navigationController pushViewController:friends animated:YES];
}

- (NSArray *)passcodeSections {
	__weak typeof(self) weakSelf = self;
	NSString *help = @"When a passcode is set, a lock icon appears above your chat list. "
			@"Tap it to lock your Telegram app.\n\nNote: if you forget your passcode, "
			@"you'll need to reinstall the app. All your Secret Chats will be lost.";
	if (![TGPasscode hasPasscode]) {
		return @[
			TGSection(nil, help, @[
				TGOpenRow(@"Turn Passcode On", nil, ^{
					TGPasscodeViewController *vc = [[TGPasscodeViewController alloc] init];
					vc.mode = TGPasscodeModeSetup;
					vc.onSuccess = ^{
						[weakSelf.navigationController popViewControllerAnimated:YES];
						[weakSelf rebuild];
					};
					vc.onCancel = ^{
						[weakSelf.navigationController popViewControllerAnimated:YES];
					};
					[weakSelf.navigationController pushViewController:vc animated:YES];
				})
			])
		];
	}

	NSInteger timeout = [TGPasscode autoLockTimeout];
	NSString *timeoutTitle;
	if (timeout < 0)
		timeoutTitle = @"Disabled";
	else if (timeout == 60)
		timeoutTitle = @"If away for 1 min";
	else if (timeout == 300)
		timeoutTitle = @"If away for 5 min";
	else if (timeout == 3600)
		timeoutTitle = @"If away for 1 hour";
	else if (timeout == 18000)
		timeoutTitle = @"If away for 5 hours";
	else
		timeoutTitle = @"Disabled";

	return @[
		TGSection(nil, help, @[
			TGOpenRow(@"Turn Passcode Off", nil, ^{
				TGPasscodeViewController *vc = [[TGPasscodeViewController alloc] init];
				vc.mode = TGPasscodeModeTurnOff;
				vc.onSuccess = ^{
					[weakSelf.navigationController popViewControllerAnimated:YES];
					[weakSelf rebuild];
				};
				vc.onCancel = ^{
					[weakSelf.navigationController popViewControllerAnimated:YES];
				};
				[weakSelf.navigationController pushViewController:vc animated:YES];
			}),
			TGOpenRow(@"Change Passcode", nil, ^{
				TGPasscodeViewController *vc = [[TGPasscodeViewController alloc] init];
				vc.mode = TGPasscodeModeChange;
				vc.onSuccess = ^{
					[weakSelf.navigationController popViewControllerAnimated:YES];
					[weakSelf rebuild];
				};
				vc.onCancel = ^{
					[weakSelf.navigationController popViewControllerAnimated:YES];
				};
				[weakSelf.navigationController pushViewController:vc animated:YES];
			})
		]),
		TGSection(@"LOCK TELEGRAM", nil, @[
			TGTapRow(@"Auto-Lock", timeoutTitle, ^{
				NSArray *choices = @[
					@"Disabled",
					@"If away for 1 min",
					@"If away for 5 min",
					@"If away for 1 hour",
					@"If away for 5 hours"
				];
				static const NSInteger timeouts[5] = {-1, 60, 300, 3600, 18000};
				[TGAlertSheet showChoices:choices
									title:@"Auto-Lock"
						 destructiveIndex:-1
								   inView:weakSelf.view
								 onChoice:^(NSInteger index){
					if (index >= 0 && index < 5) {
						[TGPasscode setAutoLockTimeout:timeouts[index]];
						[weakSelf rebuild];
					}
				}];
			})
		])
	];
}

@end
