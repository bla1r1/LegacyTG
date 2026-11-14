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
