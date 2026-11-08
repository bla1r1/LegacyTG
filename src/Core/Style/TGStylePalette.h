//
// TGStylePalette.h
// Fixed non-theme palette roles and decorative tile hues.
//
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

#pragma mark - colour that is not the theme's

UIColor *TGColourLink(void);
UIColor *TGColourCodeBackground(void);
UIColor *TGColourCodeBlockBackground(void);
/// Telegram's colour for a sender's name, which no theme overrides.
UIColor *TGColourPeerName(int64_t colourId, BOOL dark);
/// The name colour an account chose: accent_color_id 0-6 are the built-in
/// seven (the same slots TGColourPeerName fills), 7 and up come from
/// updateAccentColors. Nil when the id is unknown (negative or not listed).
UIColor *TGColourAccentName(NSInteger accentId, NSArray *accentColors, BOOL dark);

#pragma mark - icon tile hues

UIColor *TGIconTileViolet(void);
UIColor *TGIconTilePurple(void);
UIColor *TGIconTileOrchid(void);
UIColor *TGIconTileSky(void);
UIColor *TGIconTileAzure(void);
UIColor *TGIconTileCyan(void);
UIColor *TGIconTileGreen(void);
UIColor *TGIconTileAmber(void);
UIColor *TGIconTileGold(void);
UIColor *TGIconTileCoral(void);
UIColor *TGIconTileRed(void);
UIColor *TGIconTileGrey(void);
UIColor *TGIconTileSlate(void);

#pragma mark - wallpaper preset hues

@interface TGWallpaperPreset : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) UIColor *topColor;
@property (nonatomic, strong) UIColor *bottomColor;
@property (nonatomic, assign) BOOL isGradient;
+ (instancetype)presetWithName:(NSString *)name color:(UIColor *)color;
+ (instancetype)presetWithName:(NSString *)name top:(UIColor *)top bottom:(UIColor *)bottom;
@end

NSArray *TGWallpaperPalettePresets(void);

#ifdef __cplusplus
}
#endif
