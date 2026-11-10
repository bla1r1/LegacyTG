#import "TGProfileViewController+Tier2.h"
#import "TGProfileViewControllerInternal.h"
#import "TGDMTopicsViewController.h"
#import "TGDiceViewController.h"
#import "TGEmojiStatusViewController.h"
#import "TGProfileAudioViewController.h"

@implementation TGProfileViewController (Tier2)

- (NSArray *)tier2MoreItems {
	NSMutableArray *items = [NSMutableArray array];
	if (self.userId){
		// Emoji Status and Music have their own entries: the profile header
		// and the Music pane, so the More menu does not repeat them.
	} else {
		if (self.canManage || self.directMessagesChatId != 0 || self.hasDirectMessages || self.canManageDirectMessages) {
			[items addObject:@{@"title" : @"Direct Messages", @"icon" : @"chat"}];
		}
	}
	return items;
}

- (BOOL)runTier2Action:(NSString *)title {
	if ([title isEqualToString:@"Emoji Status"] ||
			[title isEqualToString:@"Set Emoji Status"]){
		BOOL own = self.userId == [[TGProfileStore shared].me[@"id"] longLongValue];
		TGEmojiStatusViewController *status =
				[[TGEmojiStatusViewController alloc] init];
		status.target = own ? TGEmojiStatusTargetSelf : TGEmojiStatusTargetUser;
		status.userId = self.userId;
		status.subjectTitle = self.name.length ? self.name : @"Emoji Status";
		status.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:status animated:YES];
		return YES;
	}
	if ([title isEqualToString:@"Profile Music"] ||
		[title isEqualToString:@"Music"]){
		TGProfileAudioViewController *audio =
				[[TGProfileAudioViewController alloc] init];
		audio.userId = self.userId;
		audio.subjectTitle = self.name.length ? self.name : @"Profile Music";
		audio.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:audio animated:YES];
		return YES;
	}
	if ([title isEqualToString:@"Direct Messages"]){
		[self openDirectMessages];
		return YES;
	}
	if ([title isEqualToString:@"Stake"]){
		TGDiceViewController *dice = [[TGDiceViewController alloc] init];
		dice.chatId = self.chatId;
		dice.chatTitle = self.name;
		dice.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:dice animated:YES];
		return YES;
	}
	return NO;
}

@end
