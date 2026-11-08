#import "TGViewController.h"
#import "TGTheme.h"
#import "TGEmptyView.h"
#import "TGGeometry.h"

@interface TGViewController ()
@property (nonatomic, strong) UIActivityIndicatorView *tg_spinner;
@property (nonatomic, strong) TGEmptyView *tg_emptyView;
@end

@implementation TGViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
		self.edgesForExtendedLayout = UIRectEdgeNone;
	}
	[self applyTheme];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tg_baseThemeDidChange:)
												 name:TGThemeChangedNotification
											   object:nil];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	if (self.tg_spinner && self.tg_spinner.isAnimating) {
		self.tg_spinner.frame = TGFrameCenterInRect(self.tg_spinner.bounds.size, self.view.bounds);
	}
	if (self.tg_emptyView) {
		self.tg_emptyView.frame = self.view.bounds;
	}
}

- (void)tg_baseThemeDidChange:(NSNotification *)note {
	[self applyTheme];
}

- (void)applyTheme {
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)setLoading:(BOOL)loading {
	if (loading) {
		if (!self.tg_spinner) {
			self.tg_spinner = [[UIActivityIndicatorView alloc]
				initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			self.tg_spinner.hidesWhenStopped = YES;
			[self.view addSubview:self.tg_spinner];
		}
		[self.view bringSubviewToFront:self.tg_spinner];
		self.tg_spinner.frame = TGFrameCenterInRect(self.tg_spinner.bounds.size, self.view.bounds);
		[self.tg_spinner startAnimating];
	} else {
		[self.tg_spinner stopAnimating];
	}
}

- (void)showEmptyWithImage:(UIImage *)image title:(NSString *)title subtitle:(NSString *)subtitle {
	[self.tg_emptyView removeFromSuperview];
	self.tg_emptyView = [TGEmptyView emptyViewWithFrame:self.view.bounds
												 image:image
												 title:title
											  subtitle:subtitle
										   buttonTitle:nil
												target:nil
												action:nil];
	[self.view addSubview:self.tg_emptyView];
}

- (void)hideEmpty {
	[self.tg_emptyView removeFromSuperview];
	self.tg_emptyView = nil;
}

@end
