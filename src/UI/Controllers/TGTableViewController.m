#import "TGTableViewController.h"
#import "TGTheme.h"
#import "TGEmptyView.h"

@interface TGTableViewController ()
@property (nonatomic, strong) TGEmptyView *tg_emptyView;
@end

@implementation TGTableViewController

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

- (void)tg_baseThemeDidChange:(NSNotification *)note {
	[self applyTheme];
	[self.tableView reloadData];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	[theme styleNavigationBar:self.navigationController.navigationBar];
	if (self.tableView.style == UITableViewStyleGrouped) {
		[theme styleGroupedTable:self.tableView];
	} else {
		self.tableView.backgroundColor = [theme listBackgroundColour];
		self.tableView.separatorColor = [theme separatorColour];
	}
}

- (void)showEmptyWithImage:(UIImage *)image title:(NSString *)title subtitle:(NSString *)subtitle {
	self.tg_emptyView = [TGEmptyView emptyViewWithFrame:self.tableView.bounds
												 image:image
												 title:title
											  subtitle:subtitle
										   buttonTitle:nil
												target:nil
												action:nil];
	self.tableView.backgroundView = self.tg_emptyView;
}

- (void)hideEmpty {
	self.tableView.backgroundView = nil;
	self.tg_emptyView = nil;
}

@end
