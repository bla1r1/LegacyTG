// TGTLottieTests.m - tlottie through TGTLottie, the renderer TGLottieView
// tries before TGLottieRender.
//
// What decides the fallback is that a file tlottie will not take answers
// NULL rather than a picture; what makes tlottie worth trying first is the
// files TGLottieRender keeps as stills (trim paths: 89 of the official 195).
#import "TGTestRunner.h"
#import "TGTLottie.h"
#import "TGLottieSupport.h"

@interface TGTLottieTests : XCTestCase @end

static NSDictionary *tlValue(id k) {
	return @{ @"a" : @0, @"k" : k };
}

static NSDictionary *tlTransform(void) {
	return @{ @"p" : tlValue(@[ @0, @0 ]), @"a" : tlValue(@[ @0, @0 ]),
			  @"s" : tlValue(@[ @100, @100 ]), @"r" : tlValue(@0), @"o" : tlValue(@100) };
}

/// A shape layer whose group holds `items` and a neutral transform.
static NSDictionary *tlLayer(NSArray *items) {
	NSMutableArray *group = [items mutableCopy];
	[group addObject:[@{ @"ty" : @"tr" } mutableCopy]];
	[group.lastObject addEntriesFromDictionary:tlTransform()];
	return @{ @"ty" : @4, @"ind" : @1, @"ip" : @0, @"op" : @60, @"st" : @0, @"ks" : tlTransform(),
			  @"shapes" : @[ @{ @"ty" : @"gr", @"it" : group } ] };
}

static NSDictionary *tlRect(double x, double y, double w, double h) {
	return @{ @"ty" : @"rc", @"p" : tlValue(@[ @(x + w / 2), @(y + h / 2) ]),
			  @"s" : tlValue(@[ @(w), @(h) ]), @"r" : tlValue(@0) };
}

static NSDictionary *tlRedFill(void) {
	return @{ @"ty" : @"fl", @"c" : tlValue(@[ @1, @0, @0, @1 ]), @"o" : tlValue(@100) };
}

static NSData *tlJson(double w, double h, NSArray *layers) {
	NSDictionary *anim = @{ @"v" : @"5.5.2", @"w" : @(w), @"h" : @(h), @"fr" : @60, @"ip" : @0,
							@"op" : @60, @"layers" : layers, @"assets" : @[] };
	return [NSJSONSerialization dataWithJSONObject:anim options:0 error:nil];
}

/// The alpha byte at (x, y) of `image`, y from the top row.
static int tlAlpha(CGImageRef image, size_t x, size_t y) {
	CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
	int alpha = CFDataGetBytePtr(data)[y * CGImageGetBytesPerRow(image) + x * 4 + 3];
	CFRelease(data);
	return alpha;
}

@implementation TGTLottieTests

- (void)testRender_TopOfTheCanvasIsTheTopRow {
	TGTLottie *animation = TGTLottieCreate(tlJson(100, 100, @[ tlLayer(@[ tlRect(0, 0, 100, 30), tlRedFill() ]) ]), @"t.tgs");
	XCTAssertTrue(animation != NULL);
	CGImageRef image = TGTLottieRender(animation, 0, CGSizeMake(100, 100));
	XCTAssertTrue(image != NULL);
	XCTAssertEqual(tlAlpha(image, 50, 10), 255);
	XCTAssertEqual(tlAlpha(image, 50, 90), 0);
	CGImageRelease(image);
	TGTLottieFree(animation);
}

- (void)testRender_FitsTheCanvasInsteadOfStretching {
	// tlottie stretches to the size it is given; a 2:1 canvas into a square
	// comes back 100 x 50.
	TGTLottie *animation = TGTLottieCreate(tlJson(200, 100, @[ tlLayer(@[ tlRect(0, 0, 200, 100), tlRedFill() ]) ]), @"t.tgs");
	CGImageRef image = TGTLottieRender(animation, 0, CGSizeMake(100, 100));
	XCTAssertEqual(CGImageGetWidth(image), (size_t)100);
	XCTAssertEqual(CGImageGetHeight(image), (size_t)50);
	CGImageRelease(image);
	TGTLottieFree(animation);
}

- (void)testFrames_CountAndRate {
	// A fill fading over the 60 frames moves; the same fill held still is one
	// frame to tlottie, and TGLottieView keeps one picture for it, not a loop.
	NSDictionary *fade = @{ @"ty" : @"fl", @"c" : tlValue(@[ @1, @0, @0, @1 ]),
			@"o" : @{ @"a" : @1, @"k" : @[ @{ @"t" : @0, @"s" : @[ @0 ] }, @{ @"t" : @59, @"s" : @[ @100 ] } ] } };
	TGTLottie *moving = TGTLottieCreate(tlJson(100, 100, @[ tlLayer(@[ tlRect(0, 0, 10, 10), fade ]) ]), @"t.tgs");
	XCTAssertEqual(TGTLottieFrameCount(moving), (NSUInteger)60);
	XCTAssertTrue(fabs(TGTLottieFrameRate(moving) - 60.0) < 0.01);
	TGTLottieFree(moving);
	TGTLottie *still = TGTLottieCreate(tlJson(100, 100, @[ tlLayer(@[ tlRect(0, 0, 10, 10), tlRedFill() ]) ]), @"t.tgs");
	XCTAssertEqual(TGTLottieFrameCount(still), (NSUInteger)1);
	TGTLottieFree(still);
}

- (void)testRefused_GarbageAndEmptyAnswerNullForTheFallback {
	XCTAssertTrue(TGTLottieCreate(nil, @"t.tgs") == NULL);
	XCTAssertTrue(TGTLottieCreate([NSData data], @"t.tgs") == NULL);
	XCTAssertTrue(TGTLottieCreate([@"{\"layers\":" dataUsingEncoding:NSUTF8StringEncoding], @"t.tgs") == NULL);
	XCTAssertTrue(TGTLottieRender(NULL, 0, CGSizeMake(10, 10)) == NULL);
	TGTLottie *animation = TGTLottieCreate(tlJson(100, 100, @[ tlLayer(@[ tlRect(0, 0, 10, 10), tlRedFill() ]) ]), @"t.tgs");
	XCTAssertTrue(TGTLottieRender(animation, 0, CGSizeZero) == NULL);
	TGTLottieFree(animation);
}

- (void)testTrimPath_DrawnWhereTGLottieRenderKeepsTheStill {
	// A stroke trimmed to its first half: the left of the line is lit, the
	// right is not.
	NSDictionary *line = @{ @"ty" : @"sh", @"ks" : tlValue(@{ @"c" : @NO,
			@"v" : @[ @[ @0, @50 ], @[ @100, @50 ] ], @"i" : @[ @[ @0, @0 ], @[ @0, @0 ] ],
			@"o" : @[ @[ @0, @0 ], @[ @0, @0 ] ] }) };
	NSDictionary *trim = @{ @"ty" : @"tm", @"s" : tlValue(@0), @"e" : tlValue(@50), @"o" : tlValue(@0), @"m" : @1 };
	NSDictionary *stroke = @{ @"ty" : @"st", @"c" : tlValue(@[ @1, @0, @0, @1 ]), @"o" : tlValue(@100),
							  @"w" : tlValue(@20), @"lc" : @1, @"lj" : @1 };
	NSData *json = tlJson(100, 100, @[ tlLayer(@[ line, trim, stroke ]) ]);
	NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
	XCTAssertTrue([TGLottieUnsupportedFeature(parsed) isEqualToString:@"trim path"]);

	TGTLottie *animation = TGTLottieCreate(json, @"trim.tgs");
	CGImageRef image = TGTLottieRender(animation, 0, CGSizeMake(100, 100));
	XCTAssertTrue(image != NULL);
	XCTAssertEqual(tlAlpha(image, 20, 50), 255);
	XCTAssertEqual(tlAlpha(image, 80, 50), 0);
	CGImageRelease(image);
	TGTLottieFree(animation);
}

@end
