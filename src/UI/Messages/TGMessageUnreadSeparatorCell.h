//
// TGMessageUnreadSeparatorCell.h - the unread band in the message list.
//
// A full-width band, not a plate: it marks a place in the conversation, so it
// keeps no corner and no side margin. The message list is an element family,
// not a TGRows row kind: a row here is a message.
//
#import "TGMessageServiceCell.h"

@interface TGMessageUnreadSeparatorCell : TGMessageServiceCell

@end
