// TGPeerRowTests.m - the shared peer row's data and colour rule.
//
// A peer row is built by screens and drawn by one cell, so the keys it may
// carry and the online subtitle rule are pinned here, away from UIKit.
#import "TGTestRunner.h"
#import "TGRows.h"

@interface TGPeerRowTests : XCTestCase @end

@implementation TGPeerRowTests

- (void)testPeerRowCarriesIdTitleSubtitleAndTap {
	__block BOOL tapped = NO;
	NSDictionary *row = TGPeerRow(@(42), @"Alice", @"online", ^{ tapped = YES; });
	XCTAssertEqualObjects(row[TGRowKind], TGKindPeerRow);
	XCTAssertEqualObjects(row[TGRowPeerId], @(42));
	XCTAssertEqualObjects(row[TGRowTitle], @"Alice");
	XCTAssertEqualObjects(row[TGRowDetail], @"online");
	((void (^)(void))row[TGRowTap])();
	XCTAssertTrue(tapped);
}

- (void)testPeerRowCarriesTheSharedAccessoryKeys {
	NSMutableDictionary *row = TGPeerRow(@(7), @"Bob", nil, nil);
	row[TGRowChecked] = @YES;
	row[TGRowAccessory] = TGRowAccessoryCheck;
	row[TGRowBadge] = @3;
	row[TGRowOnline] = @YES;

	XCTAssertEqualObjects(row[TGRowAccessory], TGRowAccessoryCheck);
	XCTAssertEqualObjects(row[TGRowBadge], @3);
	XCTAssertTrue([row[TGRowOnline] boolValue]);
	XCTAssertTrue([row[TGRowChecked] boolValue]);
}

- (void)testSubtitleColourIsAccentOnlineAndSecondaryOffline {
	UIColor *accent = [UIColor redColor];
	UIColor *secondary = [UIColor blueColor];

	XCTAssertEqualObjects(TGPeerRowSubtitleColour(YES, accent, secondary),
			accent);
	XCTAssertEqualObjects(TGPeerRowSubtitleColour(NO, accent, secondary),
			secondary);
}

- (void)testCheckStateRoundTrips {
	NSMutableDictionary *row = TGPeerRow(@(9), @"Carol", nil, nil);
	XCTAssertFalse(TGPeerRowIsChecked(row));

	row[TGRowChecked] = @YES;
	XCTAssertTrue(TGPeerRowIsChecked(row));

	row[TGRowChecked] = @NO;
	XCTAssertFalse(TGPeerRowIsChecked(row));
}

@end
