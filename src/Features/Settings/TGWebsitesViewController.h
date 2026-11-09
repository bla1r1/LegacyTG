//
// TGWebsitesViewController.h - the sites signed in through a bot.
//
#ifndef TGWEBSITESVIEWCONTROLLER_H
#define TGWEBSITESVIEWCONTROLLER_H

#import <Foundation/Foundation.h>

/// When the site last used its token, as a short date. A site that never did
/// is not a parse failure; it is one that signed in and did nothing.
static inline NSString *TGWebsiteWhen(NSNumber *seconds) {
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

/// The line under a site's domain: browser, platform, place, address, then
/// when it was last used.
static inline NSString *TGWebsiteDetail(NSDictionary *site) {
	NSMutableArray *parts = [NSMutableArray array];
	NSString *browser = site[@"browser"];
	NSString *platform = site[@"platform"];
	NSString *where = site[@"location"];
	if (browser.length || platform.length)
		[parts addObject:[NSString stringWithFormat:@"%@ %@",
				browser ?: @"", platform ?: @""]];
	if (where.length)
		[parts addObject:where];
	NSString *ip = site[@"ip"];
	if (ip.length)
		[parts addObject:ip];
	[parts addObject:TGWebsiteWhen(site[@"lastActive"])];
	return [parts componentsJoinedByString:@" · "];
}

/// The only row in the first section before the list arrives, or when it is
/// empty or refused.
static inline NSString *TGWebsiteEmptyTitle(NSArray *sites, BOOL loaded,
		NSString *readError) {
	if (sites.count)
		return nil;
	if (readError.length)
		return readError;
	return loaded ? @"None" : @"Loading...";
}

/// The domain on each site row, in server order.
static inline NSArray *TGWebsiteRowTitles(NSArray *sites, BOOL loaded,
		NSString *readError) {
	NSMutableArray *titles = [NSMutableArray array];
	if (!sites.count){
		NSString *empty = TGWebsiteEmptyTitle(sites, loaded, readError);
		if (empty)
			[titles addObject:empty];
		return titles;
	}
	for (NSDictionary *site in sites)
		[titles addObject:site[@"domain"] ?: @"?"];
	return titles;
}

#ifndef TGROW_MODELS_ONLY
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGWebsitesViewController : TGRowsViewController
@end
#endif

#endif // TGWEBSITESVIEWCONTROLLER_H
