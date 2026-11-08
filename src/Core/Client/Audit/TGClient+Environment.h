#import "TGClient+Base.h"

@interface TGClient (Environment)

/// Converts JSON text to TDLib's JsonValue tree. Nil with `error` when the
/// text is not JSON or the dylib has no execute symbol.
- (void)jsonValueForText:(NSString *)text
			  completion:(void (^)(NSDictionary *value,
								   NSString *error))completion;

/// The reverse: a JsonValue tree down to compact JSON text.
- (void)jsonTextForValue:(NSDictionary *)value
			  completion:(void (^)(NSString *text,
								   NSString *error))completion;

/// The colour set Telegram's payment and Web App surfaces expect, serialised.
/// The caller supplies the roles; missing ones are zero, which is how TDLib
/// represents black.
- (void)themeParametersJSONString:(NSDictionary *)colours
					   completion:(void (^)(NSString *text,
											NSString *error))completion;

- (void)logStreamWithCompletion:(void (^)(NSDictionary *stream,
										  NSString *error))completion;

- (void)logVerbosityLevelWithCompletion:(void (^)(int32_t level,
												  NSString *error))completion;

- (void)logTagsWithCompletion:(void (^)(NSArray *tags, NSString *error))completion;

- (void)logVerbosityForTag:(NSString *)tag
				completion:(void (^)(int32_t level, NSString *error))completion;

- (void)setLogVerbosityForTag:(NSString *)tag
						level:(int32_t)level
				   completion:(void (^)(BOOL ok, NSString *error))completion;

/// Switches TDLib's log to a file, to stderr or off. `kind` is "file",
/// "default" or "empty"; a file stream needs a path.
- (void)setLogStreamKind:(NSString *)kind
					path:(NSString *)path
			  completion:(void (^)(BOOL ok, NSString *error))completion;

/// Writes one line into TDLib's log at `level`; useful when a device log has
/// to line up with what the app did. `text` is not user data.
- (void)addLogMessage:(NSString *)text
				level:(int32_t)level
		   completion:(void (^)(BOOL ok, NSString *error))completion;

/// Sends one application event to the server's log. Can be called before
/// sign-in, so it is also the login screen's only diagnostic.
- (void)saveApplicationLogEvent:(NSString *)type
						chatId:(int64_t)chatId
						  data:(NSString *)data
					completion:(void (^)(BOOL ok, NSString *error))completion;

/// The time zones TDLib knows, as "id", "name" and "offset" (seconds).
- (void)timeZonesWithCompletion:(void (^)(NSArray *zones,
										  NSString *error))completion;

/// Exchange rates to USD, as "currency" and "rate".
- (void)currencyExchangeRatesWithCompletion:(void (^)(NSArray *rates,
													 NSString *error))completion;

/// Weather at one point, from Telegram's weather source: "temperature" and
/// "emoji".
- (void)currentWeatherAtLatitude:(double)latitude
					   longitude:(double)longitude
					  completion:(void (^)(NSDictionary *weather,
										   NSString *error))completion;

/// Succeeds after `seconds`. The only user-visible use is a deliberate wait
/// in the diagnostics screen; TDLib keeps the timer, not the app.
- (void)alarmAfterSeconds:(double)seconds
			   completion:(void (^)(BOOL ok, NSString *error))completion;

@end
