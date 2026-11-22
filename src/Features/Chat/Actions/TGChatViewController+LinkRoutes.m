//
// TGChatViewController+LinkRoutes.m - in-app links opened where official
// opens them (TelegramUI OpenResolvedUrl.swift), from TDLib's
// InternalLinkType through TGInternalLinkRoute.
//
#import "TGChatViewControllerInternal.h"
#import "TGMessageStore.h"
#import "TGSnackbar.h"
#import "TGInstantViewController.h"
#import "TGStoryViewerViewController.h"
#import "TGStoryStore.h"
#import "TGSettingsViewController.h"
#import "TGSessionsViewController.h"
#import "TGEditProfileViewController.h"
#import "TGPrivacyRuleViewController.h"
#import "TGStorageViewController.h"
#import "TGSettingsViewControllerInternal.h"
#import "TGContactsViewController.h"
#import "TGNewContactViewController.h"
#import "TGProfileViewController.h"
#import "TGPresent.h"

@implementation TGChatViewController (LinkRoutes)

- (void)pushLinkedScreen:(UIViewController *)screen {
	screen.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:screen animated:YES];
}

- (void)showLinkError {
	[TGSnackbar showInView:self.navigationController.view ?: self.view
					  text:@"An error occurred." seconds:2 onCommit:nil];
}

- (BOOL)openInternalLinkRoute:(NSDictionary *)route {
	NSString *kind = [route[@"route"] isKindOfClass:NSString.class] ? route[@"route"] : nil;
	if (!kind)
		return NO;
	if ([kind isEqualToString:@"instantView"]) {
		[self openLinkedInstantView:route[@"url"] fallback:route[@"fallback"]];
		return YES;
	}
	if ([kind isEqualToString:@"story"]) {
		[self openLinkedStoryOf:route[@"username"] storyId:[route[@"storyId"] intValue]];
		return YES;
	}
	if ([kind isEqualToString:@"directMessages"]) {
		[self openDirectMessagesOf:route[@"username"]];
		return YES;
	}
	if ([kind isEqualToString:@"settings"]) {
		[self openLinkedSettingsPage:route[@"page"] rule:route[@"rule"]];
		return YES;
	}
	if ([kind isEqualToString:@"tab"]) {
		[self openLinkedTab:route[@"name"] section:route[@"section"]];
		return YES;
	}
	return NO;
}

/// The reader for the page; a page Telegram has no reader for opens at the
/// link's fallback address instead (internalLinkTypeInstantView.fallback_url).
- (void)openLinkedInstantView:(NSString *)url fallback:(NSString *)fallback {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] instantViewForURL:url onlyLocal:NO completion:^(NSDictionary *view){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		NSArray *blocks = view[@"blocks"];
		if ([blocks isKindOfClass:NSArray.class] && blocks.count) {
			[me openInstantViewForLink:url view:view];
			return;
		}
		[me presentExternalLink:[fallback length] ? fallback : url];
	}];
}

/// One story, or with no id the poster's current ones (a live story link).
- (void)openLinkedStoryOf:(NSString *)username storyId:(int32_t)storyId {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] chatWithUsername:username completion:^(int64_t chatId, NSString *title){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		if (!chatId) {
			[me showLinkError];
			return;
		}
		NSString *name = title.length ? title : username;
		if (storyId) {
			[me pushLinkedScreen:[[TGStoryViewerViewController alloc] initWithChatId:chatId
					title:name stories:@[@(storyId)] startIndex:0 canManage:NO]];
			return;
		}
		[[TGStoryStore shared] activeStoryRowForChat:chatId completion:^(NSDictionary *row){
			TGChatViewController *again = weakSelf;
			NSArray *stories = [row[@"stories"] isKindOfClass:NSArray.class] ? row[@"stories"] : nil;
			if (!again)
				return;
			if (!stories.count) {
				[again showLinkError];
				return;
			}
			[again pushLinkedScreen:[[TGStoryViewerViewController alloc] initWithChatId:chatId
					title:name stories:stories startIndex:0 canManage:NO]];
		}];
	}];
}

/// A channel's direct messages: the channel resolves, its full record names
/// the messages chat, and that chat opens.
- (void)openDirectMessagesOf:(NSString *)username {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] chatWithUsername:username completion:^(int64_t chatId, NSString *title){
		if (!chatId) {
			[weakSelf showLinkError];
			return;
		}
		[[TGMessageStore shared] chatProfile:chatId completion:^(NSDictionary *info){
			TGChatViewController *me = weakSelf;
			int64_t dmId = [info[@"directMessagesChatId"] longLongValue];
			if (!me)
				return;
			if (!dmId) {
				[me showLinkError];
				return;
			}
			TGChatViewController *chat = [[TGChatViewController alloc] init];
			chat.chatId = dmId;
			chat.chatTitle = title.length ? title : username;
			[me pushLinkedScreen:chat];
		}];
	}];
}

- (void)openLinkedSettingsPage:(NSString *)page rule:(NSString *)rule {
	if ([page isEqualToString:@"privacyRule"]) {
		NSUInteger index = [[TGSettingsViewController privacySettings] indexOfObject:rule];
		if (index != NSNotFound) {
			NSString *title = [TGSettingsViewController privacyTitles][index];
			[self pushLinkedScreen:[[TGPrivacyRuleViewController alloc] initWithSetting:rule
					title:TGLocalized(title)]];
			return;
		}
		page = @"privacy";
	}
	if ([page isEqualToString:@"storage"]) {
		[self pushLinkedScreen:[[TGStorageViewController alloc] init]];
		return;
	}
	if ([page isEqualToString:@"sessions"]) {
		[self pushLinkedScreen:[[TGSessionsViewController alloc] init]];
		return;
	}
	if ([page isEqualToString:@"editProfile"]) {
		[self pushLinkedScreen:[[TGEditProfileViewController alloc] init]];
		return;
	}
	NSDictionary *pages = @{
		@"appearance"    : @(TGSettingsPageAppearance),
		@"folders"       : @(TGSettingsPageFolders),
		@"data"          : @(TGSettingsPageData),
		@"language"      : @(TGSettingsPageLanguage),
		@"notifications" : @(TGSettingsPageNotifications),
		@"powerSaving"   : @(TGSettingsPagePowerSaving),
		@"privacy"       : @(TGSettingsPagePrivacy),
		@"blocked"       : @(TGSettingsPageBlocked),
		@"passcode"      : @(TGSettingsPagePasscode),
		@"proxy"         : @(TGSettingsPageProxy),
		@"autosave"      : @(TGSettingsPageAutosave),
		@"wallpaper"     : @(TGSettingsPageWallpaper),
		@"autoNight"     : @(TGSettingsPageAutoNight),
	};
	TGSettingsViewController *settings = [[TGSettingsViewController alloc] init];
	settings.page = (TGSettingsPage)[pages[page] integerValue];
	[self pushLinkedScreen:settings];
}

- (void)openLinkedTab:(NSString *)name section:(NSString *)section {
	if ([name isEqualToString:@"calls"]) {
		TGSettingsViewController *calls = [[TGSettingsViewController alloc] init];
		calls.page = TGSettingsPageRecentCalls;
		[self pushLinkedScreen:calls];
		return;
	}
	if ([name isEqualToString:@"contacts"]) {
		if ([section isEqualToString:@"new"]) {
			[TGPresent presentModal:[[TGNewContactViewController alloc] init]
							   kind:TGModalForm from:self];
			return;
		}
		[self pushLinkedScreen:[[TGContactsViewController alloc] init]];
		return;
	}
	if ([name isEqualToString:@"profile"]) {
		int64_t me = [[TGMessageStore shared] savedMessagesChatId];
		[self pushLinkedScreen:[[TGProfileViewController alloc] initWithChatId:me
				userId:me title:TGLocalized(@"My Profile")]];
	}
}

@end
