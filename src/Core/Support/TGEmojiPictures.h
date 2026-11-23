//
// TGEmojiPictures.h - emoji drawn from the bundled face's own PNGs, for iOS 7.
//
// iOS 7's ImageIO crashed reading AppleColorEmojiCompat's glyphs through
// CoreGraphics while the UI redrew under load (a 4S turned with the emoji
// panel open), though each of its 3844 glyphs draws alone. Here the face file
// is read as bytes: a sequence's glyph comes from the table
// scripts/build_emoji_map.m made with macOS CoreText (flags, keycaps, skin
// tones and ZWJ families included), its PNG from the sbix table, and UIImage
// decodes a copy of those bytes. CoreGraphics never touches the face.
//
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

/// YES on iOS 7, where text, labels and the emoji panel use these pictures.
BOOL TGEmojiPicturesActive(void);

/// The face's PNG for one emoji sequence (U+FE0F anywhere is ignored), nil
/// when the face has no picture for it.
NSData *TGEmojiPicturePNG(NSString *sequence);

/// The picture at `side` points square, cached; nil like TGEmojiPicturePNG.
UIImage *TGEmojiPicture(NSString *sequence, CGFloat side);

/// The emoji in `text` the face has a picture for, as NSValue ranges, longest
/// sequence first at each place. A character that is text by default (the
/// copyright sign, a plain heart) counts only with U+FE0F after it.
NSArray *TGEmojiPictureRanges(NSString *text);

/// `text` with each of those emoji turned into an inline picture sized for
/// `font`, sitting on the baseline like a glyph; nil when there are none.
NSAttributedString *TGEmojiPictureText(NSAttributedString *text, UIFont *font);

/// The host tests point these at the repository's files; the app reads the
/// bundle's.
void TGEmojiPicturesUseFiles(NSString *fontPath, NSString *mapPath);

#ifdef __cplusplus
}
#endif
