//
// TGCountryPickerViewController.m
//
#import "TGCountryPickerViewController.h"
#import "TGLoginLogic.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGStyle.h"
#import "TGIcons.h"

@interface TGCountryPickerViewController () <UISearchBarDelegate>
@property (nonatomic, copy) NSArray *countries;
@property (nonatomic, copy) void (^picked)(NSDictionary *country);
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, copy) NSArray *indexTitles;
@end

@implementation TGCountryPickerViewController

- (instancetype)initWithCountries:(NSArray *)countries
						   picked:(void (^)(NSDictionary *country))picked {
	self = [super initWithStyle:UITableViewStylePlain];
	if (self){
		_countries = [countries copy];
		_picked = [picked copy];
	}
	return self;
}

- (void)applyTheme {
	[super applyTheme];
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Country");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	[self applyTheme];

	self.searchBar = [[UISearchBar alloc] initWithFrame:
			CGRectMake(0, 0, self.tableView.bounds.size.width, TGMetricSearchBarHeight)];
	self.searchBar.placeholder = TGLocalized(@"Search");
	self.searchBar.delegate = self;
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[[TGTheme shared] styleSearchBar:self.searchBar];
	self.tableView.tableHeaderView = self.searchBar;

	[self rebuildForQuery:@""];
}

- (void)rebuildForQuery:(NSString *)query {
	NSArray *groups = TGCountrySections(self.countries, query);
	NSMutableArray *sections = [NSMutableArray arrayWithCapacity:groups.count];
	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:groups.count];
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *group in groups){
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *country in group[@"countries"]){
			NSMutableDictionary *row = [TGTapRow(TGCountryRowTitle(country),
					country[@"prefix"], ^{ [weakSelf pick:country]; }) mutableCopy];
			UIImage *flag = [TGIcons emojiGlyph:country[@"flag"] side:TGMetricRowIconSide];
			if (flag)
				row[TGRowAvatarImage] = flag;
			[rows addObject:row];
		}
		NSString *letter = group[@"title"];
		[sections addObject:TGSection(letter.length ? letter : nil, nil, rows)];
		if (letter.length)
			[titles addObject:letter];
	}
	self.indexTitles = titles;
	self.sections = sections;
	[self reloadRows];
}

- (void)pick:(NSDictionary *)country {
	void (^picked)(NSDictionary *) = self.picked;
	[self.searchBar resignFirstResponder];
	[self.navigationController popViewControllerAnimated:YES];
	if (picked)
		picked(country);
}

#pragma mark - index and search

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	(void)tableView;
	return self.indexTitles.count ? self.indexTitles : nil;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title
			   atIndex:(NSInteger)index {
	(void)tableView; (void)title;
	return index;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	(void)searchBar;
	[self rebuildForQuery:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

@end
