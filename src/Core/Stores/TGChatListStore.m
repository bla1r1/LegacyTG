//
// TGChatListStore.m - the list's data seam and M24 row facts.
//
#import "TGChatListStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGMessageStore.h"
#import "TGLocalization.h"
#import "TGImageLruCache.h"
#import "TGDownloadStore.h"

NSString *const TGChatListStoreChangedNotification = @"TGChatListStoreChangedNotification";
NSString *const TGChatListPreviewImageLoadedNotification = @"TGChatListPreviewImageLoadedNotification";

@implementation TGChatListStore {
	NSInteger _unreadTotal;
	void (^_onChatsChanged)(void);
	void (^_onArchiveChanged)(void);
	void (^_onConnectionState)(TGConnectionState, NSString *);
	TGImageLruCache *_previewImages;
	NSMutableSet *_previewRequests;
}

+ (instancetype)shared {
	static TGChatListStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ store = [[TGChatListStore alloc] init]; });
	return store;
}

- (instancetype)init {
	self = [super init];
	if (!self)
		return nil;

	__weak __typeof__(self) weakSelf = self;
	[TGClient shared].onChatsChanged = ^{
		TGChatListStore *me = weakSelf;
		if (!me) return;
		if (me->_onChatsChanged)
			me->_onChatsChanged();
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGChatListStoreChangedNotification
							  object:me];
	};
	[TGClient shared].onArchiveChanged = ^{
		TGChatListStore *me = weakSelf;
		if (!me) return;
		if (me->_onArchiveChanged)
			me->_onArchiveChanged();
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGChatListStoreChangedNotification
							  object:me];
	};
	[TGClient shared].onConnectionState = ^(TGConnectionState state, NSString *text){
		TGChatListStore *me = weakSelf;
		if (me && me->_onConnectionState)
			me->_onConnectionState(state, text);
	};
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(unreadTotalChanged:)
				name:TGUnreadTotalChangedNotification object:nil];
	_previewImages = [[TGImageLruCache alloc] initWithCapacity:80];
	_previewRequests = [NSMutableSet set];
	return self;
}

- (void)unreadTotalChanged:(NSNotification *)note {
	NSInteger count = [note.userInfo[@"count"] integerValue];
	if (count == _unreadTotal)
		return;
	_unreadTotal = count;
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatListStoreChangedNotification object:self];
}

#pragma mark - data

- (NSArray *)chats { return [TGClient shared].chats; }
- (NSArray *)archivedChats { return [TGClient shared].archivedChats; }
- (NSArray *)folders { return [TGClient shared].folders; }
- (NSUInteger)chatsCached { return [TGClient shared].chatsCached; }
- (int64_t)savedMessagesChatId { return [[TGClient shared] savedMessagesChatId]; }
- (NSDictionary *)me { return [TGClient shared].me; }
- (NSInteger)unreadTotal { return _unreadTotal; }

+ (NSInteger)activeAccountSlot { return [TGClient activeAccountSlot]; }

- (void (^)(void))onChatsChanged { return _onChatsChanged; }
- (void)setOnChatsChanged:(void (^)(void))block { _onChatsChanged = [block copy]; }
- (void (^)(void))onArchiveChanged { return _onArchiveChanged; }
- (void)setOnArchiveChanged:(void (^)(void))block { _onArchiveChanged = [block copy]; }
- (void (^)(TGConnectionState, NSString *))onConnectionState { return _onConnectionState; }
- (void)setOnConnectionState:(void (^)(TGConnectionState, NSString *))block {
	_onConnectionState = [block copy];
}

- (void)loadChats { [[TGClient shared] loadChats]; }

- (void)chatsInFolder:(NSInteger)folderId completion:(void (^)(NSArray *))completion {
	[[TGClient shared] chatsInFolder:folderId completion:completion];
}

- (BOOL)chatIsSavedMessages:(int64_t)chatId {
	return [[TGClient shared] chatIsSavedMessages:chatId];
}

- (NSString *)titleForChat:(int64_t)chatId {
	return [[TGClient shared] titleForChat:chatId];
}

#pragma mark - chat actions

- (void)setPinnedChatIds:(NSArray *)chatIds {
	[[TGClient shared] send:@{
		@"@type"     : @"setPinnedChats",
		@"chat_list" : @{@"@type" : @"chatListMain"},
		@"chat_ids"  : chatIds ?: @[],
	}];
}

- (void)setChat:(int64_t)chatId pinned:(BOOL)pinned {
	[[TGClient shared] send:@{
		@"@type"     : @"toggleChatIsPinned",
		@"chat_list" : @{@"@type" : @"chatListMain"},
		@"chat_id"   : @(chatId),
		@"is_pinned" : @(pinned),
	}];
}

- (void)setChat:(int64_t)chatId archived:(BOOL)archived {
	[[TGClient shared] send:@{
		@"@type"     : @"addChatToList",
		@"chat_id"   : @(chatId),
		@"chat_list" : @{@"@type" :
				(archived ? @"chatListArchive" : @"chatListMain")},
	}];
}

- (void)setChat:(int64_t)chatId markedUnread:(BOOL)unread {
	[[TGClient shared] send:@{
		@"@type"               : @"toggleChatIsMarkedAsUnread",
		@"chat_id"             : @(chatId),
		@"is_marked_as_unread" : @(unread),
	}];
}

- (void)setChat:(int64_t)chatId muted:(BOOL)muted {
	// setChatNotificationSettings replaces the whole record, so the client
	// keeps the merge of what the chat already had.
	[[TGClient shared] setChat:chatId muted:muted];
}

- (void)deleteChat:(int64_t)chatId {
	[[TGClient shared] deleteChat:chatId];
}

- (void)deleteChatForEveryone:(int64_t)chatId completion:(void (^)(NSString *))completion {
	[[TGClient shared] deleteChatForEveryone:chatId completion:completion];
}

- (void)createSupergroupNamed:(NSString *)title description:(NSString *)description
					isChannel:(BOOL)isChannel completion:(void (^)(int64_t))completion {
	[[TGClient shared] createSupergroupNamed:title description:description
								   isChannel:isChannel completion:completion];
}

- (void)reorderFoldersToLocalIds:(NSArray *)order mainListAt:(NSInteger)mainIndex {
	[[TGClient shared] reorderFoldersToLocalIds:order mainListAt:mainIndex];
}

- (void)markRead:(NSArray *)messageIds inChat:(int64_t)chatId {
	[[TGMessageStore shared] markRead:messageIds inChat:chatId];
}

- (void)searchMessages:(NSString *)query completion:(void (^)(NSArray *))completion {
	[[TGClient shared] searchMessages:query completion:completion];
}

- (void)activeStoryRowsForList:(NSString *)list completion:(void (^)(NSArray *))completion {
	[[TGClient shared] activeStoryRowsForList:list completion:completion];
}

- (void)setActiveStoriesList:(NSString *)list forChat:(int64_t)chatId
				  completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] setActiveStoriesList:list forChat:chatId completion:completion];
}

#pragma mark - M24 row facts

- (NSString *)previewKindForChat:(NSDictionary *)chat {
	return [chat[@"previewKind"] isKindOfClass:NSString.class]
			? chat[@"previewKind"] : @"";
}

- (NSNumber *)previewFileIdForChat:(NSDictionary *)chat {
	NSNumber *fileId = chat[@"previewFileId"];
	return [fileId isKindOfClass:NSNumber.class] && fileId.longLongValue > 0
			? fileId : nil;
}

/// Folder ids live on the chat as chatListFolder records; the names are the
/// folder list's. Two at most, so the badge stays a badge.
- (NSString *)folderTagForChat:(NSDictionary *)chat {
	id lists = chat[@"chatLists"];
	if (![lists isKindOfClass:NSArray.class] || [(NSArray *)lists count] == 0)
		lists = chat[@"folderIds"];
	if (![lists isKindOfClass:NSArray.class] || [(NSArray *)lists count] == 0)
		return @"";
	NSArray *folders = self.folders;
	NSMutableArray *names = [NSMutableArray array];
	for (id item in lists){
		NSInteger folderId = 0;
		if ([item isKindOfClass:NSNumber.class])
			folderId = [item integerValue];
		else if ([item isKindOfClass:NSDictionary.class])
			folderId = [item[@"chat_folder_id"] integerValue];
		else
			continue;
		for (NSDictionary *folder in folders){
			if ([folder[@"id"] integerValue] != folderId)
				continue;
			NSString *name = folder[@"title"];
			if ([name isKindOfClass:NSString.class] && name.length &&
					![names containsObject:name]){
				[names addObject:name];
			}
			break;
		}
		if (names.count == 2)
			break;
	}
	return names.count ? [names componentsJoinedByString:@", "] : @"";
}

- (NSString *)trailingBadgeForChat:(NSDictionary *)chat {
	NSMutableArray *parts = [NSMutableArray array];
	NSString *folder = [self folderTagForChat:chat];
	if (folder.length)
		[parts addObject:folder];
	NSString *reactions = chat[@"previewReactionSummary"];
	if ([reactions isKindOfClass:NSString.class] && reactions.length)
		[parts addObject:reactions];
	NSInteger pollVotes = [self unreadPollVotesForChat:chat];
	if (pollVotes <= 0){
		NSNumber *votes = chat[@"previewPollVotes"];
		pollVotes = [votes isKindOfClass:NSNumber.class] ? votes.integerValue : 0;
	}
	if (pollVotes > 0)
		[parts addObject:[NSString stringWithFormat:@"%@ · %ld",
				TGLocalized(@"Poll"), (long)pollVotes]];
	return [parts componentsJoinedByString:@" · "];
}

- (NSInteger)unreadReactionsForChat:(NSDictionary *)chat {
	return [chat[@"unreadReactions"] integerValue];
}

- (NSInteger)unreadPollVotesForChat:(NSDictionary *)chat {
	return [chat[@"unreadPollVotes"] integerValue];
}

- (NSString *)compactBadgeTextForCount:(NSInteger)count {
	if (count <= 0)
		return @"";
	if (count > 99)
		return @"99+";
	return [NSString stringWithFormat:@"%ld", (long)count];
}

#pragma mark - preview thumbnails

- (UIImage *)cachedPreviewImageForFileId:(NSNumber *)fileId {
	if (![fileId isKindOfClass:NSNumber.class] || fileId.longLongValue <= 0)
		return nil;
	return [_previewImages objectForKey:fileId];
}

- (void)loadPreviewImageForFileId:(NSNumber *)fileId {
	if (![fileId isKindOfClass:NSNumber.class] || fileId.longLongValue <= 0)
		return;
	if ([_previewImages objectForKey:fileId] || [_previewRequests containsObject:fileId])
		return;
	[_previewRequests addObject:fileId];
	__weak __typeof__(self) weakSelf = self;
	[[TGDownloadStore shared] downloadFile:fileId.integerValue completion:^(NSString *path){
		dispatch_async(dispatch_get_main_queue(), ^{
			TGChatListStore *me = weakSelf;
			if (!me)
				return;
			[me->_previewRequests removeObject:fileId];
			UIImage *image = path.length
					? [[UIImage alloc] initWithContentsOfFile:path] : nil;
			if (!image)
				return;
			[me->_previewImages setObject:image forKey:fileId];
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGChatListPreviewImageLoadedNotification
								  object:me
								userInfo:@{@"fileId" : fileId}];
		});
	}];
}

@end
