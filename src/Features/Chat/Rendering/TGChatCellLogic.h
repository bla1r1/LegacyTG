//
// TGChatCellLogic.h - the chat cell's decisions that need no view.
//
#import <Foundation/Foundation.h>

/// How long the table must have stood still before rows rebuilt for pictures
/// that arrived meanwhile: each rebuild relaid every visible row, and a burst
/// of custom emoji landing mid-scroll cost 10% of the first scroll on the A4.
static const double TGChatRedrawSettleSeconds = 0.25;
/// Seconds to wait before that rebuild, 0 when it may run now.
FOUNDATION_EXPORT double TGChatRedrawDelay(double now, double lastScroll);
/// A still table is looked at twice, this far apart.
static const double TGChatStillRecheckSeconds = 0.1;
/// Whether the second look, at `now`, came soon enough after the first, at
/// `firstLook`, to confirm it: within twice the recheck interval.
FOUNDATION_EXPORT BOOL TGChatStillConfirmed(double now, double firstLook);

/// What one custom emoji in a bubble shows this pass. The still picture is
/// the answer until an animation file is on disk and can play: dropped as
/// soon as TDLib named the animation, the emoji was a hole for the seconds
/// the download took on iOS 6, and for good when the file would not parse.
typedef NS_ENUM(NSInteger, TGCustomEmojiShow) {
	/// The still picture; nothing to fetch.
	TGCustomEmojiShowStill = 0,
	/// The still picture while the animation file downloads.
	TGCustomEmojiShowStillAndFetch,
	/// Try the animation; if it does not load, the still picture.
	TGCustomEmojiShowAnimation,
};

/// `animatedAllowed`: the device and memory budget allow animation at all.
/// `playing` of `cap` animations are already running in this bubble.
/// `hasAnimation`: TDLib named an animation file. `fileLocal`: it is on disk.
/// `playedOnce`: Loop Animated Stickers is off and it has had its one loop;
/// frame 0 of an animation is often empty, so it rests as the still picture.
FOUNDATION_EXPORT TGCustomEmojiShow TGCustomEmojiChoose(BOOL animatedAllowed,
		NSUInteger playing, NSUInteger cap, BOOL hasAnimation, BOOL fileLocal,
		BOOL playedOnce);
