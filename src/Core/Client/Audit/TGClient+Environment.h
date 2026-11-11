#import "TGClient+Base.h"

@interface TGClient (Environment)

/// Converts JSON text to TDLib's JsonValue tree. Nil with `error` when the
/// text is not JSON or the dylib has no execute symbol.
/// The reverse: a JsonValue tree down to compact JSON text.
/// The colour set Telegram's payment and Web App surfaces expect, serialised.
/// The caller supplies the roles; missing ones are zero, which is how TDLib
/// represents black.
/// Switches TDLib's log to a file, to stderr or off. `kind` is "file",
/// "default" or "empty"; a file stream needs a path.
/// Writes one line into TDLib's log at `level`; useful when a device log has
/// to line up with what the app did. `text` is not user data.
/// Sends one application event to the server's log. Can be called before
/// sign-in, so it is also the login screen's only diagnostic.
/// The time zones TDLib knows, as "id", "name" and "offset" (seconds).
/// Exchange rates to USD, as "currency" and "rate".
/// Weather at one point, from Telegram's weather source: "temperature" and
/// "emoji".
- (void)currentWeatherAtLatitude:(double)latitude
					   longitude:(double)longitude
					  completion:(void (^)(NSDictionary *weather,
										   NSString *error))completion;

/// Succeeds after `seconds`. The only user-visible use is a deliberate wait
/// in the diagnostics screen; TDLib keeps the timer, not the app.
@end
