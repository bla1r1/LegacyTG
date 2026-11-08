#import "TGClient+Base.h"

@interface TGClient (StoriesInteractions)

/// Interactions with an own-account story. `offset` is "" for the first page;
/// the answer carries "nextOffset".
- (void)storyInteractionsForStory:(int32_t)storyId
							query:(NSString *)query
					 onlyContacts:(BOOL)onlyContacts
					preferForwards:(BOOL)preferForwards
				preferWithReaction:(BOOL)preferWithReaction
							 offset:(NSString *)offset
							  limit:(NSInteger)limit
						 completion:(void (^)(NSDictionary *page, NSString *error))completion;

/// Interactions with a story posted by a chat; requires an administrator
/// right in that chat.
- (void)chatStoryInteractionsForStory:(int32_t)storyId
							  fromChat:(int64_t)chatId
							reactionEmoji:(NSString *)emoji
						   preferForwards:(BOOL)preferForwards
								   offset:(NSString *)offset
									limit:(NSInteger)limit
							   completion:(void (^)(NSDictionary *page, NSString *error))completion;

/// Public messages and reposts of a story: "totalCount", "nextOffset" and
/// "forwards" rows carrying "kind", "title", "text" and a story when the
/// forward is itself a story.
- (void)storyPublicForwards:(int32_t)storyId
					fromChat:(int64_t)chatId
					  offset:(NSString *)offset
					   limit:(NSInteger)limit
				  completion:(void (^)(NSDictionary *page, NSString *error))completion;

/// Interaction and reaction graphs, each flattened to "lines" the list draws
/// as bars. A statisticalGraphAsync token is shown rather than followed: this
/// screen has nowhere to keep a graph that arrives after it closed.
- (void)storyStatistics:(int32_t)storyId
			   fromChat:(int64_t)chatId
				 isDark:(BOOL)isDark
			 completion:(void (^)(NSDictionary *statistics, NSString *error))completion;

/// The report is two steps: the first call with an empty option asks Telegram
/// which options exist; the chosen option and optional text are sent second.
- (void)reportStory:(int32_t)storyId
		   fromChat:(int64_t)chatId
		   optionId:(NSString *)optionId
			   text:(NSString *)text
		 completion:(void (^)(NSDictionary *result, NSString *error))completion;

@end
