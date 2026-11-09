// TGRowModelTests.m - the shared row model.
//
// The builders are data, so the kinds and keys they produce are pinned here;
// a screen that reads them never has to guess what a row is.
#import "TGTestRunner.h"
#import "TGRows.h"

@interface TGRowModelTests : XCTestCase @end

@implementation TGRowModelTests

- (void)testTapRowCarriesKindTitleDetailAndTap {
	__block BOOL tapped = NO;
	NSDictionary *row = TGTapRow(@"Language", @"English", ^{ tapped = YES; });
	XCTAssertEqualObjects(row[TGRowKind], TGKindDisclosure);
	XCTAssertEqualObjects(row[TGRowTitle], @"Language");
	XCTAssertEqualObjects(row[TGRowDetail], @"English");
	XCTAssertNil(row[TGRowOpens]);
	((void (^)(void))row[TGRowTap])();
	XCTAssertTrue(tapped);
}

- (void)testOpenRowAddsTheChevronFlag {
	NSDictionary *row = TGOpenRow(@"Devices", @"2", nil);
	XCTAssertEqualObjects(row[TGRowKind], TGKindDisclosure);
	XCTAssertTrue([row[TGRowOpens] boolValue]);
}

- (void)testSwitchRowCarriesItsBlockAndState {
	__block BOOL last = YES;
	NSDictionary *row = TGSwitchRow(@"Reactions", NO, ^(BOOL on){ last = on; });
	XCTAssertEqualObjects(row[TGRowKind], TGKindToggle);
	XCTAssertFalse([row[TGRowOn] boolValue]);
	XCTAssertNotNil(row[TGRowToggle]);
	((void (^)(BOOL))row[TGRowToggle])(YES);
	XCTAssertTrue(last);
}

- (void)testSwitchInfoRowKeepsIconDetailAndBlock {
	__block BOOL called = NO;
	UIColor *colour = [UIColor redColor];
	NSDictionary *row = TGSwitchInfoRow(@"Animated Stickers", @"Play on this device",
			@"sticker", colour, YES, ^(BOOL on){ called = on; });
	XCTAssertEqualObjects(row[TGRowKind], TGKindToggleInfo);
	XCTAssertEqualObjects(row[TGRowDetail], @"Play on this device");
	XCTAssertEqualObjects(row[TGRowIcon], @"sticker");
	XCTAssertEqualObjects(row[TGRowColour], colour);
	XCTAssertTrue([row[TGRowOn] boolValue]);
	((void (^)(BOOL))row[TGRowToggle])(NO);
	XCTAssertFalse(called);
}

- (void)testCheckRowCarriesCheckedAndTap {
	__block BOOL tapped = NO;
	NSDictionary *row = TGCheckRow(@"System", nil, YES, ^{ tapped = YES; });
	XCTAssertEqualObjects(row[TGRowKind], TGKindCheck);
	XCTAssertTrue([row[TGRowChecked] boolValue]);
	XCTAssertNil(row[TGRowDetail]);
	((void (^)(void))row[TGRowTap])();
	XCTAssertTrue(tapped);
}

- (void)testSubtitleRowsUseTheSubtitleFlag {
	NSDictionary *plain = TGSubtitleRow(@"Alice", @"Always Off", nil);
	XCTAssertEqualObjects(plain[TGRowKind], TGKindDisclosure);
	XCTAssertTrue([plain[TGRowSubtitle] boolValue]);
	XCTAssertEqualObjects(plain[TGRowDetail], @"Always Off");

	NSDictionary *open = TGSubtitleOpenRow(@"Bob", @"Always On", nil);
	XCTAssertTrue([open[TGRowSubtitle] boolValue]);
	XCTAssertTrue([open[TGRowOpens] boolValue]);
}

- (void)testActionAndRedRowsKeepTheirOwnKinds {
	XCTAssertEqualObjects(TGActionRow(@"Add", nil)[TGRowKind], TGKindAction);
	XCTAssertEqualObjects(TGRedRow(@"Log out", nil)[TGRowKind], TGKindDestructive);
}

- (void)testIconRowsCarryIconColourAndValue {
	UIColor *colour = [UIColor blueColor];
	NSDictionary *row = TGIconTapOpenRow(@"Data and Storage", @"1.2 GB",
			@"data", colour, nil);
	XCTAssertEqualObjects(row[TGRowKind], TGKindDisclosure);
	XCTAssertEqualObjects(row[TGRowIcon], @"data");
	XCTAssertEqualObjects(row[TGRowColour], colour);
	XCTAssertEqualObjects(row[TGRowDetail], @"1.2 GB");
	XCTAssertTrue([row[TGRowOpens] boolValue]);
}

- (void)testSectionKeepsRowOrderAndCarriesHeaderFooter {
	NSDictionary *first = TGTapRow(@"First", nil, nil);
	NSDictionary *second = TGTapRow(@"Second", nil, nil);
	NSDictionary *section = TGSection(@"Header", @"Footer", @[first, second]);
	XCTAssertEqualObjects(section[@"header"], @"Header");
	XCTAssertEqualObjects(section[@"footer"], @"Footer");
	XCTAssertEqualObjects(section[@"rows"][0][TGRowTitle], @"First");
	XCTAssertEqualObjects(section[@"rows"][1][TGRowTitle], @"Second");
}

- (void)testEmptySectionKeepsAnEmptyRowList {
	NSDictionary *section = TGSection(nil, nil, nil);
	XCTAssertNotNil(section[@"rows"]);
	XCTAssertEqual([section[@"rows"] count], (NSUInteger)0);
	XCTAssertNil(section[@"header"]);
}

- (void)testIconConsistencyIsAllOrNone {
	NSDictionary *plainA = TGTapRow(@"A", nil, nil);
	NSDictionary *plainB = TGTapRow(@"B", nil, nil);
	NSDictionary *iconA = TGIconRow(@"A", @"data", nil, nil);
	NSDictionary *iconB = TGIconRow(@"B", @"privacy", nil, nil);

	XCTAssertTrue(TGRowsSectionIconsConsistent(@[]));
	XCTAssertTrue(TGRowsSectionIconsConsistent(@[plainA, plainB]));
	XCTAssertTrue(TGRowsSectionIconsConsistent(@[iconA, iconB]));
	XCTAssertFalse(TGRowsSectionIconsConsistent(@[plainA, iconB]));
	XCTAssertFalse(TGRowsSectionIconsConsistent(@[iconA, plainB]));
	// An empty icon name is no icon, not an icon with a hole.
	NSDictionary *bad = TGIconRow(@"C", @"", nil, nil);
	XCTAssertFalse(TGRowsSectionIconsConsistent(@[iconA, bad]));
}

@end
