//
// TGChatThemeStore.h - the emoji chat themes Telegram serves and the one the
// account picked. Views ask this store; they never import TGClient.h.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
extern NSString *const TGChatThemeStoreChangedNotification;

/// The chosen theme survives a launch as its name. An emoji theme id is the
/// name prefixed with "emoji:", so it cannot collide with a base theme id.
static NSString *const TGSettingsEmojiThemeKey = @"themeEmojiName";

static inline BOOL TGChatThemeIdIsEmoji(NSString *themeId) {
	return [themeId isKindOfClass:NSString.class] &&
			[themeId hasPrefix:@"emoji:"];
}

static inline NSString *TGChatThemeIdForName(NSString *name) {
	return name.length ? [@"emoji:" stringByAppendingString:name] : nil;
}

static inline NSString *TGChatThemeNameFromId(NSString *themeId) {
	return TGChatThemeIdIsEmoji(themeId)
			? [themeId substringFromIndex:@"emoji:".length] : nil;
}

/// The settings block that paints an entry in the current mode. Official
/// switches to the dark settings of the same theme, never to another theme.
static inline NSDictionary *TGChatThemeSettingsForMode(NSDictionary *entry,
													   BOOL darkMode) {
	NSDictionary *dark = entry[@"dark"];
	if (darkMode && [dark isKindOfClass:NSDictionary.class] && dark.count)
		return dark;
	NSDictionary *light = entry[@"light"];
	return [light isKindOfClass:NSDictionary.class] ? light : nil;
}

@interface TGChatThemeStore : NSObject

/// Renders a .tgs pattern to a still image. The UI layer installs this; when
/// it is nil, animated patterns are skipped rather than parsed by the store.
@property (nonatomic, copy) void (^tgsPatternRenderer)(NSString *path, CGFloat side,
													  void (^completion)(id image));

+ (TGChatThemeStore *)shared;

/// Emoji chat themes as entries with "id", "name", "light", "dark",
/// "hasDark". The settings dictionaries are palettes ready to paint with.
- (NSArray *)themes;

- (NSDictionary *)themeNamed:(NSString *)name;
- (BOOL)themeNamedHasDarkVariant:(NSString *)name;

/// The theme the account picked, or nil for a base theme.
- (NSString *)currentThemeName;
- (void)setCurrentThemeName:(NSString *)name;
- (void)clearCurrentThemeName;

/// A palette for one theme in one variant. Keys: "accent", "wallpaper",
/// "wallpaperFill", "bubbleMine", "bubbleMineGradient", "bubbleMineText",
/// "bubbleTheirs", "bubbleTheirsText", "text", "isDark", "patternFileId",
/// "patternIntensity". Nil when the theme is unknown.
- (NSDictionary *)paletteForThemeNamed:(NSString *)name dark:(BOOL)dark;
- (NSDictionary *)paletteForEntry:(NSDictionary *)entry dark:(BOOL)dark;

/// The pattern document drawn over the theme's fill. The first call starts the
/// download and answers nil; once the file is decoded the store posts
/// TGChatThemeStoreChangedNotification and the next call answers the image.
- (id)patternImageForThemeNamed:(NSString *)name dark:(BOOL)dark;

/// The theme's own background baked at `size`, fill plus pattern, cached.
- (id)wallpaperForThemeNamed:(NSString *)name
							   dark:(BOOL)dark
							   size:(CGSize)size;

/// The same fill plus pattern for a settings card. It composites from the
/// already-decoded mask, so the SVG is never parsed on the main thread.
- (id)cardWallpaperForThemeNamed:(NSString *)name
								   dark:(BOOL)dark
								   size:(CGSize)size;

#pragma mark - parsing, shared with the host tests

/// updateEmojiChatThemes -> entries. Tolerates missing light or dark halves.
+ (NSArray *)parseThemes:(NSArray *)records;
+ (NSDictionary *)paletteForThemeRecord:(NSDictionary *)record dark:(BOOL)dark;
+ (NSDictionary *)paletteFromThemeSettings:(NSDictionary *)settings;
+ (BOOL)recordHasDarkVariant:(NSDictionary *)record;

@end
