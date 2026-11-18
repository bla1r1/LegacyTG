// TGLottieSupportTests.m - which Lottie files TGLottieView may animate.
//
// The "High Voltage" custom emoji drew as bare red outlines: its content sat
// in precomp layers and trim paths the renderer skipped. The shapes below
// mirror the structure of the real files pulled off the iPod touch 4.
#import "TGTestRunner.h"
#import "TGLottieSupport.h"

@interface TGLottieSupportTests : XCTestCase @end

static NSDictionary *lsShapeLayer(NSArray *shapes) {
	return @{ @"ty": @4, @"ip": @0, @"op": @60, @"shapes": shapes };
}

static NSDictionary *lsGroup(NSArray *items) {
	return @{ @"ty": @"gr", @"it": items };
}

@implementation TGLottieSupportTests

- (void)testDrawn_ShapesFillsStrokesAndNulls {
	// "⛔ Stop": a null parent and shape layers of groups, paths, fills,
	// gradient fills and strokes.
	NSDictionary *anim = @{ @"layers": @[
		@{ @"ty": @3 },
		lsShapeLayer(@[ lsGroup(@[ @{ @"ty": @"el" }, @{ @"ty": @"gf" }, @{ @"ty": @"tr" } ]),
						lsGroup(@[ @{ @"ty": @"sh" }, @{ @"ty": @"rc" }, @{ @"ty": @"st" },
								   @{ @"ty": @"fl" }, @{ @"ty": @"tr" } ]) ]),
	] };
	XCTAssertNil(TGLottieUnsupportedFeature(anim));
}

- (void)testHighVoltage_TrimPathsInsideItsPrecompsKeepTheStill {
	// Precomps are drawn now; what the asset holds is what decides.
	NSDictionary *anim = @{
		@"layers": @[ lsShapeLayer(@[ lsGroup(@[ @{ @"ty": @"sh" }, @{ @"ty": @"st" } ]) ]),
					  @{ @"ty": @0, @"refId": @"comp_0" } ],
		@"assets": @[ @{ @"id": @"comp_0", @"layers": @[ lsShapeLayer(@[ @{ @"ty": @"tm" } ]) ] } ],
	};
	XCTAssertEqualObjects(TGLottieUnsupportedFeature(anim), @"trim path");
}

- (void)testSlotMachineReel_PrecompsWithMergePathsAreDrawn {
	// Slot_L_Lemon and the other reels: precomps whose shapes merge paths,
	// which rlottie skips and so do we.
	NSDictionary *anim = @{
		@"layers": @[ @{ @"ty": @0, @"refId": @"comp_0" }, @{ @"ty": @3 } ],
		@"assets": @[ @{ @"id": @"comp_0", @"layers": @[ lsShapeLayer(@[ lsGroup(@[
				@{ @"ty": @"sh" }, @{ @"ty": @"sh" }, @{ @"ty": @"mm" }, @{ @"ty": @"st" },
				@{ @"ty": @"fl" }, @{ @"ty": @"tr" } ]) ]) ] } ],
	};
	XCTAssertNil(TGLottieUnsupportedFeature(anim));
}

- (void)testPrecompWithATrackMatte_KeepsTheStill {
	NSDictionary *anim = @{ @"layers": @[ @{ @"ty": @0, @"refId": @"comp_0", @"tt": @1 } ] };
	XCTAssertEqualObjects(TGLottieUnsupportedFeature(anim), @"track matte");
}

- (void)testTrimPath_InsideANestedGroup {
	// "25_Pushpin", "📈 Chart Increasing": the trim sits two groups down.
	NSDictionary *anim = @{ @"layers": @[
		lsShapeLayer(@[ lsGroup(@[ lsGroup(@[ @{ @"ty": @"sh" }, @{ @"ty": @"tm" },
											  @{ @"ty": @"st" } ]) ]) ]) ] };
	XCTAssertEqualObjects(TGLottieUnsupportedFeature(anim), @"trim path");
}

- (void)testTrackMatteAndOtherLayers {
	NSDictionary *matte = @{ @"layers": @[ @{ @"ty": @4, @"tt": @1, @"shapes": @[] } ] };
	XCTAssertEqualObjects(TGLottieUnsupportedFeature(matte), @"track matte");
	XCTAssertEqualObjects(TGLottieUnsupportedFeature(@{ @"layers": @[ @{ @"ty": @2 } ] }),
			@"image layer");
	XCTAssertEqualObjects(TGLottieUnsupportedFeature(@{ @"layers": @[ @{ @"ty": @1 } ] }),
			@"solid layer");
}

- (void)testGarbage_IsNotAnswered {
	XCTAssertNil(TGLottieUnsupportedFeature(nil));
	XCTAssertNil(TGLottieUnsupportedFeature(@{ @"layers": @"x", @"assets": @3 }));
	XCTAssertNil(TGLottieUnsupportedFeature((NSDictionary *)@[]));
}

#pragma mark - gradient stops

- (void)testGradient_WrappedArrayIsRead {
	// Telegram's files wrap the stops in {a, k}; the renderer read only a bare
	// array and skipped every gradient fill, so stickers drew as outlines.
	NSDictionary *g = @{ @"p" : @2, @"k" : @{ @"a" : @0, @"k" : @[ @0, @1, @0, @0,   @1, @0, @0, @1 ] } };
	NSArray *stops = TGLottieGradientStops(g, 0);
	XCTAssertEqualObjects(stops, (@[ @0, @1, @0, @0, @1,   @1, @0, @0, @1, @1 ]));
	NSDictionary *bare = @{ @"p" : @2, @"k" : @[ @0, @1, @0, @0,   @1, @0, @0, @1 ] };
	XCTAssertEqualObjects(TGLottieGradientStops(bare, 0), stops);
}

- (void)testGradient_OpacityStopsAreInterpolatedAtEachColourStop {
	NSDictionary *g = @{ @"p" : @3, @"k" : @{ @"a" : @0, @"k" : @[
		@0, @1, @1, @1,   @0.5, @1, @1, @1,   @1, @1, @1, @1,
		@0, @1,   @1, @0 ] } };
	NSArray *stops = TGLottieGradientStops(g, 0);
	XCTAssertEqual(stops.count, (NSUInteger)15);
	XCTAssertTrue(fabs([stops[4] doubleValue] - 1.0) < 1e-9);
	XCTAssertTrue(fabs([stops[9] doubleValue] - 0.5) < 1e-9);
	XCTAssertTrue(fabs([stops[14] doubleValue] - 0.0) < 1e-9);
}

- (void)testGradient_AnimatedTakesTheKeyframeInForce {
	NSDictionary *g = @{ @"p" : @2, @"k" : @{ @"a" : @1, @"k" : @[
		@{ @"t" : @0,  @"s" : @[ @0, @1, @0, @0,  @1, @1, @0, @0 ] },
		@{ @"t" : @10, @"s" : @[ @0, @0, @0, @1,  @1, @0, @0, @1 ] } ] } };
	XCTAssertEqualObjects(TGLottieGradientStops(g, 5)[1], @1);
	XCTAssertEqualObjects(TGLottieGradientStops(g, 12)[1], @0);
	XCTAssertNil(TGLottieGradientStops(@{ @"p" : @2, @"k" : @{ @"a" : @0, @"k" : @[ @0 ] } }, 0));
}

@end
