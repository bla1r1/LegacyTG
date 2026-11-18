// TGSlotMachineTests.m - what the slot machine's reels do in a chat row.
//
// On the iPhone 4 the reels looped for as long as "Loop Animated Stickers"
// was on, started four decodes mid-scroll, and a machine with a layer that
// would not load showed its other three over the background.
#import "TGTestRunner.h"
#import "TGSlotMachine.h"

@interface TGSlotMachineTests : XCTestCase @end

@implementation TGSlotMachineTests

- (void)testHalfBuiltMachine_ShowsTheBackgroundOnly {
	XCTAssertEqual(TGSlotReelPlaybackFor(3, 4, NO, YES), TGSlotReelHide);
	XCTAssertEqual(TGSlotReelPlaybackFor(0, 0, NO, YES), TGSlotReelHide);
}

- (void)testFirstSight_SpinsOnce {
	XCTAssertEqual(TGSlotReelPlaybackFor(4, 4, NO, YES), TGSlotReelSpin);
}

- (void)testScrolling_WaitsForTheSettle {
	XCTAssertEqual(TGSlotReelPlaybackFor(4, 4, NO, NO), TGSlotReelWait);
}

- (void)testSpunThisVisit_RestsOnTheResult {
	// A reload or a scroll back must not spin it again, scrolling or not.
	XCTAssertEqual(TGSlotReelPlaybackFor(4, 4, YES, YES), TGSlotReelRest);
	XCTAssertEqual(TGSlotReelPlaybackFor(4, 4, YES, NO), TGSlotReelRest);
}

@end
