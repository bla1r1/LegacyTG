#import "TGPlaceholderViewController.h"
#import "TGIcons.h"
#import "TGTheme.h"

@implementation TGPlaceholderViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.featureName.length ? self.featureName : @"Not Available";
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	NSString *name = self.featureName.length ? self.featureName : @"This feature";
	[self showEmptyWithImage:[TGIcons emptySearchIllustration]
	                   title:name
	                subtitle:@"This feature is not available on this device yet. "
	                         @"Settings > This Device explains what the hardware can do."];
}

@end
