//
// TGChatThemeStore.m - updateEmojiChatThemes records, their two variants and
// the pattern documents behind them.
//
// The parser lives here rather than in a view because two screens draw the
// same card and the chat applies the same palette. A record is flattened once
// into the roles TGTheme already knows, so an emoji theme and an imported file
// reach the drawing code through one shape.
//
#import "TGChatThemeStore.h"
#import "TGClient.h"
#import "TGDownloadPriority.h"
#import "TGPatternImage.h"
#import "TGStylePalette.h"


NSString *const TGChatThemeStoreChangedNotification = @"TGChatThemeStoreChanged";

static const NSInteger TGStorePatternIntensityDefault = 50;
// A card is 82 pt and the mask is tiled, so 256 px is enough; 512 px RGBA
// was 1 MB a mask, exactly the 32-bit cache limit, and each new mask evicted
// the last one, which was then asked for and decoded again, forever.
static const CGFloat TGStorePatternSide = 256.0f;

#if TARGET_OS_IPHONE
/// Decoded masks and baked wallpapers kept in Caches, so a launch reads a PNG
/// instead of parsing the SVG and compositing again.
static NSString *TGStoreDiskPath(NSString *name) {
	static NSString *dir;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
				NSUserDomainMask, YES).firstObject
				stringByAppendingPathComponent:@"ThemePatterns"];
		[[NSFileManager defaultManager] createDirectoryAtPath:dir
				withIntermediateDirectories:YES attributes:nil error:NULL];
	});
	return [dir stringByAppendingPathComponent:
			[name stringByAppendingPathExtension:@"png"]];
}

static UIImage *TGStoreDiskImage(NSString *name) {
	NSData *data = [NSData dataWithContentsOfFile:TGStoreDiskPath(name)];
	return data.length ? [UIImage imageWithData:data] : nil;
}

static void TGStoreDiskWrite(UIImage *image, NSString *name) {
	NSData *png = image ? UIImagePNGRepresentation(image) : nil;
	if (png.length)
		[png writeToFile:TGStoreDiskPath(name) atomically:YES];
}
#endif

@interface TGChatThemeStore ()
+ (NSDictionary *)paletteFromThemeSettings:(NSDictionary *)settings
								  darkHint:(BOOL)darkHint;
- (UIImage *)patternImageForFileId:(NSNumber *)fileId;
- (void)decodePatternAtPath:(NSString *)path fileId:(NSNumber *)fileId;
@end

#if TARGET_OS_IPHONE
static void TGStoreDrawFill(NSDictionary *fill, CGRect rect);
#endif

#pragma mark - colour and fill parsing

/// TDLib writes colours as signed 32-bit 0xRRGGBB.
static UIColor *TGStoreColour(id value) {
	if ([value isKindOfClass:NSNumber.class]){
		uint32_t rgb = (uint32_t)[value longLongValue];
		return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0f
							   green:((rgb >> 8) & 0xFF) / 255.0f
								blue:(rgb & 0xFF) / 255.0f
							   alpha:1.0f];
	}
	if ([value isKindOfClass:NSString.class]){
		NSString *hex = [(NSString *)value stringByReplacingOccurrencesOfString:@"#"
																	withString:@""];
		unsigned int rgb = 0;
		if (hex.length >= 6 &&
			[[NSScanner scannerWithString:[hex substringToIndex:6]] scanHexInt:&rgb]){
			return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0f
								   green:((rgb >> 8) & 0xFF) / 255.0f
									blue:(rgb & 0xFF) / 255.0f
								   alpha:1.0f];
		}
	}
	return nil;
}

static NSArray *TGStoreWallpaperColours(NSDictionary *palette) {
	NSArray *colours = palette[@"wallpaperFill"][@"colors"];
	if ([colours isKindOfClass:NSArray.class] && colours.count)
		return colours;
	UIColor *fallback = palette[@"wallpaper"];
	return [fallback isKindOfClass:[UIColor class]] ? @[fallback] : @[];
}

static CGFloat TGStoreLuminance(UIColor *colour) {
	CGFloat r = -1, g = -1, b = -1, a = -1;
	[colour getRed:&r green:&g blue:&b alpha:&a];
	if (r < 0)
		return 0.5f;
	return 0.299f * r + 0.587f * g + 0.114f * b;
}

/// One BackgroundFill as the drawing code needs it: a kind, its stops and the
/// rotation Telegram sent. A fill with no colour answers nil, never a black.
static NSDictionary *TGStoreFill(NSDictionary *fill) {
	if (![fill isKindOfClass:NSDictionary.class])
		return nil;
	NSString *kind = fill[@"@type"];
	NSMutableArray *colours = [NSMutableArray array];
	if ([kind isEqualToString:@"backgroundFillSolid"]){
		UIColor *colour = TGStoreColour(fill[@"color"]);
		if (colour)
			[colours addObject:colour];
	} else if ([kind isEqualToString:@"backgroundFillGradient"]){
		UIColor *top = TGStoreColour(fill[@"top_color"]);
		UIColor *bottom = TGStoreColour(fill[@"bottom_color"]);
		if (top) [colours addObject:top];
		if (bottom) [colours addObject:bottom];
	} else if ([kind isEqualToString:@"backgroundFillFreeformGradient"]){
		NSArray *raw = fill[@"colors"];
		if ([raw isKindOfClass:NSArray.class]){
			for (id value in raw){
				UIColor *colour = TGStoreColour(value);
				if (colour)
					[colours addObject:colour];
			}
		}
	}
	if (!colours.count)
		return nil;
	return @{
		@"kind"   : [kind isKindOfClass:NSString.class] ? kind : @"backgroundFillSolid",
		@"colors" : colours,
		@"angle"  : [fill[@"rotation_angle"] isKindOfClass:NSNumber.class]
				? fill[@"rotation_angle"] : @0,
	};
}

static NSString *TGStoreBaseThemeName(id base) {
	NSString *name = nil;
	if ([base isKindOfClass:NSDictionary.class])
		name = base[@"@type"] ?: base[@"name"];
	else if ([base isKindOfClass:NSString.class])
		name = base;
	return [name isKindOfClass:NSString.class] ? name : @"";
}

static BOOL TGStoreBaseThemeIsDark(id base) {
	NSString *name = [TGStoreBaseThemeName(base) lowercaseString];
	return [name rangeOfString:@"night"].location != NSNotFound ||
			[name rangeOfString:@"dark"].location != NSNotFound;
}

/// The incoming bubble belongs to the base theme, not to the emoji theme's own
/// settings. Telegram's built-in base palettes are small and fixed; the theme
/// only changes what sits behind them.
static void TGStoreApplyBaseIncoming(NSMutableDictionary *palette, BOOL dark) {
	if (dark){
		palette[@"bubbleTheirs"] = [UIColor colorWithRed:0x18 / 255.0f
												  green:0x25 / 255.0f
												   blue:0x33 / 255.0f alpha:1.0f];
		palette[@"bubbleTheirsText"] = [UIColor whiteColor];
		palette[@"text"] = [UIColor whiteColor];
	} else {
		palette[@"bubbleTheirs"] = [UIColor whiteColor];
		palette[@"bubbleTheirsText"] = TGClassicThemeRoleColours()[@"text"];
		palette[@"text"] = TGClassicThemeRoleColours()[@"text"];
	}
}

static NSNumber *TGStoreFileIdFromDocument(NSDictionary *document) {
	if (![document isKindOfClass:NSDictionary.class])
		return nil;
	NSNumber *fileId = document[@"document"][@"id"];
	if (![fileId isKindOfClass:NSNumber.class] || fileId.longLongValue <= 0)
		fileId = document[@"thumbnail"][@"file"][@"id"];
	return [fileId isKindOfClass:NSNumber.class] && fileId.longLongValue > 0
			? fileId : nil;
}

@implementation TGChatThemeStore {
	BOOL _changePosted;
	NSArray *_themes;
	NSCache *_patternCache;
	NSCache *_patternDataCache;
	NSCache *_wallpaperCache;
	NSMutableSet *_requestedPatterns;
	NSMutableSet *_pendingWallpapers;
#if TARGET_OS_IPHONE
#endif
}

+ (NSDictionary *)paletteFromThemeSettings:(NSDictionary *)settings {
	return [self paletteFromThemeSettings:settings darkHint:NO];
}

+ (NSDictionary *)paletteFromThemeSettings:(NSDictionary *)settings
								  darkHint:(BOOL)darkHint {
	if (![settings isKindOfClass:NSDictionary.class])
		return nil;

	BOOL dark = darkHint || TGStoreBaseThemeIsDark(settings[@"base_theme"]);
	NSMutableDictionary *palette = [NSMutableDictionary dictionary];
	palette[@"isDark"] = @(dark);

	UIColor *accent = TGStoreColour(settings[@"accent_color"]);
	NSDictionary *outgoing = TGStoreFill(settings[@"outgoing_message_fill"]);
	NSArray *outgoingColours = outgoing[@"colors"];
	UIColor *outgoingFirst = outgoingColours.firstObject;
	if (!accent)
		accent = outgoingFirst ?: TGClassicThemeRoleColours()[@"accent"];
	palette[@"accent"] = accent;

	if (outgoingFirst){
		palette[@"bubbleMine"] = outgoingFirst;
		if (outgoingColours.count > 1)
			palette[@"bubbleMineGradient"] = outgoingColours;
	} else {
		palette[@"bubbleMine"] = accent;
	}
	palette[@"bubbleMineFill"] = outgoing ?: @{};
	palette[@"bubbleMineText"] = TGStoreLuminance(palette[@"bubbleMine"]) < 0.55f
			? [UIColor whiteColor] : TGClassicThemeRoleColours()[@"text"];

	if (settings[@"outgoing_message_accent_color"])
		palette[@"outgoingAccent"] = TGStoreColour(
				settings[@"outgoing_message_accent_color"]);

	NSDictionary *background = settings[@"background"];
	NSDictionary *type = [background[@"type"] isKindOfClass:NSDictionary.class]
			? background[@"type"] : nil;
	NSDictionary *backgroundFill = TGStoreFill(type[@"fill"]);
	if (!backgroundFill)
		backgroundFill = TGStoreFill(background[@"fill"]);
	if (backgroundFill){
		palette[@"wallpaperFill"] = backgroundFill;
		palette[@"wallpaper"] = [backgroundFill[@"colors"] firstObject] ?: accent;
	} else {
		palette[@"wallpaper"] = accent;
	}
	palette[@"chatBackground"] = palette[@"wallpaper"];

	NSNumber *patternFileId = TGStoreFileIdFromDocument(background[@"document"]);
	if (patternFileId)
		palette[@"patternFileId"] = patternFileId;
	NSNumber *intensity = type[@"intensity"];
	palette[@"patternIntensity"] = [intensity isKindOfClass:NSNumber.class]
			? intensity : @(TGStorePatternIntensityDefault);
	palette[@"patternInverted"] = @([type[@"is_inverted"] boolValue]);

	TGStoreApplyBaseIncoming(palette, dark);

	// Night Mode paints the whole client from the dark base theme, not only
	// the chat. Without these roles a dark emoji theme would keep Classic's
	// white settings cards under white text.
	if (dark){
		UIColor *bar = TGStoreColour(@0x17212b);
		UIColor *paper = TGStoreColour(@0x0e1621);
		UIColor *card = TGStoreColour(@0x17212b);
		UIColor *field = TGStoreColour(@0x232e3c);
		UIColor *muted = TGStoreColour(@0x708499);
		palette[@"bar"] = bar;
		palette[@"barTitle"] = [UIColor whiteColor];
		palette[@"barSubtitle"] = muted;
		palette[@"barButton"] = accent;
		palette[@"tabBar"] = bar;
		palette[@"listBackground"] = bar;
		palette[@"groupedBackground"] = paper;
		palette[@"cardBackground"] = card;
		palette[@"primaryText"] = [UIColor whiteColor];
		palette[@"secondaryText"] = muted;
		palette[@"separator"] = paper;
		palette[@"inputBar"] = bar;
		palette[@"inputField"] = field;
		palette[@"searchBarBackground"] = bar;
		palette[@"service"] = field;
		palette[@"serviceText"] = [UIColor whiteColor];
	}
	return palette;
}

+ (BOOL)recordHasDarkVariant:(NSDictionary *)record {
	if (![record isKindOfClass:NSDictionary.class])
		return NO;
	NSDictionary *settings = record[@"dark_settings"];
	if (![settings isKindOfClass:NSDictionary.class] || !settings.count)
		return NO;
	return [self paletteFromThemeSettings:settings darkHint:YES].count > 0;
}

+ (NSDictionary *)paletteForThemeRecord:(NSDictionary *)record dark:(BOOL)dark {
	if (![record isKindOfClass:NSDictionary.class])
		return nil;
	NSDictionary *settings = dark ? record[@"dark_settings"] : record[@"light_settings"];
	if (![settings isKindOfClass:NSDictionary.class] || !settings.count)
		settings = record[@"light_settings"];
	return [self paletteFromThemeSettings:settings darkHint:dark];
}

+ (NSArray *)parseThemes:(NSArray *)records {
	NSMutableArray *themes = [NSMutableArray array];
	if (![records isKindOfClass:NSArray.class])
		return themes;
	for (NSDictionary *record in records){
		if (![record isKindOfClass:NSDictionary.class])
			continue;
		NSString *name = record[@"name"];
		if (![name isKindOfClass:NSString.class] || !name.length)
			continue;
		NSDictionary *light = [self paletteForThemeRecord:record dark:NO];
		if (!light.count)
			continue;
		NSDictionary *dark = [self paletteForThemeRecord:record dark:YES];
		BOOL hasDark = [self recordHasDarkVariant:record] && dark.count > 0;
		NSMutableDictionary *entry = [@{
			@"id"      : TGChatThemeIdForName(name),
			@"name"    : name,
			@"emoji"   : @YES,
			@"light"   : light,
			@"hasDark" : @(hasDark),
		} mutableCopy];
		if (hasDark)
			entry[@"dark"] = dark;
		[themes addObject:entry];
	}
	return themes;
}

#pragma mark - the store

+ (TGChatThemeStore *)shared {
	static TGChatThemeStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ store = [[TGChatThemeStore alloc] init]; });
	return store;
}

- (id)init {
	self = [super init];
	if (!self)
		return nil;
	_patternCache = [[NSCache alloc] init];
	_patternDataCache = [[NSCache alloc] init];
	_wallpaperCache = [[NSCache alloc] init];
	_requestedPatterns = [NSMutableSet set];
	_pendingWallpapers = [NSMutableSet set];
	// 32-bit budget: masks 1 MB, pattern documents 1 MB, baked wallpapers
	// 6 MB, the two Settings caches 3 MB each and the background store's 2 MB.
	// Sixteen megabytes in total.
	NSUInteger limit = sizeof(void *) == 4 ? 6 * 1024 * 1024 : 64 * 1024 * 1024;
	_patternCache.totalCostLimit = sizeof(void *) == 4
			? 4 * 1024 * 1024 : 16 * 1024 * 1024;
	_patternDataCache.totalCostLimit = sizeof(void *) == 4
			? 1 * 1024 * 1024 : 16 * 1024 * 1024;
	_wallpaperCache.totalCostLimit = limit;
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(appearanceChanged:)
				name:TGAppearanceDefaultsChangedNotification object:nil];
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appearanceChanged:(NSNotification *)note {
	// The records arrive on the receive thread; the list is only read on the
	// main queue, so the invalidation is handed there too.
	dispatch_async(dispatch_get_main_queue(), ^{
		self->_themes = nil;
		[self postChangedSoon];
	});
}

- (NSArray *)themes {
	if (_themes)
		return _themes;
	_themes = [[self class] parseThemes:[TGClient shared].emojiChatThemes];
	return _themes;
}

- (NSDictionary *)themeNamed:(NSString *)name {
	if (!name.length)
		return nil;
	for (NSDictionary *entry in [self themes])
		if ([entry[@"name"] isEqualToString:name])
			return entry;
	return nil;
}

- (BOOL)themeNamedHasDarkVariant:(NSString *)name {
	return [[self themeNamed:name][@"hasDark"] boolValue];
}

- (NSString *)currentThemeName {
	return [NSUserDefaults.standardUserDefaults stringForKey:TGSettingsEmojiThemeKey];
}

- (void)setCurrentThemeName:(NSString *)name {
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	if (name.length)
		[defaults setObject:name forKey:TGSettingsEmojiThemeKey];
	else
		[defaults removeObjectForKey:TGSettingsEmojiThemeKey];
	[defaults synchronize];
}

- (void)clearCurrentThemeName {
	[self setCurrentThemeName:nil];
}

- (NSDictionary *)paletteForThemeNamed:(NSString *)name dark:(BOOL)dark {
	return [self paletteForEntry:[self themeNamed:name] dark:dark];
}

- (NSDictionary *)paletteForEntry:(NSDictionary *)entry dark:(BOOL)dark {
	if (![entry isKindOfClass:NSDictionary.class])
		return nil;
	NSDictionary *palette = TGChatThemeSettingsForMode(entry, dark);
	return palette.count ? palette : nil;
}

#pragma mark - pattern documents

- (UIImage *)patternImageForThemeNamed:(NSString *)name dark:(BOOL)dark {
	NSDictionary *palette = [self paletteForThemeNamed:name dark:dark];
	NSNumber *fileId = palette[@"patternFileId"];
	if (![fileId isKindOfClass:NSNumber.class] || fileId.longLongValue <= 0)
		return nil;
	return [self patternImageForFileId:fileId];
}

- (UIImage *)patternImageForFileId:(NSNumber *)fileId {
	UIImage *cached = [_patternCache objectForKey:fileId];
	if (cached)
		return cached;
	if ([_requestedPatterns containsObject:fileId])
		return nil;
	[_requestedPatterns addObject:fileId];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:fileId.integerValue
			priority:TGDownloadPriorityOnScreen
			completion:^(NSString *path){
		TGChatThemeStore *me = weakSelf;
		if (!me)
			return;
		[me->_requestedPatterns removeObject:fileId];
		if (!path.length)
			return;
		[me decodePatternAtPath:path fileId:fileId];
	}];
	return nil;
}

#if TARGET_OS_IPHONE

/// A .tgv starts with gzip's magic; a fixture may hand over the SVG itself.
static BOOL TGStoreDataIsTGPattern(NSData *data) {
	if (data.length < 4)
		return NO;
	const uint8_t *bytes = data.bytes;
	if (bytes[0] == 0x1f && bytes[1] == 0x8b)
		return YES;
	return bytes[0] == '<' && bytes[1] == 's' && bytes[2] == 'v' &&
			bytes[3] == 'g';
}

- (void)decodePatternAtPath:(NSString *)path fileId:(NSNumber *)fileId {
	__weak typeof(self) weakSelf = self;
	dispatch_async(TGPatternWorkQueue(), ^{
		TGChatThemeStore *me = weakSelf;
		if (!me)
			return;
		NSString *diskName = [NSString stringWithFormat:@"mask-%@-%.0f",
				fileId, TGStorePatternSide];
		UIImage *stored = TGStoreDiskImage(diskName);
		if (stored){
			dispatch_async(dispatch_get_main_queue(), ^{
				[me cachePattern:stored fileId:fileId];
			});
			return;
		}
		NSData *data = [NSData dataWithContentsOfFile:path];
		if (data.length && TGStoreDataIsTGPattern(data)){
			NSData *unpacked = TGPatternGunzip(data);
			if (unpacked.length)
				[me->_patternDataCache setObject:unpacked forKey:fileId
										 cost:unpacked.length];
			CGImageRef mask = TGPatternCreateMask(data,
					CGSizeMake(TGStorePatternSide, TGStorePatternSide));
			UIImage *image = mask ? [UIImage imageWithCGImage:mask] : nil;
			if (mask)
				CGImageRelease(mask);
			TGStoreDiskWrite(image, diskName);
			if (image){
				dispatch_async(dispatch_get_main_queue(), ^{
					[me cachePattern:image fileId:fileId];
				});
				return;
			}
		}

		UIImage *image = data.length ? [UIImage imageWithData:data] : nil;
		if (image){
			dispatch_async(dispatch_get_main_queue(), ^{
				[me cachePattern:image fileId:fileId];
			});
			return;
		}
		if (![path.pathExtension.lowercaseString isEqualToString:@"tgs"])
			return;

		void (^render)(NSString *, CGFloat, void (^)(UIImage *)) = me.tgsPatternRenderer;
		if (!render)
			return;
		dispatch_async(dispatch_get_main_queue(), ^{
			render(path, TGStorePatternSide, ^(UIImage *snapshot){
				if (snapshot)
					[me cachePattern:snapshot fileId:fileId];
			});
		});
	});
}



/// The fill alone, for the first frame before the pattern mask is ready and
/// for a theme that has no pattern document at all.
- (UIImage *)fillWallpaperForPalette:(NSDictionary *)palette
								size:(CGSize)size
								 key:(NSString *)key {
	NSString *fillKey = [key stringByAppendingString:@"|fill"];
	UIImage *cached = [_wallpaperCache objectForKey:fillKey];
	if (cached)
		return cached;
	NSDictionary *fill = palette[@"wallpaperFill"];
	CGImageRef fillImage = TGPatternCreateFill(size,
			TGStoreWallpaperColours(palette), fill[@"kind"],
			[fill[@"angle"] doubleValue]);
	UIImage *image = fillImage ? [UIImage imageWithCGImage:fillImage] : nil;
	if (fillImage)
		CGImageRelease(fillImage);
	if (image){
		NSUInteger cost = (NSUInteger)(size.width * size.height * 4);
		[_wallpaperCache setObject:image forKey:fillKey cost:cost];
	}
	return image;
}

- (UIImage *)cardWallpaperForThemeNamed:(NSString *)name
								   dark:(BOOL)dark
								   size:(CGSize)size {
	if (size.width <= 0 || size.height <= 0)
		return nil;
	NSDictionary *palette = [self paletteForThemeNamed:name dark:dark];
	if (!palette)
		return nil;
	NSDictionary *fill = palette[@"wallpaperFill"];
	NSNumber *intensityNumber = palette[@"patternIntensity"];
	UIImage *pattern = [self patternImageForThemeNamed:name dark:dark];
	CGImageRef composite = TGPatternCreateWallpaper(size,
			TGStoreWallpaperColours(palette), fill[@"kind"],
			[fill[@"angle"] doubleValue], pattern.CGImage,
			fabs([intensityNumber doubleValue]) / 100.0f,
			[palette[@"patternInverted"] boolValue] ||
					[intensityNumber doubleValue] < 0);
	UIImage *image = composite ? [UIImage imageWithCGImage:composite] : nil;
	if (composite)
		CGImageRelease(composite);
	return image;
}

- (UIImage *)wallpaperForThemeNamed:(NSString *)name
							   dark:(BOOL)dark
							   size:(CGSize)size {
	if (size.width <= 0 || size.height <= 0)
		return nil;
	NSDictionary *palette = [self paletteForThemeNamed:name dark:dark];
	if (!palette)
		return nil;
	NSNumber *fileId = palette[@"patternFileId"];
	NSData *patternData = [fileId isKindOfClass:NSNumber.class]
			? [_patternDataCache objectForKey:fileId] : nil;
	UIImage *patternMask = [fileId isKindOfClass:NSNumber.class]
			? [self patternImageForFileId:fileId] : nil;
	NSString *key = [NSString stringWithFormat:@"%@|%d|%.0fx%.0f|%lu", name,
			dark, size.width, size.height,
			(unsigned long)(patternData ? patternData.hash : patternMask.hash)];
	UIImage *cached = [_wallpaperCache objectForKey:key];
	if (cached)
		return cached;

	NSDictionary *fill = palette[@"wallpaperFill"];
	NSNumber *intensityNumber = palette[@"patternIntensity"];
	CGFloat intensity = fabs([intensityNumber doubleValue]) / 100.0f;
	BOOL inverted = [palette[@"patternInverted"] boolValue] ||
			[intensityNumber doubleValue] < 0;
	BOOL hasPattern = patternData.length > 0 || patternMask != nil;

	if (hasPattern && ![_pendingWallpapers containsObject:key]){
		[_pendingWallpapers addObject:key];
		__weak typeof(self) weakSelf = self;
		dispatch_async(TGPatternWorkQueue(), ^{
			TGChatThemeStore *me = weakSelf;
			if (!me)
				return;
			NSString *diskName = [NSString stringWithFormat:@"wall-%lu",
					(unsigned long)key.hash];
			UIImage *stored = TGStoreDiskImage(diskName);
			if (stored){
				dispatch_async(dispatch_get_main_queue(), ^{
					[me->_pendingWallpapers removeObject:key];
					NSUInteger cost = (NSUInteger)(size.width * size.height * 4);
					[me->_wallpaperCache setObject:stored forKey:key cost:cost];
					[me postChangedSoon];
				});
				return;
			}
			CGImageRef mask = patternData.length
					? TGPatternCreateMask(patternData, size)
					: CGImageRetain(patternMask.CGImage);
			CGImageRef composite = TGPatternCreateWallpaper(size,
					TGStoreWallpaperColours(palette), fill[@"kind"],
					[fill[@"angle"] doubleValue], mask, intensity, inverted);
			if (mask)
				CGImageRelease(mask);
			UIImage *image = composite ? [UIImage imageWithCGImage:composite] : nil;
			if (composite)
				CGImageRelease(composite);
			TGStoreDiskWrite(image, diskName);
			dispatch_async(dispatch_get_main_queue(), ^{
				[me->_pendingWallpapers removeObject:key];
				if (!image)
					return;
				NSUInteger cost = (NSUInteger)(size.width * size.height * 4);
				[me->_wallpaperCache setObject:image forKey:key cost:cost];
				[me postChangedSoon];
			});
		});
	}

	UIImage *image = [self fillWallpaperForPalette:palette size:size key:key];
	if (![fileId isKindOfClass:NSNumber.class] && image){
		NSUInteger cost = (NSUInteger)(size.width * size.height * 4);
		[_wallpaperCache setObject:image forKey:key cost:cost];
	}
	return image;
}

- (void)cachePattern:(UIImage *)image fileId:(NSNumber *)fileId {
	NSUInteger cost = (NSUInteger)(image.size.width * image.size.height * 4);
	[_patternCache setObject:image forKey:fileId cost:cost];
	[self postChangedSoon];
}

#else

- (void)decodePatternAtPath:(NSString *)path fileId:(NSNumber *)fileId {
	(void)path;
	(void)fileId;
}

- (UIImage *)wallpaperForThemeNamed:(NSString *)name
							   dark:(BOOL)dark
							   size:(CGSize)size {
	(void)name;
	(void)dark;
	(void)size;
	return nil;
}

- (UIImage *)cardWallpaperForThemeNamed:(NSString *)name
								   dark:(BOOL)dark
								   size:(CGSize)size {
	(void)name;
	(void)dark;
	(void)size;
	return nil;
}

#endif

/// Every finished bake used to post at once, and each post repainted the
/// page, which asked for images again; a cache eviction then restarted the
/// cycle. One post per 0.1 s is all a repaint needs.
- (void)postChangedSoon {
	if (_changePosted)
		return;
	_changePosted = YES;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
		self->_changePosted = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:TGChatThemeStoreChangedNotification object:self];
	});
}

@end

// vim:ft=objc
