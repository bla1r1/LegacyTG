//
// TGChatListStore.h - the chat list's data and its row facts.
//
// Views ask this store for the chats, folders, archive and the M24 preview
// facts (kind, thumbnail file, reaction/poll/folder badge). The client caches
// stay behind it.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "TGClientTypes.h"
#import "TGClientNotifications.h"

/// Posted when the list, the archive, the folders or the unread total changed.
extern NSString *const TGChatListStoreChangedNotification;

/// Posted on the main queue when a preview thumbnail finished downloading.
/// userInfo "fileId" is the NSNumber that was asked for.
extern NSString *const TGChatListPreviewImageLoadedNotification;

@interface TGChatListStore : NSObject

+ (instancetype)shared;

/// The account slot the snapshot file is named after.
+ (NSInteger)activeAccountSlot;

@property (nonatomic, readonly) NSArray *chats;
@property (nonatomic, readonly) NSArray *archivedChats;
@property (nonatomic, readonly) NSArray *folders;
@property (nonatomic, readonly) NSUInteger chatsCached;
@property (nonatomic, readonly) int64_t savedMessagesChatId;
@property (nonatomic, readonly) NSDictionary *me;
@property (nonatomic, readonly) NSInteger unreadTotal;

/// The screen's handlers. The store owns the client's single callback slots
/// and calls these from them, so two list screens cannot overwrite each other.
@property (nonatomic, copy) void (^onChatsChanged)(void);
@property (nonatomic, copy) void (^onArchiveChanged)(void);
@property (nonatomic, copy) void (^onConnectionState)(TGConnectionState state, NSString *text);

- (void)loadChats;
- (void)chatsInFolder:(NSInteger)folderId completion:(void (^)(NSArray *chats))completion;
- (BOOL)chatIsSavedMessages:(int64_t)chatId;
- (NSString *)titleForChat:(int64_t)chatId;

#pragma mark - chat actions

- (void)setPinnedChatIds:(NSArray *)chatIds;
- (void)setChat:(int64_t)chatId pinned:(BOOL)pinned;
- (void)setChat:(int64_t)chatId muted:(BOOL)muted;
- (void)setChat:(int64_t)chatId archived:(BOOL)archived;
- (void)setChat:(int64_t)chatId markedUnread:(BOOL)unread;
- (void)deleteChat:(int64_t)chatId;
- (void)deleteChatForEveryone:(int64_t)chatId completion:(void (^)(NSString *error))completion;
- (void)createSupergroupNamed:(NSString *)title description:(NSString *)description
					isChannel:(BOOL)isChannel completion:(void (^)(int64_t chatId))completion;
- (void)reorderFoldersToLocalIds:(NSArray *)order mainListAt:(NSInteger)mainIndex;
- (void)markRead:(NSArray *)messageIds inChat:(int64_t)chatId;

/// The in-chat search from the list's pull-down; the store is the seam the
/// list uses for it too.
- (void)searchMessages:(NSString *)query completion:(void (^)(NSArray *messages))completion;

#pragma mark - stories

- (void)activeStoryRowsForList:(NSString *)list completion:(void (^)(NSArray *rows))completion;
- (void)setActiveStoriesList:(NSString *)list forChat:(int64_t)chatId
				  completion:(void (^)(BOOL ok, NSString *error))completion;

#pragma mark - M24 row facts

- (NSString *)previewKindForChat:(NSDictionary *)chat;
- (NSNumber *)previewFileIdForChat:(NSDictionary *)chat;
/// Folder names + reaction summary + poll count, one compact trailing badge.
- (NSString *)trailingBadgeForChat:(NSDictionary *)chat;
- (NSString *)folderTagForChat:(NSDictionary *)chat;
- (NSInteger)unreadReactionsForChat:(NSDictionary *)chat;
- (NSInteger)unreadPollVotesForChat:(NSDictionary *)chat;
/// 1..99, then "99+"; empty for zero.
- (NSString *)compactBadgeTextForCount:(NSInteger)count;

/// A preview thumbnail already decoded, or nil until it lands.
- (UIImage *)cachedPreviewImageForFileId:(NSNumber *)fileId;
/// Ask for one; the image notification follows on the main queue.
- (void)loadPreviewImageForFileId:(NSNumber *)fileId;

@end
