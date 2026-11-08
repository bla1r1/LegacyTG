//
// TGTableViewController.h - base table view controller for LegacyTG.
// Handles iOS 6/7 edges, table background/separator, and theme observation.
//
#import <UIKit/UIKit.h>

@class TGEmptyView;

@interface TGTableViewController : UITableViewController

/// Override in subclass to apply additional theme colors/fonts.
/// Automatically called on viewDidLoad and whenever TGThemeChangedNotification fires.
- (void)applyTheme;

/// Shows a full-table empty state view.
- (void)showEmptyWithImage:(UIImage *)image title:(NSString *)title subtitle:(NSString *)subtitle;

/// Removes the empty state view.
- (void)hideEmpty;

@end
