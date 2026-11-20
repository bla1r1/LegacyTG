//
// TGiPadSimulator.m
// LegacyTG - Virtual iPad canvas & layout preview for dev builds
//
#import "TGiPadSimulator.h"

#if TG_DEV

#import "TGStyle.h"

static const CGFloat kIPadWidth = 768.0f;
static const CGFloat kIPadHeight = 1024.0f;

CGSize TGiPadCanvasSizeForOrientation(TGiPadOrientation orientation) {
	switch (orientation) {
		case TGiPadOrientationPortrait:
			return CGSizeMake(kIPadWidth, kIPadHeight);
		case TGiPadOrientationLandscape:
			return CGSizeMake(kIPadHeight, kIPadWidth);
		case TGiPadOrientationOff:
		default:
			return CGSizeZero;
	}
}

CGFloat TGiPadScaleToFitScreen(CGSize canvasSize, CGSize screenSize) {
	if (canvasSize.width <= 0.0f || canvasSize.height <= 0.0f ||
	    screenSize.width <= 0.0f || screenSize.height <= 0.0f) {
		return 1.0f;
	}
	CGFloat scaleX = screenSize.width / canvasSize.width;
	CGFloat scaleY = screenSize.height / canvasSize.height;
	return MIN(scaleX, scaleY);
}

CGRect TGiPadCanvasRectForScreen(CGSize canvasSize, CGSize screenSize) {
	CGFloat scale = TGiPadScaleToFitScreen(canvasSize, screenSize);
	CGFloat scaledW = canvasSize.width * scale;
	CGFloat scaledH = canvasSize.height * scale;
	CGFloat x = TGCenteredOrigin(screenSize.width, scaledW);
	CGFloat y = TGCenteredOrigin(screenSize.height, scaledH);
	return CGRectMake(x, y, scaledW, scaledH);
}

#if !TARGET_OS_IPHONE

@interface TGiPadSimulator ()
@property (nonatomic, assign) TGiPadOrientation orientation;
@end

@implementation TGiPadSimulator

+ (instancetype)shared {
	static TGiPadSimulator *sInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sInstance = [[self alloc] init];
	});
	return sInstance;
}

- (BOOL)isActive {
	return self.orientation != TGiPadOrientationOff;
}

- (UIView *)canvasView {
	return nil;
}

- (void)setOrientation:(TGiPadOrientation)orientation inWindow:(UIWindow *)window {
	_orientation = orientation;
}

- (void)updateContentViewController:(UIViewController *)vc inWindow:(UIWindow *)window {
}

- (void)toggleModeInWindow:(UIWindow *)window {
	self.orientation = self.isActive ? TGiPadOrientationOff : TGiPadOrientationPortrait;
}

- (void)toggleOrientationInWindow:(UIWindow *)window {
	if (self.orientation == TGiPadOrientationPortrait) {
		self.orientation = TGiPadOrientationLandscape;
	} else {
		self.orientation = TGiPadOrientationPortrait;
	}
}

- (UIImage *)captureScreenshotAtScale:(CGFloat)scale {
	return nil;
}

- (NSString *)saveScreenshotRetina:(BOOL)retina {
	return nil;
}

@end

#else

#import "TGTheme.h"
#import "TGiPadSplitViewController.h"
#import "RootViewController.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static const CGFloat kToolbarHeight = 26.0f;
static const CGFloat kToolbarBtnMargin = 40.0f;
static const CGFloat kToolbarBtnSpacing = 42.0f;
static const CGFloat kToolbarExitBtnW = 36.0f;
static const CGFloat kToolbarRotBtnW = 38.0f;
static const CGFloat kToolbarShotBtnW = 36.0f;
static const CGFloat kToolbarTitleW = 150.0f;

#pragma mark - UIDevice userInterfaceIdiom Swizzle

static UIUserInterfaceIdiom (*sOriginalUserInterfaceIdiom)(id, SEL) = NULL;

static UIUserInterfaceIdiom TGiPadUserInterfaceIdiom(id self, SEL _cmd) {
	if ([TGiPadSimulator shared].isActive) {
		return UIUserInterfaceIdiomPad;
	}
	if (sOriginalUserInterfaceIdiom) {
		return sOriginalUserInterfaceIdiom(self, _cmd);
	}
	return UIUserInterfaceIdiomPhone;
}

static void TGiPadInstallDeviceSwizzle(void) {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		Method m = class_getInstanceMethod([UIDevice class], @selector(userInterfaceIdiom));
		if (m) {
			sOriginalUserInterfaceIdiom = (UIUserInterfaceIdiom (*)(id, SEL))method_getImplementation(m);
			method_setImplementation(m, (IMP)TGiPadUserInterfaceIdiom);
		}
	});
}

#pragma mark - Container View Controller

@interface TGiPadSimulatorContainerViewController : UIViewController
@property (nonatomic, strong) UIView *canvasView;
@property (nonatomic, strong) UIView *toolbarView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIViewController *contentViewController;
@property (nonatomic, assign) TGiPadOrientation orientation;
- (void)applyOrientationLayout;
@end

@implementation TGiPadSimulatorContainerViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor blackColor];
	self.definesPresentationContext = YES;

	self.canvasView = [[UIView alloc] init];
	self.canvasView.clipsToBounds = YES;
	self.canvasView.backgroundColor = [UIColor blackColor];
	[self.view addSubview:self.canvasView];

	if (self.contentViewController && self.contentViewController.view.superview != self.canvasView) {
		self.contentViewController.view.frame = self.canvasView.bounds;
		self.contentViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self.canvasView addSubview:self.contentViewController.view];
		[self.contentViewController.view setNeedsLayout];
		[self.contentViewController.view layoutIfNeeded];
	}

	[self setupToolbar];
	[self applyOrientationLayout];
}

- (void)setupToolbar {
	TGTheme *theme = [TGTheme shared];
	_toolbarView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.view.bounds.size.height - kToolbarHeight, self.view.bounds.size.width, kToolbarHeight)];
	_toolbarView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
	_toolbarView.backgroundColor = [theme hudBackgroundColour];

	_titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(TGMetricPadSmall, 0.0f, kToolbarTitleW, kToolbarHeight)];
	_titleLabel.backgroundColor = [UIColor clearColor];
	_titleLabel.textColor = [theme onAccentColour];
	_titleLabel.font = TGFontMicroStrong();
	[_toolbarView addSubview:_titleLabel];

	CGFloat btnX = self.view.bounds.size.width - kToolbarBtnMargin;
	CGFloat btnH = kToolbarHeight - TGDoubled(TGMetricPadTiny);

	UIButton *exitBtn = [UIButton buttonWithType:UIButtonTypeCustom];
	exitBtn.frame = CGRectMake(btnX, TGMetricPadTiny, kToolbarExitBtnW, btnH);
	exitBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[exitBtn setTitle:@"Exit" forState:UIControlStateNormal];
	exitBtn.titleLabel.font = TGFontMicro();
	[exitBtn setTitleColor:[theme destructiveColour] forState:UIControlStateNormal];
	[exitBtn addTarget:self action:@selector(exitTapped) forControlEvents:UIControlEventTouchUpInside];
	[_toolbarView addSubview:exitBtn];
	btnX -= kToolbarBtnSpacing;

	UIButton *rotBtn = [UIButton buttonWithType:UIButtonTypeCustom];
	rotBtn.frame = CGRectMake(btnX, TGMetricPadTiny, kToolbarRotBtnW, btnH);
	rotBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[rotBtn setTitle:@"Rotate" forState:UIControlStateNormal];
	rotBtn.titleLabel.font = TGFontMicro();
	[rotBtn setTitleColor:[theme secondaryTextColour] forState:UIControlStateNormal];
	[rotBtn addTarget:self action:@selector(rotateTapped) forControlEvents:UIControlEventTouchUpInside];
	[_toolbarView addSubview:rotBtn];
	btnX -= kToolbarBtnSpacing;

	UIButton *shotBtn = [UIButton buttonWithType:UIButtonTypeCustom];
	shotBtn.frame = CGRectMake(btnX, TGMetricPadTiny, kToolbarShotBtnW, btnH);
	shotBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[shotBtn setTitle:@"Shot" forState:UIControlStateNormal];
	shotBtn.titleLabel.font = TGFontMicroStrong();
	[shotBtn setTitleColor:[theme accentColour] forState:UIControlStateNormal];
	[shotBtn addTarget:self action:@selector(shotTapped:) forControlEvents:UIControlEventTouchUpInside];
	[_toolbarView addSubview:shotBtn];

	[self.view addSubview:_toolbarView];
}

- (void)exitTapped {
	[[TGiPadSimulator shared] setOrientation:TGiPadOrientationOff inWindow:self.view.window];
}

- (void)rotateTapped {
	[[TGiPadSimulator shared] toggleOrientationInWindow:self.view.window];
}

- (void)shotTapped:(UIButton *)sender {
	NSString *path = [[TGiPadSimulator shared] saveScreenshotRetina:YES];
	if (path) {
		NSString *prevTitle = [sender titleForState:UIControlStateNormal];
		[sender setTitle:@"Done!" forState:UIControlStateNormal];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[sender setTitle:prevTitle forState:UIControlStateNormal];
		});
	}
}

- (void)setContentViewController:(UIViewController *)vc {
	(void)self.view;
	if (_contentViewController == vc && vc.view.superview == self.canvasView) return;
	if (_contentViewController) {
		[_contentViewController willMoveToParentViewController:nil];
		[_contentViewController.view removeFromSuperview];
		[_contentViewController removeFromParentViewController];
	}
	_contentViewController = vc;
	if (vc) {
		[self addChildViewController:vc];
		vc.view.frame = self.canvasView.bounds;
		vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self.canvasView addSubview:vc.view];
		[vc didMoveToParentViewController:self];
		[self.canvasView bringSubviewToFront:vc.view];
		[vc.view setNeedsLayout];
		[vc.view layoutIfNeeded];
	}
}

- (void)applyOrientationLayout {
	CGSize canvasSize = TGiPadCanvasSizeForOrientation(self.orientation);
	if (CGSizeEqualToSize(canvasSize, CGSizeZero)) return;

	CGSize screenSize = self.view.bounds.size;
	if (screenSize.width <= 0.0f || screenSize.height <= 0.0f) {
		screenSize = [UIScreen mainScreen].bounds.size;
	}

	CGFloat scale = TGiPadScaleToFitScreen(canvasSize, screenSize);

	self.canvasView.transform = CGAffineTransformIdentity;
	self.canvasView.bounds = CGRectMake(0.0f, 0.0f, canvasSize.width, canvasSize.height);
	self.canvasView.center = CGPointMake(TGHalf(screenSize.width), TGHalf(screenSize.height));
	self.canvasView.transform = CGAffineTransformMakeScale(scale, scale);

	if (self.contentViewController) {
		self.contentViewController.view.frame = self.canvasView.bounds;
		[self.contentViewController.view layoutIfNeeded];
	}

	NSString *dimStr = (self.orientation == TGiPadOrientationLandscape) ? @"1024x768" : @"768x1024";
	self.titleLabel.text = [NSString stringWithFormat:@"iPad %@ (%.2fx)", dimStr, scale];
}

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];
	[self applyOrientationLayout];
}

- (BOOL)shouldAutorotate {
	return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)prefersStatusBarHidden {
	return YES;
}

@end

#pragma mark - TGiPadSimulator Implementation

@interface TGiPadSimulator ()
@property (nonatomic, assign) TGiPadOrientation orientation;
@property (nonatomic, strong) UIViewController *originalRootVC;
@property (nonatomic, strong) TGiPadSimulatorContainerViewController *containerVC;
@end

@implementation TGiPadSimulator

+ (instancetype)shared {
	static TGiPadSimulator *sInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sInstance = [[self alloc] init];
	});
	return sInstance;
}

- (BOOL)isActive {
	return self.orientation != TGiPadOrientationOff;
}

- (UIView *)canvasView {
	return self.containerVC.canvasView;
}

- (void)setOrientation:(TGiPadOrientation)orientation inWindow:(UIWindow *)window {
	if (!window) {
		window = [UIApplication sharedApplication].keyWindow;
	}
	if (!window) {
		for (UIWindow *w in [UIApplication sharedApplication].windows) {
			if (w.isKeyWindow) {
				window = w;
				break;
			}
		}
	}
	if (!window) {
		window = [UIApplication sharedApplication].windows.firstObject;
	}

	if (self.orientation == orientation && self.containerVC) return;

	TGiPadInstallDeviceSwizzle();

	if (orientation == TGiPadOrientationOff) {
		if (self.containerVC && self.originalRootVC) {
			[self.containerVC setContentViewController:nil];
			UIViewController *restoreVC = self.originalRootVC;
			if ([restoreVC isKindOfClass:[TGiPadSplitViewController class]]) {
				TGiPadSplitViewController *split = (TGiPadSplitViewController *)restoreVC;
				restoreVC = split.masterViewController;
				split.masterViewController = nil;
			}
			window.rootViewController = restoreVC;
			restoreVC.view.transform = CGAffineTransformIdentity;
			restoreVC.view.frame = window.bounds;
			[window layoutIfNeeded];
			[restoreVC.view setNeedsLayout];
			[restoreVC.view layoutIfNeeded];
		}
		self.containerVC = nil;
		self.originalRootVC = nil;
		_orientation = TGiPadOrientationOff;
		[[NSUserDefaults standardUserDefaults] setInteger:TGiPadOrientationOff forKey:@"TGiPadOrientation"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		NSLog(@"[TGiPadSimulator] Virtual iPad mode turned OFF");
		return;
	}

	if (!self.isActive) {
		UIViewController *root = window.rootViewController;
		if ([root isKindOfClass:[RootViewController class]]) {
			TGiPadSplitViewController *split = [TGiPadSplitViewController shared];
			split.masterViewController = root;
			self.originalRootVC = split;
		} else {
			self.originalRootVC = root;
		}
		self.containerVC = [[TGiPadSimulatorContainerViewController alloc] init];
	}

	_orientation = orientation;
	self.containerVC.orientation = orientation;

	(void)self.containerVC.view;

	if (window && window.rootViewController != self.containerVC) {
		window.rootViewController = self.containerVC;
	}
	[self.containerVC setContentViewController:self.originalRootVC];
	[self.containerVC applyOrientationLayout];
	[window layoutIfNeeded];

	[[NSUserDefaults standardUserDefaults] setInteger:orientation forKey:@"TGiPadOrientation"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	NSLog(@"[TGiPadSimulator] Virtual iPad mode set to %s (%@)",
	      (orientation == TGiPadOrientationLandscape ? "Landscape" : "Portrait"),
	      NSStringFromCGSize(TGiPadCanvasSizeForOrientation(orientation)));
}

- (void)updateContentViewController:(UIViewController *)vc inWindow:(UIWindow *)window {
	if (!self.isActive || !vc) return;
	self.originalRootVC = vc;
	if (!self.containerVC) {
		self.containerVC = [[TGiPadSimulatorContainerViewController alloc] init];
		self.containerVC.orientation = self.orientation;
	}
	(void)self.containerVC.view;
	if (!window) window = [UIApplication sharedApplication].keyWindow;
	if (window && window.rootViewController != self.containerVC) {
		window.rootViewController = self.containerVC;
	}
	[self.containerVC setContentViewController:vc];
	[self.containerVC applyOrientationLayout];
	[window layoutIfNeeded];
}

- (void)toggleModeInWindow:(UIWindow *)window {
	if (self.isActive) {
		[self setOrientation:TGiPadOrientationOff inWindow:window];
	} else {
		[self setOrientation:TGiPadOrientationPortrait inWindow:window];
	}
}

- (void)toggleOrientationInWindow:(UIWindow *)window {
	if (self.orientation == TGiPadOrientationPortrait) {
		[self setOrientation:TGiPadOrientationLandscape inWindow:window];
	} else {
		[self setOrientation:TGiPadOrientationPortrait inWindow:window];
	}
}

- (UIImage *)captureScreenshotAtScale:(CGFloat)scale {
	if (!self.containerVC || !self.containerVC.canvasView) return nil;
	UIView *canvas = self.containerVC.canvasView;
	CGSize size = canvas.bounds.size;
	if (size.width <= 0.0f || size.height <= 0.0f) return nil;

	UIGraphicsBeginImageContextWithOptions(size, YES, scale);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	[canvas.layer renderInContext:ctx];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

- (NSString *)saveScreenshotRetina:(BOOL)retina {
	CGFloat scale = retina ? 2.0f : 1.0f;
	UIImage *img = [self captureScreenshotAtScale:scale];
	if (!img) return nil;

	NSData *data = UIImagePNGRepresentation(img);
	if (!data) return nil;

	// The app's own tmp, numbered: afcclient --container can pull it, and
	// a run of several shots keeps every one.
	NSString *name = [NSString stringWithFormat:@"ipad_%.0f.png",
			[NSDate timeIntervalSinceReferenceDate]];
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
	BOOL ok = [data writeToFile:path atomically:YES];
	if (ok) {
		NSLog(@"[TGiPadSimulator] Saved iPad screenshot (%.0fx%.0f @ %.0fx) to %@",
		      img.size.width, img.size.height, scale, path);
		return path;
	}
	return nil;
}

@end

#endif // TARGET_OS_IPHONE

#endif // TG_DEV
