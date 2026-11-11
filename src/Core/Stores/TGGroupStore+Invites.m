//
// TGGroupStore+Invites.m - copied from TGClient+ChatTools.m for the group store.
//
#import "TGGroupStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"


@implementation TGGroupStore (Invites)

- (void)inviteLinkCountsForChat:(int64_t)chatId
					 completion:(void (^)(NSArray *counts))completion {
	[[TGClient shared] request:@{@"@type" : @"getChatInviteLinkCounts", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		__weak TGClient *weakSelf = [TGClient shared];
		TGClient *me = weakSelf;
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *count in result[@"invite_link_counts"]){
			if (![count isKindOfClass:NSDictionary.class])
				continue;
			NSNumber *userId = count[@"user_id"] ?: @(0);
			[out addObject:@{
				@"id"      : userId,
				@"name"    : [me nameForUserId:userId.longLongValue] ?: @"Administrator",
				@"active"  : count[@"invite_link_count"] ?: @(0),
				@"revoked" : count[@"revoked_invite_link_count"] ?: @(0),
			}];
		}
		if (completion)
			completion(out);
	}];
}

- (void)membersOfInviteLink:(NSString *)link
					 inChat:(int64_t)chatId
				 completion:(void (^)(NSArray *members))completion {
	[[TGClient shared] request:@{
		@"@type" : @"getChatInviteLinkMembers",
		@"chat_id" : @(chatId),
		@"invite_link" : link ?: @"",
		@"only_with_expired_subscription" : @NO,
		@"offset_member" : [NSNull null],
		@"limit" : @(100),
	} completion:^(NSDictionary *result){
		__weak TGClient *weakSelf = [TGClient shared];
		TGClient *me = weakSelf;
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *member in result[@"members"]){
			if (![member isKindOfClass:NSDictionary.class])
				continue;
			NSNumber *userId = member[@"user_id"] ?: @(0);
			[out addObject:@{
				@"id"       : userId,
				@"name"     : [me nameForUserId:userId.longLongValue] ?: @"Member",
				@"date"     : member[@"joined_chat_date"] ?: @(0),
				@"approver" : member[@"approver_user_id"] ?: @(0),
			}];
		}
		if (completion)
			completion(out);
	}];
}

- (void)createSubscriptionInviteLink:(int64_t)chatId
								name:(NSString *)name
							   stars:(NSInteger)stars
							  period:(NSInteger)period
						  completion:(void (^)(NSString *link))completion {
	[[TGClient shared] request:@{
		@"@type" : @"createChatSubscriptionInviteLink",
		@"chat_id" : @(chatId),
		@"name" : name ?: @"",
		@"subscription_pricing" : @{
			@"@type" : @"starSubscriptionPricing",
			@"period" : @(period > 0 ? period : 2592000),
			@"star_count" : @(MAX(stars, 1)),
		},
	} completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"@type"] isEqualToString:@"chatInviteLink"]
					? (result[@"invite_link"] ?: @"") : @"");
	}];
}

- (void)editSubscriptionInviteLink:(NSString *)link
							inChat:(int64_t)chatId
							  name:(NSString *)name
						completion:(void (^)(BOOL ok))completion {
	if (!link.length){
		if (completion) completion(NO);
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"editChatSubscriptionInviteLink",
					@"chat_id" : @(chatId), @"invite_link" : link,
					@"name" : name ?: @""}
	   completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"@type"] isEqualToString:@"chatInviteLink"]);
	}];
}

- (void)editInviteLink:(NSString *)link
				inChat:(int64_t)chatId
				  name:(NSString *)name
			expiration:(NSInteger)expiration
		   memberLimit:(NSInteger)memberLimit
		   joinRequest:(BOOL)joinRequest
			completion:(void (^)(BOOL ok))completion {
	if (!link.length){
		if (completion) completion(NO);
		return;
	}
	[[TGClient shared] request:@{
		@"@type" : @"editChatInviteLink",
		@"chat_id" : @(chatId),
		@"invite_link" : link,
		@"name" : name ?: @"",
		@"expiration_date" : @(expiration),
		// TDLib refuses a member limit on a link that also asks for approval.
		@"member_limit" : @(joinRequest ? 0 : memberLimit),
		@"creates_join_request" : @(joinRequest),
	} completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"@type"] isEqualToString:@"chatInviteLink"]);
	}];
}

- (void)deleteRevokedInviteLink:(NSString *)link
						 inChat:(int64_t)chatId
					 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] request:@{@"@type" : @"deleteRevokedChatInviteLink",
					@"chat_id" : @(chatId), @"invite_link" : link ?: @""}
	   completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)deleteAllRevokedInviteLinks:(int64_t)chatId
							creator:(int64_t)creatorId
						 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] request:@{@"@type" : @"deleteAllRevokedChatInviteLinks",
					@"chat_id" : @(chatId),
					@"creator_user_id" : @(creatorId)}
	   completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)inviteLink:(NSString *)link
			inChat:(int64_t)chatId
		completion:(void (^)(NSDictionary *info))completion {
	if (!link.length){
		if (completion) completion(nil);
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getChatInviteLink", @"chat_id" : @(chatId),
					@"invite_link" : link}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"chatInviteLink"]){
			if (completion) completion(nil);
			return;
		}
		if (completion)
			completion(@{
				@"link"        : result[@"invite_link"] ?: @"",
				@"name"        : result[@"name"] ?: @"",
				@"members"     : result[@"member_count"] ?: @(0),
				@"memberLimit" : result[@"member_limit"] ?: @(0),
				@"expiration"  : result[@"expiration_date"] ?: @(0),
				@"requests"    : result[@"pending_join_request_count"] ?: @(0),
				@"joinRequest" : result[@"creates_join_request"] ?: @NO,
				@"primary"     : result[@"is_primary"] ?: @NO,
				@"revoked"     : result[@"is_revoked"] ?: @NO,
				@"subscription": result[@"subscription_pricing"] ?: [NSNull null],
			});
	}];
}

- (void)setMemberTag:(NSString *)tag
			  forUser:(int64_t)userId
			   inChat:(int64_t)chatId
		   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] request:@{@"@type" : @"setChatMemberTag", @"chat_id" : @(chatId),
					@"user_id" : @(userId), @"tag" : tag ?: @""}
	   completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}


@end

// vim:ft=objc
