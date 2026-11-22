//
// TGPageViewController.m
//
#import "TGPageViewController.h"
#import "TGPageHeaderView.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGLocalization.h"
#import "TGSegmentedControl.h"

@interface TGPageViewController () <UISearchBarDelegate>
@property (nonatomic, strong, readwrite) TGPageTemplate *page;
@property (nonatomic, assign) TGPageChrome chrome;
@property (nonatomic, strong) TGPageHeaderView *header;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIToolbar *scopeStrip;
@property (nonatomic, strong) UISegmentedControl *scopeSegments;
@property (nonatomic, strong) UIButton *bottomButton;
@end

@implementation TGPageViewController

- (instancetype)initWithTemplate:(TGPageTemplate *)page {
	TGPageChrome chrome = TGPageChromeFor(page, NO);
	self = [super initWithStyle:chrome.grouped ? UITableViewStyleGrouped
											   : UITableViewStylePlain];
	if (!self)
		return nil;
	_page = page;
	_chrome = chrome;
	self.pageKind = page.kind;
	self.whiteRowsOnPage = chrome.whiteRowsOnPage;
	self.emptyTitle = page.emptyTitle;
	self.emptySubtitle = page.emptySubtitle;
	_bottomActionEnabled = YES;
	self.checksSectionIcons = YES;
	self.title = page.title.length ? TGLocalized(page.title) : nil;
	if (chrome.titleInBar){
		// Set before the push: on iOS 6 hidesBackButton alone let Back
		// come back over the field; a left item replaces it outright.
		self.navigationItem.hidesBackButton = YES;
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
				initWithCustomView:[[UIView alloc] initWithFrame:CGRectZero]];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	BOOL firstInSheet = self.navigationController.viewControllers.firstObject == self
			&& self.navigationController.presentingViewController != nil;
	self.chrome = TGPageChromeFor(self.page, firstInSheet);
	[self buildBarItems];
	[self buildTopStack];
	[self applyTheme];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (self.chrome.bottomBar)
		[self.navigationController setToolbarHidden:NO animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (self.chrome.bottomBar)
		[self.navigationController setToolbarHidden:YES animated:animated];
}

#pragma mark - chrome

- (void)buildBarItems {
	TGPageChrome c = self.chrome;
	if (c.leftItem == TGPageLeftClose)
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
				initWithTitle:TGLocalized(@"Close") style:UIBarButtonItemStyleBordered
					   target:self action:@selector(closeTapped)];
	if (c.rightItem)
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
				initWithTitle:TGLocalized(self.page.barActionTitle)
						style:UIBarButtonItemStyleDone
					   target:self action:@selector(barActionTapped)];
	if (c.titleInBar){
		self.searchBar = [self makeSearchBar];
		self.navigationItem.titleView = self.searchBar;
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
				initWithTitle:TGLocalized(@"Cancel") style:UIBarButtonItemStyleBordered
					   target:self action:@selector(closeTapped)];
	}
	if (c.bottomBar){
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		[button setTitle:TGLocalized(self.page.bottomActionTitle)
				forState:UIControlStateNormal];
		[TGTheme applySkeuomorphicStyleToButton:button style:TGButtonStyleAction];
		button.frame = CGRectMake(0, 0, TGMetricScreenWidth - TGDoubled(TGMetricPadMedium),
				TGMetricButtonHeightSmall);
		[button addTarget:self action:@selector(bottomActionTapped)
		 forControlEvents:UIControlEventTouchUpInside];
		button.enabled = self.bottomActionEnabled;
		self.bottomButton = button;
		UIBarButtonItem *flex = [[UIBarButtonItem alloc]
				initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
									 target:nil action:nil];
		self.toolbarItems = @[flex, [[UIBarButtonItem alloc] initWithCustomView:button], flex];
	}
}

/// Above the rows, top to bottom: the page header, the search, the scopes.
/// One table header holds them so they scroll away together.
- (void)buildTopStack {
	TGPageChrome c = self.chrome;
	CGFloat width = self.tableView.bounds.size.width ?: TGMetricScreenWidth;
	UIView *stack = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 0)];
	stack.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	CGFloat y = 0;
	if (c.header){
		TGPageTemplate *p = self.page;
		self.header = [[TGPageHeaderView alloc] initWithWidth:width
				artSide:p.headerArtSide
				  title:p.headerTitle.length ? TGLocalized(p.headerTitle) : nil
			   subtitle:p.headerSubtitle.length ? TGLocalized(p.headerSubtitle) : nil
				   text:p.headerText.length ? TGLocalized(p.headerText) : nil];
		self.header.imageView.image = self.headerArt;
		[stack addSubview:self.header];
		y = CGRectGetMaxY(self.header.frame);
	}
	if (c.searchInList){
		self.searchBar = [self makeSearchBar];
		self.searchBar.frame = CGRectMake(0, y, width, TGMetricRow);
		[stack addSubview:self.searchBar];
		y += TGMetricRow;
	}
	if (c.scopes){
		self.scopeStrip = [[UIToolbar alloc] initWithFrame:CGRectMake(0, y, width,
				TGMetricSearchScopeRow)];
		self.scopeStrip.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		UISegmentedControl *segments = TGBarSegments(self.page.scopeTitles);
		segments.selectedSegmentIndex = self.selectedScope;
		segments.frame = CGRectMake(TGMetricPad, TGCenteredOrigin(TGMetricSearchScopeRow,
				TGMetricSearchScopeHeight), width - TGDoubled(TGMetricPad),
				TGMetricSearchScopeHeight);
		segments.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[segments addTarget:self action:@selector(scopeChanged:)
		   forControlEvents:UIControlEventValueChanged];
		[self.scopeStrip addSubview:segments];
		self.scopeSegments = segments;
		[stack addSubview:self.scopeStrip];
		y += TGMetricSearchScopeRow;
	}
	if (y <= 0)
		return;
	stack.frame = CGRectMake(0, 0, width, y);
	self.tableView.tableHeaderView = stack;
}

- (UISearchBar *)makeSearchBar {
	UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0,
			TGMetricScreenWidth, TGMetricRow)];
	bar.delegate = self;
	bar.placeholder = TGLocalized(self.page.searchPlaceholder ?: @"Search");
	bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	return bar;
}

- (void)applyTheme {
	[super applyTheme];
	TGTheme *theme = [TGTheme shared];
	if (self.chrome.whiteRowsOnPage &&
			[self.tableView.backgroundView isMemberOfClass:UIView.class])
		self.tableView.backgroundView.backgroundColor = [theme groupedBackgroundColour];
	if (self.chrome.titleInBar)
		[theme styleNavigationSearchBar:self.searchBar];
	else
		[theme styleSearchBar:self.searchBar];
	if (self.scopeStrip)
		[theme styleBarStrip:self.scopeStrip segments:self.scopeSegments];
	[self.header applyTheme];
	if (self.chrome.bottomBar){
		UIToolbar *toolbar = self.navigationController.toolbar;
		toolbar.barStyle = [theme isDark] ? UIBarStyleBlack : UIBarStyleDefault;
		toolbar.tintColor = [theme barColour];
	}
}

#pragma mark - content

- (void)setSections:(NSArray *)sections {
	// A settings page with an intro opens with it, ahead of the screen's own
	// sections, so every such page places it the same way.
	NSArray *shown = sections ?: @[];
	if (self.page.introText.length){
		NSMutableDictionary *intro = TGPageHeaderRow(nil, nil, self.page.introText);
		if (self.page.introIcon.length)
			intro[TGRowIcon] = self.page.introIcon;
		shown = [@[TGSection(nil, nil, @[intro])] arrayByAddingObjectsFromArray:shown];
	}
	// The empty state is TGRowsViewController's; the intro row does not
	// count as content there.
	[super setSections:shown];
}

- (void)setHeaderArt:(UIImage *)headerArt {
	_headerArt = headerArt;
	self.header.imageView.image = headerArt;
}

- (void)setBottomActionEnabled:(BOOL)enabled {
	_bottomActionEnabled = enabled;
	self.bottomButton.enabled = enabled;
}

- (void)setSelectedScope:(NSInteger)selectedScope {
	_selectedScope = selectedScope;
	self.scopeSegments.selectedSegmentIndex = selectedScope;
}

#pragma mark - actions

- (void)closeTapped {
	if (self.navigationController.viewControllers.firstObject == self &&
			self.navigationController.presentingViewController)
		[self.navigationController dismissViewControllerAnimated:YES completion:nil];
	else
		[self.navigationController popViewControllerAnimated:YES];
}

- (void)barActionTapped {
	if (self.onBarAction)
		self.onBarAction();
}

- (void)bottomActionTapped {
	if (self.onBottomAction)
		self.onBottomAction();
}

- (void)scopeChanged:(UISegmentedControl *)segments {
	_selectedScope = segments.selectedSegmentIndex;
	if (self.onScope)
		self.onScope(segments.selectedSegmentIndex);
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)query {
	if (self.onSearch)
		self.onSearch(query);
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

@end
