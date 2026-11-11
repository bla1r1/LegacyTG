//
// TGGroupStore+Community.m - copied from TGClient+Communities.m for the group store.
//
#import "TGGroupStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"

#import "TGClient+Communities.h"
#import "TGClientInternal.h"
#import "TGClient+FeatureSupport.h"

@implementation TGGroupStore (Communities)

#pragma mark - communities

- (NSArray *)communities {
	NSMutableArray *out = [NSMutableArray array];
	for (NSNumber *ident in [TGClient shared].communityOrder){
		NSDictionary *row = [TGClient shared].communitiesById[ident];
		if (row)
			[out addObject:row];
	}
	return out;
}

- (NSDictionary *)cachedCommunityFullInfo:(int64_t)communityId {
	NSDictionary *info = [TGClient shared].communityFullInfoById[@(communityId)];
	return [info isKindOfClass:NSDictionary.class] ? info : nil;
}

- (void)createCommunity:(NSString *)name
                 chatId:(int64_t)chatId
                 hidden:(BOOL)hidden
             completion:(void (^)(int64_t, NSString *))completion {
	NSString *clean = [name stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!clean.length || !chatId){
		if (completion)
			completion(0, @"A community needs a name and a chat.");
		return;
	}
	[[TGClient shared] request:@{
		@"@type"         : @"createCommunity",
		@"name"          : clean,
		@"chat_id"       : @(chatId),
		@"is_chat_hidden": @(hidden),
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		int64_t communityId = ok ? [result[@"id"] longLongValue] : 0;
		if (completion)
			completion(communityId, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)communityFullInfo:(int64_t)communityId
               completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!communityId){
		if (completion)
			completion(nil, @"No community was chosen.");
		return;
	}
	__weak TGClient *weakSelf = [TGClient shared];
	[[TGClient shared] request:@{
		@"@type"        : @"getCommunityFullInfo",
		@"community_id" : @(communityId),
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(nil, TGFeatureErrorText(result));
			return;
		}
		NSMutableArray *chats = [NSMutableArray array];
		for (NSDictionary *chat in TGFeatureArray(result[@"chats"])){
			int64_t chatId = [chat[@"chat_id"] longLongValue];
			if (!chatId)
				continue;
			[chats addObject:[@{
				@"chatId"        : @(chatId),
				@"title"         : TGFeatureChatTitle(chatId) ?: [NSString stringWithFormat:
										@"Chat %lld", (long long)chatId],
				@"canViewHistory": chat[@"can_view_history"] ?: @NO,
				@"hidden"        : chat[@"is_hidden"] ?: @NO,
			} mutableCopy]];
		}
		NSDictionary *info = @{
			@"photoFileId"         : TGFeaturePhotoFileId(result[@"photo"]) ?: @(0),
			@"chats"               : chats,
			@"administratorCount"  : result[@"administrator_count"] ?: @(0),
			@"bannedCount"         : result[@"banned_count"] ?: @(0),
			@"addChatRequestCount" : result[@"add_chat_request_count"] ?: @(0),
		};
		weakSelf.communityFullInfoById[@(communityId)] = info;
		if (completion)
			completion(info, nil);
	}];
}

- (void)setCommunityName:(int64_t)communityId
                    name:(NSString *)name
              completion:(void (^)(BOOL, NSString *))completion {
	NSString *clean = [name stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!clean.length){
		if (completion)
			completion(NO, @"A community needs a name.");
		return;
	}
	[[TGClient shared] request:@{
		@"@type"        : @"setCommunityName",
		@"community_id" : @(communityId),
		@"name"         : clean,
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (ok && communityId){
			NSMutableDictionary *row = [TGClient shared].communitiesById[@(communityId)];
			if (row)
				row[@"name"] = clean;
		}
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)setCommunityPhoto:(int64_t)communityId
                     path:(NSString *)path
               completion:(void (^)(BOOL, NSString *))completion {
	NSDictionary *photo = path.length
			? @{@"@type" : @"inputChatPhotoStatic",
				@"photo" : @{@"@type" : @"inputFileLocal", @"path" : path}}
			: [NSNull null];
	[[TGClient shared] request:@{
		@"@type"        : @"setCommunityPhoto",
		@"community_id" : @(communityId),
		@"photo"        : photo,
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)setCommunityPermissions:(int64_t)communityId
                  canEditChatList:(BOOL)canEditChatList
                      completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{
		@"@type"        : @"setCommunityPermissions",
		@"community_id" : @(communityId),
		@"permissions"  : @{
			@"@type"             : @"communityPermissions",
			@"can_edit_chat_list": @(canEditChatList),
		},
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (ok && communityId){
			NSMutableDictionary *row = [TGClient shared].communitiesById[@(communityId)];
			if (row)
				row[@"canEditChatList"] = @(canEditChatList);
		}
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)deleteCommunity:(int64_t)communityId
             completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{
		@"@type"        : @"deleteCommunity",
		@"community_id" : @(communityId),
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (ok && communityId){
			[[TGClient shared].communitiesById removeObjectForKey:@(communityId)];
			[[TGClient shared].communityOrder removeObject:@(communityId)];
			[[TGClient shared].communityFullInfoById removeObjectForKey:@(communityId)];
		}
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}


#pragma mark - update cache

- (void)applyCommunityUpdate:(NSDictionary *)update {
	NSDictionary *community = TGFeatureDict(update[@"community"]);
	NSNumber *ident = community[@"id"];
	if (![ident isKindOfClass:NSNumber.class])
		return;
	if (![TGClient shared].communitiesById)
		[TGClient shared].communitiesById = [NSMutableDictionary dictionary];
	if (![TGClient shared].communityOrder)
		[TGClient shared].communityOrder = [NSMutableArray array];
	NSDictionary *row = @{
		@"id"             : ident,
		@"name"           : community[@"name"] ?: @"",
		@"haveAccess"     : community[@"have_access"] ?: @NO,
		@"date"           : community[@"date"] ?: @(0),
		@"status"         : TGFeatureCommunityStatus(TGFeatureDict(community[@"status"])),
		@"photoFileId"    : TGFeaturePhotoFileId(community[@"photo"]) ?: @(0),
		@"canEditChatList": TGFeatureDict(community[@"permissions"])[@"can_edit_chat_list"] ?: @NO,
	};
	[TGClient shared].communitiesById[ident] = [row mutableCopy];
	if (![[TGClient shared].communityOrder containsObject:ident])
		[[TGClient shared].communityOrder insertObject:ident atIndex:0];
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGCommunitiesChangedNotification object:nil];
}

- (void)applyCommunityFullInfoUpdate:(NSDictionary *)update {
	NSNumber *ident = update[@"community_id"];
	NSDictionary *info = TGFeatureDict(update[@"community_full_info"]);
	if (![ident isKindOfClass:NSNumber.class] || !info.count)
		return;
	if (![TGClient shared].communityFullInfoById)
		[TGClient shared].communityFullInfoById = [NSMutableDictionary dictionary];
	NSMutableArray *chats = [NSMutableArray array];
	for (NSDictionary *chat in TGFeatureArray(info[@"chats"])){
		int64_t chatId = [chat[@"chat_id"] longLongValue];
		if (!chatId)
			continue;
		[chats addObject:[@{
			@"chatId"        : @(chatId),
			@"title"         : TGFeatureChatTitle(chatId) ?: [NSString stringWithFormat:
									@"Chat %lld", (long long)chatId],
			@"canViewHistory": chat[@"can_view_history"] ?: @NO,
			@"hidden"        : chat[@"is_hidden"] ?: @NO,
		} mutableCopy]];
	}
	[TGClient shared].communityFullInfoById[ident] = @{
		@"photoFileId"         : TGFeaturePhotoFileId(info[@"photo"]) ?: @(0),
		@"chats"               : chats,
		@"administratorCount"  : info[@"administrator_count"] ?: @(0),
		@"bannedCount"         : info[@"banned_count"] ?: @(0),
		@"addChatRequestCount" : info[@"add_chat_request_count"] ?: @(0),
	};
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGCommunitiesChangedNotification object:nil];
}


@end

// vim:ft=objc
