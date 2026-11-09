// TGMessageLayoutTests.m — regression tests for TGMessageLayout's pure
// text/geometry layer, on the macOS host through the UIKit shim.
//
// Zone this covers (frequently-fixed, never tested before): word wrapping
// and text measurement, emoji attribute handling and message entities —
// the inputs the chat bubble geometry chain feeds on.
//
// The bubble/caption/reply-bar geometry itself lives in
// TGChatViewController+Layout.m and TGMessageBubbleCell.m, whose measurement needs
// a live UIView hierarchy a host shim cannot honestly provide; those are
// not covered here (see the PR report).
#import "TGTestRunner.h"
#import "TGMessageLayout.h"
#import "TGCapabilities.h"
#include <string.h>
#include <time.h>

static NSString *kWord = @"Supercalifragilisticexpialidocious";
static NSString *kWord2 = @"antidisestablishmentarianism";

@interface TGMessageLayoutTests : XCTestCase
@end

@implementation TGMessageLayoutTests

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - measurement basics

/// A stamp on the body's last line sits inside the body, its bottom on the
/// body's bottom. The chat once added the body height twice and drew every
/// stamp under its own bubble, over the top of the next one.
static BOOL TGTestLacksComet(UTF32Char c) { return c == 0x2604; }

/// U+FE0F after an emoji the emoji face lacks sent CoreText through every
/// font on disk (2.4 s cold in the first chat row). Only that selector goes;
/// one after an emoji the face has stays, and nothing else moves.
- (void)testSelectorAfterLackingEmojiIsDroppedAndOthersStay {
	NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
			initWithString:@"\u2604\uFE0F\u2604\uFE0F\u26D4\uFE0F a"];
	XCTAssertTrue(TGDropEmojiSelectors(text, TGTestLacksComet));
	XCTAssertEqualObjects(text.string, @"\u2604\u2604\u26D4\uFE0F a");
	NSMutableAttributedString *plain = [[NSMutableAttributedString alloc]
			initWithString:@"\u26D4\uFE0F"];
	XCTAssertFalse(TGDropEmojiSelectors(plain, TGTestLacksComet));
	XCTAssertEqualObjects(plain.string, @"\u26D4\uFE0F");
}

- (void)testInlineStamp_SitsOnTheBodysLastLine {
	CGRect body = CGRectMake(10, 6, 120, 21);
	CGFloat y = TGInlineStampY(body);
	XCTAssertTrue(y >= CGRectGetMinY(body));
	XCTAssertTrue(fabs(y + TGMetricLineMicro - CGRectGetMaxY(body)) < 0.01);
}

/// What an iOS 7 font list would answer for the characters below: these
/// emoji yes, a hieroglyph, Bamum, U+1D0D and the 2017 face 🥰 no.
static BOOL TGTestOldFonts(UTF32Char c) {
	return c == 0x1F431 || c == 0x1F1FA || c == 0x1F1E6 || c == 0x1F468 ||
		   c == 0x1F4BB || c == 0x2764;
}

/// A sticker set titled "\U00013102 Eᴍᴏᴊɪ² | @HANGSEED\U00016A18" cost up to
/// 2.75 s to draw on a 4S: one character no font had sent CoreText through
/// every font on disk. What the device fonts lack goes, emoji newer than its
/// emoji font included; joiners and variation selectors stay; untouched text is the same
/// object back.
- (void)testStripScalars_DropsWhatNoFontHasKeepsEmojiAndJoiners {
	NSString *title = @"\U00013102E\u1D0D\u00B2 | @HANGSEED\U00016A18";
	XCTAssertEqualObjects(TGStripScalars(title, TGTestOldFonts), @"E\u00B2 | @HANGSEED");
	NSString *emoji = @"Cats \U0001F431 \U0001F1FA\U0001F1E6 \U0001F468\u200D\U0001F4BB \u2764\uFE0F";
	XCTAssertTrue(TGStripScalars(emoji, TGTestOldFonts) == emoji);
	XCTAssertEqualObjects(TGStripScalars(@"Love \U0001F970", TGTestOldFonts), @"Love ");
	NSString *plain = @"Cats and dogs";
	XCTAssertTrue(TGStripScalars(plain, TGTestOldFonts) == plain);
	XCTAssertEqualObjects(TGStripScalars(@"", TGTestOldFonts), @"");
	// The real coverage test leaves Latin text alone without asking a font.
	XCTAssertTrue(TGStripUndrawableScalars(plain) == plain);
}

/// A custom emoji becomes one attachment in place of its fallback emoji,
/// carrying its id, and the entities after it still land on their own
/// characters even though the string got shorter.
- (void)testAttributedMessageText_CustomEmojiBecomesOneAttachment {
	NSString *text = @"Hi \U0001F44D there";   // the thumbs-up is two UTF-16 units
	NSArray *entities = @[
		@{@"offset" : @(3), @"length" : @(2),
		  @"type" : @{@"@type" : @"textEntityTypeCustomEmoji", @"custom_emoji_id" : @"5368324170671202286"}},
		@{@"offset" : @(6), @"length" : @(5), @"type" : @{@"@type" : @"textEntityTypeBold"}},
	];
	UIFont *font = TGFontBody();
	NSAttributedString *out = TGAttributedMessageText(text, entities, font, [UIColor blackColor]);
	XCTAssertEqual((NSInteger)out.length, (NSInteger)text.length - 1);
	XCTAssertEqual([out.string characterAtIndex:3], (unichar)0xFFFC);
	XCTAssertEqual([[out attribute:@"TGCustomEmojiId" atIndex:3 effectiveRange:NULL] longLongValue],
			5368324170671202286LL);
	XCTAssertEqualObjects([out.string substringFromIndex:5], @"there");
	UIFont *bold = [out attribute:NSFontAttributeName atIndex:5 effectiveRange:NULL];
	XCTAssertEqualObjects(bold.fontName, TGFontBoldAtSize(font.pointSize).fontName);
	XCTAssertTrue([out attribute:@"TGCustomEmojiId" atIndex:5 effectiveRange:NULL] == nil);
}

- (void)testTextSize_EmptyTextIsZero {
	CGSize empty = TGTextSize(@"", nil, 246);
	XCTAssertEqual(empty.width,  0.0);
	XCTAssertEqual(empty.height, 0.0);
}

- (void)testTextSize_ShortTextIsOneLine {
	UIFont *font = [UIFont systemFontOfSize:15];
	CGSize size = TGTextSize(@"Hi", font, 246);
	XCTAssertGreaterThan(size.width, 0.0, @"measured text must have width");
	XCTAssertGreaterThan(size.height, 0.0, @"measured text must have height");

	CGSize oneLine = TGTextSize(@"x", font, 246);
	XCTAssertLessThanOrEqual(size.height, oneLine.height + 1.0,
			@"short text must not wrap into more lines than single-letter text");
}

- (void)testTextSize_TighterColumnIsNeverShorter {
	// Word wrapping regression: a narrower measure width must never give a
	// shorter (or smaller) height than a wider one.
	UIFont *font = [UIFont systemFontOfSize:15];
	NSString *text = @"The quick brown fox jumps over the lazy dog again and again";
	CGSize wide  = TGTextSize(text, font, 246);
	CGSize mid   = TGTextSize(text, font, 120);
	CGSize tight = TGTextSize(text, font,  60);
	XCTAssertGreaterThanOrEqual(mid.height,   ceil(wide.height)  - 1.0,
			@"120pt must wrap at least as tall as 246pt");
	XCTAssertGreaterThanOrEqual(tight.height, ceil(mid.height)   - 1.0,
			@"60pt must wrap at least as tall as 120pt");
}

- (void)testTextSize_UnbreakableLongWordWrapsToMultipleLines {
	// A single word wider than the bubble must still be laid out (hard
	// character wrap), not report one line and clip on the device.
	UIFont *font = [UIFont systemFontOfSize:15];
	NSString *longWord = [kWord stringByAppendingString:kWord2];   // ~40 chars
	CGSize oneLine  = TGTextSize(@"Hi", font, 246);
	CGSize wrapped = TGTextSize(longWord, font, 100);
	XCTAssertGreaterThan(wrapped.height, oneLine.height,
			@"a long word at 100pt must occupy more than one line");
}

- (void)testTextSize_RunsOutOfMeasureWidthRatherThanShrinking {
	// Height is capped by wraps, not by text length: the same word at a
	// width wide enough for it must be one line tall.
	UIFont *font = [UIFont systemFontOfSize:15];
	CGSize loose = TGTextSize(kWord, font, 1000);
	CGSize oneLine = TGTextSize(@"Hi", font, 1000);
	XCTAssertLessThanOrEqual(loose.height, oneLine.height + 1.0,
			@"a word that fits must stay on one line");
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - entities

- (void)testAttributedMessageText_NilForEmpty {
	XCTAssertNil(TGAttributedMessageText(@"", nil, nil, nil));
}

- (void)testAttributedMessageText_PlainKeepsLengthAndColour {
	UIFont *font = [UIFont systemFontOfSize:15];
	NSString *text = @"no entities here";
	NSAttributedString *str = TGAttributedMessageText(text, nil, font,
			[UIColor redColor]);
	XCTAssertNotNil(str);
	XCTAssertEqual(str.length, text.length, @"plain attribution must keep every character");

	UIColor *colour = [str attribute:NSForegroundColorAttributeName
			atIndex:0 effectiveRange:NULL];
	XCTAssertNotNil(colour, @"message colour must be applied");
}

- (void)testAttributedMessageText_UnderlineEntity {
	UIFont *font = [UIFont systemFontOfSize:15];
	NSDictionary *ent = @{@"offset" : @0, @"length" : @5,
						  @"type" : @{@"@type" : @"textEntityTypeUnderline"}};
	NSAttributedString *str = TGAttributedMessageText(@"hello world", @[ent],
			font, nil);

	NSNumber *underline = [str attribute:NSUnderlineStyleAttributeName
			atIndex:0 effectiveRange:NULL];
	XCTAssertEqual([underline integerValue], NSUnderlineStyleSingle,
			@"the underlined range must be marked for one underline");
	NSNumber *outside = [str attribute:NSUnderlineStyleAttributeName
			atIndex:6 effectiveRange:NULL];
	XCTAssertNil(outside, @"text outside the entity must be untouched");
}

- (void)testAttributedMessageText_BoldEntityDiffersFromBodyFont {
	UIFont *font = [UIFont systemFontOfSize:15];
	NSDictionary *ent = @{@"offset" : @6, @"length" : @5,
						  @"type" : @{@"@type" : @"textEntityTypeBold"}};
	NSAttributedString *str = TGAttributedMessageText(@"plain bold here", @[ent],
			font, nil);

	UIFont *body  = [str attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
	UIFont *inside = [str attribute:NSFontAttributeName atIndex:8 effectiveRange:NULL];
	XCTAssertNotNil(body);
	XCTAssertNotNil(inside);
	XCTAssertNotEqual(inside, body, @"the bold run must carry a different font");
}

- (void)testAttributedMessageText_TextUrlCarriesItsTarget {
	UIFont *font = [UIFont systemFontOfSize:15];
	NSDictionary *ent = @{@"offset" : @3, @"length" : @4,
						  @"type" : @{@"@type" : @"textEntityTypeTextUrl",
									  @"url" : @"https://example.com"}};
	NSAttributedString *str = TGAttributedMessageText(@"see here ok", @[ent],
			font, nil);

	NSString *url = [str attribute:@"TGLinkURL" atIndex:4 effectiveRange:NULL];
	XCTAssertTrue([url isEqualToString:@"https://example.com"],
			@"the entity's target must ride along for the tap handler");
	NSNumber *underline = [str attribute:NSUnderlineStyleAttributeName
			atIndex:4 effectiveRange:NULL];
	XCTAssertNotNil(underline, @"text urls render as links");
}

- (void)testAttributedMessageText_UrlEntityIsTheTextItself {
	UIFont *font = [UIFont systemFontOfSize:15];
	NSDictionary *ent = @{@"offset" : @0, @"length" : @11,
						  @"type" : @{@"@type" : @"messageEntityUrl"}};
	NSAttributedString *str = TGAttributedMessageText(@"example.com", @[ent],
			font, nil);
	NSString *url = [str attribute:@"TGLinkURL" atIndex:2 effectiveRange:NULL];
	XCTAssertTrue([url isEqualToString:@"example.com"]);
}

- (void)testAttributedMessageText_EntitiesOutsideTextAreIgnored {
	// Entities beyond the text, negative offsets and zero-length runs used
	// to crash the chat; they are dropped.
	UIFont *font = [UIFont systemFontOfSize:15];
	NSArray *entities = @[
		@{@"offset" : @0, @"length" : @500,
		  @"type" : @{@"@type" : @"messageEntitySpoiler"}},
		@{@"offset" : @-3, @"length" : @2,
		  @"type" : @{@"@type" : @"messageEntitySpoiler"}},
		@{@"offset" : @2, @"length" : @0,
		  @"type" : @{@"@type" : @"messageEntitySpoiler"}},
		@"not-an-entity",
	];
	NSAttributedString *str = TGAttributedMessageText(@"tiny", entities, font, nil);
	XCTAssertNotNil(str);
	XCTAssertEqual(str.length, 4u, @"dropped entities must not change the text");

	__block BOOL painted = NO;
	[str enumerateAttribute:NSBackgroundColorAttributeName
					inRange:NSMakeRange(0, str.length)
					options:0
				 usingBlock:^(id value, NSRange range, BOOL *stop){
					 if (value) painted = YES;
				 }];
	XCTAssertFalse(painted,
			@"an entity longer than the text must not paint the whole message");
}

- (void)testAttributedMessageText_MentionAndBoldInLegacyShapes {
	// TDLib sends both nested ("type" dict) and flat ("@type") entity
	// spellings depending on version; both must land.
	UIFont *font = [UIFont systemFontOfSize:15];
	NSAttributedString *str = TGAttributedMessageText(@"@user text",
			@[@{@"offset" : @0, @"length" : @5,
				@"@type" : @"messageEntityMention"}], font, nil);
	UIColor *mention = [str attribute:NSForegroundColorAttributeName
			atIndex:0 effectiveRange:NULL];
	XCTAssertNotNil(mention);
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - measurement with entities

- (void)testTextSizeWithEntities_MeasuresLikePlain {
	UIFont *font = [UIFont systemFontOfSize:15];
	NSString *text = @"hello bold world";
	NSDictionary *ent = @{@"offset" : @6, @"length" : @4,
						  @"type" : @{@"@type" : @"textEntityTypeBold"}};
	CGSize withEntity  = TGTextSizeWithEntities(text, @[ent], font, 246);
	CGSize without     = TGTextSize(text, font, 246);
	XCTAssertGreaterThan(withEntity.width, 0.0);
	XCTAssertGreaterThan(without.width, 0.0);
	XCTAssertLessThanOrEqual(withEntity.height, without.height + 1.0,
			@"entities may flavour but must not rewrap the same single line");
}

- (void)testTextSizeWithEntities_EmptyTextIsZero {
	CGSize empty = TGTextSizeWithEntities(@"", nil, nil, 246);
	XCTAssertEqual(empty.width,  0.0);
	XCTAssertEqual(empty.height, 0.0);
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - emoji scalars

- (void)testIsEmojiScalar_Boundaries {
	XCTAssertTrue(TGIsEmojiScalar(0x1F000));      // first pictograph
	XCTAssertFalse(TGIsEmojiScalar(0x1EFFF));     // just below
	XCTAssertTrue(TGIsEmojiScalar(0x1FAFF));      // last extended pictograph
	XCTAssertFalse(TGIsEmojiScalar(0x1FB00));     // symbol block after it
	XCTAssertTrue(TGIsEmojiScalar(0x2600));       // misc symbols
	XCTAssertTrue(TGIsEmojiScalar(0x27BF));       // last dingbat
	XCTAssertTrue(TGIsEmojiScalar(0x2B00));       // arrows/stars open
	XCTAssertTrue(TGIsEmojiScalar(0x2BFF));       // arrows/stars close
	XCTAssertFalse(TGIsEmojiScalar(0x2C00));      // just past arrows
	XCTAssertFalse(TGIsEmojiScalar(0x0041));      // plain latin
	XCTAssertFalse(TGIsEmojiScalar(0x0020));      // space
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - emoji attribution

- (void)testEmojiAttributedText_EmptyIsNil {
	XCTAssertNil(TGEmojiAttributedText(@"", [UIFont systemFontOfSize:15]));
}

- (void)testEmojiAttributedText_PlainTextNeverDowngraded {
	NSString *plain = @"just words";
	NSAttributedString *styled = TGEmojiAttributedText(plain,
			[UIFont systemFontOfSize:15]);
	if (styled){   // an emoji font is registered on this host
		XCTAssertEqual(styled.length, plain.length,
				@"emoji styling must not drop characters");
		UIFont *f = [styled attribute:NSFontAttributeName atIndex:0
				effectiveRange:NULL];
		XCTAssertNotNil(f, @"plain text must keep some font");
	}
	// and either way the call is safe to repeat (cache)
	NSAttributedString *again = TGEmojiAttributedText(plain,
			[UIFont systemFontOfSize:15]);
	if (styled && again)
		XCTAssertTrue([again isEqualToAttributedString:styled],
				@"the cache must return the same attribution");
}

- (void)testEmojiAttributedText_EmojiTextKeepsLength {
	NSString *emoji = @"\U0001F600\U0001F601 ok";
	NSAttributedString *styled = TGEmojiAttributedText(emoji,
			[UIFont systemFontOfSize:15]);
	if (styled)
		XCTAssertEqual(styled.length, emoji.length);
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - TGSetBodyText

- (void)testSetBodyText_PlainTextLandsInLabel {
	UILabel *label = [[UILabel alloc] init];
	NSString *text = @"plain message";
	TGSetBodyText(label, text, [UIColor redColor]);
	XCTAssertEqualObjects(label.attributedText, nil, @"no emoji: plain path");
	XCTAssertEqualObjects(label.text, text);
	XCTAssertTrue([label.textColor isEqual:[UIColor redColor]],
			@"the bubble colour must be applied");
}

- (void)testSetBodyText_EmptyDoesNotThrow {
	UILabel *label = [[UILabel alloc] init];
	XCTAssertNoThrow(TGSetBodyText(label, @"", [UIColor blackColor]),
			@"an empty message must not blank a label into a bad state");
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - TGMessageLayout shell

- (void)testMessageLayout_FullRadiusReplyBarConstants {
	// The geometry chain reads these; the numbers the fix history turned on.
	XCTAssertGreaterThan(kBubbleMaxW, 0.0);
	XCTAssertGreaterThan(kTailHeight, kTailWidth, @"tail proportions");
	XCTAssertEqual(kMediaRadius, 6.0f);
}

- (void)testMessageLayout_AllocableWithDefaultGeometry {
	TGMessageLayout *layout = [[TGMessageLayout alloc] init];
	XCTAssertEqual(layout.rowHeight, 0.0);
	layout.bubbleFrame = CGRectMake(0, 0, kBubbleMaxW, 20);
	XCTAssertEqual(layout.bubbleFrame.size.width, kBubbleMaxW);
}

- (void)testLruLayoutCache_HitsConsistently {
	UIFont *font15 = [UIFont systemFontOfSize:15];
	UIFont *font17 = [UIFont systemFontOfSize:17];
	NSString *text = @"Caching test message for C++ LRU layout cache";

	CGSize size1 = TGTextSize(text, font15, 200);
	CGSize size2 = TGTextSize(text, font15, 200);
	XCTAssertEqual(size1.width, size2.width);
	XCTAssertEqual(size1.height, size2.height);

	CGSize sizeDiffFont = TGTextSize(text, font17, 200);
	XCTAssertGreaterThanOrEqual(sizeDiffFont.height, size1.height);
}

- (void)testEmojiScanning_FastBypassForPlainLetters {
	NSString *plain = @"Hello, this is pure ASCII without any emoji.";
	UIFont *font = [UIFont systemFontOfSize:15];
	NSAttributedString *str1 = TGEmojiAttributedText(plain, font);
	NSAttributedString *str2 = TGEmojiAttributedText(plain, font);
	XCTAssertNil(str1);
	XCTAssertNil(str2);
}

- (void)testDescribeMessageContent_Types {
	XCTAssertEqualObjects(TGDescribeMessageContent(@{@"kind" : @"messageVideoNote"}), @"Video message");
	XCTAssertEqualObjects(TGDescribeMessageContent(@{@"kind" : @"messageVoiceNote"}), @"Voice message");
	XCTAssertEqualObjects(TGDescribeMessageContent(@{@"kind" : @"messageSticker", @"emoji" : @"\U0001F600"}), @"Sticker \U0001F600");
	XCTAssertEqualObjects(TGDescribeMessageContent(@{@"kind" : @"messageSticker"}), @"Sticker");
	XCTAssertEqualObjects(TGDescribeMessageContent(@{@"kind" : @"messagePhoto"}), @"Photo");
	XCTAssertEqualObjects(TGDescribeMessageContent(@{@"kind" : @"messageVideo"}), @"Video");
	XCTAssertEqualObjects(TGDescribeMessageContent(@{@"kind" : @"messageAnimation"}), @"GIF");
	XCTAssertEqualObjects(TGDescribeMessageContent(@{@"kind" : @"messageDocument", @"docName" : @"file.pdf"}), @"file.pdf");
	XCTAssertEqualObjects(TGDescribeMessageContent(@{@"text" : @"Hello"}), @"Hello");
}

- (void)testVideoNoteLayout_SymmetricGeometry {
	CGRect bubble = CGRectMake(100, 10, 200, 200);
	CGRect durFrame = CGRectZero, timeFrame = CGRectZero, ticksFrame = CGRectZero, dotFrame = CGRectZero;
	TGVideoNoteLayoutBottomBar(bubble, 30.0f, 40.0f, YES, NO, &durFrame, &timeFrame, &ticksFrame, &dotFrame);

	// Both must be placed beneath the circle
	XCTAssertTrue(fabs(durFrame.origin.y - (bubble.origin.y + bubble.size.height + TGMetricPadSmall)) < 0.01);
	XCTAssertTrue(fabs(timeFrame.origin.y - (bubble.origin.y + bubble.size.height + TGMetricPadSmall)) < 0.01);

	// Duration on the left side of the circle
	XCTAssertTrue(fabs(durFrame.origin.x - (bubble.origin.x + TGMetricPadSmall)) < 0.01);

	// Time group on the right side of the circle
	CGFloat groupW = 40.0f + TGMetricPadSmall + TGMetricTicksWidth;
	XCTAssertTrue(fabs(timeFrame.origin.x - (bubble.origin.x + bubble.size.width - groupW - TGMetricPadSmall)) < 0.01);

	// Equal margin from the respective edges
	CGFloat leftMargin = durFrame.origin.x - bubble.origin.x;
	CGFloat rightMargin = (bubble.origin.x + bubble.size.width) - (timeFrame.origin.x + groupW);
	XCTAssertTrue(fabs(leftMargin - rightMargin) < 0.01);
}

#pragma mark - C++ LRU layout cache tests

- (void)testMessageLayoutCache_LruEvictionAndPromotion {
	TGMessageLayoutCache *cache = [[TGMessageLayoutCache alloc] initWithCapacity:3];
	XCTAssertEqual(cache.count, (NSUInteger)0);

	cache[@1] = @"one";
	cache[@2] = @"two";
	cache[@3] = @"three";
	XCTAssertEqual(cache.count, (NSUInteger)3);
	XCTAssertEqualObjects(cache[@1], @"one");
	XCTAssertEqualObjects(cache[@2], @"two");
	XCTAssertEqualObjects(cache[@3], @"three");

	// Accessing @1 promotes it to MRU (order now: 2, 3, 1)
	id val1 = cache[@1];
	XCTAssertEqualObjects(val1, @"one");

	// Inserting 4th item must evict LRU (@2)
	cache[@4] = @"four";
	XCTAssertEqual(cache.count, (NSUInteger)3);
	XCTAssertNil(cache[@2]); // @2 evicted!
	XCTAssertEqualObjects(cache[@1], @"one");
	XCTAssertEqualObjects(cache[@3], @"three");
	XCTAssertEqualObjects(cache[@4], @"four");

	// Clear cache
	[cache removeAllObjects];
	XCTAssertEqual(cache.count, (NSUInteger)0);
	XCTAssertNil(cache[@1]);
	XCTAssertNil(cache[@3]);
	XCTAssertNil(cache[@4]);
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - bubble stamp

- (void)testMessageStamp_NoDateIsAnEmptyLine {
	XCTAssertEqualObjects(TGMessageStamp(0, NO), @"");
	XCTAssertEqualObjects(TGMessageStamp(-1, YES), @"");
}

- (void)testMessageStamp_ClockIsTheLocalHourAndMinute {
	struct tm value;
	memset(&value, 0, sizeof(value));
	value.tm_year = 124;   // 2024
	value.tm_mon = 0;
	value.tm_mday = 2;
	value.tm_hour = 9;
	value.tm_min = 5;
	value.tm_isdst = -1;
	NSTimeInterval stamp = (NSTimeInterval)mktime(&value);
	NSDateFormatter *clock = [[NSDateFormatter alloc] init];
	clock.dateStyle = NSDateFormatterNoStyle;
	clock.timeStyle = NSDateFormatterShortStyle;
	NSString *expected = [clock stringFromDate:
			[NSDate dateWithTimeIntervalSince1970:stamp]];
	XCTAssertEqualObjects(TGMessageStamp(stamp, NO), expected);
	XCTAssertTrue([TGMessageStamp(stamp, NO) rangeOfString:@":"].location != NSNotFound,
			@"a short clock still has the time separator");
}

- (void)testMessageStamp_EditedComesAfterTheClock {
	struct tm value;
	memset(&value, 0, sizeof(value));
	value.tm_year = 124;
	value.tm_mon = 4;
	value.tm_mday = 6;
	value.tm_hour = 23;
	value.tm_min = 40;
	value.tm_isdst = -1;
	NSTimeInterval stamp = (NSTimeInterval)mktime(&value);
	NSString *line = TGMessageStamp(stamp, YES);
	NSDateFormatter *clock = [[NSDateFormatter alloc] init];
	clock.dateStyle = NSDateFormatterNoStyle;
	clock.timeStyle = NSDateFormatterShortStyle;
	NSString *time = [clock stringFromDate:
			[NSDate dateWithTimeIntervalSince1970:stamp]];
	NSString *expected = [NSString stringWithFormat:@"edited %@", time];
	XCTAssertEqualObjects(line, expected);
	XCTAssertTrue([line hasPrefix:@"edited"],
			@"Telegram puts the edited mark before the time, as the pack does");
}

/// The emoji check is warmed on a background queue while the main thread
/// asks too (TGWarmEmojiData). Its cache was a bare dictionary: two threads
/// filling it at once could corrupt it. Every thread must get the answer a
/// single thread gets.
- (void)testCanDrawEmoji_SameAnswersFromManyThreads {
	NSArray *probe = @[@"😀", @"🇺🇦", @"👍", @"x", @"🏁", @"❤️", @"🍔", @"🚗",
					   @"🇩🇪", @"⚽️", @"💡", @"🐻", @"a", @"🙈", @"😂", @"🎵"];
	NSMutableArray *expected = [NSMutableArray array];
	__block BOOL mismatch = NO;
	dispatch_apply(64, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i){
		NSString *e = [NSString stringWithFormat:@"%@%zu", probe[i % probe.count], i];
		[TGCapabilities canDrawEmoji:e];
		[TGCapabilities canDrawEmoji:probe[i % probe.count]];
	});
	for (NSString *e in probe)
		[expected addObject:@([TGCapabilities canDrawEmoji:e])];
	dispatch_apply(64, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i){
		NSUInteger k = i % probe.count;
		if ([TGCapabilities canDrawEmoji:probe[k]] != [expected[k] boolValue])
			mismatch = YES;
	});
	XCTAssertFalse(mismatch);
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - text spoilers

static NSDictionary *spSpoilerEntity(NSInteger offset, NSInteger length, NSString *type) {
	return @{@"offset" : @(offset), @"length" : @(length),
			 @"type" : @{@"@type" : type}};
}

/// A hidden spoiler is the plate colour in both roles, so the glyphs vanish
/// into the bar instead of staying readable.
- (void)testSpoiler_HiddenRangeDrawsGlyphsInThePlateColour {
	UIFont *font = [UIFont systemFontOfSize:15];
	NSAttributedString *str = TGAttributedMessageTextRevealing(@"before secret after",
			@[spSpoilerEntity(7, 6, @"textEntityTypeSpoiler")], font,
			[UIColor blackColor], NO);
	UIColor *background = [str attribute:NSBackgroundColorAttributeName
			atIndex:7 effectiveRange:NULL];
	UIColor *foreground = [str attribute:NSForegroundColorAttributeName
			atIndex:7 effectiveRange:NULL];
	XCTAssertTrue(background != nil);
	XCTAssertEqualObjects(foreground, background,
			@"the words must be the same colour as the plate that hides them");
	XCTAssertTrue([background isEqual:TGColourCodeBlockBackground()]);
}

/// Once revealed, the run carries no spoiler attributes: it reads like the
/// rest of the message.
- (void)testSpoiler_RevealedRangeHasNoSpoilerAttributes {
	UIFont *font = [UIFont systemFontOfSize:15];
	NSAttributedString *str = TGAttributedMessageTextRevealing(@"before secret after",
			@[spSpoilerEntity(7, 6, @"messageEntitySpoiler")], font,
			[UIColor blackColor], YES);
	XCTAssertTrue([str attribute:NSBackgroundColorAttributeName
			atIndex:7 effectiveRange:NULL] == nil);
	UIColor *foreground = [str attribute:NSForegroundColorAttributeName
			atIndex:7 effectiveRange:NULL];
	XCTAssertFalse([foreground isEqual:TGColourCodeBlockBackground()]);
	XCTAssertTrue([foreground isEqual:[UIColor blackColor]]);
}

/// The plate must not leak past the entity's range.
- (void)testSpoiler_TextOutsideRangeKeepsNormalColour {
	UIFont *font = [UIFont systemFontOfSize:15];
	NSAttributedString *str = TGAttributedMessageTextRevealing(@"before secret after",
			@[spSpoilerEntity(7, 6, @"textEntityTypeSpoiler")], font,
			[UIColor blackColor], NO);
	UIColor *outside = [str attribute:NSForegroundColorAttributeName
			atIndex:0 effectiveRange:NULL];
	XCTAssertTrue([outside isEqual:[UIColor blackColor]]);
	XCTAssertTrue([str attribute:NSBackgroundColorAttributeName
			atIndex:0 effectiveRange:NULL] == nil);
}

/// Every existing caller uses the old entry point; it must leave spoilers
/// hidden.
- (void)testAttributedMessageText_HidesSpoilersByDefault {
	UIFont *font = [UIFont systemFontOfSize:15];
	NSAttributedString *str = TGAttributedMessageText(@"hide me",
			@[spSpoilerEntity(0, 7, @"textEntityTypeSpoiler")], font,
			[UIColor blackColor]);
	UIColor *background = [str attribute:NSBackgroundColorAttributeName
			atIndex:0 effectiveRange:NULL];
	UIColor *foreground = [str attribute:NSForegroundColorAttributeName
			atIndex:3 effectiveRange:NULL];
	XCTAssertTrue([background isEqual:TGColourCodeBlockBackground()]);
	XCTAssertEqualObjects(foreground, background);
}

- (void)testEntitiesHaveSpoiler_RecognisesBothSpellings {
	XCTAssertTrue(TGEntitiesHaveSpoiler(@[spSpoilerEntity(0, 4, @"textEntityTypeSpoiler")]));
	XCTAssertTrue(TGEntitiesHaveSpoiler(@[@{@"offset" : @0, @"length" : @4,
			@"@type" : @"messageEntitySpoiler"}]));
}

- (void)testEntitiesHaveSpoiler_PlainEntitiesAreNotSpoilers {
	XCTAssertFalse(TGEntitiesHaveSpoiler(@[spSpoilerEntity(0, 4, @"textEntityTypeBold")]));
	XCTAssertFalse(TGEntitiesHaveSpoiler(nil));
	XCTAssertFalse(TGEntitiesHaveSpoiler(@[]));
}

- (void)testEntitiesHaveSpoiler_NSNullIsSafe {
	XCTAssertFalse(TGEntitiesHaveSpoiler((NSArray *)[NSNull null]));
	XCTAssertFalse(TGEntitiesHaveSpoiler(@[[NSNull null]]));
}

- (void)testEntitiesHaveSpoiler_GarbageEntriesAreSkipped {
	XCTAssertFalse(TGEntitiesHaveSpoiler(@[@"not-an-entity", @42,
			@{@"type" : [NSNull null]}, @{@"type" : @{@"@type" : [NSNull null]}}]));
	XCTAssertTrue(TGEntitiesHaveSpoiler(@[@"junk",
			spSpoilerEntity(0, 2, @"messageEntitySpoiler")]));
}

/// Hiding or showing must not insert or drop a character: the bubble was
/// measured against the plain text's length.
- (void)testSpoiler_LengthMatchesTextInBothModes {
	UIFont *font = [UIFont systemFontOfSize:15];
	NSString *text = @"one hidden two";
	NSArray *entities = @[spSpoilerEntity(4, 6, @"textEntityTypeSpoiler")];
	NSAttributedString *hidden = TGAttributedMessageTextRevealing(text, entities,
			font, [UIColor blackColor], NO);
	NSAttributedString *shown = TGAttributedMessageTextRevealing(text, entities,
			font, [UIColor blackColor], YES);
	XCTAssertEqual(hidden.length, text.length);
	XCTAssertEqual(shown.length, text.length);
}

@end
