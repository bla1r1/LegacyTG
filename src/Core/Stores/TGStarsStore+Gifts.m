//
// TGStarsStore+Gifts.m - the Stars store's Gifts requests.
//
// Bodies copied from src/Core/Client/Audit/TGClient+Gifts.m; the store owns them.
//

#import "TGStarsStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGStarsStore (Gifts)

#pragma mark - gifts

- (void)availableGiftsWithCompletion:(void (^)(NSArray *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getAvailableGifts"} completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *available in result[@"gifts"]){
			if (![available isKindOfClass:NSDictionary.class])
				continue;
			NSDictionary *gift = available[@"gift"];
			[rows addObject:@{
				@"id" : TGAuditNumber(gift, @"id"),
				@"title" : TGAuditString(available, @"title"),
				@"starCount" : TGAuditNumber(gift, @"star_count"),
				@"resaleCount" : TGAuditNumber(available, @"resale_count"),
				@"minResaleStarCount" : TGAuditNumber(available, @"min_resale_star_count"),
				@"emoji" : TGAuditString(gift[@"sticker"], @"emoji"),
				@"isPremium" : @([gift[@"is_premium"] boolValue]),
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)canSendGift:(int64_t)giftId
		 completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!giftId){
		if (completion) completion(nil, @"A gift id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"canSendGift", @"gift_id" : @(giftId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSString *word = TGAuditShortType(result[@"@type"]);
		NSString *reason = TGAuditString(result[@"reason"], @"text");
		if (completion)
			completion(@{@"type" : word, @"reason" : reason}, nil);
	}];
}

- (void)receivedGift:(NSString *)receivedGiftId
		  completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!receivedGiftId.length){
		if (completion) completion(nil, @"A received gift id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getReceivedGift",
					@"received_gift_id" : receivedGiftId}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSDictionary *gift = result[@"gift"];
		if (completion)
			completion(@{@"receivedGiftId" : TGAuditString(result, @"received_gift_id"),
						 @"date" : TGAuditNumber(result, @"date"),
						 @"isSaved" : @([result[@"is_saved"] boolValue]),
						 @"isPinned" : @([result[@"is_pinned"] boolValue]),
						 @"canBeUpgraded" : @([result[@"can_be_upgraded"] boolValue]),
						 @"canBeTransferred" : @([result[@"can_be_transferred"] boolValue]),
						 @"canBeDeleted" : @([result[@"can_be_deleted"] boolValue]),
						 @"starCount" : TGAuditNumber(gift, @"star_count"),
						 @"emoji" : TGAuditString(gift[@"sticker"], @"emoji"),
						 @"text" : TGAuditString(result[@"text"], @"text")}, nil);
	}];
}

- (void)upgradedGiftNamed:(NSString *)name
			   completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!name.length){
		if (completion) completion(nil, @"A gift name is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getUpgradedGift", @"name" : name}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"name" : TGAuditString(result, @"name"),
						 @"title" : TGAuditString(result, @"title"),
						 @"number" : TGAuditNumber(result, @"number"),
						 @"isPremium" : @([result[@"is_premium"] boolValue]),
						 @"model" : TGAuditString(result[@"model"], @"name"),
						 @"symbol" : TGAuditString(result[@"symbol"], @"name"),
						 @"valueCurrency" : TGAuditString(result, @"value_currency"),
						 @"valueAmount" : TGAuditNumber(result, @"value_amount"),
						 @"valueUsdAmount" : TGAuditNumber(result, @"value_usd_amount")}, nil);
	}];
}

- (void)upgradedGiftValueInfoNamed:(NSString *)name
						completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!name.length){
		if (completion) completion(nil, @"A gift name is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getUpgradedGiftValueInfo", @"name" : name}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"currency" : TGAuditString(result, @"currency"),
						 @"value" : TGAuditNumber(result, @"value"),
						 @"isValueAverage" : @([result[@"is_value_average"] boolValue]),
						 @"minimumPrice" : TGAuditNumber(result, @"minimum_price"),
						 @"averageSalePrice" : TGAuditNumber(result, @"average_sale_price"),
						 @"fragmentUrl" : TGAuditString(result, @"fragment_url")}, nil);
	}];
}

- (void)upgradedGiftVariantsForGift:(int64_t)regularGiftId
					   completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!regularGiftId){
		if (completion) completion(nil, @"A regular gift id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getUpgradedGiftVariants",
					@"regular_gift_id" : @(regularGiftId),
					@"return_upgrade_models" : @YES,
					@"return_craft_models" : @YES}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSArray *models = result[@"models"];
		NSArray *symbols = result[@"symbols"];
		NSArray *backdrops = result[@"backdrops"];
		if (completion)
			completion(@{@"models" : ([models isKindOfClass:NSArray.class] ? models : @[]),
						 @"symbols" : ([symbols isKindOfClass:NSArray.class] ? symbols : @[]),
						 @"backdrops" : ([backdrops isKindOfClass:NSArray.class] ? backdrops : @[])}, nil);
	}];
}

- (void)giftUpgradePreviewForGift:(int64_t)regularGiftId
					   completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!regularGiftId){
		if (completion) completion(nil, @"A regular gift id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getGiftUpgradePreview",
					@"regular_gift_id" : @(regularGiftId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSArray *models = result[@"models"];
		NSArray *symbols = result[@"symbols"];
		NSArray *backdrops = result[@"backdrops"];
		NSArray *prices = result[@"prices"];
		if (completion)
			completion(@{@"models" : ([models isKindOfClass:NSArray.class] ? models : @[]),
						 @"symbols" : ([symbols isKindOfClass:NSArray.class] ? symbols : @[]),
						 @"backdrops" : ([backdrops isKindOfClass:NSArray.class] ? backdrops : @[]),
						 @"prices" : ([prices isKindOfClass:NSArray.class] ? prices : @[])}, nil);
	}];
}

- (void)giftCollectionsForOwner:(NSString *)ownerKind
						ownerId:(int64_t)ownerId
					 completion:(void (^)(NSArray *, NSString *))completion {
	if (!ownerId){
		if (completion) completion(nil, @"An owner id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getGiftCollections",
					@"owner_id" : TGAuditSender(ownerKind, ownerId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *collection in result[@"collections"]){
			if (![collection isKindOfClass:NSDictionary.class])
				continue;
			[rows addObject:@{
				@"id" : TGAuditNumber(collection, @"id"),
				@"name" : TGAuditString(collection, @"name"),
				@"giftCount" : TGAuditNumber(collection, @"gift_count"),
				@"emoji" : TGAuditString(collection[@"icon"], @"emoji"),
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)giftsForCraftingFromGift:(int64_t)regularGiftId
						  offset:(NSString *)offset
						   limit:(int32_t)limit
					  completion:(void (^)(NSArray *, NSString *))completion {
	if (!regularGiftId){
		if (completion) completion(nil, @"A regular gift id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getGiftsForCrafting",
					@"regular_gift_id" : @(regularGiftId),
					@"offset" : (offset ?: @""),
					@"limit" : @(MAX((int32_t)1, MIN(limit, (int32_t)100)))}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *gift in result[@"gifts"]){
			if ([gift isKindOfClass:NSDictionary.class])
				[rows addObject:@{@"receivedGiftId" : TGAuditString(gift, @"received_gift_id"),
								  @"date" : TGAuditNumber(gift, @"date")}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)searchGiftsForResaleFromGift:(int64_t)regularGiftId
							   order:(NSString *)order
						  offset:(NSString *)offset
						   limit:(int32_t)limit
					  completion:(void (^)(NSArray *, NSString *))completion {
	if (!regularGiftId){
		if (completion) completion(nil, @"A regular gift id is needed.");
		return;
	}
	NSString *orderType = [order hasPrefix:@"giftForResaleOrder"]
			? order : @"giftForResaleOrderPrice";
	[[TGClient shared] request:@{@"@type" : @"searchGiftsForResale",
					@"gift_id" : @(regularGiftId),
					@"order" : @{@"@type" : orderType},
					@"for_crafting" : @NO,
					@"for_stars" : @YES,
					@"attributes" : @[],
					@"offset" : (offset ?: @""),
					@"limit" : @(MAX((int32_t)1, MIN(limit, (int32_t)100)))}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *row in result[@"gifts"]){
			if (![row isKindOfClass:NSDictionary.class])
				continue;
			NSDictionary *gift = row[@"gift"];
			[rows addObject:@{
				@"receivedGiftId" : TGAuditString(row, @"received_gift_id"),
				@"name" : TGAuditString(gift, @"name"),
				@"title" : TGAuditString(gift, @"title"),
				@"number" : TGAuditNumber(gift, @"number"),
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)upgradedGiftEmojiStatusesWithCompletion:(void (^)(NSArray *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getUpgradedGiftEmojiStatuses"}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *status in result[@"emoji_statuses"]){
			if (![status isKindOfClass:NSDictionary.class])
				continue;
			NSDictionary *type = status[@"type"];
			[rows addObject:@{
				@"type" : TGAuditShortType(type[@"@type"]),
				@"expirationDate" : TGAuditNumber(status, @"expiration_date"),
				@"giftTitle" : TGAuditString(type, @"gift_title"),
				@"giftName" : TGAuditString(type, @"gift_name"),
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)giftChatThemesWithOffset:(NSString *)offset
						   limit:(int32_t)limit
					  completion:(void (^)(NSArray *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getGiftChatThemes",
					@"offset" : (offset ?: @""),
					@"limit" : @(MAX((int32_t)1, MIN(limit, (int32_t)100)))}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *theme in result[@"themes"]){
			if (![theme isKindOfClass:NSDictionary.class])
				continue;
			[rows addObject:@{@"giftName" : TGAuditString(theme[@"gift"], @"name"),
							  @"giftTitle" : TGAuditString(theme[@"gift"], @"title")}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)giftAuctionStateForAuction:(NSString *)auctionId
						completion:(void (^)(NSDictionary *, NSString *))completion {
	auctionId = [auctionId stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!auctionId.length){
		if (completion) completion(nil, @"An auction id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getGiftAuctionState", @"auction_id" : auctionId}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSDictionary *state = result[@"state"];
		if (completion)
			completion(@{@"state" : TGAuditShortType(state[@"@type"]),
						 @"startDate" : TGAuditNumber(state, @"start_date"),
						 @"endDate" : TGAuditNumber(state, @"end_date"),
						 @"minBid" : TGAuditNumber(state, @"min_bid"),
						 @"currentRoundEndDate" : TGAuditNumber(state, @"current_round_end_date"),
						 @"currentRoundNumber" : TGAuditNumber(state, @"current_round_number"),
						 @"totalRoundCount" : TGAuditNumber(state, @"total_round_count"),
						 @"leftItemCount" : TGAuditNumber(state, @"left_item_count"),
						 @"giftTitle" : TGAuditString(result[@"gift"], @"title")}, nil);
	}];
}

- (void)giftAuctionAcquiredGiftsForGift:(int64_t)giftId
							 completion:(void (^)(NSArray *, NSString *))completion {
	if (!giftId){
		if (completion) completion(nil, @"A gift id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getGiftAuctionAcquiredGifts", @"gift_id" : @(giftId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *gift in result[@"gifts"]){
			if (![gift isKindOfClass:NSDictionary.class])
				continue;
			[rows addObject:@{
				@"date" : TGAuditNumber(gift, @"date"),
				@"starCount" : TGAuditNumber(gift, @"star_count"),
				@"roundNumber" : TGAuditNumber(gift, @"auction_round_number"),
				@"uniqueGiftNumber" : TGAuditNumber(gift, @"unique_gift_number"),
				@"receiverKind" : TGAuditShortType(gift[@"receiver_id"][@"@type"]),
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)openGiftAuctionForGift:(int64_t)giftId
					completion:(void (^)(BOOL, NSString *))completion {
	if (!giftId){
		if (completion) completion(NO, @"A gift id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"openGiftAuction", @"gift_id" : @(giftId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)closeGiftAuctionForGift:(int64_t)giftId
					 completion:(void (^)(BOOL, NSString *))completion {
	if (!giftId){
		if (completion) completion(NO, @"A gift id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"closeGiftAuction", @"gift_id" : @(giftId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}
- (void)upgradedGiftsPromotionalAnimationWithCompletion:
		(void (^)(NSDictionary *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getUpgradedGiftsPromotionalAnimation"}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(result, nil);
	}];
}

@end
