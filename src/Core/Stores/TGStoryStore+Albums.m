//
// TGStoryStore+Albums.m - copied from TGClient+StoriesAlbums.m.
//
#import "TGStoryStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+StoriesSupport.h"

#import "TGClient+StoriesAlbums.h"
#import "TGClient+StoriesSupport.h"
#import "TGClientInternal.h"

@implementation TGStoryStore (StoriesAlbums)

#pragma mark - albums

- (void)storyAlbumsForChat:(int64_t)chatId
				completion:(void (^)(NSArray *))completion {
	[[TGClient shared] request:@{@"@type" : @"getChatStoryAlbums", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		NSArray *albums = result[@"albums"];
		if (![albums isKindOfClass:NSArray.class]){
			if (completion) completion(@[]);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *album in albums)
			if ([album isKindOfClass:NSDictionary.class])
				[out addObject:TGStoryFlattenAlbum(album)];
		if (completion) completion(out);
	}];
}

- (void)createStoryAlbumNamed:(NSString *)name
					   inChat:(int64_t)chatId
					 storyIds:(NSArray *)storyIds
				   completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!name.length){
		if (completion) completion(nil, @"An album needs a name.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"createStoryAlbum",
					@"story_poster_chat_id" : @(chatId),
					@"name" : name,
					@"story_ids" : storyIds ?: @[]}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"storyAlbum"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion) completion(TGStoryFlattenAlbum(result), nil);
	}];
}

- (void)deleteStoryAlbum:(int32_t)albumId
				  inChat:(int64_t)chatId
			  completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"deleteStoryAlbum",
					@"chat_id" : @(chatId),
					@"story_album_id" : @(albumId)}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)setStoryAlbumName:(NSString *)name
				  albumId:(int32_t)albumId
				   inChat:(int64_t)chatId
			   completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!name.length){
		if (completion) completion(nil, @"An album needs a name.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"setStoryAlbumName",
					@"chat_id" : @(chatId),
					@"story_album_id" : @(albumId),
					@"name" : name}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"storyAlbum"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion) completion(TGStoryFlattenAlbum(result), nil);
	}];
}

- (void)reorderStoryAlbums:(NSArray *)albumIds
					inChat:(int64_t)chatId
				completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"reorderStoryAlbums",
					@"chat_id" : @(chatId),
					@"story_album_ids" : albumIds ?: @[]}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)storiesInAlbum:(int32_t)albumId
				inChat:(int64_t)chatId
				offset:(NSInteger)offset
				 limit:(NSInteger)limit
			completion:(void (^)(NSArray *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getStoryAlbumStories",
					@"chat_id" : @(chatId),
					@"story_album_id" : @(albumId),
					@"offset" : @(offset),
					@"limit" : @(limit > 0 ? limit : 20)}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"stories"]){
			if (completion)
				completion(@[], TGStoryErrorText(result));
			return;
		}
		if (completion) completion(TGStoryFlattenStoryList(result), nil);
	}];
}

- (void)addStories:(NSArray *)storyIds
		 toAlbum:(int32_t)albumId
			inChat:(int64_t)chatId
		completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!storyIds.count){
		if (completion) completion(nil, @"Pick at least one story.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"addStoryAlbumStories",
					@"chat_id" : @(chatId),
					@"story_album_id" : @(albumId),
					@"story_ids" : storyIds}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"storyAlbum"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion) completion(TGStoryFlattenAlbum(result), nil);
	}];
}

- (void)removeStories:(NSArray *)storyIds
		 fromAlbum:(int32_t)albumId
			 inChat:(int64_t)chatId
		 completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!storyIds.count){
		if (completion) completion(nil, @"Pick at least one story.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"removeStoryAlbumStories",
					@"chat_id" : @(chatId),
					@"story_album_id" : @(albumId),
					@"story_ids" : storyIds}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"storyAlbum"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion) completion(TGStoryFlattenAlbum(result), nil);
	}];
}

- (void)reorderStories:(NSArray *)storyIds
			 inAlbum:(int32_t)albumId
				inChat:(int64_t)chatId
			completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!storyIds.count){
		if (completion) completion(nil, @"Pick at least one story.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"reorderStoryAlbumStories",
					@"chat_id" : @(chatId),
					@"story_album_id" : @(albumId),
					@"story_ids" : storyIds}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"storyAlbum"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion) completion(TGStoryFlattenAlbum(result), nil);
	}];
}

@end

// vim:ft=objc
