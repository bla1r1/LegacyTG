//
// TGThemeList.h - the theme list and the Night Mode choice, shared by TGTheme
// and the Appearance page. Lives in Core so TGTheme needs nothing from
// Features; plain Foundation so the host tests compile it.
//
#ifndef TGTHEMELIST_H
#define TGTHEMELIST_H

#import <Foundation/Foundation.h>

/// Night Mode keeps the theme it will apply and the light theme it came from.
/// Both are theme ids in the same list the carousel draws.
static NSString *const TGSettingsNightModeKey = @"themeNightMode";
static NSString *const TGSettingsNightThemeKey = @"themeNightThemeId";
static NSString *const TGSettingsDayThemeKey = @"themeDayThemeId";

/// Auto-Night stores its mode and the two ends of the schedule. Minutes are
/// local wall-clock minutes after midnight, so a schedule survives a timezone.
static NSString *const TGSettingsAutoNightModeKey = @"themeAutoNightMode";
static NSString *const TGSettingsAutoNightFromKey = @"themeAutoNightFrom";
static NSString *const TGSettingsAutoNightToKey = @"themeAutoNightTo";
static const NSInteger TGSettingsAutoNightModeDisabled = 0;
static const NSInteger TGSettingsAutoNightModeScheduled = 1;
static const NSInteger TGSettingsAutoNightDefaultFrom = 22 * 60;
static const NSInteger TGSettingsAutoNightDefaultTo = 7 * 60;

/// A theme's display name. An imported file can arrive with its extension in
/// the name or as a bare id; neither belongs on a card or in a row.
static inline NSString *TGSettingsThemeDisplayName(NSDictionary *entry) {
	NSString *name = [entry isKindOfClass:NSDictionary.class] ? entry[@"name"] : nil;
	if (![name isKindOfClass:NSString.class])
		name = @"";
	if ([name rangeOfString:@"/"].location != NSNotFound)
		name = name.lastPathComponent;
	NSArray *extensions = @[@".tgios-theme", @".attheme", @".tdesktop-palette",
			@".tdesktop-theme", @".theme"];
	for (NSString *extension in extensions)
		if ([name.lowercaseString hasSuffix:extension]){
			name = [name substringToIndex:name.length - extension.length];
			break;
		}
	if ([name hasSuffix:@"."])
		name = [name substringToIndex:name.length - 1];
	name = [name stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	NSString *themeId = entry[@"id"];
	if (!name.length && [themeId isKindOfClass:NSString.class]){
		if ([themeId hasPrefix:@"file:"])
			name = [themeId substringFromIndex:5].lastPathComponent;
		else if ([themeId isEqualToString:@"classic"])
			name = @"Classic";
		for (NSString *extension in extensions)
			if ([name.lowercaseString hasSuffix:extension]){
				name = [name substringToIndex:name.length - extension.length];
				break;
			}
	}
	if ([name hasSuffix:@"."])
		name = [name substringToIndex:name.length - 1];
	name = [name stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return name.length ? name : @"Classic";
}

/// Classic leads; imported files keep the order the file system handed back,
/// dark files included. The carousel and -selectThemeId: both read this list,
/// so a theme cannot be shown and then not found by id.
static inline NSArray *TGSettingsThemeList(NSArray *fileThemes) {
	NSMutableArray *themes = [@[@{@"id" : @"classic", @"name" : @"Classic",
			@"dark" : @NO}] mutableCopy];
	for (NSDictionary *entry in fileThemes){
		if (![entry isKindOfClass:NSDictionary.class])
			continue;
		NSString *themeId = entry[@"id"];
		if (![themeId isKindOfClass:NSString.class] || !themeId.length)
			continue;
		NSMutableDictionary *clean = [entry mutableCopy];
		clean[@"name"] = TGSettingsThemeDisplayName(entry);
		[themes addObject:clean];
	}
	return themes;
}

static inline NSDictionary *TGSettingsThemeForId(NSArray *themes, NSString *themeId) {
	if (!themeId.length)
		return nil;
	for (NSDictionary *entry in themes)
		if ([entry[@"id"] isEqualToString:themeId])
			return entry;
	return nil;
}

static inline BOOL TGSettingsThemeIsDark(NSArray *themes, NSString *themeId) {
	return [TGSettingsThemeForId(themes, themeId)[@"dark"] boolValue];
}

/// The dark theme Night Mode switches to: the last one chosen, otherwise the
/// first dark entry in the list. nil when the list has no dark theme at all.
static inline NSString *TGSettingsNightThemeId(NSUserDefaults *defaults,
											   NSArray *themes) {
	NSString *stored = [defaults stringForKey:TGSettingsNightThemeKey];
	if (stored.length && TGSettingsThemeIsDark(themes, stored))
		return stored;
	for (NSDictionary *entry in themes)
		if ([entry[@"dark"] boolValue])
			return entry[@"id"];
	return nil;
}

/// The light theme Night Mode returns to. A stale or dark id falls back to
/// Classic, which every build has.
static inline NSString *TGSettingsDayThemeId(NSUserDefaults *defaults,
											 NSArray *themes) {
	NSString *stored = [defaults stringForKey:TGSettingsDayThemeKey];
	if (stored.length && TGSettingsThemeForId(themes, stored) &&
		!TGSettingsThemeIsDark(themes, stored))
		return stored;
	return @"classic";
}

static inline BOOL TGSettingsNightModeEnabled(NSUserDefaults *defaults) {
	return [defaults boolForKey:TGSettingsNightModeKey];
}

#pragma mark - Auto-Night

static inline NSInteger TGSettingsAutoNightMode(NSUserDefaults *defaults) {
	NSNumber *stored = [defaults objectForKey:TGSettingsAutoNightModeKey];
	return stored ? stored.integerValue : TGSettingsAutoNightModeDisabled;
}

static inline void TGSettingsSetAutoNightMode(NSUserDefaults *defaults,
											  NSInteger mode) {
	[defaults setInteger:mode forKey:TGSettingsAutoNightModeKey];
	[defaults synchronize];
}

static inline NSInteger TGSettingsAutoNightMinute(NSUserDefaults *defaults,
												  NSString *key,
												  NSInteger fallback) {
	NSNumber *stored = [defaults objectForKey:key];
	if (!stored)
		return fallback;
	NSInteger minute = stored.integerValue;
	return minute < 0 || minute >= 24 * 60 ? fallback : minute;
}

/// Local wall-clock minutes after midnight for `date`.
static inline NSInteger TGSettingsMinuteOfDay(NSDate *date) {
	NSDateComponents *parts = [[NSCalendar currentCalendar]
			components:(NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:date];
	return parts.hour * 60 + parts.minute;
}

/// The night window is [from, to), wrapping through midnight. Equal ends are
/// an empty window, not a 24-hour one: a user who sets both to the same time
/// has not asked for permanent Night Mode.
static inline BOOL TGSettingsAutoNightShouldBeDark(NSInteger nowMinute,
												   NSInteger fromMinute,
												   NSInteger toMinute) {
	if (fromMinute == toMinute)
		return NO;
	if (fromMinute < toMinute)
		return nowMinute >= fromMinute && nowMinute < toMinute;
	return nowMinute >= fromMinute || nowMinute < toMinute;
}

#endif
