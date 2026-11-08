#import "TGClient+Base.h"

@interface TGClient (OwnedBots)

/// YES when the cached user record says this account is a bot. The profile
/// uses it to decide whether the Bot Settings row can do anything.
- (BOOL)userIsBot:(int64_t)userId;

/// Every bot owned by this account, as "id", "name" and "username".
- (void)ownedBotsWithCompletion:(void (^)(NSArray *bots,
										  NSString *error))completion;

/// Whether a username is free for a new bot or as a secondary name. The
/// answer is a word: "ok", "invalid", "occupied", "purchasable",
/// "tooLong", "tooShort" or "unsupported".
- (void)checkBotUsername:(NSString *)username
			  isSecondary:(BOOL)isSecondary
			   completion:(void (^)(NSString *result,
									NSString *error))completion;

- (void)botNameForBot:(int64_t)botUserId
			 language:(NSString *)language
		   completion:(void (^)(NSString *name, NSString *error))completion;

- (void)setBotName:(NSString *)name
			forBot:(int64_t)botUserId
		  language:(NSString *)language
		completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)botDescriptionForBot:(int64_t)botUserId
					language:(NSString *)language
				  completion:(void (^)(NSString *text,
									   NSString *error))completion;

- (void)setBotDescription:(NSString *)text
				   forBot:(int64_t)botUserId
				 language:(NSString *)language
			   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)botShortDescriptionForBot:(int64_t)botUserId
						 language:(NSString *)language
					   completion:(void (^)(NSString *text,
											NSString *error))completion;

- (void)setBotShortDescription:(NSString *)text
						forBot:(int64_t)botUserId
					  language:(NSString *)language
					completion:(void (^)(BOOL ok, NSString *error))completion;

/// Removes an owned bot's photo. A replacement needs an uploaded photo, which
/// is the same static-photo path the profile screen already owns; this call
/// is the null half of setBotProfilePhoto.
- (void)removeBotProfilePhoto:(int64_t)botUserId
				   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)addBotSecondaryUsername:(NSString *)username
						 forBot:(int64_t)botUserId
					 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)deleteBotSecondaryUsernameForBot:(int64_t)botUserId
							  completion:(void (^)(BOOL ok,
												   NSString *error))completion;

- (void)setBotUsername:(NSString *)username
				active:(BOOL)active
				forBot:(int64_t)botUserId
			completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)reorderBotActiveUsernames:(NSArray *)usernames
						   forBot:(int64_t)botUserId
					   completion:(void (^)(BOOL ok, NSString *error))completion;

/// The owned bot's media previews, as "fileId", "date" and "contentType".
- (void)botMediaPreviewsForBot:(int64_t)botUserId
					completion:(void (^)(NSArray *previews,
										 NSString *error))completion;

/// Previews for one language plus the languages the bot has for them.
- (void)botMediaPreviewInfoForBot:(int64_t)botUserId
						 language:(NSString *)language
					   completion:(void (^)(NSDictionary *info,
											NSString *error))completion;

/// Adds a preview from a file already known to TDLib. `video` chooses the
/// video content shape; the duration and cover frame default to a still
/// preview's values when it is NO.
- (void)addBotMediaPreviewForBot:(int64_t)botUserId
						language:(NSString *)language
						  fileId:(int32_t)fileId
						   video:(BOOL)video
					  completion:(void (^)(NSDictionary *preview,
										   NSString *error))completion;

- (void)editBotMediaPreviewForBot:(int64_t)botUserId
						 language:(NSString *)language
						   fileId:(int32_t)fileId
					   newFileId:(int32_t)newFileId
							video:(BOOL)video
					   completion:(void (^)(NSDictionary *preview,
											NSString *error))completion;

- (void)deleteBotMediaPreviewsForBot:(int64_t)botUserId
							language:(NSString *)language
							 fileIds:(NSArray *)fileIds
						  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)reorderBotMediaPreviewsForBot:(int64_t)botUserId
							 language:(NSString *)language
							  fileIds:(NSArray *)fileIds
						   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)similarBotCountForBot:(int64_t)botUserId
						local:(BOOL)localOnly
				   completion:(void (^)(int32_t count, NSString *error))completion;

- (void)similarBotsForBot:(int64_t)botUserId
			   completion:(void (^)(NSArray *bots, NSString *error))completion;

- (void)openSimilarBot:(int64_t)openedBotId
			   fromBot:(int64_t)botUserId
			completion:(void (^)(BOOL ok, NSString *error))completion;

/// Whether an owned bot may change this account's emoji status.
- (void)setBotCanManageEmojiStatus:(BOOL)allowed
							forBot:(int64_t)botUserId
						completion:(void (^)(BOOL ok, NSString *error))completion;

/// An owned bot's verification mark on a user or chat. `kind` is "user" or
/// "chat"; an empty description uses Telegram's default wording.
- (void)setBotVerification:(int64_t)botUserId
			 verifiedKind:(NSString *)kind
				 verifiedId:(int64_t)verifiedId
				description:(NSString *)description
				 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)removeBotVerification:(int64_t)botUserId
				 verifiedKind:(NSString *)kind
					 verifiedId:(int64_t)verifiedId
				   completion:(void (^)(BOOL ok, NSString *error))completion;

/// Creates a bot managed by `managerBotId`. Returns the new user row.
- (void)createBotNamed:(NSString *)name
			  username:(NSString *)username
			  manager:(int64_t)managerBotId
			completion:(void (^)(NSDictionary *bot, NSString *error))completion;

/// The user's recently used inline bots.
- (void)recentInlineBotsWithCompletion:(void (^)(NSArray *bots,
												NSString *error))completion;

/// Starts a bot in a chat with the deep-link parameter. Returns the sent
/// message record's id and text, or Telegram's refusal.
- (void)startBot:(int64_t)botUserId
		  inChat:(int64_t)chatId
	   parameter:(NSString *)parameter
	  completion:(void (^)(NSDictionary *message,
						   NSString *error))completion;

/// Whether a bot can be put on the attachment menu and whether it already is.
- (void)attachmentMenuBot:(int64_t)botUserId
			   completion:(void (^)(NSDictionary *bot,
									NSString *error))completion;

- (void)setBotOnAttachmentMenu:(int64_t)botUserId
					   added:(BOOL)added
			 allowWriteAccess:(BOOL)allowWriteAccess
					completion:(void (^)(BOOL ok, NSString *error))completion;

/// Whether a bot is allowed to message this account. A 404 means it may ask;
/// the error text is Telegram's.
- (void)canBotSendMessages:(int64_t)botUserId
				completion:(void (^)(BOOL can, NSString *error))completion;

- (void)allowBotToSendMessages:(int64_t)botUserId
					completion:(void (^)(BOOL ok, NSString *error))completion;

/// Adds one inline result to a saved reply shortcut, for the inline flow the
/// composer already knows how to run.
- (void)addInlineResultToQuickReply:(NSString *)shortcutName
						 replyToId:(int64_t)replyToMessageId
						   queryId:(int64_t)queryId
						  resultId:(NSString *)resultId
						 hideViaBot:(BOOL)hideViaBot
						completion:(void (^)(NSDictionary *message,
											 NSString *error))completion;

@end
