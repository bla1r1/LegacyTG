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
	self.view.backgroundColor = (self.tableView.style == UITableViewStyleGrouped)
			? [theme groupedBackgroundColour]
			: [theme listBackgroundColour];
	[theme styleNavigationBar:self.navigationController.navigationBar];
	if (self.tableView.style == UITableViewStyleGrouped) {
		[theme styleGroupedTable:self.tableView];
	} else {
		[theme stylePlainTable:self.tableView];
	}
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	TGTheme *theme = [TGTheme shared];
	if ([theme isDark]) {
		UIColor *bg = (tableView.style == UITableViewStyleGrouped)
				? [theme cardBackgroundColour]
				: [theme listBackgroundColour];
		if (!cell.backgroundColor || [cell.backgroundColor isEqual:[UIColor whiteColor]]) {
			cell.backgroundColor = bg;
		}
		if (!cell.contentView.backgroundColor || [cell.contentView.backgroundColor isEqual:[UIColor whiteColor]]) {
			cell.contentView.backgroundColor = bg;
		}
		if (cell.backgroundView && (!cell.backgroundView.backgroundColor || [cell.backgroundView.backgroundColor isEqual:[UIColor whiteColor]])) {
			cell.backgroundView.backgroundColor = bg;
		}
		if (!cell.selectedBackgroundView) {
			UIView *sel = [[UIView alloc] init];
			sel.backgroundColor = [theme inputBarColour];
			cell.selectedBackgroundView = sel;
		}
	}
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
	[[TGTheme shared] styleHeaderFooterView:view];
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
	[[TGTheme shared] styleHeaderFooterView:view];
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
