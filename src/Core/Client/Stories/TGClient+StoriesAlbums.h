#import "TGClient+Base.h"

@interface TGClient (StoriesAlbums)

/// "id", "name", "photoFileId" and "videoFileId" per album.
- (void)storyAlbumsForChat:(int64_t)chatId
				completion:(void (^)(NSArray *albums))completion;

/// Telegram returns only the album record (id, name, icons) - the stories it
/// now holds are read with -storiesInAlbum:... after this answers.
- (void)createStoryAlbumNamed:(NSString *)name
					   inChat:(int64_t)chatId
					 storyIds:(NSArray *)storyIds
				   completion:(void (^)(NSDictionary *album, NSString *error))completion;

- (void)deleteStoryAlbum:(int32_t)albumId
				  inChat:(int64_t)chatId
			  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setStoryAlbumName:(NSString *)name
					albumId:(int32_t)albumId
					 inChat:(int64_t)chatId
				 completion:(void (^)(NSDictionary *album, NSString *error))completion;

- (void)reorderStoryAlbums:(NSArray *)albumIds
					inChat:(int64_t)chatId
				completion:(void (^)(BOOL ok, NSString *error))completion;

/// Flattened stories in an album, in the album's order.
- (void)storiesInAlbum:(int32_t)albumId
				inChat:(int64_t)chatId
				offset:(NSInteger)offset
				 limit:(NSInteger)limit
			completion:(void (^)(NSArray *stories, NSString *error))completion;

- (void)addStories:(NSArray *)storyIds
		 toAlbum:(int32_t)albumId
			inChat:(int64_t)chatId
		completion:(void (^)(NSDictionary *album, NSString *error))completion;

- (void)removeStories:(NSArray *)storyIds
		 fromAlbum:(int32_t)albumId
			 inChat:(int64_t)chatId
		 completion:(void (^)(NSDictionary *album, NSString *error))completion;

/// Moves the named stories to the front of the album in the order given.
- (void)reorderStories:(NSArray *)storyIds
			 inAlbum:(int32_t)albumId
				inChat:(int64_t)chatId
			completion:(void (^)(NSDictionary *album, NSString *error))completion;

@end
