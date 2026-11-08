#import "TGClient+Base.h"

@interface TGClient (QuickReplies)

#pragma mark - quick replies

/// The shortcuts this client knows, in Telegram's order. Rows carry "id",
/// "name", "messageCount" and "preview".
@property (nonatomic, readonly) NSArray *quickReplyShortcuts;

/// Sends loadQuickReplyShortcuts, then answers the cache as the updates
/// fill it. `completion` gets the same rows as the property.
- (void)loadQuickReplyShortcutsWithCompletion:
        (void (^)(NSArray *shortcuts))completion;

/// One shortcut's messages, flattened: "id", "text", "kind" and "photoId".
/// A load request goes out first; an empty array is a real empty shortcut.
- (void)loadQuickReplyMessagesForShortcut:(NSInteger)shortcutId
                               completion:(void (^)(NSArray *messages))completion;

/// Telegram's name check. `ok` is NO and `error` holds the sentence when the
/// name is taken or malformed.
- (void)checkQuickReplyShortcutName:(NSString *)name
                         completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setQuickReplyShortcutName:(NSInteger)shortcutId
                             name:(NSString *)name
                       completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)deleteQuickReplyShortcut:(NSInteger)shortcutId
                      completion:(void (^)(BOOL ok, NSString *error))completion;

/// `shortcutIds` is the whole order, first row first.
- (void)reorderQuickReplyShortcuts:(NSArray *)shortcutIds
                        completion:(void (^)(BOOL ok, NSString *error))completion;

/// Adding a message is how a new shortcut is made: there is no empty
/// create request. `shortcutName` names it; Telegram creates it on success.
- (void)addQuickReplyShortcutMessage:(NSString *)shortcutName
                                text:(NSString *)text
                          completion:(void (^)(NSDictionary *message, NSString *error))completion;

/// Adds two or more text messages as one album.
- (void)addQuickReplyShortcutMessageAlbum:(NSString *)shortcutName
                                    texts:(NSArray *)texts
                               completion:(void (^)(NSArray *messages, NSString *error))completion;

- (void)editQuickReplyMessage:(int64_t)messageId
                   shortcutId:(NSInteger)shortcutId
                         text:(NSString *)text
                   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)deleteQuickReplyShortcutMessages:(NSArray *)messageIds
                              shortcutId:(NSInteger)shortcutId
                              completion:(void (^)(BOOL ok, NSString *error))completion;

/// Puts messages TDLib still remembers back into the shortcut. The ids are
/// the ones deleteQuickReplyShortcutMessages took.
- (void)readdQuickReplyShortcutMessages:(NSArray *)messageIds
                           shortcutName:(NSString *)shortcutName
                             completion:(void (^)(NSArray *messages, NSString *error))completion;

/// Sends the shortcut into a chat. `sendingId` is the client's own marker;
/// the answer carries the messages TDLib queued.
- (void)sendQuickReplyShortcutMessages:(NSInteger)shortcutId
                                toChat:(int64_t)chatId
                             sendingId:(int32_t)sendingId
                            completion:(void (^)(NSArray *messages, NSString *error))completion;


@end
