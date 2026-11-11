#import "TGClient+Base.h"

@interface TGClient (InlineMessages)

/// Pin a message to the top of the chat, or take it down again. `notify`
/// posts the "pinned a message" service message the way their clients do.
/// Every pinned message down at once; `threadId` limits it to a forum topic.
/// The last message on or before `date` (unix seconds), or nil.
- (void)messageAtDate:(NSTimeInterval)date inChat:(int64_t)chatId
		   completion:(void (^)(NSDictionary *message))completion;

/// Bot-side edits of a message sent through an inline bot. The id is the
/// bot's own inline message id; every call passes null markup, leaving the
/// buttons as they were unless the buttons are the thing being changed.
- (void)editInlineMessageText:(NSString *)inlineMessageId
						 text:(NSString *)text
				   completion:(void (^)(BOOL ok))completion;

- (void)editInlineMessageCaption:(NSString *)inlineMessageId
						 caption:(NSString *)caption
					  completion:(void (^)(BOOL ok))completion;

- (void)clearInlineMessageReplyMarkup:(NSString *)inlineMessageId
						   completion:(void (^)(BOOL ok))completion;

- (void)editInlineMessagePhoto:(NSString *)inlineMessageId
					   photoId:(int64_t)photoId
					   caption:(NSString *)caption
					completion:(void (^)(BOOL ok))completion;

- (void)editInlineMessageLiveLocation:(NSString *)inlineMessageId
							 latitude:(double)latitude
							longitude:(double)longitude
						   completion:(void (^)(BOOL ok))completion;

/// What Telegram makes of a link: "url", "site", "title", "description",
/// "photoId" and "instantView". nil when the link has no preview, which is
/// most links.
- (void)linkPreviewForText:(NSString *)text
				completion:(void (^)(NSDictionary *preview))completion;

/// What a t.me or tg:// link points at, decided by Telegram rather than by
/// pattern-matching the path. The kind is one word - "publicChat",
/// "message", "stickerSet", "inviteLink", "phoneNumber" or "unknown" - with
/// the piece of it worth acting on.
- (void)internalLinkKind:(NSString *)link
			  completion:(void (^)(NSString *kind, NSString *value))completion;

/// A received formatted message handed back as the markdown its sender
/// typed: *bold*, `_italic_`, `code` - so Edit edits the origin, not the
/// render. A message with no markup comes back as its plain text.
- (void)markdownOfMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
				completion:(void (^)(NSString *markdown))completion;

/// Telegram's own static map of a place, as a PNG, answered as a local path
/// once it is down - or nil, which on this device is ordinary. The drawn card
/// is what a caller falls back to.
- (void)mapThumbnailForLatitude:(double)latitude
					  longitude:(double)longitude
						  width:(NSInteger)width
						 height:(NSInteger)height
						 inChat:(int64_t)chatId
					 completion:(void (^)(NSString *path))completion;

/// Reports messages in a supergroup as spam. Reads the chat first: the
/// request wants the supergroup's own id, which a chat id is not.
- (void)reportSpamMessages:(NSArray *)messageIds
				    inChat:(int64_t)chatId
				completion:(void (^)(BOOL ok))completion;

/// Blocks whoever sent a message from replying again, optionally deleting
/// what they wrote and reporting it.
/// Closes a poll you sent; nobody can vote after that.
/// Who voted for one answer. `optionIndex` is the 0-based one; entries
/// carry "id", "name", "date".
- (void)pollVotersOfOption:(NSInteger)optionIndex
                ofMessage:(int64_t)messageId
                     inChat:(int64_t)chatId
                completion:(void (^)(NSArray *voters, BOOL end))completion;

/// The poll's vote statistics as one graph: the entries carry "json" (the
/// chart data as a JSON string) and "zoom". nil when the answer is an
/// error, which is how a poll without statistics everywhere says so.
- (void)pollVoteStatisticsOfMessage:(int64_t)messageId
							 inChat:(int64_t)chatId
						 completion:(void (^)(NSDictionary *graph))completion;

/// An option added after the poll went out, for polls that allow it.
/// An option taken out again; `optionId` is the string id pollOption
/// carries, not an index.
/// What one answer still allows: "canBeDeleted", "canBeReplied",
/// "canBeRepliedInAnotherChat" and "canGetLink". `optionId` is pollOption's
/// string id. Nil with `error` when the poll has no such option or Telegram
/// refuses the read, which is what the answer card shows.
- (void)pollOptionProperties:(NSString *)optionId
				   ofMessage:(int64_t)messageId
					  inChat:(int64_t)chatId
				  completion:(void (^)(NSDictionary *properties,
									   NSString *error))completion;

/// Every poll in the chat read up on, so the fresh-vote badge is gone.
- (void)readAllChatPollVotes:(int64_t)chatId;

/// Reports a reaction the flattening named - `sender` is the MessageSender
/// dict it carried, and TDLib files the report against whoever added it.
/// React to a message with an emoji, as the current user.
/// Takes your own reaction back off. Nothing happens if it was not there.
/// it expires a few seconds after the last one. Cancel sends the stop.
/// Marks a voice note, a video note or a one-time picture as opened, so the
/// sender's ticks say it was played.
/// Sends failed messages again, by the ids they kept while failing.
/// The message a reply points at, fetched from the server - the history on
/// screen may not reach back far enough to hold it. nil when it is gone.
/// Returns messages by their ids in a chat. Missing messages are returned as NSNull.
/// Returns properties of a message (e.g. can_be_replied, can_get_message_thread).
/// A t.me link to one message, or nil for a chat that has no public link.
- (void)linkToMessage:(int64_t)messageId
			   inChat:(int64_t)chatId
		   completion:(void (^)(NSString *link))completion;

@end
