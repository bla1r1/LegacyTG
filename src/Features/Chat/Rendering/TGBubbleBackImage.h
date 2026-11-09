//
// TGBubbleBackImage.h - the chat's eight stretchable bubble pictures, shared
// with the Appearance preview so its bubbles and tails are the chat's own.
//
#import <UIKit/UIKit.h>

@class TGTheme;

/// Mine or theirs, first of a run or not, tailed (`last`) or not. The image
/// is TGMetricBubbleTailWidth wider than the bubble on the tail side.
UIImage *TGBubbleBackImage(TGTheme *theme, BOOL mine, BOOL first, BOOL last);
void TGBubbleFlushCache(void);
