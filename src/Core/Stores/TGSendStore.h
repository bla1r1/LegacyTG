//
// TGSendStore.h - the outbound side of a chat: send, edit, delete, retry.
//
// A screen asks this store; the store owns the request shapes and one state
// table for messages that are on their way, sent, or refused by Telegram.
// The header is plain Objective-C on purpose: no C++ reaches a view.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

/// Where a tracked message stands. TGSendStateUnknown is a message the store
/// has never seen; a screen draws that one from the history's own fields.
typedef NS_ENUM(NSInteger, TGSendState) {
	TGSendStateUnknown = 0,
	TGSendStateSending,
	TGSendStateSent,
	TGSendStateFailed,
};

/// Posted on the main queue when a tracked message changes state, or when a
/// failed one is retried. userInfo carries the keys below.
extern NSString *const TGSendStoreMessageStateChangedNotification;

/// NSNumber int64: the chat the message belongs to.
extern NSString *const TGSendStoreChatIdKey;
/// NSNumber int64: the message's current id.
extern NSString *const TGSendStoreMessageIdKey;
/// NSNumber int64: the id it had before updateMessageSendSucceeded renamed it,
/// or 0. Absent apart from that transition.
extern NSString *const TGSendStoreOldMessageIdKey;
/// NSNumber TGSendState.
extern NSString *const TGSendStoreStateKey;
/// NSString: why Telegram refused the message, empty when it did not.
extern NSString *const TGSendStoreErrorKey;
/// NSNumber BOOL: whether resending the message is worth trying.
extern NSString *const TGSendStoreCanRetryKey;

@interface TGSendStore : NSObject

+ (instancetype)shared;

#pragma mark - outbound requests

/// sendMessage carrying `formattedText` as is. `schedulingState` is one of
/// TGClient's two scheduling records, or nil to send now.
- (void)sendFormattedText:(NSDictionary *)formattedText
				   toChat:(int64_t)chatId
				   thread:(int64_t)threadId
				  replyTo:(int64_t)replyToId
		  schedulingState:(NSDictionary *)schedulingState;

/// The plain-text send the composer's held Send uses. Markdown is parsed by
/// the client as before; the store only tracks what comes back.
- (void)sendText:(NSString *)text
		  toChat:(int64_t)chatId
		  thread:(int64_t)threadId
		 replyTo:(int64_t)replyToId
 schedulingState:(NSDictionary *)schedulingState;

/// editMessageText with a formattedText record.
- (void)editMessageText:(int64_t)messageId
				 inChat:(int64_t)chatId
		  formattedText:(NSDictionary *)formattedText;

/// deleteMessages. `revoke` is delete-for-everyone; NO keeps it for this
/// account only. The store forgets the ids either way.
- (void)deleteMessages:(NSArray *)messageIds
				inChat:(int64_t)chatId
				revoke:(BOOL)revoke;

/// resendMessages, one request for the whole list.
- (void)resendMessages:(NSArray *)messageIds inChat:(int64_t)chatId;

/// One failed message again. This is what a tap on the failed bubble and the
/// hold menu's Retry row both call.
- (void)retryMessageId:(int64_t)messageId inChat:(int64_t)chatId;

#pragma mark - media and other outbound content

- (void)sendAnimation:(NSDictionary *)animation toChat:(int64_t)chatId thread:(int64_t)threadId;

- (void)sendChecklist:(NSString *)title tasks:(NSArray *)tasks
			   toChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)sendContactNamed:(NSString *)name phone:(NSString *)phone toChat:(int64_t)chatId;

- (void)sendEphemeralText:(NSString *)text toChat:(int64_t)chatId
			 receiverUserId:(int64_t)receiverUserId
			ephemeralReplyId:(NSInteger)ephemeralReplyId
				 completion:(void (^)(NSDictionary *message, NSString *error))completion;

- (void)sendLiveLocation:(NSInteger)seconds latitude:(double)latitude
			   longitude:(double)longitude toChat:(int64_t)chatId
			  completion:(void (^)(int64_t messageId))completion;

- (void)sendLocation:(double)latitude longitude:(double)longitude toChat:(int64_t)chatId;

- (void)sendPhotoAlbumAtPaths:(NSArray *)paths caption:(NSString *)caption
					   toChat:(int64_t)chatId thread:(int64_t)threadId;

- (void)sendPhotoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce toChat:(int64_t)chatId;

- (void)sendQuickReplyShortcutMessages:(NSInteger)shortcutId toChat:(int64_t)chatId
							 sendingId:(int32_t)sendingId
							completion:(void (^)(NSArray *messages, NSString *error))completion;

- (void)sendRichMessageDraft:(NSString *)text toChat:(int64_t)chatId
					 topicId:(int32_t)topicId draftId:(int64_t)draftId
					 canStop:(BOOL)canStop keepOnStop:(BOOL)keepOnStop
				  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)sendStickerWithFileId:(NSInteger)fileId toChat:(int64_t)chatId thread:(int64_t)threadId;

/// The bot keyboard's text send; the composer's own send is above.
- (void)sendText:(NSString *)text toChat:(int64_t)chatId thread:(int64_t)threadId;

- (void)sendVideoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce toChat:(int64_t)chatId;

- (void)sendVideoNoteAtPath:(NSString *)path duration:(NSInteger)seconds
					 length:(NSInteger)length toChat:(int64_t)chatId thread:(int64_t)threadId
				   viewOnce:(BOOL)viewOnce thumbnail:(NSString *)thumbnailPath
				   progress:(void (^)(CGFloat progress))progress
				   accepted:(void (^)(int64_t messageId))accepted
				 completion:(void (^)(BOOL sent))completion;

- (void)sendVoiceAtPath:(NSString *)path duration:(NSInteger)seconds
				 toChat:(int64_t)chatId thread:(int64_t)threadId viewOnce:(BOOL)viewOnce
			   progress:(void (^)(CGFloat progress))progress
			   accepted:(void (^)(int64_t messageId))accepted
			 completion:(void (^)(BOOL sent))completion;

/// Upload fraction of a voice or round note still going out.
- (CGFloat)sendProgressForMessage:(int64_t)messageId;

/// Takes back a message that is still uploading.
- (void)cancelSendingMessage:(int64_t)messageId inChat:(int64_t)chatId;

/// Moves a scheduled message: nil `state` sends it now.
- (void)setSchedulingState:(NSDictionary *)state forMessage:(int64_t)messageId
					inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;

#pragma mark - state

/// The state the store knows. TGSendStateUnknown when it has never seen it.
- (TGSendState)stateForMessageId:(int64_t)messageId inChat:(int64_t)chatId;

/// Telegram's reason for the refusal, or an empty string.
- (NSString *)failureReasonForMessageId:(int64_t)messageId inChat:(int64_t)chatId;

/// Whether TDLib said the failed message may be sent again.
- (BOOL)canRetryMessageId:(int64_t)messageId inChat:(int64_t)chatId;

/// Seed the table from a history page: a chat reopened after a failed send
/// still draws the failure, and tapping it retries. Never overwrites a state
/// the live updates already moved forward.
- (void)adoptMessages:(NSArray *)messages inChat:(int64_t)chatId;

/// Drop every record. Account switches and the host tests start clean.
- (void)reset;

@end
