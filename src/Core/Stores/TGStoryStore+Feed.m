//
// TGStoryStore+Feed.m - copied from TGClient+StoriesFeed.m.
//
#import "TGStoryStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+StoriesSupport.h"

#import "TGClient+StoriesFeed.h"
#import "TGClient+StoriesSupport.h"
#import "TGClientInternal.h"

@implementation TGStoryStore (StoriesFeed)

#pragma mark - the feed

- (void)loadActiveStoriesForList:(NSString *)list
					  completion:(void (^)(BOOL, NSString *))completion {
	NSString *type = [list isEqualToString:@"archive"]
			? @"storyListArchive" : @"storyListMain";
	[[TGClient shared] request:@{@"@type" : @"loadActiveStories", @"story_list" : @{@"@type" : type}}
	   completion:^(NSDictionary *result){
		// A 404 here means every active story is already loaded; the strip
		// still gets its rows from the per-chat reads below.
		BOOL failed = [result[@"@type"] isEqualToString:@"error"] &&
				[result[@"code"] integerValue] != 404;
		if (completion)
			completion(!failed, failed ? TGStoryErrorText(result) : nil);
	}];
}

/// updateChatActiveStories is the strip's real feed: loadActiveStories turns
/// the cache on, and every chat with something to watch then arrives here.
/// Reading only the first sixty chats missed a contact whose story sat below
/// them, which is why the strip could look empty while Telegram had stories.
- (void)applyChatActiveStoriesUpdate:(NSDictionary *)update {
	NSDictionary *active = [update[@"active_stories"] isKindOfClass:NSDictionary.class]
			? update[@"active_stories"] : nil;
	if (!active)
		return;
	int64_t chatId = [active[@"chat_id"] longLongValue];
	if (!chatId)
		return;
	NSArray *infos = [active[@"stories"] isKindOfClass:NSArray.class]
			? active[@"stories"] : @[];
	NSString *listType = TGStoryDict(active[@"list"])[@"@type"];
	if (!infos.count){
		if ([listType isEqualToString:@"storyListMain"])
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGStoriesChangedNotification object:self
								userInfo:@{@"chatId" : @(chatId), @"remove" : @YES}];
		return;
	}
	if (![listType isEqualToString:@"storyListMain"])
		return;

	NSMutableArray *stories = [NSMutableArray array];
	BOOL live = NO;
	int32_t maxRead = [active[@"max_read_story_id"] intValue];
	int32_t newest = 0;
	for (NSDictionary *info in infos){
		[stories addObject:TGStoryFlattenInfo(info, active)];
		int32_t storyId = [info[@"story_id"] intValue];
		if (storyId > newest)
			newest = storyId;
		if ([info[@"is_live"] boolValue])
			live = YES;
	}
	NSDictionary *chat = nil;
	for (NSDictionary *candidate in [TGClient shared].chats)
		if ([candidate[@"id"] longLongValue] == chatId){
			chat = candidate;
			break;
		}
	NSNumber *photoId = chat[@"photoFileId"] ?: TGStoryChatPhotoFileId(chat);
	NSMutableDictionary *row = [@{
		@"chatId"        : @(chatId),
		@"title"         : [[TGClient shared] titleForChat:chatId]
				?: chat[@"title"] ?: @"",
		@"isOwn"         : @(chatId == [[TGClient shared] savedMessagesChatId]),
		@"unread"        : @(newest > maxRead),
		@"isLive"        : @(live),
		@"maxReadStoryId": @(maxRead),
		@"order"         : active[@"order"] ?: @(0),
		@"canBeArchived" : active[@"can_be_archived"] ?: @NO,
		@"list"          : @"main",
		@"stories"       : stories,
	} mutableCopy];
	if ([photoId isKindOfClass:NSNumber.class])
		row[@"photoFileId"] = photoId;
	[[NSNotificationCenter defaultCenter] postNotificationName:TGStoriesChangedNotification
			object:self userInfo:@{@"row" : row}];

	// The update can arrive before the chat or the user behind a private
	// chat has been described, leaving a row with no name to draw. Ask for
	// the record once and post the row again when it lands.
	if (![row[@"title"] isKindOfClass:NSString.class] || ![row[@"title"] length]){
		[[TGClient shared] chatRecordForChat:chatId completion:^(NSDictionary *chat){
			if (!chat)
				return;
			NSMutableDictionary *fixed = [row mutableCopy];
			NSString *title = chat[@"title"];
			if ([title isKindOfClass:NSString.class] && title.length)
				fixed[@"title"] = title;
			NSNumber *photo = chat[@"photo"][@"small"][@"id"];
			if (photo)
				fixed[@"photoFileId"] = photo;
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGStoriesChangedNotification object:self
								userInfo:@{@"row" : fixed}];
		}];
	}
}

/// A story changed in place, for an open viewer. The strip's row is kept by
/// updateChatActiveStories; asking for the row here as well would be one request
/// per story, and loading a list of stories can bring many of these at once.
- (void)applyStoryUpdate:(NSDictionary *)update {
	NSDictionary *story = [update[@"story"] isKindOfClass:NSDictionary.class]
			? update[@"story"] : nil;
	int64_t chatId = [story[@"poster_chat_id"] longLongValue];
	if (!chatId)
		return;
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGStoriesChangedNotification object:self
						userInfo:@{@"chatId" : @(chatId), @"story" : TGStoryFlatten(story)}];
}

/// The story is gone, for an open viewer, which drops it by id.
- (void)applyStoryDeletedUpdate:(NSDictionary *)update {
	int64_t chatId = [update[@"story_poster_chat_id"] longLongValue];
	if (!chatId)
		return;
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGStoriesChangedNotification object:self
						userInfo:@{@"chatId" : @(chatId),
								   @"deletedStoryId" : @([update[@"story_id"] intValue])}];
}

/// postStory answers with a story that is still being posted; this is the
/// server saying it finished, or why it did not. One notification because the
/// composer only has to clear its button and say one sentence.
- (void)applyStoryPostUpdate:(NSDictionary *)update {
	BOOL ok = [update[@"@type"] isEqualToString:@"updateStoryPostSucceeded"];
	NSDictionary *story = [update[@"story"] isKindOfClass:NSDictionary.class]
			? update[@"story"] : nil;
	NSNumber *chatId = story[@"poster_chat_id"] ?: update[@"story_poster_chat_id"] ?: @(0);
	NSNumber *storyId = story[@"id"] ?: update[@"story_id"] ?: update[@"old_story_id"] ?: @(0);
	NSMutableDictionary *info = [@{
		@"ok"      : @(ok),
		@"chatId"  : chatId,
		@"storyId" : storyId,
	} mutableCopy];
	if (story)
		info[@"story"] = TGStoryFlatten(story);
	if (!ok){
		NSDictionary *error = [update[@"error"] isKindOfClass:NSDictionary.class]
				? update[@"error"] : @{};
		NSString *message = [error[@"message"] isKindOfClass:NSString.class]
				? error[@"message"] : @"Telegram could not post the story.";
		info[@"error"] = message;
	}
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGStoryPostFinishedNotification object:self
						userInfo:info];
}

- (void)applyStoryListChatCountUpdate:(NSDictionary *)update {
	NSString *listType = TGStoryDict(update[@"story_list"])[@"@type"];
	NSInteger count = [update[@"chat_count"] integerValue];
	if ([listType isEqualToString:@"storyListArchive"])
		[TGClient shared].storyArchiveListChatCount = count;
	else if ([listType isEqualToString:@"storyListMain"])
		[TGClient shared].storyMainListChatCount = count;
}

- (NSInteger)storyListChatCountForList:(NSString *)list {
	if ([list isEqualToString:@"archive"])
		return [TGClient shared].storyArchiveListChatCount;
	return [TGClient shared].storyMainListChatCount;
}

- (void)applyStoryStealthModeUpdate:(NSDictionary *)update {
	[TGClient shared].storyStealthModeValue = @{
		@"activeUntilDate"   : update[@"active_until_date"] ?: @(0),
		@"cooldownUntilDate" : update[@"cooldown_until_date"] ?: @(0),
	};
}

- (NSDictionary *)storyStealthMode {
	return [TGClient shared].storyStealthModeValue;
}

- (void)activeStoryRowForChat:(int64_t)chatId
				   completion:(void (^)(NSDictionary *))completion {
	if (!chatId){
		if (completion) completion(nil);
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getChatActiveStories", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"chatActiveStories"]){
			if (completion) completion(nil);
			return;
		}
		NSArray *infos = [result[@"stories"] isKindOfClass:NSArray.class]
				? result[@"stories"] : @[];
		if (!infos.count){
			if (completion) completion(nil);
			return;
		}
		NSMutableArray *stories = [NSMutableArray array];
		BOOL live = NO;
		int32_t maxRead = [result[@"max_read_story_id"] intValue];
		int32_t newest = 0;
		for (NSDictionary *info in infos){
			[stories addObject:TGStoryFlattenInfo(info, result)];
			int32_t storyId = [info[@"story_id"] intValue];
			if (storyId > newest)
				newest = storyId;
			if ([info[@"is_live"] boolValue])
				live = YES;
		}
		NSString *listName = @"";
		NSString *listType = TGStoryDict(result[@"list"])[@"@type"];
		if ([listType isEqualToString:@"storyListMain"])
			listName = @"main";
		else if ([listType isEqualToString:@"storyListArchive"])
			listName = @"archive";
		NSDictionary *chat = nil;
		for (NSDictionary *candidate in [TGClient shared].chats)
			if ([candidate[@"id"] longLongValue] == chatId){
				chat = candidate;
				break;
			}
		NSNumber *photoId = chat[@"photoFileId"] ?: TGStoryChatPhotoFileId(chat);
		NSMutableDictionary *row = [@{
			@"chatId"        : @(chatId),
			@"title"         : [[TGClient shared] titleForChat:chatId]
					?: chat[@"title"] ?: @"",
			@"isOwn"         : @(chatId == [[TGClient shared] savedMessagesChatId]),
			@"unread"        : @(newest > maxRead),
			@"isLive"        : @(live),
			@"maxReadStoryId": @(maxRead),
			@"order"         : result[@"order"] ?: @(0),
			@"canBeArchived" : result[@"can_be_archived"] ?: @NO,
			@"list"          : listName,
			@"stories"       : stories,
		} mutableCopy];
		if ([photoId isKindOfClass:NSNumber.class])
			row[@"photoFileId"] = photoId;
		if (completion) completion(row);
	}];
}



- (void)activeStoryRowsForList:(NSString *)list
					completion:(void (^)(NSArray *))completion {
	NSArray *knownChats = [TGClient shared].chats ?: @[];
	int64_t savedId = [[TGClient shared] savedMessagesChatId];
	NSMutableArray *ids = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];
	if (savedId){
		[ids addObject:@(savedId)];
		[seen addObject:@(savedId)];
	}
	// The strip is a first screen, not an archive walk, and
	// updateChatActiveStories is its real feed: this only fills it sooner.
	NSUInteger probes = TGStoryRowProbeLimit([TGDevice tier]);
	for (NSDictionary *chat in knownChats){
		if (ids.count >= probes)
			break;
		NSNumber *chatId = chat[@"id"];
		if (![chatId isKindOfClass:NSNumber.class] || [seen containsObject:chatId])
			continue;
		[seen addObject:chatId];
		[ids addObject:chatId];
	}

	__weak TGClient *weakSelf = [TGClient shared];
	[[TGClient shared] loadActiveStoriesForList:list completion:^(BOOL ok, NSString *error){
		TGClient *me = weakSelf;
		if (!me)
			return;
		if (!ids.count){
			if (completion) completion(@[]);
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		__block NSUInteger outstanding = ids.count;
		for (NSNumber *chatId in ids){
			[me activeStoryRowForChat:chatId.longLongValue
						   completion:^(NSDictionary *row){
				if (row)
					[rows addObject:row];
				if (--outstanding == 0){
					[rows sortUsingComparator:^NSComparisonResult(NSDictionary *a,
																  NSDictionary *b){
						NSComparisonResult byOrder = [b[@"order"] compare:a[@"order"]];
						if (byOrder != NSOrderedSame)
							return byOrder;
						return [b[@"chatId"] compare:a[@"chatId"]];
					}];
					if (completion)
						completion(rows);
				}
			}];
		}
	}];
}

- (void)setActiveStoriesList:(NSString *)list
					 forChat:(int64_t)chatId
				  completion:(void (^)(BOOL, NSString *))completion {
	NSString *type = [list isEqualToString:@"archive"]
			? @"storyListArchive" : @"storyListMain";
	[[TGClient shared] request:@{@"@type" : @"setChatActiveStoriesList",
					@"chat_id" : @(chatId),
					@"story_list" : @{@"@type" : type}}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)setPinnedStoryIds:(NSArray *)storyIds
				   inChat:(int64_t)chatId
			   completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"setChatPinnedStories",
					@"chat_id" : @(chatId),
					@"story_ids" : storyIds ?: @[]}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)archivedStoriesForChat:(int64_t)chatId
					completion:(void (^)(NSArray *))completion {
	[[TGClient shared] request:@{@"@type" : @"getChatArchivedStories",
					@"chat_id" : @(chatId),
					@"from_story_id" : @(0),
					@"limit" : @(60)}
	   completion:^(NSDictionary *result){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *story in TGStoryArray(result[@"stories"]))
			if ([story isKindOfClass:NSDictionary.class])
				[out addObject:TGFlattenStory(story)];
		if (completion)
			completion(out);
	}];
}

- (void)archivedStoryIdsForChat:(int64_t)chatId
					 fromStoryId:(int32_t)fromStoryId
						  limit:(NSInteger)limit
					 completion:(void (^)(NSArray *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getChatArchivedStories",
					@"chat_id" : @(chatId),
					@"from_story_id" : @(fromStoryId),
					@"limit" : @(limit > 0 ? limit : 20)}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"stories"]){
			if (completion)
				completion(@[], TGStoryErrorText(result));
			return;
		}
		NSMutableArray *ids = [NSMutableArray array];
		for (NSDictionary *story in TGStoryArray(result[@"stories"]))
			if ([story isKindOfClass:NSDictionary.class] && story[@"id"])
				[ids addObject:story[@"id"]];
		if (completion)
			completion(ids, nil);
	}];
}

- (void)story:(int32_t)storyId
	  fromChat:(int64_t)chatId
  completion:(void (^)(NSDictionary *))completion {
	[[TGClient shared] request:@{@"@type" : @"getStory",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId),
					@"only_local" : @NO}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"story"]){
			if (completion) completion(nil);
			return;
		}
		if (completion) completion(TGStoryFlatten(result));
	}];
}

@end

// vim:ft=objc
