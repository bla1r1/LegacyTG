#import "TGTheme.h"
#import "TGThemeFile.h"
#import <objc/runtime.h>
#import "TGIcons.h"
#import "TGThemeInternal.h"
#import "TGStyle.h"
#import "TGThemeList.h"
#import "TGChatThemeStore.h"

#define rgb TGThemeRGB

NSString *const TGThemeChangedNotification = @"TGThemeChanged";

static NSString *const kImportKey = @"themeImportPath";
static NSString *const kFontKey   = @"messageFontSize";

static NSString *const kWallpaperTypeKey = @"themeWallpaperType";
static const NSTimeInterval kAutoNightCheckInterval = 60.0;

@implementation TGTheme {
	NSDictionary *_imported;
	UIImage *_wallpaper;
	UIImage *_themeWallpaper;
}

+ (instancetype)shared {
	static TGTheme *s = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ s = [[TGTheme alloc] init]; });
	return s;
}

+ (BOOL)drawsSkeuomorphicChrome {
	static BOOL draws;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		draws = NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_6_1;
	});
	return draws;
}

/// A theme's wallpaper is a colour with Telegram's doodle sheet over it. The
/// official client bakes the same two layers; doing it once keeps the chat's
/// scrolling layer free of blends.
static UIImage *TGThemeWallpaperImage(UIColor *colour, BOOL dark) {
	UIImage *pattern = [UIImage imageNamed:@"builtin-wallpaper-0.jpg"];
	if (!pattern || pattern.size.width <= 0 || pattern.size.height <= 0)
		return nil;
	CGSize size = pattern.size;
	UIGraphicsBeginImageContextWithOptions(size, YES, 1);
	CGRect rect = CGRectMake(0, 0, size.width, size.height);
	[colour setFill];
	UIRectFill(rect);
	[pattern drawInRect:rect
			  blendMode:(dark ? kCGBlendModeScreen : kCGBlendModeNormal)
				  alpha:TGAlphaOpaque];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

- (id)init {
	self = [super init];
	if (!self)
		return nil;

	// A theme file, light or dark, survives a launch as the current theme.
	NSString *imported = [NSUserDefaults.standardUserDefaults stringForKey:kImportKey];
	if (imported.length)
		[self loadImportedTheme:[TGTheme pathInDocuments:imported]];

	// Auto-Night has to fire even when Settings is not open, so the theme
	// observes foregrounding itself and checks once a minute while running.
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(refreshAutoNightMode)
				name:UIApplicationDidBecomeActiveNotification object:nil];
	// A pattern file finishes after the theme list was drawn; the baked
	// wallpaper has to be thrown away when the document behind it arrives.
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(chatThemeStoreChanged)
				name:TGChatThemeStoreChangedNotification object:nil];
	NSTimer *timer = [NSTimer timerWithTimeInterval:kAutoNightCheckInterval
			target:self selector:@selector(refreshAutoNightMode)
			userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
	[self refreshAutoNightMode];
	return self;
}

#pragma mark - the theme list

+ (NSArray *)availableThemes {
	NSMutableArray *files = [NSMutableArray array];
	for (NSString *path in [self availableThemeFiles]){
		NSString *name = nil;
		NSDictionary *p = [TGThemeFile paletteFromFile:path name:&name];
		if (!name.length)
			name = [path.lastPathComponent stringByDeletingPathExtension];
		BOOL dark = [p[@"isDark"] boolValue];
		[files addObject:@{
			@"id"   : [@"file:" stringByAppendingString:path.lastPathComponent],
			@"name" : name,
			@"dark" : @(dark),
			@"path" : path,
		}];
	}
	return TGSettingsThemeList(files);
}

/// The role colours and card geometry for one availableThemes entry. The
/// resolver lives in TGThemeFile so the host tests can read a Classic and a
/// file card without a live theme.
+ (NSDictionary *)cardPaletteForThemeEntry:(NSDictionary *)entry {
	return [TGThemeFile cardPaletteForThemeEntry:entry];
}

- (NSString *)currentThemeId {
	NSString *emoji = [TGChatThemeStore shared].currentThemeName;
	if (emoji.length)
		return TGChatThemeIdForName(emoji);
	NSString *imported = [NSUserDefaults.standardUserDefaults stringForKey:kImportKey];
	if (_imported && imported.length)
		return [@"file:" stringByAppendingString:imported];
	return @"classic";
}

- (void)chatThemeStoreChanged {
	if (![TGChatThemeStore shared].currentThemeName.length)
		return;
	_themeWallpaper = nil;
	[self themeChanged];
}

- (NSString *)nightThemeId {
	return TGSettingsNightThemeId(NSUserDefaults.standardUserDefaults,
			[[self class] availableThemes]);
}

- (BOOL)isNightModeEnabled {
	return TGSettingsNightModeEnabled(NSUserDefaults.standardUserDefaults);
}

/// Night Mode does not change the palette by itself: it selects the dark theme
/// the user chose and remembers the light one. Picking a theme while it is on
/// updates that choice; picking a light theme turns the mode off.
- (void)setNightModeEnabled:(BOOL)enabled {
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;

	// An emoji theme carries both variants itself. Night Mode flips to the
	// dark settings of that theme; it must not swap in Night Blue behind it.
	if ([TGChatThemeStore shared].currentThemeName.length){
		[defaults setBool:enabled forKey:TGSettingsNightModeKey];
		[defaults synchronize];
		_themeWallpaper = nil;
		[self themeChanged];
		return;
	}

	NSArray *themes = [[self class] availableThemes];
	if (enabled){
		NSString *night = TGSettingsNightThemeId(defaults, themes);
		if (!night.length)
			return;
		NSString *day = [self currentThemeId];
		if (day.length && !TGSettingsThemeIsDark(themes, day))
			[defaults setObject:day forKey:TGSettingsDayThemeKey];
		[defaults setBool:YES forKey:TGSettingsNightModeKey];
		[defaults synchronize];
		if (![night isEqualToString:[self currentThemeId]])
			[self selectThemeId:night];
		else
			[self themeChanged];
		return;
	}

	[defaults setBool:NO forKey:TGSettingsNightModeKey];
	[defaults synchronize];
	NSString *day = TGSettingsDayThemeId(defaults, themes);
	if (![day isEqualToString:[self currentThemeId]])
		[self selectThemeId:day];
	else
		[self themeChanged];
}

- (void)refreshAutoNightMode {
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	if (TGSettingsAutoNightMode(defaults) != TGSettingsAutoNightModeScheduled)
		return;
	NSInteger from = TGSettingsAutoNightMinute(defaults,
			TGSettingsAutoNightFromKey, TGSettingsAutoNightDefaultFrom);
	NSInteger to = TGSettingsAutoNightMinute(defaults,
			TGSettingsAutoNightToKey, TGSettingsAutoNightDefaultTo);
	BOOL dark = TGSettingsAutoNightShouldBeDark(
			TGSettingsMinuteOfDay([NSDate date]), from, to);
	if (dark != [self isNightModeEnabled])
		[self setNightModeEnabled:dark];
}

- (BOOL)selectThemeId:(NSString *)themeId {
	if (![themeId isKindOfClass:NSString.class] || !themeId.length)
		return NO;

	if (TGChatThemeIdIsEmoji(themeId)){
		NSString *name = TGChatThemeNameFromId(themeId);
		TGChatThemeStore *store = [TGChatThemeStore shared];
		if (!name.length || (store.themes.count && ![store themeNamed:name]))
			return NO;
		[store setCurrentThemeName:name];
		_imported = nil;
		_importedName = nil;
		_themeWallpaper = nil;
		[NSUserDefaults.standardUserDefaults removeObjectForKey:kImportKey];
	} else if ([themeId hasPrefix:@"file:"]){
		NSString *name = [themeId substringFromIndex:5];
		if (![self loadImportedTheme:[TGTheme pathInDocuments:name]])
			return NO;
		[[TGChatThemeStore shared] clearCurrentThemeName];
		[NSUserDefaults.standardUserDefaults setObject:name forKey:kImportKey];
	} else {
		// Anything else is Classic: clear the imported file.
		[[TGChatThemeStore shared] clearCurrentThemeName];
		_imported = nil;
		_importedName = nil;
		_themeWallpaper = nil;
		[NSUserDefaults.standardUserDefaults removeObjectForKey:kImportKey];
	}

	// A theme carries its own wall. Selecting it makes that the chat
	// background again, dropping a photo or texture chosen for the old theme.
	_wallpaper = nil;
	[NSUserDefaults.standardUserDefaults setInteger:TGWallpaperTypeNone
											 forKey:kWallpaperTypeKey];

	if (TGChatThemeIdIsEmoji(themeId)){
		// The emoji theme owns both day and night variants; the base theme
		// keys keep pointing at whatever base was last chosen for later.
		[NSUserDefaults.standardUserDefaults synchronize];
		[self themeChanged];
		return YES;
	}

	// Keep the two Night Mode choices pointing at the theme that is in use:
	// a dark theme is what Night Mode will apply, a light one is what it
	// returns to. Picking a light theme while Night Mode is on turns it off.
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	NSArray *themes = [[self class] availableThemes];
	BOOL dark = TGSettingsThemeIsDark(themes, themeId);
	if (dark)
		[defaults setObject:themeId forKey:TGSettingsNightThemeKey];
	else
		[defaults setObject:themeId forKey:TGSettingsDayThemeKey];
	if (!dark && TGSettingsNightModeEnabled(defaults))
		[defaults setBool:NO forKey:TGSettingsNightModeKey];
	[defaults synchronize];
	[self themeChanged];
	return YES;
}

- (void)themeChanged {
	[[NSNotificationCenter defaultCenter] postNotificationName:TGThemeChangedNotification
													   object:nil];
}

- (CGFloat)messageFontSize {
	CGFloat stored = [NSUserDefaults.standardUserDefaults floatForKey:kFontKey];
	return stored > 0 ? stored : 15.0f;
}

- (void)setMessageFontSize:(CGFloat)size {
	[NSUserDefaults.standardUserDefaults setFloat:size forKey:kFontKey];
	[NSUserDefaults.standardUserDefaults synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:TGThemeChangedNotification
													   object:nil];
}

#pragma mark - imported themes

// Store file name only to survive container path changes across reinstall
- (BOOL)importThemeAtPath:(NSString *)path {
	return [self selectThemeId:
			[@"file:" stringByAppendingString:path.lastPathComponent]];
}

+ (NSString *)pathInDocuments:(NSString *)name {
	NSString *documents = [NSSearchPathForDirectoriesInDomains(
			NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	NSString *docPath = [documents stringByAppendingPathComponent:name.lastPathComponent];
	if ([[NSFileManager defaultManager] fileExistsAtPath:docPath])
		return docPath;
	NSString *bundle = [[NSBundle mainBundle] bundlePath];
	NSString *bundlePath = [bundle stringByAppendingPathComponent:name.lastPathComponent];
	if ([[NSFileManager defaultManager] fileExistsAtPath:bundlePath])
		return bundlePath;
	return docPath;
}

- (BOOL)loadImportedTheme:(NSString *)path {
	NSString *name = nil;
	NSDictionary *palette = [TGThemeFile paletteFromFile:path name:&name];
	if (!palette)
		palette = [TGThemeFile chatPaletteFromFile:path name:&name];
	if (!palette)
		return NO;
	_imported = palette;
	_importedName = name;
	_themeWallpaper = nil;
	_wallpaper = nil;
	return YES;
}

- (void)clearImportedTheme {
	[self selectThemeId:@"classic"];
}

+ (NSArray *)availableThemeFiles {
	NSMutableArray *found = [NSMutableArray array];
	NSString *documents = [NSSearchPathForDirectoriesInDomains(
			NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	for (NSString *entry in [[NSFileManager defaultManager]
			contentsOfDirectoryAtPath:documents error:nil]){
		NSString *path = [documents stringByAppendingPathComponent:entry];
		if ([TGThemeFile handlesFile:path])
			[found addObject:path];
	}
	NSString *bundle = [[NSBundle mainBundle] bundlePath];
	for (NSString *entry in [[NSFileManager defaultManager]
			contentsOfDirectoryAtPath:bundle error:nil]){
		NSString *path = [bundle stringByAppendingPathComponent:entry];
		if ([TGThemeFile handlesFile:path] && ![found containsObject:path])
			[found addObject:path];
	}
	return found;
}

- (UIColor *)importedColour:(NSString *)key {
	NSString *emoji = [TGChatThemeStore shared].currentThemeName;
	if (emoji.length){
		NSDictionary *palette = [[TGChatThemeStore shared]
				paletteForThemeNamed:emoji dark:[self isNightModeEnabled]];
		UIColor *colour = palette[key];
		if ([colour isKindOfClass:UIColor.class])
			return colour;
	}
	return _imported[key];
}

- (BOOL)isDark {
	NSString *emoji = [TGChatThemeStore shared].currentThemeName;
	if (emoji.length){
		NSDictionary *palette = [[TGChatThemeStore shared]
				paletteForThemeNamed:emoji dark:[self isNightModeEnabled]];
		if (palette)
			return [palette[@"isDark"] boolValue];
		return [self isNightModeEnabled];
	}
	return [_imported[@"isDark"] boolValue];
}

+ (UITableViewCell *)systemCellOfStyle:(UITableViewCellStyle)style {
	static UITableViewCell *cells[4];
	if (style < 0 || style > 3)
		style = UITableViewCellStyleDefault;
	if (!cells[style])
		cells[style] = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:nil];
	return cells[style];
}

- (void)styleCell:(UITableViewCell *)cell {
	// UIKit's own cell: its fonts and colours, and labels it can highlight -
	// opaque white ones showed as boxes on the blue selection.
	UITableViewCell *system = [TGTheme systemCellOfStyle:UITableViewCellStyleValue1];
	cell.textLabel.font = system.textLabel.font;
	cell.detailTextLabel.font = system.detailTextLabel.font;
	cell.textLabel.backgroundColor = [UIColor clearColor];
	cell.detailTextLabel.backgroundColor = [UIColor clearColor];
	cell.textLabel.opaque = NO;
	cell.detailTextLabel.opaque = NO;
	cell.selectedBackgroundView = nil;

	if ([self isDark]) {
		cell.backgroundColor = [self cardBackgroundColour];
		cell.contentView.backgroundColor = [self cardBackgroundColour];
		cell.textLabel.textColor = [self primaryTextColour];
		cell.detailTextLabel.textColor = [self cellDetailColour];
		UIView *sel = [[UIView alloc] init];
		sel.backgroundColor = [self inputBarColour];
		cell.selectedBackgroundView = sel;
		if (cell.backgroundView)
			cell.backgroundView.backgroundColor = [self cardBackgroundColour];
	} else {
		cell.backgroundColor = nil;
		cell.contentView.backgroundColor = nil;
		cell.textLabel.textColor = system.textLabel.textColor;
		cell.detailTextLabel.textColor = system.detailTextLabel.textColor;
		cell.selectedBackgroundView = nil;
	}
}

/// A search bar as the OS draws one: grey on iOS 6, light on 7, nothing of
/// ours painted on it. A dark or imported theme gets the black style and
/// its own colours.
- (void)styleSearchBar:(UISearchBar *)bar {
	if (!bar)
		return;
	if ([bar respondsToSelector:@selector(setBackgroundImage:)])
		[bar setBackgroundImage:nil];
	if ([self isDark]) {
		bar.barStyle = UIBarStyleBlack;
		bar.tintColor = [self accentColour];
		if ([bar respondsToSelector:@selector(setBarTintColor:)])
			bar.barTintColor = [self searchBarBackgroundColour];
		bar.backgroundColor = [self listBackgroundColour];
	} else {
		bar.barStyle = UIBarStyleDefault;
		bar.tintColor = nil;
		if ([bar respondsToSelector:@selector(setBarTintColor:)])
			bar.barTintColor = nil;
		bar.backgroundColor = nil;
	}
}

/// A grouped table as UIKit draws it on the OS it runs on - iOS 6's
/// pinstripes and rounded cards, iOS 7's grey sheet - with only the colours
/// changed on a dark or imported theme.
- (void)styleGroupedTable:(UITableView *)table {
	table.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	if ([self isDark]) {
		table.backgroundColor = [self groupedBackgroundColour];
		UIView *bg = [[UIView alloc] initWithFrame:table.bounds];
		bg.backgroundColor = [self groupedBackgroundColour];
		table.backgroundView = bg;
		table.separatorColor = [self separatorColour];
	} else {
		table.backgroundColor = [self groupedBackgroundColour];
		table.backgroundView = nil;
		table.separatorColor = nil;
	}
}

- (void)stylePlainTable:(UITableView *)table {
	if ([self isDark]) {
		table.backgroundColor = [self listBackgroundColour];
		UIView *bg = [[UIView alloc] initWithFrame:table.bounds];
		bg.backgroundColor = [self listBackgroundColour];
		table.backgroundView = bg;
		table.separatorColor = [self separatorColour];
		if ([table respondsToSelector:@selector(setSectionIndexColor:)])
			table.sectionIndexColor = [self accentColour];
		// iOS 6 has sectionIndexColor but not the background/tracking pair.
		if ([table respondsToSelector:@selector(setSectionIndexBackgroundColor:)])
			table.sectionIndexBackgroundColor = [UIColor clearColor];
		if ([table respondsToSelector:@selector(setSectionIndexTrackingBackgroundColor:)])
			table.sectionIndexTrackingBackgroundColor = [self listBackgroundColour];
	} else {
		table.backgroundColor = [self listBackgroundColour];
		table.backgroundView = nil;
		table.separatorColor = [self separatorColour];
	}
}

- (void)styleHeaderFooterView:(UIView *)view {
	if (!view)
		return;
	if ([self isDark]) {
		UIColor *bg = [self groupedBackgroundColour];
		if ([view respondsToSelector:@selector(contentView)]) {
			UIView *cv = [(id)view contentView];
			cv.backgroundColor = bg;
		}
		if ([view respondsToSelector:@selector(backgroundView)]) {
			UIView *bv = [(id)view backgroundView];
			bv.backgroundColor = bg;
		}
		view.backgroundColor = bg;
		if ([view respondsToSelector:@selector(textLabel)]) {
			UILabel *label = [(id)view textLabel];
			label.textColor = [self sectionHeaderColour];
			label.backgroundColor = [UIColor clearColor];
		}
	}
}

static char kTabOnMaskKey;
static char kTabStyleKey;
static char kTabOffMaskKey;

- (void)styleTabBar:(UITabBar *)bar {
	if (!bar)
		return;
	// Launch styled the same bar three times (root build, chat list load and
	// appear), re-tinting every glyph each time: 92 ms on an A5. Same theme,
	// same items: nothing to repaint.
	NSMutableString *signature = [NSMutableString stringWithFormat:@"%@|%d",
			[self currentThemeId], [self isDark]];
	for (UITabBarItem *item in bar.items)
		[signature appendFormat:@"|%p", item];
	if ([objc_getAssociatedObject(bar, &kTabStyleKey) isEqualToString:signature])
		return;
	objc_setAssociatedObject(bar, &kTabStyleKey, signature,
			OBJC_ASSOCIATION_COPY_NONATOMIC);

	UIColor *barBg = [self importedColour:@"tabBar"] ?: [self barColour];
	UIColor *on = [self isDark] ? [self accentColour] : [UIColor whiteColor];
	UIColor *off = [UIColor colorWithWhite:1.0f alpha:TGAlphaSecondary];

	// iOS <= 6 keeps the native skeuomorphic glossy tab bar tinted to the theme; iOS 7+ sets barTintColor.
	if ([TGTheme drawsSkeuomorphicChrome]) {
		bar.tintColor = barBg;
		if ([bar respondsToSelector:@selector(setBackgroundImage:)])
			bar.backgroundImage = nil;
		if ([bar respondsToSelector:@selector(setSelectionIndicatorImage:)])
			bar.selectionIndicatorImage = nil;
		if ([bar respondsToSelector:@selector(setSelectedImageTintColor:)])
			bar.selectedImageTintColor = [self accentColour];
	} else if ([bar respondsToSelector:@selector(setBarTintColor:)]) {
		bar.translucent = NO;      // see -styleNavigationBar:
		bar.barTintColor = barBg;
		bar.tintColor = on;
		if ([bar respondsToSelector:@selector(setBackgroundImage:)])
			bar.backgroundImage = nil;
		if ([bar respondsToSelector:@selector(setSelectionIndicatorImage:)])
			bar.selectionIndicatorImage = nil;
	} else {
		bar.tintColor = barBg;
		if ([bar respondsToSelector:@selector(setBackgroundImage:)])
			bar.backgroundImage = nil;
	}

	// On the tinted bar the system's grey glyphs went dark/gray; they are drawn
	// white instead - full for the selected tab, faded for the rest.
	for (UITabBarItem *item in bar.items) {
		// The masks are the glyphs the item was made with, kept on first use.
		// Re-reading item.image took the faded copy painted last time as the
		// next mask, so every theme change multiplied the alpha again (0.75,
		// 0.56, 0.42 ...) and the unselected tabs faded away.
		UIImage *onMask = objc_getAssociatedObject(item, &kTabOnMaskKey);
		UIImage *offMask = objc_getAssociatedObject(item, &kTabOffMaskKey);
		if (!onMask && !offMask) {
			if (item.tag == 0) {
				onMask = [TGIcons chats];
				offMask = [TGIcons chatsOutline];
			} else if (item.tag == 1) {
				onMask = [TGIcons contacts];
				offMask = [TGIcons contactsOutline];
			} else if (item.tag == 2) {
				onMask = [TGIcons settings];
				offMask = [TGIcons settingsOutline];
			} else if (item.tag == 3) {
				onMask = [TGIcons calls];
				offMask = [TGIcons calls];
			} else {
				if ([item respondsToSelector:@selector(selectedImage)])
					onMask = item.selectedImage;
				if (!onMask)
					onMask = item.image;
				offMask = item.image ?: onMask;
			}
			if (onMask)
				objc_setAssociatedObject(item, &kTabOnMaskKey, onMask,
						OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			if (offMask)
				objc_setAssociatedObject(item, &kTabOffMaskKey, offMask,
						OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}

		if ([TGTheme drawsSkeuomorphicChrome]) {
			// iOS <= 6: native UIKit skeuomorphic tab item with embossed gradient and shadow.
			if ([item respondsToSelector:@selector(setFinishedSelectedImage:withFinishedUnselectedImage:)]) {
				[item setFinishedSelectedImage:nil withFinishedUnselectedImage:nil];
			}
			item.image = onMask ?: offMask;
		} else if (onMask || offMask) {
			UIImage *onImg = [TGIcons image:(onMask ?: offMask) filledWith:on];
			UIImage *offImg = [TGIcons image:(offMask ?: onMask) filledWith:off];

			if ([item respondsToSelector:@selector(setFinishedSelectedImage:withFinishedUnselectedImage:)]) {
				[item setFinishedSelectedImage:onImg withFinishedUnselectedImage:offImg];
			}
			if ([item respondsToSelector:@selector(setSelectedImage:)] &&
				[onImg respondsToSelector:@selector(imageWithRenderingMode:)]) {
				item.selectedImage = [onImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
				item.image = [offImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
			}
		}

		if (![TGTheme drawsSkeuomorphicChrome]) {
			NSDictionary *normalAttrs = @{
				UITextAttributeTextColor : off,
				NSForegroundColorAttributeName : off
			};
			NSDictionary *selectedAttrs = @{
				UITextAttributeTextColor : on,
				NSForegroundColorAttributeName : on
			};
			[item setTitleTextAttributes:normalAttrs forState:UIControlStateNormal];
			[item setTitleTextAttributes:selectedAttrs forState:UIControlStateSelected];
		} else {
			[item setTitleTextAttributes:nil forState:UIControlStateNormal];
			[item setTitleTextAttributes:nil forState:UIControlStateSelected];
		}
	}
	[bar setNeedsDisplay];
	[bar setNeedsLayout];
}

#pragma mark - wallpaper

- (NSString *)wallpaperPath {
	NSString *documents = [NSSearchPathForDirectoriesInDomains(
			NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	return [documents stringByAppendingPathComponent:@"wallpaper.jpg"];
}

- (TGWallpaperType)wallpaperType {
	NSNumber *stored = [NSUserDefaults.standardUserDefaults objectForKey:kWallpaperTypeKey];
	if (stored) {
		return (TGWallpaperType)stored.integerValue;
	}
	if ([[NSFileManager defaultManager] fileExistsAtPath:[self wallpaperPath]]) {
		return TGWallpaperTypeCustom;
	}
	return TGWallpaperTypeNone;
}

- (void)setWallpaperType:(TGWallpaperType)type {
	_wallpaper = nil;
	[NSUserDefaults.standardUserDefaults setInteger:type forKey:kWallpaperTypeKey];
	[NSUserDefaults.standardUserDefaults synchronize];
	if (type != TGWallpaperTypeCustom) {
		[[NSFileManager defaultManager] removeItemAtPath:[self wallpaperPath] error:nil];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:TGThemeChangedNotification object:nil];
}

- (NSString *)wallpaperTitleForType:(TGWallpaperType)type {
	switch (type) {
		case TGWallpaperTypeNone: return @"None (Solid)";
		case TGWallpaperTypePaperGrain: return @"Paper Grain";
		case TGWallpaperTypePinstripes: return @"Pinstripes";
		case TGWallpaperTypeLinen: return @"Classic Linen";
		case TGWallpaperTypeParchment: return @"Parchment";
		case TGWallpaperTypeFelt: return @"Game Center Felt";
		case TGWallpaperTypeCustom: return @"Photo Library";
	}
	return @"None";
}

- (UIImage *)wallpaper {
	if (_wallpaper)
		return _wallpaper;
	TGWallpaperType type = [self wallpaperType];
	if (type == TGWallpaperTypeCustom) {
		_wallpaper = [UIImage imageWithContentsOfFile:[self wallpaperPath]];
		return _wallpaper;
	}
	if (type != TGWallpaperTypeNone) {
		_wallpaper = [TGTheme textureImageForType:type];
		return _wallpaper;
	}

	// No photo or texture chosen: the theme's own wallpaper is in force.
	if (_themeWallpaper)
		return _themeWallpaper;
	NSString *emoji = [TGChatThemeStore shared].currentThemeName;
	if (emoji.length){
		// The emoji theme's background is a fill plus its own pattern document;
		// the store bakes and caches it, and asks Telegram for the pattern.
		CGSize size = [UIScreen mainScreen].bounds.size;
		_themeWallpaper = [[TGChatThemeStore shared]
				wallpaperForThemeNamed:emoji dark:[self isNightModeEnabled]
				size:size];
		if (_themeWallpaper)
			return _themeWallpaper;
	}
	UIColor *colour = [self importedColour:@"wallpaper"];
	if (colour)
		return nil;
	if ([self isDark])
		return nil;
	if (!_themeWallpaper)
		_themeWallpaper = [UIImage imageNamed:@"builtin-wallpaper-0.jpg"];
	return _themeWallpaper;
}

- (void)setWallpaperImage:(UIImage *)image {
	NSString *path = [self wallpaperPath];
	if (image){
		// Scaled down first: a full camera frame behind every chat is megabytes
		// of memory on a device that has 512.
		CGFloat maxSide = 640;
		CGFloat scale = MIN(1.0f, maxSide / MAX(image.size.width, image.size.height));
		if (scale < 1.0f){
			CGSize size = CGSizeMake(image.size.width * scale, image.size.height * scale);
			UIGraphicsBeginImageContextWithOptions(size, YES, 1);
			[image drawInRect:CGRectMake(0, 0, size.width, size.height)];
			image = UIGraphicsGetImageFromCurrentImageContext();
			UIGraphicsEndImageContext();
		}
		[UIImageJPEGRepresentation(image, 0.8f) writeToFile:path atomically:YES];
		_wallpaper = image;
		[NSUserDefaults.standardUserDefaults setInteger:TGWallpaperTypeCustom forKey:kWallpaperTypeKey];
	} else {
		[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		_wallpaper = nil;
		[NSUserDefaults.standardUserDefaults setInteger:TGWallpaperTypeNone forKey:kWallpaperTypeKey];
	}
	[NSUserDefaults.standardUserDefaults synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:TGThemeChangedNotification
													   object:nil];
}



- (void)styleNavigationBar:(UINavigationBar *)bar {
	if (!bar)
		return;

	bar.barStyle = [self isDark] ? UIBarStyleBlack : UIBarStyleDefault;

	// iOS 6 draws its own bar: tinted, it is the real gloss, edge and shadow,
	// and its Back and Done buttons match it because they come from the same
	// place.
	if ([TGTheme drawsSkeuomorphicChrome]) {
		if ([bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)])
			[bar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
		if ([bar respondsToSelector:@selector(setShadowImage:)])
			[bar setShadowImage:nil];
		bar.tintColor = [self barColour];
		bar.titleTextAttributes = @{
			UITextAttributeTextColor : [self barTitleColour],
			UITextAttributeTextShadowColor : [UIColor clearColor]
		};
		return;
	}

	// iOS 7 and later: their flat bar, its hairline and their title font. The
	// iOS 6 gloss painted over it here looked foreign on every later system.
	if ([bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)])
		[bar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
	if ([bar respondsToSelector:@selector(setShadowImage:)])
		[bar setShadowImage:nil];
	bar.translucent = NO;
	bar.barTintColor = [self barColour];
	bar.tintColor = [self barButtonColour];
	bar.titleTextAttributes = @{ NSForegroundColorAttributeName : [self barTitleColour] };
}

@end

// vim:ft=objc
