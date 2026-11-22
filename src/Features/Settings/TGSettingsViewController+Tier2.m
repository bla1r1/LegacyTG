//
// TGSettingsViewController+Tier2.m - the Telegram Business row, and in dev builds
// the web proxy carrier, the communities/AI hub and the profile extras.
//
// The rows live in a category so the root list gains calls, not branches:
// a later screen that wants one of them can ask for the same row too.
//
#import "TGSettingsViewController+Tier2.h"
#import "TGSettingsViewControllerInternal.h"
#import "TGBusinessViewController.h"
#import "TGDevWebProxyCarrierViewController.h"
#import "TGDevHubViewController.h"
#import "TGTextStylesViewController.h"
#import "TGDiceViewController.h"

@implementation TGSettingsViewController (Tier2)

- (NSDictionary *)tier2BusinessRow {
	__weak typeof(self) weakSelf = self;
	return TGIconOpenRow(@"Telegram Business", @"briefcase", TGIconTileAzure(), ^{
		TGBusinessViewController *business = [[TGBusinessViewController alloc] init];
		business.hidesBottomBarWhenPushed = YES;
		[weakSelf.navigationController pushViewController:business animated:YES];
	});
}

#if TG_DEV
- (NSDictionary *)tier2ProxyCarrierRow {
	__weak typeof(self) weakSelf = self;
	// Plain rows like the rest of Consoles: two tiles among five rows broke
	// TGRowsSectionIconsConsistent.
	return TGSubtitleOpenRow(@"Web Proxy Carrier",
			@"Carrier messages and errors", ^{
		TGDevWebProxyCarrierViewController *carrier =
				[[TGDevWebProxyCarrierViewController alloc] init];
		carrier.hidesBottomBarWhenPushed = YES;
		[weakSelf.navigationController pushViewController:carrier animated:YES];
	});
}

- (NSDictionary *)tier2ToolsRow {
	__weak typeof(self) weakSelf = self;
	return TGOpenRow(@"Communities and Replies", nil, ^{
		TGDevHubViewController *screen = [[TGDevHubViewController alloc] init];
		screen.hidesBottomBarWhenPushed = YES;
		[weakSelf.navigationController pushViewController:screen animated:YES];
	});
}

- (NSArray *)tier2Sections {
	return @[];
}
#endif

@end

// vim:ft=objc
