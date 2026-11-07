#import "TGTestRunner.h"
#import "TGMessageCardView.h"
#import "TGStyle.h"
#import <math.h>

static TGMessageCard *mclMakeCard(NSString *kicker,
								  NSString *title,
								  NSArray *lines,
								  int64_t imageFileId,
								  CGFloat aspect,
								  BOOL isRound,
								  NSString *buttonTitle) {
	TGMessageCard *card = [[TGMessageCard alloc] init];
	card.kicker = kicker;
	card.title = title;
	card.lines = lines;
	card.imageFileId = imageFileId;
	card.imageAspect = aspect;
	card.imageIsRound = isRound;
	card.buttonTitle = buttonTitle;
	return card;
}

static BOOL mclHasAnyOverlap(TGMessageCardFrames frames) {
	CGRect rects[8];
	NSUInteger count = 0;
	if (!CGRectIsEmpty(frames.image)) {
		rects[count++] = frames.image;
	}
	if (!CGRectIsEmpty(frames.kicker)) {
		rects[count++] = frames.kicker;
	}
	if (!CGRectIsEmpty(frames.title)) {
		rects[count++] = frames.title;
	}
	for (NSUInteger i = 0; i < 4; i++) {
		if (!CGRectIsEmpty(frames.lines[i])) {
			rects[count++] = frames.lines[i];
		}
	}
	if (!CGRectIsEmpty(frames.button)) {
		rects[count++] = frames.button;
	}

	for (NSUInteger i = 0; i < count; i++) {
		for (NSUInteger j = i + 1; j < count; j++) {
			if (CGRectIntersectsRect(rects[i], rects[j])) {
				return YES;
			}
		}
	}
	return NO;
}

static BOOL mclAllFramesWithinWidth(TGMessageCardFrames frames, CGFloat width) {
	CGRect rects[8];
	NSUInteger count = 0;
	if (!CGRectIsEmpty(frames.image)) {
		rects[count++] = frames.image;
	}
	if (!CGRectIsEmpty(frames.kicker)) {
		rects[count++] = frames.kicker;
	}
	if (!CGRectIsEmpty(frames.title)) {
		rects[count++] = frames.title;
	}
	for (NSUInteger i = 0; i < 4; i++) {
		if (!CGRectIsEmpty(frames.lines[i])) {
			rects[count++] = frames.lines[i];
		}
	}
	if (!CGRectIsEmpty(frames.button)) {
		rects[count++] = frames.button;
	}

	for (NSUInteger i = 0; i < count; i++) {
		CGRect r = rects[i];
		if (CGRectGetMinX(r) < 0.0f || CGRectGetMaxX(r) > width) {
			return NO;
		}
	}
	return YES;
}

static BOOL mclIsIntegral(CGFloat val) {
	return fabs(val - floor(val)) < 0.001f;
}

static BOOL mclAllHeightsIntegral(TGMessageCardFrames frames) {
	if (!CGRectIsEmpty(frames.image) && !mclIsIntegral(frames.image.size.height)) {
		return NO;
	}
	if (!CGRectIsEmpty(frames.kicker) && !mclIsIntegral(frames.kicker.size.height)) {
		return NO;
	}
	if (!CGRectIsEmpty(frames.title) && !mclIsIntegral(frames.title.size.height)) {
		return NO;
	}
	for (NSUInteger i = 0; i < 4; i++) {
		if (!CGRectIsEmpty(frames.lines[i]) && !mclIsIntegral(frames.lines[i].size.height)) {
			return NO;
		}
	}
	if (!CGRectIsEmpty(frames.button) && !mclIsIntegral(frames.button.size.height)) {
		return NO;
	}
	if (!mclIsIntegral(frames.size.height)) {
		return NO;
	}
	return YES;
}

@interface TGMessageCardLayoutTests : XCTestCase @end

@implementation TGMessageCardLayoutTests

- (void)testNilCard_ReturnsZeroSizeAndFrames {
	TGMessageCardFrames f = TGMessageCardLayout(nil, 240.0f);
	XCTAssertTrue(f.size.width == 0.0f);
	XCTAssertTrue(f.size.height == 0.0f);
	XCTAssertTrue(CGRectIsEmpty(f.image));
	XCTAssertTrue(CGRectIsEmpty(f.kicker));
	XCTAssertTrue(CGRectIsEmpty(f.title));
	XCTAssertTrue(CGRectIsEmpty(f.button));
}

- (void)testZeroWidth_ReturnsZeroSizeAndFrames {
	TGMessageCard *card = mclMakeCard(@"Invoice", @"Monthly subscription", @[@"$9.99"], 1, 1.0f, NO, @"Pay");
	TGMessageCardFrames f0 = TGMessageCardLayout(card, 0.0f);
	XCTAssertTrue(f0.size.width == 0.0f);
	XCTAssertTrue(f0.size.height == 0.0f);

	TGMessageCardFrames fNeg = TGMessageCardLayout(card, -100.0f);
	XCTAssertTrue(fNeg.size.width == 0.0f);
	XCTAssertTrue(fNeg.size.height == 0.0f);
}

- (void)testNoImage_KickerStartsAtTopLeft {
	TGMessageCard *card = mclMakeCard(@"Gift", @"Telegram Premium", @[@"1 year"], 0, 1.0f, NO, @"View");
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);
	XCTAssertTrue(CGRectIsEmpty(f.image));
	XCTAssertFalse(CGRectIsEmpty(f.kicker));
	XCTAssertEqual(f.kicker.origin.x, 0.0f);
	XCTAssertEqual(f.kicker.origin.y, 0.0f);
	XCTAssertEqual(f.kicker.size.height, TGMetricLineCaption);
}

- (void)testSquareImage_TextColumnStartsAfterThumbAndGap {
	TGMessageCard *card = mclMakeCard(@"Invoice", @"Shoes", @[@"Size 42"], 42, 1.0f, NO, @"Buy");
	CGFloat width = 240.0f;
	TGMessageCardFrames f = TGMessageCardLayout(card, width);
	CGFloat expectedColX = TGMetricPersonRow + TGMetricPad;
	CGFloat expectedColW = width - expectedColX;

	XCTAssertEqual(f.image.origin.x, 0.0f);
	XCTAssertEqual(f.image.origin.y, 0.0f);
	XCTAssertEqual(f.image.size.width, TGMetricPersonRow);
	XCTAssertEqual(f.image.size.height, TGMetricPersonRow);

	XCTAssertEqual(f.kicker.origin.x, expectedColX);
	XCTAssertEqual(f.kicker.size.width, expectedColW);
	XCTAssertEqual(f.title.origin.x, expectedColX);
	XCTAssertEqual(f.title.size.width, expectedColW);
	XCTAssertEqual(f.lines[0].origin.x, expectedColX);
	XCTAssertEqual(f.lines[0].size.width, expectedColW);
}

- (void)testWideImage_Aspect16By9CalculatesHeightAndTitleBelow {
	TGMessageCard *card = mclMakeCard(nil, @"Game stream", @[@"Live now"], 99, 16.0f / 9.0f, NO, @"Watch");
	CGFloat width = 240.0f;
	TGMessageCardFrames f = TGMessageCardLayout(card, width);

	XCTAssertEqual(f.image.origin.x, 0.0f);
	XCTAssertEqual(f.image.origin.y, 0.0f);
	XCTAssertEqual(f.image.size.width, 240.0f);
	XCTAssertEqual(f.image.size.height, 135.0f);

	XCTAssertTrue(CGRectIsEmpty(f.kicker));
	XCTAssertEqual(f.title.origin.x, 0.0f);
	XCTAssertEqual(f.title.size.width, 240.0f);
	XCTAssertEqual(f.title.origin.y, 135.0f + TGMetricPad);
}

- (void)testRoundImage_IsSquareEvenWithWideAspect {
	TGMessageCard *card = mclMakeCard(@"User", @"John Doe", @[@"Online"], 55, 2.0f, YES, @"Open");
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);

	XCTAssertEqual(f.image.origin.x, 0.0f);
	XCTAssertEqual(f.image.origin.y, 0.0f);
	XCTAssertEqual(f.image.size.width, TGMetricPersonRow);
	XCTAssertEqual(f.image.size.height, TGMetricPersonRow);

	CGFloat expectedColX = TGMetricPersonRow + TGMetricPad;
	XCTAssertEqual(f.title.origin.x, expectedColX);
}

- (void)testButtonAbsent_ButtonRectIsZero {
	TGMessageCard *card = mclMakeCard(@"Info", @"Notice", @[@"Detail"], 0, 1.0f, NO, nil);
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);
	XCTAssertTrue(CGRectIsEmpty(f.button));
}

- (void)testButtonPresent_SitsBelowAllTextAndDefinesCardHeight {
	TGMessageCard *card = mclMakeCard(@"Giveaway", @"100 Telegram Stars", @[@"Winners selected", @"3 days left"], 0, 1.0f, NO, @"View giveaway");
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);

	XCTAssertFalse(CGRectIsEmpty(f.button));
	XCTAssertEqual(f.button.origin.x, 0.0f);
	XCTAssertEqual(f.button.size.width, 240.0f);
	XCTAssertEqual(f.button.size.height, TGMetricButtonHeightSmall);

	XCTAssertTrue(f.button.origin.y >= CGRectGetMaxY(f.kicker) + TGMetricPad);
	XCTAssertTrue(f.button.origin.y >= CGRectGetMaxY(f.title) + TGMetricPad);
	XCTAssertTrue(f.button.origin.y >= CGRectGetMaxY(f.lines[0]) + TGMetricPad);
	XCTAssertTrue(f.button.origin.y >= CGRectGetMaxY(f.lines[1]) + TGMetricPad);
	XCTAssertEqual(f.size.height, CGRectGetMaxY(f.button));
}

- (void)testButtonPresent_WithSquareImageShortText_SitsBelowSquareImage {
	TGMessageCard *card = mclMakeCard(nil, @"Hi", nil, 10, 1.0f, NO, @"Action");
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);

	CGFloat expectedMinY = TGMetricPersonRow + TGMetricPad;
	XCTAssertTrue(f.button.origin.y >= expectedMinY);
	XCTAssertEqual(f.size.height, CGRectGetMaxY(f.button));
}

- (void)testFourLineCap_ExtraLinesIgnoredAndStopsAtLineFour {
	NSArray *sixLines = @[@"Line 0", @"Line 1", @"Line 2", @"Line 3", @"Line 4", @"Line 5"];
	TGMessageCard *card = mclMakeCard(nil, @"Title", sixLines, 0, 1.0f, NO, nil);
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);

	XCTAssertFalse(CGRectIsEmpty(f.lines[0]));
	XCTAssertFalse(CGRectIsEmpty(f.lines[1]));
	XCTAssertFalse(CGRectIsEmpty(f.lines[2]));
	XCTAssertFalse(CGRectIsEmpty(f.lines[3]));
	XCTAssertEqual(f.size.height, CGRectGetMaxY(f.lines[3]));
}

- (void)testFourLineCap_WithButton_StopsAtButton {
	NSArray *sixLines = @[@"A", @"B", @"C", @"D", @"E", @"F"];
	TGMessageCard *card = mclMakeCard(nil, @"Title", sixLines, 0, 1.0f, NO, @"Done");
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);

	XCTAssertFalse(CGRectIsEmpty(f.lines[3]));
	XCTAssertTrue(f.button.origin.y >= CGRectGetMaxY(f.lines[3]) + TGMetricPad);
	XCTAssertEqual(f.size.height, CGRectGetMaxY(f.button));
}

- (void)testAllFramesWithinWidth_160 {
	TGMessageCard *card = mclMakeCard(@"Kicker", @"A title", @[@"Detail 1", @"Detail 2"], 12, 1.0f, NO, @"Tap");
	TGMessageCardFrames f = TGMessageCardLayout(card, 160.0f);
	XCTAssertTrue(mclAllFramesWithinWidth(f, 160.0f));
}

- (void)testAllFramesWithinWidth_240 {
	TGMessageCard *card = mclMakeCard(@"Kicker", @"A title", @[@"Detail 1", @"Detail 2"], 12, 1.5f, NO, @"Tap");
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);
	XCTAssertTrue(mclAllFramesWithinWidth(f, 240.0f));
}

- (void)testAllFramesWithinWidth_300 {
	TGMessageCard *card = mclMakeCard(@"Kicker", @"A title", @[@"Detail 1", @"Detail 2"], 12, 1.0f, NO, @"Tap");
	TGMessageCardFrames f = TGMessageCardLayout(card, 300.0f);
	XCTAssertTrue(mclAllFramesWithinWidth(f, 300.0f));
}

- (void)testNoOverlaps_SquareImage {
	NSArray *lines = @[@"First", @"Second", @"Third", @"Fourth"];
	TGMessageCard *card = mclMakeCard(@"Category", @"Main Heading", lines, 10, 1.0f, NO, @"Action");
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);
	XCTAssertFalse(mclHasAnyOverlap(f));
}

- (void)testNoOverlaps_WideImage {
	NSArray *lines = @[@"Alpha", @"Beta", @"Gamma"];
	TGMessageCard *card = mclMakeCard(@"Stream", @"Major League Gaming", lines, 20, 16.0f / 9.0f, NO, @"Watch");
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);
	XCTAssertFalse(mclHasAnyOverlap(f));
}

- (void)testNoOverlaps_NoImage {
	NSArray *lines = @[@"Line A", @"Line B"];
	TGMessageCard *card = mclMakeCard(@"Order", @"Confirmation #10029", lines, 0, 1.0f, NO, @"Track");
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);
	XCTAssertFalse(mclHasAnyOverlap(f));
}

- (void)testVeryLongTitle_CappedAtTwoLines {
	NSString *longTitle = @"This is a very long title designed to span across more than two lines of text at narrow column width";
	TGMessageCard *card = mclMakeCard(nil, longTitle, nil, 0, 1.0f, NO, nil);
	TGMessageCardFrames f = TGMessageCardLayout(card, 160.0f);
	XCTAssertEqual(f.title.size.height, 2.0f * TGMetricLineBody);
}

- (void)testEmptyKicker_GivesZeroKickerFrameAndTitleAtTop {
	TGMessageCard *card = mclMakeCard(@"", @"Headline", @[@"Subtitle"], 0, 1.0f, NO, nil);
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);
	XCTAssertTrue(CGRectIsEmpty(f.kicker));
	XCTAssertEqual(f.title.origin.y, 0.0f);
}

- (void)testHeightsAreIntegral_AcrossAllComponents {
	NSArray *lines = @[@"Line 1", @"Line 2"];
	TGMessageCard *card = mclMakeCard(@"Header", @"Medium Length Title", lines, 7, 1.33f, NO, @"Go");
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);
	XCTAssertTrue(mclAllHeightsIntegral(f));
}

- (void)testAspectThreshold_Boundaries {
	TGMessageCard *card101 = mclMakeCard(nil, @"Test", nil, 1, 1.01f, NO, nil);
	TGMessageCardFrames f101 = TGMessageCardLayout(card101, 240.0f);
	XCTAssertEqual(f101.image.size.width, TGMetricPersonRow);

	TGMessageCard *card102 = mclMakeCard(nil, @"Test", nil, 1, 1.02f, NO, nil);
	TGMessageCardFrames f102 = TGMessageCardLayout(card102, 240.0f);
	XCTAssertEqual(f102.image.size.width, 240.0f);
}

- (void)testNilButtonTitle_GivesZeroButtonFrame {
	TGMessageCard *card = mclMakeCard(@"Invoice", @"Paid", @[@"Receipt #44"], 0, 1.0f, NO, nil);
	TGMessageCardFrames f = TGMessageCardLayout(card, 240.0f);
	XCTAssertTrue(CGRectIsEmpty(f.button));
}

/// A long prize line wraps to a second line instead of being cut at the
/// card's edge, and the lines under it move down.
- (void)testLongLineWrapsOnce {
	TGMessageCard *card = [[TGMessageCard alloc] init];
	card.title = @"Giveaway Prizes";
	card.lines = @[@"3 Telegram Premium subscriptions for 3 months", @"Only new subscribers"];
	TGMessageCardFrames f = TGMessageCardLayout(card, 160);
	XCTAssertTrue(f.lines[0].size.height > TGMetricLineSubhead);
	XCTAssertTrue(f.lines[0].size.height <= 2 * TGMetricLineSubhead + 1);
	XCTAssertTrue(f.lines[1].origin.y >= CGRectGetMaxY(f.lines[0]));
	XCTAssertTrue(f.lines[1].size.height < 2 * TGMetricLineSubhead);
}

@end
