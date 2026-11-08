//
// TGNameWithStatus.h - name string unified with emoji status attachment.
//
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Appends a space and an NSTextAttachment with the custom emoji picture
/// sized to font's line height on iOS 7+ when statusEmojiId is non-zero.
/// On iOS 6 or when statusEmojiId is 0 or while loading, returns the plain
/// name with font and colour applied.
FOUNDATION_EXPORT NSAttributedString *TGNameWithStatus(NSString *name, int64_t statusEmojiId, UIFont *font, UIColor *colour);

#ifdef __cplusplus
}
#endif
