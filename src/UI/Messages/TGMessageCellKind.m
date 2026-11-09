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
