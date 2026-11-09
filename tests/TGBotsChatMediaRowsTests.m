// TGBotsChatMediaRowsTests.m - the row lists of the Bots/Chat/Media/Dev screens.
//
// Each screen used to decide its rows inside UITableView data source methods,
// where a host test cannot see them. The rows now come from pure functions;
// these checks pin order, fallbacks and the values that change with state.
#define TGROW_MODELS_ONLY 1
#import "TGTestRunner.h"
#import "TGGiftViewController.h"
#import "TGScheduledViewController.h"
#import "TGEphemeralViewController.h"
#import "TGForwardPicker.h"
#import "TGFileInfoViewController.h"
#import "TGDevFileToolsViewController.h"
#import "TGStarsGiftsViewController.h"
#import "TGRows.h"

@interface TGBotsChatMediaRowsTests : XCTestCase @end

static NSArray *BotsChatMediaTitles(NSArray *rows) {
	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:rows.count];
	for (NSDictionary *row in rows)
		[titles addObject:row[@"title"]];
	return titles;
}

@implementation TGBotsChatMediaRowsTests

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

#pragma mark - gift

- (void)testGift_RegularDetailIsDateThenValue {
	XCTAssertEqualObjects(TGGiftDetailRowTitles(@{@"starCount" : @5}),
			(@[@"Date", @"Value"]));
}

- (void)testGift_CollectibleAddsModelSymbolBackdrop {
	XCTAssertEqualObjects(TGGiftDetailRowTitles(@{@"isCollectible" : @YES}),
			(@[@"Date", @"Model", @"Symbol", @"Backdrop"]));
	XCTAssertEqualObjects(TGGiftDetailRowTitles(@{
		@"isCollectible" : @YES,
		@"valueAmount" : @100,
		@"valueCurrency" : @"USD",
	}), (@[@"Date", @"Model", @"Symbol", @"Backdrop", @"Value"]));
}

#pragma mark - scheduled messages

- (void)testScheduled_UsesTheMessageTextAndFallsBackToMessage {
	NSTimeInterval now = 1700000000;
	NSArray *models = TGScheduledRowModels(@[
		@{@"text" : @"Ship it", @"date" : @(now + 7200)},
		@{@"date" : @(now + 7200)},
	], now);
	XCTAssertEqualObjects(BotsChatMediaTitles(models), (@[@"Ship it", @"Message"]));
	XCTAssertTrue([models[0][@"detail"] length] > 0);
	XCTAssertEqualObjects(models[0][@"detail"],
			TGScheduledRowDetail(now + 7200, now));
}

#pragma mark - ephemeral

- (void)testEphemeral_ActionOrderAndStateFallbacks {
	XCTAssertEqualObjects(TGEphemeralActionTitles(), (@[
		@"Send Message", @"Edit Message", @"Edit Caption", @"Delete Message",
		@"Remove", @"Clear",
	]));
	XCTAssertEqualObjects(TGEphemeralSectionTitles(),
			(@[@"Target", @"Requests", @"Result"]));
	XCTAssertEqualObjects(TGEphemeralReceiverDetail(42), @"42");
	XCTAssertEqualObjects(TGEphemeralReceiverDetail(0), @"Choose a Bot");
	XCTAssertEqualObjects(TGEphemeralReplyDetail(7), @"7");
	XCTAssertEqualObjects(TGEphemeralReplyDetail(0), @"None");
	XCTAssertEqualObjects(TGEphemeralResultDetail(@"hi"), @"Sent: hi");
	XCTAssertNil(TGEphemeralResultDetail(nil));
}

#pragma mark - forward picker

- (void)testForwardPicker_OnlyTheRecentListGetsAHeading {
	XCTAssertEqualObjects(TGForwardPickerSectionHeader(@"", 2),
			@"Recent chats");
	XCTAssertNil(TGForwardPickerSectionHeader(@"an", 2));
	XCTAssertNil(TGForwardPickerSectionHeader(@"", 0));
}

#pragma mark - file info

- (void)testFileInfo_BytesAndDetailOrder {
	XCTAssertEqualObjects(TGFileInfoBytesText(0), @"0 B");
	XCTAssertEqualObjects(TGFileInfoBytesText(512), @"512 B");
	XCTAssertEqualObjects(TGFileInfoBytesText(1536), @"2 KB");
	XCTAssertEqualObjects(TGFileInfoBytesText(1024 * 1024), @"1.0 MB");

	NSArray *rows = TGFileInfoDetailModels(@{
		@"size" : @2048, @"expectedSize" : @4096,
		@"localPath" : @"/tmp/a.txt",
	}, @{@"extension" : @"txt", @"mime" : @"text/plain",
		@"cleanName" : @"a"}, @"a.txt", 1024, YES);
	XCTAssertEqualObjects(BotsChatMediaTitles(rows), (@[
		@"Name", @"Type", @"Clean Name", @"Size", @"Expected Size",
		@"Downloaded", @"Local Path", @"Remote ID",
	]));
	XCTAssertEqualObjects(rows[1][@"detail"], @"txt - text/plain");
	XCTAssertEqualObjects(rows[3][@"detail"], @"2 KB");
	XCTAssertEqualObjects(rows[5][@"detail"], @"1 KB of 2 KB");
	XCTAssertEqualObjects(rows[6][@"detail"], @"/tmp/a.txt");
}

- (void)testFileInfo_ActionsNeedTheLocalBytes {
	XCTAssertEqualObjects(TGFileInfoActionTitles(NO, @""), (@[@"Copy"]));
	XCTAssertEqualObjects(TGFileInfoActionTitles(YES, @"PNG"),
			(@[@"Share", @"Save to Photos", @"Copy", @"Delete"]));
	XCTAssertEqualObjects(TGFileInfoActionTitles(YES, @"pdf"),
			(@[@"Share", @"Copy", @"Delete"]));
}

#pragma mark - dev file tools

- (void)testDevFileTools_ProgressAndResultRows {
	XCTAssertEqualObjects(TGDevFileToolsProgressText(@"Uploading", 0.42f),
			@"Uploading  42%");
	XCTAssertEqualObjects(TGDevFileToolsProgressText(nil, 0.0f), @"Working  0%");

	NSArray *rows = TGDevFileToolsResultModels(@"/tmp/a.txt", 12,
			@"one\ntwo");
	XCTAssertEqualObjects(BotsChatMediaTitles(rows), (@[@"Path", @"Size", @"one two"]));
	XCTAssertEqualObjects(rows[1][@"detail"], @"12 bytes");
}

#pragma mark - stars ledger

- (void)testStarsLedger_KeepsTitleDateAmountAndDirection {
	NSArray *models = TGStarsLedgerRowModels(@[
		@{@"title" : @"Gift Purchase", @"subtitle" : @"1 Jan",
		  @"amount" : @"-5 Stars", @"isOutgoing" : @YES},
		@{@"title" : @"Refund", @"subtitle" : @"2 Jan",
		  @"amount" : @"+5 Stars"},
	]);
	XCTAssertEqualObjects(BotsChatMediaTitles(models),
			(@[@"Gift Purchase", @"Refund"]));
	XCTAssertEqualObjects(models[0][@"amount"], @"-5 Stars");
	XCTAssertTrue([models[0][@"isOutgoing"] boolValue]);
	XCTAssertFalse([models[1][@"isOutgoing"] boolValue]);
}

#pragma mark - shared keys

- (void)testRowKeysAreTheOnesTheScreensSet {
	NSMutableDictionary *row = [TGTapRow(@"note", nil, nil) mutableCopy];
	row[TGRowTitleLines] = @0;
	row[TGRowAccessory] = @"+5 Stars";
	row[TGRowAccessoryColour] = [UIColor redColor];
	XCTAssertEqualObjects(row[TGRowTitleLines], @0);
	XCTAssertEqualObjects(row[TGRowAccessory], @"+5 Stars");
	XCTAssertEqualObjects(row[TGRowAccessoryColour], [UIColor redColor]);
}

@end
