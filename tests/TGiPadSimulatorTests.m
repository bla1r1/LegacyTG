//
// TGiPadSimulatorTests.m
// LegacyTG - Tests for virtual iPad simulator geometry and behavior
//
#import "TGTestRunner.h"
#import "TGiPadSimulator.h"
#import "TGStyle.h"
#include <math.h>

@interface TGiPadSimulatorTests : XCTestCase
@end

@implementation TGiPadSimulatorTests

/// On the iPad idiom iOS 6 filled the chat's navigation bar flat (7f96b1)
/// beside the list's glossy one. The split draws the gloss itself; these are
/// the phone's own pixels at the default tint 6d84a2, read off the 4S.
static BOOL TGSheenMatches(CGFloat amount, int r, int g, int b) {
	CGFloat tint[3] = { 109.0f / 255.0f, 132.0f / 255.0f, 162.0f / 255.0f };
	int want[3] = { r, g, b };
	for (int i = 0; i < 3; i++)
		if (fabs(TGLiftToWhite(tint[i], amount) * 255.0f - want[i]) > 3.0)
			return NO;
	return YES;
}

- (void)testBarSheenMatchesThePhonesTintedBars {
	XCTAssertTrue(TGSheenMatches(TGBarSheenNavTop, 0xb3, 0xc0, 0xd0), @"nav bar top");
	XCTAssertTrue(TGSheenMatches(TGBarSheenNavBottom, 0x80, 0x96, 0xb1), @"nav bar bottom");
	XCTAssertTrue(TGSheenMatches(TGBarSheenNavHighlight, 0xd1, 0xd9, 0xe2), @"nav bar highlight");
	XCTAssertTrue(TGSheenMatches(TGBarSheenTabTop, 0x98, 0xaa, 0xc0), @"tab bar top");
	XCTAssertTrue(TGSheenMatches(TGBarSheenTabFlat, 0x7f, 0x96, 0xb1), @"tab bar lower half");
	XCTAssertTrue(TGBarSheenNavTop > TGBarSheenNavBottom, @"a flat bar has no gloss");
}

/// The first drawn sheen came out lighter than UIKit's bars beside it: iOS 6
/// shows a bitmap-context image through a 1.8 -> 2.2 gamma. The composer's
/// aluminium bottom stop (0.72, 0.74, 0.77) shows as c4c9cf on the 4S.
- (void)testBitmapGammaMatchesWhatTheDeviceShows {
	CGFloat drawn[3] = { 0.72f, 0.74f, 0.77f };
	int shown[3] = { 0xc4, 0xc9, 0xcf };
	for (int i = 0; i < 3; i++)
		XCTAssertTrue(fabs(TGBitmapShown(drawn[i]) * 255.0f - shown[i]) <= 3.0,
				@"aluminium channel %d", i);
	// Drawing the compensated value shows the sheen UIKit's tab bar has.
	CGFloat flat = TGLiftToWhite(109.0f / 255.0f, TGBarSheenTabFlat);
	XCTAssertTrue(fabs(TGBitmapShown(TGBitmapDrawn(flat)) - flat) < 0.002f);
	XCTAssertTrue(TGBitmapDrawn(flat) < flat, @"compensation draws darker");
}

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
