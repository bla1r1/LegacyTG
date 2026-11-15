#import "TGCustomEmojiStore.h"
#import "TGNameWithStatus.h"
#import "TGChatListViewControllerInternal.h"
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
#import "TGSettingsViewController.h"


// Height of the folder pill strip above the chat list (official-style tabs).




@implementation TGChatListViewController (TGChatListSelection)

#pragma mark - selection
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.editingChats){
		// The table draws the left selection control; a second blue tick on
		// the right was ours, not official.
		[self refreshEditToolbar];
		[self refreshListTitleView];
		return;
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	NSArray *header = [self headerRows];
	if (indexPath.row < (NSInteger)header.count){
		if ([header[indexPath.row] isEqualToString:@"notice"])
			[self openNotice];
		else if ([header[indexPath.row] isEqualToString:@"archive"])
			[self openArchive];
		else
			[self openSavedMessages];
		return;
	}

	NSDictionary *c = [self visibleChats][indexPath.row - header.count];
	NSLog(@"open chat: group=%@ forum=%@", c[@"isGroup"], c[@"isForum"] ?: @"(absent)");
	double pushStart = TGPerfNow();
	[self openChatInfo:c];
	// An open that feels instant lands its screen inside two frames; over
	// that the tap reads as nothing happening.
	TGPerfReport("chat open", "push", pushStart, 66.0);
}

/// The notice's tap, as official: the password setup, or the Premium
/// subscription page TDLib names.
- (void)openNotice {
	NSDictionary *notice = TGChatListNotice([TGChatListStore shared].suggestedActions);
	if ([notice[@"kind"] isEqualToString:@"setupPassword"]){
		TGSettingsViewController *settings = [[TGSettingsViewController alloc] init];
		settings.page = TGSettingsPagePrivacy;
		settings.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:settings animated:YES];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{ [settings showTwoStepState]; });
	} else if ([notice[@"url"] length]){
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:notice[@"url"]]];
	}
}

/// The one place a chat dictionary becomes a screen: the forum check is what
/// decides a topics list from a plain chat, and both push the same way.
- (void)openChatInfo:(NSDictionary *)c {
	if ([c[@"isForum"] boolValue]){
		TGTopicsViewController *topics = [[TGTopicsViewController alloc] init];
		topics.chatId = [c[@"id"] longLongValue];
		topics.chatTitle = c[@"title"];
		topics.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:topics animated:YES];
		return;
	}

	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = [c[@"id"] longLongValue];
	vc.chatTitle = c[@"title"];
	vc.isGroup = [c[@"isGroup"] boolValue];
	vc.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:vc animated:YES];
}

/// The system's caption is grey on grey over a dark list, which is what
/// this screen had: every other list styles its own.


@end
