//
// TGUpdateStoreTests.m - the M45 query, answer and daily-check rules.
//
// These are the pure functions from TGUpdateStore.h: the bot never has to be
// reached, and no UIKit is involved.
//
#import "TGTestRunner.h"
#import "TGUpdateStore.h"

static NSDictionary *TGUSUpdateResult(NSString *json, NSString *title) {
	return @{
		@"@type" : @"inlineQueryResultArticle",
		@"id" : @"update",
		@"title" : title ?: @"1.3",
		@"description" : json ?: @"",
	};
}

static NSDictionary *TGUSNotesResult(NSString *notes) {
	return @{
		@"@type" : @"inlineQueryResultArticle",
		@"id" : @"notes",
		@"title" : @"Changes",
		@"description" : notes ?: @"",
	};
}

static NSString *TGUSUpdateJSON(NSInteger build, BOOL blocking) {
	return [NSString stringWithFormat:
			@"{\"v\":\"1.3\",\"b\":%ld,\"min_ios\":\"6.0\","
			@"\"blocking\":%@,\"ipa\":\"https://example.test/1.3.ipa\","
			@"\"cydia\":\"cydia://package/org.legacy.itg\",\"notes_b\":%ld}",
			(long)build, blocking ? @"true" : @"false", (long)(build - 1)];
}

@interface TGUpdateStoreTests : XCTestCase
@end

@implementation TGUpdateStoreTests

- (void)testQueryStringHasEveryFieldInOrder {
	NSString *query = TGUpdateQueryString(@"1.2", @"42", @"7.1.2",
			@"iPhone4,1", @"legacy", NO, @"en", YES);
	XCTAssertEqualObjects(query,
			@"lt1 v=1.2 b=42 ios=7.1.2 dev=iPhone4,1 tier=legacy jb=0 lang=en stats=1");
}

- (void)testQueryStringSaysJailbrokenAndStatsOff {
	NSString *query = TGUpdateQueryString(@"1.2", @"42", @"6.1.6",
			@"iPhone3,1", @"vintage", YES, @"uk", NO);
	XCTAssertEqualObjects(query,
			@"lt1 v=1.2 b=42 ios=6.1.6 dev=iPhone3,1 tier=vintage jb=1 lang=uk stats=0");
}

- (void)testQueryStringIsCappedAt256Bytes {
	NSString *device = [@"" stringByPaddingToLength:400
			withString:@"A" startingAtIndex:0];
	NSString *query = TGUpdateQueryString(@"1.2", @"42", @"7.1.2", device,
			@"legacy", NO, @"en", YES);
	NSUInteger bytes = [query lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	XCTAssertLessThanOrEqual(bytes, (NSUInteger)256);
	XCTAssertTrue([query hasPrefix:@"lt1 v=1.2 b=42 ios=7.1.2 dev=AAAA"]);
}

- (void)testQueryStringDoesNotSplitAMultiByteCharacter {
	NSString *language = [@"" stringByPaddingToLength:200
			withString:@"\u044f" startingAtIndex:0];
	NSString *query = TGUpdateQueryString(@"1.2", @"42", @"7.1.2",
			@"iPhone4,1", @"legacy", NO, language, YES);
	NSUInteger bytes = [query lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	XCTAssertLessThanOrEqual(bytes, (NSUInteger)256);
	XCTAssertNotNil([query dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)testParsesUpdateAndNotesResults {
	NSArray *results = @[
		TGUSUpdateResult(TGUSUpdateJSON(45, NO), @"1.3"),
		TGUSNotesResult(@"1.3\n- First change\n- Second change"),
	];
	TGUpdateInfo *info = TGUpdateInfoFromInlineResults(results, 42, 0);
	XCTAssertNotNil(info);
	XCTAssertEqualObjects(info.version, @"1.3");
	XCTAssertEqual(info.build, (NSInteger)45);
	XCTAssertEqualObjects(info.minimumIOS, @"6.0");
	XCTAssertFalse(info.isBlocking);
	XCTAssertEqualObjects(info.ipaURL, @"https://example.test/1.3.ipa");
	XCTAssertEqualObjects(info.cydiaURL, @"cydia://package/org.legacy.itg");
	XCTAssertEqualObjects(info.changelog,
			@"1.3\n- First change\n- Second change");
}

- (void)testParsesUpdateWithoutNotes {
	NSArray *results = @[TGUSUpdateResult(TGUSUpdateJSON(45, YES), @"1.3")];
	TGUpdateInfo *info = TGUpdateInfoFromInlineResults(results, 42, 0);
	XCTAssertNotNil(info);
	XCTAssertTrue(info.isBlocking);
	XCTAssertEqualObjects(info.changelog, @"");
}

- (void)testNoResultsMeansUpToDate {
	XCTAssertNil(TGUpdateInfoFromInlineResults(@[], 42, 0));
	XCTAssertNil(TGUpdateInfoFromInlineResults(
			@[TGUSNotesResult(@"1.3\n- a change")], 42, 0));
	XCTAssertNil(TGUpdateInfoFromInlineResults(nil, 42, 0));
}

- (void)testMalformedUpdateJSONIsIgnored {
	XCTAssertNil(TGUpdateInfoFromInlineResults(
			@[TGUSUpdateResult(@"not json", @"1.3")], 42, 0));
	XCTAssertNil(TGUpdateInfoFromInlineResults(
			@[TGUSUpdateResult(@"{bad", @"1.3")], 42, 0));
	XCTAssertNil(TGUpdateInfoFromInlineResults(
			@[TGUSUpdateResult(@"[1,2,3]", @"1.3")], 42, 0));
	XCTAssertNil(TGUpdateInfoFromInlineResults(
			@[TGUSUpdateResult(@"{\"v\":\"1.3\"}", @"1.3")], 42, 0));
}

- (void)testBuildComparisonUsesB {
	TGUpdateInfo *newer = TGUpdateInfoFromInlineResults(
			@[TGUSUpdateResult(TGUSUpdateJSON(43, NO), @"1.3")], 42, 0);
	XCTAssertNotNil(newer);
	XCTAssertNil(TGUpdateInfoFromInlineResults(
			@[TGUSUpdateResult(TGUSUpdateJSON(42, NO), @"1.3")], 42, 0));
	XCTAssertNil(TGUpdateInfoFromInlineResults(
			@[TGUSUpdateResult(TGUSUpdateJSON(41, NO), @"1.3")], 42, 0));
}

- (void)testSkippedBuildIsIgnoredUnlessBlocking {
	NSArray *skipped = @[TGUSUpdateResult(TGUSUpdateJSON(45, NO), @"1.3")];
	XCTAssertNil(TGUpdateInfoFromInlineResults(skipped, 42, 45));

	NSArray *blocking = @[TGUSUpdateResult(TGUSUpdateJSON(45, YES), @"1.3")];
	XCTAssertNotNil(TGUpdateInfoFromInlineResults(blocking, 42, 45));

	NSArray *nextBuild = @[TGUSUpdateResult(TGUSUpdateJSON(46, NO), @"1.4")];
	XCTAssertNotNil(TGUpdateInfoFromInlineResults(nextBuild, 42, 45));
}

- (void)testDailyDueLogicUsesTheInjectedDates {
	NSDate *now = [NSDate dateWithTimeIntervalSince1970:1000000.0];
	XCTAssertTrue(TGUpdateCheckIsDue(now, nil));
	XCTAssertFalse(TGUpdateCheckIsDue(now,
			[NSDate dateWithTimeInterval:-23.0 * 60.0 * 60.0 sinceDate:now]));
	XCTAssertTrue(TGUpdateCheckIsDue(now,
			[NSDate dateWithTimeInterval:-25.0 * 60.0 * 60.0 sinceDate:now]));
	XCTAssertTrue(TGUpdateCheckIsDue(now,
			[NSDate dateWithTimeInterval:-24.0 * 60.0 * 60.0 sinceDate:now]));
	XCTAssertFalse(TGUpdateCheckIsDue(now,
			[NSDate dateWithTimeInterval:60.0 * 60.0 sinceDate:now]));
}

@end
