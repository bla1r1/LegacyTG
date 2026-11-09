//
// TGSettingsFormatting.h - the value formatting the settings pages share.
//
// Kept apart from the row model so the host tests can compile it without
// UIKit or TGClient.
//
#ifndef TGSETTINGSFORMATTING_H
#define TGSETTINGSFORMATTING_H

#import <Foundation/Foundation.h>
#include <math.h>
#import "TGLocalization.h"
#import "TGThemeTypes.h"
#import "TGThemeList.h"
#import "TGUIFormat.h"
#import "TGStyle.h"
#import "TGRows.h"

/// A byte count in the pack's own unit strings ("%@ KB", "%@ MB", "%@ GB"),
/// with the decimal separator of the app's language rather than the phone's.
/// A Russian interface says "1,5 МБ" on a device set to English because the
/// number and the unit belong to the same sentence. `language` is passed in so
/// the host test can pin both spellings; TGBytes uses the selected pack.
///
/// One formatter is cached: NSNumberFormatter is an ICU setup, and the settings
/// rows build their values when data arrives, not in cellForRow:.
static inline NSString *TGBytesForLanguage(long long bytes, NSString *language) {
	static NSNumberFormatter *formatter = nil;
	static NSString *formatterLanguage = nil;
	if (!formatter)
		formatter = [[NSNumberFormatter alloc] init];
	NSString *code = language.length ? language : @"en";
	if (![formatterLanguage isEqualToString:code]){
		formatterLanguage = [code copy];
		formatter.locale = [NSLocale localeWithLocaleIdentifier:code];
		formatter.numberStyle = NSNumberFormatterDecimalStyle;
	}
	if (bytes <= 0)
		return TGLocalizedFormat(@"%@ KB", @"0");
	if (bytes < 1024 * 1024){
		formatter.maximumFractionDigits = 0;
		return TGLocalizedFormat(@"%@ KB",
				[formatter stringFromNumber:@(bytes / 1024.0)]);
	}
	if (bytes < 1024LL * 1024 * 1024){
		formatter.maximumFractionDigits = 1;
		return TGLocalizedFormat(@"%@ MB",
				[formatter stringFromNumber:@(bytes / (1024.0 * 1024.0))]);
	}
	formatter.maximumFractionDigits = 2;
	return TGLocalizedFormat(@"%@ GB",
			[formatter stringFromNumber:@(bytes / (1024.0 * 1024.0 * 1024.0))]);
}

static inline NSString *TGBytes(long long bytes) {
	return TGBytesForLanguage(bytes, TGAppLanguage());
}

/// The auto-download value as official's autodownloadDataSizeString makes it:
/// a whole number of MB from 10 MB up, one decimal below that, and the app
/// language's decimal separator. "121,5 МБ" was wider than the value column
/// beside "Using Wi-Fi"; "121 МБ" fits.
static inline NSString *TGSettingsAutoDownloadBytesForLanguage(long long bytes,
															   NSString *language) {
	if (bytes <= 0)
		return TGLocalized(@"Off");
	NSString *code = language.length ? language : @"en";
	NSLocale *locale = [NSLocale localeWithLocaleIdentifier:code];
	NSString *separator = [locale objectForKey:NSLocaleDecimalSeparator] ?: @".";
	NSString *unit;
	long long whole;
	long long fraction = 0;
	if (bytes >= 1024LL * 1024 * 1024){
		unit = @"GB";
		whole = bytes / (1024LL * 1024 * 1024);
		fraction = (bytes % (1024LL * 1024 * 1024)) / (1024LL * 1024 * 102);
	} else if (bytes >= 1024 * 1024){
		unit = @"MB";
		whole = bytes / (1024 * 1024);
		fraction = (bytes % (1024 * 1024)) / (1024 * 102);
		if (whole >= 10)
			fraction = 0;
	} else if (bytes >= 1024){
		unit = @"KB";
		whole = bytes / 1024;
	} else {
		return TGLocalizedFormat(@"%@ B",
				[NSString stringWithFormat:@"%lld", bytes]);
	}
	if (fraction == 10){
		fraction = 9;
	}
	while (fraction != 0 && fraction % 10 == 0)
		fraction /= 10;
	NSString *number = fraction > 0
			? [NSString stringWithFormat:@"%lld%@%lld", whole, separator, fraction]
			: [NSString stringWithFormat:@"%lld", whole];
	return TGLocalizedFormat([@"%@ " stringByAppendingString:TGLocalized(unit)],
			number);
}

static inline NSString *TGSettingsAutoDownloadBytes(long long bytes) {
	return TGSettingsAutoDownloadBytesForLanguage(bytes, TGAppLanguage());
}

/// A segmented-control segment wide enough for the translated title plus the
/// control's own side inset. "Пропущ." was clipped because the control split
/// the bar in half; each segment now gets its own measured width.
static inline CGFloat TGSettingsSegmentWidth(NSString *title, UIFont *font,
											 CGFloat horizontalPadding) {
	if (!title.length)
		return TGMetricZero;
	UIFont *face = font ?: TGFontCaption();
	return ceilf([title sizeWithFont:face].width) +
			TGDoubled(horizontalPadding);
}

/// A capability row on This Device: the feature name and On (in the online
/// green, applied by the screen) or the reason it is unavailable.
static inline NSDictionary *TGDeviceCapabilityRowModel(NSString *name,
													   BOOL available,
													   NSString *requirement) {
	NSString *detail = available ? TGLocalized(@"On")
			: TGLocalized(requirement ?: @"");
	return TGTapRow(TGLocalized(name ?: @""), detail, nil);
}

/// The storage page's category rows: "Photos  42.3%" over the size, with the
/// panel's check state. The screen adds the chart-coloured disc; the model
/// keeps the order, the share and the selection rule testable.
static inline NSArray *TGSettingsStorageCategoryRowModels(NSArray *categories,
														  long long total,
														  NSSet *selectedKinds) {
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *category in categories){
		long long bytes = [category[@"bytes"] longLongValue];
		double share = total > 0 ? (bytes / (double)total) * 100.0 : 0;
		NSString *title = [NSString stringWithFormat:@"%@  %.1f%%",
				category[@"name"] ?: @"", share];
		NSArray *kinds = category[@"kinds"] ?: @[];
		BOOL allSelected = kinds.count > 0;
		for (NSString *kind in kinds)
			if (![selectedKinds containsObject:kind]){
				allSelected = NO;
				break;
			}
		NSMutableDictionary *row = [TGCheckRow(title, TGBytes(bytes),
				allSelected, nil) mutableCopy];
		row[@"storageKinds"] = kinds;
		[rows addObject:row];
	}
	return rows;
}

#pragma mark - usernames

/// TDLib compares usernames without case, and the field lets people type the
/// leading @ they see on every link.
static inline NSString *TGUsernameNormalized(NSString *text) {
	NSString *trimmed = [text ?: @"" stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([trimmed hasPrefix:@"@"])
		trimmed = [trimmed substringFromIndex:1];
	return [trimmed lowercaseString];
}

/// Empty and unchanged text need no request. The rest is one check per pause
/// in the field, not one per keystroke.
static inline BOOL TGUsernameShouldCheck(NSString *typed, NSString *current) {
	NSString *normalized = TGUsernameNormalized(typed);
	return normalized.length > 0 &&
			![normalized isEqualToString:TGUsernameNormalized(current)];
}

/// The line under the username field. The four answers the official setup
/// screen names; anything else Telegram can answer (purchasable, too many
/// public chats) is not an available name either, so it reads as invalid.
static inline NSString *TGUsernameAvailabilityText(NSString *result,
												   NSString *username) {
	if ([result isEqualToString:@"checking"])
		return TGLocalized(@"Checking username...");
	if ([result isEqualToString:@"ok"])
		return TGLocalizedFormat(@"%@ is available.", username ?: @"");
	if ([result isEqualToString:@"occupied"])
		return TGLocalized(@"Sorry, this username is already taken.");
	return TGLocalized(@"Sorry, this username is invalid.");
}

/// A reply belongs to the text that asked for it. Typing on while a check is
/// in flight must not paint the old answer under the new name.
static inline BOOL TGUsernameAnswerStillApplies(NSString *answerFor,
												NSString *current) {
	return [TGUsernameNormalized(answerFor) isEqualToString:
			TGUsernameNormalized(current)];
}

#pragma mark - notifications

/// getChatNotificationSettingsExceptions is asked once for the whole account;
/// the category page keeps the chats that belong to its scope. A channel is a
/// supergroup with is_channel, so groups exclude it explicitly.
static inline NSArray *TGNotificationExceptionsForScope(NSArray *chats,
														NSString *scope) {
	BOOL channels = [scope isEqualToString:@"channels"];
	BOOL groups = [scope isEqualToString:@"groups"];
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *chat in chats){
		if (![chat isKindOfClass:NSDictionary.class])
			continue;
		BOOL isChannel = [chat[@"isChannel"] boolValue];
		BOOL isGroup = [chat[@"isGroup"] boolValue];
		BOOL matches = channels ? isChannel
				: (groups ? (isGroup && !isChannel) : (!isGroup && !isChannel));
		if (matches)
			[out addObject:chat];
	}
	[out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b){
		NSString *left = [a[@"title"] isKindOfClass:NSString.class]
				? a[@"title"] : @"";
		NSString *right = [b[@"title"] isKindOfClass:NSString.class]
				? b[@"title"] : @"";
		return [left caseInsensitiveCompare:right];
	}];
	return out;
}

/// The state line under an exception's name. A custom sound or preview is an
/// extra detail on the same line in official; the two mute states are what the
/// row has to say before that.
static inline NSString *TGNotificationExceptionDetail(NSDictionary *chat) {
	NSDictionary *settings = chat[@"notificationSettings"];
	BOOL muted = [settings[@"mute_for"] integerValue] > 0;
	return muted ? @"Always Off" : @"Always On";
}

#pragma mark - proxy status

/// One line on a proxy row. The active proxy speaks about the connection; the
/// saved ones name their type and what the ping said.
static inline NSString *TGProxyRowStatusText(BOOL active, BOOL checking,
											 double pingSeconds,
											 NSString *typeName) {
	NSString *kind = typeName.length ? typeName : @"Proxy";
	NSString *connected = TGLocalizedKey(@"SocksProxySetup_ProxyStatusConnected",
			@"connected");
	NSString *connecting = TGLocalizedKey(@"SocksProxySetup_ProxyStatusConnecting",
			@"connecting");
	if (active){
		if (checking)
			return connecting;
		if (pingSeconds < 0)
			return connected;
		NSString *ping = TGLocalizedFormat(@"%@ ms ping",
				[NSString stringWithFormat:@"%ld",
						(long)llround(pingSeconds * 1000.0)]);
		return [NSString stringWithFormat:@"%@, %@", connected, ping];
	}
	if (checking)
		return [NSString stringWithFormat:@"%@, %@", kind,
				TGLocalized(@"not tested")];
	if (pingSeconds < 0)
		return [NSString stringWithFormat:@"%@, %@", kind,
				TGLocalized(@"unavailable")];
	NSString *ping = TGLocalizedFormat(@"%@ ms ping",
			[NSString stringWithFormat:@"%ld", (long)llround(pingSeconds * 1000.0)]);
	return [NSString stringWithFormat:@"%@, %@", kind, ping];
}

/// The reset-account date uses the app's own scheduled-message formatter, so
/// it follows the selected language instead of the phone's medium/short
/// NSDateFormatter styles.
static inline NSString *TGSettingsDateTimeText(double stamp, NSTimeInterval now) {
	if (stamp <= 0)
		return @"—";
	return TGUIFormatScheduledWhen(stamp, now);
}

/// The account's inactivity lifetime, from the months the menu offers to the
/// days TDLib stores. A year is 365 days and 18 months is 548, so the stored
/// value round-trips through the display mapping below without drifting.
static inline NSInteger TGSettingsAccountTtlDaysForMonths(NSInteger months) {
	switch (months){
		case 1:  return 30;
		case 3:  return 90;
		case 6:  return 180;
		case 12: return 365;
		case 18: return 548;
		case 24: return 730;
		default: return months * 365 / 12;
	}
}

/// The months a stored lifetime came from. 540 and 548 both mean 18 months:
/// older builds wrote 540 and the official client writes 548.
static inline NSInteger TGSettingsAccountTtlMonthsForDays(NSInteger days) {
	switch (days){
		case 30:  return 1;
		case 90:  return 3;
		case 180: return 6;
		case 365: return 12;
		case 540: case 548: return 18;
		case 730: return 24;
		default: return 0;
	}
}

/// The away-for row's value. Until Telegram has answered, zero is unknown
/// rather than Off, so the caller passes whether the answer has arrived.
static inline NSString *TGSettingsAccountTtlLabel(NSInteger days, BOOL loaded) {
	if (!loaded)
		return @"Loading...";
	if (days <= 0)
		return @"Off";
	NSInteger months = TGSettingsAccountTtlMonthsForDays(days);
	if (months == 1)
		return TGLocalizedPluralValue(@"%@ month", @"%@ months", @"1", 1);
	if (months == 12)
		return TGLocalizedPluralValue(@"%@ year", @"%@ years", @"1", 1);
	if (months == 24)
		return TGLocalizedPluralValue(@"%@ year", @"%@ years", @"2", 2);
	if (months > 0)
		return TGLocalizedPluralValue(@"%@ month", @"%@ months",
				[NSString stringWithFormat:@"%ld", (long)months], months);
	return TGLocalizedPluralValue(@"%@ day", @"%@ days",
			[NSString stringWithFormat:@"%ld", (long)days], days);
}

/// The Devices row: the total when there is another session, Add Device when
/// the account has only this one. "1" would claim a session that is not there.
static inline NSString *TGSettingsDevicesValue(NSInteger otherSessions) {
	if (otherSessions <= 0)
		return @"Add Device";
	return [NSString stringWithFormat:@"%ld", (long)(otherSessions + 1)];
}

/// In the proxy list row 0 is the Use Proxy switch and the last row is Add
/// Proxy; only the saved proxies between them can be deleted.
static inline BOOL TGSettingsProxyRowEditable(NSInteger row, NSInteger proxyCount) {
	return row >= 1 && row <= proxyCount;
}

/// A Saved Messages tap waits while the account record is still arriving, but
/// only while the screen is on top and only for a bounded number of attempts.
static inline BOOL TGSettingsSavedMessagesShouldRetry(NSInteger retries,
													  BOOL onScreen) {
	return onScreen && retries < 20;
}

/// A storage category toggles every kind it contains: tapping a partly
/// selected panel selects the rest, tapping a complete one clears it.
static inline void TGSettingsToggleKinds(NSMutableSet *selected, NSArray *kinds) {
	if (!kinds.count)
		return;
	BOOL all = YES;
	for (NSString *kind in kinds)
		if (![selected containsObject:kind]){
			all = NO;
			break;
		}
	if (all)
		for (NSString *kind in kinds)
			[selected removeObject:kind];
	else
		[selected addObjectsFromArray:kinds];
}

/// The bytes the current selection covers. A category is counted once, even
/// when several of its kinds are selected.
static inline long long TGSettingsSelectedBytes(NSArray *categories,
												NSSet *selectedKinds) {
	long long bytes = 0;
	for (NSDictionary *category in categories){
		for (NSString *kind in category[@"kinds"])
			if ([selectedKinds containsObject:kind]){
				bytes += [category[@"bytes"] longLongValue];
				break;
			}
	}
	return bytes;
}

/// A privacy rule value from TDLib ("everybody", "contacts (+4)") as the
/// pack's row label. The count keeps its own template so the exception
/// suffixes translate.
static inline NSString *TGPrivacyLabel(NSString *value) {
	if (!value.length) return @"Loading...";
	NSString *base = value;
	NSInteger count = 0;
	BOOL minus = NO;
	NSRange open = [value rangeOfString:@" ("];
	if (open.location != NSNotFound){
		base = [value substringToIndex:open.location];
		NSString *suffix = [value substringFromIndex:NSMaxRange(open)];
		minus = [suffix hasPrefix:@"-"];
		NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
		NSString *number = [[suffix componentsSeparatedByCharactersInSet:
				[digits invertedSet]] componentsJoinedByString:@""];
		count = number.integerValue;
	}
	NSString *label = base;
	if ([base isEqualToString:@"everybody"]) label = @"Everybody";
	else if ([base isEqualToString:@"contacts"]) label = @"My Contacts";
	else if ([base isEqualToString:@"nobody"]) label = @"Nobody";
	if (!count)
		return label;
	if (minus)
		return TGLocalizedFormat([label stringByAppendingString:@" (-%@)"],
				[NSString stringWithFormat:@"%ld", (long)count]);
	return TGLocalizedFormat([label stringByAppendingString:@" (+%@)"],
			[NSString stringWithFormat:@"%ld", (long)count]);
}

#pragma mark - Appearance

/// The five physical textures the app has always drawn itself, in the order
/// the old wallpaper list showed them. Their ids are stable strings because a
/// grid mixes them with server backgrounds, whose ids are numbers.
static inline NSArray *TGSettingsLocalWallpaperItems(void) {
	return @[
		@{@"id" : @"local:paper-grain", @"title" : @"Paper Grain",
		  @"localWallpaperType" : @(TGWallpaperTypePaperGrain)},
		@{@"id" : @"local:pinstripes", @"title" : @"Pinstripes",
		  @"localWallpaperType" : @(TGWallpaperTypePinstripes)},
		@{@"id" : @"local:classic-linen", @"title" : @"Classic Linen",
		  @"localWallpaperType" : @(TGWallpaperTypeLinen)},
		@{@"id" : @"local:parchment", @"title" : @"Parchment",
		  @"localWallpaperType" : @(TGWallpaperTypeParchment)},
		@{@"id" : @"local:game-center-felt", @"title" : @"Game Center Felt",
		  @"localWallpaperType" : @(TGWallpaperTypeFelt)},
	];
}

/// The wallpaper gallery model: the app's own textures first, then the
/// account's installed backgrounds. The caller puts the active theme's
/// wallpaper in front of this list.
static inline NSArray *TGSettingsWallpaperGridItems(NSArray *localItems,
													NSArray *serverItems) {
	NSMutableArray *items = [NSMutableArray array];
	[items addObjectsFromArray:localItems ?: @[]];
	[items addObjectsFromArray:serverItems ?: @[]];
	return items;
}

/// The sample conversation in ThemeSettingsChatPreviewItem. The four strings
/// are the official pack keys, not the account's own name or an old preview
/// sentence: that is why they translate on a Ukrainian or Russian phone.
static inline NSDictionary *TGSettingsAppearancePreviewTexts(void) {
	return @{
		@"author"   : TGLocalized(@"Zakhar"),
		@"reply"    : TGLocalized(@"Good morning! 👋"),
		@"incoming" : TGLocalized(@"It's almost noon..."),
		@"outgoing" : TGLocalized(@"It's morning in Tokyo 😎"),
	};
}

/// Official section headers are uppercased after the pack lookup, not before:
/// the pack stores "Select Theme" in title case, and ThemePickerController
/// calls .uppercased() on the translated value.
static inline NSString *TGSettingsHeaderText(NSString *english) {
	return [TGLocalized(english) uppercaseString];
}

/// ThemeSettingsController inserts .builtin(.dayClassic) at the front of the
/// chat theme list. The carousel and the Chat Themes grid therefore show one
/// Classic card before the server's emoji themes.
static inline NSDictionary *TGSettingsClassicThemeEntry(void) {
	return @{@"id" : @"classic", @"name" : @"Classic", @"dark" : @NO,
			 @"emoji" : @NO};
}

static inline NSArray *TGSettingsThemesWithClassic(NSArray *themes) {
	NSMutableArray *result = [NSMutableArray arrayWithObject:
			TGSettingsClassicThemeEntry()];
	for (NSDictionary *entry in themes){
		if (![entry isKindOfClass:NSDictionary.class])
			continue;
		if ([entry[@"id"] isEqualToString:@"classic"])
			continue;
		[result addObject:entry];
	}
	return result;
}

/// The Chat Themes page order, matching ThemePickerController: the server's
/// emoji themes are the grid under "Select Theme"; the base themes sit under
/// the preview, because they are what "Create Your Own Theme" edits. Kept as
/// data so the host test can pin the two sections without UIKit.
static inline NSArray *TGSettingsChatThemesModel(NSArray *emojiThemes,
												 NSArray *baseThemes,
												 NSString *currentThemeId) {
	return @[
		@{
			@"kind"   : @"emojiGrid",
			@"header" : @"Select Theme",
			@"themes" : emojiThemes ?: @[],
		},
		@{
			@"kind"    : @"customTheme",
			@"header"  : @"Create Your Own Theme",
			@"themes"  : baseThemes ?: @[],
			@"current" : currentThemeId ?: @"",
		},
	];
}

static inline NSString *TGSettingsAutoNightModeLabel(NSUserDefaults *defaults) {
	return TGSettingsAutoNightMode(defaults) == TGSettingsAutoNightModeScheduled
			? TGLocalized(@"Scheduled") : TGLocalized(@"Disabled");
}

/// A stored minute of day as the phone's own short time ("22:00", "10 PM").
static inline NSString *TGSettingsAutoNightTimeText(NSInteger minutes) {
	if (minutes < 0 || minutes >= 24 * 60)
		minutes = 0;
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *today = [calendar components:(NSYearCalendarUnit |
			NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:[NSDate date]];
	today.hour = minutes / 60;
	today.minute = minutes % 60;
	today.second = 0;
	NSDate *date = [calendar dateFromComponents:today] ?: [NSDate date];
	return [NSDateFormatter localizedStringFromDate:date
										  dateStyle:NSDateFormatterNoStyle
										  timeStyle:NSDateFormatterShortStyle];
}

/// getInstalledBackgrounds is asked for one side of the theme, but a list can
/// still carry both. Keep the side the caller is drawing; entries without a
/// side are kept rather than silently disappearing from the grid.
static inline NSArray *TGSettingsBackgroundsForDarkTheme(NSArray *backgrounds,
														 BOOL darkTheme) {
	NSMutableArray *kept = [NSMutableArray array];
	for (NSDictionary *background in backgrounds){
		if (![background isKindOfClass:NSDictionary.class])
			continue;
		id side = background[@"isDark"];
		if ([side isKindOfClass:NSNumber.class] &&
			[side boolValue] != darkTheme)
			continue;
		[kept addObject:background];
	}
	return kept;
}

#endif // TGSETTINGSFORMATTING_H
