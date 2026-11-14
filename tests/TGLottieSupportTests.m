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

- (void)testHighVoltage_PrecompLayersKeepTheStill {
	NSDictionary *anim = @{
		@"layers": @[ lsShapeLayer(@[ lsGroup(@[ @{ @"ty": @"sh" }, @{ @"ty": @"st" } ]) ]),
					  @{ @"ty": @0, @"refId": @"comp_0" } ],
		@"assets": @[ @{ @"id": @"comp_0", @"layers": @[ lsShapeLayer(@[ @{ @"ty": @"tm" } ]) ] } ],
	};
	XCTAssertEqualObjects(TGLottieUnsupportedFeature(anim), @"precomp layer");
}

- (void)testTrimPath_InsideANestedGroup {
	// "25_Pushpin", "📈 Chart Increasing": the trim sits two groups down.
	NSDictionary *anim = @{ @"layers": @[
		lsShapeLayer(@[ lsGroup(@[ lsGroup(@[ @{ @"ty": @"sh" }, @{ @"ty": @"tm" },
											  @{ @"ty": @"st" } ]) ]) ]) ] };
	XCTAssertEqualObjects(TGLottieUnsupportedFeature(anim), @"trim path");
}

- (void)testTrackMatteAndMergePathsAndOtherLayers {
	NSDictionary *matte = @{ @"layers": @[ @{ @"ty": @4, @"tt": @1, @"shapes": @[] } ] };
	XCTAssertEqualObjects(TGLottieUnsupportedFeature(matte), @"track matte");
	NSDictionary *merge = @{ @"layers": @[ lsShapeLayer(@[ lsGroup(@[ @{ @"ty": @"mm" } ]) ]) ] };
	XCTAssertEqualObjects(TGLottieUnsupportedFeature(merge), @"merge paths");
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

@end
