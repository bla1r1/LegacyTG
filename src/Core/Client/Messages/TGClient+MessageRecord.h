#import "TGClient+Base.h"

@interface TGClient (MessageRecord)

/// Adds a note to the chat without sending it to anyone: TDLib stores it in
/// the history like any other message. The completion gets its id, or 0.
/// A tap on a message with an animated emoji (a dice, a ball). TDLib answers
/// with the sticker to play, whose emoji is what the sheet shows; nil when
/// the ordinary animation is the answer.
/// Replaces a message's buttons. An empty keyboard removes them; the rest of
/// the message stays. Bot accounts own this request, so a user account gets
/// the server's refusal back as NO.
/// The message a callback query belongs to. Bots receive the query, so a
/// user account can only read back one it already owns.
- (void)callbackQueryMessage:(int64_t)messageId
					  inChat:(int64_t)chatId
			 callbackQueryId:(int64_t)callbackQueryId
				  completion:(void (^)(NSDictionary *message))completion;

/// The message as it sits in the local database, without asking the server.
/// nil when it is not cached.
- (void)localMessageWithId:(int64_t)messageId
					inChat:(int64_t)chatId
				completion:(void (^)(NSDictionary *message))completion;

/// The message's 1-based place among the chat's messages, or 0 when unknown.
/// `threadId` is a forum topic or a Saved Messages topic; 0 is the whole chat.
- (void)positionOfMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
				   thread:(int64_t)threadId
			   completion:(void (^)(NSInteger position))completion;

/// Sparse message positions used by a shared-media scroll: message ids in
/// reverse chronological order, at most `limit` of them. `threadId` is a
/// Saved Messages topic; 0 covers the chat. TDLib has no forum-topic filter
/// for this call, so a forum's map is the chat's.
- (void)sparsePositionsInChat:(int64_t)chatId
				fromMessageId:(int64_t)fromMessageId
					   thread:(int64_t)threadId
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *messageIds))completion;

/// The channel post's interaction and reaction graphs. nil when the message
/// is not a post whose statistics this account may read.
/// Tells TDLib how long a message stayed on screen, which is what a channel
/// post's view count is made of.
/// Sets the reactions on a message by name. Bot accounts own this request;
/// a user gets the refusal back as NO.
- (void)setReactions:(NSArray *)emojis
		   onMessage:(int64_t)messageId
			  inChat:(int64_t)chatId
		  completion:(void (^)(BOOL ok))completion;

/// The messages in a user's personal chat, newest first. Bots own the
/// request, so a user account gets an empty list back.
- (void)personalChatHistoryForUser:(int64_t)userId
							 limit:(NSInteger)limit
						completion:(void (^)(NSArray *messages))completion;

@end
