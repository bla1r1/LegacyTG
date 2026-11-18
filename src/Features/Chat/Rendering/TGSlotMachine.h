//
// TGSlotMachine.h - what the slot machine's reels and lever do in a row.
//
// Official SlotMachineAnimationNode spins a machine once and rests on the
// result; one already seen is drawn at its result straight away. Ours looped
// the reels for as long as "Loop Animated Stickers" was on, started all four
// decodes mid-scroll on the A4, and showed a half-built machine when one of
// the four layers would not load.
//
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TGSlotReelPlayback) {
	/// Not every layer is there: the background alone, no reels.
	TGSlotReelHide,
	/// Spun this chat visit already: the last frame, the result.
	TGSlotReelRest,
	/// The table is scrolling on a single core: the first frame until it
	/// settles, then the settle reload spins it.
	TGSlotReelWait,
	/// One spin that ends on the result.
	TGSlotReelSpin,
};

/// `loaded` of `wanted` layers could be drawn; `spun` says this message
/// spun before in this visit; `settled` is the scroll check the row's main
/// sticker uses.
FOUNDATION_EXPORT TGSlotReelPlayback TGSlotReelPlaybackFor(NSUInteger loaded, NSUInteger wanted,
		BOOL spun, BOOL settled);
