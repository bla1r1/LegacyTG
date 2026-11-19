//
// TGRenderedLabel.h - a UILabel whose message text comes as a picture drawn
// by TGTextRender, from the cache when the chat drew it ahead of time.
//
#import <UIKit/UIKit.h>

@interface TGRenderedLabel : UILabel
/// The cache key of this text's picture (message, size, colour, reveal).
/// Nil draws the way UILabel does. Set after the text.
@property (nonatomic, copy) NSString *renderKey;
/// Whether bubbles use this class here: on iOS 6 only, where there is no
/// TextKit and UILabel has the plain drawRect: this class takes over.
+ (BOOL)wanted;
@end
