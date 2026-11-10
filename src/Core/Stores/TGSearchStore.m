//
// TGSearchStore.m - the search screen's seam.
//
#import "TGSearchStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+Accounts.h"
#import "TGChatListStore.h"
#import "TGMessageStore.h"

@implementation TGSearchStore

+ (instancetype)shared {
	static TGSearchStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ store = [[TGSearchStore alloc] init]; });
	return store;
}

- (NSArray *)chats { return [TGChatListStore shared].chats; }

- (void)topChatsWithCompletion:(void (^)(NSArray *))completion {
	[[TGClient shared] topChatsWithCompletion:completion];
}

- (void)recentlyOpenedChatsWithCompletion:(void (^)(NSArray *))completion {
	[[TGClient shared] recentlyOpenedChatsWithCompletion:completion];
}

- (void)searchRecentlyFoundChats:(NSString *)query
					  completion:(void (^)(NSArray *))completion {
	[[TGClient shared] searchRecentlyFoundChats:query completion:completion];
}

- (void)forgetRecentlyFoundChat:(int64_t)chatId {
	[[TGClient shared] send:@{
		@"@type"   : @"removeRecentlyFoundChat",
		@"chat_id" : @(chatId),
	}];
}

- (void)clearRecentlyFoundChats {
	[[TGClient shared] send:@{@"@type" : @"clearRecentlyFoundChats"}];
}

- (void)recentHashtagsWithCompletion:(void (^)(NSArray *))completion {
	[[TGClient shared] recentHashtagsWithCompletion:completion];
}

- (void)searchHashtags:(NSString *)prefix limit:(NSInteger)limit
			completion:(void (^)(NSArray *))completion {
	[[TGClient shared] searchHashtags:prefix limit:limit completion:completion];
}

- (void)removeRecentHashtag:(NSString *)hashtag {
	if (!hashtag.length)
		return;
	[[TGClient shared] send:@{
		@"@type"   : @"removeRecentHashtag",
		@"hashtag" : hashtag,
	}];
}

- (void)removeSearchedForTag:(NSString *)tag {
	if (!tag.length)
		return;
	[[TGClient shared] send:@{
		@"@type" : @"removeSearchedForTag",
		@"tag"   : tag,
	}];
}

- (void)clearSearchedForTags {
	[[TGClient shared] send:@{@"@type" : @"clearSearchedForTags"}];
}

- (void)forgetTopChat:(int64_t)chatId {
	[[TGClient shared] send:@{
		@"@type"    : @"removeTopChat",
		@"category" : @{@"@type" : @"topChatCategoryUsers"},
		@"chat_id"  : @(chatId),
	}];
}

- (void)rememberFoundChat:(int64_t)chatId {
	[[TGClient shared] send:@{
		@"@type"   : @"addRecentlyFoundChat",
		@"chat_id" : @(chatId),
	}];
}

- (void)searchChatsForQuery:(NSString *)query
				 completion:(void (^)(NSArray *))completion {
	[[TGClient shared] searchChatsForQuery:query completion:completion];
}

- (void)searchContactsForQuery:(NSString *)query
					completion:(void (^)(NSArray *))completion {
	[[TGClient shared] searchContactsForQuery:query completion:completion];
}

- (void)searchMessages:(NSString *)query
			completion:(void (^)(NSArray *))completion {
	[[TGChatListStore shared] searchMessages:query completion:completion];
}

- (void)stringsMatchingPrefix:(NSArray *)strings query:(NSString *)query
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *))completion {
	[[TGClient shared] stringsMatchingPrefix:strings query:query limit:limit
								  completion:completion];
}

- (void)publicPostSearchLimitsForQuery:(NSString *)query
							completion:(void (^)(NSDictionary *))completion {
	[[TGClient shared] publicPostSearchLimitsForQuery:query completion:completion];
}

- (void)searchPublicPosts:(NSString *)query offset:(NSString *)offset
					limit:(NSInteger)limit starCount:(NSInteger)starCount
			   completion:(void (^)(NSArray *, NSString *, NSDictionary *, BOOL))completion {
	[[TGClient shared] searchPublicPosts:query offset:offset limit:limit
							   starCount:starCount completion:completion];
}

- (void)recentlyVisitedTMeUrlsWithReferrer:(NSString *)referrer
								completion:(void (^)(NSArray *))completion {
	[[TGClient shared] recentlyVisitedTMeUrlsWithReferrer:referrer
											   completion:completion];
}

- (NSString *)nameForUserId:(int64_t)userId {
	return [[TGMessageStore shared] nameForUserId:userId];
}

- (NSString *)defaultsKeyForSearchBase:(NSString *)base {
	return TGAccountDefaultsKey(base);
}

- (int64_t)emojiStatusIdForUser:(int64_t)userId {
	return [[TGMessageStore shared] emojiStatusIdForUser:userId];
}

- (NSString *)titleForChat:(int64_t)chatId {
	return [[TGChatListStore shared] titleForChat:chatId];
}

- (void)privateChatWithUser:(int64_t)userId
				 completion:(void (^)(int64_t))completion {
	[[TGMessageStore shared] privateChatWithUser:userId completion:completion];
}

- (void)internalLinkKind:(NSString *)link
			  completion:(void (^)(NSString *, NSString *))completion {
	[[TGClient shared] internalLinkKind:link completion:completion];
}

- (void)chatWithUsername:(NSString *)username
			  completion:(void (^)(int64_t, NSString *))completion {
	[[TGClient shared] chatWithUsername:username completion:completion];
}

- (void)messageLinkInfo:(NSString *)link
			 completion:(void (^)(int64_t, int64_t))completion {
	[[TGMessageStore shared] messageLinkInfo:link completion:completion];
}

- (void)joinChatByInviteLink:(NSString *)inviteLink
				  completion:(void (^)(int64_t, NSString *))completion {
	[[TGClient shared] joinChatByInviteLink:inviteLink completion:completion];
}

@end
