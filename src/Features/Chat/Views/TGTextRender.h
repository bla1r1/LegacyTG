//
// TGTextRender.h - message text drawn by CoreText into a bitmap, on any
// thread, so the chat's bubbles stop paying UILabel's layout and drawing on
// the main thread while it scrolls.
//
// The same layout serves the picture, the custom emoji rects and the link
// hit test: three engines (UIKit drawing, CoreText placement, CoreText hit
// test) used to disagree on where lines broke on iOS 6.
//
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Whether this text can be drawn here. Not when it carries an inline
/// attachment (iOS 7+ custom emoji pictures): CoreText cannot draw those,
/// the label keeps drawing it.
BOOL TGTextRenderCan(NSAttributedString *text);

/// The text laid out top-left in `size` points and drawn at `scale`: fonts,
/// colours, background plates (code, spoilers), underline and strikethrough.
/// Returns a +1 image, NULL for empty text or an empty box. Any thread.
CGImageRef TGTextRenderCreateImage(NSAttributedString *text, CGSize size, CGFloat scale);

/// Draws `text` into `ctx`, a top-down UIKit context, as a UILabel would lay it out
/// in `bounds`: at most `maxLines` lines (0 for all), the last one ending in
/// an ellipsis when text is left over, aligned and centred vertically. For
/// labels iOS 6 UIKit draws wrong (a flag from the bundled emoji face).
/// With `lineHeight` above 0 every line is that tall and its baseline
/// `faceAscent` below its top, whatever face its runs have.
void TGTextRenderDrawLabel(CGContextRef ctx, NSAttributedString *text, CGRect bounds, NSInteger maxLines,
		NSTextAlignment alignment, CGFloat lineHeight, CGFloat faceAscent, CGFloat scale);

/// How many lines `text` takes at `width` in this engine's layout.
NSUInteger TGTextRenderLineCount(NSAttributedString *text, CGFloat width);

/// The character under `point` (top-left origin, points) in the same layout,
/// or NSNotFound off any glyph.
NSUInteger TGTextRenderIndexAtPoint(NSAttributedString *text, CGSize size, CGPoint point);

/// Main-thread cache of finished pictures by key, bounded by bytes (LRU).
CGImageRef TGTextRenderCached(NSString *key);
void TGTextRenderStore(NSString *key, CGImageRef image);
/// Builds the text with `build` and draws it on the render queue, then stores
/// it under `key`, unless it is cached or already on the way. Main thread;
/// `build` runs on the render queue.
void TGTextRenderPrefetch(NSString *key, CGSize size, CGFloat scale, NSAttributedString *(^build)(void));
/// The custom emoji rects (TGCustomEmojiRectsCoreText) worked out with the
/// prefetched picture, from the same layout; nil when not prefetched.
NSArray *TGTextRenderCachedEmojiRects(NSString *key);
void TGTextRenderClearCache(void);
/// Holds the render queue while a table moves and lets it run again after:
/// drawing ahead took the glyph lock and the core from the frames it was
/// drawing for. Main thread; calls pair up.
void TGTextRenderHold(BOOL held);
/// Bytes the cache holds, for tests and the memory line.
size_t TGTextRenderCacheBytes(void);

#ifdef __cplusplus
}
#endif
