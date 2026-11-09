#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// The app's own UI text. `english` is both the key and the fallback: the
/// Telegram language pack is loaded as an English-value → translated-value
/// map, so a custom string with no pack entry stays readable.
NSString *TGLocalized(NSString *english);
NSString *TGLocalizedOrNil(NSString *english);
NSString *TGLocalizedFormat(NSString *english, ...);

/// For an English value the pack shares between keys ("%1$@ %2$@" is both
/// the date header and several unrelated templates): the translation of
/// that one key (e.g. @"Date.ChatDateHeader"), else TGLocalized(english).
NSString *TGLocalizedKey(NSString *packKey, NSString *english);

/// Prefix of the keyed entries in the lookup; English text never starts
/// with it.
extern NSString *const TGLocalizationKeyPrefix;

/// A count sentence with the grammar the selected language needs. `one` and
/// `other` are the English forms; the pack supplies one/few/many/other. The
/// format uses a single integer placeholder (`%d`).
NSString *TGLocalizedPlural(NSString *one, NSString *other, NSInteger count);

/// The same for a count carried as text, for the pack's `%@ hours`,
/// `%@ days`, `%@ months` templates.
NSString *TGLocalizedPluralValue(NSString *one, NSString *other,
								 NSString *value, NSInteger count);

/// The selected language pack id, or nil for the system language.
NSString *TGAppLanguage(void);
BOOL TGAppLanguageIsSystem(void);
void TGSetAppLanguage(NSString *packId);

/// Called by the language bridge once a pack has been loaded.
void TGSetTelegramLanguageLookup(NSDictionary *englishToTranslated);

/// The plural forms for the pack's English other-values, e.g.
/// `@"%d chats" -> @{@"one": …, @"few": …, @"many": …, @"other": …}`.
void TGSetTelegramLanguagePlurals(NSDictionary *englishToForms);

/// YES when these are the tables already in use, so a pack that arrives
/// unchanged at launch skips the reinstall and the interface walk it posts.
BOOL TGTelegramLanguageMatches(NSDictionary *englishToTranslated,
		NSDictionary *englishToForms);

/// Posted after the lookup or the selected language changes.
extern NSString *const TGAppLanguageChangedNotification;

#ifdef __cplusplus
}
#endif
