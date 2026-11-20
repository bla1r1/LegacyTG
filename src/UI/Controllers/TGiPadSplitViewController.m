//
// TGiPadSplitViewController.m
// LegacyTG - Master-Detail split controller for iPad layout
//
#import "TGiPadSplitViewController.h"
#import "TGiPadChatPlaceholderViewController.h"
#import "TGChatViewController.h"
#import "TGTopicsViewController.h"
#import "TGNavController.h"
#import "TGObservers.h"
#import "TGTheme.h"
#import "TGStyle.h"

@interface TGiPadSplitViewController ()
@property (nonatomic, strong) UIView *masterContainerView;
@property (nonatomic, strong) UIView *separatorView;
@property (nonatomic, strong) UIView *barSeparatorView;
@property (nonatomic, strong) UIView *barHighlightView;
@property (nonatomic, strong) UIView *bodySeparatorView;
@property (nonatomic, strong) UIView *bodyHighlightView;
@property (nonatomic, strong) UIView *bottomBarSeparatorView;
@property (nonatomic, strong) UIView *bottomBarHighlightView;
@property (nonatomic, strong) UIView *detailContainerView;
@property (nonatomic, assign) int64_t activeChatId;
@end

@implementation TGiPadSplitViewController

+ (instancetype)shared {
	static TGiPadSplitViewController *sInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sInstance = [[self alloc] init];
	});
	return sInstance;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		__weak typeof(self) weakSelf = self;
		[TGObservers observe:TGThemeChangedNotification
		               owner:self
		          usingBlock:^(NSNotification *note) {
			[weakSelf applyTheme];
		}];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

/// The list's bars were styled at launch, before the split existed (and in
/// the dev simulator before the idiom turned to iPad); they are styled again
/// so both panes carry the same bar.
- (void)styleBarsIn:(UIViewController *)vc {
	if ([vc isKindOfClass:UINavigationController.class])
		[[TGTheme shared] styleNavigationBar:((UINavigationController *)vc).navigationBar];
	if ([vc isKindOfClass:UITabBarController.class])
		[[TGTheme shared] styleTabBar:((UITabBarController *)vc).tabBar];
	NSArray *children = [vc isKindOfClass:UITabBarController.class]
			? ((UITabBarController *)vc).viewControllers : vc.childViewControllers;
	for (UIViewController *child in children)
		[self styleBarsIn:child];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	[self styleBarsIn:self.masterViewController];
	if (self.isViewLoaded) {
		self.view.backgroundColor = [theme padSplitBarDividerColour];
		self.separatorView.backgroundColor = [theme padSplitDividerColour];
		self.barSeparatorView.backgroundColor = [theme padSplitBarDividerColour];
		self.barHighlightView.backgroundColor = [theme padSplitBarHighlightColour];
		self.bodySeparatorView.backgroundColor = [theme padSplitDividerColour];
		self.bodyHighlightView.backgroundColor = [theme padSplitHighlightColour];
		self.bottomBarSeparatorView.backgroundColor = [theme padSplitBarDividerColour];
		self.bottomBarHighlightView.backgroundColor = [theme padSplitBarHighlightColour];
	}
	if (self.detailNavigationController) {
		[theme styleNavigationBar:self.detailNavigationController.navigationBar];
	}
}

- (UIViewController *)childViewControllerForStatusBarStyle {
	return self.detailNavigationController ?: self.masterViewController;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	TGTheme *theme = [TGTheme shared];
	self.view.backgroundColor = [theme padSplitBarDividerColour];

	_masterContainerView = [[UIView alloc] init];
	_masterContainerView.clipsToBounds = YES;
	[self.view addSubview:_masterContainerView];

	_detailContainerView = [[UIView alloc] init];
	_detailContainerView.clipsToBounds = YES;
	[self.view addSubview:_detailContainerView];

	_separatorView = [[UIView alloc] init];
	_separatorView.backgroundColor = [theme padSplitDividerColour];
	[self.view addSubview:_separatorView];

	_barSeparatorView = [[UIView alloc] init];
	_barSeparatorView.backgroundColor = [theme padSplitBarDividerColour];
	[_separatorView addSubview:_barSeparatorView];

	_barHighlightView = [[UIView alloc] init];
	_barHighlightView.backgroundColor = [theme padSplitBarHighlightColour];
	[_separatorView addSubview:_barHighlightView];

	_bodySeparatorView = [[UIView alloc] init];
	_bodySeparatorView.backgroundColor = [theme padSplitDividerColour];
	[_separatorView addSubview:_bodySeparatorView];

	_bodyHighlightView = [[UIView alloc] init];
	_bodyHighlightView.backgroundColor = [theme padSplitHighlightColour];
	[_separatorView addSubview:_bodyHighlightView];

	_bottomBarSeparatorView = [[UIView alloc] init];
	_bottomBarSeparatorView.backgroundColor = [theme padSplitBarDividerColour];
	[_separatorView addSubview:_bottomBarSeparatorView];

	_bottomBarHighlightView = [[UIView alloc] init];
	_bottomBarHighlightView.backgroundColor = [theme padSplitBarHighlightColour];
	[_separatorView addSubview:_bottomBarHighlightView];

	[self layoutSplit];

	if (self.masterViewController) {
		[self attachChildViewController:self.masterViewController toContainer:_masterContainerView];
	}

	if (!self.detailNavigationController) {
		[self clearDetailToPlaceholder];
	} else {
		[self attachChildViewController:self.detailNavigationController toContainer:_detailContainerView];
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	// The dev simulator hands the list over before it reports the iPad idiom.
	[self styleBarsIn:self.masterViewController];
}

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];
	[self layoutSplit];
}

- (void)layoutSplit {
	CGSize size = self.view.bounds.size;
	if (size.width <= 0.0f || size.height <= 0.0f) return;

	CGFloat mW = TGMetricPadMasterWidthForWidth(size.width);
	CGFloat sepW = TGMetricBorderWidth;
	CGFloat dW = size.width - mW - sepW;
	if (dW < 0.0f) dW = 0.0f;

	_masterContainerView.frame = CGRectMake(0.0f, 0.0f, mW, size.height);
	_separatorView.frame = CGRectMake(mW, 0.0f, sepW, size.height);
	_detailContainerView.frame = CGRectMake(mW + sepW, 0.0f, dW, size.height);

	CGFloat navH = TGMetricNavigationBarHeight;
	CGFloat botH = TGMetricTabBarHeight;
	CGFloat bodyH = size.height - navH - botH;
	if (bodyH < 0.0f) bodyH = 0.0f;

	CGFloat hlW = TGMetricHairline;
	CGFloat hlX = sepW - hlW;

	_barSeparatorView.frame = CGRectMake(0.0f, 0.0f, sepW, navH);
	_barHighlightView.frame = CGRectMake(hlX, 0.0f, hlW, navH);

	_bodySeparatorView.frame = CGRectMake(0.0f, navH, sepW, bodyH);
	_bodyHighlightView.frame = CGRectMake(hlX, navH, hlW, bodyH);

	_bottomBarSeparatorView.frame = CGRectMake(0.0f, size.height - botH, sepW, botH);
	_bottomBarHighlightView.frame = CGRectMake(hlX, size.height - botH, hlW, botH);

	if (self.masterViewController.isViewLoaded) {
		self.masterViewController.view.frame = _masterContainerView.bounds;
	}
	if (self.detailNavigationController.isViewLoaded) {
		self.detailNavigationController.view.frame = _detailContainerView.bounds;
	}
	[self.view bringSubviewToFront:_separatorView];
}

- (void)attachChildViewController:(UIViewController *)vc toContainer:(UIView *)container {
	if (!vc || !container) return;
	[self addChildViewController:vc];
	vc.view.frame = container.bounds;
	vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[container addSubview:vc.view];
	[vc didMoveToParentViewController:self];
	[vc.view setNeedsLayout];
	[vc.view layoutIfNeeded];
}

- (void)detachChildViewController:(UIViewController *)vc {
	if (!vc) return;
	[vc willMoveToParentViewController:nil];
	[vc.view removeFromSuperview];
	[vc removeFromParentViewController];
}

- (void)setMasterViewController:(UIViewController *)masterVC {
	if (_masterViewController == masterVC) return;
	if (_masterViewController) {
		[self detachChildViewController:_masterViewController];
	}
	_masterViewController = masterVC;
	[self styleBarsIn:masterVC];
	if (masterVC && self.isViewLoaded) {
		[self attachChildViewController:masterVC toContainer:_masterContainerView];
	}
}

- (void)setDetailNavigationController:(UINavigationController *)detailNC {
	if (_detailNavigationController == detailNC) return;
	if (_detailNavigationController) {
		[self detachChildViewController:_detailNavigationController];
	}
	_detailNavigationController = detailNC;
	if (detailNC && self.isViewLoaded) {
		[self attachChildViewController:detailNC toContainer:_detailContainerView];
	}
}

- (void)clearDetailToPlaceholder {
	_activeChatId = 0;
	TGiPadChatPlaceholderViewController *placeholder = [[TGiPadChatPlaceholderViewController alloc] init];
	TGNavController *nav = [[TGNavController alloc] initWithRootViewController:placeholder];
	[[TGTheme shared] styleNavigationBar:nav.navigationBar];
	// Official shows no bar over the empty pane: an empty bar beside the
	// list's own read as a missing title.
	nav.navigationBarHidden = YES;
	self.detailNavigationController = nav;
}

- (void)showChatWithId:(int64_t)chatId
                 title:(NSString *)title
               isGroup:(BOOL)isGroup
               isForum:(BOOL)isForum
{
	if (_activeChatId == chatId && self.detailNavigationController) {
		[self.detailNavigationController popToRootViewControllerAnimated:YES];
		return;
	}
	_activeChatId = chatId;

	UIViewController *rootVC = nil;
	if (isForum) {
		TGTopicsViewController *topics = [[TGTopicsViewController alloc] init];
		topics.chatId = chatId;
		topics.chatTitle = title;
		rootVC = topics;
	} else {
		TGChatViewController *chatVC = [[TGChatViewController alloc] init];
		chatVC.chatId = chatId;
		chatVC.chatTitle = title;
		chatVC.isGroup = isGroup;
		rootVC = chatVC;
	}

	TGNavController *nav = [[TGNavController alloc] initWithRootViewController:rootVC];
	[[TGTheme shared] styleNavigationBar:nav.navigationBar];
	self.detailNavigationController = nav;

	[[NSNotificationCenter defaultCenter] postNotificationName:@"TGiPadActiveChatChangedNotification"
	                                                    object:nil
	                                                  userInfo:@{ @"chatId": @(chatId) }];
}

@end
