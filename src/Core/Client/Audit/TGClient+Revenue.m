#import "TGClient+Revenue.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGClient (Revenue)

#pragma mark - revenue

- (void)chatRevenueStatisticsForChat:(int64_t)chatId
							  dark:(BOOL)dark
						  completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!chatId){
		if (completion) completion(nil, @"A chat id is needed.");
		return;
	}
	[self request:@{@"@type" : @"getChatRevenueStatistics",
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
	[self request:@{@"@type" : @"getChatRevenueTransactions",
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
	[self request:@{@"@type" : @"getStarRevenueStatistics",
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
	[self request:@{@"@type" : @"getGramRevenueStatistics", @"is_dark" : @(dark)}
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
	[self request:@{@"@type" : @"getPaidMessageRevenue", @"user_id" : @(userId)}
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
	[self request:@{@"@type" : @"getDirectMessagesChatTopicRevenue",
					@"chat_id" : @(chatId), @"topic_id" : @(topicId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(0, TGAuditError(result));
			return;
		}
		if (completion) completion([TGAuditNumber(result, @"star_count") longLongValue], nil);
	}];
}

/// The balance itself has no screen asking for it today, so it is only kept
/// here for the getter. The two revenue updates do have a screen: the Stars
/// page re-reads the statistics it already asked for when it hears them.
- (void)applyOwnedStarCountUpdate:(NSDictionary *)update {
	self.ownedStarCountValue = [update[@"star_count"] longLongValue];
}

- (int64_t)ownedStarCount {
	return self.ownedStarCountValue;
}

- (void)applyChatRevenueAmountUpdate:(NSDictionary *)update {
	NSNumber *chatId = update[@"chat_id"];
	if (!chatId)
		return;
	NSDictionary *amount = [update[@"revenue_amount"] isKindOfClass:NSDictionary.class]
			? update[@"revenue_amount"] : @{};
	if (!self.chatRevenueAmountByChat)
		self.chatRevenueAmountByChat = [NSMutableDictionary dictionary];
	self.chatRevenueAmountByChat[chatId] = amount;
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatRevenueChangedNotification object:self
						userInfo:@{@"chatId" : chatId}];
}

- (NSDictionary *)chatRevenueAmountForChat:(int64_t)chatId {
	return self.chatRevenueAmountByChat[@(chatId)];
}

- (void)applyStarRevenueStatusUpdate:(NSDictionary *)update {
	NSDictionary *owner = [update[@"owner_id"] isKindOfClass:NSDictionary.class]
			? update[@"owner_id"] : nil;
	if (!owner)
		return;
	BOOL isChat = [owner[@"@type"] isEqualToString:@"messageSenderChat"];
	NSString *kind = isChat ? @"chat" : @"user";
	int64_t ownerId = isChat ? [owner[@"chat_id"] longLongValue]
			: [owner[@"user_id"] longLongValue];
	if (!ownerId)
		return;
	NSDictionary *status = [update[@"status"] isKindOfClass:NSDictionary.class]
			? update[@"status"] : @{};
	if (!self.starRevenueStatusByOwner)
		self.starRevenueStatusByOwner = [NSMutableDictionary dictionary];
	self.starRevenueStatusByOwner[[NSString stringWithFormat:@"%@:%lld", kind, ownerId]]
			= status;
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGStarRevenueChangedNotification object:self
						userInfo:@{@"ownerKind" : kind, @"ownerId" : @(ownerId)}];
}

- (NSDictionary *)starRevenueStatusForOwner:(NSString *)ownerKind
									ownerId:(int64_t)ownerId {
	NSString *kind = [ownerKind isEqualToString:@"chat"] ? @"chat" : @"user";
	return self.starRevenueStatusByOwner[
			[NSString stringWithFormat:@"%@:%lld", kind, ownerId]];
}

@end
