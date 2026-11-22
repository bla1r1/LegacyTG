//
// AppDelegate+Walk.m
//
#import "AppDelegate+Walk.h"
#import "TGClient.h"
#import "TGDevScreenRoute.h"
#import "TGPopupMenu.h"
#import "TGSheet.h"

/// AppDelegate+URL's: the tab bar the routes act on, dev mode's when it is up.
@interface AppDelegate (WalkTabs)
- (UITabBarController *)activeTabBarController;
@end

@implementation AppDelegate (Walk)

- (BOOL)tg_handleWalkURL:(NSURL *)url {
#if TG_DEV
	NSString *host = url.host;
	// itglegacy://reset - nothing open over the tabs: no menu, sheet or modal,
	// so a walk step starts from the same place whatever the one before left.
	if ([host isEqualToString:@"reset"]){
		dispatch_async(dispatch_get_main_queue(), ^{
			[TGPopupMenu dismiss];
			[TGSheet dismissOpen];
			UIViewController *root = self.rootViewController ?: self.window.rootViewController;
			if (root.presentedViewController)
				[root dismissViewControllerAnimated:NO completion:nil];
		});
		return YES;
	}

	// itglegacy://vc/<Class>[/<chat id | @username | current>] - any screen by
	// its class, pushed on the open tab, for the emulator walk (scripts/emu.sh
	// walk). "current" is the chat or profile on top; a username is resolved
	// first, so a public group or channel stands in for one of the account's.
	if ([host isEqualToString:@"vc"]){
		NSArray *parts = [url.path componentsSeparatedByString:@"/"];
		NSString *name = parts.count > 1 ? parts[1] : @"";
		NSString *target = parts.count > 2 ? parts[2] : @"";
		Class cls = TGDevScreenClass(name, [UIViewController class]);
		if ([cls isSubclassOfClass:[UINavigationController class]])
			cls = Nil;                  // a flow, not a screen to push
		if (!cls){
			NSLog(@"vc: no screen named %@", name);
			return YES;
		}
		void (^push)(int64_t, NSString *) = ^(int64_t chatId, NSString *title){
			dispatch_async(dispatch_get_main_queue(), ^{
				UITabBarController *tabs = [self activeTabBarController];
				if (![tabs isKindOfClass:UITabBarController.class])
					return;
				UINavigationController *nc = tabs.viewControllers[tabs.selectedIndex];
				int64_t chat = chatId;
				NSString *chatTitle = title;
				UIViewController *top = nc.topViewController;
				if ([target isEqualToString:@"current"] && [top respondsToSelector:NSSelectorFromString(@"chatId")]){
					chat = [[top valueForKey:@"chatId"] longLongValue];
					chatTitle = top.title;
				}
				UIViewController *screen = TGDevScreenMake(cls, chat, chatTitle);
				if (!screen)
					return;
				screen.hidesBottomBarWhenPushed = YES;
				[nc pushViewController:screen animated:NO];
				NSLog(@"vc: %@ chat %lld", name, chat);
			});
		};
		if ([target hasPrefix:@"@"])
			[[TGClient shared] chatWithUsername:[target substringFromIndex:1] completion:push];
		else
			push(target.longLongValue, nil);
		return YES;
	}
#endif
	return NO;
}

@end
