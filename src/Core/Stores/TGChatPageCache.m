//
// TGChatPageCache.m - see TGChatPageCache.h.
//
#import "TGChatPageCache.h"
#import "TGBase64.h"
#import <sqlite3.h>

/// 30 newest messages per chat: covers a full screen plus scrollback when
/// TDLib's own message database is off.
static const NSUInteger kTGChatPageMessages = 30;
/// Chats kept in the local SQLite page cache; older rows are trimmed on save.
static const NSUInteger kTGChatPagesKept = 50;

BOOL TGChatPageIsCurrent(NSArray *page, int64_t lastMessageId) {
	if (![page isKindOfClass:NSArray.class] || !page.count || lastMessageId <= 0)
		return NO;
	NSDictionary *newest = page.lastObject;
	return [newest isKindOfClass:NSDictionary.class] &&
			[newest[@"id"] longLongValue] == lastMessageId;
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

static NSString *TGChatPageDBPath(int64_t accountId) {
	return [[TGChatPageCache directoryForAccount:accountId]
			stringByAppendingPathComponent:@"pages.sqlite"];
}

static id TGPageJSONSafe(id value) {
	if ([value isKindOfClass:NSData.class])
		return @{ @"$data" : TGBase64Encode(value) ?: @"" };
	if ([value isKindOfClass:NSDictionary.class]) {
		NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:[value count]];
		[(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
			out[key] = TGPageJSONSafe(obj);
		}];
		return out;
	}
	if ([value isKindOfClass:NSArray.class]) {
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:[value count]];
		for (id obj in (NSArray *)value)
			[out addObject:TGPageJSONSafe(obj)];
		return out;
	}
	return value;
}

static id TGPageJSONRestored(id value) {
	if ([value isKindOfClass:NSDictionary.class]) {
		NSDictionary *dict = value;
		if (dict.count == 1 && [dict[@"$data"] isKindOfClass:NSString.class])
			return TGBase64Decode(dict[@"$data"]) ?: [NSData data];
		NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:dict.count];
		[dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
			out[key] = TGPageJSONRestored(obj);
		}];
		return out;
	}
	if ([value isKindOfClass:NSArray.class]) {
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:[value count]];
		for (id obj in (NSArray *)value)
			[out addObject:TGPageJSONRestored(obj)];
		return out;
	}
	return value;
}

static sqlite3 *TGOpenPageDB(int64_t accountId, BOOL create) {
	NSString *path = TGChatPageDBPath(accountId);
	if (!create && ![[NSFileManager defaultManager] fileExistsAtPath:path])
		return NULL;
	if (create) {
		[[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
				withIntermediateDirectories:YES attributes:nil error:NULL];
	}
	sqlite3 *db = NULL;
	int flags = create ? (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE) : SQLITE_OPEN_READONLY;
	if (sqlite3_open_v2(path.UTF8String, &db, flags, NULL) != SQLITE_OK) {
		if (db) sqlite3_close(db);
		return NULL;
	}
	sqlite3_busy_timeout(db, 1000);
	if (create) {
		sqlite3_exec(db,
				"PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;"
				"CREATE TABLE IF NOT EXISTS chat_pages ("
				"  chat_id INTEGER PRIMARY KEY,"
				"  updated_at REAL NOT NULL,"
				"  payload BLOB NOT NULL"
				");"
				"CREATE INDEX IF NOT EXISTS idx_chat_pages_updated ON chat_pages(updated_at);"
				"CREATE TABLE IF NOT EXISTS chat_list ("
				"  slot INTEGER PRIMARY KEY,"
				"  payload BLOB NOT NULL"
				");",
				NULL, NULL, NULL);
	}
	return db;
}

+ (void)savePage:(NSArray *)messages chat:(int64_t)chatId account:(int64_t)accountId {
	if (!chatId || !accountId || !messages.count)
		return;
	NSUInteger keep = MIN(messages.count, kTGChatPageMessages);
	NSArray *page = [messages subarrayWithRange:NSMakeRange(messages.count - keep, keep)];
	dispatch_async(TGChatPageQueue(), ^{
		id json = TGPageJSONSafe(page);
		if (![NSJSONSerialization isValidJSONObject:json])
			return;
		NSData *blob = [NSJSONSerialization dataWithJSONObject:json options:0 error:NULL];
		if (!blob.length)
			return;
		sqlite3 *db = TGOpenPageDB(accountId, YES);
		if (!db)
			return;
		sqlite3_stmt *stmt = NULL;
		if (sqlite3_prepare_v2(db,
				"INSERT OR REPLACE INTO chat_pages (chat_id, updated_at, payload) VALUES (?, ?, ?);",
				-1, &stmt, NULL) == SQLITE_OK) {
			sqlite3_bind_int64(stmt, 1, chatId);
			sqlite3_bind_double(stmt, 2, CFAbsoluteTimeGetCurrent());
			sqlite3_bind_blob(stmt, 3, blob.bytes, (int)blob.length, SQLITE_TRANSIENT);
			sqlite3_step(stmt);
			sqlite3_finalize(stmt);
		}
		if (sqlite3_prepare_v2(db,
				"DELETE FROM chat_pages WHERE chat_id NOT IN "
				"(SELECT chat_id FROM chat_pages ORDER BY updated_at DESC LIMIT ?);",
				-1, &stmt, NULL) == SQLITE_OK) {
			sqlite3_bind_int(stmt, 1, (int)kTGChatPagesKept);
			sqlite3_step(stmt);
			sqlite3_finalize(stmt);
		}
		sqlite3_close(db);
	});
}

+ (NSArray *)pageForChat:(int64_t)chatId account:(int64_t)accountId {
	if (!chatId || !accountId)
		return nil;
	sqlite3 *db = TGOpenPageDB(accountId, NO);
	if (!db)
		return nil;
	NSData *blob = nil;
	sqlite3_stmt *stmt = NULL;
	if (sqlite3_prepare_v2(db,
			"SELECT payload FROM chat_pages WHERE chat_id = ? LIMIT 1;",
			-1, &stmt, NULL) == SQLITE_OK) {
		sqlite3_bind_int64(stmt, 1, chatId);
		if (sqlite3_step(stmt) == SQLITE_ROW) {
			const void *bytes = sqlite3_column_blob(stmt, 0);
			int len = sqlite3_column_bytes(stmt, 0);
			if (bytes && len > 0)
				blob = [NSData dataWithBytes:bytes length:(NSUInteger)len];
		}
		sqlite3_finalize(stmt);
	}
	sqlite3_close(db);
	if (!blob.length)
		return nil;
	id object = [NSJSONSerialization JSONObjectWithData:blob options:0 error:NULL];
	id restored = object ? TGPageJSONRestored(object) : nil;
	return [restored isKindOfClass:NSArray.class] ? restored : nil;
}

+ (void)saveChats:(NSArray *)chats account:(int64_t)accountId {
	if (!accountId || !chats.count)
		return;
	NSArray *snapshot = [chats copy];
	dispatch_async(TGChatPageQueue(), ^{
		id json = TGPageJSONSafe(snapshot);
		if (![NSJSONSerialization isValidJSONObject:json])
			return;
		NSData *blob = [NSJSONSerialization dataWithJSONObject:json options:0 error:NULL];
		if (!blob.length)
			return;
		sqlite3 *db = TGOpenPageDB(accountId, YES);
		if (!db)
			return;
		sqlite3_stmt *stmt = NULL;
		if (sqlite3_prepare_v2(db,
				"INSERT OR REPLACE INTO chat_list (slot, payload) VALUES (1, ?);",
				-1, &stmt, NULL) == SQLITE_OK) {
			sqlite3_bind_blob(stmt, 1, blob.bytes, (int)blob.length, SQLITE_TRANSIENT);
			sqlite3_step(stmt);
			sqlite3_finalize(stmt);
		}
		sqlite3_close(db);
	});
}

+ (NSArray *)chatsForAccount:(int64_t)accountId {
	if (!accountId)
		return nil;
	sqlite3 *db = TGOpenPageDB(accountId, NO);
	if (!db)
		return nil;
	NSData *blob = nil;
	sqlite3_stmt *stmt = NULL;
	if (sqlite3_prepare_v2(db,
			"SELECT payload FROM chat_list WHERE slot = 1 LIMIT 1;",
			-1, &stmt, NULL) == SQLITE_OK) {
		if (sqlite3_step(stmt) == SQLITE_ROW) {
			const void *bytes = sqlite3_column_blob(stmt, 0);
			int len = sqlite3_column_bytes(stmt, 0);
			if (bytes && len > 0)
				blob = [NSData dataWithBytes:bytes length:(NSUInteger)len];
		}
		sqlite3_finalize(stmt);
	}
	sqlite3_close(db);
	if (!blob.length)
		return nil;
	id object = [NSJSONSerialization JSONObjectWithData:blob options:0 error:NULL];
	id restored = object ? TGPageJSONRestored(object) : nil;
	return [restored isKindOfClass:NSArray.class] ? restored : nil;
}

@end
