//
// TGStickerStore - forwards the sticker shelf's questions to the client.
// One method per line the client already answers; the point is the boundary
// the panel sees, not a new implementation.
//
#import "TGStickerStore.h"
#import "TGClient.h"
#import "TGDownloadStore.h"
#import "TGJSONCache.h"

static NSString *TGStickerKeptPath(NSString *name, int64_t account) {
	NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
			NSUserDomainMask, YES) firstObject];
	return [caches stringByAppendingPathComponent:
			[NSString stringWithFormat:@"sticker-shelves/%lld/%@.json", account, name]];
}

@implementation TGStickerStore

+ (TGStickerStore *)shared {
	static TGStickerStore *one;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ one = [[TGStickerStore alloc] init]; });
	return one;
}

#pragma mark - reads





- (BOOL)accountHasPremium {
	id me = [TGClient shared].me;
	if (![me isKindOfClass:NSDictionary.class])
		return NO;
	id prem = me[@"is_premium"];
	if ([prem respondsToSelector:@selector(boolValue)])
		return [prem boolValue];
	return NO;
}

- (int64_t)myUserId {
	id me = [TGClient shared].me;
	if (![me isKindOfClass:NSDictionary.class])
		return 0;
	id uid = me[@"id"];
	if ([uid respondsToSelector:@selector(longLongValue)])
		return [uid longLongValue];
	return 0;
}





- (void)recentStickersWithCompletion:(void (^)(NSArray *stickers))completion {
	[[TGClient shared] recentStickersWithCompletion:completion];
}



















- (NSArray *)animationSearchEmojis {
	return [[TGClient shared] animationSearchEmojis];
}





- (void)allStickerEmojisForQuery:(NSString *)query
					  completion:(void (^)(NSArray *))completion {
	// An empty chat id asks across the installed shelf rather than one
	// chat's own picker, which is what the hold card wants.
	[[TGClient shared] allStickerEmojisForQuery:query chatId:0
								   stickerType:@"regular" mainOnly:NO
									completion:completion];
}







- (void)clearRecentStickers {
	[[TGClient shared] clearRecentStickersAttached:NO];
}

#pragma mark - commands











#pragma mark - files

- (void)downloadFile:(NSInteger)fileId completion:(void (^)(NSString *path))completion {
	[[TGDownloadStore shared] downloadFile:fileId completion:completion];
}

- (void)downloadFile:(NSInteger)fileId priority:(NSInteger)priority
          completion:(void (^)(NSString *path))completion {
	[[TGDownloadStore shared] downloadFile:fileId priority:priority completion:completion];
}



















































/// A list answered at once with what was last fetched (memory, then disk)
/// and again only when the fetch answers something else. Main thread.
- (void)keptList:(NSString *)name fetch:(void (^)(void (^)(NSArray *)))fetch
	  completion:(void (^)(NSArray *items))completion {
	[self keptList:name oncePerLaunch:NO fetch:fetch completion:completion];
}

/// `oncePerLaunch`: what is kept stands for the rest of the run once fetched
/// (a pack's stickers barely change; every pack's full JSON on every panel
/// open was 1.5-2.2 s of tg.receive on the iPod touch 4).
- (void)keptList:(NSString *)name oncePerLaunch:(BOOL)oncePerLaunch
		   fetch:(void (^)(void (^)(NSArray *)))fetch
	  completion:(void (^)(NSArray *items))completion {
	if (!completion)
		return;
	static NSMutableDictionary *kept;
	if (!kept)
		kept = [NSMutableDictionary dictionary];
	int64_t account = [self myUserId];
	NSString *key = [NSString stringWithFormat:@"%lld/%@", account, name];
	NSArray *known = kept[key];
	if (!known && account) {
		id saved = TGJSONCacheRead(TGStickerKeptPath(name, account));
		known = [saved isKindOfClass:NSArray.class] ? saved : nil;
		if (known)
			kept[key] = known;
	}
	if (known)
		completion(known);
	static NSMutableSet *fetchedThisLaunch;
	if (!fetchedThisLaunch)
		fetchedThisLaunch = [NSMutableSet set];
	if (oncePerLaunch && known && [fetchedThisLaunch containsObject:key])
		return;
	[fetchedThisLaunch addObject:key];
	fetch(^(NSArray *items) {
		items = items ? [NSArray arrayWithArray:items] : @[];
		if (known && [known isEqualToArray:items])
			return;
		kept[key] = items;
		completion(items);
		if (account)
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
				TGJSONCacheWrite(items, TGStickerKeptPath(name, account));
			});
	});
}

- (void)shelf:(TGStickerShelf)shelf completion:(void (^)(NSArray *items))completion {
	__weak typeof(self) weakSelf = self;
	[self keptList:[NSString stringWithFormat:@"%ld", (long)shelf] fetch:^(void (^done)(NSArray *)) {
		TGStickerStore *me = weakSelf;
		switch (shelf) {
			case TGStickerShelfOwned: [me ownedStickerSetsWithCompletion:done]; break;
			case TGStickerShelfTrending: [me trendingStickerSetsWithCompletion:done]; break;
			case TGStickerShelfArchived: [me archivedStickerSetsWithCompletion:done]; break;
			case TGStickerShelfRecent: [me recentStickersWithCompletion:done]; break;
			case TGStickerShelfFavorite: [me favoriteStickersWithCompletion:done]; break;
			case TGStickerShelfInstalled: [me installedStickerSetsWithCompletion:done]; break;
		}
	} completion:completion];
}

- (void)stickersInSetKept:(id)setId completion:(void (^)(NSArray *stickers))completion {
	if (!setId) {
		if (completion) completion(@[]);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self keptList:[NSString stringWithFormat:@"set-%@", setId] oncePerLaunch:YES fetch:^(void (^done)(NSArray *)) {
		[weakSelf stickersInSet:setId completion:done];
	} completion:completion];
}

- (void)savedAnimationsWithCompletion:(void (^)(NSArray *animations))completion {
	__weak typeof(self) weakSelf = self;
	[self keptList:@"saved-animations" fetch:^(void (^done)(NSArray *)) {
		[weakSelf fetchSavedAnimationsWithCompletion:done];
	} completion:completion];
}

@end
