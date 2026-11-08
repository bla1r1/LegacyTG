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




@implementation TGGroupSettingsViewController (TGGroupTools)

#pragma mark - tools

- (void)openChatTools {
	TGChatToolsViewController *tools = [[TGChatToolsViewController alloc] init];
	tools.chatId = self.chatId;
	tools.chatTitle = self.chatTitle;
	tools.isGroup = YES;
	tools.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:tools animated:YES];
}

/// The switch Telegram offers channel owners: post under yourself, or as one
/// of the other accounts you own.
- (void)showSendAs {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] availableMessageSendersInChat:self.chatId completion:^(NSArray *senders){
		TGGroupSettingsViewController *me = weakSelf;
		if (!senders.count){
			[TGAlertSheet showMessage:@"Only a chat you may post in carries a "
									  @"Send-as switch."
								title:@"Send as" inView:me.view];
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *sender in senders){
			NSString *who = nil;
			NSString *userId = sender[@"user_id"];
			if (userId)
				who = [[TGClient shared] nameForUserId:[userId longLongValue]];
			if (!who.length && sender[@"chat_id"])
				who = [[TGClient shared] titleForChat:
						[sender[@"chat_id"] longLongValue]];
			NSString *line = who.length ? who : @"chat";
			NSString *current = [sender[@"is_current"] boolValue] ? @" — now" : @"";
			[rows addObject:[line stringByAppendingString:current]];
		}
		[TGAlertSheet showChoices:rows title:@"Send as"
							message:@"What you post here posts under that name."
				 destructiveIndex:-1 inView:me.view
						 onChoice:^(NSInteger index){
			NSDictionary *sender = senders[(NSUInteger)index];
			[[TGClient shared] setMessageSender:sender inChat:me.chatId
									 completion:^(BOOL ok){
				if (!ok)
					[TGAlertSheet showMessage:@"Telegram refused that."
										title:@"Send as" inView:me.view];
			}];
		}];
	}];
}

- (void)chooseDirectMessages {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Off", @"On, free", @"On, 1 star per message"]
						title:@"Channel Direct Messages"
			  destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		BOOL enabled = index > 0;
		NSInteger stars = index > 1 ? 1 : 0;
		[[TGClient shared] setDirectMessagesEnabled:enabled paidStars:stars
											 inChat:weakSelf.chatId
										 completion:^(BOOL ok){
			TGGroupSettingsViewController *me = weakSelf;
			[TGSnackbar showInView:me.view
							  text:(ok ? @"Direct messages updated"
									   : @"Only the channel's owner changes this")
						   seconds:2 onCommit:nil];
		}];
	}];
}

- (void)clearByDate {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Older than a week", @"Older than a month",
								@"Everything older than today"]
						title:@"Clear by Date"
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
		NSInteger days = index == 0 ? 7 : (index == 1 ? 30 : 1);
		[TGAlertSheet showConfirm:@"Everything sent before that is deleted for "
								  @"everyone, if this account may delete it here."
							title:@"Clear by Date"
						   action:@"Clear"
					  destructive:YES
						   inView:weakSelf.view
						onConfirm:^{
			[[TGClient shared] deleteChatMessagesByDate:weakSelf.chatId
												 minDate:0
												 maxDate:(NSInteger)(now - days * 86400)
												  revoke:YES];
		}];
	}];
}

/// A group's sticker shelf and its custom emoji shelf are two settings on the
/// supergroup, chosen from the packs this account owns.
- (void)chooseStickerSet:(BOOL)customEmoji {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] ownedStickerSetsWithCompletion:^(NSArray *sets){
		TGGroupSettingsViewController *me = weakSelf;
		NSMutableArray *titles = [NSMutableArray arrayWithObject:@"None"];
		NSMutableArray *ids = [NSMutableArray arrayWithObject:@(0)];
		for (NSDictionary *set in sets){
			NSString *type = set[@"stickerType"] ?: @"";
			BOOL isCustom = [type isEqualToString:@"stickerTypeCustomEmoji"];
			if (customEmoji != isCustom)
				continue;
			int64_t setId = [set[@"id"] longLongValue];
			if (!setId)
				continue;
			[titles addObject:[NSString stringWithFormat:@"%@  ·  %lu stickers",
					set[@"title"] ?: @"Pack",
					(unsigned long)[set[@"count"] unsignedIntegerValue]]];
			[ids addObject:@(setId)];
		}
		NSString *title = customEmoji ? @"Custom Emoji Stickers" : @"Group Stickers";
		if (titles.count == 1){
			[TGAlertSheet showMessage:(customEmoji
					? @"This account owns no custom emoji packs."
					: @"This account owns no sticker packs.")
								  title:title inView:me.view];
			return;
		}
		[TGAlertSheet showChoices:titles title:title
							message:(customEmoji
									? @"Used for the group's emoji status and reactions."
									: @"Shown above the composer for everyone here.")
				 destructiveIndex:-1 inView:me.view
						 onChoice:^(NSInteger index){
			int64_t setId = [ids[(NSUInteger)index] longLongValue];
			void (^done)(BOOL) = ^(BOOL ok){
				[TGAlertSheet showMessage:(ok ? @"The group's shelf is updated."
											  : @"Telegram refused the shelf; only "
												@"an administrator can change it.")
								  title:title inView:me.view];
			};
			if (customEmoji)
				[[TGClient shared] setSupergroupCustomEmojiStickerSet:setId
						inChat:me.chatId completion:done];
			else
				[[TGClient shared] setSupergroupStickerSet:setId
						inChat:me.chatId completion:done];
		}];
	}];
}

/// Reads an export file's opening lines so Telegram can name it, asks the
/// chat's own confirmation sentence, then imports it. Paths are relative to
/// Documents, which is the folder iTunes file sharing exposes.
- (void)importMessages {
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Import Messages"
					message:@"Name a history file in this app's Documents "
							@"folder. Its media files go in the same folder."
				placeholder:@"export.json"
					   text:nil
					 action:@"Next"
					 inView:self.view
				   onSubmit:^(NSString *name){
		[weakSelf beginImportFromPath:name inChat:chatId];
	}];
}

- (void)beginImportFromPath:(NSString *)name inChat:(int64_t)chatId {
	NSString *trimmed = [name stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!trimmed.length)
		return;
	NSString *path = trimmed;
	if (!path.isAbsolutePath){
		NSString *documents = [NSSearchPathForDirectoriesInDomains(
				NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
		path = [documents stringByAppendingPathComponent:trimmed];
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath:path]){
		[TGAlertSheet showMessage:[NSString stringWithFormat:
				@"No file at %@. Put the export in the app's Documents folder "
				@"first; iTunes file sharing shows it.", path]
							title:@"Import Messages" inView:self.view];
		return;
	}
	NSStringEncoding encoding = NSUTF8StringEncoding;
	NSError *error = nil;
	NSString *contents = [NSString stringWithContentsOfFile:path
			usedEncoding:&encoding error:&error];
	if (!contents)
		contents = [NSString stringWithContentsOfFile:path
				encoding:NSUTF8StringEncoding error:nil];
	if (!contents.length){
		[TGAlertSheet showMessage:@"The file is not text this app can read."
							title:@"Import Messages" inView:self.view];
		return;
	}
	NSArray *lines = [contents componentsSeparatedByString:@"\n"];
	NSUInteger headCount = MIN((NSUInteger)100, lines.count);
	NSString *head = [[lines subarrayWithRange:NSMakeRange(0, headCount)]
			componentsJoinedByString:@"\n"];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] messageFileTypeForHead:head completion:^(NSDictionary *fileType){
		TGGroupSettingsViewController *me = weakSelf;
		NSString *kind = fileType[@"kind"] ?: @"unknown";
		NSString *who = fileType[@"title"];
		[[TGClient shared] importConfirmationTextForChat:chatId
											  completion:^(NSString *text){
			TGGroupSettingsViewController *again = weakSelf;
			NSString *title = [kind isEqualToString:@"private"]
					? [NSString stringWithFormat:@"Import chat with %@",
							who.length ? who : @"them"]
					: ([kind isEqualToString:@"group"]
							? [NSString stringWithFormat:@"Import group %@",
									who.length ? who : @""]
							: @"Import messages");
			NSString *body = text.length ? text
					: @"This file looks like a history export. Importing adds "
					  @"its messages to this chat.";
			[TGAlertSheet showConfirm:body title:title action:@"Import"
						  destructive:YES inView:again.view
							onConfirm:^{
				[[TGClient shared] importMessagesFromFile:path
											attachedFiles:@[]
												 intoChat:chatId
											   completion:^(BOOL ok){
					[TGSnackbar showInView:again.view
									  text:(ok ? @"Import started"
											   : @"Telegram refused the import")
								   seconds:2 onCommit:nil];
				}];
			}];
			(void)me;
		}];
	}];
}


@end
