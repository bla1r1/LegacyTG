//
// TGiPadSimulator.h
// LegacyTG - Virtual iPad canvas & layout preview for dev builds
//
#import <UIKit/UIKit.h>

@class UIWindow;

#if TG_DEV

typedef NS_ENUM(NSInteger, TGiPadOrientation) {
	TGiPadOrientationOff = 0,
	TGiPadOrientationPortrait,   // 768 x 1024
	TGiPadOrientationLandscape   // 1024 x 768
};

#ifdef __cplusplus
extern "C" {
#endif

CGSize TGiPadCanvasSizeForOrientation(TGiPadOrientation orientation);
CGFloat TGiPadScaleToFitScreen(CGSize canvasSize, CGSize screenSize);
CGRect TGiPadCanvasRectForScreen(CGSize canvasSize, CGSize screenSize);

#ifdef __cplusplus
}
#endif

@interface TGiPadSimulator : NSObject

+ (instancetype)shared;
@property (nonatomic, assign, readonly) TGiPadOrientation orientation;
@property (nonatomic, assign, readonly) BOOL isActive;
@property (nonatomic, strong, readonly) UIView *canvasView;

- (void)setOrientation:(TGiPadOrientation)orientation inWindow:(UIWindow *)window;
- (void)toggleModeInWindow:(UIWindow *)window;
- (void)toggleOrientationInWindow:(UIWindow *)window;
- (UIImage *)captureScreenshotAtScale:(CGFloat)scale;
- (NSString *)saveScreenshotRetina:(BOOL)retina;

@end

#endif
