#import "TGClient+Base.h"

@interface TGClient (StoriesPosting)

/// Telegram's answer for "may this chat post a story now?". The dictionary
/// carries "ok", "reason", "storyCount", "retryAfter" and "storyId" (the
/// live story that has to be deleted first, when that is the reason).
- (void)canPostStoryInChat:(int64_t)chatId
				completion:(void (^)(NSDictionary *answer))completion;

/// Chats this account may post stories on behalf of: "id", "title",
/// "photoFileId" and "isChannel".
- (void)chatsToPostStoriesWithCompletion:(void (^)(NSArray *chats))completion;

/// Posts a photo or video story. `path` is a local JPEG/MP4; the controller
/// has already sized it to Telegram's 1080x1920 / 720x1280 contract.
/// `caption` may be empty. `privacy` is "everyone", "contacts",
/// "closeFriends" or "selected"; `userIds` is used by the last.
- (void)postStoryToChat:(int64_t)chatId
				   path:(NSString *)path
				isVideo:(BOOL)isVideo
			   duration:(double)duration
				caption:(NSString *)caption
				privacy:(NSString *)privacy
				 userIds:(NSArray *)userIds
		   activePeriod:(NSInteger)seconds
		postedToChatPage:(BOOL)postedToChatPage
		  protectContent:(BOOL)protectContent
				albumIds:(NSArray *)albumIds
			 completion:(void (^)(NSDictionary *story, NSString *error))completion;

/// Edits a story's media and/or caption. A nil `path` keeps the current
/// media; a nil `caption` keeps the current caption.
- (void)editStory:(int32_t)storyId
		  fromChat:(int64_t)chatId
			  path:(NSString *)path
		 isVideo:(BOOL)isVideo
		duration:(double)duration
		 caption:(NSString *)caption
	  completion:(void (^)(BOOL ok, NSString *error))completion;

/// The poster frame used for a video story, in seconds from the start.
- (void)editStoryCover:(int32_t)storyId
			  fromChat:(int64_t)chatId
	  coverTimestamp:(double)timestamp
		  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)deleteStory:(int32_t)storyId
		   fromChat:(int64_t)chatId
		 completion:(void (^)(BOOL ok, NSString *error))completion;

/// Keeps the story on the profile after it expires, or takes it off.
- (void)toggleStory:(int32_t)storyId
			 fromChat:(int64_t)chatId
	  postedToChatPage:(BOOL)posted
		  completion:(void (^)(BOOL ok, NSString *error))completion;

/// Own-account stories only; Telegram refuses it for a chat's story.
- (void)setStoryPrivacySettings:(int32_t)storyId
						privacy:(NSString *)privacy
						userIds:(NSArray *)userIds
					 completion:(void (^)(BOOL ok, NSString *error))completion;

/// The two business-only variants. A user account gets Telegram's refusal,
/// which is the answer the menu shows.
- (void)deleteBusinessStory:(int32_t)storyId
				   fromChat:(int64_t)chatId
				 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)editBusinessStory:(int32_t)storyId
				 fromChat:(int64_t)chatId
					 path:(NSString *)path
				  isVideo:(BOOL)isVideo
				 duration:(double)duration
				  caption:(NSString *)caption
			   completion:(void (^)(BOOL ok, NSString *error))completion;

@end
