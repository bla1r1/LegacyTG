//
// TGMessageServiceCell.h - a service event plate in the message list.
//
// "Pinned a message", "joined the group": one centred line on a plate. The
// prebuilt TGMessageLayout carries the plate and text frames; the cell only
// paints them from the theme. The message list is an element family, not a
// TGRows row kind: a row here is a message.
//
#import "TGMessageBubbleCell.h"

@class TGTheme;

@interface TGMessageServiceCell : TGBubbleCell

@end
