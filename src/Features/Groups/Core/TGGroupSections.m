#import "TGGroupSettingsViewController.h"
#import "TGLocalization.h"
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
		return @"Read-Only Mode";
	return media ? @"All" : @"Messages";
}

- (NSString *)slowModeDetail {
	NSInteger seconds = [self.groupInfo[@"slow_mode_delay"] integerValue];
	if (seconds <= 0)
		return @"Off";
	if (seconds < 60)
		return TGLocalizedFormat(@"%@ seconds",
				[NSString stringWithFormat:@"%ld", (long)seconds]);
	if (seconds < 3600)
		return TGLocalizedFormat(@"%@ min", @(seconds / 60));
	return TGLocalizedFormat(@"%@ h", @(seconds / 3600));
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
	self.tableView.backgroundView = nil;
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
	NSString *photoTitle = channel ? @"Set Channel Photo" : @"Set Group Photo";
	NSString *nameTitle = channel ? @"Channel Name" : @"Group Name";
	NSString *noInfoRight = nil;
	if (manager && !self.canChangeInfo){
		[info addObject:TGDisabledRow(photoTitle, noInfoRight, @"photo")];
		[info addObject:TGDisabledRow(nameTitle, nameDetail, @"name")];
	} else {
		[info addObject:TGOpenRow(photoTitle,
				manager ? photoDetail : (self.hasPhoto ? @"Set" : @"None"),
				manager ? @"photo" : nil)];
		[info addObject:TGOpenRow(nameTitle, nameDetail, manager ? @"name" : nil)];
	}
	if (supergroup){
		if (manager && !self.canChangeInfo){
			[info addObject:TGDisabledRow(@"Description",
					self.descriptionText.length ? self.descriptionText
							: @"None", @"description")];
		} else {
			[info addObject:TGOpenRow(@"Description",
					self.descriptionText.length ? self.descriptionText
							: (manager ? @"Description" : @"None"),
					manager ? @"description" : nil)];
		}
		if (manager && !self.canInvite){
			[info addObject:TGDisabledRow(@"Invite Link",
					self.inviteLink.length ? self.inviteLink
							: @"Manage",
					@"invite")];
		} else if (manager || self.inviteLink.length){
			[info addObject:TGOpenRow(@"Invite Link",
					self.inviteLink.length ? self.inviteLink
							: (manager ? @"Manage" : @"None"),
					manager ? @"invite" : nil)];
		}
		// Telegram names this row Group Type / Channel Type and sits it
		// above the link. Private here means no active username.
		BOOL isPublic = self.editable.length > 0 || self.active.count > 0;
		NSString *typeTitle = channel ? @"Channel Type" : @"Group Type";
		// The official row names the visibility (Group.Setup.TypePublic).
		// By key: the English "Public" is shared and maps to the pack's
		// "sociality" word.
		NSString *typeKey = [NSString stringWithFormat:@"%@.Setup.Type%@",
				channel ? @"Channel" : @"Group", isPublic ? @"Public" : @"Private"];
		NSString *typeDetail = TGLocalizedKey(typeKey, isPublic ? @"Public" : @"Private");
		if (editInfo)
			[info addObject:TGOpenRow(typeTitle, typeDetail, @"groupType")];
		else if (manager)
			[info addObject:TGDisabledRow(typeTitle, typeDetail, @"groupType")];
		else
			[info addObject:TGInfoRow(typeTitle, typeDetail, nil)];
	}
	if (basic)
		[info addObject:TGInfoRow(@"Group Type", @"Private", nil)];
	if (self.memberCount > 0)
		[info addObject:TGOpenRow(channel ? @"Subscribers" : @"Members",
				[NSString stringWithFormat:@"%ld", (long)self.memberCount],
				@"members")];
	if (basic && manager)
		[info addObject:TGActionRow(@"Upgrade to Supergroup",
				nil, @"upgrade", NO)];
	[sections addObject:TGSection(channel ? @"Channel Info" : @"Group Info",
			nil,
			info)];

	// ── people ──────────────────────────────────────────────────────────
	if (!channel){
		NSMutableArray *people = [NSMutableArray array];
		if (manager && !self.canInvite)
			[people addObject:TGDisabledRow(@"Add Members",
					nil,
					@"addMembers")];
		else if (self.canInvite)
			[people addObject:TGOpenActionRow(@"Add Members", nil, @"addMembers", NO)];
		[people addObject:TGOpenActionRow(@"Search Members", nil,
										 @"findMember", NO)];
		NSString *header = self.memberCount > 0
				? TGLocalizedPluralValue(@"%@ member", @"%@ members", [NSString stringWithFormat:@"%ld", (long)self.memberCount], (NSInteger)self.memberCount)
				: @"Members";
		[sections addObject:TGSection(header,
				nil, people)];
	}

	// ── calls ───────────────────────────────────────────────────────────
	NSMutableArray *calls = [NSMutableArray array];
	[calls addObject:TGOpenActionRow(@"Group Call",
			nil, @"groupCall", NO)];
	[calls addObject:TGOpenActionRow(@"Video Chat",
			nil, @"videoChat", NO)];
	[sections addObject:TGSection(@"Calls",
			nil, calls)];

	// ── what the group does ─────────────────────────────────────────────
	if (supergroup && manager){
		BOOL canBehaviour = self.canChangeInfo;
		NSMutableArray *behaviour = [NSMutableArray array];
		if (self.canRestrict)
			[behaviour addObject:TGOpenActionRow(@"Permissions",
					[self permissionsDetail], @"permissions", NO)];
		else
			[behaviour addObject:TGDisabledRow(@"Permissions",
					[self permissionsDetail], @"permissions")];
		if (canBehaviour)
			[behaviour addObject:TGOpenActionRow(@"Slow Mode", [self slowModeDetail],
											 @"slow", NO)];
		else
			[behaviour addObject:TGDisabledRow(@"Slow Mode", [self slowModeDetail],
											   @"slow")];
		[behaviour addObject:TGSwitchRow(@"Sign Messages", nil, @"sign",
										 self.signMessages, canBehaviour)];
		[behaviour addObject:TGSwitchRow(@"Send Messages", nil, @"join",
										 self.joinToSend, canBehaviour)];
		[behaviour addObject:TGSwitchRow(@"History", nil, @"history",
										 self.allHistory, canBehaviour)];
		[behaviour addObject:TGSwitchRow(@"Aggressive Anti-Spam",
				nil,
				@"antispam", self.aggressiveAntiSpam, self.canToggleAntiSpam)];
		[behaviour addObject:TGOpenActionRow(@"Report False Positive",
				nil, @"antispamFalsePositive",
				NO)];
		[behaviour addObject:TGSwitchRow(@"Approve New Members",
				nil,
				@"joinRequests",
				[self.settings[@"joinByRequest"] boolValue], canBehaviour)];
		BOOL canHide = [self.settings[@"canHideMembers"] boolValue];
		[behaviour addObject:TGSwitchRow(@"Hide Members",
				nil,
				@"hidden", [self.settings[@"hiddenMembers"] boolValue],
				canBehaviour && canHide)];
		if (!channel){
			[behaviour addObject:TGSwitchRow(@"Topics",
					self.settings[@"isForum"] ? @"On" : @"Off",
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
				[behaviour addObject:TGActionRow(@"Manage Welcome Messages",
						nil, @"welcome", NO)];
			else
				[behaviour addObject:TGDisabledRow(@"Manage Welcome Messages",
						nil, @"welcome")];
		}
		[behaviour addObject:TGSwitchRow(@"Auto-Translate Messages",
				self.settings[@"automaticTranslation"] ? @"On" : @"Off",
				@"translation",
				[self.settings[@"automaticTranslation"] boolValue], canBehaviour)];
		// No requests means no row; a count on the right is the badge.
		if (self.joinRequestCount > 0){
			NSString *count = [NSString stringWithFormat:@"%ld",
					(long)self.joinRequestCount];
			if (self.canInvite)
				[behaviour addObject:TGOpenActionRow(@"Join Requests", count,
												 @"joinRequests", NO)];
			else
				[behaviour addObject:TGDisabledRow(@"Join Requests",
						count, @"joinRequests")];
		}
		[sections addObject:TGSection(@"Permissions",
				nil,
				behaviour)];
	}

	// ── tools ───────────────────────────────────────────────────────────
	// ── usernames ───────────────────────────────────────────────────────
	if (supergroup && self.settings && manager){
		NSMutableArray *names = [NSMutableArray array];
		if (self.canChangeInfo){
			[names addObject:TGOpenRow(@"Username",
					self.editable.length ? [@"@" stringByAppendingString:self.editable]
										 : @"None", @"username")];
			if (self.editable.length)
				[names addObject:TGActionRow(@"Deactivate Username",
						nil, @"removeUsername", YES)];
		} else {
			[names addObject:TGDisabledRow(@"Username",
					self.editable.length ? [@"@" stringByAppendingString:self.editable]
										 : @"None", @"username")];
		}
		[sections addObject:TGSection(@"Username",
				nil, names)];

		if (self.active.count){
			NSMutableArray *rows = [NSMutableArray array];
			for (NSString *name in self.active){
				NSMutableDictionary *row = TGUsernameRow(name, YES);
				row[@"enabled"] = @(self.canChangeInfo);
				[rows addObject:row];
			}
			[sections addObject:TGSection(@"USERNAME ORDER",
					nil, rows)];
		}
		if (self.disabled.count){
			NSMutableArray *rows = [NSMutableArray array];
			for (NSString *name in self.disabled){
				NSMutableDictionary *row = TGUsernameRow(name, NO);
				row[@"enabled"] = @(self.canChangeInfo);
				[rows addObject:row];
			}
			[sections addObject:TGSection(@"Disabled",
					nil, rows)];
		}
	}

	// ── tools ───────────────────────────────────────────────────────────
	if (manager){
		NSMutableArray *tools = [NSMutableArray array];
		[tools addObject:TGOpenActionRow(@"Manage", nil,
									 @"chatTools", NO)];
		if (channel)
			[tools addObject:TGOpenActionRow(@"Direct Messages", nil,
										 @"directMessages", NO)];
		[tools addObject:TGOpenActionRow(@"Import Messages", nil,
									 @"import", NO)];
		if (supergroup)
			[tools addObject:TGOpenActionRow(@"Send Message As...", nil,
										 @"sendAs", NO)];
		if (self.canDeleteMessages)
			[tools addObject:TGOpenActionRow(@"Clear History", nil,
										 @"clearByDate", YES)];
		else
			[tools addObject:TGDisabledRow(@"Clear History",
					nil,
					@"clearByDate")];
		if (supergroup){
			if (self.canChangeInfo){
				[tools addObject:TGOpenActionRow(@"Group Stickers", nil,
											 @"groupStickers", NO)];
				[tools addObject:TGOpenActionRow(@"Custom Emoji", nil,
											 @"customEmojiStickers", NO)];
			} else {
				[tools addObject:TGDisabledRow(@"Group Stickers",
						nil,
						@"groupStickers")];
				[tools addObject:TGDisabledRow(@"Custom Emoji",
						nil,
						@"customEmojiStickers")];
			}
		}
		[sections addObject:TGSection(@"Manage", nil, tools)];
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
		[danger addObject:dangerRow];
		[sections addObject:TGSection(nil,
				nil,
				danger)];
	}

	self.sections = sections;
	[self updateEditButton];
	[self reloadTableDebounced];
}


@end
