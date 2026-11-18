//
// TGSlotMachine.m - see TGSlotMachine.h.
//
#import "TGSlotMachine.h"

TGSlotReelPlayback TGSlotReelPlaybackFor(NSUInteger loaded, NSUInteger wanted, BOOL spun, BOOL settled) {
	if (!wanted || loaded < wanted)
		return TGSlotReelHide;
	if (spun)
		return TGSlotReelRest;
	return settled ? TGSlotReelSpin : TGSlotReelWait;
}
