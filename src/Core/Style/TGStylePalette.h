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

#pragma mark - Classic theme roles

/// The chat roles Classic uses when no imported theme is active. TGTheme's
/// colour getters and the baked theme cards both read this one table, so a
/// card can never drift from the screen it previews.
static inline NSDictionary *TGClassicThemeRoleColours(void) {
	static NSDictionary *roles = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		roles = @{
		@"wallpaper"        : [UIColor colorWithRed:226.0f / 255.0f
											  green:230.0f / 255.0f
											   blue:236.0f / 255.0f alpha:1.0f],
		@"bubbleMine"       : [UIColor colorWithRed:223.0f / 255.0f
											  green:238.0f / 255.0f
											   blue:250.0f / 255.0f alpha:1.0f],
		@"bubbleTheirs"     : [UIColor colorWithRed:255.0f / 255.0f
											  green:255.0f / 255.0f
											   blue:255.0f / 255.0f alpha:1.0f],
		@"bubbleMineText"   : [UIColor colorWithRed:34.0f / 255.0f
											  green:34.0f / 255.0f
											   blue:34.0f / 255.0f alpha:1.0f],
		@"bubbleTheirsText" : [UIColor colorWithRed:34.0f / 255.0f
											  green:34.0f / 255.0f
											   blue:34.0f / 255.0f alpha:1.0f],
		@"text"             : [UIColor colorWithRed:34.0f / 255.0f
											  green:34.0f / 255.0f
											   blue:34.0f / 255.0f alpha:1.0f],
		@"accent"           : [UIColor colorWithRed:81.0f / 255.0f
											  green:125.0f / 255.0f
											   blue:162.0f / 255.0f alpha:1.0f],
		// The same verticals TGTheme (Gradients) paints on a Classic bubble.
		@"bubbleMineGradient": @[
			[UIColor colorWithRed:230.0f / 255.0f green:242.0f / 255.0f blue:253.0f / 255.0f alpha:1.0f],
			[UIColor colorWithRed:214.0f / 255.0f green:235.0f / 255.0f blue:250.0f / 255.0f alpha:1.0f],
			[UIColor colorWithRed:196.0f / 255.0f green:226.0f / 255.0f blue:248.0f / 255.0f alpha:1.0f],
			[UIColor colorWithRed:180.0f / 255.0f green:218.0f / 255.0f blue:245.0f / 255.0f alpha:1.0f],
		],
		@"bubbleTheirsGradient": @[
			[UIColor colorWithRed:255.0f / 255.0f green:255.0f / 255.0f blue:255.0f / 255.0f alpha:1.0f],
			[UIColor colorWithRed:242.0f / 255.0f green:242.0f / 255.0f blue:245.0f / 255.0f alpha:1.0f],
			[UIColor colorWithRed:220.0f / 255.0f green:220.0f / 255.0f blue:224.0f / 255.0f alpha:1.0f],
			[UIColor colorWithRed:208.0f / 255.0f green:208.0f / 255.0f blue:214.0f / 255.0f alpha:1.0f],
		],
	};
	});
	return roles;
}

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
