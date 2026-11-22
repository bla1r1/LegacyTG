//
// TGBarItem.h - navigation bar buttons by what they mean.
//
// Screens in src/Features never build a UIBarButtonItem: they ask for a role
// (TGPresentRules.h) or a named action, and get the same words, weight and glyph
// every other screen gets.
//
//   leftBarButtonItem  = [TGBarItem itemWithRole:TGBarRoleCancel target:self action:@selector(cancel)];
//   rightBarButtonItem = [TGBarItem itemWithRole:TGBarRoleDone target:self action:@selector(save)];
//
#import <UIKit/UIKit.h>
#import "TGPresentRules.h"

@interface TGBarItem : NSObject

/// The button for `role`: its official title (or glyph), its weight.
+ (UIBarButtonItem *)itemWithRole:(TGBarRole)role target:(id)target action:(SEL)action;

/// A button that names its own action where no role fits: Next, Send,
/// Create, Apply, Skip. `primary` makes it bold, the one that commits.
/// `title` is official English and is localised here.
+ (UIBarButtonItem *)itemWithTitle:(NSString *)title
						   primary:(BOOL)primary
							target:(id)target
							action:(SEL)action;

/// Words with no border, for a toolbar over a picker (Cancel beside a bold
/// Done). In a navigation bar iOS 6 borders it anyway; use itemWithTitle:.
+ (UIBarButtonItem *)plainItemWithTitle:(NSString *)title
								target:(id)target
								action:(SEL)action;

/// An icon-only action with no role of its own (QR, camera light). `label`
/// is what VoiceOver reads, official English.
+ (UIBarButtonItem *)itemWithGlyph:(NSString *)glyph
							 label:(NSString *)label
							target:(id)target
							action:(SEL)action;

/// An icon-only action drawn by the screen itself (the Settings QR mark).
+ (UIBarButtonItem *)itemWithImage:(UIImage *)image
							 label:(NSString *)label
							target:(id)target
							action:(SEL)action;

/// A view standing in the bar: a canvas's own button (the chat's avatar, the
/// story ring) or an empty view that holds a side free.
+ (UIBarButtonItem *)itemWithView:(UIView *)view;

/// A spinner in the bar while a Done is being saved (official .activity).
+ (UIBarButtonItem *)activityItem;

/// Toolbar spacing.
+ (UIBarButtonItem *)flexibleSpace;

/// Puts the button for `role` on the side official puts it.
+ (void)setRole:(TGBarRole)role
	 onController:(UIViewController *)controller
		   target:(id)target
		   action:(SEL)action;

/// The button's frame in `host`'s coordinates, for a menu to hang from.
/// Falls back to the corner of the bar on `side` where UIKit hides the view.
+ (CGRect)frameOfItem:(UIBarButtonItem *)item
		 onController:(UIViewController *)controller
				 side:(TGBarSide)side
			   inView:(UIView *)host;

@end

// vim:ft=objc
