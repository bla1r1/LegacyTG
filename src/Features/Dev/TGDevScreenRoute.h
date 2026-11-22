//
// TGDevScreenRoute.h - itglegacy://vc/<Class>[/<chat>]: any screen by its
// class name, for the emulator walk. Most screens sit three taps and an
// account state away; the walk has no fingers, only routes, and a route per
// screen would be 90 more branches in AppDelegate+URL.
//
// Foundation only, so the host suite checks the rules without UIKit: the
// route passes [UIViewController class] as `base`.
//
#import <Foundation/Foundation.h>

#if TG_DEV

#ifdef __cplusplus
extern "C" {
#endif

/// The class named when it is one of ours (TG prefix) and a subclass of
/// `base`, Nil otherwise. Screens that need live state the route cannot give
/// (chat, call, login, the iPad canvas) are refused: they have routes of
/// their own.
Class TGDevScreenClass(NSString *name, Class base);

/// A screen of `cls` for `chatId` (0 for none): initWithChatId:title: or
/// initWithChatId: where the class has one, otherwise init and the chatId
/// and chatTitle properties when it has them.
id TGDevScreenMake(Class cls, int64_t chatId, NSString *title);

#ifdef __cplusplus
}
#endif

#endif
