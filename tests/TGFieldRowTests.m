// TGFieldRowTests.m - the shared field row's data, limit and rebuild rules.
//
// The counter is official's, not an always-on "used / max": it appears past
// 70% of the limit and counts what is left. A section rebuild keeps whatever
// the user has typed, keyed by the field's stable identifier.
#import "TGTestRunner.h"
#import "TGRows.h"

@interface TGFieldRowTests : XCTestCase @end

@implementation TGFieldRowTests

- (void)testFieldRowCarriesPlaceholderTextAndBlock {
	__block NSString *last = nil;
	NSMutableDictionary *row = TGFieldRow(@"First Name", @"Ann", ^(NSString *text){
		last = text;
	});
	XCTAssertEqualObjects(row[TGRowKind], TGKindField);
	XCTAssertEqualObjects(row[TGRowFieldPlaceholder], @"First Name");
	XCTAssertEqualObjects(row[TGRowFieldText], @"Ann");
	XCTAssertNotNil(row[TGRowFieldChanged]);
	((void (^)(NSString *))row[TGRowFieldChanged])(@"Bob");
	XCTAssertEqualObjects(last, @"Bob");
}

- (void)testMultilineRowHasItsOwnKindAndKeepsTheCounterInputs {
	NSMutableDictionary *row = TGMultilineFieldRow(@"Bio", @"hello", nil);
	XCTAssertEqualObjects(row[TGRowKind], TGKindMultilineField);
	XCTAssertEqualObjects(row[TGRowFieldText], @"hello");
	row[TGRowFieldMaxLength] = @(70);
	XCTAssertEqualObjects(row[TGRowFieldMaxLength], @(70));
}

- (void)testLimitIsInclusiveAndZeroIsUnlimited {
	XCTAssertTrue(TGFieldTextWithinLimit(@"12345", 5));
	XCTAssertTrue(TGFieldTextWithinLimit(@"", 5));
	XCTAssertFalse(TGFieldTextWithinLimit(@"123456", 5));
	XCTAssertTrue(TGFieldTextWithinLimit(@"anything at all", 0));
	XCTAssertTrue(TGFieldTextWithinLimit(@"anything at all", -1));
}

- (void)testCounterStaysHiddenAtSeventyPercent {
	XCTAssertNil(TGFieldCounterText(@"1234567", 10, NULL));
	XCTAssertNil(TGFieldCounterText(@"", 10, NULL));
}

- (void)testCounterShowsRemainingAfterSeventyPercent {
	BOOL exceeded = YES;
	NSString *counter = TGFieldCounterText(@"12345678", 10, &exceeded);
	XCTAssertEqualObjects(counter, @"2");
	XCTAssertFalse(exceeded);

	counter = TGFieldCounterText(@"1234567890", 10, &exceeded);
	XCTAssertEqualObjects(counter, @"0");
	XCTAssertFalse(exceeded);
}

- (void)testCounterGoesNegativePastTheLimit {
	BOOL exceeded = NO;
	NSString *counter = TGFieldCounterText(@"12345678901", 10, &exceeded);
	XCTAssertEqualObjects(counter, @"-1");
	XCTAssertTrue(exceeded);
}

- (void)testCounterIsAbsentWithoutALimit {
	XCTAssertNil(TGFieldCounterText(@"123", 0, NULL));
}

- (void)testFieldKeyPrefersIdentifierAndFallsBackToPlaceholder {
	NSMutableDictionary *row = TGFieldRow(@"Phone number", @"", nil);
	XCTAssertEqualObjects(TGRowFieldKey(row), @"Phone number");
	row[TGRowFieldIdentifier] = @"phone";
	XCTAssertEqualObjects(TGRowFieldKey(row), @"phone");
}

- (void)testRebuildPutsTypedTextBackWithoutTouchingOtherRows {
	NSDictionary *oldFirst = TGFieldRow(@"First Name", @"Ann", nil);
	NSDictionary *oldLast = TGFieldRow(@"Last Name", @"Lee", nil);
	NSDictionary *plain = TGTapRow(@"Language", @"English", nil);
	NSArray *old = @[TGSection(@"Name", nil, @[oldFirst, oldLast]),
			TGSection(nil, nil, @[plain])];

	NSMutableDictionary *newFirst = TGFieldRow(@"First Name", @"", nil);
	newFirst[TGRowFieldIdentifier] = @"first";
	NSMutableDictionary *newLast = TGFieldRow(@"Last Name", @"", nil);
	newLast[TGRowFieldIdentifier] = @"last";
	NSArray *fresh = @[TGSection(@"Name", nil, @[newFirst, newLast]),
			TGSection(nil, nil, @[TGTapRow(@"Language", @"English", nil)])];

	NSArray *rebuilt = TGRowsApplyingFieldTexts(fresh,
			@{@"first" : @"Annabel", @"last" : @"Lee"});
	XCTAssertEqualObjects(rebuilt[0][@"rows"][0][TGRowFieldText], @"Annabel");
	XCTAssertEqualObjects(rebuilt[0][@"rows"][1][TGRowFieldText], @"Lee");
	XCTAssertEqualObjects(rebuilt[1][@"rows"][0][TGRowTitle], @"Language");
	// The input is data: it is copied, not edited under the screen's feet.
	XCTAssertEqualObjects(fresh[0][@"rows"][0][TGRowFieldText], @"");
	XCTAssertEqualObjects(old[0][@"rows"][0][TGRowFieldText], @"Ann");
}

- (void)testRebuildLeavesRowsWithoutRememberedTextAlone {
	NSMutableDictionary *row = TGFieldRow(@"First Name", @"Ann", nil);
	NSArray *sections = @[TGSection(nil, nil, @[row])];
	NSArray *same = TGRowsApplyingFieldTexts(sections, nil);
	XCTAssertEqualObjects(same[0][@"rows"][0][TGRowFieldText], @"Ann");
	same = TGRowsApplyingFieldTexts(sections, @{});
	XCTAssertEqualObjects(same[0][@"rows"][0][TGRowFieldText], @"Ann");
}

- (void)testFieldTextsReadsEveryFieldByItsKey {
	NSMutableDictionary *first = TGFieldRow(@"First Name", @"Ann", nil);
	first[TGRowFieldIdentifier] = @"first";
	NSMutableDictionary *bio = TGMultilineFieldRow(@"Bio", @"Hi", nil);
	NSArray *sections = @[TGSection(nil, nil, @[first, bio,
			TGTapRow(@"Language", @"English", nil)])];
	NSDictionary *texts = TGRowsFieldTexts(sections);
	XCTAssertEqualObjects(texts[@"first"], @"Ann");
	XCTAssertEqualObjects(texts[@"Bio"], @"Hi");
	XCTAssertEqual(texts.count, (NSUInteger)2);
}

@end
