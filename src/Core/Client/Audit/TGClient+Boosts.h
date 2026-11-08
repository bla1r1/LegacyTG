#import "TGClient+Base.h"

@interface TGClient (Boosts)

/// Boost slots this account can still spend, as "slotId",
/// "currentlyBoostedChatId", "startDate", "expirationDate" and
/// "cooldownUntilDate".
- (void)availableChatBoostSlotsWithCompletion:(void (^)(NSArray *slots,
													   NSString *error))completion;

/// A chat's boost level and counts, as "level", "boostCount",
/// "currentLevelBoostCount", "nextLevelBoostCount" and "boostUrl".
- (void)chatBoostStatusForChat:(int64_t)chatId
					completion:(void (^)(NSDictionary *status,
										 NSString *error))completion;

/// The offline feature table for channels or groups.
- (void)chatBoostFeaturesForChannel:(BOOL)isChannel
						 completion:(void (^)(NSDictionary *features,
											  NSString *error))completion;

- (void)chatBoostLevelFeaturesForChannel:(BOOL)isChannel
								   level:(int32_t)level
							  completion:(void (^)(NSDictionary *features,
												   NSString *error))completion;

- (void)chatBoostLinkForChat:(int64_t)chatId
				  completion:(void (^)(NSString *link, NSString *error))completion;

- (void)chatBoostLinkInfo:(NSString *)url
			   completion:(void (^)(NSDictionary *info, NSString *error))completion;

/// The boosts on a chat; `offset` and `limit` page the list.
- (void)chatBoostsForChat:(int64_t)chatId
				   offset:(NSString *)offset
					limit:(int32_t)limit
			   completion:(void (^)(NSDictionary *page, NSString *error))completion;

/// Spends the named slots on a chat. No payment provider is involved: the
/// slots are the Premium boost allowance.
- (void)boostChat:(int64_t)chatId
		  slotIds:(NSArray *)slotIds
	   completion:(void (^)(NSArray *slots, NSString *error))completion;

@end
