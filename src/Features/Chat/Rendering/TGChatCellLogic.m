#import "TGChatCellLogic.h"

TGCustomEmojiShow TGCustomEmojiChoose(BOOL animatedAllowed, NSUInteger playing,
		NSUInteger cap, BOOL hasAnimation, BOOL fileLocal, BOOL playedOnce) {
	if (!animatedAllowed || playing >= cap || !hasAnimation || playedOnce)
		return TGCustomEmojiShowStill;
	return fileLocal ? TGCustomEmojiShowAnimation : TGCustomEmojiShowStillAndFetch;
}
