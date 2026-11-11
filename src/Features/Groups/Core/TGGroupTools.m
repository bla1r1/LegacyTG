#import "TGGroupSettingsViewController.h"
#import "TGLocalization.h"
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
#import "TGGroupLogic.h"
#import "TGChatViewController.h"
#import "TGGroupStore.h"
#import "TGStickerStore.h"
#import "TGProfileStore.h"
#import "TGMessageStore.h"



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
	[[TGGroupStore shared] availableMessageSendersInChat:self.chatId completion:^(NSArray *senders){
		TGGroupSettingsViewController *me = weakSelf;
		if (!senders.count){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Send Message As..." inView:me.view];
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *sender in senders){
			NSString *who = nil;
			NSString *userId = sender[@"user_id"];
			if (userId)
				who = [[TGMessageStore shared] nameForUserId:[userId longLongValue]];
			if (!who.length && sender[@"chat_id"])
				who = [[TGMessageStore shared] titleForChat:
						[sender[@"chat_id"] longLongValue]];
			NSString *line = who.length ? who : @"chat";
			NSString *current = [sender[@"is_current"] boolValue] ? @" — now" : @"";
			[rows addObject:[line stringByAppendingString:current]];
		}
		[TGAlertSheet showChoices:rows title:@"Send Message As..."
							message:nil
				 destructiveIndex:-1 inView:me.view
						 onChoice:^(NSInteger index){
			NSDictionary *sender = senders[(NSUInteger)index];
			[[TGGroupStore shared] setMessageSender:sender inChat:me.chatId
									 completion:^(BOOL ok){
				if (!ok)
					[TGAlertSheet showMessage:@"An error occurred."
										title:@"Send Message As..." inView:me.view];
			}];
		}];
	}];
}

/// The tile opens the direct-messages chat. The price is part of the
/// monoforum's own setup, not the first thing this row asks.
- (void)chooseDirectMessages {
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] chatProfile:self.chatId completion:^(NSDictionary *info){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		int64_t chatId = [info[@"directMessagesChatId"] longLongValue];
		if (chatId){
			TGChatViewController *chat = [[TGChatViewController alloc] init];
			chat.chatId = chatId;
			chat.chatTitle = me.chatTitle ?: @"Direct Messages";
			chat.hidesBottomBarWhenPushed = YES;
			[me.navigationController pushViewController:chat animated:YES];
			return;
		}
		if (![info[@"hasDirectMessages"] boolValue] &&
				![info[@"canManageDirectMessages"] boolValue]){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Direct Messages" inView:me.view];
			return;
		}
		[[TGGroupStore shared] setDirectMessagesEnabled:YES paidStars:0
											 inChat:me.chatId
										 completion:^(BOOL ok){
			TGGroupSettingsViewController *again = weakSelf;
			if (!again)
				return;
			if (!ok){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Direct Messages" inView:again.view];
				return;
			}
			[again chooseDirectMessages];
		}];
	}];
}

- (void)clearByDate {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"1 week",
								TGLocalizedPluralValue(@"%@ month", @"%@ months", @"1", 1),
								@"Today"]
						title:@"Clear History"
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		TGGroupSettingsViewController *me = weakSelf;
		NSInteger minDate = 0;
		NSInteger maxDate = 0;
		TGClearHistoryWindowForChoice(index, [NSDate date], &minDate, &maxDate);
		[TGAlertSheet showConfirm:@"This will **delete all messages** in this chat."
							title:@"Clear History"
						   action:@"Clear"
					  destructive:YES
						   inView:me.view
						onConfirm:^{
			[[TGGroupStore shared] deleteChatMessagesByDate:weakSelf.chatId
												 minDate:minDate
												 maxDate:maxDate
												  revoke:YES];
		}];
	}];
}

/// A group's sticker shelf and its custom emoji shelf are two settings on the
/// supergroup, chosen from the packs this account owns.
- (void)chooseStickerSet:(BOOL)customEmoji {
	__weak typeof(self) weakSelf = self;
	[[TGStickerStore shared] ownedStickerSetsWithCompletion:^(NSArray *sets){
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
					set[@"title"] ?: @"Stickers",
					(unsigned long)[set[@"count"] unsignedIntegerValue]]];
			[ids addObject:@(setId)];
		}
		NSString *title = customEmoji ? @"Custom Emoji" : @"Group Stickers";
		if (titles.count == 1){
			[TGAlertSheet showMessage:(customEmoji
					? @"No Stickers Found"
					: @"No Stickers Found")
								  title:title inView:me.view];
			return;
		}
		[TGAlertSheet showChoices:titles title:title
							message:nil
				 destructiveIndex:-1 inView:me.view
						 onChoice:^(NSInteger index){
			int64_t setId = [ids[(NSUInteger)index] longLongValue];
			void (^done)(BOOL) = ^(BOOL ok){
				[TGAlertSheet showMessage:(ok ? (customEmoji
												? @"Group emoji pack updated." : @"Done")
											  : @"An error occurred.")
								  title:title inView:me.view];
			};
			if (customEmoji)
				[[TGGroupStore shared] setSupergroupCustomEmojiStickerSet:setId
						inChat:me.chatId completion:done];
			else
				[[TGGroupStore shared] setSupergroupStickerSet:setId
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
					message:nil
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
		[TGAlertSheet showMessage:@"An error occurred."
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
		[TGAlertSheet showMessage:@"An error occurred."
							title:@"Import Messages" inView:self.view];
		return;
	}
	NSArray *lines = [contents componentsSeparatedByString:@"\n"];
	NSUInteger headCount = MIN((NSUInteger)100, lines.count);
	NSString *head = [[lines subarrayWithRange:NSMakeRange(0, headCount)]
			componentsJoinedByString:@"\n"];

	__weak typeof(self) weakSelf = self;
	[[TGGroupStore shared] messageFileTypeForHead:head completion:^(NSDictionary *fileType){
		(void)fileType;
		TGGroupSettingsViewController *me = weakSelf;
		[[TGGroupStore shared] importConfirmationTextForChat:chatId
											  completion:^(NSString *text){
			TGGroupSettingsViewController *again = weakSelf;
			NSString *title = @"Import Messages";
			NSString *body = text.length ? text : @"Import Messages";
			[TGAlertSheet showConfirm:body title:title action:@"Import"
						  destructive:YES inView:again.view
							onConfirm:^{
				[[TGGroupStore shared] importMessagesFromFile:path
											attachedFiles:@[]
												 intoChat:chatId
											   completion:^(BOOL ok){
					[TGSnackbar showInView:again.view
									  text:(ok ? @"Importing Chat"
											   : @"An error occurred.")
								   seconds:2 onCommit:nil];
				}];
			}];
			(void)me;
		}];
	}];
}


@end
