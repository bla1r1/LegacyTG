#import "TGGroupSettingsViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
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




@implementation TGGroupSettingsViewController (TGGroupData)

#pragma mark - the chat behind the screen

- (BOOL)isSupergroupChat {
	return [self.chat[@"type"][@"@type"] isEqualToString:@"chatTypeSupergroup"];
}

- (BOOL)isChannelChat {
	return [self isSupergroupChat] &&
		   [self.chat[@"type"][@"is_channel"] boolValue];
}

- (BOOL)isBasicGroupChat {
	return [self.chat[@"type"][@"@type"] isEqualToString:@"chatTypeBasicGroup"];
}

- (void)load {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatRecordForChat:self.chatId completion:^(NSDictionary *chat){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		if (!chat){
			// No record means no type, and every row below is decided by the
			// type. A blank screen would leave the user guessing why.
			me.loaded = YES;
			me.sections = @[TGSection(@"Group Settings",
					@"Telegram did not return this chat. Reopen the profile to try again.",
					@[TGInfoRow(@"Unavailable", @"No answer from Telegram", nil)])];
			[me reloadTableDebounced];
			return;
		}
		me.chat = chat;
		NSString *title = chat[@"title"];
		if (title.length){
			me.chatTitle = title;
			me.title = title;
		}
		me.hasPhoto = [[TGClient shared] photoFileIdForChat:me.chatId] != nil;
		me.loaded = YES;
		[me rebuild];
		[me loadOwnRole];
	}];
	[[TGClient shared] chatProfile:self.chatId completion:^(NSDictionary *info){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.descriptionText = info[@"description"] ?: @"";
		me.memberCount = [info[@"members"] integerValue];
		me.inviteLink = info[@"inviteLink"] ?: @"";
		[me rebuild];
	}];
	[[TGClient shared] supergroupSettingsForChat:self.chatId completion:^(NSDictionary *settings){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.settings = settings;
		me.active = [settings[@"active"] isKindOfClass:NSArray.class]
				? [settings[@"active"] mutableCopy] : [NSMutableArray array];
		me.disabled = [settings[@"disabled"] isKindOfClass:NSArray.class]
				? [settings[@"disabled"] mutableCopy] : [NSMutableArray array];
		me.editable = settings[@"editable"] ?: @"";
		[me rebuild];
	}];
	[[TGClient shared] groupFullInfoForChat:self.chatId completion:^(NSDictionary *info){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.groupInfo = info;
		me.aggressiveAntiSpam = [info[@"has_aggressive_anti_spam_enabled"] boolValue];
		me.canToggleAntiSpam = [info[@"can_toggle_aggressive_anti_spam"] boolValue];
		[me rebuild];
	}];
	[[TGClient shared] supergroupFlagsForChat:self.chatId
			completion:^(BOOL signMessages, BOOL joinToSend, BOOL allHistory, BOOL ok){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me || !ok)
			return;
		me.signMessages = signMessages;
		me.joinToSend = joinToSend;
		me.allHistory = allHistory;
		[me rebuild];
	}];
	[[TGClient shared] membersOfChat:self.chatId completion:^(NSArray *members){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.members = members ?: @[];
		[me rebuild];
	}];
}

- (void)loadOwnRole {
	// The member list is the aggregate; this is the one record that says
	// what this account may actually change. Without it the screen would
	// offer a plain member every switch and then show Telegram's refusal.
	int64_t meId = [[TGClient shared].me[@"id"] longLongValue];
	if (!meId || !self.chatId){
		self.canManage = NO;
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatMember:meId inChat:self.chatId
						completion:^(NSDictionary *member){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		NSDictionary *status = [member[@"status"] isKindOfClass:NSDictionary.class]
				? member[@"status"] : @{};
		NSString *kind = status[@"@type"];
		me.myStatus = [kind isEqualToString:@"chatMemberStatusCreator"] ? @"owner"
				: ([kind isEqualToString:@"chatMemberStatusAdministrator"]
						? @"admin" : @"member");
		me.myRights = [status[@"rights"] isKindOfClass:NSDictionary.class]
				? status[@"rights"] : @{};
		BOOL owner = [me.myStatus isEqualToString:@"owner"];
		me.isOwner = owner;
		me.canManage = owner || [me.myStatus isEqualToString:@"admin"];
		me.canChangeInfo = owner || [me.myRights[@"can_change_info"] boolValue];
		me.canInvite = owner || [me.myRights[@"can_invite_users"] boolValue];
		me.canRestrict = owner || [me.myRights[@"can_restrict_members"] boolValue];
		me.canDeleteMessages = owner ||
				[me.myRights[@"can_delete_messages"] boolValue];
		// A basic group's administrators have no rights object in this
		// TDLib, and any unrestricted member may invite. The chat's own
		// permissions are the source for both.
		if ([me isBasicGroupChat]){
			if (!owner){
				id canInvite = me.chat[@"permissions"][@"can_invite_users"];
				me.canInvite = canInvite ? [canInvite boolValue] : YES;
			}
			if (me.canManage && !owner){
				me.canChangeInfo = YES;
				me.canDeleteMessages = YES;
			}
		}
		[me rebuild];
	}];
}

- (void)reloadTableDebounced {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(doReloadTable) object:nil];
	[self performSelector:@selector(doReloadTable) withObject:nil afterDelay:0.05];
}

- (void)doReloadTable {
	[self.tableView reloadData];
}

- (void)showRefusal:(NSString *)error title:(NSString *)title {
	[TGAlertSheet showMessage:(error.length ? error : @"Telegram refused that.")
						title:title inView:self.view];
}


@end
