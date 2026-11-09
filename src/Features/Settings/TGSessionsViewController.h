//
// TGSessionsViewController - other devices signed into this account.
//
#ifndef TGSESSIONSVIEWCONTROLLER_H
#define TGSESSIONSVIEWCONTROLLER_H

#import <Foundation/Foundation.h>
#import "TGLocalization.h"

/// Row text from the getActiveSessions answer, kept as data so the host tests
/// can pin the order the list shows.
static inline NSString *TGSessionRowTitle(NSDictionary *session) {
	return session[@"name"] ?: @"Loading...";
}

static inline NSString *TGSessionRowDetail(NSDictionary *session, BOOL isCurrent) {
	NSMutableArray *parts = [NSMutableArray array];
	if ([session[@"platform"] length])
		[parts addObject:session[@"platform"]];
	if ([session[@"ip"] length])
		[parts addObject:session[@"ip"]];
	if (isCurrent)
		[parts addObject:@"online"];
	if ([session[@"isUnconfirmed"] boolValue])
		[parts addObject:@"Confirm"];
	return [parts componentsJoinedByString:@" · "];
}

/// The names under ACTIVE SESSIONS, including the honest empty row.
static inline NSArray *TGSessionOtherTitles(NSArray *sessions) {
	NSMutableArray *names = [NSMutableArray array];
	for (NSDictionary *session in sessions)
		if (![session[@"isCurrent"] boolValue] &&
			![session[@"isUnconfirmed"] boolValue])
			[names addObject:TGSessionRowTitle(session)];
	return names.count ? names : @[@"No other sessions"];
}

/// The names under INCOMPLETE LOGIN ATTEMPTS, in server order.
static inline NSArray *TGSessionUnconfirmedTitles(NSArray *sessions) {
	NSMutableArray *names = [NSMutableArray array];
	for (NSDictionary *session in sessions)
		if (![session[@"isCurrent"] boolValue] &&
			[session[@"isUnconfirmed"] boolValue])
			[names addObject:TGSessionRowTitle(session)];
	return names;
}

/// The TTL is a span, not a number of days.
static inline NSString *TGSessionTtlDetail(NSInteger days, BOOL loaded) {
	if (!loaded)
		return @"...";
	if (days <= 0)
		return @"Disabled";
	if (days == 7)
		return TGLocalizedPluralValue(@"%@ week", @"%@ weeks", @"1", 1);
	if (days == 180)
		return TGLocalizedPluralValue(@"%@ month", @"%@ months", @"6", 6);
	if (days == 365 || days == 366)
		return TGLocalizedPluralValue(@"%@ year", @"%@ years", @"1", 1);
	if (days == 30)
		return TGLocalizedPluralValue(@"%@ month", @"%@ months", @"1", 1);
	if (days == 90)
		return TGLocalizedPluralValue(@"%@ month", @"%@ months", @"3", 3);
	return TGLocalizedPluralValue(@"%@ day", @"%@ days",
			[NSString stringWithFormat:@"%ld", (long)days], days);
}

/// Every row title in the order the screen stacks its sections.
static inline NSArray *TGSessionRowTitles(NSArray *sessions, BOOL ttlLoaded) {
	(void)ttlLoaded;
	NSMutableArray *titles = [NSMutableArray array];
	NSDictionary *current = nil;
	NSMutableArray *allOthers = [NSMutableArray array];
	for (NSDictionary *session in sessions){
		if ([session[@"isCurrent"] boolValue])
			current = session;
		else
			[allOthers addObject:session];
	}
	[titles addObject:TGSessionRowTitle(current)];
	if (allOthers.count)
		[titles addObject:@"Terminate all other sessions"];
	[titles addObjectsFromArray:TGSessionUnconfirmedTitles(sessions)];
	[titles addObjectsFromArray:TGSessionOtherTitles(sessions)];
	[titles addObject:@"Active Websites"];
	[titles addObject:@"Scan QR Code"];
	[titles addObject:@"If Away For"];
	return titles;
}

#ifndef TGROW_MODELS_ONLY
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGSessionsViewController : TGRowsViewController
@end
#endif

#endif // TGSESSIONSVIEWCONTROLLER_H
