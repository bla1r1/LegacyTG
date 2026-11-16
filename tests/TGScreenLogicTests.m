// TGScreenLogicTests.m - the four audit defects of 2026-11-14 that were
// arithmetic inside a view, now functions. Each test fails on the calculation
// the screen had before the audit fixed it on the device.
#import "TGTestRunner.h"
#import "TGLoginLogic.h"
#import "TGRowGeometry.h"
#import "TGChatCellLogic.h"
#import "TGChatActionMenuModel.h"

@interface TGScreenLogicTests : XCTestCase @end

@implementation TGScreenLogicTests

#pragma mark - sign-in step stack

- (void)testLogin_HiddenButtonTakesNoRow {
	// 320 pt: the bar's Next is the action, the bottom button is hidden, and
	// "Forgot password?" goes where the button would have been.
	XCTAssertTrue(TGLoginUsesBarNext(320));
	XCTAssertFalse(TGLoginShowsBottomButton(YES, 320));
	XCTAssertEqual(TGLoginYAfterActionRow(200, 320), (CGFloat)200);
}

- (void)testLogin_WideButtonTakesItsRow {
	XCTAssertFalse(TGLoginUsesBarNext(375));
	XCTAssertTrue(TGLoginShowsBottomButton(YES, 375));
	XCTAssertEqual(TGLoginYAfterActionRow(200, 375),
			(CGFloat)(200 + TGMetricRow + TGMetricStackStep));
}

- (void)testLogin_CodeStepHasNoBottomButton {
	XCTAssertFalse(TGLoginShowsBottomButton(NO, 375));
	XCTAssertFalse(TGLoginShowsBottomButton(NO, 320));
}

#pragma mark - swatch and tile grids

- (void)testSwatches_FifthStaysInsideTheGroupedCellOnIOS6 {
	// iOS 6 insets a grouped cell by 10 pt a side: 300 pt of content in a
	// 320 pt table. Laid across 320 the fifth swatch crossed the border.
	CGFloat width = TGRowContentWidth(320, YES, YES);
	XCTAssertEqual(width, (CGFloat)300);
	CGRect fifth = TGRowStripCellFrame(4, width, 5, TGMetricPadMedium,
			TGMetricPadSmall, 54, 44);
	XCTAssertLessThanOrEqual(CGRectGetMaxX(fifth), width - TGMetricPadMedium);
	XCTAssertEqual(fifth.origin.y, (CGFloat)5);
}

- (void)testSwatches_NoInsetOnIOS7OrPlainTables {
	XCTAssertEqual(TGRowContentWidth(320, YES, NO), (CGFloat)320);
	XCTAssertEqual(TGRowContentWidth(320, NO, YES), (CGFloat)320);
	XCTAssertEqual(TGRowContentWidth(0, NO, NO), TGMetricScreenWidth);
}

- (void)testGrid_HeightMatchesTheTilesTheCellLaysOut {
	// The height came from the table's width and the tiles from the cell's:
	// the last line of tiles ran past the row and was cut.
	CGFloat width = TGGridContentWidthForTable(320);
	XCTAssertEqual(width, (CGFloat)(320 - TGMetricGridTableMargin));
	CGFloat height = TGGridRowHeightForCount(width, 4, 7, YES);
	CGRect last = TGGridTileFrame(6, width, 4, YES);
	XCTAssertEqual(CGRectGetMaxY(last) + TGMetricGridInset, height);
	CGRect rightmost = TGGridTileFrame(3, width, 4, YES);
	XCTAssertLessThanOrEqual(CGRectGetMaxX(rightmost), width - TGMetricGridInset);
}

- (void)testGrid_NoRoomFallsBackToAPlainRow {
	XCTAssertEqual(TGGridRowHeightForCount(10, 4, 3, NO), TGMetricRow);
	XCTAssertTrue(CGRectIsEmpty(TGGridTileFrame(0, 10, 4, NO)));
	XCTAssertEqual(TGGridContentWidthForTable(0),
			(CGFloat)(TGMetricScreenWidth - TGMetricGridTableMargin));
}

#pragma mark - keepValueWhole

- (void)testValue_ShortValueIsLeftAlone {
	TGRowValueSplit s = TGRowKeepValueWhole(15, 120, 60, 300, 100, 80);
	XCTAssertEqual(s.titleWidth, (CGFloat)120);
	XCTAssertEqual(s.valueX, (CGFloat)200);
	XCTAssertEqual(s.valueWidth, (CGFloat)100);
}

- (void)testValue_LongValueLeavesTheTitleItsWords {
	// A channel description as the value took the whole row and ran off
	// its left edge; the title "Info" kept no width at all.
	TGRowValueSplit s = TGRowKeepValueWhole(15, 120, 60, 300, 100, 900);
	XCTAssertGreaterThanOrEqual(s.titleWidth, (CGFloat)60);
	XCTAssertGreaterThanOrEqual(s.valueX, (CGFloat)(15 + 60 + TGMetricPadMedium));
	XCTAssertEqual(s.valueX + s.valueWidth, (CGFloat)300);
}

- (void)testValue_LongTitleAndValueSplitTheRow {
	TGRowValueSplit s = TGRowKeepValueWhole(15, 200, 400, 300, 60, 400);
	CGFloat room = 300 - 15 - TGMetricPadMedium;
	XCTAssertEqual(s.valueWidth, room - floorf(room / 2));
	XCTAssertEqual(s.titleWidth, s.valueX - TGMetricPadMedium - 15);
}

#pragma mark - custom emoji still or animated

- (void)testEmoji_StillUntilTheAnimationIsOnDisk {
	// The emoji was dropped as soon as TDLib named the animation and stayed a
	// hole while it downloaded (on iOS 6 for good, if it would not parse).
	XCTAssertEqual(TGCustomEmojiChoose(YES, 0, 3, YES, NO, NO),
			TGCustomEmojiShowStillAndFetch);
	XCTAssertEqual(TGCustomEmojiChoose(YES, 0, 3, YES, YES, NO),
			TGCustomEmojiShowAnimation);
}

- (void)testEmoji_StillWhenAnimationIsNotAllowedOrCapped {
	XCTAssertEqual(TGCustomEmojiChoose(NO, 0, 3, YES, YES, NO), TGCustomEmojiShowStill);
	XCTAssertEqual(TGCustomEmojiChoose(YES, 3, 3, YES, YES, NO), TGCustomEmojiShowStill);
	XCTAssertEqual(TGCustomEmojiChoose(YES, 0, 3, NO, NO, NO), TGCustomEmojiShowStill);
}

- (void)testEmoji_RestsAsStillAfterItsOneLoop {
	XCTAssertEqual(TGCustomEmojiChoose(YES, 0, 3, YES, YES, YES), TGCustomEmojiShowStill);
}

#pragma mark - composer

- (void)testComposer_BarSitsOnItsBottomAndTheTableFillsAbove {
	TGChatComposerFrames f = TGChatComposerPlace(320, 416, 1);
	XCTAssertEqual(f.barHeight, TGChatComposerBarHeightForLines(1));
	XCTAssertEqual(CGRectGetMaxY(f.bar), (CGFloat)416);
	XCTAssertEqual(CGRectGetMaxY(f.table), CGRectGetMinY(f.bar));
	XCTAssertFalse(f.scrolls);
}

- (void)testComposer_ControlsStayOnTheBottomLineAsTheFieldGrows {
	TGChatComposerFrames one = TGChatComposerPlace(320, 416, 1);
	TGChatComposerFrames four = TGChatComposerPlace(320, 416, 4);
	XCTAssertEqual(four.well.size.height - one.well.size.height, 3 * TGChatComposerLineHeight());
	XCTAssertEqual(CGRectGetMaxY(four.send) + four.bar.origin.y,
			CGRectGetMaxY(one.send) + one.bar.origin.y);
	XCTAssertEqual(four.attach.origin.y, four.send.origin.y);
	XCTAssertEqual(four.sticker.origin.y, four.send.origin.y);
	// The AI entry is the slot above the paperclip.
	XCTAssertEqual(CGRectGetMaxY(four.ai), four.attach.origin.y);
	// The text ends where the sticker toggle starts.
	XCTAssertEqual(CGRectGetMaxX(four.text), four.sticker.origin.x);
	XCTAssertEqual(CGRectGetMaxX(four.sticker), CGRectGetMaxX(four.well));
}

- (void)testComposer_PastTheCapTheFieldScrolls {
	NSInteger cap = TGChatComposerMaxLines();
	TGChatComposerFrames over = TGChatComposerPlace(320, 416, cap + 3);
	XCTAssertTrue(over.scrolls);
	XCTAssertEqual(over.barHeight, TGChatComposerBarHeightForLines(cap));
	XCTAssertGreaterThan(TGChatComposerTextWidth(320), (CGFloat)0);
	XCTAssertEqual(TGChatComposerTextWidth(320) + kFieldLeftPad + TGMetricSendSide,
			TGChatComposerPlace(320, 416, 1).well.size.width);
}

- (void)testComposer_KeyboardLiftsBarAndShortensTheTable {
	CGRect bar, table;
	TGChatComposerAboveKeyboard(CGSizeMake(320, 416), 52, 216, &bar, &table);
	XCTAssertEqual(CGRectGetMaxY(bar), (CGFloat)(416 - 216));
	XCTAssertEqual(CGRectGetMaxY(table), CGRectGetMinY(bar));
}

- (void)testReplyPlate_RidesOnTheBarAndCentresOneLine {
	TGChatComposeBannerFrames one = TGChatComposeBannerPlace(320, 364, NO);
	TGChatComposeBannerFrames two = TGChatComposeBannerPlace(320, 364, YES);
	XCTAssertEqual(CGRectGetMaxY(one.plate), (CGFloat)364);
	XCTAssertEqual(CGRectGetMidY(one.title), TGHalf(kComposeBannerHeight));
	XCTAssertEqual(two.title.origin.y, kBannerTitleTop);
	XCTAssertEqual(two.subtitle.origin.y, CGRectGetMaxY(two.title));
	XCTAssertEqual(CGRectGetMaxX(one.close), (CGFloat)320);
	XCTAssertLessThanOrEqual(CGRectGetMaxX(one.title), one.close.origin.x);
}

#pragma mark - page header and empty state column

- (void)testStack_PartsFollowEachOtherWithFixedGaps {
	TGCentredStack s = TGCentredStackPlace(320, 16, 64, 26, 18, 36, CGSizeZero);
	XCTAssertEqual(CGRectGetMidX(s.art), (CGFloat)160);
	XCTAssertEqual(s.title.origin.y, CGRectGetMaxY(s.art) + TGMetricPadMedium);
	// The subtitle belongs to the title: no gap.
	XCTAssertEqual(s.subtitle.origin.y, CGRectGetMaxY(s.title));
	XCTAssertEqual(s.text.origin.y, CGRectGetMaxY(s.subtitle) + TGMetricPad);
	XCTAssertEqual(s.title.size.width, (CGFloat)(320 - 2 * TGMetricPadWide));
	XCTAssertEqual(s.height, CGRectGetMaxY(s.text) - 16 + TGMetricPadLarge);
}

- (void)testStack_AMissingPartTakesItsGapWithIt {
	// No art: the title starts at the top, not a gap below nothing.
	TGCentredStack s = TGCentredStackPlace(320, 16, 0, 26, 0, 0, CGSizeZero);
	XCTAssertTrue(CGRectIsEmpty(s.art));
	XCTAssertEqual(s.title.origin.y, (CGFloat)16);
	// Subtitle without a title keeps the gap from the art.
	TGCentredStack lone = TGCentredStackPlace(320, 0, 64, 0, 18, 0, CGSizeZero);
	XCTAssertEqual(lone.subtitle.origin.y, (CGFloat)(64 + TGMetricPadMedium));
}

- (void)testEmptyState_CentredButNeverUnderTheTop {
	TGCentredStack mid = TGEmptyStatePlace(CGSizeMake(320, 400), 64, 26, 36,
			CGSizeMake(160, 36));
	CGFloat content = CGRectGetMaxY(mid.button) - mid.art.origin.y;
	XCTAssertEqual(mid.art.origin.y, TGCenteredOrigin(400, content));
	XCTAssertEqual(mid.button.origin.y, CGRectGetMaxY(mid.subtitle) + TGMetricPadLarge);
	TGCentredStack tight = TGEmptyStatePlace(CGSizeMake(320, 60), 64, 26, 36, CGSizeZero);
	XCTAssertEqual(tight.art.origin.y, TGMetricPadWide);
}

// A word or phrase code had the digit-code sentence and digit boxes.
- (void)testLoginWordCode_UsesOfficialHint {
	NSString *word = TGLoginWordCodeSentence(@{ @"@type" : @"authenticationCodeTypeSmsWord", @"first_letter" : @"k" }, @"+1 555");
	XCTAssertTrue([word rangeOfString:@"starts with **\"k\"**"].location != NSNotFound);
	NSString *phrase = TGLoginWordCodeSentence(@{ @"@type" : @"authenticationCodeTypeSmsPhrase" }, @"+1 555");
	XCTAssertTrue([phrase hasPrefix:@"We've sent you an SMS with a secret phrase to your phone"]);
}


- (void)testEmailReset_PendingAndWaitWords {
	XCTAssertEqualObjects(TGLoginEmailResetPendingText(299), @"Email will be reset in 4:59");
	XCTAssertEqualObjects(TGLoginEmailResetPendingText(6 * 86400 + 5), @"Email will be reset in 6 days");
	XCTAssertEqualObjects(TGLoginEmailResetPendingText(0), @"Email will be reset Please wait...");
	XCTAssertEqualObjects(TGLoginResetInterval(3 * 3600), @"in 3 hours");
}

/// The Country row opened a search alert and up to 20 matches; official's
/// list is every country A-Z under letter headers.
- (void)testCountrySections_LetterHeadersInNameOrder {
	NSArray *countries = @[
		@{@"code" : @"DE", @"name" : @"Germany", @"prefix" : @"+49"},
		@{@"code" : @"AT", @"name" : @"Austria", @"prefix" : @"+43"},
		@{@"code" : @"GE", @"name" : @"Georgia", @"prefix" : @"+995"},
		@{@"code" : @"AX", @"name" : @"\u00C5land Islands", @"prefix" : @"+358"},
	];
	NSArray *sections = TGCountrySections(countries, @"");
	NSMutableArray *titles = [NSMutableArray array];
	for (NSDictionary *s in sections)
		[titles addObject:s[@"title"]];
	// Official takes the first letter as it is, so Aland's ring keeps its own header.
	XCTAssertEqualObjects(titles, (@[@"\u00C5", @"A", @"G"]));
	NSDictionary *g = sections.lastObject;
	XCTAssertEqualObjects(g[@"title"], @"G");
	XCTAssertEqualObjects([g[@"countries"] valueForKey:@"code"], (@[@"GE", @"DE"]));
}

- (void)testCountrySections_SearchByNameOrCode {
	NSArray *countries = @[
		@{@"code" : @"DE", @"name" : @"Germany", @"prefix" : @"+49"},
		@{@"code" : @"UA", @"name" : @"Ukraine", @"prefix" : @"+380"},
	];
	XCTAssertEqualObjects([TGCountrySections(countries, @"ger")[0][@"countries"] valueForKey:@"code"], (@[@"DE"]));
	XCTAssertEqualObjects([TGCountrySections(countries, @"+380")[0][@"countries"] valueForKey:@"code"], (@[@"UA"]));
	XCTAssertEqualObjects(TGCountrySections(countries, @"+380")[0][@"title"], @"");
	XCTAssertEqual(TGCountrySections(countries, @"zz").count, (NSUInteger)0);
}

@end
