#import "TGClient+Boosts.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGClient (Boosts)

#pragma mark - boosts

- (void)availableChatBoostSlotsWithCompletion:(void (^)(NSArray *, NSString *))completion {
	[self request:@{@"@type" : @"getAvailableChatBoostSlots"}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *slot in result[@"slots"]){
			if (![slot isKindOfClass:NSDictionary.class])
				continue;
			[rows addObject:@{
				@"slotId" : TGAuditNumber(slot, @"slot_id"),
				@"currentlyBoostedChatId" : TGAuditNumber(slot, @"currently_boosted_chat_id"),
				@"startDate" : TGAuditNumber(slot, @"start_date"),
				@"expirationDate" : TGAuditNumber(slot, @"expiration_date"),
				@"cooldownUntilDate" : TGAuditNumber(slot, @"cooldown_until_date"),
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)chatBoostStatusForChat:(int64_t)chatId
					completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!chatId){
		if (completion) completion(nil, @"A chat id is needed.");
		return;
	}
	[self request:@{@"@type" : @"getChatBoostStatus", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSArray *slots = result[@"applied_slot_ids"];
		if (completion)
			completion(@{@"level" : TGAuditNumber(result, @"level"),
						 @"boostCount" : TGAuditNumber(result, @"boost_count"),
						 @"currentLevelBoostCount" : TGAuditNumber(result, @"current_level_boost_count"),
						 @"nextLevelBoostCount" : TGAuditNumber(result, @"next_level_boost_count"),
						 @"premiumMemberCount" : TGAuditNumber(result, @"premium_member_count"),
						 @"boostUrl" : TGAuditString(result, @"boost_url"),
						 @"appliedSlotIds" : ([slots isKindOfClass:NSArray.class] ? slots : @[])}, nil);
	}];
}

- (void)chatBoostFeaturesForChannel:(BOOL)isChannel
						 completion:(void (^)(NSDictionary *, NSString *))completion {
	[self request:@{@"@type" : @"getChatBoostFeatures", @"is_channel" : @(isChannel)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSArray *features = result[@"features"];
		if (completion)
			completion(@{@"levels" : @([features isKindOfClass:NSArray.class] ? features.count : 0),
						 @"minEmojiStatusBoostLevel" : TGAuditNumber(result, @"min_emoji_status_boost_level"),
						 @"minCustomBackgroundBoostLevel" : TGAuditNumber(result, @"min_custom_background_boost_level"),
						 @"minSpeechRecognitionBoostLevel" : TGAuditNumber(result, @"min_speech_recognition_boost_level"),
						 @"minSponsoredMessageDisableBoostLevel" : TGAuditNumber(result, @"min_sponsored_message_disable_boost_level")}, nil);
	}];
}

- (void)chatBoostLevelFeaturesForChannel:(BOOL)isChannel
								   level:(int32_t)level
							  completion:(void (^)(NSDictionary *, NSString *))completion {
	if (level < 0){
		if (completion) completion(nil, @"A boost level is needed.");
		return;
	}
	[self request:@{@"@type" : @"getChatBoostLevelFeatures",
					@"is_channel" : @(isChannel), @"level" : @(level)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"level" : TGAuditNumber(result, @"level"),
						 @"storyPerDay" : TGAuditNumber(result, @"story_per_day_count"),
						 @"customEmojiReactionCount" : TGAuditNumber(result, @"custom_emoji_reaction_count"),
						 @"canSetEmojiStatus" : @([result[@"can_set_emoji_status"] boolValue]),
						 @"canRecognizeSpeech" : @([result[@"can_recognize_speech"] boolValue]),
						 @"canDisableSponsoredMessages" : @([result[@"can_disable_sponsored_messages"] boolValue])}, nil);
	}];
}

- (void)chatBoostLinkForChat:(int64_t)chatId
				  completion:(void (^)(NSString *, NSString *))completion {
	if (!chatId){
		if (completion) completion(nil, @"A chat id is needed.");
		return;
	}
	[self request:@{@"@type" : @"getChatBoostLink", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditString(result, @"link"), nil);
	}];
}

- (void)chatBoostLinkInfo:(NSString *)url
			   completion:(void (^)(NSDictionary *, NSString *))completion {
	url = [url stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!url.length){
		if (completion) completion(nil, @"A boost link is needed.");
		return;
	}
	[self request:@{@"@type" : @"getChatBoostLinkInfo", @"url" : url}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"isPublic" : @([result[@"is_public"] boolValue]),
						 @"chatId" : TGAuditNumber(result, @"chat_id")}, nil);
	}];
}

- (void)chatBoostsForChat:(int64_t)chatId
				   offset:(NSString *)offset
					limit:(int32_t)limit
			   completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!chatId){
		if (completion) completion(nil, @"A chat id is needed.");
		return;
	}
	[self request:@{@"@type" : @"getChatBoosts",
					@"chat_id" : @(chatId),
					@"only_gift_codes" : @NO,
					@"offset" : (offset ?: @""),
					@"limit" : @(MAX((int32_t)1, MIN(limit, (int32_t)100)))}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *boost in result[@"boosts"]){
			if (![boost isKindOfClass:NSDictionary.class])
				continue;
			[rows addObject:@{
				@"id" : TGAuditString(boost, @"id"),
				@"count" : TGAuditNumber(boost, @"count"),
				@"startDate" : TGAuditNumber(boost, @"start_date"),
				@"expirationDate" : TGAuditNumber(boost, @"expiration_date"),
				@"source" : TGAuditShortType(boost[@"source"][@"@type"]),
			}];
		}
		if (completion)
			completion(@{@"boosts" : rows,
						 @"nextOffset" : TGAuditString(result, @"next_offset"),
						 @"totalCount" : TGAuditNumber(result, @"total_count")}, nil);
	}];
}

- (void)boostChat:(int64_t)chatId
		  slotIds:(NSArray *)slotIds
	   completion:(void (^)(NSArray *, NSString *))completion {
	if (!chatId || !slotIds.count){
		if (completion) completion(nil, @"A chat id and at least one slot id are needed.");
		return;
	}
	[self request:@{@"@type" : @"boostChat",
					@"chat_id" : @(chatId),
					@"slot_ids" : slotIds}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *slot in result[@"slots"]){
			if (![slot isKindOfClass:NSDictionary.class])
				continue;
			[rows addObject:@{@"slotId" : TGAuditNumber(slot, @"slot_id"),
							  @"currentlyBoostedChatId" : TGAuditNumber(slot, @"currently_boosted_chat_id")}];
		}
		if (completion) completion(rows, nil);
	}];
}

@end
