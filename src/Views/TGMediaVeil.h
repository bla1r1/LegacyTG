//
// TGMediaVeil - the cover over a picture the person must not see yet: a
// spoiler, a view-once photo or video, paid media. One cover for all three,
// so they look alike: the picture blurred, a dimming plate, one label (and
// for paid media the price as a button).
//
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TGMediaVeilKind) {
	TGMediaVeilKindNone = 0,
	TGMediaVeilKindSpoiler,   ///< tap reveals, as in Telegram
	TGMediaVeilKindViewOnce,  ///< "Tap to view", opens once full screen
	TGMediaVeilKindPaid,      ///< "Unlock for N Stars"
};

/// A blurred copy of `image`: the result is small (at most 48 px on its long
/// side) and the caller draws it scaled up; this keeps a 4S from holding a
/// full-size blurred copy. Safe off the main thread. Nil in, nil out.
FOUNDATION_EXPORT CGImageRef TGMediaVeilBlurCreate(CGImageRef image, CGFloat radius) CF_RETURNS_RETAINED;

/// The words on the veil: nil for a spoiler (official shows none), "Tap to view" for view-once, "Unlock for N Stars" ("Unlock for 1 Star") for paid.
FOUNDATION_EXPORT NSString *TGMediaVeilTitle(TGMediaVeilKind kind, int64_t starCount);

@interface TGMediaVeilView : UIView
@property (nonatomic, assign) TGMediaVeilKind kind;
/// For TGMediaVeilKindPaid: the price shown on the button.
@property (nonatomic, assign) int64_t starCount;
/// Called when the person taps the veil (reveal, view, unlock).
@property (nonatomic, copy) void (^onTap)(TGMediaVeilKind kind);
/// The picture under the veil; it is blurred off the main thread and drawn
/// when ready. Nil shows the plate alone.
- (void)setPicture:(UIImage *)picture;
@end
