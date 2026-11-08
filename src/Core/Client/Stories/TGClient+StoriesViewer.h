#import "TGClient+Base.h"

@interface TGClient (StoriesViewer)

/// Tells TDLib the story is open, so views count and read state moves.
- (void)openStory:(int32_t)storyId
		  fromChat:(int64_t)chatId
	   completion:(void (^)(BOOL ok, NSString *error))completion;

/// Tells TDLib the viewer closed. Sent when leaving a story, whatever moved
/// the user away from it.
- (void)closeStory:(int32_t)storyId
		  fromChat:(int64_t)chatId
	   completion:(void (^)(BOOL ok, NSString *error))completion;

/// Reactions Telegram offers for stories: "emojis" (top first), "recent",
/// "popular", "allowCustom" and "unavailable" (Telegram's reason, or nil).
- (void)storyAvailableReactionsWithCompletion:
		(void (^)(NSDictionary *reactions))completion;

/// Sets a reaction on a story. `emoji` nil removes the current one; custom
/// emoji reactions are sent as "custom:<id>" so the picker has one string
/// to carry. Unsupported for live stories.
- (void)setStoryReaction:(NSString *)emoji
				  onStory:(int32_t)storyId
				 fromChat:(int64_t)chatId
			  completion:(void (^)(BOOL ok, NSString *error))completion;

@end
