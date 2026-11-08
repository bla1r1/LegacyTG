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




@implementation TGGroupSettingsViewController (TGGroupPermissions)

#pragma mark - permissions and behaviour

- (void)choosePermissions {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"All", @"Messages", @"Read-Only Mode"]
						title:@"Permissions"
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		NSString *preset = index == 0 ? @"all" : (index == 1 ? @"text" : @"read");
		[[TGClient shared] setChatPermissionsFromPreset:preset
												 inChat:weakSelf.chatId
											  completion:^(BOOL ok){
			TGGroupSettingsViewController *me = weakSelf;
			if (!ok){
				[TGAlertSheet showMessage:@"An error occurred."
										  title:@"Permissions" inView:me.view];
				return;
			}
			[me load];
		}];
	}];
}

- (void)chooseSlowMode {
	NSArray *titles = @[@"Off",
						TGLocalizedPluralValue(@"%@ second", @"%@ seconds", @"5", 5),
						TGLocalizedPluralValue(@"%@ second", @"%@ seconds", @"10", 10),
						TGLocalizedPluralValue(@"%@ second", @"%@ seconds", @"30", 30),
						TGLocalizedPluralValue(@"%@ minute", @"%@ minutes", @"1", 1),
						TGLocalizedPluralValue(@"%@ minute", @"%@ minutes", @"5", 5),
						TGLocalizedPluralValue(@"%@ minute", @"%@ minutes", @"15", 15),
						TGLocalizedPluralValue(@"%@ hour", @"%@ hours", @"1", 1)];
	static const NSInteger seconds[] = {0, 5, 10, 30, 60, 300, 900, 3600};
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles title:@"Slow Mode" destructiveIndex:-1
					   inView:self.view onChoice:^(NSInteger index){
		[[TGClient shared] setSlowModeDelayForChat:weakSelf.chatId
										   seconds:seconds[index]
										completion:^(BOOL ok){
			TGGroupSettingsViewController *me = weakSelf;
			if (!ok){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Slow Mode" inView:me.view];
				return;
			}
			NSMutableDictionary *changed = [me.groupInfo mutableCopy];
			changed[@"slow_mode_delay"] = @(seconds[index]);
			me.groupInfo = changed;
			[me rebuild];
		}];
	}];
}

- (void)confirmBroadcast {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"Broadcast groups can have over %@ members, but only admins can send messages in them."
						title:@"Convert to Broadcast Group"
					   action:@"Convert"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGClient shared] convertSupergroupToBroadcastInChat:weakSelf.chatId
				completion:^(BOOL ok, NSString *error){
			TGGroupSettingsViewController *me = weakSelf;
			if (!ok){
				[me showRefusal:error title:@"Broadcast Group"];
				return;
			}
			NSMutableDictionary *changed = [me.settings mutableCopy];
			changed[@"isBroadcast"] = @YES;
			me.settings = changed;
			[me rebuild];
		}];
	}];
}

- (void)showJoinRequests {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] joinRequestsForChat:self.chatId completion:^(NSArray *requests){
		TGGroupSettingsViewController *me = weakSelf;
		if (!requests.count){
			[TGAlertSheet showMessage:@"There are no pending join requests."
								title:@"Join Requests" inView:me.view];
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *request in requests)
			[rows addObject:request[@"name"] ?: @"?"];
		[rows addObject:@"Approve"];
		[rows addObject:@"Decline All"];

		[TGAlertSheet showChoices:rows title:@"Join Requests"
				 destructiveIndex:(NSInteger)rows.count - 1 inView:me.view
						 onChoice:^(NSInteger index){
			if (index == (NSInteger)requests.count ||
				index == (NSInteger)requests.count + 1){
				BOOL approve = index == (NSInteger)requests.count;
				[[TGClient shared] processAllJoinRequests:me.chatId link:@""
						approve:approve completion:^(BOOL ok){
					[TGAlertSheet showMessage:(ok ? @"Done"
												   : @"An error occurred.")
										title:@"Join Requests" inView:me.view];
					[me showJoinRequests];
				}];
				return;
			}
			int64_t userId = [requests[index][@"id"] longLongValue];
			NSString *name = requests[index][@"name"] ?: @"them";
			[TGAlertSheet showChoices:@[@"Accept", @"Decline"] title:name
					 destructiveIndex:1 inView:me.view
							 onChoice:^(NSInteger pick){
				[[TGClient shared] processJoinRequest:userId inChat:me.chatId
											   approve:(pick == 0)];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
						(int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					[me showJoinRequests];
				});
			}];
		}];
	}];
}

/// One sheet, everything a welcome-message family does: add, edit, delete
/// one or all. Text is what this client composes; media stays TDLib-side.
- (void)showWelcomeMessages {
	__weak typeof(self) weakSelf = self;
	int64_t chatId = self.chatId;
	NSString *groupTitle = self.chatTitle ?: @"Manage Welcome Messages";
	[[TGClient shared] welcomeMessagesOfChat:chatId completion:^(NSArray *welcomes){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;

		NSMutableArray *rows = [NSMutableArray array];
		NSMutableArray *ids = [NSMutableArray array];
		for (NSDictionary *welcome in welcomes){
			NSString *text = welcome[@"text"];
			NSString *preview = text.length
					? [text substringToIndex:MIN((NSUInteger)30, text.length)]
					: @"No text";
			[rows addObject:[NSString stringWithFormat:@"%@ — %@",
					TGLocalized(@"Edit"), preview]];
			[ids addObject:welcome[@"id"]];
		}
		[rows addObject:@"Add"];
		if (welcomes.count)
			[rows addObject:@"Delete"];
		[rows addObject:@"Delete All"];

		NSInteger destructive = (NSInteger)[rows indexOfObject:@"Delete All"];
		[TGAlertSheet showChoices:rows title:groupTitle
							message:nil
				 destructiveIndex:destructive inView:me.view
						 onChoice:^(NSInteger index){
			NSString *what = rows[(NSUInteger)index];
			if ([what isEqualToString:@"Delete All"]){
				[TGAlertSheet showConfirm:@"Delete All"
									title:@"Manage Welcome Messages"
								   action:@"Delete All"
							  destructive:YES
								   inView:me.view
								onConfirm:^{
					[[TGClient shared] clearAllWelcomeMessagesInChat:chatId];
					[me showWelcomeMessages];
				}];
				return;
			}
			if ([what isEqualToString:@"Delete"]){
				NSMutableArray *previews = [NSMutableArray array];
				for (NSUInteger i = 0; i < welcomes.count; i++){
					NSString *text = welcomes[i][@"text"];
					NSString *preview = text.length
							? [text substringToIndex:MIN((NSUInteger)30, text.length)]
							: @"No text";
					[previews addObject:[NSString stringWithFormat:@"%lu. %@",
										 (unsigned long)(i + 1), preview]];
				}
				[TGAlertSheet showChoices:previews title:@"Manage Welcome Messages"
								   message:nil
						 destructiveIndex:0 inView:me.view
								 onChoice:^(NSInteger which){
					NSString *wid = [ids[(NSUInteger)which] isKindOfClass:NSString.class]
							? ids[(NSUInteger)which]
							: [ids[(NSUInteger)which] stringValue];
					[[TGClient shared] deleteWelcomeMessage:[wid longLongValue]
													 inChat:chatId];
					[me showWelcomeMessages];
				}];
				return;
			}
			if ([what isEqualToString:@"Add"]){
				[TGAlertSheet showInput:@"Create a Welcome Message" message:nil
							placeholder:@"Welcome Message" text:nil
								 action:@"Add" inView:me.view
							 onSubmit:^(NSString *typed){
					[[TGClient shared] addWelcomeMessageToChat:chatId text:typed
													completion:^(BOOL ok){
						if (!ok)
							[TGAlertSheet showMessage:@"An error occurred."
												title:@"Welcome" inView:me.view];
					}];
				}];
				return;
			}
			if (index >= (NSInteger)ids.count)
				return;
			NSString *old = welcomes[index][@"text"];
			NSString *welcomeId = [ids[index] isKindOfClass:NSString.class]
					? ids[index] : [ids[index] stringValue];
			[TGAlertSheet showInput:@"Welcome Message" message:nil
						placeholder:old ?: @"Welcome Message" text:old
							 action:@"Save" inView:me.view
						 onSubmit:^(NSString *typed){
				[[TGClient shared] setWelcomeMessage:[welcomeId longLongValue]
											  inChat:chatId text:typed
										  completion:^(BOOL ok){
					if (!ok)
						[TGAlertSheet showMessage:@"An error occurred."
											title:@"Welcome" inView:me.view];
				}];
			}];
		}];
	}];
}


@end
