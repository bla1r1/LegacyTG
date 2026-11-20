#import "TGCustomEmojiStore.h"
#import "TGNameWithStatus.h"
#import "TGChatListViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGPerf.h"
#import "TGStatusText.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGDateFormat.h"
#import "TGOptions.h"
#import "TGStoryViewerViewController.h"
#import "TGStoryComposerViewController.h"
#import "TGProfileViewController.h"
#import "TGPasscode.h"
#import "TGPasscodeViewController.h"
#import "TGChatListRowGeometry.h"
#import "TGiPadSplitViewController.h"
#import "TGiPadSimulator.h"


// Height of the folder pill strip above the chat list (official-style tabs).




@implementation TGChatListViewController (TGChatListCompose)

#pragma mark - compose and links
- (void)openSavedMessages {
	int64_t chatId = [[TGChatListStore shared] savedMessagesChatId];
	if (!chatId)
		return;
#if TG_DEV
	if ([[TGiPadSimulator shared] isActive]) {
		[[TGiPadSplitViewController shared] showChatWithId:chatId
		                                             title:TGLocalized(@"Saved Messages")
		                                           isGroup:NO
		                                           isForum:NO];
		return;
	}
#endif
	if (TGIsPad()) {
		[[TGiPadSplitViewController shared] showChatWithId:chatId
		                                             title:TGLocalized(@"Saved Messages")
		                                           isGroup:NO
		                                           isForum:NO];
		return;
	}
	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = chatId;
	vc.chatTitle = TGLocalized(@"Saved Messages");
	vc.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:vc animated:YES];
}

- (void)composeTapped {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"New Message", @"New Group", @"New Channel"]
						title:nil
			 destructiveIndex:-1
					   inView:self.navigationController.view ?: self.view
					 onChoice:^(NSInteger index){
		TGChatListViewController *me = weakSelf;
		if (index == 2){
			// A channel is a supergroup with one voice: TDLib names both with
			// one request, and the is_channel flag is the whole difference.
			[TGAlertSheet showInput:@"New Channel"
							message:nil
						placeholder:@"Channel Name"
							   text:nil
							 action:@"Create"
							 inView:me.view
						 onSubmit:^(NSString *title){
				[[TGChatListStore shared] createSupergroupNamed:title
											description:@""
											  isChannel:YES
											 completion:^(int64_t chatId){
					if (!chatId)
						return;
					TGChatViewController *vc = [[TGChatViewController alloc] init];
					vc.chatId = chatId;
					vc.chatTitle = title;
					vc.hidesBottomBarWhenPushed = YES;
					[me.navigationController pushViewController:vc animated:YES];
				}];
			}];
			return;
		}
		if (index != 2){
			TGContactsViewController *contacts = [[TGContactsViewController alloc] init];
			if (index == 1)
				contacts.picksGroupMembers = YES;
			else
				contacts.title = @"New Message";
			[me.navigationController pushViewController:contacts animated:YES];
			return;
		}
	}];
}

/// A pill switch arms this before asking the folder for its chats; the answer
/// replaces the whole table, and that one swap fades. Spending the flag here
/// is what keeps the periodic reloads from crossfading the list too.

@end
