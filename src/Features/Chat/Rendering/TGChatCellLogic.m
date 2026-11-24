#import "TGChatCellLogic.h"

TGCustomEmojiShow TGCustomEmojiChoose(BOOL animatedAllowed, NSUInteger playing,
		NSUInteger cap, BOOL hasAnimation, BOOL fileLocal, BOOL playedOnce) {
	if (!animatedAllowed || playing >= cap || !hasAnimation || playedOnce)
		return TGCustomEmojiShowStill;
	return fileLocal ? TGCustomEmojiShowAnimation : TGCustomEmojiShowStillAndFetch;
}

double TGChatRedrawDelay(double now, double lastScroll) {
	double still = now - lastScroll;
	return still >= TGChatRedrawSettleSeconds ? 0 : TGChatRedrawSettleSeconds - still;
}

BOOL TGChatStillConfirmed(double now, double firstLook) {
	double since = now - firstLook;
	return since >= TGChatStillRecheckSeconds && since <= 2 * TGChatStillRecheckSeconds;
}

NSUInteger TGCustomEmojiAnimationCap(NSInteger tier) {
	static const NSUInteger caps[] = {3, 5, 10, 20};
	if (tier < 0)
		return caps[0];
	return caps[MIN((NSUInteger)tier, sizeof(caps) / sizeof(caps[0]) - 1)];
}
