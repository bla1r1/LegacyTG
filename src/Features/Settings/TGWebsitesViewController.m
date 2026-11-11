//
// TGWebsitesViewController.m - Devices -> Connected Websites.
//
// The list is the account's own login record, not a browser: each row is a
// site that asked a bot to vouch for the account and was let in. Signing one
// out is the only write here; the page re-reads the list afterwards because
// the site itself loses its token on its next request, not on this tap.
//
#import "TGWebsitesViewController.h"
#import "TGAlertSheet.h"
#import "TGStyle.h"
#import "TGRows.h"
#import "TGAccountStore.h"


@interface TGWebsitesViewController ()
@property (nonatomic, strong) NSArray *sites;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) NSString *readError;
@end

@implementation TGWebsitesViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Active Websites";
	[self refresh];
}

- (void)refresh {
	__weak typeof(self) weakSelf = self;
	[[TGAccountStore shared] connectedWebsitesWithCompletion:^(NSArray *sites, NSString *error){
		weakSelf.sites = sites ?: @[];
		weakSelf.readError = error;
		weakSelf.loaded = YES;
		[weakSelf rebuildSections];
	}];
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *sections = [NSMutableArray array];

	if (!self.sites.count){
		NSString *title = TGWebsiteEmptyTitle(self.sites, self.loaded,
				self.readError);
		NSString *header = (self.sites.count || self.readError)
				? @"Active Websites" : nil;
		[sections addObject:TGSection(header, nil, @[
			TGTapRow(title, nil, nil),
		])];
	} else {
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *site in self.sites){
			NSMutableDictionary *row = [TGSubtitleRow(site[@"domain"] ?: @"?",
					TGWebsiteDetail(site),
					^{ [weakSelf showActionsForSite:site]; }) mutableCopy];
			row[TGRowDetailLines] = @2;
			row[TGRowHeight] = @(TGMetricPersonRow);
			[rows addObject:row];
		}
		[sections addObject:TGSection(@"Active Websites", nil, rows)];
		[sections addObject:TGSection(@"Websites", nil, @[
			TGRedRow(@"Disconnect All Websites", ^{ [weakSelf confirmDisconnectAll]; }),
		])];
	}

	self.sections = sections;
	[self reloadRows];
}

#pragma mark - actions

- (void)confirmDisconnectAll {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:@"Disconnect All Websites"
					   action:@"Disconnect All"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGAccountStore shared] disconnectAllWebsitesWithCompletion:^(BOOL ok,
																 NSString *error){
			[weakSelf answer:ok error:error title:@"Active Websites"];
		}];
	}];
}

- (void)showActionsForSite:(NSDictionary *)site {
	int64_t websiteId = [site[@"id"] longLongValue];
	if (!websiteId)
		return;

	NSString *domain = site[@"domain"] ?: @"this website";
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Log Out"]
						title:domain
					  message:TGWebsiteDetail(site)
			 destructiveIndex:0
					   inView:self.view
					 onChoice:^(NSInteger index){
		[TGAlertSheet showConfirm:nil
							title:@"Log Out"
						   action:@"Log Out"
					  destructive:YES
						   inView:weakSelf.view
						onConfirm:^{
			[[TGAccountStore shared] disconnectWebsite:websiteId
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
