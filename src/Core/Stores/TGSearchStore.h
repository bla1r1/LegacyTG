//
// TGSearchStore.h - what the search screen may ask for.
//
// The screen used to reach into TGClient for its empty state, suggestions,
// public posts and link resolution. Those calls live here now.
//
#import <Foundation/Foundation.h>

@interface TGSearchStore : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) NSArray *chats;

- (void)topChatsWithCompletion:(void (^)(NSArray *chats))completion;
- (void)recentlyOpenedChatsWithCompletion:(void (^)(NSArray *chats))completion;
- (void)searchRecentlyFoundChats:(NSString *)query
					  completion:(void (^)(NSArray *chats))completion;
- (void)forgetRecentlyFoundChat:(int64_t)chatId;
- (void)clearRecentlyFoundChats;

- (void)recentHashtagsWithCompletion:(void (^)(NSArray *tags))completion;
- (void)searchHashtags:(NSString *)prefix limit:(NSInteger)limit
			completion:(void (^)(NSArray *tags))completion;
- (void)removeRecentHashtag:(NSString *)hashtag;
- (void)removeSearchedForTag:(NSString *)tag;
- (void)clearSearchedForTags;

- (void)forgetTopChat:(int64_t)chatId;
- (void)rememberFoundChat:(int64_t)chatId;

- (void)searchChatsForQuery:(NSString *)query
				 completion:(void (^)(NSArray *chats))completion;
- (void)searchContactsForQuery:(NSString *)query
					completion:(void (^)(NSArray *users))completion;
- (void)searchMessages:(NSString *)query
			completion:(void (^)(NSArray *messages))completion;
- (void)stringsMatchingPrefix:(NSArray *)strings query:(NSString *)query
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *matches))completion;

- (void)publicPostSearchLimitsForQuery:(NSString *)query
							completion:(void (^)(NSDictionary *limits))completion;
- (void)searchPublicPosts:(NSString *)query offset:(NSString *)offset
					limit:(NSInteger)limit starCount:(NSInteger)starCount
			   completion:(void (^)(NSArray *messages, NSString *next,
									NSDictionary *limits, BOOL exceeded))completion;
- (void)recentlyVisitedTMeUrlsWithReferrer:(NSString *)referrer
								completion:(void (^)(NSArray *urls))completion;

- (NSString *)nameForUserId:(int64_t)userId;
/// The per-account defaults key the search history uses.
- (NSString *)defaultsKeyForSearchBase:(NSString *)base;
- (int64_t)emojiStatusIdForUser:(int64_t)userId;
- (NSString *)titleForChat:(int64_t)chatId;
- (void)privateChatWithUser:(int64_t)userId
				 completion:(void (^)(int64_t chatId))completion;
- (void)internalLinkKind:(NSString *)link
			  completion:(void (^)(NSString *kind, NSString *value))completion;
- (void)chatWithUsername:(NSString *)username
			  completion:(void (^)(int64_t chatId, NSString *title))completion;
- (void)messageLinkInfo:(NSString *)link
			 completion:(void (^)(int64_t chatId, int64_t messageId))completion;
- (void)joinChatByInviteLink:(NSString *)inviteLink
				  completion:(void (^)(int64_t chatId, NSString *title))completion;

@end
