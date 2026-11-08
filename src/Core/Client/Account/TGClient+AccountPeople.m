#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountPeople.h"
#import "TGClient+AccountSupport.h"


/// Defined with the autosave reads below; the update branch above it only
/// needs the same flattening so both paths produce one row shape.
static NSDictionary *TGFlattenAutosaveScope(NSDictionary *settings);

/// TDLib names the three scopes; the app names them shortly.
static NSString *TGScopeType(NSString *scope) {
	if ([scope isEqualToString:@"groups"])   return @"notificationSettingsScopeGroupChats";
	if ([scope isEqualToString:@"channels"]) return @"notificationSettingsScopeChannelChats";
	return @"notificationSettingsScopePrivateChats";
}

/// Kept as a compatibility call into the pure gift flattening utility.
static NSDictionary *TGFlattenGift(NSDictionary *entry) {
	return TGFlattenReceivedGift(entry);
}


static NSArray *TGPacksFrom(NSDictionary *target) {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *pack in target[@"language_packs"]){
		if (![pack[@"id"] length])
			continue;
		[out addObject:@{@"id"   : pack[@"id"],
						 @"name" : pack[@"native_name"] ?: pack[@"name"] ?: pack[@"id"]}];
	}
	return out;
}





@implementation TGClient (AccountPeople)

#pragma mark - people

- (void)setUser:(int64_t)userId blocked:(BOOL)blocked {
	// Chat ids are negative; a blocked channel has to be named as a chat, or
	// the unblock goes to a user id that does not exist.
	NSDictionary *sender = userId < 0
			? @{@"@type" : @"messageSenderChat", @"chat_id" : @(userId)}
			: @{@"@type" : @"messageSenderUser", @"user_id" : @(userId)};
	[self send:@{
		@"@type"      : @"setMessageSenderBlockList",
		@"sender_id"  : sender,
		// A null block list is how TDLib spells "not blocked".
		@"block_list" : blocked ? @{@"@type" : @"blockListMain"} : [NSNull null],
	}];
}

- (void)isUserBlocked:(int64_t)userId completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"getUserFullInfo", @"user_id" : @(userId)}
	   completion:^(NSDictionary *full){
		if (completion)
			completion([full[@"block_list"] isKindOfClass:NSDictionary.class]);
	}];
}

- (void)giftsForUser:(int64_t)userId completion:(void (^)(NSArray *))completion {
	[self giftsForOwner:@{@"@type" : @"messageSenderUser", @"user_id" : @(userId)}
				 offset:@""
			 completion:^(NSArray *gifts, NSString *nextOffset, NSInteger totalCount){
		if (completion)
			completion(gifts);
	}];
}

- (void)giftsForOwner:(NSDictionary *)ownerId
			   offset:(NSString *)offset
		   completion:(void (^)(NSArray *gifts, NSString *nextOffset, NSInteger totalCount))completion {
	NSMutableDictionary *query = [NSMutableDictionary dictionaryWithDictionary:@{
		@"@type" : @"getReceivedGifts",
		@"limit" : @(50),
		@"offset": offset ?: @"",
	}];
	if (ownerId)
		query[@"owner_id"] = ownerId;

	[self request:query completion:^(NSDictionary *result){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *entry in result[@"gifts"]){
			if (![entry isKindOfClass:NSDictionary.class])
				continue;
			NSDictionary *flat = TGFlattenReceivedGift(entry);
			if (flat)
				[out addObject:flat];
		}
		NSString *nextOffset = [result[@"next_offset"] isKindOfClass:NSString.class]
				? result[@"next_offset"] : @"";
		NSInteger totalCount = [result[@"total_count"] respondsToSelector:@selector(integerValue)]
				? [result[@"total_count"] integerValue] : (NSInteger)out.count;
		if (completion)
			completion(out, nextOffset, totalCount);
	}];
}

- (void)premiumStateWithCompletion:(void (^)(NSString *))completion {
	[self request:@{@"@type" : @"getPremiumState"} completion:^(NSDictionary *state){
		NSDictionary *me = self.me;
		if (![me[@"is_premium"] boolValue]){
			if (completion) completion(nil);
			return;
		}
		// The state carries what is active; a date is the useful part of it.
		NSNumber *until = state[@"state"][@"expiration_date"] ?: state[@"expiration_date"];
		if (!until.doubleValue){
			if (completion) completion(@"Active");
			return;
		}
		static NSDateFormatter *fmt = nil;
		if (!fmt){
			fmt = [[NSDateFormatter alloc] init];
			[fmt setDateFormat:@"d MMM yyyy"];
		}
		if (completion)
			completion([NSString stringWithFormat:@"Until %@", [fmt stringFromDate:
					[NSDate dateWithTimeIntervalSince1970:until.doubleValue]]]);
	}];
}


@end
