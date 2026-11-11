//
// TGStoryStore+Posting.m - copied from TGClient+StoriesPosting.m.
//
#import "TGStoryStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+StoriesSupport.h"

#import "TGClient+StoriesPosting.h"
#import "TGClient+StoriesSupport.h"
#import "TGClientInternal.h"

@implementation TGStoryStore (StoriesPosting)

#pragma mark - posting and editing

- (void)canPostStoryInChat:(int64_t)chatId
				completion:(void (^)(NSDictionary *))completion {
	[[TGClient shared] request:@{@"@type" : @"canPostStory", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		NSString *type = result[@"@type"];
		if ([type isEqualToString:@"error"]){
			if (completion)
				completion(@{@"ok" : @NO,
							 @"reason" : TGStoryErrorText(result),
							 @"type" : @"error"});
			return;
		}
		NSMutableDictionary *out = [@{
			@"ok" : @([type isEqualToString:@"canPostStoryResultOk"]),
			@"type" : type ?: @"",
			@"storyCount" : result[@"story_count"] ?: @(0),
			@"retryAfter" : result[@"retry_after"] ?: @(0),
			@"storyId" : result[@"story_id"] ?: @(0),
		} mutableCopy];
		if ([type isEqualToString:@"canPostStoryResultOk"])
			out[@"reason"] = @"";
		else if ([type isEqualToString:@"canPostStoryResultPremiumNeeded"])
			out[@"reason"] = @"Telegram Premium is needed to post more stories.";
		else if ([type isEqualToString:@"canPostStoryResultBoostNeeded"])
			out[@"reason"] = @"This chat has to be boosted before it can post another story.";
		else if ([type isEqualToString:@"canPostStoryResultActiveStoryLimitExceeded"])
			out[@"reason"] = @"Too many active stories. Delete one or wait for the oldest to expire.";
		else if ([type isEqualToString:@"canPostStoryResultWeeklyLimitExceeded"])
			out[@"reason"] = @"The weekly story limit is reached.";
		else if ([type isEqualToString:@"canPostStoryResultMonthlyLimitExceeded"])
			out[@"reason"] = @"The monthly story limit is reached.";
		else if ([type isEqualToString:@"canPostStoryResultLiveStoryIsActive"])
			out[@"reason"] = @"A live story is already running. Delete it first.";
		else
			out[@"reason"] = @"Telegram did not say why this story cannot be posted.";
		if (completion) completion(out);
	}];
}

- (void)chatsToPostStoriesWithCompletion:(void (^)(NSArray *))completion {
	__weak TGClient *weakSelf = [TGClient shared];
	[[TGClient shared] request:@{@"@type" : @"getChatsToPostStories"}
	   completion:^(NSDictionary *result){
		NSArray *chatIds = result[@"chat_ids"];
		if (![chatIds isKindOfClass:NSArray.class] || !chatIds.count){
			if (completion) completion(@[]);
			return;
		}
		NSMutableArray *chats = [NSMutableArray array];
		__block NSUInteger outstanding = MIN(chatIds.count, (NSUInteger)50);
		for (NSNumber *chatId in [chatIds subarrayWithRange:
				NSMakeRange(0, MIN(chatIds.count, (NSUInteger)50))]){
			[[TGClient shared] request:@{@"@type" : @"getChat", @"chat_id" : chatId}
				   completion:^(NSDictionary *chat){
				if ([chat[@"@type"] isEqualToString:@"chat"]){
					NSMutableDictionary *row = [@{
						@"id" : chat[@"id"] ?: @(0),
						@"title" : chat[@"title"] ?: @"",
						@"isChannel" : @([chat[@"type"][@"@type"]
								isEqualToString:@"chatTypeSupergroup"] &&
								[chat[@"type"][@"is_channel"] boolValue]),
					} mutableCopy];
					NSNumber *photoId = TGStoryChatPhotoFileId(chat);
					if (photoId)
						row[@"photoFileId"] = photoId;
					[chats addObject:row];
				}
				if (--outstanding == 0){
					[chats sortUsingComparator:^NSComparisonResult(NSDictionary *a,
																  NSDictionary *b){
						return [a[@"title"] compare:b[@"title"]];
					}];
					if (completion) completion(chats);
				}
			}];
		}
	}];
}

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
			 completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!chatId || !path.length){
		if (completion)
			completion(nil, @"Pick a picture or a video first.");
		return;
	}
	NSDictionary *content = nil;
	if (isVideo)
		content = @{@"@type" : @"inputStoryContentVideo",
					@"video" : @{@"@type" : @"inputFileLocal", @"path" : path},
					@"added_sticker_file_ids" : @[],
					@"duration" : @(duration > 0 ? duration : 1),
					@"cover_frame_timestamp" : @(0),
					@"is_animation" : @NO};
	else
		content = @{@"@type" : @"inputStoryContentPhoto",
					@"photo" : @{@"@type" : @"inputFileLocal", @"path" : path},
					@"added_sticker_file_ids" : @[]};

	id captionObject = caption.length
			? @{@"@type" : @"formattedText", @"text" : caption, @"entities" : @[]}
			: [NSNull null];
	NSInteger period = (seconds == 21600 || seconds == 43200 ||
						seconds == 86400 || seconds == 172800)
			? seconds : 86400;
	NSMutableDictionary *request = [@{
		@"@type" : @"postStory",
		@"chat_id" : @(chatId),
		@"content" : content,
		@"areas" : [NSNull null],
		@"caption" : captionObject,
		@"privacy_settings" : TGStoryPrivacyObject(privacy, userIds),
		@"album_ids" : albumIds ?: @[],
		@"active_period" : @(period),
		@"from_story_full_id" : [NSNull null],
		@"is_posted_to_chat_page" : @(postedToChatPage),
		@"protect_content" : @(protectContent),
	} mutableCopy];
	[[TGClient shared] request:request completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"story"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion)
			completion(TGStoryFlatten(result), nil);
	}];
}

- (void)editStory:(int32_t)storyId
		  fromChat:(int64_t)chatId
			  path:(NSString *)path
		 isVideo:(BOOL)isVideo
		duration:(double)duration
		 caption:(NSString *)caption
	  completion:(void (^)(BOOL, NSString *))completion {
	id content = [NSNull null];
	if (path.length){
		if (isVideo)
			content = @{@"@type" : @"inputStoryContentVideo",
						@"video" : @{@"@type" : @"inputFileLocal", @"path" : path},
						@"added_sticker_file_ids" : @[],
						@"duration" : @(duration > 0 ? duration : 1),
						@"cover_frame_timestamp" : @(0),
						@"is_animation" : @NO};
		else
			content = @{@"@type" : @"inputStoryContentPhoto",
						@"photo" : @{@"@type" : @"inputFileLocal", @"path" : path},
						@"added_sticker_file_ids" : @[]};
	}
	id captionObject = [NSNull null];
	if ([caption isKindOfClass:NSString.class])
		captionObject = @{@"@type" : @"formattedText",
						  @"text" : caption,
						  @"entities" : @[]};
	[[TGClient shared] request:@{@"@type" : @"editStory",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId),
					@"content" : content,
					@"areas" : [NSNull null],
					@"caption" : captionObject}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)editStoryCover:(int32_t)storyId
			  fromChat:(int64_t)chatId
	  coverTimestamp:(double)timestamp
		  completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"editStoryCover",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId),
					@"cover_frame_timestamp" : @(timestamp)}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)deleteStory:(int32_t)storyId
		   fromChat:(int64_t)chatId
		 completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"deleteStory",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId)}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)toggleStory:(int32_t)storyId
			 fromChat:(int64_t)chatId
	  postedToChatPage:(BOOL)posted
		  completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"toggleStoryIsPostedToChatPage",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId),
					@"is_posted_to_chat_page" : @(posted)}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)setStoryPrivacySettings:(int32_t)storyId
						privacy:(NSString *)privacy
						userIds:(NSArray *)userIds
					 completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"setStoryPrivacySettings",
					@"story_id" : @(storyId),
					@"privacy_settings" : TGStoryPrivacyObject(privacy, userIds)}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)deleteBusinessStory:(int32_t)storyId
				   fromChat:(int64_t)chatId
				 completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"deleteBusinessStory",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId)}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)editBusinessStory:(int32_t)storyId
				 fromChat:(int64_t)chatId
					 path:(NSString *)path
				  isVideo:(BOOL)isVideo
				 duration:(double)duration
				  caption:(NSString *)caption
			   completion:(void (^)(BOOL, NSString *))completion {
	id content = [NSNull null];
	if (path.length){
		if (isVideo)
			content = @{@"@type" : @"inputStoryContentVideo",
						@"video" : @{@"@type" : @"inputFileLocal", @"path" : path},
						@"added_sticker_file_ids" : @[],
						@"duration" : @(duration > 0 ? duration : 1),
						@"cover_frame_timestamp" : @(0),
						@"is_animation" : @NO};
		else
			content = @{@"@type" : @"inputStoryContentPhoto",
						@"photo" : @{@"@type" : @"inputFileLocal", @"path" : path},
						@"added_sticker_file_ids" : @[]};
	}
	id captionObject = [NSNull null];
	if ([caption isKindOfClass:NSString.class])
		captionObject = @{@"@type" : @"formattedText",
						  @"text" : caption,
						  @"entities" : @[]};
	[[TGClient shared] request:@{@"@type" : @"editBusinessStory",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId),
					@"content" : content,
					@"areas" : [NSNull null],
					@"caption" : captionObject}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

@end

// vim:ft=objc
