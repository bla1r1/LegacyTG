#import "TGClient+Base.h"

@interface TGClient (Revenue)

- (void)chatRevenueStatisticsForChat:(int64_t)chatId
							  dark:(BOOL)dark
						  completion:(void (^)(NSDictionary *statistics,
											   NSString *error))completion;

- (void)chatRevenueTransactionsForChat:(int64_t)chatId
								offset:(NSString *)offset
								 limit:(int32_t)limit
							completion:(void (^)(NSDictionary *page,
												 NSString *error))completion;

- (void)starRevenueStatisticsForOwner:(NSString *)ownerKind
							  ownerId:(int64_t)ownerId
								 dark:(BOOL)dark
						   completion:(void (^)(NSDictionary *statistics,
												NSString *error))completion;

/// The account's own Star balance, from updateOwnedStarCount. Zero until
/// Telegram reports one.
@property (nonatomic, readonly) int64_t ownedStarCount;

/// One chat's revenue amount, from updateChatRevenueAmount: "totalAmount",
/// "balanceAmount", "availableAmount" and "withdrawalEnabled". Nil until the
/// update names that chat.
- (NSDictionary *)chatRevenueAmountForChat:(int64_t)chatId;

/// One owner's Star revenue status, from updateStarRevenueStatus: the whole
/// starRevenueStatus record. Nil until the update names that owner.
- (NSDictionary *)starRevenueStatusForOwner:(NSString *)ownerKind
									ownerId:(int64_t)ownerId;

- (void)gramRevenueStatisticsWithDark:(BOOL)dark
						   completion:(void (^)(NSDictionary *statistics,
												NSString *error))completion;

- (void)paidMessageRevenueForUser:(int64_t)userId
					   completion:(void (^)(int64_t starCount,
											NSString *error))completion;

- (void)directMessagesChatTopicRevenueForChat:(int64_t)chatId
										topic:(int64_t)topicId
								   completion:(void (^)(int64_t starCount,
														NSString *error))completion;

@end
