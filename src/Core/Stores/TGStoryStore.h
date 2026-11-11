//
// TGStoryStore.h - stories, albums, the viewer and live stories.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "TGClientTypes.h"
#import "TGDevice.h"

/// Probe count for the story row on a device tier.
FOUNDATION_EXPORT NSUInteger TGStoryRowProbeLimit(TGDeviceTier tier);

@interface TGStoryStore : NSObject

+ (instancetype)shared;

- (void)storyNotificationExceptionsWithCompletion:(void (^)(NSArray *))completion;
- (void)activateStoryStealthModeWithCompletion:
		(void (^)(BOOL, NSString *))completion;
- (void)storyAlbumsForChat:(int64_t)chatId
				completion:(void (^)(NSArray *))completion;
- (void)createStoryAlbumNamed:(NSString *)name
					   inChat:(int64_t)chatId
					 storyIds:(NSArray *)storyIds
				   completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)deleteStoryAlbum:(int32_t)albumId
				  inChat:(int64_t)chatId
			  completion:(void (^)(BOOL, NSString *))completion;
- (void)setStoryAlbumName:(NSString *)name
				  albumId:(int32_t)albumId
				   inChat:(int64_t)chatId
			   completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)reorderStoryAlbums:(NSArray *)albumIds
					inChat:(int64_t)chatId
				completion:(void (^)(BOOL, NSString *))completion;
- (void)storiesInAlbum:(int32_t)albumId
				inChat:(int64_t)chatId
				offset:(NSInteger)offset
				 limit:(NSInteger)limit
			completion:(void (^)(NSArray *, NSString *))completion;
- (void)addStories:(NSArray *)storyIds
		 toAlbum:(int32_t)albumId
			inChat:(int64_t)chatId
		completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)removeStories:(NSArray *)storyIds
		 fromAlbum:(int32_t)albumId
			 inChat:(int64_t)chatId
		 completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)reorderStories:(NSArray *)storyIds
			 inAlbum:(int32_t)albumId
				inChat:(int64_t)chatId
			completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)canPostStoryInChat:(int64_t)chatId
				completion:(void (^)(NSDictionary *))completion;
- (void)chatsToPostStoriesWithCompletion:(void (^)(NSArray *))completion;
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
			 completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)editStory:(int32_t)storyId
		  fromChat:(int64_t)chatId
			  path:(NSString *)path
		 isVideo:(BOOL)isVideo
		duration:(double)duration
		 caption:(NSString *)caption
	  completion:(void (^)(BOOL, NSString *))completion;
- (void)editStoryCover:(int32_t)storyId
			  fromChat:(int64_t)chatId
	  coverTimestamp:(double)timestamp
		  completion:(void (^)(BOOL, NSString *))completion;
- (void)deleteStory:(int32_t)storyId
		   fromChat:(int64_t)chatId
		 completion:(void (^)(BOOL, NSString *))completion;
- (void)toggleStory:(int32_t)storyId
			 fromChat:(int64_t)chatId
	  postedToChatPage:(BOOL)posted
		  completion:(void (^)(BOOL, NSString *))completion;
- (void)setStoryPrivacySettings:(int32_t)storyId
						privacy:(NSString *)privacy
						userIds:(NSArray *)userIds
					 completion:(void (^)(BOOL, NSString *))completion;
- (void)deleteBusinessStory:(int32_t)storyId
				   fromChat:(int64_t)chatId
				 completion:(void (^)(BOOL, NSString *))completion;
- (void)editBusinessStory:(int32_t)storyId
				 fromChat:(int64_t)chatId
					 path:(NSString *)path
				  isVideo:(BOOL)isVideo
				 duration:(double)duration
				  caption:(NSString *)caption
			   completion:(void (^)(BOOL, NSString *))completion;
- (void)storyInteractionsForStory:(int32_t)storyId
							query:(NSString *)query
					 onlyContacts:(BOOL)onlyContacts
					preferForwards:(BOOL)preferForwards
				preferWithReaction:(BOOL)preferWithReaction
							 offset:(NSString *)offset
							  limit:(NSInteger)limit
						 completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)chatStoryInteractionsForStory:(int32_t)storyId
							  fromChat:(int64_t)chatId
							reactionEmoji:(NSString *)emoji
						   preferForwards:(BOOL)preferForwards
								   offset:(NSString *)offset
									limit:(NSInteger)limit
							   completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)storyPublicForwards:(int32_t)storyId
					fromChat:(int64_t)chatId
					  offset:(NSString *)offset
					   limit:(NSInteger)limit
				  completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)storyStatistics:(int32_t)storyId
			   fromChat:(int64_t)chatId
				 isDark:(BOOL)isDark
			 completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)reportStory:(int32_t)storyId
		   fromChat:(int64_t)chatId
		   optionId:(NSString *)optionId
			   text:(NSString *)text
		 completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)startLiveStoryInChat:(int64_t)chatId
					 privacy:(NSString *)privacy
					  userIds:(NSArray *)userIds
			   protectContent:(BOOL)protectContent
					   rtmp:(BOOL)rtmp
			 enableMessages:(BOOL)enableMessages
			  paidMessageStars:(NSInteger)paidMessageStars
				  completion:(void (^)(NSDictionary *))completion;
- (void)joinLiveStoryCall:(int32_t)groupCallId
			   completion:(void (^)(NSString *, NSString *))completion;
- (void)liveStoryStreamerForCall:(int32_t)groupCallId
					  completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)liveStoryRtmpUrlForChat:(int64_t)chatId
					 completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)replaceLiveStoryRtmpUrlForChat:(int64_t)chatId
							completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)liveStoryAvailableMessageSendersForCall:(int32_t)groupCallId
									 completion:(void (^)(NSArray *, NSString *))completion;
- (void)setLiveStoryMessageSender:(NSDictionary *)sender
						  forCall:(int32_t)groupCallId
					   completion:(void (^)(BOOL, NSString *))completion;
- (void)liveStoryTopDonorsForCall:(int32_t)groupCallId
					   completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)addPendingLiveStoryReactionInCall:(int32_t)groupCallId
								   stars:(NSInteger)stars
							  completion:(void (^)(BOOL, NSString *))completion;
- (void)commitPendingLiveStoryReactionsInCall:(int32_t)groupCallId
								   completion:(void (^)(BOOL, NSString *))completion;
- (void)removePendingLiveStoryReactionsInCall:(int32_t)groupCallId
								   completion:(void (^)(BOOL, NSString *))completion;
- (void)loadActiveStoriesForList:(NSString *)list
					  completion:(void (^)(BOOL, NSString *))completion;
- (void)applyChatActiveStoriesUpdate:(NSDictionary *)update;
- (void)applyStoryUpdate:(NSDictionary *)update;
- (void)applyStoryDeletedUpdate:(NSDictionary *)update;
- (void)applyStoryPostUpdate:(NSDictionary *)update;
- (void)applyStoryListChatCountUpdate:(NSDictionary *)update;
- (NSInteger)storyListChatCountForList:(NSString *)list;
- (void)applyStoryStealthModeUpdate:(NSDictionary *)update;
- (NSDictionary *)storyStealthMode;
- (void)activeStoryRowForChat:(int64_t)chatId
				   completion:(void (^)(NSDictionary *))completion;
- (void)activeStoryRowsForList:(NSString *)list
					completion:(void (^)(NSArray *))completion;
- (void)setActiveStoriesList:(NSString *)list
					 forChat:(int64_t)chatId
				  completion:(void (^)(BOOL, NSString *))completion;
- (void)setPinnedStoryIds:(NSArray *)storyIds
				   inChat:(int64_t)chatId
			   completion:(void (^)(BOOL, NSString *))completion;
- (void)archivedStoriesForChat:(int64_t)chatId
					completion:(void (^)(NSArray *))completion;
- (void)archivedStoryIdsForChat:(int64_t)chatId
					 fromStoryId:(int32_t)fromStoryId
						  limit:(NSInteger)limit
					 completion:(void (^)(NSArray *, NSString *))completion;
- (void)story:(int32_t)storyId
	  fromChat:(int64_t)chatId
  completion:(void (^)(NSDictionary *))completion;
- (void)openStory:(int32_t)storyId
		  fromChat:(int64_t)chatId
	   completion:(void (^)(BOOL, NSString *))completion;
- (void)closeStory:(int32_t)storyId
		  fromChat:(int64_t)chatId
	   completion:(void (^)(BOOL, NSString *))completion;
- (void)storyAvailableReactionsWithCompletion:
		(void (^)(NSDictionary *))completion;
- (void)setStoryReaction:(NSString *)emoji
				  onStory:(int32_t)storyId
				 fromChat:(int64_t)chatId
			  completion:(void (^)(BOOL, NSString *))completion;
- (void)storyLinkForStory:(int32_t)storyId inChat:(int64_t)chatId
			   completion:(void (^)(NSString *link))completion;
- (void)searchPublicStoriesByTag:(NSString *)tag
						  offset:(NSString *)offset
						   limit:(NSInteger)limit
					  completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)searchPublicStoriesByLocation:(NSDictionary *)address
							   offset:(NSString *)offset
								limit:(NSInteger)limit
						   completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)searchPublicStoriesByVenue:(NSString *)venueProvider
						   venueId:(NSString *)venueId
							offset:(NSString *)offset
							 limit:(NSInteger)limit
						completion:(void (^)(NSDictionary *, NSString *))completion;

@end
