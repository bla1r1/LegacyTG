#import <CoreGraphics/CoreGraphics.h>
#import "TGClient+Base.h"

@interface TGClient (Messages)

- (NSString *)titleForChat:(int64_t)chatId;

/// Newest `limit` messages of a chat, oldest first. Each entry has "id",
/// "text", "date", "outgoing" (NSNumber BOOL), "senderId", "photoId"
/// (NSNumber file id or nil).
- (void)historyForChat:(int64_t)chatId
         fromMessageId:(int64_t)fromMessageId
                offset:(NSInteger)offset
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *messages))completion;

/// A page with the message itself in the middle, for jumping to it.
/// History of one forum topic. `threadId` is the topic's message_thread_id.
- (void)sendText:(NSString *)text toChat:(int64_t)chatId;

/// Markdown in `formattedText`'s text parsed by parseMarkdown, which keeps
/// the entities already there (custom emoji) and moves their offsets.
/// Synchronous; returns the input when TDLib refuses it.
- (NSDictionary *)markdownParsed:(NSDictionary *)formattedText;

/// A message's text as the composer edits it: markup back in the text
/// (getMarkdownText), custom emoji kept as entities. Synchronous.
- (NSDictionary *)markdownForEditing:(NSDictionary *)formattedText;

/// sendMessage with inputMessageText carrying this formattedText as is.
- (void)sendFormattedText:(NSDictionary *)formattedText toChat:(int64_t)chatId
				   thread:(int64_t)threadId replyTo:(int64_t)replyToId;

/// The same send, with TDLib's pending message handed back. The store uses it
/// to remember the temporary id that updateMessageSendSucceeded later renames.
- (void)sendFormattedText:(NSDictionary *)formattedText toChat:(int64_t)chatId
				   thread:(int64_t)threadId replyTo:(int64_t)replyToId
		  schedulingState:(NSDictionary *)schedulingState
			   completion:(void (^)(NSDictionary *message))completion;
- (void)sendFormattedText:(NSDictionary *)formattedText toChat:(int64_t)chatId
				   thread:(int64_t)threadId replyTo:(int64_t)replyToId
		  schedulingState:(NSDictionary *)schedulingState
				  options:(NSDictionary *)options
			   completion:(void (^)(NSDictionary *message))completion;

/// editMessageText with this formattedText as is.
- (void)editMessage:(int64_t)messageId inChat:(int64_t)chatId formattedText:(NSDictionary *)formattedText;

/// Send into a forum topic.
- (void)sendText:(NSString *)text toChat:(int64_t)chatId thread:(int64_t)threadId;

/// Send as a reply to a message.
- (void)sendText:(NSString *)text toChat:(int64_t)chatId
          thread:(int64_t)threadId replyTo:(int64_t)replyToId;

/// The two scheduling states a send can carry; nil fields are refused by
/// TDLib, so the request without one is the send-now call in the header.
+ (NSDictionary *)scheduledAtDate:(NSTimeInterval)date;

+ (NSDictionary *)scheduledAtDate:(NSTimeInterval)date repeatPeriod:(NSInteger)seconds;

+ (NSDictionary *)scheduledWhenOnline;

/// A complete messageSendOptions record: every field TDLib asks for, with
/// the scheduling state where the schema expects it. `schedulingState` may
/// be nil, which sends now; `silent` turns off notifications.
+ (NSDictionary *)messageSendOptionsSilent:(BOOL)silent
						   schedulingState:(NSDictionary *)schedulingState;

/// The reply send with one of those states attached.
- (void)sendText:(NSString *)text toChat:(int64_t)chatId
          thread:(int64_t)threadId replyTo:(int64_t)replyToId
        scheduled:(NSDictionary *)schedulingState;

/// The same held-back send, answering with TDLib's pending message.
- (void)sendText:(NSString *)text toChat:(int64_t)chatId
          thread:(int64_t)threadId replyTo:(int64_t)replyToId
        scheduled:(NSDictionary *)schedulingState
      completion:(void (^)(NSDictionary *message))completion;
- (void)sendText:(NSString *)text toChat:(int64_t)chatId
          thread:(int64_t)threadId replyTo:(int64_t)replyToId
        scheduled:(NSDictionary *)schedulingState
          options:(NSDictionary *)options
      completion:(void (^)(NSDictionary *message))completion;

/// What a chat has waiting. Flattened like the history is.
- (void)scheduledMessagesInChat:(int64_t)chatId
                     completion:(void (^)(NSArray *messages))completion;

/// Move a scheduled message: nil for `state` sends it now, which is TDLib's
/// meaning of an absent scheduling state.
/// Forward messages into another chat.
/// Replace the text of a message already sent.
- (void)editMessage:(int64_t)messageId inChat:(int64_t)chatId text:(NSString *)text;

/// The caption under a picture, a video or a file - a different request from
/// editing text, which is why only text could be edited before.
/// Replaces the picture itself, keeping the message where it is. The caption
/// travels with it, because the request takes the whole content.
/// Up to ten pictures as one message rather than as a run of separate ones.
/// Only the first carries the caption; TDLib refuses an album where more
/// than one does.
/// One message by id, flattened. Used to show what a reply is answering.
- (void)messageWithId:(int64_t)messageId
               inChat:(int64_t)chatId
           completion:(void (^)(NSDictionary *message))completion;

/// Stickers the user reached for lately: "fileId", "emoji", "isAnimated".
- (void)recentStickersWithCompletion:(void (^)(NSArray *stickers))completion;

/// Send a sticker TDLib already knows, by file id.
/// Send a recorded voice note (.oga), with its duration in seconds.
/// A voice note for one viewing: `viewOnce` asks Telegram to keep it only
/// until the other side opened it, the same one-time mode the "1" button on
/// their recorder sets (a self destruct that fires immediately on open).
/// A voice note with its upload reported. There is no transcode, so
/// `progress` is the whole line. `accepted` gets the pending message id as
/// soon as sendMessage answers, before the waiter is usable.
/// A square video note recorded on this device.
/// The same send with the note's life reported: `progress` runs on the main
/// queue with the upload's share, 0..1, and `completion` once TDLib has
/// confirmed the message (YES) or refused it (NO). Both may be nil.
/// The full note send. `thumbnailPath` is the first-frame JPEG the recorder
/// made, or nil; `accepted` receives the pending id before the waiter exists.
/// Cancels a pending send the way their clients do: delete it and revoke it.
/// The waiter is answered as a success, because the person asked for it.
/// Send a video file from the library.
/// The same video as a view-once message: it opens once and is gone.
/// Share a point on the map.
/// A place that keeps changing, for `seconds` more. The send is answered
/// with the message itself - its id is what every later edit answers
/// through.
/// The moving pin, moved again, for `seconds` more of its period. 0 stops
/// it. nil id is refused, because a pin nobody can move is a lie on the map.
/// Share someone from the address book.
/// Send a local image file. TDLib uploads it and echoes the message back.
/// The same picture as a view-once message: it opens once and is gone.
/// Vote in a poll. `optionIds` are indexes into the poll's options.
/// Tick or untick one task of a checklist. TDLib carries the two directions
/// in two vectors, so one of them is always empty.
/// Search messages across every chat. Each result is a flattened message with
/// an extra "chatId" and "chatTitle" so it can be shown out of context.
- (void)searchMessages:(NSString *)query completion:(void (^)(NSArray *messages))completion;

/// Search inside one chat, newest first. Flattened messages.
- (void)searchInChat:(int64_t)chatId query:(NSString *)query
          completion:(void (^)(NSArray *messages))completion;

/// Bot buttons. See TGFlattenReplyMarkup for the button dictionaries.
- (void)pressCallbackButton:(NSDictionary *)button
					 inChat:(int64_t)chatId
				  messageId:(int64_t)messageId
				 completion:(void (^)(NSString *text, BOOL alert, NSString *url,
									  NSString *error))completion;

- (void)loginURLForButton:(NSDictionary *)button
				   inChat:(int64_t)chatId
				messageId:(int64_t)messageId
			   completion:(void (^)(NSString *url, NSString *confirmDomain,
									NSString *error))completion;

- (void)confirmLoginButton:(NSDictionary *)button
					inChat:(int64_t)chatId
				 messageId:(int64_t)messageId
				completion:(void (^)(NSString *url, NSString *error))completion;

/// The reply keyboard a bot left on the chat, or nil.
- (void)replyKeyboardForChat:(int64_t)chatId completion:(void (^)(NSDictionary *keyboard))completion;

/// A channel post's comments: its discussion group and the thread in it.
- (void)commentThreadForChat:(int64_t)chatId
				   messageId:(int64_t)messageId
				  completion:(void (^)(int64_t discussionChatId, int64_t threadId,
									   NSString *error))completion;

@end
