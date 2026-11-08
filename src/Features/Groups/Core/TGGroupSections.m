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




@implementation TGGroupSettingsViewController (TGGroupSections)

#pragma mark - the section model

- (NSString *)permissionsDetail {
	NSDictionary *p = self.chat[@"permissions"];
	if (![p isKindOfClass:NSDictionary.class])
		return @"Change";
	BOOL send = [p[@"can_send_basic_messages"] boolValue] ||
				[p[@"can_send_messages"] boolValue];
	BOOL media = [p[@"can_send_photos"] boolValue] ||
				 [p[@"can_send_videos"] boolValue] ||
				 [p[@"can_send_documents"] boolValue];
	if (!send)
		return @"Read only";
	return media ? @"Everything allowed" : @"Messages only";
}

- (NSString *)slowModeDetail {
	NSInteger seconds = [self.groupInfo[@"slow_mode_delay"] integerValue];
	if (seconds <= 0)
		return @"Off";
	if (seconds < 60)
		return [NSString stringWithFormat:@"%ld s", (long)seconds];
	if (seconds < 3600)
		return [NSString stringWithFormat:@"%ld min", (long)(seconds / 60)];
	return [NSString stringWithFormat:@"%ld h", (long)(seconds / 3600)];
}

- (NSString *)labelForTab:(NSString *)tab {
	if ([tab isEqualToString:@"media"]) return @"Media";
	if ([tab isEqualToString:@"files"]) return @"Files";
	if ([tab isEqualToString:@"links"]) return @"Links";
	if ([tab isEqualToString:@"music"]) return @"Music";
	if ([tab isEqualToString:@"voice"]) return @"Voice";
	if ([tab isEqualToString:@"gifs"])  return @"GIFs";
	return @"Posts";
}

- (void)updateEditButton {
	BOOL canOrder = self.canManage && self.canChangeInfo &&
			self.active.count > 1 && self.settings != nil;
	if (!canOrder){
		self.navigationItem.rightBarButtonItem = nil;
		return;
	}
	self.navigationItem.rightBarButtonItem =
			[[UIBarButtonItem alloc] initWithTitle:(self.editingNames ? @"Done" : @"Edit")
											  style:UIBarButtonItemStylePlain
											 target:self action:@selector(toggleEditing)];
}

- (void)toggleEditing {
	self.editingNames = !self.editingNames;
	[self.tableView setEditing:self.editingNames animated:YES];
	[self updateEditButton];
}

- (void)rebuild {
	if (!self.loaded || !self.chat)
		return;
	BOOL supergroup = [self isSupergroupChat];
	BOOL channel = [self isChannelChat];
	BOOL basic = [self isBasicGroupChat];
	BOOL manager = self.canManage;
	NSMutableArray *sections = [NSMutableArray array];

	// ── identity ────────────────────────────────────────────────────────
	NSMutableArray *info = [NSMutableArray array];
	BOOL editInfo = manager && self.canChangeInfo;
	NSString *photoDetail = self.hasPhoto ? @"Change" : @"Set";
	NSString *nameDetail = self.chatTitle ?: @"";
	NSString *noInfoRight = @"An administrator with the change-info right does this";
	if (manager && !self.canChangeInfo){
		[info addObject:TGDisabledRow(@"Group Photo", noInfoRight, @"photo")];
		[info addObject:TGDisabledRow(@"Group Name", nameDetail, @"name")];
	} else {
		[info addObject:TGOpenRow(@"Group Photo",
				manager ? photoDetail : (self.hasPhoto ? @"Set" : @"None"),
				manager ? @"photo" : nil)];
		[info addObject:TGInfoRow(@"Group Name", nameDetail, manager ? @"name" : nil)];
	}
	if (supergroup){
		if (manager && !self.canChangeInfo){
			[info addObject:TGDisabledRow(@"Description",
					self.descriptionText.length ? self.descriptionText
							: @"No description", @"description")];
		} else {
			[info addObject:TGInfoRow(@"Description",
					self.descriptionText.length ? self.descriptionText
							: (manager ? @"Add a description" : @"None"),
					manager ? @"description" : nil)];
		}
		if (manager && !self.canInvite){
			[info addObject:TGDisabledRow(@"Invite Link",
					self.inviteLink.length ? self.inviteLink
							: @"An administrator with the invite right manages links",
					@"invite")];
		} else if (manager || self.inviteLink.length){
			[info addObject:TGInfoRow(@"Invite Link",
					self.inviteLink.length ? self.inviteLink
							: (manager ? @"Manage" : @"None"),
					manager ? @"invite" : nil)];
		}
		// Telegram names this row Group Type / Channel Type and sits it
		// above the link. Private here means no active username.
		BOOL isPublic = self.editable.length > 0 || self.active.count > 0;
		NSString *typeTitle = channel ? @"Channel Type" : @"Group Type";
		NSString *typeDetail = isPublic
				? (self.editable.length
						? [@"@" stringByAppendingString:self.editable] : @"Public")
				: @"Private";
		if (editInfo)
			[info addObject:TGInfoRow(typeTitle, typeDetail, @"groupType")];
		else if (manager)
			[info addObject:TGDisabledRow(typeTitle, typeDetail, @"groupType")];
		else
			[info addObject:TGInfoRow(typeTitle, typeDetail, nil)];
		[info addObject:TGInfoRow(@"Main Profile Tab",
				[self labelForTab:self.settings[@"mainTab"]],
				editInfo ? @"tab" : nil)];
	}
	if (basic)
		[info addObject:TGInfoRow(@"Group Type", @"Private", nil)];
	if (self.memberCount > 0)
		[info addObject:TGInfoRow(channel ? @"Subscribers" : @"Members",
				[NSString stringWithFormat:@"%ld", (long)self.memberCount], nil)];
	if (basic && manager)
		[info addObject:TGActionRow(@"Upgrade to Supergroup",
				@"Basic groups stop at 200 members", @"upgrade", NO)];
	[sections addObject:TGSection(@"Group Info",
			manager ? (basic ? @"A basic group has no username, invite link or supergroup "
					@"permissions. Upgrading gives it those and a new chat id."
				  : @"The public identity of this group. Telegram applies each "
					@"change or says why not.")
					: @"Anyone in the group can read this. Changing it needs an "
					  @"administrator.",
			info)];

	// ── people ──────────────────────────────────────────────────────────
	if (!channel){
		NSMutableArray *people = [NSMutableArray array];
		if (manager && !self.canInvite)
			[people addObject:TGDisabledRow(@"Add Members",
					@"An administrator with the invite right adds people",
					@"addMembers")];
		else if (self.canInvite)
			[people addObject:TGOpenActionRow(@"Add Members", nil, @"addMembers", NO)];
		[people addObject:TGActionRow(@"Find Member", @"Search by name or @username",
									  @"findMember", NO)];
		for (NSDictionary *member in self.members)
			[people addObject:@{@"kind" : @(TGGroupRowMember), @"member" : member}];
		NSString *header = self.memberCount > 0
				? [NSString stringWithFormat:@"%ld members", (long)self.memberCount]
				: @"Members";
		[sections addObject:TGSection(header,
				@"Tap a member for their profile; hold for their actions. The "
				@"list shows the members Telegram returned first.", people)];
	}

	// ── calls ───────────────────────────────────────────────────────────
	NSMutableArray *calls = [NSMutableArray array];
	[calls addObject:TGOpenActionRow(@"Group Call",
			@"Join, leave or manage the active call", @"groupCall", NO)];
	[calls addObject:TGOpenActionRow(@"Video Chat",
			@"Create, schedule and record", @"videoChat", NO)];
	[sections addObject:TGSection(@"Calls",
			@"A video chat is a group call bound to this chat. The call screen "
			@"shows Telegram's participant list, messages and stream metadata; "
			@"this client has no group-call audio engine.", calls)];

	// ── what the group does ─────────────────────────────────────────────
	if (supergroup && manager){
		BOOL canBehaviour = self.canChangeInfo;
		NSMutableArray *behaviour = [NSMutableArray array];
		if (self.canRestrict)
			[behaviour addObject:TGActionRow(@"Permissions",
					[self permissionsDetail], @"permissions", NO)];
		else
			[behaviour addObject:TGDisabledRow(@"Permissions",
					[self permissionsDetail], @"permissions")];
		if (canBehaviour)
			[behaviour addObject:TGActionRow(@"Slow Mode", [self slowModeDetail],
											 @"slow", NO)];
		else
			[behaviour addObject:TGDisabledRow(@"Slow Mode", [self slowModeDetail],
											   @"slow")];
		[behaviour addObject:TGSwitchRow(@"Sign Messages", nil, @"sign",
										 self.signMessages, canBehaviour)];
		[behaviour addObject:TGSwitchRow(@"Join to Send", nil, @"join",
										 self.joinToSend, canBehaviour)];
		[behaviour addObject:TGSwitchRow(@"All History", nil, @"history",
										 self.allHistory, canBehaviour)];
		[behaviour addObject:TGSwitchRow(@"Aggressive Anti-Spam",
				self.canToggleAntiSpam
						? (self.aggressiveAntiSpam
								? @"Deletes suspicious messages automatically"
								: @"Off")
						: @"Telegram does not allow this group to turn it on",
				@"antispam", self.aggressiveAntiSpam, self.canToggleAntiSpam)];
		[behaviour addObject:TGOpenActionRow(@"Anti-Spam False Positives",
				@"Report a message deleted by mistake", @"antispamFalsePositive",
				NO)];
		[behaviour addObject:TGSwitchRow(@"Join by Request",
				[self.settings[@"joinByRequest"] boolValue]
						? @"Administrators approve each join"
						: @"Anyone with the link joins",
				@"joinRequests",
				[self.settings[@"joinByRequest"] boolValue], canBehaviour)];
		BOOL canHide = [self.settings[@"canHideMembers"] boolValue];
		[behaviour addObject:TGSwitchRow(@"Hidden Members",
				canHide ? (self.settings[@"hiddenMembers"]
						? @"Members are hidden" : @"Members are listed")
						: @"Telegram does not allow this group to hide members",
				@"hidden", [self.settings[@"hiddenMembers"] boolValue],
				canBehaviour && canHide)];
		if (!channel){
			[behaviour addObject:TGSwitchRow(@"Forum Mode",
					self.settings[@"isForum"] ? @"Topics are on" : @"One message stream",
					@"forum", [self.settings[@"isForum"] boolValue], canBehaviour)];
			BOOL broadcast = [self.settings[@"isBroadcast"] boolValue];
			if (canBehaviour)
				[behaviour addObject:TGActionRow(@"Broadcast Group",
						broadcast ? @"On" : @"Convert",
						broadcast ? nil : @"broadcast", NO)];
			else
				[behaviour addObject:TGDisabledRow(@"Broadcast Group",
						broadcast ? @"On" : @"Convert", @"broadcast")];
			if (canBehaviour)
				[behaviour addObject:TGActionRow(@"Welcome Messages",
						@"Greet someone when they join", @"welcome", NO)];
			else
				[behaviour addObject:TGDisabledRow(@"Welcome Messages",
						@"Greet someone when they join", @"welcome")];
		}
		[behaviour addObject:TGSwitchRow(@"Automatic Translation",
				self.settings[@"automaticTranslation"]
						? @"The chat suggests a translation"
						: @"No automatic translation",
				@"translation",
				[self.settings[@"automaticTranslation"] boolValue], canBehaviour)];
		if (self.canInvite)
			[behaviour addObject:TGActionRow(@"Join Requests", nil,
											 @"joinRequests", NO)];
		else
			[behaviour addObject:TGDisabledRow(@"Join Requests",
					@"An administrator with the invite right answers requests",
					@"joinRequests")];
		[sections addObject:TGSection(@"Permissions and Behaviour",
				@"Telegram applies the switch that moved or refuses it with a "
				@"reason. A row this account cannot change says who can.",
				behaviour)];
	}

	// ── tools ───────────────────────────────────────────────────────────
	// ── usernames ───────────────────────────────────────────────────────
	if (supergroup && self.settings && manager){
		NSMutableArray *names = [NSMutableArray array];
		if (self.canChangeInfo){
			[names addObject:TGInfoRow(@"Editable Username",
					self.editable.length ? [@"@" stringByAppendingString:self.editable]
										 : @"None", @"username")];
			if (self.editable.length)
				[names addObject:TGActionRow(@"Remove Username",
						@"Keeps every active name below", @"removeUsername", YES)];
			if (self.active.count > 1)
				[names addObject:TGActionRow(@"Disable All Usernames",
						@"Every name except the editable one",
						@"disableUsernames", YES)];
		} else {
			[names addObject:TGDisabledRow(@"Editable Username",
					self.editable.length ? [@"@" stringByAppendingString:self.editable]
										 : @"None", @"username")];
		}
		[sections addObject:TGSection(@"Usernames",
				@"The public names in front of this group's links. The editable "
				@"name is the one Telegram shows first.", names)];

		if (self.active.count){
			NSMutableArray *rows = [NSMutableArray array];
			for (NSString *name in self.active){
				NSMutableDictionary *row = TGUsernameRow(name, YES);
				row[@"enabled"] = @(self.canChangeInfo);
				[rows addObject:row];
			}
			[sections addObject:TGSection(@"Active usernames",
					self.active.count > 1
							? @"Tap Edit and drag a row to change the order of the names "
							  @"on the group's profile."
							: nil, rows)];
		}
		if (self.disabled.count){
			NSMutableArray *rows = [NSMutableArray array];
			for (NSString *name in self.disabled){
				NSMutableDictionary *row = TGUsernameRow(name, NO);
				row[@"enabled"] = @(self.canChangeInfo);
				[rows addObject:row];
			}
			[sections addObject:TGSection(@"Disabled usernames",
					@"Every name here can be switched back on. Telegram keeps "
					@"them on the group while they are off.", rows)];
		}
	}

	// ── tools ───────────────────────────────────────────────────────────
	if (manager){
		NSMutableArray *tools = [NSMutableArray array];
		[tools addObject:TGOpenActionRow(@"Chat Tools", @"Log, statistics, theme",
									 @"chatTools", NO)];
		if (channel)
			[tools addObject:TGActionRow(@"Direct Messages", @"Reader replies",
										 @"directMessages", NO)];
		[tools addObject:TGActionRow(@"Import Messages", @"From an export file",
									 @"import", NO)];
		if (supergroup)
			[tools addObject:TGActionRow(@"Send as", @"Who a post is from",
										 @"sendAs", NO)];
		if (self.canDeleteMessages)
			[tools addObject:TGActionRow(@"Clear by Date", @"Delete older messages",
										 @"clearByDate", YES)];
		else
			[tools addObject:TGDisabledRow(@"Clear by Date",
					@"An administrator with the delete-messages right clears",
					@"clearByDate")];
		if (supergroup){
			if (self.canChangeInfo){
				[tools addObject:TGActionRow(@"Group Stickers", nil,
											 @"groupStickers", NO)];
				[tools addObject:TGActionRow(@"Custom Emoji Stickers", nil,
											 @"customEmojiStickers", NO)];
			} else {
				[tools addObject:TGDisabledRow(@"Group Stickers",
						@"An administrator with the change-info right sets it",
						@"groupStickers")];
				[tools addObject:TGDisabledRow(@"Custom Emoji Stickers",
						@"An administrator with the change-info right sets it",
						@"customEmojiStickers")];
			}
		}
		[sections addObject:TGSection(@"Tools", nil, tools)];
	}

	// ── leaving and deleting ────────────────────────────────────────────
	if (self.myStatus.length){
		NSMutableArray *danger = [NSMutableArray array];
		NSString *what = channel ? @"Channel" : @"Group";
		NSMutableDictionary *dangerRow = self.isOwner
				? TGActionRow([NSString stringWithFormat:@"Delete %@", what],
							  nil, @"deleteChat", YES)
				: TGActionRow([NSString stringWithFormat:@"Leave %@", what],
							  nil, @"leave", YES);
		dangerRow[@"centered"] = @YES;
		[danger addObject:dangerRow];
		[sections addObject:TGSection(nil,
				(self.isOwner
						? @"Deleting removes this chat and every message in it for all members."
						: @"Leaving removes this chat from your list. The group stays for everyone else."),
				danger)];
	}

	self.sections = sections;
	[self updateEditButton];
	[self reloadTableDebounced];
}


@end
