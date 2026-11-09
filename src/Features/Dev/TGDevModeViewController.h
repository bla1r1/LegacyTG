//
// TGDevModeViewController - dev builds only. A tab bar of its own over the real
// app: chats with example messages, and the settings that are not for people.
// Three taps on the Chats tab open it, Close leaves it.
//
#import <UIKit/UIKit.h>

#if TG_DEV
@interface TGDevModeViewController : UITabBarController
+ (void)presentFrom:(UIViewController *)host;
@end

/// The fixture list's row titles, in the order the dev tab draws them.
static inline NSArray *TGDevChatRowTitles(NSArray *chats) {
	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:chats.count];
	for (NSDictionary *chat in chats)
		[titles addObject:chat[@"title"] ?: @""];
	return titles;
}
#endif
