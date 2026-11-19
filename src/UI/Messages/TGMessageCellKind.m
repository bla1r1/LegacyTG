//
// TGMessageCellKind.m - the pure message element choice.
//
#import "TGMessageCellFactory.h"
#import "TGMessageLayout.h"

TGMessageCellKind TGMessageCellKindForMessage(NSDictionary *message,
		TGMessageLayout *layout) {
	NSString *separator = [message[@"separator"] isKindOfClass:NSString.class]
			? message[@"separator"] : nil;
	if ([separator isEqualToString:@"unread"] || layout.isUnreadSeparator)
		return TGMessageCellKindUnreadSeparator;
	if (separator.length || layout.isDateHeader)
		return TGMessageCellKindDateHeader;
	if (layout.isService)
		return TGMessageCellKindService;
	return TGMessageCellKindBubble;
}

NSString *TGMessageCellReuseIdentifierForKind(TGMessageCellKind kind) {
	switch (kind) {
		case TGMessageCellKindService:
			return @"TGMessageServiceCell";
		case TGMessageCellKindDateHeader:
			return @"TGMessageDateHeaderCell";
		case TGMessageCellKindUnreadSeparator:
			return @"TGMessageUnreadSeparatorCell";
		case TGMessageCellKindBubble:
		default:
			return @"TGBubbleCell";
	}
}

NSString *TGBubbleReuseIdentifier(TGMessageLayout *layout) {
	if (layout.isSticker || layout.isRound)
		return @"TGBubbleCell.sticker";
	if (layout.isVoice || layout.isTrack || layout.isCall)
		return @"TGBubbleCell.audio";
	if (layout.isPoll || layout.isChecklist || layout.isCard || layout.isDoc ||
			layout.isContact || layout.isLocation)
		return @"TGBubbleCell.card";
	if (layout.isAlbum || !CGRectIsEmpty(layout.pictureFrame))
		return @"TGBubbleCell.media";
	return @"TGBubbleCell.text";
}
