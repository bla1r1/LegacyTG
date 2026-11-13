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





@implementation TGGroupSettingsViewController (TGGroupUsernames)

#pragma mark - usernames

- (void)editUsername {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Set Username"
					message:nil
				placeholder:@"username"
					   text:self.editable
					 action:@"Save"
					 inView:self.view
				 onSubmit:^(NSString *text){
		NSString *username = [text stringByReplacingOccurrencesOfString:@"@"
															withString:@""];
		[[TGGroupStore shared] setSupergroupUsername:username inChat:weakSelf.chatId
				completion:^(BOOL ok, NSString *error){
			if (!ok){
				[weakSelf showRefusal:error title:@"Set Username"];
				return;
			}
			[weakSelf load];
		}];
	}];
}

- (void)removeUsername {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"Deactivate Username"
						title:@"Deactivate Username"
					   action:@"Deactivate Username"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGGroupStore shared] setSupergroupUsername:@"" inChat:weakSelf.chatId
				completion:^(BOOL ok, NSString *error){
			if (!ok){
				[weakSelf showRefusal:error title:@"Deactivate Username"];
				return;
			}
			[weakSelf load];
		}];
	}];
}

- (void)disableAllUsernames {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"Deactivate Username"
						title:@"Deactivate Username"
					   action:@"Deactivate Username"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGGroupStore shared] disableAllSupergroupUsernamesInChat:weakSelf.chatId
				completion:^(BOOL ok, NSString *error){
			if (!ok){
				[weakSelf showRefusal:error title:@"Deactivate Username"];
				return;
			}
			[weakSelf load];
		}];
	}];
}


@end
