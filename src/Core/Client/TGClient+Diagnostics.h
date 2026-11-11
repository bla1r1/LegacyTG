//
// TGClient+Diagnostics.h - what TDLib says about itself: the state it is in,
// its configuration, its database, its network counters, and the escape
// hatches a support session needs.
//
#import "TGClient+Base.h"

@interface TGClient (Diagnostics)

#pragma mark - state and configuration

/// getCurrentState, one row per update: "type" and a short "summary". An
/// error answers an empty list and the server's sentence.
/// getApplicationConfig's JsonValue, converted to Foundation objects with
/// the nested jsonValue wrappers removed. Nil and the refusal otherwise.
/// TDLib's human-readable database report.
#pragma mark - network

/// "none", "mobile", "roaming", "wifi" or "other". TDLib reopens every
/// connection when this changes, which is why a switch on a screen is enough
/// to follow a handover.
/// Adds one call entry to TDLib's data-usage counters. The entries are what
/// getNetworkStatistics totals; a screen that adds one re-reads the totals.
#pragma mark - charts

/// getStatisticalGraph for a statistics token. An asynchronous answer is
/// followed up to three times; the result then has "kind" ("data" or
/// "async"), the parsed "json", the raw "raw" text, a "zoomToken" and
/// printable "lines" - a list when there are no points to draw.
#pragma mark - raw request and database key

/// sendCustomRequest with a method name and a JSON parameter string. The
/// answer is the reply's own result string, unparsed - a custom method is
/// exactly the place where the app cannot know the shape in advance.
/// Whether this app can read the key the database is opened with. NO means
/// the keychain failed; changing the key then could make the database
/// unreadable, so setDatabaseEncryptionKey refuses.
/// Whether the database currently has a key at all.
/// Changes TDLib's database key. Only legal when the current key is known;
/// the new key is saved before the request is sent and the old one is put
/// back if Telegram refuses, so a refusal never leaves the next launch with
/// a key that does not open this database.
@end
