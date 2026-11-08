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
#import "TGUIFormat.h"

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

#endif // TGSETTINGSFORMATTING_H
