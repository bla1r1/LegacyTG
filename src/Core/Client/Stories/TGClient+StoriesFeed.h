#import "TGDevice.h"
#import "TGClient+Base.h"

/// How many chats the first pass over the story strip asks about, on this tier.
#ifdef __cplusplus
extern "C"
#endif
NSUInteger TGStoryRowProbeLimit(TGDeviceTier tier);

@interface TGClient (StoriesFeed)

- (void)loadActiveStoriesForList:(NSString *)list
					  completion:(void (^)(BOOL ok, NSString *error))completion;

/// One chat's active stories: "chatId", "title", "photoFileId", "isOwn",
/// "unread" (max_read_story_id is behind the newest story), "isLive",
/// "maxReadStoryId", "order", "canBeArchived", "list" and "stories" - the
/// storyInfo records TDLib sends. Nil when the chat has none.
- (void)activeStoryRowForChat:(int64_t)chatId
				   completion:(void (^)(NSDictionary *row))completion;

/// The rows the chat list's stories strip draws. Sends loadActiveStories for
/// the list, then reads each chat already in the client's list. Empty is a
/// real answer: no active stories, not a failed request.
- (void)activeStoryRowsForList:(NSString *)list
					completion:(void (^)(NSArray *rows))completion;

/// Moves a chat's stories between the main strip and the archive strip.
- (void)setActiveStoriesList:(NSString *)list
					 forChat:(int64_t)chatId
				  completion:(void (^)(BOOL ok, NSString *error))completion;

/// The stories pinned to a chat's profile page, in order. Every id must
/// already be posted to the chat page.
- (void)setPinnedStoryIds:(NSArray *)storyIds
				   inChat:(int64_t)chatId
			   completion:(void (^)(BOOL ok, NSString *error))completion;

/// All stories a chat has ever posted; requires can_edit_stories in a group
/// or channel. Only the ids Telegram returns are new: the archive screen
/// converts them with -story:fromChat:completion:.
/// The archive as tiles, the same rows storiesForChat: gives: first 60.
- (void)archivedStoriesForChat:(int64_t)chatId
					completion:(void (^)(NSArray *))completion;

- (void)archivedStoryIdsForChat:(int64_t)chatId
					 fromStoryId:(int32_t)fromStoryId
						  limit:(NSInteger)limit
					 completion:(void (^)(NSArray *storyIds, NSString *error))completion;

/// A story by id, flattened. The viewer asks for this rather than re-reading
/// the whole chat every time the user swipes.
- (void)story:(int32_t)storyId
	  fromChat:(int64_t)chatId
  completion:(void (^)(NSDictionary *story))completion;

/// How many chats Telegram says have stories in "main" or "archive", from
/// updateStoryListChatCount. Zero when that list has not reported yet.
- (NSInteger)storyListChatCountForList:(NSString *)list;

/// The stealth window Telegram last reported, as "activeUntilDate" and
/// "cooldownUntilDate" (Unix seconds). Nil until updateStoryStealthMode.
- (NSDictionary *)storyStealthMode;

@end
