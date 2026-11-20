//
// TGiPadSimulatorTests.m
// LegacyTG - Tests for virtual iPad simulator geometry and behavior
//
#import "TGTestRunner.h"
#import "TGiPadSimulator.h"
#include <math.h>

@interface TGiPadSimulatorTests : XCTestCase
@end

@implementation TGiPadSimulatorTests

- (void)testCanvasSizeForOrientation {
	CGSize zero = TGiPadCanvasSizeForOrientation(TGiPadOrientationOff);
	XCTAssertEqual(zero.width, 0.0f);
	XCTAssertEqual(zero.height, 0.0f);

	CGSize portrait = TGiPadCanvasSizeForOrientation(TGiPadOrientationPortrait);
	XCTAssertEqual(portrait.width, 768.0f);
	XCTAssertEqual(portrait.height, 1024.0f);

	CGSize landscape = TGiPadCanvasSizeForOrientation(TGiPadOrientationLandscape);
	XCTAssertEqual(landscape.width, 1024.0f);
	XCTAssertEqual(landscape.height, 768.0f);
}

- (void)testScaleToFitScreenCalculatesCorrectRatios {
	CGSize iphone4 = CGSizeMake(320.0f, 480.0f);
	CGSize padPortrait = CGSizeMake(768.0f, 1024.0f);
	CGSize padLandscape = CGSizeMake(1024.0f, 768.0f);

	CGFloat scaleP = TGiPadScaleToFitScreen(padPortrait, iphone4);
	XCTAssertTrue(fabs(scaleP - (320.0f / 768.0f)) < 0.0001f);

	CGFloat scaleL = TGiPadScaleToFitScreen(padLandscape, iphone4);
	XCTAssertTrue(fabs(scaleL - (320.0f / 1024.0f)) < 0.0001f);

	CGFloat scaleZero = TGiPadScaleToFitScreen(CGSizeZero, iphone4);
	XCTAssertEqual(scaleZero, 1.0f);
}

- (void)testCanvasRectCentersInsideScreenBounds {
	CGSize iphone4 = CGSizeMake(320.0f, 480.0f);
	CGSize padPortrait = CGSizeMake(768.0f, 1024.0f);
	CGRect rectP = TGiPadCanvasRectForScreen(padPortrait, iphone4);

	XCTAssertTrue(fabs(rectP.origin.x - 0.0f) < 0.0001f);
	XCTAssertTrue(fabs(rectP.size.width - 320.0f) < 0.0001f);
	CGFloat expectedHP = 1024.0f * (320.0f / 768.0f);
	XCTAssertTrue(fabs(rectP.size.height - expectedHP) < 0.0001f);
	XCTAssertTrue(fabs(rectP.origin.y - (480.0f - expectedHP) / 2.0f) < 0.0001f);

	CGSize padLandscape = CGSizeMake(1024.0f, 768.0f);
	CGRect rectL = TGiPadCanvasRectForScreen(padLandscape, iphone4);
	XCTAssertTrue(fabs(rectL.origin.x - 0.0f) < 0.0001f);
	XCTAssertTrue(fabs(rectL.size.width - 320.0f) < 0.0001f);
	XCTAssertTrue(fabs(rectL.size.height - 240.0f) < 0.0001f);
	XCTAssertTrue(fabs(rectL.origin.y - 120.0f) < 0.0001f);
}

- (void)testSharedSimulatorSingleton {
	TGiPadSimulator *sim = [TGiPadSimulator shared];
	XCTAssertNotNil(sim);
	XCTAssertFalse(sim.isActive);
	XCTAssertEqual(sim.orientation, TGiPadOrientationOff);

	[sim toggleModeInWindow:nil];
	XCTAssertTrue(sim.isActive);
	XCTAssertEqual(sim.orientation, TGiPadOrientationPortrait);

	[sim toggleOrientationInWindow:nil];
	XCTAssertTrue(sim.isActive);
	XCTAssertEqual(sim.orientation, TGiPadOrientationLandscape);

	[sim setOrientation:TGiPadOrientationOff inWindow:nil];
	XCTAssertFalse(sim.isActive);
	XCTAssertEqual(sim.orientation, TGiPadOrientationOff);
}

@end
