#import "TGClient+Base.h"

@interface TGClient (Boosts)

/// Boost slots this account can still spend, as "slotId",
/// "currentlyBoostedChatId", "startDate", "expirationDate" and
/// "cooldownUntilDate".
/// A chat's boost level and counts, as "level", "boostCount",
/// "currentLevelBoostCount", "nextLevelBoostCount" and "boostUrl".
/// The offline feature table for channels or groups.
/// The boosts on a chat; `offset` and `limit` page the list.
/// Spends the named slots on a chat. No payment provider is involved: the
/// slots are the Premium boost allowance.
@end
