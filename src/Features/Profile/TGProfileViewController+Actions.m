#import "TGProfileViewControllerInternal.h"
#import "TGProfileHeaderView.h"
#import "TGLocalization.h"
#import "TGCapabilities.h"
#import "TGStatusText.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGSnackbar.h"
#import "TGChatViewController.h"
#import "TGProfilePhotosViewController.h"
#import "TGGroupSettingsViewController.h"
#import "TGGroupMemberActions.h"
#import "TGGroupCallViewController.h"
#import "TGContactsViewController.h"
#import "TGNewContactViewController.h"
#import "TGProfileBirthdaySuggestViewController.h"
#import "TGProfileViewController+Tier2.h"
#import "TGSponsoredMessagesViewController.h"
#import "TGStoryComposerViewController.h"
#import "TGDevBotConsoleViewController.h"
#import "TGAffiliateProgramsViewController.h"
#import "TGGroupLogic.h"
#import <CoreImage/CoreImage.h>

@implementation TGProfileViewController (Actions)

/// The avatar's tap: other accounts' profiles go straight to the photo
/// history; the signed-in one asks, because its photo is also something this
/// app can take back - and the t.me link is a copy away.
- (void)avatarTapped {
	BOOL mine = !self.userId
			|| self.userId == [[TGProfileStore shared].me[@"id"] longLongValue];
	if (!mine){
		TGProfilePhotosViewController *photos =
				[[TGProfilePhotosViewController alloc] initWithUserId:self.userId];
		photos.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:photos animated:YES];
		return;
	}

	__weak typeof(self) weakSelf = self;
	NSMutableArray *choices = [NSMutableArray arrayWithObjects:
			@"Photos", @"Copy Link", nil];
	NSString *sheetTitle = self.name.length ? self.name : @"Profile";
	// The account wears no photo, so there is nothing to take back.
	if ([TGProfileStore shared].me[@"profile_photo"])
		[choices addObject:@"Remove Photo"];
	[TGAlertSheet showChoices:choices
						title:sheetTitle
			 destructiveIndex:[choices indexOfObject:@"Remove Photo"]
					   inView:self.view
					 onChoice:^(NSInteger index){
		NSString *picked = choices[index];
		if ([picked isEqualToString:@"Photos"]){
			TGProfilePhotosViewController *photos =
					[[TGProfilePhotosViewController alloc] initWithUserId:self.userId];
			photos.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:photos animated:YES];
			return;
		}
		if ([picked isEqualToString:@"Copy Link"]){
			[[TGProfileStore shared] myUserLink:^(NSString *link){
				if (link.length){
					[UIPasteboard generalPasteboard].string = link;
					[TGAlertSheet showMessage:@"Link copied." title:nil
									   inView:weakSelf.view];
				}
			}];
			return;
		}
		if ([picked isEqualToString:@"Remove Photo"]){
			// The photo to drop is the one the account wears now - the first
			// of the history is what Telegram wears back.
			[[TGProfileStore shared] userProfilePhotos:self.userId completion:^(NSArray *photos){
				NSDictionary *first = photos.firstObject;
				[[TGProfileStore shared] deleteProfilePhoto:
						[first[@"photoId"] longLongValue] completion:^(BOOL ok){
					if (ok)
						[weakSelf buildHeader];
				}];
			}];
		}
	}];
}

/// Whose phrase the status line carries: the network state first, then the
/// resting answer (last seen or member count). B4: a profile opened offline
/// used to freeze at its captured status instead of saying why it cannot
/// answer - "Waiting for network".
- (void)statusLabelOwnerChanged:(NSNotification *)note {
	NSString *network = TGNetworkSubtitleForState(
			(NSInteger)[TGProfileStore shared].connectionState, nil);
	NSString *line = network ?: (self.restingStatus ?: @"");
	if (line.length && ![self.headerView.statusText isEqualToString:line])
		self.headerView.statusText = line;
}

/// The Story tile and the empty Stories tab's link both start here.
- (void)addStoryTapped {
	__weak typeof(self) weakSelf = self;
	[TGStoryComposerViewController openFromController:self chatId:self.chatId
												title:@"Your Story" onPosted:^{
		[weakSelf reloadOwnStories];
	}];
}

- (void)handleActionKey:(NSString *)action {
	if ([action isEqualToString:@"saved"]){
		int64_t myId = [[TGProfileStore shared].me[@"id"] longLongValue];
		int64_t savedChatId = [[TGProfileStore shared] savedMessagesChatId] ?: myId;
		TGChatViewController *chat = [[TGChatViewController alloc] init];
		chat.chatId = savedChatId;
		chat.chatTitle = @"Saved Messages";
		chat.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:chat animated:YES];
	} else if ([action isEqualToString:@"edit"]){
		[self editProfileTapped];
	} else if ([action isEqualToString:@"story"]){
		[self addStoryTapped];
	} else if ([action isEqualToString:@"call"] || [action isEqualToString:@"video"]){
		[TGCallViewController presentForUserId:self.userId
										  name:self.name
									  outgoing:YES];
	} else if ([action isEqualToString:@"stop"]){
		[self stopBot];
	} else if ([action isEqualToString:@"message"]){
		if (self.isChannel)
			[self openDirectMessages];
		else
			[self messageTapped];
	} else if ([action isEqualToString:@"leave"]){
		[self leaveChatTapped];
	} else if ([action isEqualToString:@"add"]){
		[self addMemberTapped];
	} else if ([action hasSuffix:@"mute"]){
		self.muted = !self.muted;
		[[TGProfileStore shared] setChat:self.chatId muted:self.muted];
		[self buildHeader];              // the tile says the opposite now
	} else if ([action isEqualToString:@"search"]){
		if (self.onSearchTapped) self.onSearchTapped();
	} else {
		[self showMoreMenuFrom:(self.headerView ?: self.view)];
	}
}

/// The Message tile. A profile reached from Contacts has no chat behind it,
/// and Telegram opens one from here after the same can-send pre-check the
/// member sheet uses.
/// The Add to Contacts row opens the contact form prefilled with the name
/// and known number, and writes only when the person taps Done.
- (void)addToContactsTapped {
	NSArray *words = [self.name componentsSeparatedByString:@" "];
	TGNewContactViewController *contact = [[TGNewContactViewController alloc] init];
	contact.first = words.firstObject ?: @"";
	contact.last = words.count > 1
			? [[words subarrayWithRange:NSMakeRange(1, words.count - 1)]
					componentsJoinedByString:@" "] : @"";
	contact.phone = self.phoneNumber ?: @"";
	UINavigationController *nav = [[UINavigationController alloc]
			initWithRootViewController:contact];
	[self presentViewController:nav animated:YES completion:nil];
}

/// Stop is the bot's block: Telegram marks the bot stopped so it cannot
/// message again until the person starts it.
- (void)stopBot {
	int64_t userId = self.userId;
	if (!userId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] setUser:userId blocked:YES completion:^(BOOL ok){
		TGProfileViewController *me = weakSelf;
		if (!me || !ok)
			return;
		me.blocked = YES;
		[me loadDetails];
	}];
}

/// The bot's own policy page when it declares one. Official falls back to the
/// public page for a bot that has no URL of its own.
- (void)openBotPrivacyPolicy {
	int64_t userId = self.userId;
	if (!userId)
		return;
	[[TGProfileStore shared] request:@{@"@type" : @"getUserFullInfo", @"user_id" : @(userId)}
				   completion:^(NSDictionary *full){
		NSString *url = full[@"bot_info"][@"privacy_policy_url"];
		if (![url isKindOfClass:NSString.class] || !url.length)
			url = @"https://telegram.org/privacy";
		NSURL *target = [NSURL URLWithString:url];
		if (target)
			[[UIApplication sharedApplication] openURL:target];
	}];
}

/// A bot command is a chat message; open the bot's chat once and send it.
- (void)performBotCommand:(NSString *)command {
	int64_t userId = self.userId;
	if (!userId || !command.length)
		return;
	NSString *name = self.name;
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] privateChatWithUser:userId completion:^(int64_t chatId){
		TGProfileViewController *me = weakSelf;
		if (!me || !chatId)
			return;
		[[TGProfileStore shared] sendText:[@"/" stringByAppendingString:command]
							 toChat:chatId];
		TGChatViewController *chat = [[TGChatViewController alloc] init];
		chat.chatId = chatId;
		chat.chatTitle = name ?: @"";
		chat.hidesBottomBarWhenPushed = YES;
		[me.navigationController pushViewController:chat animated:YES];
	}];
}

- (void)messageTapped {
	int64_t userId = self.userId;
	if (!userId)
		return;
	NSString *name = self.name;
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] canSendMessageToUser:userId completion:^(NSString *result){
		TGProfileViewController *me = weakSelf;
		if (!me)
			return;
		if (![result isEqualToString:@"ok"]){
			NSString *say = [result isEqualToString:@"paidMessages"]
					? @"An error occurred."
					: ([result isEqualToString:@"userRestrictsNewChats"]
					   ? @"An error occurred."
					   : @"An error occurred.");
			[TGAlertSheet showMessage:say
								title:name.length ? name : @"Message"
							   inView:me.view];
			return;
		}
		[[TGProfileStore shared] privateChatWithUser:userId completion:^(int64_t chatId){
			TGProfileViewController *again = weakSelf;
			if (!again || !chatId)
				return;
			TGChatViewController *chat = [[TGChatViewController alloc] init];
			chat.chatId = chatId;
			chat.chatTitle = name ?: @"";
			chat.hidesBottomBarWhenPushed = YES;
			[again.navigationController pushViewController:chat animated:YES];
		}];
	}];
}

/// The group's Add tile and its menu row both land here: the contacts picker
/// in add-to-chat mode, which is the same picker Group Settings uses.
- (void)addMemberTapped {
	if (!self.chatId || !self.canInvite || self.isChannel)
		return;
	TGContactsViewController *contacts = [[TGContactsViewController alloc] init];
	contacts.addingToChatId = self.chatId;
	contacts.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:contacts animated:YES];
}

/// Tapping a member of a group: message them, or - where this account is
/// allowed to - change what they are in it. The sheet moved to
/// TGGroupMemberActions so Group Settings opens the same one.
- (void)showMemberActionsFor:(NSDictionary *)member {
	__weak typeof(self) weakSelf = self;
	[TGGroupMemberActions showForMember:member
								 inChat:self.chatId
								   from:self
							  onChanged:^{
		[weakSelf loadDetails];
	}];
}

/// The "more" menu from the current client, minus what this app cannot do:
/// no secret chats, no gifts.
- (void)showMoreMenuFrom:(UIView *)tile {
	NSMutableArray *items = [NSMutableArray array];
	// Emoji status, profile audio, direct messages and stake dice: one
	// category answers the rows and the tap so this menu stays a menu.
	[items addObjectsFromArray:[self tier2MoreItems]];
	if (self.userId){
		// Share Contact only exists for a real contact with a number to send.
		if (self.isContact && self.phoneNumber.length)
			[items addObject:@{@"title" : @"Share Contact", @"icon" : @"forward"}];
		if (self.userId == [[TGProfileStore shared].me[@"id"] longLongValue])
			[items addObject:@{@"title" : @"Copy Link", @"icon" : @"forward"}];
		// Bots cannot have secret chats.
		if (!self.isBot)
			[items addObject:@{@"title" : @"Start Secret Chat", @"icon" : @"privacy"}];
	}
	// The things one person can do to another's profile: a photo or birthday
	// they may accept, the picture only this account sees, and the card their
	// link opens with. The note row is added once, below, so it routes to the
	// note editor rather than the local-message branch.
	if (self.userId && self.userId != [[TGProfileStore shared].me[@"id"] longLongValue]){
		[items addObject:@{@"title" : @"Suggest as Profile Photo", @"icon" : @"react"}];
		[items addObject:@{@"title" : @"Suggest Birthday", @"icon" : @"star"}];
		[items addObject:@{@"title" : (self.hasPersonalPhoto
				? @"Change Profile Photo" : @"Set Profile Photo"), @"icon" : @"user"}];
		if (self.hasPersonalPhoto)
			[items addObject:@{@"title" : @"Remove Photo", @"icon" : @"delete",
							   @"destructive" : @YES}];
		[items addObject:@{@"title" : @"Share", @"icon" : @"folder"}];
	}
	// A group's own management lives on one screen now. The menu keeps the
	// way in and the rows that are not group management (a note, the date
	// picker, the chat's own history actions).
	if (!self.userId){
		if (self.canManage) {
			[items addObject:@{@"title" : self.isChannel ? @"Channel Settings"
														 : @"Group Settings",
							   @"icon" : @"privacy"}];
			if (self.isChannel)
				[items addObject:@{@"title" : @"Telegram Ads",
								   @"icon" : @"data"}];
			if (self.isChannel)
				[items addObject:@{@"title" : @"Affiliate Program",
								   @"icon" : @"star"}];
		}
		if (self.canInvite && !self.isChannel)
			[items addObject:@{@"title" : @"Add Members", @"icon" : @"plus"}];
		if (!self.isChannel) {
			[items addObject:@{@"title" : @"Calls", @"icon" : @"call"}];
			[items addObject:@{@"title" : @"View as Topics", @"icon" : @"folder"}];
		}
	}
	// A bot's own record is editable by the account that owns it, and its
	// commands carry the Settings / Help / Privacy rows official offers.
	if (self.userId && (self.isBot || [[TGProfileStore shared] userIsBot:self.userId])){
		[items addObject:@{@"title" : @"Bot Settings", @"icon" : @"data"}];
		[items addObject:@{@"title" : @"Help", @"icon" : @"faq"}];
		[items addObject:@{@"title" : @"Privacy Policy", @"icon" : @"policy"}];
	}
	// A note kept in the chat without being sent to anyone. It is the only
	// way to make a message that never leaves this device.
	if (self.userId && !self.isOwnProfile)
		[items addObject:@{@"title" : (self.personalNote.length
				? @"Note" : @"Add Notes"), @"icon" : @"edit"}];
	if ([[TGProfileStore shared] chatIsSavedMessages:self.chatId])
		[items insertObject:@{@"title" : @"Topics", @"icon" : @"folder"} atIndex:0];
	if (self.onJumpToDateTapped)
		[items addObject:@{@"title" : @"Jump to Date", @"icon" : @"folder"}];
	if (self.userId || !self.isChannel || self.canManage)
		[items addObject:@{@"title" : @"Auto-Delete Messages", @"icon" : @"delete"}];
	if (self.userId || !self.isChannel)
		[items addObject:@{@"title" : @"Clear history", @"icon" : @"delete"}];
	[items addObject:@{@"title" : @"Report", @"icon" : @"privacy",
					   @"destructive" : @YES}];
	BOOL isMe = self.userId == [[TGProfileStore shared].me[@"id"] longLongValue];
	// Delete Contact has its own bottom section on the profile.
	// Leaving and deleting are not the same row. Telegram keeps Delete Group
	// for the owner, because a group without one cannot be left; everybody
	// else gets Leave Group. The role arrives with loadOwnRole.
	if (!self.userId){
		if ([self isOwner]){
			[items addObject:@{@"title" : (self.isChannel ? @"Delete Channel"
														   : @"Delete Group"),
							   @"icon" : @"delete", @"destructive" : @YES}];
		} else {
			[items addObject:@{@"title" : (self.isChannel ? @"Leave Channel"
														   : @"Leave Group"),
							   @"icon" : @"delete", @"destructive" : @YES}];
		}
	}
	// A non-contact gets Block User in the card; a contact keeps it in More.
	if (self.userId && !isMe && !self.isBot && self.isContact) {
		[items addObject:@{@"title" : @"Delete Contact",
						   @"icon" : @"delete", @"destructive" : @YES}];
		[items addObject:@{@"title" : (self.blocked ? @"Unblock" : @"Block"),
						   @"icon" : @"privacy", @"destructive" : @YES}];
	}

	CGPoint where = [tile convertPoint:CGPointMake(TGHalf(tile.bounds.size.width),
												   tile.bounds.size.height)
								toView:self.navigationController.view];
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:where inView:self.navigationController.view
				  onChoice:^(NSInteger index, NSString *title){
		[weakSelf runMoreAction:title];
	}];
}

/// The chat's own link, with the two things worth doing to it: copying it,
/// and replacing it so the old one stops working.
- (void)reportThisChatWithOption:(NSString *)optionId {
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] reportChat:self.chatId
						 optionId:optionId
							 text:@""
					   completion:^(NSString *title, NSArray *options, BOOL done){
		TGProfileViewController *me = weakSelf;
		if (!me)
			return;
		if (done){
			[TGAlertSheet showMessage:@"Telegram moderators will review your report. Thank you!"
								title:@"Report" inView:me.view];
			return;
		}
		if (!options.count){
			// A reason this screen has no step for - free text, or a report
			// that has to name messages. Saying so beats a dead menu row.
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Report" inView:me.view];
			return;
		}

		NSMutableArray *titles = [NSMutableArray array];
		for (NSDictionary *option in options)
			[titles addObject:option[@"text"]];
		[TGAlertSheet showChoices:titles
							title:title.length ? title : @"Report"
				 destructiveIndex:-1
						   inView:me.view
						 onChoice:^(NSInteger index){
			[me reportThisChatWithOption:options[(NSUInteger)index][@"id"]];
		}];
	}];
}

- (void)leaveChatTapped {
	int64_t chatId = self.chatId;
	NSString *title = self.isChannel ? @"Leave Channel" : @"Leave Group";
	NSString *name = self.name ?: @"";
	NSString *message = self.isChannel
			? TGLocalizedFormat(@"Are you sure you want to leave the channel **%@**?", name)
			: TGLocalizedFormat(@"Do you want to leave the group **%@**?", name);
	[TGAlertSheet showConfirm:TGStripBoldMarkers(message)
						title:title
					   action:@"Leave"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		// deleteChat removes the row and leaves the group in one call,
		// so a later message cannot put it back on the list.
		[[TGProfileStore shared] deleteChat:chatId];
		[self.navigationController popToRootViewControllerAnimated:YES];
	}];
}

- (void)runMoreAction:(NSString *)title {
	if ([self runTier2Action:title])
		return;
	if ([title isEqualToString:@"Edit Profile"]){
		[self editProfileTapped];
		return;
	}
	if ([title isEqualToString:@"Copy Link"]){
		// The link is Telegram's, not the username's spellcheck: ask whose
		// account it hands out, which here is the signed-in one.
		NSString *name = self.name;
		__weak typeof(self) weakSelf = self;
		[[TGProfileStore shared] myUserLink:^(NSString *link){
			if (!link.length){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Copy Link"
								   inView:weakSelf.view];
				return;
			}
			[UIPasteboard generalPasteboard].string = link;
			NSString *message = @"Link copied.";
			[TGAlertSheet showMessage:message
								title:@"Copy Link"
							   inView:weakSelf.view];
		}];
		return;
	}

	if ([title isEqualToString:@"Story Archive"]){
		[self mediaTabSelected:@"archive"];
		return;
	}

	if ([title isEqualToString:@"Share Contact"]){
		NSString *phone = self.phoneNumber;
		if (!phone.length)
			return;
		NSString *name = self.name.length ? self.name : phone;
		NSString *card = [NSString stringWithFormat:
				@"BEGIN:VCARD\nVERSION:3.0\nFN:%@\nTEL;TYPE=CELL:+%@\nEND:VCARD\n",
				name, phone];
		NSString *path = [NSTemporaryDirectory()
				stringByAppendingPathComponent:@"contact.vcf"];
		[card writeToFile:path atomically:YES
				 encoding:NSUTF8StringEncoding error:NULL];
		NSURL *url = [NSURL fileURLWithPath:path];
		UIActivityViewController *share = [[UIActivityViewController alloc]
				initWithActivityItems:@[url] applicationActivities:nil];
		[self presentViewController:share animated:YES completion:nil];
		return;
	}


	if ([title isEqualToString:@"Auto-Delete Messages"]){
		int64_t chatId = self.chatId;
		[TGAlertSheet showChoices:@[@"Off", @"1 day", @"1 week", TGLocalizedPluralValue(@"%@ month", @"%@ months", @"1", 1)]
							title:@"Auto-Delete After..."
				 destructiveIndex:-1
						   inView:self.view
						 onChoice:^(NSInteger index){
			static const NSInteger seconds[4] = {0, 86400, 604800, 2592000};
			[[TGProfileStore shared] setChat:chatId autoDeleteSeconds:seconds[index]];
		}];
		return;
	}

	if ([title isEqualToString:@"Add Story"]){
		__weak typeof(self) weakSelf = self;
		[TGStoryComposerViewController openFromController:self chatId:self.chatId
													title:@"Your Story" onPosted:^{
			[weakSelf reloadOwnStories];
		}];
		return;
	}

	if ([title isEqualToString:@"Start Secret Chat"]){
		int64_t userId = self.userId;
		NSString *name = self.name;
		__weak typeof(self) weakSelf = self;
		[[TGProfileStore shared] createSecretChatWithUser:userId
										completion:^(int64_t chatId){
			TGProfileViewController *me = weakSelf;
			if (!chatId){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Secret Chat" inView:me.view];
				return;
			}
			// It exists but is not usable until their device answers the key
			// exchange, and a chat that silently refuses to send reads as a
			// bug rather than as waiting.
			Class chatClass = NSClassFromString(@"TGChatViewController");
			UIViewController *chat = [[chatClass alloc] init];
			[chat setValue:@(chatId) forKey:@"chatId"];
			[chat setValue:[NSString stringWithFormat:@"%@ (secret)",
					name.length ? name : @"Secret"] forKey:@"chatTitle"];
			chat.hidesBottomBarWhenPushed = YES;
			[me.navigationController pushViewController:chat animated:YES];
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Secret Chat" inView:chat.view];
		}];
		return;
	}








	if ([title isEqualToString:@"Telegram Ads"]){
		TGSponsoredMessagesViewController *ads =
				[[TGSponsoredMessagesViewController alloc] init];
		ads.chatId = self.chatId;
		ads.hidesBottomBarWhenPushed = YES;
		TGPresentControllerFrom(ads, self);
		return;
	}
	if ([title isEqualToString:@"Affiliate Program"]){
		TGAffiliateProgramsViewController *affiliate =
				[[TGAffiliateProgramsViewController alloc] init];
		if (self.userId){
			affiliate.kind = @"bot";
			affiliate.botUserId = self.userId;
		} else {
			affiliate.kind = @"channel";
			affiliate.chatId = self.chatId;
		}
		affiliate.hidesBottomBarWhenPushed = YES;
		TGPresentControllerFrom(affiliate, self);
		return;
	}
	if ([title isEqualToString:@"Bot Settings"]){
		TGDevBotConsoleViewController *bots = [[TGDevBotConsoleViewController alloc] init];
		bots.botUserId = self.userId;
		bots.hidesBottomBarWhenPushed = YES;
		TGPresentControllerFrom(bots, self);
		return;
	}
	if ([title isEqualToString:@"Help"]){
		[self performBotCommand:[title lowercaseString]];
		return;
	}
	if ([title isEqualToString:@"Privacy"] || [title isEqualToString:@"Privacy Policy"]){
		[self openBotPrivacyPolicy];
		return;
	}

	if ([title isEqualToString:@"Calls"]){
		TGGroupCallViewController *screen = [[TGGroupCallViewController alloc]
				initWithChatId:self.chatId groupCallId:0];
		screen.hidesBottomBarWhenPushed = YES;
		TGPresentControllerFrom(screen, self);
		return;
	}
	if ([title isEqualToString:@"Group Settings"] ||
			[title isEqualToString:@"Channel Settings"]){
		// Build through the runtime class name so a build that somehow lost
		// the screen says so in the log instead of pushing nil and looking
		// like a dead row.
		Class settingsClass = NSClassFromString(@"TGGroupSettingsViewController");
		TGGroupSettingsViewController *settings = settingsClass
				? [[settingsClass alloc] init] : nil;
		if (!settings){
			NSLog(@"TGProfile: Group Settings unavailable (class %@, chat %lld)",
				  settingsClass ? @"present but init returned nil" : @"missing",
				  self.chatId);
			[TGAlertSheet showMessage:@"An error occurred."
								title:title inView:self.view];
			return;
		}
		settings.chatId = self.chatId;
		settings.chatTitle = self.name;
		settings.hidesBottomBarWhenPushed = YES;
		NSLog(@"TGProfile: opening Group Settings for chat %lld", self.chatId);
		// Pushing is right when this profile is on a stack. A profile shown
		// modally has none, and `[nil pushViewController:]` is the tap that
		// does nothing; the shared helper presents it instead.
		TGPresentControllerFrom(settings, self);
		return;
	}

	/// The picker answers the same way the settings screen's own does: one
	/// UIImagePicker serves both wallpaper and avatar there, one serves this
	/// screen's group photo here.



	if ([title isEqualToString:@"Topics"]){
		__weak typeof(self) weakSelf = self;
		Class topicsClass = NSClassFromString(@"TGSavedTopicsViewController");
		UIViewController *topics = [[topicsClass alloc] init];
		if (topics){
			topics.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:topics animated:YES];
		}
		return;
	}





	if ([title isEqualToString:@"View as Topics"]){
		int64_t chatId = self.chatId;
		NSString *chatTitle = self.name;
		__weak typeof(self) weakSelf = self;
		// What it is now is read off the chat, so the menu row says the
		// move it is about to make rather than one it has already made.
		NSString *next = @"Show in Topics";
		NSString *warn = @"View as Topics";
		NSString *now = @"Messages";
		NSString *warnBack = @"View as Topics";
		[[TGProfileStore shared] chatWithViewAsTopics:chatId completion:^(BOOL viewAsTopics){
			NSString *action = viewAsTopics ? now : next;
			NSString *say = viewAsTopics ? warnBack : warn;
			[TGAlertSheet showConfirm:say
								title:nil
							   action:action
						  destructive:NO
							   inView:weakSelf.view
							onConfirm:^{
				[[TGProfileStore shared] setChatViewAsTopics:chatId
										  viewAsTopics:!viewAsTopics
											completion:^(BOOL ok){
					TGProfileViewController *me = weakSelf;
					if (!ok)
						[TGAlertSheet showMessage:@"An error occurred."
											title:(chatTitle ?: @"Topics")
										   inView:me.view];
				}];
			}];
		}];
		return;
	}

	if ([title isEqualToString:@"Add Notes"] ||
			[title isEqualToString:@"Note"]){
		int64_t userId = self.userId;
		__weak typeof(self) weakSelf = self;
		void (^write)(void) = ^{
			[TGAlertSheet showInput:@"Note"
							message:@"Notes are only visible to you."
						placeholder:@"Note"
							   text:weakSelf.personalNote
							 action:@"Save"
							 inView:weakSelf.view
						   onSubmit:^(NSString *text){
				[[TGProfileStore shared] setUserNote:text forUser:userId
									completion:^(BOOL ok, NSString *error){
					TGProfileViewController *me = weakSelf;
					if (!ok){
						[TGAlertSheet showMessage:(error ?: @"An error occurred.")
											title:@"Note" inView:me.view];
						return;
					}
					me.personalNote = text;
					[me loadDetails];
					[TGAlertSheet showMessage:@"Saved"
										title:@"Note" inView:me.view];
				}];
			}];
		};
		if (!self.personalNote.length){
			write();
			return;
		}
		[TGAlertSheet showChoices:@[@"Edit Note", @"Remove"]
							title:@"Note"
				 destructiveIndex:1
						   inView:self.view
						 onChoice:^(NSInteger index){
			if (index == 0){
				write();
				return;
			}
			[[TGProfileStore shared] setUserNote:@"" forUser:userId
								completion:^(BOOL ok, NSString *error){
				TGProfileViewController *me = weakSelf;
				if (!ok){
					[TGAlertSheet showMessage:(error ?: @"An error occurred.")
										title:@"Note" inView:me.view];
					return;
				}
				me.personalNote = @"";
				[me loadDetails];
				[TGAlertSheet showMessage:@"Saved"
									title:@"Note" inView:me.view];
			}];
		}];
		return;
	}

	if ([title isEqualToString:@"Suggest Birthday"]){
		TGProfileBirthdaySuggestViewController *suggest =
				[[TGProfileBirthdaySuggestViewController alloc] init];
		suggest.userId = self.userId;
		suggest.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:suggest animated:YES];
		return;
	}

	if ([title isEqualToString:@"Suggest as Profile Photo"] ||
			[title isEqualToString:@"Set Profile Photo"] ||
			[title isEqualToString:@"Change Profile Photo"]){
		self.pendingPhotoAction = [title isEqualToString:@"Suggest as Profile Photo"]
				? @"suggest" : @"personal";
		UIImagePickerController *picker = [[UIImagePickerController alloc] init];
		picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
		picker.delegate = self;
		[self presentViewController:picker animated:YES completion:nil];
		return;
	}

	if ([title isEqualToString:@"Remove Photo"]){
		int64_t userId = self.userId;
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showConfirm:@"Remove Photo"
							title:@"Remove Photo"
						   action:@"Remove"
					  destructive:YES
						   inView:self.view
						onConfirm:^{
			[[TGProfileStore shared] setPersonalProfilePhotoAtPath:nil forUser:userId
												  completion:^(BOOL ok, NSString *error){
				TGProfileViewController *me = weakSelf;
				if (!ok){
					[TGAlertSheet showMessage:(error ?: @"An error occurred.")
										title:@"Edit Profile Photo" inView:me.view];
					return;
				}
				me.hasPersonalPhoto = NO;
				[me loadDetails];
				[TGAlertSheet showMessage:@"Saved"
									title:@"Edit Profile Photo" inView:me.view];
			}];
		}];
		return;
	}

	if ([title isEqualToString:@"Share"]){
		int64_t userId = self.userId;
		__weak typeof(self) weakSelf = self;
		[[TGProfileStore shared] profileShareThemeBackdropsWithCompletion:^(NSArray *backdrops,
																	   NSString *error){
			TGProfileViewController *me = weakSelf;
			if (!me)
				return;
			if (error.length){
				[TGAlertSheet showMessage:error title:@"Share" inView:me.view];
				return;
			}
			NSMutableArray *titles = [NSMutableArray arrayWithObject:@"Default"];
			for (NSDictionary *backdrop in backdrops)
				[titles addObject:backdrop[@"name"] ?: @"Backdrop"];
			if (titles.count == 1){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Share" inView:me.view];
				return;
			}
			[TGAlertSheet showChoices:titles
								title:@"Share"
							  message:nil
					 destructiveIndex:-1
							   inView:me.view
							 onChoice:^(NSInteger index){
				[[TGProfileStore shared] privateChatWithUser:userId completion:^(int64_t chatId){
					if (!chatId){
						[TGAlertSheet showMessage:@"An error occurred."
											title:@"Share" inView:me.view];
						return;
					}
					void (^answer)(BOOL, NSString *) = ^(BOOL ok, NSString *error){
						[TGAlertSheet showMessage:(ok
								? @"Saved"
								: (error ?: @"An error occurred."))
											title:@"Share" inView:me.view];
						if (ok)
							[me loadDetails];
					};
					if (index == 0){
						[[TGProfileStore shared] clearProfileShareThemeForChat:chatId
															  completion:answer];
						return;
					}
					NSDictionary *backdrop = backdrops[(NSUInteger)index - 1];
					[[TGProfileStore shared] setProfileShareThemeForChat:chatId
														backdropId:[backdrop[@"id"] integerValue]
														useDefault:NO
														completion:answer];
				}];
			}];
		}];
		return;
	}

	if ([title isEqualToString:@"Report"]){
		[self reportThisChatWithOption:nil];
		return;
	}

	if ([title isEqualToString:@"Jump to Date"]){
		if (self.onJumpToDateTapped)
			self.onJumpToDateTapped();
		return;
	}

	if ([title isEqualToString:@"Delete Contact"]){
		int64_t userId = self.userId;
		__weak typeof(self) weakSelf = self;
		// One red row in an action sheet, as official has it; no repeated
		// message under the title.
		[TGAlertSheet showConfirm:nil
							title:nil
						   action:@"Delete Contact"
					  destructive:YES
						   inView:self.view
						onConfirm:^{
			[[TGProfileStore shared] removeContactWithUserId:userId completion:^(BOOL ok){
				TGProfileViewController *me = weakSelf;
				if (!me)
					return;
				NSString *done = TGStripBoldMarkers(TGLocalizedFormat(
						@"**%@** deleted from your contacts", me.name ?: @""));
				[TGAlertSheet showMessage:(ok ? done : @"An error occurred.")
									title:@"Delete Contact" inView:me.view];
				if (ok)
					[me loadDetails];
			}];
		}];
		return;
	}

	if ([title isEqualToString:@"Add Members"]){
		[self addMemberTapped];
		return;
	}

	if ([title isEqualToString:@"Leave Group"] || [title isEqualToString:@"Leave Channel"]){
		[self leaveChatTapped];
		return;
	}

	if ([title isEqualToString:@"Delete Group"] || [title isEqualToString:@"Delete Channel"] ||
			[title isEqualToString:@"Delete for Everyone"]){
		int64_t chatId = self.chatId;
		NSString *name = self.name ?: @"";
		NSString *message = [title isEqualToString:@"Delete Channel"]
				? TGLocalizedFormat(@"Do you want to delete the channel **%@** and all of its messages for all subscribers?", name)
				: TGLocalizedFormat(@"Do you want to delete the group **%@** and all of its messages for all members?", name);
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showConfirm:TGStripBoldMarkers(message)
							title:title
						   action:@"Delete"
					  destructive:YES
						   inView:self.view
						onConfirm:^{
			[[TGProfileStore shared] deleteChatForEveryone:chatId completion:^(NSString *error){
				TGProfileViewController *me = weakSelf;
				if (error) {
					[TGAlertSheet showMessage:error title:title inView:me.view];
					return;
				}
				[me.navigationController popToRootViewControllerAnimated:YES];
			}];
		}];
		return;
	}

	if ([title isEqualToString:@"Clear history"]){
		int64_t chatId = self.chatId;
		[TGAlertSheet showConfirm:@"This will **delete all messages** in this chat."
							title:@"Clear history"
						   action:@"Clear"
					  destructive:YES
						   inView:self.view
						onConfirm:^{ [[TGProfileStore shared] clearHistoryInChat:chatId]; }];
		return;
	}

	// The last row of a user's menu is Block/Unblock; an unknown title must
	// not fall through and silently block them.
	if ([title isEqualToString:@"Block"] || [title isEqualToString:@"Unblock"]){
		BOOL block = ![title isEqualToString:@"Unblock"];
		int64_t userId = self.userId;
		__weak typeof(self) weakSelf = self;
		if (!block){
			[[TGProfileStore shared] setUser:userId blocked:NO completion:^(BOOL ok){
				TGProfileViewController *me = weakSelf;
				if (!me || !ok)
					return;
				me.blocked = NO;
				[me loadDetails];
			}];
			return;
		}
		[TGAlertSheet showConfirm:TGLocalizedFormat(@"Do you want to block %@ from messaging and calling you on Telegram?", self.name ?: @"")
							title:nil
						   action:TGLocalizedFormat(@"Block %@", self.name ?: @"")
					  destructive:YES
						   inView:self.view
						onConfirm:^{
			[[TGProfileStore shared] setUser:userId blocked:YES completion:^(BOOL ok){
				TGProfileViewController *me = weakSelf;
				if (!me || !ok)
					return;
				me.blocked = YES;
				[me loadDetails];
			}];
		}];
	}
}

/// The picker's answer becomes a file, because that is what the photo
/// requests take: scaled, JPEG'd and written out like the settings screen
/// does with its avatar.
- (void)imagePickerController:(UIImagePickerController *)picker
		didFinishPickingMediaWithInfo:(NSDictionary *)info {
	[picker dismissViewControllerAnimated:YES completion:nil];
	if (self.pendingPhotoAction.length){
		NSString *action = self.pendingPhotoAction;
		self.pendingPhotoAction = nil;
		UIImage *image = info[UIImagePickerControllerOriginalImage];
		if (!image)
			return;
		UIImage *scaled = [TGIcons decodedImage:image
								fittingSize:CGSizeMake(TGMetricUploadPhotoSide, TGMetricUploadPhotoSide)
									   fill:NO scale:TGMetricScaleFull];
		NSString *path = [NSTemporaryDirectory()
				stringByAppendingPathComponent:@"profile-suggestion.jpg"];
		if (![UIImageJPEGRepresentation(scaled, TGCompressionQualityStandard) writeToFile:path atomically:YES]){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Edit Profile Photo" inView:self.view];
			return;
		}
		int64_t userId = self.userId;
		__weak typeof(self) weakSelf = self;
		BOOL suggest = [action isEqualToString:@"suggest"];
		void (^answer)(BOOL, NSString *) = ^(BOOL ok, NSString *error){
			TGProfileViewController *me = weakSelf;
			if (!ok){
				[TGAlertSheet showMessage:(error ?: @"An error occurred.")
									title:@"Edit Profile Photo" inView:me.view];
				return;
			}
			[TGAlertSheet showMessage:(suggest
					? @"Suggested Profile Photo"
					: @"Saved")
								title:@"Edit Profile Photo" inView:me.view];
			if (!suggest)
				[me loadDetails];
		};
		if (suggest)
			[[TGProfileStore shared] suggestProfilePhotoAtPath:path forUser:userId
											  completion:answer];
		else
			[[TGProfileStore shared] setPersonalProfilePhotoAtPath:path forUser:userId
												  completion:answer];
		return;
	}
}

/// A username row's QR: the t.me address drawn as a code, with the address
/// under it for anyone who has to type it. CoreImage's generator is used when
/// the OS has it; the oldest devices fall back to the plain address.
- (void)showQRCodeForValue:(NSString *)value {
	NSString *address = value ?: @"";
	if ([address hasPrefix:@"@"])
		address = [@"https://t.me/" stringByAppendingString:
				[address substringFromIndex:1]];
	UIViewController *sheet = [[UIViewController alloc] init];
	sheet.title = @"QR Code";
	sheet.view.backgroundColor = [[TGTheme shared] groupedBackgroundColour];
	CGFloat width = sheet.view.bounds.size.width;
	UIImageView *image = [[UIImageView alloc] initWithFrame:
			CGRectMake(TGCenteredOrigin(width, TGMetricProfileAvatar), TGMetricPadLarge,
					TGMetricProfileAvatar, TGMetricProfileAvatar)];
	image.contentMode = UIViewContentModeScaleAspectFit;
	image.backgroundColor = [[TGTheme shared] cardBackgroundColour];
	Class filterClass = NSClassFromString(@"CIFilter");
	if (filterClass){
		CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
		[filter setValue:[address dataUsingEncoding:NSUTF8StringEncoding]
				  forKey:@"inputMessage"];
		[filter setValue:@"H" forKey:@"inputCorrectionLevel"];
		CIImage *output = filter.outputImage;
		if (output){
			CIContext *context = [CIContext contextWithOptions:nil];
			CGFloat scale = TGMetricProfileAvatar / MAX(1, output.extent.size.width);
			CGImageRef cg = [context createCGImage:output
										 fromRect:CGRectMake(0, 0,
												 output.extent.size.width * scale,
												 output.extent.size.height * scale)];
			if (cg){
				image.image = [UIImage imageWithCGImage:cg];
				CGImageRelease(cg);
			}
		}
	}
	if (!image.image)
		image.hidden = YES;
	[sheet.view addSubview:image];

	UILabel *label = [[UILabel alloc] initWithFrame:
			CGRectMake(TGMetricPadLarge, CGRectGetMaxY(image.frame) + TGMetricPad,
					width - TGDoubled(TGMetricPadLarge), TGDoubled(TGMetricLineBody))];
	label.numberOfLines = 2;
	label.textAlignment = NSTextAlignmentCenter;
	label.font = TGFontBody();
	label.textColor = [[TGTheme shared] secondaryTextColour];
	label.backgroundColor = [UIColor clearColor];
	label.text = address;
	[sheet.view addSubview:label];

	sheet.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:@"Close" style:UIBarButtonItemStylePlain
				   target:self action:@selector(closeQRCode:)];
	UINavigationController *nav = [[UINavigationController alloc]
			initWithRootViewController:sheet];
	[self presentViewController:nav animated:YES completion:nil];
}

- (void)closeQRCode:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	self.pendingPhotoAction = nil;
	[picker dismissViewControllerAnimated:YES completion:nil];
}

@end
