//
// TGStickerStore - forwards the sticker shelf's questions to the client.
// One method per line the client already answers; the point is the boundary
// the panel sees, not a new implementation.
//
#import "TGStickerStore.h"
#import "TGClient.h"

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
	[[TGClient shared] downloadFile:fileId completion:completion];
}

- (void)downloadFile:(NSInteger)fileId priority:(NSInteger)priority
          completion:(void (^)(NSString *path))completion {
	[[TGClient shared] downloadFile:fileId priority:priority completion:completion];
}



















































@end
