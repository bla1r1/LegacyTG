//
// TGChatPageCache - the newest page of a chat as it was last shown, kept on
// disk so the chat can show it at once while TDLib reads its own database:
// 2.3-2.5 s on the iPod touch 4 before the first message.
//
#import <Foundation/Foundation.h>

/// Whether a saved page (oldest first) still ends at the chat's newest message.
FOUNDATION_EXPORT BOOL TGChatPageIsCurrent(NSArray *page, int64_t lastMessageId);
/// Whether it can be shown at all: it ends at or before the chat's newest
/// message. Newer messages come with TDLib's page, under it, the way
/// official shows what it holds and fills in the rest.
FOUNDATION_EXPORT BOOL TGChatPageIsUsable(NSArray *page, int64_t lastMessageId);
/// Whether the page holds a message the reader has not read: incoming, not
/// a service line, past `readInbox` (as the chat's unread line counts them;
/// the reader's own messages do not count, whatever their ids).
FOUNDATION_EXPORT BOOL TGChatPageHasUnread(NSArray *page, int64_t readInbox);
/// The id of the page's newest message, 0 for none.
FOUNDATION_EXPORT int64_t TGChatPageNewestId(NSArray *page);

@interface TGChatPageCache : NSObject

/// Keeps the newest messages of `messages` (oldest first) for the chat, off
/// the main thread; only the most recently saved chats are kept.
+ (void)savePage:(NSArray *)messages chat:(int64_t)chatId account:(int64_t)accountId;

/// The page saved for the chat, oldest first, or nil. Reads the file now:
/// a page is ~10 messages, and the chat needs it before
/// its first paint.
+ (NSArray *)pageForChat:(int64_t)chatId account:(int64_t)accountId;

/// Where an account's pages live, for tests and an account's removal.
+ (NSString *)directoryForAccount:(int64_t)accountId;

/// Keeps the chat list rows for `accountId` in the same SQLite store so
/// TDLib's chat_info_database can stay off without a blank list at launch.
+ (void)saveChats:(NSArray *)chats account:(int64_t)accountId;
+ (NSArray *)chatsForAccount:(int64_t)accountId;

@end
