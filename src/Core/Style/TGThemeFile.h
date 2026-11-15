//
// TGThemeFile - parser for Telegram theme files (.tgios-theme JSON, .attheme ARGB).
//
#import <UIKit/UIKit.h>

@interface TGThemeFile : NSObject

/// Palette keyed by TGTheme's colour names ("bar", "accent", "bubbleMine"...),
/// or nil if the file is neither format. `name` gets the theme's own name.
+ (NSDictionary *)paletteFromFile:(NSString *)path name:(NSString **)name;

/// The part of a theme the app applies: the chat roles only, since bars
/// and lists stay the system's. Light and dark files are both accepted.
+ (NSDictionary *)chatPaletteFromFile:(NSString *)path name:(NSString **)name;

/// YES for a path this class can read.
+ (BOOL)handlesFile:(NSString *)path;

/// The role colours one availableThemes entry paints with, without switching
/// the live theme: Classic reads TGClassicThemeRoleColours(), a file theme
/// reads its own chat palette. Keyed by "wallpaper", "bubbleMine",
/// "bubbleTheirs", "bubbleMineText", "bubbleTheirsText", "text", "accent",
/// and, when the file carries them, "bubbleMineGradient" and
/// "bubbleTheirsGradient".
+ (NSDictionary *)cardPaletteForThemeEntry:(NSDictionary *)entry;

@end

/// "#3497ED" or "3497edcc" as a colour, nil for anything else. Data-borne
/// colours only (a theme file, a statistics graph); the app's own come from
/// TGTheme.
FOUNDATION_EXPORT UIColor *TGColourFromHexString(NSString *hex);
