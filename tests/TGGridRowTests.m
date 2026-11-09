// TGGridRowTests.m - the shared picture grid's pure layout and row model.
//
// The tile line is geometry a host test can pin without a table: how many
// tiles fit, how large a square becomes, and which tile a point belongs to.
#import "TGTestRunner.h"
#import "TGGridRowCell.h"
#import "TGRows.h"

@interface TGGridRowTests : XCTestCase @end

@implementation TGGridRowTests

- (void)testColumnsFollowTheWidthAndTheSmallestTile {
	XCTAssertEqual(TGGridColumnsForWidth(320, 80), 3);
	XCTAssertEqual(TGGridColumnsForWidth(320, 40), 6);
	XCTAssertEqual(TGGridColumnsForWidth(375, 80), 4);
	XCTAssertEqual(TGGridColumnsForWidth(0, 80), 1);
	XCTAssertEqual(TGGridColumnsForWidth(320, 0), 1);
}

- (void)testTileSideIsTheWidthLeftAfterInsetAndGaps {
	// 300 = 320 - 2 * 10; three tiles and two 4 pt gaps leave 272 / 3 = 90.
	XCTAssertTrue(fabs(TGGridTileSideForWidth(300, 3) - 90) < 0.01);
	XCTAssertTrue(fabs(TGGridTileSideForWidth(300, 6) - 43) < 0.01);
	// A square never needs more room than a line has.
	XCTAssertGreaterThanOrEqual(TGGridTileSideForWidth(300, 3), 0);
	XCTAssertEqual(TGGridTileSideForWidth(300, 0), 0);
}

- (void)testTapPointFindsItsTileAndGapsAreNotFound {
	// Content width 300 with three columns: tiles start at x = 10, 104, 198.
	XCTAssertEqual(TGGridIndexAtPoint(CGPointMake(50, 10), 300, 3, 3), 0);
	XCTAssertEqual(TGGridIndexAtPoint(CGPointMake(110, 10), 300, 3, 3), 1);
	XCTAssertEqual(TGGridIndexAtPoint(CGPointMake(200, 50), 300, 3, 3), 2);
	// The inset, a gap, the row below and a fourth tile are not a tile.
	XCTAssertEqual(TGGridIndexAtPoint(CGPointMake(5, 10), 300, 3, 3),
			(NSInteger)NSNotFound);
	XCTAssertEqual(TGGridIndexAtPoint(CGPointMake(102, 10), 300, 3, 4),
			(NSInteger)NSNotFound);
	XCTAssertEqual(TGGridIndexAtPoint(CGPointMake(50, 110), 300, 3, 3),
			(NSInteger)NSNotFound);
	XCTAssertEqual(TGGridIndexAtPoint(CGPointMake(200, 10), 300, 3, 2),
			(NSInteger)NSNotFound);
}

- (void)testCaptionAddsOneLineUnderTheSquare {
	CGFloat plain = TGGridRowHeightForWidth(300, 3, NO);
	CGFloat captioned = TGGridRowHeightForWidth(300, 3, YES);
	XCTAssertGreaterThan(captioned, plain);
	XCTAssertTrue(fabs((captioned - plain) -
			(TGMetricLineCaption + TGMetricPadTiny)) < 0.01);
}

- (void)testGridRowCarriesItsLineAndCallsBackWithTheTileIndex {
	NSArray *items = @[@{TGGridItemInitials : @"A"},
			@{TGGridItemInitials : @"B"}];
	__block NSInteger tapped = -1;
	NSMutableDictionary *row = TGGridRow(items, 3, ^(NSInteger index){
		tapped = index;
	});

	XCTAssertEqualObjects(row[TGRowKind], TGKindGrid);
	XCTAssertEqualObjects(row[TGRowGridItems], items);
	XCTAssertEqualObjects(row[TGRowGridColumns], @3);
	((void (^)(NSInteger))row[TGRowGridTap])(1);
	XCTAssertEqual(tapped, (NSInteger)1);
}

- (void)testGridRowNeverHasZeroColumns {
	NSMutableDictionary *row = TGGridRow(@[], 0, nil);
	XCTAssertEqualObjects(row[TGRowGridColumns], @1);
	XCTAssertEqual([row[TGRowGridItems] count], (NSUInteger)0);
}

@end
