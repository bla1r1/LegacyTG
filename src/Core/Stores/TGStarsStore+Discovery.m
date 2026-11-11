//
// TGStarsStore+Discovery.m - the Stars store's Discovery requests.
//
// Bodies copied from src/Core/Client/Audit/TGClient+Discovery.m; the store owns them.
//

#import "TGStarsStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGStarsStore (Discovery)

#pragma mark - discovery

- (void)allowUnpaidMessagesFromUser:(int64_t)userId
							 refund:(BOOL)refund
						 completion:(void (^)(BOOL, NSString *))completion {
	if (!userId){
		if (completion) completion(NO, @"A user id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"allowUnpaidMessagesFromUser",
					@"user_id" : @(userId), @"refund_payments" : @(refund)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)applyUnpaidMessagesToken:(NSString *)token
						  forUser:(int64_t)userId
					   completion:(void (^)(BOOL, NSString *))completion {
	token = [token stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!userId || !token.length){
		if (completion) completion(NO, @"A user id and a token are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"applyUnpaidMessagesToken",
					@"user_id" : @(userId), @"token" : token}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)paidReactionSendersForChat:(int64_t)chatId
						completion:(void (^)(NSArray *, NSString *))completion {
	if (!chatId){
		if (completion) completion(nil, @"A chat id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getChatAvailablePaidMessageReactionSenders",
					@"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *sender in result[@"senders"]){
			if (![sender isKindOfClass:NSDictionary.class])
				continue;
			NSNumber *identifier = sender[@"user_id"] ?: sender[@"chat_id"];
			[rows addObject:@{@"kind" : TGAuditShortType(sender[@"@type"]),
							  @"id" : identifier ?: @0}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)setChatPaidMessageStarCount:(int64_t)chatId
							  count:(int32_t)starCount
						 completion:(void (^)(BOOL, NSString *))completion {
	if (!chatId || starCount < 0){
		if (completion) completion(NO, @"A chat id and a non-negative price are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"setChatPaidMessageStarCount",
					@"chat_id" : @(chatId),
					@"paid_message_star_count" : @(starCount)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)setGroupCallPaidMessageStarCount:(int32_t)groupCallId
								   count:(int32_t)starCount
							  completion:(void (^)(BOOL, NSString *))completion {
	if (!groupCallId || starCount < 0){
		if (completion) completion(NO, @"A call id and a non-negative price are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"setGroupCallPaidMessageStarCount",
					@"group_call_id" : @(groupCallId),
					@"paid_message_star_count" : @(starCount)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)setDirectMessagesTopicUnpaid:(int64_t)chatId
							   topic:(int64_t)topicId
							 allowed:(BOOL)allowed
							  refund:(BOOL)refund
						  completion:(void (^)(BOOL, NSString *))completion {
	if (!chatId || !topicId){
		if (completion) completion(NO, @"A chat id and a topic id are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"toggleDirectMessagesChatTopicCanSendUnpaidMessages",
					@"chat_id" : @(chatId),
					@"topic_id" : @(topicId),
					@"can_send_unpaid_messages" : @(allowed),
					@"refund_payments" : @(refund)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)paymentReceiptForChat:(int64_t)chatId
					  message:(int64_t)messageId
				   completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!chatId || !messageId){
		if (completion) completion(nil, @"An error occurred.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getPaymentReceipt",
					@"chat_id" : @(chatId), @"message_id" : @(messageId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSDictionary *product = result[@"product_info"];
		NSDictionary *type = result[@"type"];
		if (completion)
			completion(@{@"kind" : TGAuditShortType(type[@"@type"]),
						 @"title" : TGAuditString(product, @"title"),
						 @"description" : TGAuditString(product, @"description"),
						 @"date" : TGAuditNumber(result, @"date"),
						 @"starCount" : TGAuditNumber(type, @"star_count"),
						 @"transactionId" : TGAuditString(type, @"transaction_id"),
						 @"credentialsTitle" : TGAuditString(type, @"credentials_title")}, nil);
	}];
}

- (void)starAdAccountURLForOwner:(NSString *)ownerKind
						 ownerId:(int64_t)ownerId
					  completion:(void (^)(NSString *, NSString *))completion {
	if (!ownerId){
		if (completion) completion(nil, @"An owner id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getStarAdAccountUrl",
					@"owner_id" : TGAuditSender(ownerKind, ownerId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditString(result, @"url"), nil);
	}];
}

- (void)setSupergroupUnrestrictBoostCount:(int32_t)count
							  supergroupId:(int64_t)supergroupId
							   completion:(void (^)(BOOL, NSString *))completion {
	if (!supergroupId || count < 0 || count > 8){
		if (completion) completion(NO, @"A supergroup id and a count from 0 to 8 are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"setSupergroupUnrestrictBoostCount",
					@"supergroup_id" : @(supergroupId),
					@"unrestrict_boost_count" : @(count)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)giveawayInfoForChat:(int64_t)chatId
					message:(int64_t)messageId
				 completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!chatId || !messageId){
		if (completion) completion(nil, @"An error occurred.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getGiveawayInfo",
					@"chat_id" : @(chatId), @"message_id" : @(messageId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"kind" : TGAuditShortType(result[@"@type"]),
						 @"creationDate" : TGAuditNumber(result, @"creation_date"),
						 @"isEnded" : @([result[@"is_ended"] boolValue]),
						 @"isWinner" : @([result[@"is_winner"] boolValue]),
						 @"winnerCount" : TGAuditNumber(result, @"winner_count"),
						 @"wonStarCount" : TGAuditNumber(result, @"won_star_count"),
						 @"giftCode" : TGAuditString(result, @"gift_code")}, nil);
	}];
}

- (void)collectibleItemInfoForKind:(NSString *)kind
							 value:(NSString *)value
						completion:(void (^)(NSDictionary *, NSString *))completion {
	value = [value stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!value.length){
		if (completion) completion(nil, @"The username or phone number is needed.");
		return;
	}
	NSDictionary *type = nil;
	if ([kind isEqualToString:@"phoneNumber"]){
		type = @{@"@type" : @"collectibleItemTypePhoneNumber",
				 @"phone_number" : value};
	} else {
		type = @{@"@type" : @"collectibleItemTypeUsername", @"username" : value};
	}
	[[TGClient shared] request:@{@"@type" : @"getCollectibleItemInfo", @"type" : type}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"purchaseDate" : TGAuditNumber(result, @"purchase_date"),
						 @"currency" : TGAuditString(result, @"currency"),
						 @"amount" : TGAuditNumber(result, @"amount"),
						 @"cryptocurrency" : TGAuditString(result, @"cryptocurrency"),
						 @"cryptocurrencyAmount" : TGAuditNumber(result, @"cryptocurrency_amount"),
						 @"url" : TGAuditString(result, @"url")}, nil);
	}];
}

@end
