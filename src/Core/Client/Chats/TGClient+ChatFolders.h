#import "TGClient+Base.h"

@interface TGClient (ChatFolders)

- (int64_t)lastReadOutboxForChat:(int64_t)chatId;

/// The newest incoming message you have read in a chat; 0 when unknown.
- (int64_t)lastReadInboxForChat:(int64_t)chatId;

/// Profile photo file id of a chat we already know about, or nil. Groups and
/// channels have no user record, so this is where their picture comes from.
- (NSNumber *)photoFileIdForChat:(int64_t)chatId;

/// Writes the action bar over an unknown chat - its kind, a join request's
/// words, the account details to add a contact by - into a chat dict.
- (void)mergeActionBar:(NSDictionary *)bar intoChatRow:(NSMutableDictionary *)row;

/// One TDLib member record as the row a member list draws: "id", "name",
/// "status" (owner/admin/restricted/banned/left/member) and "owner"
/// (NSNumber). nil when the record names no user.
FOUNDATION_EXPORT NSDictionary *TGMemberRowForMember(NSDictionary *member,
													  NSString *name);

/// Members in a group or supergroup; 0 for anything else.
- (void)memberCountForChat:(int64_t)chatId completion:(void (^)(NSInteger count))completion;

/// The chat's real kind, even when the chat is not in chatsById: a chat opened
/// from a profile or a link has no cached row, and guessing private put
/// presence under a channel's name. The answer carries "isGroup", "isChannel",
/// "isMember", "memberCount", the raw "status", "silent" (the chat's default
/// silent send) and "canBeAnonymous". For a group the membership
/// comes from the supergroup or basic group record, not from the chat.
- (void)chatKindForChat:(int64_t)chatId
             completion:(void (^)(NSDictionary *kind))completion;

/// Joins a public group or channel. `ok` only when TDLib says the account is now a
/// member; `requestSent` when an admin has to approve it first.
- (void)joinChat:(int64_t)chatId completion:(void (^)(BOOL ok, BOOL requestSent))completion;

- (void)closeChat:(int64_t)chatId;

/// Makes a folder holding `chatIds`. `icon` is one of Telegram's own icon
/// names and may be nil. The completion gets the new folder's id, or 0.
- (void)createFolderNamed:(NSString *)name
					 icon:(NSString *)icon
				withChats:(NSArray *)chatIds
			   completion:(void (^)(NSInteger folderId))completion;

/// The folder as it stands - its chats, its flags - or nil if it is gone.
- (void)folderDetails:(NSInteger)folderId
		   completion:(void (^)(NSDictionary *folder))completion;

/// Renames a folder, or changes which chats it holds, or both: a nil leaves
/// that part as it was. An edit replaces the whole folder on Telegram's side,
/// so this reads it first.
- (void)editFolder:(NSInteger)folderId
			  name:(NSString *)name
			 chats:(NSArray *)chatIds
		completion:(void (^)(BOOL ok))completion;

/// Drops the folder. The chats in it stay; `leaveChatIds` is for the ones
/// you also want out of, and is usually empty.
- (void)deleteFolder:(NSInteger)folderId leavingChats:(NSArray *)leaveChatIds;

/// The order of the pill strip. "All chats" is a position in that order
/// rather than a folder of its own.
- (void)reorderFolderIds:(NSArray *)folderIds mainListAt:(NSInteger)position;

/// The pill strip's drag result: the local order is written first so the
/// strip holds it while the wire request is still in flight, then the same
/// order is sent.
- (void)reorderFoldersToLocalIds:(NSArray *)folderIds
					 mainListAt:(NSInteger)position;

/// Telegram's own suggestions, each with the sentence their client shows
/// under it: "title", "description", and "folder" ready to be created.
- (void)recommendedFoldersWithCompletion:(void (^)(NSArray *folders))completion;

- (void)createRecommendedFolder:(NSDictionary *)folder
					 completion:(void (^)(NSInteger folderId))completion;

/// Marks every chat of one chat list read: the folder's badge clears because
/// the list was read as a whole, not chat by chat. folderId 0 = "All chats".
- (void)readChatListOfFolder:(NSInteger)folderId archived:(BOOL)archived;

/// Asks TDLib for the archive settings again and swaps the local copy under
/// the completion; the block runs whether the answer is good or bad, because
/// a page built on the old copy must not wait for one.
- (void)refreshArchiveChatListSettings:(void (^)(void))completion;

/// Sets all three at once - the archive settings are one object in TDLib,
/// not three unrelated switches.
- (void)setArchiveSettingsArchiveAndMute:(BOOL)archiveAndMute
					 keepUnmutedArchived:(BOOL)keepUnmuted
				   keepFolderChatsArchived:(BOOL)keepFolders;

@end
