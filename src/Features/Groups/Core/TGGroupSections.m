#import "TGGroupSettingsViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGGroupSettingsViewControllerInternal.h"
#import "TGGroupLogic.h"
#import "TGRows.h"
#import "TGRowCell.h"

//
// TGGroupSettingsViewController (TGGroupSections) - the screen's data.
//
// One screen for everything a group is: identity, people, calls, behaviour,
// usernames, tools and the way out. Every row is a shared TGRows row; the
// controller and TGRowCell own how it is drawn.
//

@implementation TGGroupSettingsViewController (TGGroupSections)

#pragma mark - row builders

- (NSMutableDictionary *)valueRow:(NSString *)title detail:(NSString *)detail
						   action:(NSString *)action opens:(BOOL)opens
					  destructive:(BOOL)destructive disabled:(BOOL)disabled {
	NSMutableDictionary *row = [TGGroupInfoRowModel(title, detail, opens,
			destructive, disabled) mutableCopy];
	TGTheme *theme = [TGTheme shared];
	BOOL tappable = action.length > 0 && !disabled;
	row[TGRowDetailColour] = tappable ? [theme cellDetailColour]
			: [theme secondaryTextColour];
	if (disabled)
		row[TGRowTitleColour] = [theme secondaryTextColour];
	if (tappable){
		__weak typeof(self) weakSelf = self;
		row[TGRowTap] = ^{ [weakSelf runAction:action]; };
	}
	return row;
}

- (NSMutableDictionary *)switchRow:(NSString *)title detail:(NSString *)detail
							   key:(NSString *)key on:(BOOL)on
						   enabled:(BOOL)enabled {
	__weak typeof(self) weakSelf = self;
	NSMutableDictionary *row = [TGSwitchRow(title, on, ^(BOOL value){
		[weakSelf switchKey:key on:value];
	}) mutableCopy];
	row[TGRowSubtitle] = @YES;
	if (detail)
		row[TGRowDetail] = detail;
	row[TGRowEnabled] = @(enabled && !self.busy);
	return row;
}

- (NSMutableDictionary *)usernameRow:(NSString *)username active:(BOOL)active {
	NSString *key = [@"@" stringByAppendingString:username];
	__weak typeof(self) weakSelf = self;
	NSMutableDictionary *row = [TGSwitchRow(key, active, ^(BOOL value){
		[weakSelf switchKey:key on:value];
	}) mutableCopy];
	row[TGRowRawTitle] = @YES;
	row[TGRowDetail] = active ? TGLocalized(@"Active") : TGLocalized(@"Disabled");
	row[TGRowSubtitle] = @YES;
	row[TGRowEnabled] = @(self.canChangeInfo && !self.busy);
	if (active && self.active.count > 1 && self.canChangeInfo){
		row[TGRowCanMove] = @YES;
		NSUInteger index = (NSUInteger)[self.active indexOfObject:username];
		row[TGRowMove] = ^(NSInteger from, NSInteger to){
			(void)index;
			[weakSelf reorderUsernameFrom:from to:to];
		};
	}
	return row;
}

#pragma mark - switches

/// A switch names its setting: "@name" is a username, everything else is a
/// behaviour key. The real work stays in TGGroupSwitches.
- (void)switchKey:(NSString *)key on:(BOOL)on {
	if ([key hasPrefix:@"@"])
		[self setUsername:key active:on];
	else
		[self setBehaviour:key on:on];
}

#pragma mark - reordering usernames

- (void)reorderUsernameFrom:(NSInteger)from to:(NSInteger)to {
	if (from < 0 || to < 0 || from >= (NSInteger)self.active.count ||
			to >= (NSInteger)self.active.count)
		return;
	NSArray *before = [self.active copy];
	NSString *name = self.active[(NSUInteger)from];
	[self.active removeObjectAtIndex:(NSUInteger)from];
	[self.active insertObject:name atIndex:(NSUInteger)to];
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] reorderSupergroupActiveUsernames:self.active inChat:self.chatId
			completion:^(BOOL ok, NSString *error){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.busy = NO;
		if (!ok){
			me.active = [before mutableCopy];
			[me showRefusal:error title:TGLocalized(@"Username Order")];
		}
		[me rebuild];
	}];
}


#pragma mark - details

- (NSString *)permissionsDetail {
	NSDictionary *p = self.chat[@"permissions"];
	if (![p isKindOfClass:NSDictionary.class])
		return TGLocalized(@"Change");
	BOOL send = [p[@"can_send_basic_messages"] boolValue] ||
				[p[@"can_send_messages"] boolValue];
	BOOL media = [p[@"can_send_photos"] boolValue] ||
				 [p[@"can_send_videos"] boolValue] ||
				 [p[@"can_send_documents"] boolValue];
	if (!send)
		return TGLocalized(@"Read-Only Mode");
	return media ? TGLocalized(@"All") : TGLocalized(@"Messages");
}

- (NSString *)slowModeDetail {
	NSInteger seconds = [self.groupInfo[@"slow_mode_delay"] integerValue];
	if (seconds <= 0)
		return TGLocalized(@"Off");
	if (seconds < 60)
		return TGLocalizedFormat(@"%@ seconds",
				[NSString stringWithFormat:@"%ld", (long)seconds]);
	if (seconds < 3600)
		return TGLocalizedFormat(@"%@ min", @(seconds / 60));
	return TGLocalizedFormat(@"%@ h", @(seconds / 3600));
}

- (void)updateEditButton {
	BOOL canOrder = self.canManage && self.canChangeInfo &&
			self.active.count > 1 && self.settings != nil;
	if (!canOrder){
		self.navigationItem.rightBarButtonItem = nil;
		return;
	}
	self.navigationItem.rightBarButtonItem =
			[[UIBarButtonItem alloc] initWithTitle:(self.editingNames
					? TGLocalized(@"Done") : TGLocalized(@"Edit"))
					style:UIBarButtonItemStylePlain
					target:self action:@selector(toggleEditing)];
}

- (void)toggleEditing {
	self.editingNames = !self.editingNames;
	[self.tableView setEditing:self.editingNames animated:YES];
	[self updateEditButton];
}

#pragma mark - the section model

- (void)rebuild {
	if (!self.loaded || !self.chat)
		return;
	self.tableView.backgroundView = nil;
	BOOL supergroup = [self isSupergroupChat];
	BOOL channel = [self isChannelChat];
	BOOL basic = [self isBasicGroupChat];
	BOOL manager = self.canManage;
	NSMutableArray *sections = [NSMutableArray array];

	// ── identity ────────────────────────────────────────────────────────
	NSMutableArray *info = [NSMutableArray array];
	BOOL editInfo = manager && self.canChangeInfo;
	NSString *photoDetail = self.hasPhoto ? TGLocalized(@"Change")
			: TGLocalized(@"Set");
	NSString *nameDetail = self.chatTitle ?: @"";
	NSString *photoTitle = channel ? TGLocalized(@"Set Channel Photo")
			: TGLocalized(@"Set Group Photo");
	NSString *nameTitle = channel ? TGLocalized(@"Channel Name")
			: TGLocalized(@"Group Name");
	if (manager && !self.canChangeInfo){
		[info addObject:[self valueRow:photoTitle detail:nil action:@"photo"
				opens:NO destructive:NO disabled:YES]];
		[info addObject:[self valueRow:nameTitle detail:nameDetail
				action:@"name" opens:NO destructive:NO disabled:YES]];
	} else {
		[info addObject:[self valueRow:photoTitle
				detail:manager ? photoDetail : (self.hasPhoto
						? TGLocalized(@"Set") : TGLocalized(@"None"))
				action:(manager ? @"photo" : nil) opens:manager
				destructive:NO disabled:NO]];
		[info addObject:[self valueRow:nameTitle detail:nameDetail
				action:(manager ? @"name" : nil) opens:manager
				destructive:NO disabled:NO]];
	}
	if (supergroup){
		if (manager && !self.canChangeInfo){
			[info addObject:[self valueRow:TGLocalized(@"Description")
					detail:self.descriptionText.length ? self.descriptionText
							: TGLocalized(@"None")
					action:@"description" opens:NO destructive:NO disabled:YES]];
		} else {
			[info addObject:[self valueRow:TGLocalized(@"Description")
					detail:self.descriptionText.length ? self.descriptionText
							: (manager ? TGLocalized(@"Description")
									: TGLocalized(@"None"))
					action:(manager ? @"description" : nil) opens:manager
					destructive:NO disabled:NO]];
		}
		if (manager && !self.canInvite){
			[info addObject:[self valueRow:TGLocalized(@"Invite Link")
					detail:self.inviteLink.length ? self.inviteLink
							: TGLocalized(@"Manage")
					action:@"invite" opens:NO destructive:NO disabled:YES]];
		} else if (manager || self.inviteLink.length){
			[info addObject:[self valueRow:TGLocalized(@"Invite Link")
					detail:self.inviteLink.length ? self.inviteLink
							: (manager ? TGLocalized(@"Manage")
									: TGLocalized(@"None"))
					action:(manager ? @"invite" : nil) opens:manager
					destructive:NO disabled:NO]];
		}
		BOOL isPublic = self.editable.length > 0 || self.active.count > 0;
		NSString *typeTitle = channel ? TGLocalized(@"Channel Type")
				: TGLocalized(@"Group Type");
		NSString *typeKey = [NSString stringWithFormat:@"%@.Setup.Type%@",
				channel ? @"Channel" : @"Group",
				isPublic ? @"Public" : @"Private"];
		NSString *typeDetail = TGLocalizedKey(typeKey,
				isPublic ? @"Public" : @"Private");
		if (editInfo)
			[info addObject:[self valueRow:typeTitle detail:typeDetail
					action:@"groupType" opens:YES destructive:NO disabled:NO]];
		else if (manager)
			[info addObject:[self valueRow:typeTitle detail:typeDetail
					action:@"groupType" opens:NO destructive:NO disabled:YES]];
		else
			[info addObject:[self valueRow:typeTitle detail:typeDetail
					action:nil opens:NO destructive:NO disabled:NO]];
	}
	if (basic)
		[info addObject:[self valueRow:TGLocalized(@"Group Type")
				detail:TGLocalized(@"Private") action:nil opens:NO
				destructive:NO disabled:NO]];
	if (self.memberCount > 0)
		[info addObject:[self valueRow:(channel ? TGLocalized(@"Subscribers")
				: TGLocalized(@"Members"))
				detail:[NSString stringWithFormat:@"%ld", (long)self.memberCount]
				action:@"members" opens:YES destructive:NO disabled:NO]];
	if (basic && manager)
		[info addObject:[self valueRow:TGLocalized(@"Upgrade to Supergroup")
				detail:nil action:@"upgrade" opens:NO destructive:NO disabled:NO]];
	[sections addObject:TGSection(channel ? TGLocalized(@"Channel Info")
			: TGLocalized(@"Group Info"), nil, info)];

	// ── people ──────────────────────────────────────────────────────────
	if (!channel){
		NSMutableArray *people = [NSMutableArray array];
		if (manager && !self.canInvite)
			[people addObject:[self valueRow:TGLocalized(@"Add Members")
					detail:nil action:@"addMembers" opens:NO
					destructive:NO disabled:YES]];
		else if (self.canInvite)
			[people addObject:[self valueRow:TGLocalized(@"Add Members")
					detail:nil action:@"addMembers" opens:YES
					destructive:NO disabled:NO]];
		[people addObject:[self valueRow:TGLocalized(@"Search Members")
				detail:nil action:@"findMember" opens:YES
				destructive:NO disabled:NO]];
		NSString *header = self.memberCount > 0
				? TGLocalizedPluralValue(@"%@ member", @"%@ members",
						[NSString stringWithFormat:@"%ld",
								(long)self.memberCount],
						(NSInteger)self.memberCount)
				: TGLocalized(@"Members");
		[sections addObject:TGSection(header, nil, people)];
	}

	// ── calls ───────────────────────────────────────────────────────────
	[sections addObject:TGSection(TGLocalized(@"Calls"), nil, @[
		[self valueRow:TGLocalized(@"Group Call") detail:nil
				action:@"groupCall" opens:YES destructive:NO disabled:NO],
		[self valueRow:TGLocalized(@"Video Chat") detail:nil
				action:@"videoChat" opens:YES destructive:NO disabled:NO],
	])];

	// ── what the group does ─────────────────────────────────────────────
	if (supergroup && manager){
		BOOL canBehaviour = self.canChangeInfo;
		NSMutableArray *behaviour = [NSMutableArray array];
		[behaviour addObject:[self valueRow:TGLocalized(@"Permissions")
				detail:[self permissionsDetail]
				action:@"permissions" opens:YES destructive:NO
				disabled:!self.canRestrict]];
		[behaviour addObject:[self valueRow:TGLocalized(@"Slow Mode")
				detail:[self slowModeDetail] action:@"slow" opens:YES
				destructive:NO disabled:!canBehaviour]];
		[behaviour addObject:[self switchRow:TGLocalized(@"Sign Messages")
				detail:nil key:@"sign" on:self.signMessages
				enabled:canBehaviour]];
		[behaviour addObject:[self switchRow:TGLocalized(@"Send Messages")
				detail:nil key:@"join" on:self.joinToSend
				enabled:canBehaviour]];
		[behaviour addObject:[self switchRow:TGLocalized(@"History")
				detail:nil key:@"history" on:self.allHistory
				enabled:canBehaviour]];
		[behaviour addObject:[self switchRow:TGLocalized(@"Aggressive Anti-Spam")
				detail:nil key:@"antispam" on:self.aggressiveAntiSpam
				enabled:self.canToggleAntiSpam]];
		[behaviour addObject:[self valueRow:TGLocalized(@"Report False Positive")
				detail:nil action:@"antispamFalsePositive" opens:YES
				destructive:NO disabled:NO]];
		[behaviour addObject:[self switchRow:TGLocalized(@"Approve New Members")
				detail:nil key:@"joinRequests"
				on:[self.settings[@"joinByRequest"] boolValue]
				enabled:canBehaviour]];
		BOOL canHide = [self.settings[@"canHideMembers"] boolValue];
		[behaviour addObject:[self switchRow:TGLocalized(@"Hide Members")
				detail:nil key:@"hidden"
				on:[self.settings[@"hiddenMembers"] boolValue]
				enabled:canBehaviour && canHide]];
		if (!channel){
			[behaviour addObject:[self switchRow:TGLocalized(@"Topics")
					detail:[self.settings[@"isForum"] boolValue]
							? TGLocalized(@"On") : TGLocalized(@"Off")
					key:@"forum" on:[self.settings[@"isForum"] boolValue]
					enabled:canBehaviour]];
			BOOL broadcast = [self.settings[@"isBroadcast"] boolValue];
			[behaviour addObject:[self valueRow:TGLocalized(@"Broadcast Group")
					detail:broadcast ? TGLocalized(@"On")
							: TGLocalized(@"Convert")
					action:(broadcast ? nil : @"broadcast") opens:!broadcast
					destructive:NO disabled:!canBehaviour]];
			[behaviour addObject:[self valueRow:
					TGLocalized(@"Manage Welcome Messages")
					detail:nil action:@"welcome" opens:YES destructive:NO
					disabled:!canBehaviour]];
		}
		[behaviour addObject:[self switchRow:
				TGLocalized(@"Auto-Translate Messages")
				detail:[self.settings[@"automaticTranslation"] boolValue]
						? TGLocalized(@"On") : TGLocalized(@"Off")
				key:@"translation"
				on:[self.settings[@"automaticTranslation"] boolValue]
				enabled:canBehaviour]];
		if (self.joinRequestCount > 0){
			NSString *count = [NSString stringWithFormat:@"%ld",
					(long)self.joinRequestCount];
			[behaviour addObject:[self valueRow:TGLocalized(@"Join Requests")
					detail:count action:@"joinRequests" opens:YES
					destructive:NO disabled:!self.canInvite]];
		}
		[sections addObject:TGSection(TGLocalized(@"Permissions"), nil,
				behaviour)];
	}

	// ── usernames ───────────────────────────────────────────────────────
	if (supergroup && self.settings && manager){
		NSMutableArray *names = [NSMutableArray array];
		NSString *usernameDetail = self.editable.length
				? [@"@" stringByAppendingString:self.editable]
				: TGLocalized(@"None");
		[names addObject:[self valueRow:TGLocalized(@"Username")
				detail:usernameDetail action:@"username" opens:YES
				destructive:NO disabled:!self.canChangeInfo]];
		if (self.editable.length)
			[names addObject:[self valueRow:
					TGLocalized(@"Deactivate Username") detail:nil
					action:@"removeUsername" opens:NO destructive:YES
					disabled:!self.canChangeInfo]];
		[sections addObject:TGSection(TGLocalized(@"Username"), nil, names)];

		if (self.active.count){
			NSMutableArray *rows = [NSMutableArray array];
			for (NSString *name in self.active)
				[rows addObject:[self usernameRow:name active:YES]];
			[sections addObject:TGSection(@"USERNAME ORDER", nil, rows)];
		}
		if (self.disabled.count){
			NSMutableArray *rows = [NSMutableArray array];
			for (NSString *name in self.disabled)
				[rows addObject:[self usernameRow:name active:NO]];
			[sections addObject:TGSection(TGLocalized(@"Disabled"), nil, rows)];
		}
	}

	// ── tools ───────────────────────────────────────────────────────────
	if (manager){
		NSMutableArray *tools = [NSMutableArray array];
		[tools addObject:[self valueRow:TGLocalized(@"Manage") detail:nil
				action:@"chatTools" opens:YES destructive:NO disabled:NO]];
		if (channel)
			[tools addObject:[self valueRow:TGLocalized(@"Direct Messages")
					detail:nil action:@"directMessages" opens:YES
					destructive:NO disabled:NO]];
		[tools addObject:[self valueRow:TGLocalized(@"Import Messages")
				detail:nil action:@"import" opens:YES destructive:NO
				disabled:NO]];
		if (supergroup)
			[tools addObject:[self valueRow:TGLocalized(@"Send Message As...")
					detail:nil action:@"sendAs" opens:YES destructive:NO
					disabled:NO]];
		[tools addObject:[self valueRow:TGLocalized(@"Clear History")
				detail:nil action:@"clearByDate" opens:YES destructive:YES
				disabled:!self.canDeleteMessages]];
		if (supergroup){
			[tools addObject:[self valueRow:TGLocalized(@"Group Stickers")
					detail:nil action:@"groupStickers" opens:YES
					destructive:NO disabled:!self.canChangeInfo]];
			[tools addObject:[self valueRow:TGLocalized(@"Custom Emoji")
					detail:nil action:@"customEmojiStickers" opens:YES
					destructive:NO disabled:!self.canChangeInfo]];
		}
		[sections addObject:TGSection(TGLocalized(@"Manage"), nil, tools)];
	}

	// ── leaving and deleting ────────────────────────────────────────────
	if (self.myStatus.length){
		NSString *what = channel ? TGLocalized(@"Channel") : TGLocalized(@"Group");
		NSString *title = self.isOwner
				? TGLocalizedFormat(@"Delete %@", what)
				: TGLocalizedFormat(@"Leave %@", what);
		NSString *action = self.isOwner ? @"deleteChat" : @"leave";
		NSMutableDictionary *row = [self valueRow:title detail:nil
				action:action opens:NO destructive:YES disabled:NO];
		[sections addObject:TGSection(nil, nil, @[row])];
	}

	self.sections = sections;
	[self updateEditButton];
	[self reloadTableDebounced];
}

@end
