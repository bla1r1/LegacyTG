#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Classic iOS 6 skeuomorphic segmented control with metallic satin frame,
/// engraved dividers, and tactile sliding active pill indicator.
@interface TGSegmentedControl : UIControl

@property (nonatomic, copy) NSArray *items;
@property (nonatomic, assign) NSInteger selectedSegmentIndex;

- (instancetype)initWithItems:(nullable NSArray *)items;
- (void)setSelectedSegmentIndex:(NSInteger)selectedSegmentIndex animated:(BOOL)animated;
- (void)setTitle:(NSString *)title forSegmentAtIndex:(NSUInteger)segment;
- (nullable NSString *)titleForSegmentAtIndex:(NSUInteger)segment;

@end

/// The system segments the screens use, in the two places they sit. A bar's
/// segments (scopes, a title-view filter) take the short bar style that iOS 6
/// needs to fit 44 pt; content segments (a card, a table header) keep the
/// tall plain style. Target and selection are the caller's.
FOUNDATION_EXPORT UISegmentedControl *TGBarSegments(NSArray *items);
FOUNDATION_EXPORT UISegmentedControl *TGContentSegments(NSArray *items);

NS_ASSUME_NONNULL_END
