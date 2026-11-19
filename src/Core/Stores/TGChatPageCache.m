//
// TGChatPageCache.m - see TGChatPageCache.h.
//
#import "TGChatPageCache.h"
#import "TGBase64.h"

/// A first screen and a little above it. Each message is measured before the
/// page shows: thirty long posts were 315 ms of reading on the main thread
/// and seconds of measuring on the iPod touch 4; TDLib's page follows.
static const NSUInteger kTGChatPageMessages = 10;
/// Chats whose page is kept; older files are deleted on the next save.
static const NSUInteger kTGChatPagesKept = 10;

BOOL TGChatPageIsCurrent(NSArray *page, int64_t lastMessageId) {
	if (![page isKindOfClass:NSArray.class] || !page.count || lastMessageId <= 0)
		return NO;
	NSDictionary *newest = page.lastObject;
	return [newest isKindOfClass:NSDictionary.class] &&
			[newest[@"id"] longLongValue] == lastMessageId;
}

/// A message's bytes (a voice note's waveform) as {"$data": base64}: JSON has
/// no bytes, and every voice message would have kept its chat from a page.
static id TGChatPageToJSON(id value) {
	if ([value isKindOfClass:NSData.class])
		return @{ @"$data" : TGBase64Encode(value) ?: @"" };
	if ([value isKindOfClass:NSDictionary.class]) {
		NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:[value count]];
		[(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
			out[key] = TGChatPageToJSON(obj);
		}];
		return out;
	}
	if ([value isKindOfClass:NSArray.class]) {
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:[value count]];
		for (id obj in (NSArray *)value)
			[out addObject:TGChatPageToJSON(obj)];
		return out;
	}
	return value;
}

static id TGChatPageFromJSON(id value) {
	if ([value isKindOfClass:NSDictionary.class]) {
		NSDictionary *dict = value;
		if (dict.count == 1 && [dict[@"$data"] isKindOfClass:NSString.class])
			return TGBase64Decode(dict[@"$data"]) ?: [NSData data];
		NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:dict.count];
		[dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
			out[key] = TGChatPageFromJSON(obj);
		}];
		return out;
	}
	if ([value isKindOfClass:NSArray.class]) {
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:[value count]];
		for (id obj in (NSArray *)value)
			[out addObject:TGChatPageFromJSON(obj)];
		return out;
	}
	return value;
}

int64_t TGChatPageNewestId(NSArray *page) {
	NSDictionary *newest = [page isKindOfClass:NSArray.class] ? page.lastObject : nil;
	return [newest isKindOfClass:NSDictionary.class] ? [newest[@"id"] longLongValue] : 0;
}

BOOL TGChatPageHasUnread(NSArray *page, int64_t readInbox) {
	for (NSDictionary *m in page)
		if ([m isKindOfClass:NSDictionary.class] && ![m[@"outgoing"] boolValue] &&
				![m[@"service"] boolValue] && [m[@"id"] longLongValue] > readInbox)
			return YES;
	return NO;
}

BOOL TGChatPageIsUsable(NSArray *page, int64_t lastMessageId) {
	int64_t newest = TGChatPageNewestId(page);
	return newest > 0 && lastMessageId > 0 && newest <= lastMessageId;
}

@implementation TGChatPageCache

static dispatch_queue_t TGChatPageQueue(void) {
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("org.legacy.itg.chat-pages", DISPATCH_QUEUE_SERIAL);
		dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
	});
	return queue;
}

+ (NSString *)directoryForAccount:(int64_t)accountId {
	NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
			NSUserDomainMask, YES) firstObject];
	return [[caches stringByAppendingPathComponent:@"chat-pages"]
			stringByAppendingPathComponent:[NSString stringWithFormat:@"%lld", accountId]];
}

static NSString *TGChatPagePath(int64_t chatId, int64_t accountId) {
	return [[TGChatPageCache directoryForAccount:accountId]
			stringByAppendingPathComponent:[NSString stringWithFormat:@"%lld.json", chatId]];
}

+ (void)savePage:(NSArray *)messages chat:(int64_t)chatId account:(int64_t)accountId {
	if (!chatId || !accountId || !messages.count)
		return;
	NSUInteger keep = MIN(messages.count, kTGChatPageMessages);
	NSArray *page = [messages subarrayWithRange:NSMakeRange(messages.count - keep, keep)];
	dispatch_async(TGChatPageQueue(), ^{
		// JSON, not a keyed archive: unarchiving thirty long posts took
		// 380-470 ms of the main thread on the iPod touch 4. A message JSON
		// cannot hold (a date, data) means no page for this chat.
		id json = TGChatPageToJSON(page);
		if (![NSJSONSerialization isValidJSONObject:json])
			return;
		NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:NULL];
		if (!data)
			return;
		NSString *dir = [self directoryForAccount:accountId];
		NSFileManager *fm = [NSFileManager defaultManager];
		[fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
		[data writeToFile:TGChatPagePath(chatId, accountId) atomically:YES];

		NSArray *names = [fm contentsOfDirectoryAtPath:dir error:NULL];
		if (names.count <= kTGChatPagesKept)
			return;
		NSMutableArray *files = [NSMutableArray array];
		for (NSString *name in names) {
			NSString *path = [dir stringByAppendingPathComponent:name];
			NSDate *date = [fm attributesOfItemAtPath:path error:NULL].fileModificationDate;
			if (date)
				[files addObject:@[ date, path ]];
		}
		[files sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) {
			return [b[0] compare:a[0]];
		}];
		for (NSUInteger i = kTGChatPagesKept; i < files.count; i++)
			[fm removeItemAtPath:files[i][1] error:NULL];
	});
}

+ (NSArray *)pageForChat:(int64_t)chatId account:(int64_t)accountId {
	if (!chatId || !accountId)
		return nil;
	NSData *data = [NSData dataWithContentsOfFile:TGChatPagePath(chatId, accountId)];
	if (!data.length)
		return nil;
	id page = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
	return [page isKindOfClass:NSArray.class] ? TGChatPageFromJSON(page) : nil;
}

@end
