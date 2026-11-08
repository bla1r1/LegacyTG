//
// TGWebsitesViewController.m - Devices -> Connected Websites.
//
// The list is the account's own login record, not a browser: each row is a
// site that asked a bot to vouch for the account and was let in. Signing one
// out is the only write here; the page re-reads the list afterwards because
// the site itself loses its token on its next request, not on this tap.
//
#import "TGWebsitesViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGAlertSheet.h"
#import "TGStyle.h"

@interface TGWebsitesViewController ()
@property (nonatomic, strong) NSArray *sites;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) NSString *readError;
@end

@implementation TGWebsitesViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Active Websites";
	self.tableView.rowHeight = TGMetricPersonRow;
	[self applyTheme];
	[self refresh];

}

- (void)applyTheme {
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)refresh {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] connectedWebsitesWithCompletion:^(NSArray *sites, NSString *error){
		weakSelf.sites = sites ?: @[];
		weakSelf.readError = error;
		weakSelf.loaded = YES;
		[weakSelf.tableView reloadData];
	}];
}

/// When the site last used its token, as a short date. A site that never did
/// is not a parse failure; it is one that signed in and did nothing.
static NSString *TGWebsiteWhen(NSNumber *seconds) {
	NSTimeInterval stamp = seconds.doubleValue;
	if (stamp <= 0)
		return @"—";
	static NSDateFormatter *formatter = nil;
	if (!formatter){
		formatter = [[NSDateFormatter alloc] init];
		formatter.dateStyle = NSDateFormatterShortStyle;
		formatter.timeStyle = NSDateFormatterShortStyle;
	}
	return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:stamp]];
}

- (NSString *)detailForSite:(NSDictionary *)site {
	NSMutableArray *parts = [NSMutableArray array];
	NSString *browser = site[@"browser"];
	NSString *platform = site[@"platform"];
	NSString *where = site[@"location"];
	if (browser.length || platform.length)
		[parts addObject:[NSString stringWithFormat:@"%@ %@", browser ?: @"", platform ?: @""]];
	if (where.length)
		[parts addObject:where];
	NSString *ip = site[@"ip"];
	if (ip.length)
		[parts addObject:ip];
	[parts addObject:TGWebsiteWhen(site[@"lastActive"])];
	return [parts componentsJoinedByString:@" · "];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (!self.loaded)
		return 1;
	return self.sites.count ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 1)
		return @"Websites";
	return self.sites.count || self.readError ? @"Active Websites" : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 1)
		return 1;
	if (self.sites.count || self.loaded)
		return self.sites.count ? self.sites.count : 1;
	return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"site"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"site"];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.textAlignment = NSTextAlignmentLeft;
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];

	if (indexPath.section == 1){
		cell.textLabel.text = @"Disconnect All Websites";
		cell.textLabel.textColor = [[TGTheme shared] destructiveColour];
		cell.detailTextLabel.text = nil;
		cell.textLabel.textAlignment = NSTextAlignmentCenter;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	if (!self.sites.count){
		cell.textLabel.text = self.loaded ? @"None"
				: @"Loading...";
		if (self.readError.length)
			cell.textLabel.text = self.readError;
		cell.detailTextLabel.text = nil;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}

	NSDictionary *site = self.sites[(NSUInteger)indexPath.row];
	cell.textLabel.text = site[@"domain"] ?: @"?";
	cell.detailTextLabel.text = [self detailForSite:site];
	cell.detailTextLabel.numberOfLines = 2;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.section == 1){
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showConfirm:nil
							title:@"Disconnect All Websites"
						   action:@"Disconnect All"
					  destructive:YES
						   inView:self.view
						onConfirm:^{
			[[TGClient shared] disconnectAllWebsitesWithCompletion:^(BOOL ok,
																	 NSString *error){
				[weakSelf answer:ok error:error title:@"Active Websites"];
			}];
		}];
		return;
	}

	if (indexPath.row >= (NSInteger)self.sites.count)
		return;
	NSDictionary *site = self.sites[(NSUInteger)indexPath.row];
	int64_t websiteId = [site[@"id"] longLongValue];
	if (!websiteId)
		return;

	NSString *domain = site[@"domain"] ?: @"this website";
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Log Out"]
						title:domain
					  message:[self detailForSite:site]
			 destructiveIndex:0
					   inView:self.view
					 onChoice:^(NSInteger index){
		[TGAlertSheet showConfirm:nil
							title:@"Log Out"
						   action:@"Log Out"
					  destructive:YES
						   inView:weakSelf.view
						onConfirm:^{
			[[TGClient shared] disconnectWebsite:websiteId
									 completion:^(BOOL ok, NSString *error){
				[weakSelf answer:ok error:error title:domain];
			}];
		}];
	}];
}

/// The server's own sentence when it refuses, and a short confirmation when
/// it agrees. Either way the list is re-read, because a sign-out that was
/// accepted still takes a moment to leave the record.
- (void)answer:(BOOL)ok error:(NSString *)error title:(NSString *)title {
	if (!ok){
		[TGAlertSheet showMessage:(error ?: @"An error occurred.")
							title:title
						   inView:self.view];
		return;
	}
	[self performSelector:@selector(refresh) withObject:nil afterDelay:0.7];
}

@end

// vim:ft=objc
