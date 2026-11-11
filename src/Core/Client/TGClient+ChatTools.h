//
// TGClient+ChatTools.h - the chat half of Tier 2: folders' links and
// suggestions, invite-link administration, per-chat settings, event logs,
// statistics, similar chats, positions, and the account-level chat surfaces.
//
// One header because the screens that drive these are one family: the chat
// tools sheet, the folder editor, the search screen and the profile. Splitting
// them per noun produced seven categories that each re-read the same chat.
//
#import "TGClient+Base.h"

@interface TGClient (ChatTools)

#pragma mark - chat folders, the shared half

/// Approximate number of chats a not-yet-created folder would hold.
/// Pinned or always-included chats a folder suggests leaving when it is
/// deleted. The delete confirmation offers them; deleteFolder takes the ids.
/// The icon Telegram would draw for a folder that did not name one. Read
/// synchronously, so a folder row can show it without a round trip.
/// Invite links created for a shareable folder, flattened to "link", "name"
/// and "chatIds".
/// Chats from a folder that may be named in a folder invite link.
/// What a folder invite link points at: "name", "id", "missing" and "added"
/// chat id arrays. `folder` is nil when the link is dead.
/// Adopts a folder from a link. `chatIds` is the subset of the link's chats
/// the user chose to add; an empty array adds all of them.
/// Chats the owner of a shared folder has added since this account last
/// processed them.
/// The chat lists a chat may be moved into: main, archive and each folder.
/// Entries are carried as raw chatList dictionaries.
- (void)chatListsForChat:(int64_t)chatId
			  completion:(void (^)(NSArray *lists))completion;

#pragma mark - invite links, the administrator's half

/// One link, with every field the edit sheet needs.
/// Administrators and how many active and revoked links each made.
/// Members who joined through one link: "id", "name", "date", "approver".
/// A subscription link. `stars` is the price per period, `period` one of
/// 2592000, 60 or 300 seconds.
#pragma mark - join requests and bot seams

/// Answers an updateNewChatJoinRequest query (bots only, but this app still
/// carries the button in case a guard bot ever hands one over).
/// Every pending request at one link, or at all links when `link` is empty.
- (void)processAllJoinRequests:(int64_t)chatId
						  link:(NSString *)link
					   approve:(BOOL)approve
					completion:(void (^)(BOOL ok))completion;

/// Drops a bot's one-time or force-reply keyboard from a message.
- (void)deleteReplyMarkupInChat:(int64_t)chatId messageId:(int64_t)messageId;

/// The same for the keyboard the chat currently carries, found from the chat
/// row: what a key press on a one-time keyboard owes the server.
- (void)dismissReplyMarkupInChat:(int64_t)chatId;

#pragma mark - recently found chats

/// The recently found list, optionally narrowed by a query.
- (void)searchRecentlyFoundChats:(NSString *)query
					  completion:(void (^)(NSArray *chats))completion;

#pragma mark - discovery

/// Similar channels and the approximate total Telegram knows. Entries carry
/// "id", "title" and "members".
/// Tells Telegram a similar chat was opened from the list of another chat.
- (void)recommendedChatsWithCompletion:(void (^)(NSArray *chats))completion;

- (void)suitableDiscussionChatsWithCompletion:(void (^)(NSArray *chats))completion;

#pragma mark - public chats and usernames

/// `publicChatTypeHasUsername` or `publicChatTypeIsLocationBased`.
#pragma mark - account-level chat preferences

#pragma mark - the chat itself, read and changed

/// The whole chat record: flags, client data, theme and accent ids.
- (void)chatRecordForChat:(int64_t)chatId
			   completion:(void (^)(NSDictionary *chat))completion;

/// The raw supergroup full info, for the fields the chat row does not carry
/// (slow mode, linked chat, location permission).
- (void)groupFullInfoForChat:(int64_t)chatId
				  completion:(void (^)(NSDictionary *info))completion;

/// Moves a chat into one chat list, or adds it without removing it elsewhere.
- (void)addChat:(int64_t)chatId toList:(NSDictionary *)list
	 completion:(void (^)(BOOL ok))completion;

/// The user who becomes owner after this account leaves for good.
- (void)ownerAfterLeavingChat:(int64_t)chatId
				   completion:(void (^)(NSDictionary *user))completion;

- (void)chatStatisticsForChat:(int64_t)chatId
				   completion:(void (^)(NSArray *rows, NSString *kind))completion;

/// Service actions in a supergroup or channel, newest first. Each entry is
/// "date", "actor" and "text".
/// The largest chat-photo file id, which is what reportChatPhoto accepts.
- (void)reportChatPhotoInChat:(int64_t)chatId
					   reason:(NSString *)reason
					   detail:(NSString *)detail
				   completion:(void (^)(BOOL ok))completion;

/// Emoji chat photos come from this set; entries carry "emoji", "name" and
/// "customEmojiId".
- (void)defaultChatPhotoEmojiStickersWithCompletion:
		(void (^)(NSArray *stickers))completion;

/// Sets a chat photo built from a custom emoji and a solid background.
- (void)setEmojiPhotoForChat:(int64_t)chatId
				customEmojiId:(int64_t)customEmojiId
					   colour:(NSInteger)colour
				   completion:(void (^)(BOOL ok))completion;

- (void)setChatAccentColour:(int64_t)chatId colourId:(NSInteger)colourId;
- (void)setChatProfileAccentColour:(int64_t)chatId colourId:(NSInteger)colourId;

/// `name` is a chatThemeEmoji name; empty resets to the default theme.
- (void)setChatTheme:(int64_t)chatId name:(NSString *)name
		  completion:(void (^)(BOOL ok))completion;

/// `imagePath` is a JPEG written by the screen; empty resets nothing and is
/// refused. `colour` is the RGB integer TDLib fills the bubble background
/// with.
- (void)setChatBackground:(int64_t)chatId
				imagePath:(NSString *)imagePath
				   colour:(NSInteger)colour
			  onlyForSelf:(BOOL)onlyForSelf
			   completion:(void (^)(BOOL ok))completion;

- (void)deleteChatBackground:(int64_t)chatId restorePrevious:(BOOL)restore;

/// "all", "none" or "some"; some leaves the default emoji set active.
- (void)setAvailableReactionsForChat:(int64_t)chatId
								mode:(NSString *)mode
						  completion:(void (^)(BOOL ok))completion;

- (void)setSlowModeDelayForChat:(int64_t)chatId
						seconds:(NSInteger)seconds
					 completion:(void (^)(BOOL ok))completion;

- (void)toggleTranslatableForChat:(int64_t)chatId on:(BOOL)on;
- (void)toggleProtectedContentForChat:(int64_t)chatId
								   on:(BOOL)on
						   completion:(void (^)(BOOL ok))completion;
- (void)toggleDefaultSilentForChat:(int64_t)chatId on:(BOOL)on;

/// Application-specific data: this app keeps a short local note in it.
- (void)setClientNote:(NSString *)note forChat:(int64_t)chatId
		   completion:(void (^)(BOOL ok))completion;

- (void)setDiscussionGroup:(int64_t)discussionChatId
				   forChat:(int64_t)chatId
				completion:(void (^)(BOOL ok))completion;

- (void)setLocationAddress:(NSString *)address
				   forChat:(int64_t)chatId
				completion:(void (^)(BOOL ok))completion;

/// Approves or rejects a pending request to turn protected content off.
#pragma mark - chat positions

/// Sparse positions for a media tab: entries are "position", "messageId"
/// and "date", newest first.
- (void)sparsePositionsInChat:(int64_t)chatId
					   filter:(NSString *)filter
				   fromMessage:(int64_t)messageId
					completion:(void (^)(NSInteger total, NSArray *positions))completion;

/// The 1-based position of one message among the same filter's matches.
#pragma mark - sessions

#pragma mark - compatibility resolvers

/// TDLib's older spellings of "open the chat for this internal id". The app
/// addresses chats by chat id, so these exist for the admin tool that has to
/// turn a basic-group, supergroup or secret-chat id back into a chat.
@end
