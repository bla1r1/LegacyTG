//
// TGNavController.m - a navigation controller that names its back button
// "Back" instead of whatever the previous screen happened to be titled.
//
#import "TGNavController.h"
#import "TGTheme.h"

@implementation TGNavController

/// While our bar is showing, the bar's colour decides the status bar, so the
/// theme does: a screen that never overrides the style would otherwise get
/// UIKit's dark default over a Night Blue bar. A screen that hides the bar
/// (stories, the player) draws under the status bar itself and decides.
- (UIViewController *)childViewControllerForStatusBarStyle {
	return self.navigationBarHidden ? self.topViewController : nil;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
	if ([[TGTheme shared] isDark]) {
		return UIStatusBarStyleLightContent;
	}
	return UIStatusBarStyleDefault;
}

- (void)pushViewController:(UIViewController *)vc animated:(BOOL)animated {
	// The back button belongs to the screen below the one being pushed, so
	// its title has to say "Back" here, right before the push - otherwise it
	// reads as the button's fate carrying the outgoing screen's name (a
	// folder, "Chats", "Info"), which says nothing about where pressing it
	// actually goes.
	UIViewController *under = self.topViewController;
	if (under)
		under.navigationItem.backBarButtonItem =
				[[UIBarButtonItem alloc] initWithTitle:@"Back"
					style:UIBarButtonItemStyleBordered
					target:nil
					action:NULL];
	[super pushViewController:vc animated:animated];
}

@end
