//
// TGEmojiPicturesTests.m - iOS 7's emoji pictures, read from the repository's
// face and table: the PNG bytes come out of sbix, and the matcher finds whole
// sequences (flags, keycaps, ZWJ families) and leaves text characters alone.
//
#import "TGTestRunner.h"
#import "TGEmojiPictures.h"

@interface TGEmojiPicturesTests : XCTestCase @end

static NSArray *TGPicRanges(NSString *text) {
	TGEmojiPicturesUseFiles(@"resources/fonts/AppleColorEmojiCompat.ttf",
			@"resources/fonts/AppleColorEmojiCompat.map");
	NSMutableArray *found = [NSMutableArray array];
	for (NSValue *range in TGEmojiPictureRanges(text))
		[found addObject:[text substringWithRange:range.rangeValue]];
	return found;
}

@implementation TGEmojiPicturesTests

- (void)testAPictureIsTheFacePNG {
	TGPicRanges(@"");
	NSData *png = TGEmojiPicturePNG(@"\U0001F973");
	XCTAssertTrue(png.length > 100);
	XCTAssertEqual(memcmp(png.bytes, "\x89PNG", 4), 0);
	XCTAssertNil(TGEmojiPicturePNG(@"A"));
}

- (void)testWholeSequencesAreFound {
	NSArray *found = TGPicRanges(@"Hi \U0001F973\U0001F1FA\U0001F1E6 1️⃣ "
			@"\U0001F468‍\U0001F469‍\U0001F467 \U0001F44D\U0001F3FD!");
	NSArray *want = @[@"\U0001F973", @"\U0001F1FA\U0001F1E6", @"1️⃣",
			@"\U0001F468‍\U0001F469‍\U0001F467", @"\U0001F44D\U0001F3FD"];
	XCTAssertEqualObjects(found, want);
}

/// A copyright sign or a plain heart in a sentence is text; with U+FE0F it is
/// the emoji, and the selector goes with it.
- (void)testTextCharactersNeedTheSelector {
	XCTAssertEqualObjects(TGPicRanges(@"© 2026 ❤ 1"), @[]);
	XCTAssertEqualObjects(TGPicRanges(@"❤️"), @[@"❤️"]);
}

- (void)testPlainTextHasNone {
	XCTAssertEqualObjects(TGPicRanges(@"Привет, как дела? 123 #tag *bold*"), @[]);
}

@end
