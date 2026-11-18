// TGLottieRenderTests.m - frames drawn by TGLottieRender, read back pixel by
// pixel.
//
// The slot machine's reels came out blank on the iPhone 4: they are precomp
// layers, which the renderer refused, and every sticker it did draw was
// upside down (the 7 on its head, the lamp under the body). The animations
// below are the smallest that show each rule; canvas 100 x 100, drawn at
// 100 x 100 px, so a canvas point is a pixel.
#import "TGTestRunner.h"
#import "TGLottieRender.h"

@interface TGLottieRenderTests : XCTestCase @end

/// A static property.
static NSDictionary *lrValue(id k) {
	return @{ @"a" : @0, @"k" : k };
}

/// A transform that leaves everything where it is, with an opacity.
static NSDictionary *lrTransform(double opacity) {
	return @{ @"p" : lrValue(@[ @0, @0 ]), @"a" : lrValue(@[ @0, @0 ]),
			  @"s" : lrValue(@[ @100, @100 ]), @"r" : lrValue(@0), @"o" : lrValue(@(opacity)) };
}

/// A shape layer filling the rectangle x, y, w, h opaque red.
static NSDictionary *lrRectLayer(double x, double y, double w, double h, double ip, double op) {
	return @{ @"ty" : @4, @"ind" : @1, @"ip" : @(ip), @"op" : @(op), @"ks" : lrTransform(100),
			  @"shapes" : @[ @{ @"ty" : @"gr", @"it" : @[
				  @{ @"ty" : @"rc", @"p" : lrValue(@[ @(x + w / 2), @(y + h / 2) ]),
					 @"s" : lrValue(@[ @(w), @(h) ]), @"r" : lrValue(@0) },
				  @{ @"ty" : @"fl", @"c" : lrValue(@[ @1, @0, @0, @1 ]), @"o" : lrValue(@100) },
				  @{ @"ty" : @"tr", @"p" : lrValue(@[ @0, @0 ]), @"a" : lrValue(@[ @0, @0 ]),
					 @"s" : lrValue(@[ @100, @100 ]), @"r" : lrValue(@0), @"o" : lrValue(@100) } ] } ] };
}

static NSDictionary *lrAnimation(NSArray *layers, NSArray *assets) {
	return @{ @"w" : @100, @"h" : @100, @"fr" : @60, @"ip" : @0, @"op" : @60,
			  @"layers" : layers, @"assets" : assets ?: @[] };
}

/// A precomp of `comp_0` with extra keys (st, tm, w, h, ks).
static NSDictionary *lrPrecomp(NSDictionary *extra) {
	NSMutableDictionary *layer = [@{ @"ty" : @0, @"ind" : @1, @"refId" : @"comp_0", @"ip" : @0,
			@"op" : @60, @"st" : @0, @"w" : @100, @"h" : @100, @"ks" : lrTransform(100) } mutableCopy];
	[layer addEntriesFromDictionary:extra];
	return layer;
}

static NSArray *lrAsset(NSArray *layers) {
	return @[ @{ @"id" : @"comp_0", @"layers" : layers } ];
}

/// The alpha byte at (x, y), y counted from the top row.
static int lrAlphaAt(NSDictionary *animation, double frame, int x, int y) {
	TGLottieScene *scene = TGLottieSceneCreate(animation);
	if (!scene)
		return -1;
	CGImageRef image = TGLottieSceneRender(scene, frame, CGSizeMake(100, 100));
	TGLottieSceneFree(scene);
	if (!image)
		return -1;
	CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
	const UInt8 *bytes = CFDataGetBytePtr(data);
	size_t row = CGImageGetBytesPerRow(image);
	int alpha = bytes[(size_t)y * row + (size_t)x * 4 + 3];
	CFRelease(data);
	CGImageRelease(image);
	return alpha;
}

@implementation TGLottieRenderTests

- (void)testOrientation_TopOfTheCanvasIsTheTopRow {
	NSDictionary *anim = lrAnimation(@[ lrRectLayer(0, 0, 100, 30, 0, 60) ], nil);
	XCTAssertEqual(lrAlphaAt(anim, 0, 50, 10), 255);
	XCTAssertEqual(lrAlphaAt(anim, 0, 50, 90), 0);
}

- (void)testPrecomp_ContentIsDrawn {
	NSDictionary *anim = lrAnimation(@[ lrPrecomp(@{}) ],
			lrAsset(@[ lrRectLayer(20, 20, 60, 60, 0, 60) ]));
	XCTAssertEqual(lrAlphaAt(anim, 10, 50, 50), 255);
	XCTAssertEqual(lrAlphaAt(anim, 10, 5, 5), 0);
}

- (void)testPrecomp_RunsOnItsOwnClockFromItsStart {
	// The reel inside is shown for its first 10 frames; the precomp starts at
	// 20, so the root's frame 25 is the reel's 5 and the root's 5 its -15.
	NSDictionary *anim = lrAnimation(@[ lrPrecomp(@{ @"st" : @20 }) ],
			lrAsset(@[ lrRectLayer(0, 0, 100, 100, 0, 10) ]));
	XCTAssertEqual(lrAlphaAt(anim, 25, 50, 50), 255);
	XCTAssertEqual(lrAlphaAt(anim, 5, 50, 50), 0);
	XCTAssertEqual(lrAlphaAt(anim, 35, 50, 50), 0);
}

- (void)testPrecomp_StretchSlowsItsClock {
	// sr 2: the root's frame 16 is the child's 8, still inside its 10.
	NSDictionary *anim = lrAnimation(@[ lrPrecomp(@{ @"sr" : @2 }) ],
			lrAsset(@[ lrRectLayer(0, 0, 100, 100, 0, 10) ]));
	XCTAssertEqual(lrAlphaAt(anim, 16, 50, 50), 255);
	XCTAssertEqual(lrAlphaAt(anim, 24, 50, 50), 0);
}

- (void)testPrecomp_TimeRemapIsSecondsOfTheChild {
	// 0.5 s at 60 fps is the child's frame 30, past a layer shown for 0...10
	// and inside one shown for 25...35, whatever the root's frame.
	NSArray *early = lrAsset(@[ lrRectLayer(0, 0, 100, 100, 0, 10) ]);
	NSArray *late = lrAsset(@[ lrRectLayer(0, 0, 100, 100, 25, 35) ]);
	NSDictionary *remap = @{ @"tm" : lrValue(@0.5) };
	XCTAssertEqual(lrAlphaAt(lrAnimation(@[ lrPrecomp(remap) ], early), 2, 50, 50), 0);
	XCTAssertEqual(lrAlphaAt(lrAnimation(@[ lrPrecomp(remap) ], late), 2, 50, 50), 255);
}

- (void)testPrecomp_TimeRemapStaysInsideTheAnimation {
	// 10 s would be frame 600; tlottie holds it at the last frame, 59.
	NSDictionary *anim = lrAnimation(@[ lrPrecomp(@{ @"tm" : lrValue(@10) }) ],
			lrAsset(@[ lrRectLayer(0, 0, 100, 100, 50, 60) ]));
	XCTAssertEqual(lrAlphaAt(anim, 2, 50, 50), 255);
}

- (void)testPrecomp_ClippedToItsSize {
	NSDictionary *anim = lrAnimation(@[ lrPrecomp(@{ @"w" : @50, @"h" : @50 }) ],
			lrAsset(@[ lrRectLayer(0, 0, 100, 100, 0, 60) ]));
	XCTAssertEqual(lrAlphaAt(anim, 0, 25, 25), 255);
	XCTAssertEqual(lrAlphaAt(anim, 0, 75, 75), 0);
}

- (void)testPrecomp_OpacityCarriesIntoItsContent {
	NSDictionary *anim = lrAnimation(@[ lrPrecomp(@{ @"ks" : lrTransform(50) }) ],
			lrAsset(@[ lrRectLayer(0, 0, 100, 100, 0, 60) ]));
	int alpha = lrAlphaAt(anim, 0, 50, 50);
	XCTAssertTrue(alpha > 120 && alpha < 135, @"alpha %d", alpha);
}

- (void)testParenting_MovesButDoesNotFade {
	// A child takes its parent's matrix, never its opacity (rlottie).
	NSMutableDictionary *parent = [lrRectLayer(0, 0, 10, 10, 0, 60) mutableCopy];
	parent[@"ind"] = @7;
	parent[@"ks"] = lrTransform(0);
	NSMutableDictionary *child = [lrRectLayer(0, 0, 100, 100, 0, 60) mutableCopy];
	child[@"ind"] = @8;
	child[@"parent"] = @7;
	XCTAssertEqual(lrAlphaAt(lrAnimation(@[ child, parent ], nil), 0, 50, 50), 255);
}

- (void)testPrecomp_LoopingReferenceStops {
	// comp_0 holds a precomp of itself: drawn to the depth limit, no hang.
	NSDictionary *anim = lrAnimation(@[ lrPrecomp(@{}) ],
			lrAsset(@[ lrPrecomp(@{}), lrRectLayer(0, 0, 100, 100, 0, 60) ]));
	XCTAssertEqual(lrAlphaAt(anim, 0, 50, 50), 255);
}

- (void)testScene_NeedsLayersAndACanvas {
	XCTAssertTrue(TGLottieSceneCreate(nil) == NULL);
	XCTAssertTrue(TGLottieSceneCreate(@{ @"w" : @100, @"h" : @100, @"layers" : @[] }) == NULL);
	XCTAssertTrue(TGLottieSceneCreate(@{ @"w" : @0, @"h" : @100,
			@"layers" : @[ lrRectLayer(0, 0, 1, 1, 0, 1) ] }) == NULL);
}

@end
