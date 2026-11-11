#import "TGGroupSettingsViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGSnackbar.h"
#import "TGContactsViewController.h"
#import "TGChatToolsViewController.h"
#import "TGGroupMemberActions.h"
#import "TGMemberCell.h"
#import "TGProfileViewController.h"
#import "TGIcons.h"
#import "TGGroupCallViewController.h"
#import "TGVideoChatSetupViewController.h"
#import "TGAntiSpamViewController.h"
#import "TGGroupSettingsViewController.h"
#import "TGGroupSwitch.h"
#import "TGGroupSettingsViewControllerInternal.h"
#import "TGGroupLogic.h"
#import "TGGroupStore.h"



//
// TGGroupSettingsViewController.m - one screen for everything a group is.
//
// The group profile's More menu used to grow one row per setting: Photo,
// Name, Description, Invite Link, Permissions, Sign Messages, Join to Send,
// All History, Welcome Messages, Direct Messages, Import, Send as, Clear by
// Date, Chat Tools. Each row asked the server what it sat on and answered
// with a sheet. A settings screen can show the value, group the rows by what
// they change, and leave the profile menu for the things a profile does.
//
// The chat id is the only thing the caller passes. Every action here names
// that id directly, so nothing is routed through the profile controller
// behind this screen.
//

/// The rows a section can hold. A switch draws a UISwitch, a member row a
/// face, and everything else a value with a chevron.
typedef NS_ENUM(NSInteger, TGGroupRowKind) {
	TGGroupRowInfo = 0,
	TGGroupRowAction,
	TGGroupRowSwitch,
	TGGroupRowUsername,
	TGGroupRowMember,
};

/// A switch that names the setting it changes, so a reload can rebuild rows
/// without an index pointing at the wrong one.


static NSMutableDictionary *TGRow(NSString *title, NSString *detail,
								  NSString *action, TGGroupRowKind kind) {
	NSMutableDictionary *row = [@{@"kind" : @(kind), @"title" : title ?: @""}
			mutableCopy];
	if (detail)
		row[@"detail"] = detail;
	if (action)
		row[@"action"] = action;
	return row;
}

static NSMutableDictionary *TGInfoRow(NSString *title, NSString *detail,
									  NSString *action) {
	return TGRow(title, detail, action, TGGroupRowInfo);
}

static NSMutableDictionary *TGOpenRow(NSString *title, NSString *detail,
									  NSString *action) {
	NSMutableDictionary *row = TGInfoRow(title, detail, action);
	row[@"opens"] = @YES;
	return row;
}

static NSMutableDictionary *TGActionRow(NSString *title, NSString *detail,
										NSString *action, BOOL destructive) {
	NSMutableDictionary *row = TGRow(title, detail, action, TGGroupRowAction);
	if (destructive)
		row[@"destructive"] = @YES;
	return row;
}

static NSMutableDictionary *TGOpenActionRow(NSString *title, NSString *detail,
											NSString *action, BOOL destructive) {
	NSMutableDictionary *row = TGActionRow(title, detail, action, destructive);
	row[@"opens"] = @YES;
	return row;
}

/// The same row when the account has no right for it: the title and the
/// reason stay on screen, the chevron and the tap do not. That is what
/// Telegram does for a switch an administrator may see but not move.
static NSMutableDictionary *TGDisabledRow(NSString *title, NSString *reason,
										  NSString *action) {
	NSMutableDictionary *row = TGActionRow(title, reason, nil, NO);
	if (action)
		row[@"refusedAction"] = action;
	row[@"disabled"] = @YES;
	return row;
}

static NSMutableDictionary *TGSwitchRow(NSString *title, NSString *detail,
										NSString *key, BOOL on, BOOL enabled) {
	NSMutableDictionary *row = TGRow(title, detail, nil, TGGroupRowSwitch);
	row[@"switch"] = key;
	row[@"on"] = @(on);
	row[@"enabled"] = @(enabled);
	return row;
}

static NSMutableDictionary *TGUsernameRow(NSString *username, BOOL active) {
	NSMutableDictionary *row = TGRow([@"@" stringByAppendingString:username],
									 active ? @"Active" : @"Disabled",
									 nil, TGGroupRowUsername);
	row[@"switch"] = [@"@" stringByAppendingString:username];
	row[@"username"] = username;
	row[@"active"] = @(active);
	row[@"on"] = @(active);
	row[@"enabled"] = @YES;
	return row;
}

static NSDictionary *TGSection(NSString *header, NSString *footer, NSArray *rows) {
	NSMutableDictionary *section = [NSMutableDictionary dictionary];
	if (header) section[@"header"] = header;
	if (footer) section[@"footer"] = footer;
	section[@"rows"] = rows ?: @[];
	return section;
}




@implementation TGGroupSettingsViewController (TGGroupSwitches)

#pragma mark - switches

- (void)switchChanged:(TGGroupSwitch *)sender {
	if (self.busy)
		return;
	NSString *key = sender.key;
	BOOL on = sender.on;
	if ([key hasPrefix:@"@"])
		[self setUsername:key active:on];
	else
		[self setBehaviour:key on:on];
}

- (void)setUsername:(NSString *)key active:(BOOL)on {
	NSString *username = [key substringFromIndex:1];
	self.busy = YES;
	[self rebuild];
	__weak typeof(self) weakSelf = self;
	[[TGGroupStore shared] toggleSupergroupUsernameIsActive:username
												 inChat:self.chatId
											   isActive:on
											 completion:^(BOOL ok, NSString *error){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.busy = NO;
		if (!ok){
			[me showRefusal:error title:TGLocalized(@"Username")];
			[me rebuild];
			return;
		}
		[me load];
	}];
}

- (void)setBehaviour:(NSString *)key on:(BOOL)on {
	self.busy = YES;
	[self rebuild];
	__weak typeof(self) weakSelf = self;
	void (^done)(BOOL, NSString *) = ^(BOOL ok, NSString *error){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.busy = NO;
		if (!ok){
			[me showRefusal:error title:TGLocalized(@"Group Settings")];
			[me rebuild];
			return;
		}
		if ([key isEqualToString:@"sign"])
			me.signMessages = on;
		else if ([key isEqualToString:@"join"])
			me.joinToSend = on;
		else if ([key isEqualToString:@"history"])
			me.allHistory = on;
		else if ([key isEqualToString:@"antispam"])
			me.aggressiveAntiSpam = on;
		else if ([key isEqualToString:@"hidden"] || [key isEqualToString:@"forum"] ||
				 [key isEqualToString:@"joinRequests"] ||
				 [key isEqualToString:@"translation"]){
			NSMutableDictionary *changed = [me.settings mutableCopy];
			if ([key isEqualToString:@"hidden"])
				changed[@"hiddenMembers"] = @(on);
			else if ([key isEqualToString:@"forum"])
				changed[@"isForum"] = @(on);
			else if ([key isEqualToString:@"joinRequests"])
				changed[@"joinByRequest"] = @(on);
			else
				changed[@"automaticTranslation"] = @(on);
			me.settings = changed;
		}
		[me rebuild];
	};

	if ([key isEqualToString:@"sign"]){
		[[TGGroupStore shared] setChatSignMessages:self.chatId on:on completion:^(BOOL ok){
			done(ok, ok ? nil : @"An error occurred.");
		}];
	} else if ([key isEqualToString:@"join"]){
		[[TGGroupStore shared] setChatJoinToSendMessages:self.chatId on:on
										  completion:^(BOOL ok){
			done(ok, ok ? nil : @"An error occurred.");
		}];
	} else if ([key isEqualToString:@"history"]){
		[[TGGroupStore shared] setSupergroupAllHistoryAvailable:self.chatId on:on
												completion:^(BOOL ok){
			done(ok, ok ? nil : @"An error occurred.");
		}];
	} else if ([key isEqualToString:@"antispam"]){
		[[TGGroupStore shared] setChat:self.chatId aggressiveAntiSpam:on
						completion:done];
	} else if ([key isEqualToString:@"hidden"]){
		[[TGGroupStore shared] setSupergroupHiddenMembersInChat:self.chatId on:on
												completion:done];
	} else if ([key isEqualToString:@"forum"]){
		[[TGGroupStore shared] setSupergroupForumInChat:self.chatId on:on
										 completion:done];
	} else if ([key isEqualToString:@"joinRequests"]){
		[[TGGroupStore shared] setSupergroupJoinByRequestInChat:self.chatId on:on
											 guardBotUserId:[self.settings[@"guardBotUserId"] longLongValue]
												 completion:done];
	} else {
		[[TGGroupStore shared] setSupergroupAutomaticTranslationInChat:self.chatId on:on
														completion:done];
	}
}

/// Group Type / Channel Type. Telegram treats "private" and "public" as the
/// presence of a username, so the row edits that one name rather than
/// inventing a second switch that could disagree with the Usernames section.
- (void)chooseGroupType {
	BOOL isPublic = self.editable.length > 0 || self.active.count > 0;
	if (!isPublic){
		[self editUsername];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Edit Username", @"Deactivate Username"]
						title:([self isChannelChat] ? @"Channel Type" : @"Group Type")
						message:nil
			 destructiveIndex:1
						 inView:self.view
					   onChoice:^(NSInteger index){
		if (index == 0){
			[weakSelf editUsername];
			return;
		}
		[weakSelf removeUsername];
	}];
}

/// Leaving is the member's row; the owner gets Delete instead because a
/// group cannot be left without an owner to hand it to.
- (void)leaveChat {
	__weak typeof(self) weakSelf = self;
	NSString *name = self.chatTitle ?: @"";
	NSString *message = [self isChannelChat]
			? TGLocalizedFormat(@"Are you sure you want to leave the channel **%@**?", name)
			: TGLocalizedFormat(@"Do you want to leave the group **%@**?", name);
	[TGAlertSheet showConfirm:TGStripBoldMarkers(message)
							title:([self isChannelChat] ? @"Leave Channel"
														: @"Leave Group")
						   action:@"Leave"
					  destructive:YES
						   inView:self.view
						onConfirm:^{
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		// deleteChat removes the row and leaves in the same request pair.
		[[TGGroupStore shared] deleteChat:me.chatId];
		[me.navigationController popToRootViewControllerAnimated:YES];
	}];
}

- (void)deleteChatForEveryone {
	NSString *what = [self isChannelChat] ? @"Channel" : @"Group";
	NSString *name = self.chatTitle ?: @"";
	NSString *message = [self isChannelChat]
			? TGLocalizedFormat(@"Do you want to delete the channel **%@** and all of its messages for all subscribers?", name)
			: TGLocalizedFormat(@"Do you want to delete the group **%@** and all of its messages for all members?", name);
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:TGStripBoldMarkers(message)
							title:[NSString stringWithFormat:@"Delete %@", what]
						   action:@"Delete"
					  destructive:YES
						   inView:self.view
						onConfirm:^{
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		[[TGGroupStore shared] deleteChatForEveryone:me.chatId completion:^(NSString *error){
			TGGroupSettingsViewController *again = weakSelf;
			if (!again)
				return;
			if (error.length){
				[TGAlertSheet showMessage:error
									title:[NSString stringWithFormat:@"Delete %@", what]
								   inView:again.view];
				return;
			}
			[again.navigationController popToRootViewControllerAnimated:YES];
		}];
	}];
}


@end
