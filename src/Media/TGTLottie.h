//
// TGTLottie.h - tlottie, the official client's Lottie renderer, behind a
// CoreGraphics face.
//
// tlottie (third_party/tlottie, built by scripts/build_tlottie.sh) draws every
// feature the official stickers use - trim paths, mattes, gradient strokes,
// repeaters - and drew a 54-frame loop about 4x faster than TGLottieRender on
// the same files. TGLottieView tries it first; a file it will not parse or
// render goes to TGLottieRender, and past that to the still.
//
// Every tlottie call goes through one lock: tlottie is single-threaded per
// instance, and the crash guard below names one file at a time.
//
// A crash inside tlottie (panic = abort) takes the app down; TGCrashGuard
// writes the file's name on the way out, and from the next launch that file
// is refused here and drawn by TGLottieRender.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef struct TGTLottie TGTLottie;

/// Where the crash marker (tlottie.crashed) and the refused list
/// (tlottie.refused, one file name per line) live. Moves a marker left by a
/// crash into the list and installs the guard; call before the first create.
FOUNDATION_EXPORT void TGTLottieUseCrashLog(NSString *directory);

/// tlottie's instance for a .tgs's JSON, `name` being the file it came from;
/// NULL when tlottie cannot parse it or crashed on that file before.
FOUNDATION_EXPORT TGTLottie *TGTLottieCreate(NSData *json, NSString *name);

FOUNDATION_EXPORT void TGTLottieFree(TGTLottie *animation);

/// Frames from the first, at the animation's own rate.
FOUNDATION_EXPORT NSUInteger TGTLottieFrameCount(const TGTLottie *animation);
FOUNDATION_EXPORT double TGTLottieFrameRate(const TGTLottie *animation);

/// Frame `frame` (counted from the first) fitted into `pixelSize`, the
/// animation's proportions kept; rows top to bottom. NULL when tlottie
/// reports an error. The caller releases the image.
FOUNDATION_EXPORT CGImageRef TGTLottieRender(TGTLottie *animation, double frame,
		CGSize pixelSize) CF_RETURNS_RETAINED;
