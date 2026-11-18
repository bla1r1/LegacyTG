//
// TGLottieRender.h - draws one frame of a parsed Lottie animation.
//
// The layer tree is laid out once into C++ (layers, parents and precomps
// resolved to indices), so a frame walks vectors instead of building
// NSArrays and looking parents up in a dictionary. Precomp layers are drawn
// the way the official client's renderers (tlottie by default, rlottie behind
// a killswitch) draw them: their own clock (frame - st, over sr, or the time
// remap in seconds), clipped to w x h, the precomp's opacity carried into its
// content. Merge paths are skipped, as both of those renderers skip them.
// What else it cannot draw, TGLottieUnsupportedFeature
// names before a scene is made.
//
// Plain C over CoreGraphics: TGLottieView rasterises a loop with it in the
// background, and the host tests draw with it on macOS.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef struct TGLottieScene TGLottieScene;

/// The scene of a parsed Lottie dictionary; NULL when it has no layers or no
/// canvas. Free it with TGLottieSceneFree.
FOUNDATION_EXPORT TGLottieScene *TGLottieSceneCreate(NSDictionary *animation);

FOUNDATION_EXPORT void TGLottieSceneFree(TGLottieScene *scene);

/// Frame `frame` of the root composition, fitted into `pixelSize` and
/// centred. Rows run top to bottom, as Lottie's y axis does. NULL for an
/// empty size; the caller releases the image.
FOUNDATION_EXPORT CGImageRef TGLottieSceneRender(const TGLottieScene *scene, double frame,
		CGSize pixelSize) CF_RETURNS_RETAINED;
