//
// TGPageHeaderView.h - the top of a page that introduces what it is about:
// a picture, a title, a line under it and a short paragraph, all centred.
//
// Every page that had one built its own, with its own fonts and gaps (Update,
// File Info, Gift). Here the parts are fixed and only the content changes;
// TGCentredStackPlace in TGRowGeometry decides where each part goes.
//
#import <UIKit/UIKit.h>

@interface TGPageHeaderView : UIView

/// Sized to its content for `width`; set it as the table's header. A nil part
/// is left out with its gap; an empty string keeps one line for text that
/// arrives later. `artSide` 0 means no picture.
- (instancetype)initWithWidth:(CGFloat)width artSide:(CGFloat)artSide
		title:(NSString *)title subtitle:(NSString *)subtitle text:(NSString *)text;

/// The height initWithWidth:... would give, without building the view.
+ (CGFloat)heightForWidth:(CGFloat)width artSide:(CGFloat)artSide
		title:(NSString *)title subtitle:(NSString *)subtitle text:(NSString *)text;

/// Holds the picture. `imageView` fills it; a page with an animation adds its
/// own view here instead.
@property (nonatomic, strong, readonly) UIView *artView;
@property (nonatomic, strong, readonly) UIImageView *imageView;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *subtitleLabel;
@property (nonatomic, strong, readonly) UILabel *textLabel;

/// Repaints the labels from TGTheme; the page calls it from its applyTheme.
- (void)applyTheme;

@end
