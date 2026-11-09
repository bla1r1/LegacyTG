//
// TGPatternImage.h - Telegram .tgv wallpaper patterns.
//
// A .tgv is a gzipped SVG. It is decoded once into a coverage mask, then the
// fill and the mask are baked into one bitmap: no SVG, gradient or blend runs
// while a list scrolls.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#ifdef __cplusplus
extern "C" {
#endif

/// A .tgv's gzip payload, or the input unchanged when it is already SVG/zlib.
NSData *TGPatternGunzip(NSData *data);

/// One serial queue for every pattern decode and bake. nanosvg holds the parsed
/// document plus a bitmap per call; on the global queues a screen of theme
/// cards ran a dozen at once and the 4S was killed by jetsam.
dispatch_queue_t TGPatternWorkQueue(void);

/// The SVG's shapes rasterised white-on-transparent at `size`, aspect-filled.
/// Returns a retained image, or NULL when the document is not a usable SVG.
CGImageRef TGPatternCreateMask(NSData *tgvData, CGSize size) CF_RETURNS_RETAINED;

/// The background fill alone: solid, linear gradient, or a baked four-corner
/// freeform blend for three or more colours.
CGImageRef TGPatternCreateFill(CGSize size, NSArray *colours, NSString *kind,
							   CGFloat rotation) CF_RETURNS_RETAINED;

/// The fill plus the mask. `inverted` is the dark variant: the pattern becomes
/// holes in a black overlay instead of a soft-light tint. Returns a retained
/// image, or NULL when no fill can be drawn.
CGImageRef TGPatternCreateWallpaper(CGSize size, NSArray *colours, NSString *kind,
									CGFloat rotation, CGImageRef mask,
									CGFloat intensity, BOOL inverted)
		CF_RETURNS_RETAINED;

#ifdef __cplusplus
}
#endif
