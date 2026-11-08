//
// TGMessageCardView - draws one TGMessageCard inside a chat bubble: kicker,
// title, lines, an optional picture on the left, an optional button under
// them. Text is plain UILabels, the picture one UIImageView with the circle
// baked into the bitmap: no masks, no shadows, nothing the A4 repaints per
// scroll frame.
//
#import <UIKit/UIKit.h>
#import "TGMessageCard.h"

/// Frames of every part, from TGMessageCardLayout. Zero rects for parts the
/// card does not have.
typedef struct {
	CGSize size;          ///< the whole card
	CGRect image;
	CGRect kicker;
	CGRect title;
	CGRect lines[4];
	CGRect button;
} TGMessageCardFrames;

/// The card's geometry at `width`: pure, no views, so a host test and the
/// chat's layout pass can both call it. Width is the bubble's inner width.
FOUNDATION_EXPORT TGMessageCardFrames TGMessageCardLayout(TGMessageCard *card, CGFloat width);

@interface TGMessageCardView : UIView
/// Called with the card when its button is tapped.
@property (nonatomic, copy) void (^onAction)(TGMessageCard *card);
/// Lays the card out at the view's current width and starts loading its
/// picture through TGMediaStore; a later card cancels an earlier load.
- (void)showCard:(TGMessageCard *)card;
@end
