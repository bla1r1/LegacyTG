//
// TGStarsStore+Stars.m - the Stars store's Stars requests.
//
// Bodies copied from src/Core/Client/Audit/TGClient+Stars.m; the store owns them.
//

#import "TGStarsStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGStarsStore (Stars)

#pragma mark - Stars

- (void)starTransactionsForOwner:(NSString *)ownerKind
						 ownerId:(int64_t)ownerId
					 direction:(NSString *)direction
						offset:(NSString *)offset
						 limit:(int32_t)limit
					completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!ownerId){
		if (completion) completion(nil, @"An owner id is needed.");
		return;
	}
	NSDictionary *directionObject = nil;
	if ([direction isEqualToString:@"incoming"])
		directionObject = @{@"@type" : @"transactionDirectionIncoming"};
	else if ([direction isEqualToString:@"outgoing"])
		directionObject = @{@"@type" : @"transactionDirectionOutgoing"};
	[[TGClient shared] request:@{@"@type" : @"getStarTransactions",
					@"owner_id" : TGAuditSender(ownerKind, ownerId),
					@"subscription_id" : @"",
					@"direction" : directionObject ?: [NSNull null],
					@"offset" : (offset ?: @""),
					@"limit" : @(MAX((int32_t)1, MIN(limit, (int32_t)100)))}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *transaction in result[@"transactions"]){
			if (![transaction isKindOfClass:NSDictionary.class])
				continue;
			[rows addObject:@{
				@"id" : TGAuditString(transaction, @"id"),
				@"date" : TGAuditNumber(transaction, @"date"),
				@"starCount" : TGAuditNumber(transaction[@"star_amount"], @"star_count"),
				@"isRefund" : @([transaction[@"is_refund"] boolValue]),
				@"type" : TGAuditShortType(transaction[@"type"][@"@type"]),
			}];
		}
		if (completion)
			completion(@{@"transactions" : rows,
						 @"nextOffset" : TGAuditString(result, @"next_offset"),
						 @"starCount" : TGAuditNumber(result[@"star_amount"], @"star_count")}, nil);
	}];
}

- (void)starSubscriptionsOnlyExpiring:(BOOL)onlyExpiring
							   offset:(NSString *)offset
						   completion:(void (^)(NSDictionary *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getStarSubscriptions",
					@"only_expiring" : @(onlyExpiring),
					@"offset" : (offset ?: @"")}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *subscription in result[@"subscriptions"]){
			if (![subscription isKindOfClass:NSDictionary.class])
				continue;
			[rows addObject:@{
				@"id" : TGAuditString(subscription, @"id"),
				@"chatId" : TGAuditNumber(subscription, @"chat_id"),
				@"expirationDate" : TGAuditNumber(subscription, @"expiration_date"),
				@"isCanceled" : @([subscription[@"is_canceled"] boolValue]),
				@"isExpiring" : @([subscription[@"is_expiring"] boolValue]),
				@"period" : TGAuditNumber(subscription[@"pricing"], @"period"),
				@"starCount" : TGAuditNumber(subscription[@"pricing"], @"star_count"),
				@"type" : TGAuditShortType(subscription[@"type"][@"@type"]),
			}];
		}
		if (completion)
			completion(@{@"subscriptions" : rows,
						 @"nextOffset" : TGAuditString(result, @"next_offset"),
						 @"starCount" : TGAuditNumber(result[@"star_amount"], @"star_count"),
						 @"requiredStarCount" : TGAuditNumber(result, @"required_star_count")}, nil);
	}];
}

- (void)setStarSubscription:(NSString *)subscriptionId
				   canceled:(BOOL)canceled
				 completion:(void (^)(BOOL, NSString *))completion {
	if (!subscriptionId.length){
		if (completion) completion(NO, @"A subscription id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"editStarSubscription",
					@"subscription_id" : subscriptionId,
					@"is_canceled" : @(canceled)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)reuseStarSubscription:(NSString *)subscriptionId
				   completion:(void (^)(BOOL, NSString *))completion {
	if (!subscriptionId.length){
		if (completion) completion(NO, @"A subscription id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"reuseStarSubscription",
					@"subscription_id" : subscriptionId}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

@end
