//
// TGLottieSupport.h - what TGLottieView's renderer cannot draw.
//
// The renderer draws shape layers (path, ellipse, rectangle, fill, gradient
// fill, stroke, group transforms) and masks. Anything else it skipped in
// silence, and the animation came out wrong instead of failing: the "High
// Voltage" custom emoji (6 precomp layers, 12 trim paths) drew as bare red
// outlines, so of five equal emoji in a message only the fifth, past the
// three-animation cap, looked right. A file that needs more keeps its still
// picture.
//
#import <Foundation/Foundation.h>

/// The first feature in a parsed Lottie dictionary the renderer cannot draw,
/// as a short name for the log ("precomp layer", "trim path", "track matte",
/// ...); nil when it can draw all of it. Assets' layers are checked too.
FOUNDATION_EXPORT NSString *TGLottieUnsupportedFeature(NSDictionary *animation);

/// A gradient's stops at `frame` as [offset, r, g, b, a] per colour stop.
/// `g` is the shape's "g": {p: colour stops, k: {a: 0|1, k: ...}}. Telegram's
/// files always wrap the array in {a, k}, and the renderer read only a bare
/// array: every gradient fill was skipped and stickers drew as outlines.
/// After the colour stops come optional opacity stops (offset, alpha); each
/// colour stop takes the opacity interpolated at its offset. An animated
/// gradient takes the keyframe in force at `frame`. Nil when unreadable.
FOUNDATION_EXPORT NSArray *TGLottieGradientStops(NSDictionary *g, double frame);
