// TGThemeFileTests.m — the theme import parsers, pinned.
//
// TGThemeFile is Foundation-only, so each real format (.tgios-theme JSON,
// Android .attheme, Desktop .tdesktop-palette) is fed through its parser
// here: role mapping, variable chains, dark detection. Compiled into
// TGClientTests.
#import "TGTestRunner.h"
#import "TGThemeFile.h"
#import "TGChatThemeStore.h"

// Writes text into the inherited temp dir and returns the path.
static NSString *TGThemeWriteTemp(NSString *name, NSString *text) {
	NSString *path = [NSTemporaryDirectory()
			stringByAppendingPathComponent:name];
	[text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
	return path;
}

// A .attheme value is signed decimal ARGB with an opaque alpha byte.
static int32_t TGAtThemeARGB(int r, int g, int b) {
	return (int32_t)(0xFF000000u | ((uint32_t)r << 16) | ((uint32_t)g << 8) | b);
}

static BOOL TGColourMatches(UIColor *colour, int r, int g, int b) {
	// getRed: is BOOL on iOS, void on newer macOS hosts - the sentinel
	// out-params carry the success bit instead.
	CGFloat cr = -1, cg = -1, cb = -1, ca = -1;
	[colour getRed:&cr green:&cg blue:&cb alpha:&ca];
	return cr >= 0 && lroundf(cr * 255) == r && lroundf(cg * 255) == g
			&& lroundf(cb * 255) == b;
}

static void TGAssertColour(NSString *key, NSDictionary *palette,
						   int r, int g, int b) {
	UIColor *colour = [palette objectForKey:key];
	XCTAssertNotNil(colour, "theme must carry the %@ role", key);
	if (colour)
		XCTAssertTrue(TGColourMatches(colour, r, g, b),
				"%@ must be #%02x%02x%02x, got %@", key, r, g, b, colour);
}

@interface TGThemeFileTests : XCTestCase
@end
@implementation TGThemeFileTests

- (void)testHandlesFileKnowsTheRootFamilies {
	XCTAssertTrue([TGThemeFile handlesFile:@"a.tgios-theme"]);
	XCTAssertTrue([TGThemeFile handlesFile:@"a.attheme"]);
	XCTAssertTrue([TGThemeFile handlesFile:@"a.tdesktop-palette"]);
	XCTAssertTrue([TGThemeFile handlesFile:@"a.tdesktop-theme"]);
	XCTAssertFalse([TGThemeFile handlesFile:@"a.json"]);
}

- (void)testIOSThemeMapsNavBubblesAndBadges {
	NSString *json = @"{\n"
		"  \"name\": \"Reference\",\n"
		"  \"dark\": true,\n"
		"  \"root\": {\"navBar\": {\"background\": \"#517DA2\",\n"
		"      \"primaryText\": \"FFFFFF\", \"secondaryText\": \"F2F2F2\"}},\n"
		"  \"chatList\": {\"title\": \"E9EEEEF4\", \"messageText\": \"D8E1E7\",\n"
		"      \"unreadBadgeActiveBg\": \"FF6262\",\n"
		"      \"unreadBadgeActiveText\": \"FFFFFF\",\n"
		"      \"unreadBadgeMutedBg\": \"8E6E6E\"},\n"
		"  \"chat\": {\"message\": {\n"
		"      \"outgoing\": {\"bubble\": {\"withoutWp\": {\"bg\": \"96E176\"}}},\n"
		"      \"incoming\": {\"bubble\": {\"withoutWp\": {\"bg\": \"FFFFFF\"}}}}}}";
	NSString *path = TGThemeWriteTemp(@"reference.tgios-theme", json);

	NSString *name = nil;
	NSDictionary *palette = [TGThemeFile paletteFromFile:path name:&name];
	XCTAssertNotNil(palette);
	XCTAssertEqualObjects(name, @"Reference");
	XCTAssertTrue([palette[@"isDark"] boolValue], "%@", palette);
	TGAssertColour(@"bar", palette, 0x51, 0x7D, 0xA2);
	TGAssertColour(@"barTitle", palette, 0xFF, 0xFF, 0xFF);
	TGAssertColour(@"barSubtitle", palette, 0xF2, 0xF2, 0xF2);
	// withWp is the last resort; withoutWp must win first.
	TGAssertColour(@"bubbleMine", palette, 0x96, 0xE1, 0x76);
	TGAssertColour(@"bubbleTheirs", palette, 0xFF, 0xFF, 0xFF);
	TGAssertColour(@"primaryText", palette, 0xE9, 0xEE, 0xEE);
	TGAssertColour(@"badge", palette, 0xFF, 0x62, 0x62);
	TGAssertColour(@"badgeText", palette, 0xFF, 0xFF, 0xFF);
	TGAssertColour(@"mutedBadge", palette, 0x8E, 0x6E, 0x6E);

	NSString *ignored = nil;
	NSString *brokenPath = TGThemeWriteTemp(@"broken.tgios-theme", @"{\"no\": [");
	XCTAssertNil([TGThemeFile paletteFromFile:brokenPath name:&ignored]);
}

- (void)testNightBlueOfficialThemeMapsAllRoles {
	NSString *path = @"resources/NightBlue.tgios-theme";
	NSString *name = nil;
	NSDictionary *palette = [TGThemeFile paletteFromFile:path name:&name];
	XCTAssertNotNil(palette);
	XCTAssertEqualObjects(name, @"Night Blue");
	XCTAssertTrue([palette[@"isDark"] boolValue]);
	TGAssertColour(@"bar", palette, 0x17, 0x21, 0x2B);
	TGAssertColour(@"barTitle", palette, 0xFF, 0xFF, 0xFF);
	TGAssertColour(@"wallpaper", palette, 0x0E, 0x16, 0x21);
	TGAssertColour(@"chatBackground", palette, 0x0E, 0x16, 0x21);
	TGAssertColour(@"bubbleMine", palette, 0x2B, 0x52, 0x78);
	TGAssertColour(@"bubbleTheirs", palette, 0x18, 0x25, 0x33);
	TGAssertColour(@"bubbleMineText", palette, 0xFF, 0xFF, 0xFF);
	TGAssertColour(@"bubbleTheirsText", palette, 0xFF, 0xFF, 0xFF);
	TGAssertColour(@"accent", palette, 0x52, 0x88, 0xC1);
	TGAssertColour(@"barButton", palette, 0x52, 0x88, 0xC1);
	TGAssertColour(@"tabBar", palette, 0x17, 0x21, 0x2B);
}

- (void)testCardPaletteComesFromTheEntry {
	NSDictionary *classic = [TGThemeFile cardPaletteForThemeEntry:@{@"id" : @"classic"}];
	TGAssertColour(@"wallpaper", classic, 0xE2, 0xE6, 0xEC);
	TGAssertColour(@"bubbleMine", classic, 0xDF, 0xEE, 0xFA);
	TGAssertColour(@"bubbleTheirs", classic, 0xFF, 0xFF, 0xFF);
	TGAssertColour(@"accent", classic, 0x51, 0x7D, 0xA2);

	NSDictionary *night = [TGThemeFile cardPaletteForThemeEntry:@{
		@"id" : @"file:NightBlue.tgios-theme",
		@"path" : @"resources/NightBlue.tgios-theme",
		@"dark" : @YES,
	}];
	TGAssertColour(@"wallpaper", night, 0x0E, 0x16, 0x21);
	TGAssertColour(@"bubbleMine", night, 0x2B, 0x52, 0x78);
	TGAssertColour(@"bubbleTheirs", night, 0x18, 0x25, 0x33);
	TGAssertColour(@"text", night, 0xFF, 0xFF, 0xFF);
	TGAssertColour(@"accent", night, 0x52, 0x88, 0xC1);
	XCTAssertFalse([classic[@"wallpaper"] isEqual:night[@"wallpaper"]]);
}

- (void)testEmojiChatTheme_ParsesLightAndDarkSettings {
	NSDictionary *light = @{
		@"@type" : @"themeSettings",
		@"base_theme" : @{@"@type" : @"baseThemeClassic"},
		@"accent_color" : @(0x112233),
		@"outgoing_message_fill" : @{
			@"@type" : @"backgroundFillFreeformGradient",
			@"colors" : @[@(0x111111), @(0x222222), @(0x333333)],
		},
		@"outgoing_message_accent_color" : @(0x445566),
		@"background" : @{
			@"@type" : @"background",
			@"document" : @{
				@"@type" : @"document",
				@"document" : @{@"@type" : @"file", @"id" : @77},
			},
			@"type" : @{
				@"@type" : @"backgroundTypePattern",
				@"intensity" : @50,
				@"fill" : @{
					@"@type" : @"backgroundFillGradient",
					@"top_color" : @(0xAABBCC),
					@"bottom_color" : @(0xDDEEFF),
					@"rotation_angle" : @45,
				},
			},
		},
	};
	NSDictionary *dark = @{
		@"@type" : @"themeSettings",
		@"base_theme" : @{@"@type" : @"baseThemeNight"},
		@"accent_color" : @(0x445566),
		@"outgoing_message_fill" : @{
			@"@type" : @"backgroundFillSolid",
			@"color" : @(0x123456),
		},
		@"background" : @{
			@"@type" : @"background",
			@"type" : @{
				@"@type" : @"backgroundTypeFill",
				@"fill" : @{
					@"@type" : @"backgroundFillSolid",
					@"color" : @(0x0A0B0C),
				},
			},
		},
	};
	NSArray *themes = [TGChatThemeStore parseThemes:@[@{
		@"@type" : @"emojiChatTheme",
		@"name" : @"Sunset",
		@"light_settings" : light,
		@"dark_settings" : dark,
	}]];
	XCTAssertEqual(themes.count, (NSUInteger)1);
	NSDictionary *entry = themes.firstObject;
	XCTAssertEqualObjects(entry[@"id"], @"emoji:Sunset");
	XCTAssertTrue([entry[@"hasDark"] boolValue]);

	NSDictionary *lightPalette = entry[@"light"];
	TGAssertColour(@"accent", lightPalette, 0x11, 0x22, 0x33);
	TGAssertColour(@"bubbleMine", lightPalette, 0x11, 0x11, 0x11);
	XCTAssertEqual([lightPalette[@"bubbleMineGradient"] count], (NSUInteger)3);
	XCTAssertEqualObjects(lightPalette[@"patternFileId"], @77);
	XCTAssertEqualObjects(lightPalette[@"patternIntensity"], @50);
	XCTAssertEqualObjects(lightPalette[@"wallpaperFill"][@"kind"],
			@"backgroundFillGradient");
	TGAssertColour(@"wallpaper", lightPalette, 0xAA, 0xBB, 0xCC);
	XCTAssertFalse([lightPalette[@"isDark"] boolValue]);

	NSDictionary *darkPalette = entry[@"dark"];
	TGAssertColour(@"accent", darkPalette, 0x44, 0x55, 0x66);
	TGAssertColour(@"bubbleMine", darkPalette, 0x12, 0x34, 0x56);
	TGAssertColour(@"wallpaper", darkPalette, 0x0A, 0x0B, 0x0C);
	XCTAssertTrue([darkPalette[@"isDark"] boolValue]);

	// Night Mode is a variant switch inside the same theme, not a jump to
	// another theme: the entry keeps one id and answers its dark settings.
	XCTAssertEqual(TGChatThemeSettingsForMode(entry, NO), lightPalette);
	XCTAssertEqual(TGChatThemeSettingsForMode(entry, YES), darkPalette);
}

- (void)testNightBlueCard_KeepsItsOwnWallpaperAndBubble {
	NSDictionary *palette = [TGThemeFile cardPaletteForThemeEntry:@{
		@"id" : @"file:NightBlue.tgios-theme",
		@"name" : @"Night Blue",
		@"path" : @"resources/NightBlue.tgios-theme",
		@"dark" : @YES,
	}];
	TGAssertColour(@"wallpaper", palette, 0x0E, 0x16, 0x21);
	TGAssertColour(@"bubbleMine", palette, 0x2B, 0x52, 0x78);
	TGAssertColour(@"bubbleTheirs", palette, 0x18, 0x25, 0x33);
	TGAssertColour(@"text", palette, 0xFF, 0xFF, 0xFF);
	// Classic's light paper must not leak into the Night Blue card.
	NSDictionary *classic = [TGThemeFile cardPaletteForThemeEntry:
			@{@"id" : @"classic"}];
	XCTAssertFalse([palette[@"wallpaper"] isEqual:classic[@"wallpaper"]]);
}

- (void)testIOSThemeCarriesBubbleGradients {
	NSString *json = @"{\"dark\": true, \"chat\": {\"message\": {"
		"\"outgoing\": {\"bubble\": {\"withoutWp\": {\"bg\": \"#112233-#445566\"}}},"
		"\"incoming\": {\"bubble\": {\"withoutWp\": {\"bg\": \"#778899-#aabbcc\"}}}}}}";
	NSDictionary *palette = [TGThemeFile paletteFromFile:
			TGThemeWriteTemp(@"gradient.tgios-theme", json) name:NULL];
	NSArray *mineGradient = palette[@"bubbleMineGradient"];
	XCTAssertEqual(mineGradient.count, (NSUInteger)2);
	XCTAssertEqual([palette[@"bubbleTheirsGradient"] count], (NSUInteger)2);
	TGAssertColour(@"bubbleMine", palette, 0x11, 0x22, 0x33);
	XCTAssertTrue(TGColourMatches(mineGradient[1], 0x44, 0x55, 0x66));
}

- (void)testAndroidThemeMapsRolesAndGuessesDark {
	NSString *light = [NSString stringWithFormat:
		@"actionBarDefault=%d\n"
		"actionBarDefaultTitle=%d\n"
		"windowBackgroundWhite=%d\n"
		"windowBackgroundWhiteBlackText=%d\n"
		"windowBackgroundWhiteRedText=%d\n"
		"chat_wallpaper=%d\n"
		"chat_inBubble=%d\n"
		"chat_outBubble=%d\n"
		"chats_unreadCounter=%d\n"
		"chats_unreadCounterText=%d\n"
		"chat_outSentCheck=%d\n",
		TGAtThemeARGB(0x51, 0x7D, 0xA2),
		TGAtThemeARGB(0xFF, 0xFF, 0xFF),
		TGAtThemeARGB(0xFF, 0xFF, 0xFF),
		TGAtThemeARGB(0x22, 0x22, 0x22),
		TGAtThemeARGB(0xE5, 0x39, 0x35),
		TGAtThemeARGB(0xD9, 0xDE, 0xD4),
		TGAtThemeARGB(0xFF, 0xFF, 0xFF),
		TGAtThemeARGB(0x2B, 0x5D, 0x7F),
		TGAtThemeARGB(0x3D, 0x95, 0xD4),
		TGAtThemeARGB(0xFF, 0xFF, 0xFF),
		TGAtThemeARGB(0xE5, 0x39, 0x35)];
	NSString *path = TGThemeWriteTemp(@"light.attheme", light);
	NSString *name = nil;
	NSDictionary *palette = [TGThemeFile paletteFromFile:path name:&name];
	XCTAssertNotNil(palette);
	XCTAssertEqualObjects(name, @"light");
	XCTAssertFalse([palette[@"isDark"] boolValue], "%@", palette);
	TGAssertColour(@"bar", palette, 0x51, 0x7D, 0xA2);
	TGAssertColour(@"bubbleMine", palette, 0x2B, 0x5D, 0x7F);
	TGAssertColour(@"bubbleTheirs", palette, 0xFF, 0xFF, 0xFF);
	TGAssertColour(@"badge", palette, 0x3D, 0x95, 0xD4);
	TGAssertColour(@"badgeText", palette, 0xFF, 0xFF, 0xFF);
	TGAssertColour(@"ticks", palette, 0xE5, 0x39, 0x35);
	TGAssertColour(@"destructive", palette, 0xE5, 0x39, 0x35);

	// A dark paper must be detected, so unmap roles don't fall to light.
	NSString *dark = [NSString stringWithFormat:
		@"windowBackgroundWhite=%d\n",
		TGAtThemeARGB(0x26, 0x2E, 0x26)];
	NSString *darkPath = TGThemeWriteTemp(@"dark.attheme", dark);
	NSString *darkName = nil;
	NSDictionary *darkPalette = [TGThemeFile paletteFromFile:darkPath name:&darkName];
	XCTAssertNotNil(darkPalette);
	XCTAssertEqualObjects(darkName, @"dark");
	XCTAssertTrue([darkPalette[@"isDark"] boolValue], "%@", darkPalette);
}

- (void)testDesktopPaletteMapsRolesVariablesAndComments {
	NSString *text = @"// Variable theme, comments everywhere\n"
		"windowBg: #17212b;      // background\n"
		"windowFg: #ffffff;\n"
		"windowSubTextFg: #708499;\n"
		"topBarBg:\n"
		"  #17212b;              // value continues on the next line\n"
		"topBarFg: #ffffff;\n"
		"chatBg: #0e1621;\n"
		"msgInBg: #182533;\n"
		"msgOutBg: #2b5278;\n"
		"dialogsBg: #17212b;\n"
		"windowBgActive: #5288c1;\n"
		"dialogsUnreadBg: windowBgActive;   // resolves a variable chain\n"
		"msgServiceBg: #22303cc0;  // eight digits: alpha is the last pair\n"
		"msgServiceFg: #ffffff;\n"
		"windowBgOver: #17212b;";
	NSString *path = TGThemeWriteTemp(@"night.tdesktop-palette", text);
	NSString *name = nil;
	NSDictionary *palette = [TGThemeFile paletteFromFile:path name:&name];
	XCTAssertNotNil(palette, "%@", palette);
	XCTAssertEqualObjects(name, @"night");
	XCTAssertTrue([palette[@"isDark"] boolValue], "%@", palette);
	TGAssertColour(@"bar", palette, 0x17, 0x21, 0x2b);
	TGAssertColour(@"barTitle", palette, 0xFF, 0xFF, 0xFF);
	TGAssertColour(@"chatBackground", palette, 0x0e, 0x16, 0x21);
	TGAssertColour(@"bubbleMine", palette, 0x2b, 0x52, 0x78);
	TGAssertColour(@"bubbleTheirs", palette, 0x18, 0x25, 0x33);
	TGAssertColour(@"secondaryText", palette, 0x70, 0x84, 0x99);
	// The reference must reach both its role and the badge that falls back
	// to the same key name in the desktop palette.
	TGAssertColour(@"accent", palette, 0x52, 0x88, 0xc1);
	TGAssertColour(@"badge", palette, 0x52, 0x88, 0xc1);
	// The alpha byte trails the colour in tdesktop's spelling.
	TGAssertColour(@"service", palette, 0x22, 0x30, 0x3c);
	UIColor *service = [palette objectForKey:@"service"];
	CGFloat sa = -1, sr = -1, sg = -1, sb = -1;
	[service getRed:&sr green:&sg blue:&sb alpha:&sa];
	XCTAssertGreaterThan(sa, 0.7f, "the alpha byte must survive, got %.2f", sa);
	XCTAssertLessThan(sa, 0.9f, "too opaque: the alpha byte was lost");
	TGAssertColour(@"service", palette, 0x22, 0x30, 0x3c);
}
/// Dark themes are allowed for chat and keep chat roles.
- (void)testChatPaletteAllowsDarkAndKeepsChatRoles {
	NSString *light = [NSString stringWithFormat:
		@"actionBarDefault=%d\n"
		"windowBackgroundWhite=%d\n"
		"chat_outBubble=%d\n"
		"chat_inBubble=%d\n",
		TGAtThemeARGB(0x51, 0x7D, 0xA2),
		TGAtThemeARGB(0xFF, 0xFF, 0xFF),
		TGAtThemeARGB(0x2B, 0x5D, 0x7F),
		TGAtThemeARGB(0xFF, 0xFF, 0xFF)];
	NSString *name = nil;
	NSDictionary *chat = [TGThemeFile chatPaletteFromFile:TGThemeWriteTemp(@"chatonly.attheme", light)
													 name:&name];
	XCTAssertNotNil(chat);
	XCTAssertEqualObjects(name, @"chatonly");
	TGAssertColour(@"bubbleMine", chat, 0x2B, 0x5D, 0x7F);
	XCTAssertNil(chat[@"bar"], "%@", chat);
	XCTAssertNil(chat[@"listBackground"], "%@", chat);

	NSString *dark = [NSString stringWithFormat:@"windowBackgroundWhite=%d\nchat_outBubble=%d\n",
		TGAtThemeARGB(0x26, 0x2E, 0x26),
		TGAtThemeARGB(0x2B, 0x5D, 0x7F)];
	NSDictionary *darkChat = [TGThemeFile chatPaletteFromFile:TGThemeWriteTemp(@"night.attheme", dark) name:NULL];
	XCTAssertNotNil(darkChat);
	XCTAssertTrue([darkChat[@"isDark"] boolValue]);
	TGAssertColour(@"bubbleMine", darkChat, 0x2B, 0x5D, 0x7F);
}

@end

// The .tgv pipeline lives in its own file; this suite is what main_client
// already imports, so it pulls the pattern tests into the same binary.
#import "TGPatternTests.m"
