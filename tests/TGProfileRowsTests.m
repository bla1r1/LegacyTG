// TGProfileRowsTests.m - the profile screens as data.
//
// The profile, Group Settings and the photo gallery only describe sections;
// TGRowsViewController draws them. These tests pin the section order for the
// three peer kinds, the media tab strip's row kind and the grid chunking.
#import "TGTestRunner.h"
#import "TGRows.h"
#import "TGProfileLogic.h"

@interface TGProfileRowsTests : XCTestCase @end

static NSArray *ProfileRowKinds(NSArray *rows) {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *row in rows)
		[out addObject:row[TGRowKind] ?: @""];
	return out;
}

static NSDictionary *InfoRow(NSString *kind, NSString *label, NSString *value) {
	return @{@"kind" : kind, @"label" : label, @"value" : value};
}

@implementation TGProfileRowsTests

- (void)testUserFixtureIsDetailsDangerThenMedia {
	__block NSString *tappedKind = nil;
	NSArray *sections = TGProfileSectionsForFixture(@{
		@"details" : @[
			InfoRow(@"phone", @"Mobile", @"+1 555 0100"),
			InfoRow(@"bio", @"Bio", @"Mathematician"),
		],
		@"danger" : @YES,
		@"mediaTabs" : @[
			@{@"title" : @"Media", @"kind" : @"media"},
			@{@"title" : @"Files", @"kind" : @"files"},
		],
		@"mediaKind" : @"files",
		@"mediaRows" : @[TGPictureRow(@"notes.pdf", @"12 KB", nil)],
		@"handlers" : @{
			@"detail" : ^(id kind){ tappedKind = kind; },
		},
	});

	XCTAssertEqual(sections.count, (NSUInteger)3);
	XCTAssertEqualObjects(ProfileRowKinds(sections[0][@"rows"]),
			(@[TGKindDisclosure, TGKindDisclosure]));
	XCTAssertEqualObjects(sections[1][@"rows"][0][TGRowKind],
			TGKindDestructive);
	XCTAssertEqualObjects(sections[2][@"rows"][0][TGRowKind],
			TGKindTabStrip);
	XCTAssertEqualObjects(sections[2][@"rows"][1][TGRowKind],
			TGKindPicture);

	((void (^)(void))sections[0][@"rows"][0][TGRowTap])();
	XCTAssertEqualObjects(tappedKind, @"phone");
}

- (void)testGroupFixtureKeepsCommunityBeforeTheCardAndMembersAfter {
	NSArray *sections = TGProfileSectionsForFixture(@{
		@"community" : @{
			@"id" : @(-1001),
			@"title" : @"Design",
			@"subtitle" : @"Community with 3 chats",
		},
		@"details" : @[
			InfoRow(@"invite", @"Link", @"https://t.me/design"),
			InfoRow(@"about", @"Description", @"A place to talk"),
		],
		@"members" : @[
			@{@"id" : @(1), @"name" : @"Ada", @"status" : @"owner"},
			@{@"id" : @(2), @"name" : @"Bob", @"status" : @"admin"},
		],
		@"memberCount" : @(2),
		@"mediaTabs" : @[@{@"title" : @"Media", @"kind" : @"media"}],
		@"mediaKind" : @"media",
	});

	XCTAssertEqual(sections.count, (NSUInteger)4);
	XCTAssertEqualObjects(sections[0][@"rows"][0][TGRowKind], TGKindPeerRow);
	XCTAssertEqualObjects(sections[1][@"rows"][0][TGRowKind],
			TGKindDisclosure);
	XCTAssertEqualObjects(sections[2][@"header"], @"2 members");
	XCTAssertEqualObjects(ProfileRowKinds(sections[2][@"rows"]),
			(@[TGKindPeerRow, TGKindPeerRow]));
	XCTAssertEqualObjects(sections[2][@"rows"][0][TGRowBadge], @"Owner");
	XCTAssertEqualObjects(sections[3][@"rows"][0][TGRowKind],
			TGKindTabStrip);
}

- (void)testChannelFixtureSaysSubscribersAndHasNoDangerSection {
	NSArray *sections = TGProfileSectionsForFixture(@{
		@"isChannel" : @YES,
		@"details" : @[
			InfoRow(@"invite", @"Link", @"https://t.me/design_channel"),
			InfoRow(@"about", @"Description", @"Posts about design"),
		],
		@"members" : @[@{@"id" : @(7), @"name" : @"Carol"}],
		@"memberCount" : @(42),
		@"mediaTabs" : @[
			@{@"title" : @"Media", @"kind" : @"media"},
			@{@"title" : @"Similar Channels", @"kind" : @"similar"},
		],
		@"mediaKind" : @"media",
	});

	XCTAssertEqual(sections.count, (NSUInteger)3);
	XCTAssertEqualObjects(sections[1][@"header"], @"42 subscribers");
	XCTAssertEqualObjects(sections[2][@"rows"][0][TGRowKind],
			TGKindTabStrip);
	XCTAssertEqualObjects(sections[2][@"rows"][0][TGRowTabStripSelected],
			@"media");
}

- (void)testMediaTabRowIsTheSharedTabStrip {
	NSArray *tabs = @[
		@{@"title" : @"Media", @"kind" : @"media"},
		@{@"title" : @"Files", @"kind" : @"files"},
	];
	NSMutableDictionary *row = TGProfileMediaTabRowModel(tabs, nil);
	XCTAssertEqualObjects(row[TGRowKind], TGKindTabStrip);
	XCTAssertEqualObjects(row[TGRowTabStripItems], tabs);
	XCTAssertEqualObjects(row[TGRowTabStripSelected], @"media");

	NSMutableDictionary *chosen = TGProfileMediaTabRowModel(tabs, @"files");
	XCTAssertEqualObjects(chosen[TGRowTabStripSelected], @"files");
}

- (void)testGridChunksAListIntoFullLines {
	NSArray *items = @[@"0", @"1", @"2", @"3", @"4", @"5", @"6"];
	NSArray *rows = TGProfileGridRowModels(items, 3,
			^NSDictionary *(NSInteger index){
		return @{TGGridItemCaption : items[(NSUInteger)index]};
	}, nil);

	XCTAssertEqual(rows.count, (NSUInteger)3);
	XCTAssertEqualObjects(rows[0][TGRowKind], TGKindGrid);
	XCTAssertEqual([rows[0][TGRowGridItems] count], (NSUInteger)3);
	XCTAssertEqual([rows[1][TGRowGridItems] count], (NSUInteger)3);
	XCTAssertEqual([rows[2][TGRowGridItems] count], (NSUInteger)1);
	XCTAssertEqualObjects(rows[0][TGRowGridColumns], @3);
	XCTAssertEqualObjects(rows[2][TGRowGridItems][0][TGGridItemCaption],
			@"6");
}

- (void)testGridTapReportsTheGlobalIndex {
	__block NSInteger seen = -1;
	NSArray *items = @[@"a", @"b", @"c", @"d"];
	NSArray *rows = TGProfileGridRowModels(items, 2, nil,
			^(NSInteger index){ seen = index; });
	XCTAssertEqual(rows.count, (NSUInteger)2);
	void (^tap)(NSInteger) = rows[1][TGRowGridTap];
	tap(1);
	XCTAssertEqual(seen, (NSInteger)3);
}

@end
