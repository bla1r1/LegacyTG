//
// TGStarsStore+Premium.m - the Stars store's Premium requests.
//
// Bodies copied from src/Core/Client/Audit/TGClient+Premium.m; the store owns them.
//

#import "TGStarsStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGStarsStore (Premium)

#pragma mark - Premium

- (void)premiumFeaturesFromSource:(NSString *)source
					   completion:(void (^)(NSDictionary *, NSString *))completion {
	NSDictionary *sourceObject = nil;
	if ([source hasPrefix:@"premiumSource"]){
		sourceObject = @{@"@type" : source};
	} else if ([source length]){
		sourceObject = @{@"@type" : @"premiumSourceLink", @"referrer" : source};
	}
	NSMutableDictionary *request = [@{@"@type" : @"getPremiumFeatures"} mutableCopy];
	request[@"source"] = sourceObject ?: [NSNull null];
	[[TGClient shared] request:request completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *features = [NSMutableArray array];
		for (NSDictionary *feature in result[@"features"]){
			if ([feature isKindOfClass:NSDictionary.class])
				[features addObject:TGAuditShortType(feature[@"@type"])];
		}
		NSMutableArray *limits = [NSMutableArray array];
		for (NSDictionary *limit in result[@"limits"]){
			if (![limit isKindOfClass:NSDictionary.class])
				continue;
			[limits addObject:@{
				@"type" : TGAuditShortType(limit[@"type"][@"@type"]),
				@"defaultValue" : TGAuditNumber(limit, @"default_value"),
				@"premiumValue" : TGAuditNumber(limit, @"premium_value"),
			}];
		}
		if (completion)
			completion(@{@"features" : features,
						 @"limits" : limits,
						 @"paymentLink" : TGAuditShortType(result[@"payment_link"][@"@type"])}, nil);
	}];
}

- (void)viewPremiumFeature:(NSString *)featureType
				completion:(void (^)(BOOL, NSString *))completion {
	featureType = [featureType stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!featureType.length){
		if (completion) completion(NO, @"A Premium feature is needed.");
		return;
	}
	if (![featureType hasPrefix:@"premiumFeature"])
		featureType = TGAuditPrefixedType(@"premiumFeature", featureType);
	[[TGClient shared] request:@{@"@type" : @"viewPremiumFeature",
					@"feature" : @{@"@type" : featureType}}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)premiumLimitOfType:(NSString *)limitType
				completion:(void (^)(NSDictionary *, NSString *))completion {
	limitType = [limitType stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!limitType.length){
		if (completion) completion(nil, @"A Premium limit type is needed.");
		return;
	}
	if (![limitType hasPrefix:@"premiumLimitType"])
		limitType = TGAuditPrefixedType(@"premiumLimitType", limitType);
	[[TGClient shared] request:@{@"@type" : @"getPremiumLimit",
					@"limit_type" : @{@"@type" : limitType}}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"type" : TGAuditShortType(result[@"type"][@"@type"]),
						 @"defaultValue" : TGAuditNumber(result, @"default_value"),
						 @"premiumValue" : TGAuditNumber(result, @"premium_value")}, nil);
	}];
}

- (void)premiumStickersWithLimit:(int32_t)limit
					  completion:(void (^)(NSArray *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getPremiumStickers",
					@"limit" : @(MAX((int32_t)0, MIN(limit, (int32_t)100)))}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *sticker in result[@"stickers"]){
			if ([sticker isKindOfClass:NSDictionary.class])
				[rows addObject:TGAuditSticker(sticker)];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)premiumStickerExamplesWithCompletion:(void (^)(NSArray *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getPremiumStickerExamples"}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *sticker in result[@"stickers"]){
			if ([sticker isKindOfClass:NSDictionary.class])
				[rows addObject:TGAuditSticker(sticker)];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)premiumInfoStickerForMonths:(int32_t)months
						 completion:(void (^)(NSDictionary *, NSString *))completion {
	if (months <= 0){
		if (completion) completion(nil, @"A month count is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getPremiumInfoSticker", @"month_count" : @(months)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditSticker(result), nil);
	}];
}

- (void)checkPremiumGiftCode:(NSString *)code
				  completion:(void (^)(NSDictionary *, NSString *))completion {
	code = [code stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!code.length){
		if (completion) completion(nil, @"A code is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"checkPremiumGiftCode", @"code" : code}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"monthCount" : TGAuditNumber(result, @"month_count"),
						 @"dayCount" : TGAuditNumber(result, @"day_count"),
						 @"isFromGiveaway" : @([result[@"is_from_giveaway"] boolValue]),
						 @"userId" : TGAuditNumber(result, @"user_id"),
						 @"useDate" : TGAuditNumber(result, @"use_date")}, nil);
	}];
}

- (void)applyPremiumGiftCode:(NSString *)code
				  completion:(void (^)(BOOL, NSString *))completion {
	code = [code stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!code.length){
		if (completion) completion(NO, @"A code is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"applyPremiumGiftCode", @"code" : code}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)clickPremiumSubscriptionButtonWithCompletion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"clickPremiumSubscriptionButton"}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

@end
