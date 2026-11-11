//
// TGStarsStore+Revenue.m - the Stars store's Revenue requests.
//
// Bodies copied from src/Core/Client/Audit/TGClient+Revenue.m; the store owns them.
//

#import "TGStarsStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGStarsStore (Revenue)

#pragma mark - revenue

- (void)chatRevenueStatisticsForChat:(int64_t)chatId
							  dark:(BOOL)dark
						  completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!chatId){
		if (completion) completion(nil, @"A chat id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getChatRevenueStatistics",
					@"chat_id" : @(chatId), @"is_dark" : @(dark)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"usdRate" : TGAuditNumber(result, @"usd_rate"),
						 @"totalAmount" : TGAuditNumber(result[@"revenue_amount"], @"total_amount"),
						 @"balanceAmount" : TGAuditNumber(result[@"revenue_amount"], @"balance_amount"),
						 @"availableAmount" : TGAuditNumber(result[@"revenue_amount"], @"available_amount"),
						 @"withdrawalEnabled" : @([result[@"revenue_amount"][@"withdrawal_enabled"] boolValue]),
						 @"graph" : TGAuditString(result[@"revenue_graph"], @"@type")}, nil);
	}];
}

- (void)chatRevenueTransactionsForChat:(int64_t)chatId
								offset:(NSString *)offset
								 limit:(int32_t)limit
							completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!chatId){
		if (completion) completion(nil, @"A chat id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getChatRevenueTransactions",
					@"chat_id" : @(chatId),
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
				@"currency" : TGAuditString(transaction, @"cryptocurrency"),
				@"amount" : TGAuditNumber(transaction, @"cryptocurrency_amount"),
				@"type" : TGAuditShortType(transaction[@"type"][@"@type"]),
			}];
		}
		if (completion)
			completion(@{@"transactions" : rows,
						 @"nextOffset" : TGAuditString(result, @"next_offset"),
						 @"gramAmount" : TGAuditNumber(result, @"gram_amount")}, nil);
	}];
}

- (void)starRevenueStatisticsForOwner:(NSString *)ownerKind
							  ownerId:(int64_t)ownerId
								 dark:(BOOL)dark
						   completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!ownerId){
		if (completion) completion(nil, @"An owner id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getStarRevenueStatistics",
					@"owner_id" : TGAuditSender(ownerKind, ownerId),
					@"is_dark" : @(dark)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSDictionary *status = result[@"status"];
		if (completion)
			completion(@{@"total" : TGAuditNumber(status[@"total_amount"], @"star_count"),
						 @"current" : TGAuditNumber(status[@"current_amount"], @"star_count"),
						 @"available" : TGAuditNumber(status[@"available_amount"], @"star_count"),
						 @"withdrawalEnabled" : @([status[@"withdrawal_enabled"] boolValue]),
						 @"nextWithdrawalIn" : TGAuditNumber(status, @"next_withdrawal_in"),
						 @"graph" : TGAuditString(result[@"revenue_by_day_graph"], @"@type")}, nil);
	}];
}

- (void)gramRevenueStatisticsWithDark:(BOOL)dark
						   completion:(void (^)(NSDictionary *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getGramRevenueStatistics", @"is_dark" : @(dark)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSDictionary *status = result[@"status"];
		if (completion)
			completion(@{@"total" : TGAuditNumber(status, @"total_amount"),
						 @"balance" : TGAuditNumber(status, @"balance_amount"),
						 @"available" : TGAuditNumber(status, @"available_amount"),
						 @"withdrawalEnabled" : @([status[@"withdrawal_enabled"] boolValue]),
						 @"graph" : TGAuditString(result[@"revenue_by_day_graph"], @"@type")}, nil);
	}];
}

- (void)paidMessageRevenueForUser:(int64_t)userId
					   completion:(void (^)(int64_t, NSString *))completion {
	if (!userId){
		if (completion) completion(0, @"A user id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getPaidMessageRevenue", @"user_id" : @(userId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(0, TGAuditError(result));
			return;
		}
		if (completion) completion([TGAuditNumber(result, @"star_count") longLongValue], nil);
	}];
}

- (void)directMessagesChatTopicRevenueForChat:(int64_t)chatId
										topic:(int64_t)topicId
								   completion:(void (^)(int64_t, NSString *))completion {
	if (!chatId || !topicId){
		if (completion) completion(0, @"A chat id and a topic id are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getDirectMessagesChatTopicRevenue",
					@"chat_id" : @(chatId), @"topic_id" : @(topicId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(0, TGAuditError(result));
			return;
		}
		if (completion) completion([TGAuditNumber(result, @"star_count") longLongValue], nil);
	}];
}

@end
