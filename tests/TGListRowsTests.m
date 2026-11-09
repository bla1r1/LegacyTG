// TGListRowsTests.m - the shared list rows.
//
// TGListViewController's flat entries, the message search result and the
// Contacts index are data decisions, so they are pinned here without a table.
#import "TGTestRunner.h"
#import "TGRows.h"

@interface TGListRowsTests : XCTestCase @end

@implementation TGListRowsTests

- (void)testListEntryBecomesASharedRow {
	__block BOOL tapped = NO;
	NSDictionary *entry = @{
		@"title" : @"Network Type",
		@"detail" : @"Wi-Fi",
		@"tap" : ^{ tapped = YES; },
	};
	NSDictionary *row = TGRowFromListEntry(entry);
	XCTAssertEqualObjects(row[TGRowKind], TGKindDisclosure);
	XCTAssertEqualObjects(row[TGRowTitle], @"Network Type");
	XCTAssertEqualObjects(row[TGRowDetail], @"Wi-Fi");
	XCTAssertNil(row[TGRowOpens]);
	((void (^)(void))row[TGRowTap])();
	XCTAssertTrue(tapped);
}

- (void)testListEntryKeepsTheOpenAndDestructiveFlags {
	NSDictionary *open = TGRowFromListEntry(@{
		@"title" : @"TDLib State",
		@"opens" : @YES,
	});
	XCTAssertTrue([open[TGRowOpens] boolValue]);

	NSDictionary *red = TGRowFromListEntry(@{
		@"title" : @"Clear All",
		@"detail" : @"2 topics",
		@"destructive" : @YES,
	});
	XCTAssertEqualObjects(red[TGRowKind], TGKindDestructive);
	XCTAssertEqualObjects(red[TGRowDetail], @"2 topics");
}

- (void)testListEntriesKeepTheirOrder {
	NSArray *rows = TGRowsFromListEntries(@[
		@{@"title" : @"First"},
		@{@"title" : @"Second"},
	]);
	XCTAssertEqual(rows.count, (NSUInteger)2);
	XCTAssertEqualObjects(rows[0][TGRowTitle], @"First");
	XCTAssertEqualObjects(rows[1][TGRowTitle], @"Second");
	XCTAssertEqual(TGRowsFromListEntries(nil).count, (NSUInteger)0);
}

- (void)testMessageResultRowCarriesItsKeys {
	__block BOOL tapped = NO;
	NSMutableDictionary *row = TGMessageResultRow(@(-1001), @"LegacyTG",
			@"the build passed", @"12:30", ^{ tapped = YES; });
	XCTAssertEqualObjects(row[TGRowKind], TGKindMessageResult);
	XCTAssertEqualObjects(row[TGRowPeerId], @(-1001));
	XCTAssertEqualObjects(row[TGRowTitle], @"LegacyTG");
	XCTAssertEqualObjects(row[TGRowMessageText], @"the build passed");
	XCTAssertEqualObjects(row[TGRowMessageDate], @"12:30");
	((void (^)(void))row[TGRowTap])();
	XCTAssertTrue(tapped);
}

- (void)testContactIndexLettersAreAHashOrALetter {
	XCTAssertEqualObjects(TGContactSectionTitle(@"Alice"), @"A");
	XCTAssertEqualObjects(TGContactSectionTitle(@"  bob"), @"B");
	XCTAssertEqualObjects(TGContactSectionTitle(@"Ёлка"), @"Ё");
	XCTAssertEqualObjects(TGContactSectionTitle(@"1 Alice"), @"#");
	XCTAssertEqualObjects(TGContactSectionTitle(@"🎉 Party"), @"#");
	XCTAssertEqualObjects(TGContactSectionTitle(@""), @"#");
	XCTAssertEqualObjects(TGContactSectionTitle(nil), @"#");
}

@end
