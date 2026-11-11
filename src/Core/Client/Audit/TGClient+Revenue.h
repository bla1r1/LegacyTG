#import "TGClient+Base.h"

@interface TGClient (Revenue)

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

@end
