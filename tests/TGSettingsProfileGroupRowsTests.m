// TGSettingsProfileGroupRowsTests.m - the row models behind storage, device,
// profile, group and story screens.
//
// Data and Storage, Storage, This Device, Your Color, the story sheet, the
// profile card and group settings all described their rows inside a data
// source method, where a host test could not see them. The pure builders are
// pinned here: value order, the official size shape, the raw-text flags that
// keep an account's bio untranslated, and the member rows that became
// TGPeerRow.
#import "TGTestRunner.h"
#import "TGRows.h"
#import "TGSettingsFormatting.h"
#import "TGProfileLogic.h"
#import "TGGroupLogic.h"
#import "TGStoryText.h"
#import "TGBadge.h"

@interface TGSettingsProfileGroupRowsTests : XCTestCase @end

@implementation TGSettingsProfileGroupRowsTests

- (void)tearDown {
	TGSetTelegramLanguageLookup(nil);
	TGSetAppLanguage(nil);
}

- (void)testAutoDownloadValueUsesTheOfficialShortShape {
	TGSetTelegramLanguageLookup(nil);
	long long mb = 1024LL * 1024;
	// Official prints whole MB from 10 MB up and one decimal below it; the
	// value column beside "Using Wi-Fi" cut "121,5 МБ" to "121,…".
	XCTAssertEqualObjects(
			TGSettingsAutoDownloadBytesForLanguage(121 * mb + mb / 2, @"en"),
			@"121 MB");
	XCTAssertEqualObjects(
			TGSettingsAutoDownloadBytesForLanguage(121 * mb, @"en"), @"121 MB");
	XCTAssertEqualObjects(
			TGSettingsAutoDownloadBytesForLanguage(mb + mb / 2, @"en"),
			@"1.5 MB");
	XCTAssertEqualObjects(
			TGSettingsAutoDownloadBytesForLanguage(mb + mb / 2, @"ru"),
			@"1,5 MB");
	XCTAssertEqualObjects(
			TGSettingsAutoDownloadBytesForLanguage(500 * 1024, @"en"),
			@"500 KB");

	TGSetTelegramLanguageLookup(@{@"MB" : @"МБ"});
	XCTAssertEqualObjects(
			TGSettingsAutoDownloadBytesForLanguage(mb + mb / 2, @"ru"),
			@"1,5 МБ");
}

- (void)testPowerSavingHeightIsMeasuredFromBothLines {
	CGFloat oneLine = TGRowsToggleInfoHeight(TGMetricLineRow, TGMetricLineCaption);
	CGFloat threeLines = TGRowsToggleInfoHeight(TGMetricLineRow,
			TGMetricLineCaption * 3);
	XCTAssertGreaterThanOrEqual(oneLine, TGMetricActionTile);
	XCTAssertGreaterThan(threeLines, oneLine + TGMetricLineCaption);
	// One title and one detail line with the two paddings and the gap.
	CGFloat expected = TGMetricPad + TGMetricLineRow + TGMetricPadTiny +
			TGMetricLineCaption + TGMetricPad;
	XCTAssertLessThan(fabs(oneLine - expected), 0.51);
}

- (void)testStorageCategoryRowsKeepShareSizeAndCheck {
	NSArray *categories = @[
		@{@"name" : @"Photos", @"bytes" : @(1024 * 1024),
		  @"kinds" : @[@"photo"]},
		@{@"name" : @"Videos", @"bytes" : @(2 * 1024 * 1024),
		  @"kinds" : @[@"video", @"animation"]},
	];
	NSArray *rows = TGSettingsStorageCategoryRowModels(categories,
			3 * 1024 * 1024, [NSSet setWithObject:@"photo"]);
	XCTAssertEqual(rows.count, (NSUInteger)2);
	XCTAssertEqualObjects(rows[0][TGRowTitle], @"Photos  33.3%");
	XCTAssertTrue([rows[0][TGRowChecked] boolValue]);
	XCTAssertFalse([rows[1][TGRowChecked] boolValue]);
	XCTAssertEqualObjects(rows[0][@"storageKinds"], (@[@"photo"]));
	XCTAssertTrue([rows[1][TGRowDetail] hasSuffix:@"MB"]);
}

- (void)testProfileInfoRowKeepsTheLabelAndMarksAccountTextRaw {
	NSDictionary *phone = TGProfileInfoRowModel(@{
		@"kind" : @"phone", @"label" : @"Mobile", @"value" : @"+1 555",
	});
	XCTAssertEqualObjects(phone[TGRowTitle], @"Mobile");
	XCTAssertEqualObjects(phone[TGRowDetail], @"+1 555");
	XCTAssertTrue([phone[TGRowSubtitle] boolValue]);
	XCTAssertTrue([phone[TGRowRawDetail] boolValue]);
	XCTAssertNil(phone[TGRowRawTitle]);

	NSDictionary *bio = TGProfileInfoRowModel(@{
		@"kind" : @"bio", @"label" : @"", @"value" : @"Am a teapot",
	});
	XCTAssertEqualObjects(bio[TGRowTitle], @"Am a teapot");
	XCTAssertNil(bio[TGRowDetail]);
	XCTAssertTrue([bio[TGRowRawTitle] boolValue]);

	NSDictionary *settings = TGProfileInfoRowModel(@{
		@"kind" : @"settings", @"label" : @"Group Settings", @"value" : @"",
	});
	XCTAssertTrue([settings[TGRowOpens] boolValue]);
}

- (void)testProfileMemberRowIsAPeerRowWithItsRoleBadge {
	NSDictionary *admin = TGProfileMemberRowModel(@{
		@"id" : @(42), @"name" : @"Alice", @"status" : @"admin",
		@"tag" : @"", @"tagRole" : @"",
	}, 0);
	XCTAssertEqualObjects(admin[TGRowPeerId], @(42));
	XCTAssertEqualObjects(admin[TGRowTitle], @"Alice");
	XCTAssertEqualObjects(admin[TGRowBadge], @"Admin");
	XCTAssertEqualObjects(admin[TGRowBadgeVariant], @(TGBadgeVariantMuted));
	XCTAssertTrue([admin[TGRowBadgeInline] boolValue]);
	XCTAssertEqualObjects(admin[TGRowAccessory], TGRowAccessoryDisclosure);
	XCTAssertTrue([admin[TGRowAvatarUser] boolValue]);

	NSDictionary *owner = TGProfileMemberRowModel(@{
		@"id" : @(7), @"name" : @"Bob", @"status" : @"owner", @"tag" : @"Boss",
	}, 9001);
	XCTAssertEqualObjects(owner[TGRowBadge], @"Boss");
	XCTAssertEqualObjects(owner[TGRowStatusEmojiId], @(9001));
}

- (void)testGroupInfoRowOpensAndDestructiveStayDistinct {
	NSDictionary *info = TGGroupInfoRowModel(@"Members", @"1 234", YES, NO, NO);
	XCTAssertEqualObjects(info[TGRowKind], TGKindDisclosure);
	XCTAssertEqualObjects(info[TGRowTitle], @"Members");
	XCTAssertEqualObjects(info[TGRowDetail], @"1 234");
	XCTAssertTrue([info[TGRowOpens] boolValue]);
	XCTAssertTrue([info[TGRowRawDetail] boolValue]);

	NSDictionary *leave = TGGroupInfoRowModel(@"Leave Group", nil, YES, YES, NO);
	XCTAssertEqualObjects(leave[TGRowKind], TGKindDestructive);

	NSDictionary *disabled = TGGroupInfoRowModel(@"Slow Mode", @"No right",
			NO, NO, YES);
	XCTAssertEqualObjects(disabled[TGRowEnabled], @NO);
	XCTAssertFalse([disabled[TGRowOpens] boolValue]);
}

- (void)testGroupMemberRowCarriesTheFaceAndTheDisclosure {
	NSDictionary *member = @{
		@"id" : @(55), @"name" : @"Carol", @"status" : @"member",
	};
	NSDictionary *row = TGGroupMemberRowModel(member, 0);
	XCTAssertEqualObjects(row[TGRowKind], TGKindPeerRow);
	XCTAssertEqualObjects(row[TGRowPeerId], @(55));
	XCTAssertEqualObjects(row[TGRowAccessory], TGRowAccessoryDisclosure);
	XCTAssertNil(row[TGRowBadge]);
}

- (void)testStorySheetRowsKeepTheOfficialOrder {
	NSDictionary *story = @{
		@"date" : @(1700000000), @"viewers" : @(12), @"forwards" : @(3),
		@"reactions" : @(4), @"privacy" : @"everyone",
		@"isPostedToChatPage" : @YES,
	};
	NSArray *info = TGStoryInfoRowsModel(story, NO);
	XCTAssertEqual(info.count, (NSUInteger)10);
	XCTAssertEqualObjects(info[0][TGRowTitle], @"Posted Stories");
	XCTAssertEqualObjects(info[1][TGRowTitle], @"Views");
	XCTAssertEqualObjects(info[1][TGRowDetail], @"12");
	XCTAssertEqualObjects(info[5][TGRowTitle], @"Chat");
	XCTAssertEqualObjects(info[5][TGRowDetail], @"Yes");
	XCTAssertEqualObjects(info[6][TGRowTitle], @"Interactions");
	XCTAssertEqualObjects(info[9][TGRowTitle], @"Report Story");

	NSArray *report = TGStoryInfoRowsModel(story, YES);
	XCTAssertEqual(report.count, (NSUInteger)6);
	XCTAssertFalse([[report valueForKeyPath:@"@unionOfObjects.title"]
			containsObject:@"Report Story"]);
	XCTAssertTrue([info[0][TGRowSubtitle] boolValue]);
	XCTAssertEqualObjects(info[0][TGRowDetailLines], @4);
}

- (void)testCentredDestructiveRowCarriesTheFlagAndTheTap {
	__block BOOL tapped = NO;
	NSDictionary *row = TGCentredDestructiveRow(@"Log out", ^{ tapped = YES; });
	XCTAssertEqualObjects(row[TGRowKind], TGKindDestructive);
	XCTAssertTrue([row[TGRowCentred] boolValue]);
	((void (^)(void))row[TGRowTap])();
	XCTAssertTrue(tapped);
}

- (void)testSegmentWidthFitsTheWholeTranslatedWord {
	UIFont *font = TGFontCaption();
	CGFloat measured = ceilf([@"Пропущ." sizeWithFont:font].width);
	CGFloat width = TGSettingsSegmentWidth(@"Пропущ.", font, TGMetricPadSmall);
	XCTAssertGreaterThanOrEqual(width, measured + TGDoubled(TGMetricPadSmall) - 0.01);
	// Two segments at the measured width and the old half-screen split would
	// have clipped the word; the full widths still leave the bar room.
	CGFloat all = TGSettingsSegmentWidth(@"Все", font, TGMetricPadSmall);
	XCTAssertLessThan(all + width, TGMetricScreenWidth - TGMetricPadLarge);
}

- (void)testDeviceCapabilityRowPutsOnInTheDetail {
	NSDictionary *available = TGDeviceCapabilityRowModel(@"Video Calls",
			YES, @"Requires iOS 8");
	XCTAssertEqualObjects(available[TGRowTitle], @"Video Calls");
	XCTAssertEqualObjects(available[TGRowDetail], @"On");
	NSDictionary *missing = TGDeviceCapabilityRowModel(@"Video Calls",
			NO, @"Requires iOS 8");
	XCTAssertEqualObjects(missing[TGRowDetail], @"Requires iOS 8");
}

@end
