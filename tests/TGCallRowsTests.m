// TGCallRowsTests.m - the shared row data behind the call screen and player.
//
// The call screen and player describe rows and hand them to TGRowsDataSource,
// so the counts, the heights and the participant row's keys are pinned here without a
// table or a theme.
#import "TGTestRunner.h"
#import "TGRows.h"
#import "TGRowsDataSource.h"
#import "TGGridRowCell.h"
#import "TGGroupCallParticipantCell.h"

@interface TGCallRowsTests : XCTestCase @end

@implementation TGCallRowsTests

- (NSArray *)fixtureSections {
	return @[
		TGSection(@"People", nil, @[
			TGPeerRow(@(1), @"Alice", @"Speaking", nil),
		]),
		TGSection(@"Call", nil, @[
			TGTapRow(@"Join", nil, nil),
			TGSubtitleRow(@"Camera", @"On", nil),
			TGOpenRow(@"Participants", @"3", nil),
		]),
	];
}

- (void)testSectionAndRowCountsFollowTheFixture {
	NSArray *sections = [self fixtureSections];
	XCTAssertEqual(TGRowsDataSourceSectionCount(sections), (NSInteger)2);
	XCTAssertEqual(TGRowsDataSourceRowCount(sections, 0), (NSInteger)1);
	XCTAssertEqual(TGRowsDataSourceRowCount(sections, 1), (NSInteger)3);
	XCTAssertEqual(TGRowsDataSourceRowCount(sections, 9), (NSInteger)0);
	XCTAssertEqual(TGRowsDataSourceSectionCount(nil), (NSInteger)0);
}

- (void)testRowLookupIsBoundsChecked {
	NSArray *sections = [self fixtureSections];
	NSDictionary *row = TGRowsDataSourceRow(sections, 1, 1);
	XCTAssertEqualObjects(row[TGRowTitle], @"Camera");
	XCTAssertEqualObjects(row[TGRowDetail], @"On");
	XCTAssertNil(TGRowsDataSourceRow(sections, 1, 7));
	XCTAssertNil(TGRowsDataSourceRow(nil, 0, 0));
}

- (void)testHeightsMatchTheSharedCellRules {
	NSDictionary *peer = TGPeerRow(@(1), @"Alice", @"Speaking", nil);
	NSDictionary *plain = TGTapRow(@"Join", nil, nil);
	NSDictionary *subtitle = TGSubtitleRow(@"Camera", @"On", nil);

	XCTAssertEqual(TGRowsDataSourceHeight(peer, 320),
			TGMetricPersonRow);
	XCTAssertEqual(TGRowsDataSourceHeight(plain, 320), TGMetricRow);
	XCTAssertEqual(TGRowsDataSourceHeight(subtitle, 320), TGMetricRow);

	NSMutableDictionary *tall = [peer mutableCopy];
	tall[TGRowHeight] = @(72);
	XCTAssertEqual(TGRowsDataSourceHeight(tall, 320), (CGFloat)72);
}

- (void)testGridHeightComesFromTheGridGeometry {
	NSMutableDictionary *grid = TGGridRow(@[
		@{TGGridItemInitials : @"A"},
		@{TGGridItemInitials : @"B"},
	], 3, nil);
	CGFloat expected = TGGridRowHeightForWidth(320, 3, NO);
	XCTAssertTrue(fabs(TGRowsDataSourceHeight(grid, 320) - expected) < 0.01);

	grid[TGRowGridItems] = @[
		@{TGGridItemInitials : @"A", TGGridItemCaption : @"One"},
	];
	CGFloat captioned = TGGridRowHeightForWidth(320, 3, YES);
	XCTAssertTrue(fabs(TGRowsDataSourceHeight(grid, 320) - captioned) < 0.01);
}

- (void)testMeasuredKindsAskTheirCell {
	XCTAssertTrue(TGRowsDataSourceHeight(TGFieldRow(@"Name", @"", nil), 320) < 0);
	XCTAssertTrue(TGRowsDataSourceHeight(
			@{TGRowKind : TGKindNote, TGRowTitle : @"Note"}, 320) < 0);
}

- (void)testParticipantRowKeysMarkSpeakingAndTheCurrentUser {
	NSDictionary *participant = @{
		@"name" : @"Alice",
		@"userId" : @(42),
		@"isSpeaking" : @YES,
		@"isMutedForAllUsers" : @NO,
		@"isMutedForCurrentUser" : @NO,
		@"isCurrentUser" : @NO,
	};
	UIColor *accent = [UIColor redColor];
	NSDictionary *row = TGGroupCallParticipantRow(participant, accent, nil);

	XCTAssertEqualObjects(row[TGRowKind], TGKindPeerRow);
	XCTAssertEqualObjects(row[TGRowPeerId], @(42));
	XCTAssertEqualObjects(row[TGRowTitle], @"Alice");
	XCTAssertTrue([row[TGRowAvatarUser] boolValue]);
	XCTAssertTrue([row[TGRowOnline] boolValue]);
	XCTAssertNil(row[TGRowTitleColour]);

	NSMutableDictionary *me = [participant mutableCopy];
	me[@"isCurrentUser"] = @YES;
	NSDictionary *mine = TGGroupCallParticipantRow(me, accent, nil);
	XCTAssertEqualObjects(mine[TGRowTitleColour], accent);
}

- (void)testParticipantRowCarriesTheMutedIconKey {
	UIImage *mutedIcon = [UIImage new];
	NSDictionary *muted = @{
		@"name" : @"Bob",
		@"userId" : @(7),
		@"isSpeaking" : @YES,
		@"isMutedForAllUsers" : @YES,
	};
	NSDictionary *row = TGGroupCallParticipantRow(muted,
			[UIColor blueColor], mutedIcon);
	XCTAssertEqualObjects(row[TGRowTrailingImage], mutedIcon);
	XCTAssertFalse([row[TGRowOnline] boolValue]);

	NSDictionary *unmuted = TGGroupCallParticipantRow(@{
		@"name" : @"Carol",
		@"userId" : @(8),
	}, nil, mutedIcon);
	XCTAssertNil(unmuted[TGRowTrailingImage]);
}

@end
