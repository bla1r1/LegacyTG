//
// TGClient+MessageMeta.h - the client surface for facts around one message: viewers, forwards, reactions, translate.
//
#import "TGClient+Base.h"

@interface TGClient (MessageMeta)

/// The reaction Telegram names as the default. nil until
/// updateDefaultReactionType has arrived; the picker keeps its own order then.
@property (nonatomic, readonly) NSString *defaultReactionEmoji;

/// The chat and the exact message a "message"-kind link resolves to: a
/// t.me/name/12345 landed on. The chat id is 0 when Telegram refused.
/// Every cache's draft dropped at once, on every device.
/// The lifetime new chats carry when nobody chose one. Zero is off.
/// A nil date with the reason word is the honest sheet line.
/// The reactions this message offers, top row first. nil when the message
/// cannot be reacted to or has no explicit top list.
- (void)addedReactionsOfMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
						  emoji:(NSString *)emoji
						 offset:(NSString *)offset
					 completion:(void (^)(NSArray *rows, NSString *next))completion;

/// The same list for a reaction type that is not an emoji, chiefly a custom
/// emoji by id. `reactionType` is the TDLib ReactionType object.
- (void)addedReactionsOfMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
				   reactionType:(NSDictionary *)reactionType
						 offset:(NSString *)offset
					 completion:(void (^)(NSArray *rows, NSString *next))completion;

/// How many messages a chat carries under one SearchMessagesFilter, which is
/// the number a profile tab shows in its subtitle. `filterType` is a TDLib
/// filter name ("searchMessagesFilterPhotoAndVideo", ...); nil means the
/// whole chat.
- (void)messageCountInChat:(int64_t)chatId
					filter:(NSString *)filterType
				completion:(void (^)(NSInteger count))completion;

- (void)calendarJumpForChat:(int64_t)chatId
					 endDate:(NSInteger)end
				  completion:(void (^)(int64_t messageId, NSInteger total))completion;

- (void)publicMessagesByTag:(NSString *)tag
					 offset:(NSString *)offset
				completion:(void (^)(NSArray *messages, NSString *next))completion;

/// The description of a message effect by id: "emoji", "premium" and the
/// effect's kind. nil when Telegram has no such effect.
/// What kind of export file a message file is, read from its first lines, so
/// the import sheet can name it before importing. nil for an unknown file.
/// The sentence Telegram wants shown before it starts importing into a chat.
/// Imports an exported history file into a chat. `path` is a local file;
/// `attachedPaths` are the media files the export refers to.
/// An inline message a bot prepared for this user, ready to be sent.
/// Saves an inline result for another user to send; bots own the request, so
/// a user account gets nil back with the server's refusal.
/// A bot's streaming draft for a chat. `draftId` names the stream so stop
/// knows which one to stop; `canStop` shows the user a stop button.
/// Stops the draft stream `draftId` in a chat.
@end
