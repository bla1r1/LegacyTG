#import "TGClient+Base.h"

@interface TGClient (BusinessBot)

/// The business bot connected to this account. Nil with Telegram's 404 text
/// when there is none.
- (void)businessConnectedBotWithCompletion:(void (^)(NSDictionary *bot,
													 NSString *error))completion;

/// Connects or replaces the business bot. `recipients` follows
/// businessRecipients; missing keys are false.
- (void)setBusinessConnectedBot:(int64_t)botUserId
					 recipients:(NSDictionary *)recipients
					 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)deleteBusinessConnectedBot:(int64_t)botUserId
						completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)confirmBusinessConnectedBot:(int64_t)botUserId
						 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)removeBusinessConnectedBotFromChat:(int64_t)chatId
								completion:(void (^)(BOOL ok,
													 NSString *error))completion;

- (void)pauseBusinessConnectedBotInChat:(int64_t)chatId
								 paused:(BOOL)paused
							 completion:(void (^)(BOOL ok, NSString *error))completion;

@end
