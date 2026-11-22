#import "TGGroupSettingsViewController.h"
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
#import "TGMemberListViewController.h"
#import "TGGroupStore.h"
#import "TGPresent.h"



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





@implementation TGGroupSettingsViewController (TGGroupMembers)

#pragma mark - members

- (void)addMembers {
	TGContactsViewController *contacts = [[TGContactsViewController alloc] init];
	contacts.addingToChatId = self.chatId;
	contacts.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:contacts animated:YES];
}

/// The Members row in Group Info: the official screen's member pane, not a
/// sheet of names. The pane is the same list Group Settings already loaded,
/// so opening it costs no request and a name opens the person's profile.
- (void)showMembersList {
	TGMemberListViewController *list = [[TGMemberListViewController alloc] init];
	list.chatId = self.chatId;
	list.members = self.members;
	// The people section this row lives beside is group-only; a channel's
	// subscribers are added through invite links, not this list.
	list.canAddMembers = self.canInvite && !self.isChannelChat;
	list.listTitle = self.isChannelChat ? @"Subscribers" : @"Members";
	list.hidesBottomBarWhenPushed = YES;
	[TGPresent openController:list from:self];
}

/// getChatMembers is a page, not a search; searchChatMembers answers the
/// query server-side, which is the only way a group of a few thousand is
/// usable from a phone at all.
- (void)findMember {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Search Members" message:nil
				placeholder:@"Username" text:nil action:@"Search"
					 inView:self.view onSubmit:^(NSString *query){
		[[TGGroupStore shared] searchMembersInChat:weakSelf.chatId query:query
									completion:^(NSArray *members){
			TGGroupSettingsViewController *me = weakSelf;
			if (!members.count){
				[TGAlertSheet showMessage:@"No Results"
									  title:@"Search Members" inView:me.view];
				return;
			}
			NSMutableArray *names = [NSMutableArray array];
			for (NSDictionary *member in members)
				[names addObject:[member[@"name"] length]
						? member[@"name"] : @"Member"];
			[TGPresent showList:names title:@"Search Members" destructiveIndex:-1
			from:me onPick:^(NSInteger index){
				NSDictionary *member = members[(NSUInteger)index];
				int64_t userId = [member[@"id"] longLongValue];
				if (!userId)
					return;
				TGProfileViewController *profile = [[TGProfileViewController alloc]
						initWithChatId:userId
								userId:userId
								 title:[member[@"name"] length] ? member[@"name"] : @""];
				profile.hidesBottomBarWhenPushed = YES;
				[me.navigationController pushViewController:profile animated:YES];
			}];
		}];
	}];
}


@end
