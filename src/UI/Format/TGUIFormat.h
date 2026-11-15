//
// TGUIFormat.h - the small, screen-independent strings several merged screens
// share: a call's clock, a scheduled message's date, a phone number put
// together from its two fields, and the match a forward search makes.
//
// Pure functions on purpose: the host suite can pin them without UIKit, and
// every screen that shows one of these strings then says the same thing.
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// A call's duration the way Telegram writes it: 0:07, 12:04, 1:02:09.
NSString *TGUIFormatCallDuration(NSTimeInterval seconds);

/// "Today at 18:30", "Tomorrow at 09:00", "3 Nov at 09:00". `now` is passed in
/// so the host test does not depend on when it runs.
NSString *TGUIFormatScheduledWhen(NSTimeInterval sendDate, NSTimeInterval now);

/// "in 2 h 15 min" under a scheduled message; empty for a stamp in the past.
NSString *TGUIFormatScheduledRelative(NSTimeInterval sendDate, NSTimeInterval now);

/// The full number Telegram is asked to sign in: the prefix's digits, then
/// the national number's, without repeating a prefix already typed into it.
NSString *TGUIFormatFullPhone(NSString *prefix, NSString *number);

/// Whether a forward-picker query names a chat: case and accents do not
/// count, and an empty query matches everything.
BOOL TGUIFormatChatMatches(NSString *title, NSString *query);

/// A list row's date the way the chat list prints it: the time today, the
/// weekday this week, the date before that. Empty for no date. `now` is
/// TGOptionNow, the server's clock, so a phone with a wrong clock still says
/// "today" about today.
NSString *TGUIFormatChatDate(NSTimeInterval unix, NSTimeInterval now);

/// A date in `language` (the device locale when empty), nil for no date.
/// Formatters are kept per style and language: making one per row is what
/// made long lists scroll badly on an A5.
NSString *TGUIFormatDate(NSTimeInterval unix, NSDateFormatterStyle date,
		NSDateFormatterStyle time, NSString *language);

/// TGUIFormatDate in the app's language, so a Russian UI never prints an
/// English month.
NSString *TGAppDate(NSTimeInterval unix, NSDateFormatterStyle date,
		NSDateFormatterStyle time);

/// A byte count in the pack's own unit strings ("%@ KB", "%@ MB", "%@ GB"),
/// with the decimal separator of the app's language rather than the phone's.
/// A Russian interface says "1,5 МБ" on a device set to English because the
/// number and the unit belong to the same sentence. `language` is passed in so
/// the host test can pin both spellings; TGBytes uses the selected pack.
///
/// One formatter is cached: NSNumberFormatter is an ICU setup, and the settings
/// rows build their values when data arrives, not in cellForRow:.
NSString *TGBytesForLanguage(long long bytes, NSString *language);
NSString *TGBytes(long long bytes);

/// Compact count for post views: 0..999 as is, 1.2K, 12K, 1M, 1.2M.
NSString *TGCompactCount(int64_t n);

/// A textEntityTypeDateTime's words in the reader's time
/// (stringForEntityFormattedDate): "5 minutes ago", "in 2 days", or the
/// date and time at the precision the sender chose, weekday first when asked.
/// Nil when the entity has no formatting type: its own text stays.
NSString *TGDateEntityText(int64_t unixTime, NSDictionary *formattingType,
		NSTimeInterval now);

/// `text` with every formatted date entity's words swapped in, and in
/// `outEntities` all the entities moved to match. Nil when nothing changes,
/// so the common message pays for one scan of its entity types.
NSString *TGApplyDateEntities(NSString *text, NSArray *entities, NSTimeInterval now,
		NSArray **outEntities);

/// The link a "0:42" media timestamp carries inside a message, and its
/// seconds back out of it; -1 for any other link.
NSString *TGMediaTimestampLink(int32_t seconds);
int32_t TGMediaTimestampFromLink(NSString *link);

#ifdef __cplusplus
}
#endif
