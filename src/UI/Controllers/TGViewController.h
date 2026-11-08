//
// TGViewController.h - base view controller for LegacyTG.
// Handles iOS 6/7 edges, theme observation, and standard loading/empty states.
//
#import <UIKit/UIKit.h>

@class TGEmptyView;

@interface TGViewController : UIViewController

/// Override in subclass to apply additional theme colors/fonts.
/// Automatically called on viewDidLoad and whenever TGThemeChangedNotification fires.
- (void)applyTheme;

/// Shows or hides a centered activity spinner.
- (void)setLoading:(BOOL)loading;

/// Shows a full-screen empty state view.
- (void)showEmptyWithImage:(UIImage *)image title:(NSString *)title subtitle:(NSString *)subtitle;

/// Removes the empty state view.
- (void)hideEmpty;

@end
