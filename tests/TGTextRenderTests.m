// TGTextRenderTests.m - the iOS 6 message text engine: one CoreText layout
// for the picture, the custom emoji and the link under a finger.
#import "TGTestRunner.h"
#import "TGTextRender.h"
#import "TGMessageLayout.h"
#import <CoreText/CoreText.h>

@interface TGTextRenderTests : XCTestCase @end

/// The colour of the pixel at (x, y) points from the top left, premultiplied.
static void trPixel(CGImageRef image, CGFloat scale, CGFloat x, CGFloat y, uint8_t out[4]) {
	size_t w = CGImageGetWidth(image), h = CGImageGetHeight(image);
	uint8_t *data = (uint8_t *)calloc(w * h, 4);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(data, w, h, 8, w * 4, space,
			kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(space);
	CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), image);
	size_t px = (size_t)(x * scale), py = (size_t)(y * scale);
	memcpy(out, data + (py * w + px) * 4, 4);
	CGContextRelease(ctx);
	free(data);
}

/// Whether any pixel in the rect (points, top left) has ink of the colour
/// picked by `match`.
static BOOL trAny(CGImageRef image, CGFloat scale, CGRect r, BOOL (*match)(const uint8_t *)) {
	for (CGFloat y = r.origin.y; y < CGRectGetMaxY(r); y += 0.5)
		for (CGFloat x = r.origin.x; x < CGRectGetMaxX(r); x += 0.5) {
			uint8_t p[4];
			trPixel(image, scale, x, y, p);
			if (match(p))
				return YES;
		}
	return NO;
}

static BOOL trRed(const uint8_t *p) { return p[3] > 128 && p[0] > 150 && p[1] < 80 && p[2] < 80; }
static BOOL trBlack(const uint8_t *p) { return p[3] > 128 && p[0] < 60 && p[1] < 60 && p[2] < 60; }
static BOOL trGreen(const uint8_t *p) { return p[3] > 200 && p[1] > 150 && p[0] < 80 && p[2] < 80; }

static NSMutableAttributedString *trText(NSString *s) {
	return [[NSMutableAttributedString alloc] initWithString:s
			attributes:@{ NSFontAttributeName : TGFontAtSize(16),
						  NSForegroundColorAttributeName : [UIColor blackColor] }];
}

@implementation TGTextRenderTests

- (void)setUp {
	[super setUp];
	TGTextRenderClearCache();
}

- (void)testImage_IsTheBoxAtTheScaleWithTheTextAtTheTop {
	CGImageRef image = TGTextRenderCreateImage(trText(@"MMMM"), CGSizeMake(100, 50), 2);
	XCTAssertTrue(image != NULL);
	XCTAssertEqual(CGImageGetWidth(image), (size_t)200);
	XCTAssertEqual(CGImageGetHeight(image), (size_t)100);
	XCTAssertTrue(trAny(image, 2, CGRectMake(0, 0, 40, 20), trBlack), @"ink on the first line");
	XCTAssertFalse(trAny(image, 2, CGRectMake(0, 30, 100, 20), trBlack), @"nothing below one line");
	CGImageRelease(image);
}

/// CoreText draws every run black unless told to take the colour from the
/// context; a link would come out the colour of the text around it.
- (void)testRuns_KeepTheirOwnColours {
	NSMutableAttributedString *t = trText(@"MMMM MMMM");
	[t addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(5, 4)];
	CGImageRef image = TGTextRenderCreateImage(t, CGSizeMake(200, 30), 2);
	XCTAssertTrue(trAny(image, 2, CGRectMake(0, 0, 40, 25), trBlack));
	XCTAssertFalse(trAny(image, 2, CGRectMake(0, 0, 40, 25), trRed));
	XCTAssertTrue(trAny(image, 2, CGRectMake(60, 0, 80, 25), trRed));
	CGImageRelease(image);
}

/// A code span and a hidden spoiler are plates; CoreText draws neither.
- (void)testBackground_IsAPlateBehindTheRun {
	NSMutableAttributedString *t = trText(@"ab code");
	[t addAttribute:NSBackgroundColorAttributeName value:[UIColor greenColor] range:NSMakeRange(3, 4)];
	CGImageRef image = TGTextRenderCreateImage(t, CGSizeMake(200, 30), 2);
	XCTAssertFalse(trAny(image, 2, CGRectMake(0, 0, 15, 25), trGreen));
	XCTAssertTrue(trAny(image, 2, CGRectMake(20, 0, 60, 25), trGreen));
	CGImageRelease(image);
}

- (void)testUnderline_IsDrawnUnderTheRun {
	NSMutableAttributedString *t = trText(@"            ");
	[t addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:NSMakeRange(0, t.length)];
	CGImageRef image = TGTextRenderCreateImage(t, CGSizeMake(200, 30), 2);
	XCTAssertTrue(trAny(image, 2, CGRectMake(0, 0, 40, 30), trBlack), @"spaces only: the line is the ink");
	CGImageRelease(image);
}

- (void)testIndexAtPoint_TheCharacterUnderTheFingerAndNothingPastTheLine {
	NSMutableAttributedString *t = trText(@"MMMM MMMM");
	CGSize box = CGSizeMake(300, 30);
	CGFloat m = [@"MMMM " sizeWithFont:TGFontAtSize(16)].width;
	NSUInteger first = TGTextRenderIndexAtPoint(t, box, CGPointMake(2, 8));
	XCTAssertEqual(first, (NSUInteger)0);
	NSUInteger second = TGTextRenderIndexAtPoint(t, box, CGPointMake(m + 3, 8));
	XCTAssertEqual(second, (NSUInteger)5);
	XCTAssertEqual(TGTextRenderIndexAtPoint(t, box, CGPointMake(290, 8)), (NSUInteger)NSNotFound);
	XCTAssertEqual(TGTextRenderIndexAtPoint(t, box, CGPointMake(2, 28)), (NSUInteger)NSNotFound);
}

- (void)testAttachment_IsLeftToTheLabel {
	NSMutableAttributedString *t = trText(@"a b");
	XCTAssertTrue(TGTextRenderCan(t));
	[t addAttribute:@"NSAttachment" value:@"stand-in" range:NSMakeRange(1, 1)];
	XCTAssertFalse(TGTextRenderCan(t));
	XCTAssertFalse(TGTextRenderCan(trText(@"")));
}

/// 8 MB, least recently used out first.
- (void)testCache_StaysUnderItsBytesAndDropsTheOldest {
	CGImageRef big = TGTextRenderCreateImage(trText(@"x"), CGSizeMake(512, 512), 2);   // 4 MB
	TGTextRenderStore(@"a", big);
	TGTextRenderStore(@"b", big);
	XCTAssertTrue(TGTextRenderCached(@"a") != NULL);   // a is now the newest
	TGTextRenderStore(@"c", big);
	XCTAssertTrue(TGTextRenderCacheBytes() <= 8u * 1024 * 1024);
	XCTAssertTrue(TGTextRenderCached(@"b") == NULL);
	XCTAssertTrue(TGTextRenderCached(@"a") != NULL);
	XCTAssertTrue(TGTextRenderCached(@"c") != NULL);
	CGImageRelease(big);
	TGTextRenderClearCache();
	XCTAssertEqual(TGTextRenderCacheBytes(), (size_t)0);
}

/// The picture is drawn on the render queue and lands in the cache.
- (void)testPrefetch_DrawsOffMainAndStores {
	__block BOOL builtOffMain = NO;
	TGTextRenderPrefetch(@"p", CGSizeMake(100, 30), 2, ^NSAttributedString *{
		builtOffMain = ![NSThread isMainThread];
		return trText(@"MMMM");
	});
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
	while (!TGTextRenderCached(@"p") && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	XCTAssertTrue(TGTextRenderCached(@"p") != NULL);
	XCTAssertTrue(builtOffMain);
}

/// The prefetch places the custom emoji from the layout it drew, so the
/// cell does not lay the text out again on the main thread.
- (void)testPrefetch_KeepsTheEmojiRectsOfThatLayout {
	NSMutableAttributedString *t = trText(@"ab ");
	[t appendAttributedString:TGCustomEmojiSpacer(77, TGFontAtSize(16))];
	TGTextRenderPrefetch(@"e", CGSizeMake(200, 30), 2, ^NSAttributedString *{ return t; });
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
	while (!TGTextRenderCached(@"e") && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	NSArray *rects = TGTextRenderCachedEmojiRects(@"e");
	XCTAssertEqual(rects.count, (NSUInteger)1);
	XCTAssertEqualObjects(rects.firstObject[@"id"], @77);
	XCTAssertNil(TGTextRenderCachedEmojiRects(@"missing"));
}

/// Held while a table moves: nothing is drawn ahead until it is let go.
- (void)testHold_DrawsNothingUntilLetGo {
	TGTextRenderHold(YES);
	TGTextRenderPrefetch(@"held", CGSizeMake(100, 30), 2, ^NSAttributedString *{ return trText(@"h"); });
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	XCTAssertTrue(TGTextRenderCached(@"held") == NULL);
	TGTextRenderHold(NO);
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
	while (!TGTextRenderCached(@"held") && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	XCTAssertTrue(TGTextRenderCached(@"held") != NULL);
}

/// A body taller than a screen is drawn ahead even while held: the main
/// thread would draw it whole in one frame when its row came in.
- (void)testHold_LetsATallBodyThrough {
	TGTextRenderHold(YES);
	TGTextRenderPrefetch(@"tall", CGSizeMake(100, TGMetricTextHoldMaxHeight + 1), 1,
			^NSAttributedString *{ return trText(@"t"); });
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
	while (!TGTextRenderCached(@"tall") && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	TGTextRenderHold(NO);
	XCTAssertTrue(TGTextRenderCached(@"tall") != NULL);
}

@end
