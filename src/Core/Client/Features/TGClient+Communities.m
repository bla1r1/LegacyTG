#import "TGClient+Communities.h"
#import "TGClientInternal.h"
#import "TGClient+FeatureSupport.h"

@implementation TGClient (Communities)

#pragma mark - communities

- (void)communityFullInfo:(int64_t)communityId
               completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!communityId){
		if (completion)
			completion(nil, @"No community was chosen.");
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{
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

#pragma mark - update cache

- (void)applyCommunityUpdate:(NSDictionary *)update {
	NSDictionary *community = TGFeatureDict(update[@"community"]);
	NSNumber *ident = community[@"id"];
	if (![ident isKindOfClass:NSNumber.class])
		return;
	if (!self.communitiesById)
		self.communitiesById = [NSMutableDictionary dictionary];
	if (!self.communityOrder)
		self.communityOrder = [NSMutableArray array];
	NSDictionary *row = @{
		@"id"             : ident,
		@"name"           : community[@"name"] ?: @"",
		@"haveAccess"     : community[@"have_access"] ?: @NO,
		@"date"           : community[@"date"] ?: @(0),
		@"status"         : TGFeatureCommunityStatus(TGFeatureDict(community[@"status"])),
		@"photoFileId"    : TGFeaturePhotoFileId(community[@"photo"]) ?: @(0),
		@"canEditChatList": TGFeatureDict(community[@"permissions"])[@"can_edit_chat_list"] ?: @NO,
	};
	self.communitiesById[ident] = [row mutableCopy];
	if (![self.communityOrder containsObject:ident])
		[self.communityOrder insertObject:ident atIndex:0];
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGCommunitiesChangedNotification object:nil];
}

- (void)applyCommunityFullInfoUpdate:(NSDictionary *)update {
	NSNumber *ident = update[@"community_id"];
	NSDictionary *info = TGFeatureDict(update[@"community_full_info"]);
	if (![ident isKindOfClass:NSNumber.class] || !info.count)
		return;
	if (!self.communityFullInfoById)
		self.communityFullInfoById = [NSMutableDictionary dictionary];
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
	self.communityFullInfoById[ident] = @{
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
