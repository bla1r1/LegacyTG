// TGAccountPrivacyRowsTests.m - the row text of the settings-shaped screens.
//
// Each screen below built its rows inside a view controller, where a host
// test cannot reach them. These pure helpers are the data the screen now
// feeds to TGRows; the checks pin order, fallbacks and the words official
// uses.
#define TGROW_MODELS_ONLY 1
#import "TGTestRunner.h"
#import "TGSessionsViewController.h"
#import "TGWebsitesViewController.h"
#import "TGPrivacyRuleViewController.h"
#import "TGTextStylesViewController.h"
#import "TGAdminRightsViewController.h"
#import "TGSimilarChannelsViewController.h"
#import "TGLocalization.h"

@interface TGAccountPrivacyRowsTests : XCTestCase @end

@implementation TGAccountPrivacyRowsTests

- (void)setUp {
	[super setUp];
	TGSetAppLanguage(nil);
	TGSetTelegramLanguageLookup(nil);
	TGSetTelegramLanguagePlurals(nil);
}

- (void)tearDown {
	TGSetTelegramLanguageLookup(nil);
	TGSetTelegramLanguagePlurals(nil);
	TGSetAppLanguage(nil);
	[super tearDown];
}

#pragma mark - sessions

- (void)testSessions_CurrentFirstThenOthersWebsitesAndTtl {
	NSDictionary *current = @{@"name" : @"iPhone", @"platform" : @"iOS",
			@"ip" : @"1.2.3.4", @"isCurrent" : @YES};
	NSDictionary *other = @{@"name" : @"Mac", @"platform" : @"macOS",
			@"ip" : @"5.6.7.8"};
	NSArray *titles = TGSessionRowTitles(@[current, other], YES);
	XCTAssertEqualObjects(titles, (@[@"iPhone",
			@"Terminate all other sessions", @"Mac", @"Active Websites",
			@"Scan QR Code", @"If Away For"]));
}

- (void)testSessions_EmptyListKeepsTheHonestLoadingAndEmptyRows {
	NSArray *titles = TGSessionRowTitles(@[], NO);
	XCTAssertEqualObjects(titles, (@[@"Loading...", @"No other sessions",
			@"Active Websites", @"Scan QR Code", @"If Away For"]));
}

- (void)testSessions_DetailAndTtlUseTheirOfficialShape {
	NSDictionary *current = @{@"name" : @"iPhone", @"platform" : @"iOS",
			@"ip" : @"1.2.3.4", @"isCurrent" : @YES};
	NSDictionary *pending = @{@"name" : @"New login",
			@"platform" : @"Android", @"isUnconfirmed" : @YES};
	XCTAssertEqualObjects(TGSessionRowDetail(current, YES),
			@"iOS · 1.2.3.4 · online");
	XCTAssertEqualObjects(TGSessionRowDetail(pending, NO), @"Android · Confirm");
	XCTAssertEqualObjects(TGSessionUnconfirmedTitles(@[current, pending]),
			(@[@"New login"]));
	XCTAssertEqualObjects(TGSessionOtherTitles(@[current, pending]),
			(@[@"No other sessions"]));
	XCTAssertEqualObjects(TGSessionTtlDetail(0, YES), @"Disabled");
	XCTAssertEqualObjects(TGSessionTtlDetail(180, YES), @"6 months");
	XCTAssertEqualObjects(TGSessionTtlDetail(365, YES), @"1 year");
	XCTAssertEqualObjects(TGSessionTtlDetail(0, NO), @"...");
}

#pragma mark - websites

- (void)testWebsites_EmptyStatesAndDomainOrder {
	XCTAssertEqualObjects(TGWebsiteEmptyTitle(@[], NO, nil), @"Loading...");
	XCTAssertEqualObjects(TGWebsiteEmptyTitle(@[], YES, nil), @"None");
	XCTAssertEqualObjects(TGWebsiteEmptyTitle(@[], YES, @"No access"),
			@"No access");
	NSArray *sites = @[@{@"domain" : @"a.com"}, @{@"domain" : @"b.com"}];
	XCTAssertEqualObjects(TGWebsiteRowTitles(sites, YES, nil),
			(@[@"a.com", @"b.com"]));
}

- (void)testWebsites_DetailIsBrowserPlaceAddressThenDate {
	NSDictionary *site = @{@"browser" : @"Safari", @"platform" : @"iOS",
			@"location" : @"Kyiv", @"ip" : @"1.1.1.1", @"lastActive" : @0};
	XCTAssertEqualObjects(TGWebsiteDetail(site),
			@"Safari iOS · Kyiv · 1.1.1.1 · —");
}

#pragma mark - privacy rule

- (void)testPrivacyRule_OptionsAndExceptionCounts {
	XCTAssertEqualObjects(TGPrivacyRuleRowTitles(@"contacts", 1, 2),
			(@[@"Everybody", @"My Contacts", @"Nobody", @"Always Allow",
			@"Never Allow"]));
	XCTAssertEqualObjects(TGPrivacyExceptionDetail(0), @"Never");
	XCTAssertEqualObjects(TGPrivacyExceptionDetail(1), @"1 user");
	XCTAssertEqualObjects(TGPrivacyExceptionDetail(2), @"2 users");
}

#pragma mark - text styles

- (void)testTextStyles_TitleAndWhoOwnsTheStyle {
	NSArray *styles = @[
		@{@"title" : @"Bold", @"prompt" : @"Make it bold"},
		@{@"name" : @"Plain", @"isCreator" : @YES},
		@{@"name" : @"Telegram"},
	];
	XCTAssertEqualObjects(TGTextStyleRowTitles(styles),
			(@[@"Bold", @"Plain", @"Telegram"]));
	XCTAssertEqualObjects(TGTextStyleRowDetail(styles[0]), @"Make it bold");
	XCTAssertEqualObjects(TGTextStyleRowDetail(styles[1]), @"Created by you");
	XCTAssertEqualObjects(TGTextStyleRowDetail(styles[2]), @"Telegram style");
}

#pragma mark - admin rights

- (void)testAdminRights_PresetLabelsAndGroupChannelOrder {
	XCTAssertEqualObjects(TGAdminPresetLabel(@"readonly"), @"Read-Only Mode");
	XCTAssertEqualObjects(TGAdminPresetLabel(@"standard"), @"Default");
	XCTAssertEqualObjects(TGAdminPresetLabel(@"posting"), @"Posting Members");
	XCTAssertEqualObjects(TGAdminPresetLabel(@"full"), @"Admin");
	XCTAssertEqualObjects(TGAdminPresetLabel(nil), @"Default");
	XCTAssertEqualObjects(TGAdminRightsRowTitles(),
			(@[@"Admin Rights", @"Admin Rights"]));
	XCTAssertEqualObjects(TGAdminRightsRowDetails(@"full", nil),
			(@[@"Admin", @"Default"]));
}

#pragma mark - similar channels

- (void)testSimilarChannels_TitleDetailAndOrder {
	NSArray *items = @[@{@"id" : @1, @"title" : @"News"}, @2];
	NSDictionary *details = @{
		@1 : @{@"title" : @"News HD", @"member_count" : @120},
		@2 : @{@"member_count" : @0},
	};
	XCTAssertEqualObjects(TGSimilarChannelRowTitles(items, details),
			(@[@"News HD", @"Channel"]));
	XCTAssertEqualObjects(TGSimilarChannelDetail(items[0], details[@1]),
			@"120 subscribers");
	XCTAssertEqualObjects(TGSimilarChannelDetail(nil, details[@2]),
			@"Channel");
	XCTAssertEqualObjects(TGSimilarChannelDetail(@{@"members" : @5}, @{}),
			@"5 subscribers");
}

@end
