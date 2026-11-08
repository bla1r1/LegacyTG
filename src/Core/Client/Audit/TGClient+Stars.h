#import "TGClient+Base.h"

@interface TGClient (Stars)

/// The Star wallet: transactions and subscriptions. `ownerKind` is "user" or
/// "chat"; `direction` is "incoming", "outgoing" or empty for both.
- (void)starTransactionsForOwner:(NSString *)ownerKind
						 ownerId:(int64_t)ownerId
					 direction:(NSString *)direction
						offset:(NSString *)offset
						 limit:(int32_t)limit
					completion:(void (^)(NSDictionary *page,
										 NSString *error))completion;

- (void)starSubscriptionsOnlyExpiring:(BOOL)onlyExpiring
							   offset:(NSString *)offset
						   completion:(void (^)(NSDictionary *page,
												NSString *error))completion;

- (void)setStarSubscription:(NSString *)subscriptionId
				   canceled:(BOOL)canceled
				 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)reuseStarSubscription:(NSString *)subscriptionId
				   completion:(void (^)(BOOL ok, NSString *error))completion;

@end
