//
// TGSendStore.h - outbound messages and their send state.
//
// Rebuilt from TGSendStore.mm after an accidental overwrite. The public
// surface is the same: send requests, retry, delete, scheduling, and the
// per-message state table that the failed-send mark reads.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "TGClientTypes.h"

/// The four states a tracked message can be in. `failed` carries a reason
/// and a retry flag through the notification's userInfo.
typedef NS_ENUM(NSInteger, TGSendState) {
	TGSendStateUnknown = 0,
	TGSendStateSending,
	TGSendStateSent,
	TGSendStateFailed,
};

extern NSString *const TGSendStoreMessageStateChangedNotification;
extern NSString *const TGSendStoreChatIdKey;
extern NSString *const TGSendStoreMessageIdKey;
extern NSString *const TGSendStoreOldMessageIdKey;
extern NSString *const TGSendStoreStateKey;
extern NSString *const TGSendStoreErrorKey;
extern NSString *const TGSendStoreCanRetryKey;

@interface TGSendStore : NSObject

+ (instancetype)shared;

+ (instancetype)shared;
- (instancetype)init;
- (void)sendFormattedText:(NSDictionary *)formattedText
				   toChat:(int64_t)chatId
				   thread:(int64_t)threadId
				  replyTo:(int64_t)replyToId
		  schedulingState:(NSDictionary *)schedulingState;
- (void)sendFormattedText:(NSDictionary *)formattedText
				   toChat:(int64_t)chatId
				   thread:(int64_t)threadId
				  replyTo:(int64_t)replyToId
		  schedulingState:(NSDictionary *)schedulingState
				   silent:(BOOL)silent;
- (void)sendText:(NSString *)text
		  toChat:(int64_t)chatId
		  thread:(int64_t)threadId
		 replyTo:(int64_t)replyToId
 schedulingState:(NSDictionary *)schedulingState;
- (void)sendText:(NSString *)text
		  toChat:(int64_t)chatId
		  thread:(int64_t)threadId
		 replyTo:(int64_t)replyToId
 schedulingState:(NSDictionary *)schedulingState
		   silent:(BOOL)silent;
- (void)sendAnimation:(NSDictionary *)animation toChat:(int64_t)chatId thread:(int64_t)threadId;
- (void)sendAnimation:(NSDictionary *)animation caption:(NSString *)caption
			  toChat:(int64_t)chatId thread:(int64_t)threadId;
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
- (void)sendPhotoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce seconds:(NSInteger)seconds
				 toChat:(int64_t)chatId;
- (void)sendQuickReplyShortcutMessages:(NSInteger)shortcutId toChat:(int64_t)chatId
							 sendingId:(int32_t)sendingId
							completion:(void (^)(NSArray *messages, NSString *error))completion;
- (void)sendRichMessageDraft:(NSString *)text toChat:(int64_t)chatId
					 topicId:(int32_t)topicId draftId:(int64_t)draftId
					 canStop:(BOOL)canStop keepOnStop:(BOOL)keepOnStop
				  completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)sendStickerWithFileId:(NSInteger)fileId toChat:(int64_t)chatId thread:(int64_t)threadId;
- (void)sendText:(NSString *)text toChat:(int64_t)chatId thread:(int64_t)threadId;
- (void)sendVideoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce toChat:(int64_t)chatId;
- (void)sendVideoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce seconds:(NSInteger)seconds
				 toChat:(int64_t)chatId;
- (void)sendDocumentAtPath:(NSString *)path caption:(NSString *)caption
					toChat:(int64_t)chatId thread:(int64_t)threadId;
- (void)sendAudioAtPath:(NSString *)path title:(NSString *)title
			  performer:(NSString *)performer duration:(NSInteger)seconds
				caption:(NSString *)caption toChat:(int64_t)chatId thread:(int64_t)threadId;
- (void)sendPhotoAtPath:(NSString *)path toChat:(int64_t)chatId;
- (void)sendVideoAtPath:(NSString *)path toChat:(int64_t)chatId;
- (void)sendVoiceAtPath:(NSString *)path duration:(NSInteger)seconds
				 toChat:(int64_t)chatId thread:(int64_t)threadId viewOnce:(BOOL)viewOnce;
- (void)sendVideoNoteAtPath:(NSString *)path duration:(NSInteger)seconds
					 length:(NSInteger)length toChat:(int64_t)chatId thread:(int64_t)threadId
				   viewOnce:(BOOL)viewOnce;
- (void)sendVideoNoteAtPath:(NSString *)path duration:(NSInteger)seconds
					 length:(NSInteger)length toChat:(int64_t)chatId thread:(int64_t)threadId
				   viewOnce:(BOOL)viewOnce
				   progress:(void (^)(CGFloat progress))progress
				 completion:(void (^)(BOOL sent))completion;
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
- (CGFloat)sendProgressForMessage:(int64_t)messageId;
- (void)cancelSendingMessage:(int64_t)messageId inChat:(int64_t)chatId;
- (void)setSchedulingState:(NSDictionary *)state forMessage:(int64_t)messageId
					inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
- (void)editMessageText:(int64_t)messageId
				 inChat:(int64_t)chatId
		  formattedText:(NSDictionary *)formattedText;
- (void)deleteMessages:(NSArray *)messageIds
				inChat:(int64_t)chatId
				revoke:(BOOL)revoke;
- (void)resendMessages:(NSArray *)messageIds inChat:(int64_t)chatId;
- (void)retryMessageId:(int64_t)messageId inChat:(int64_t)chatId;
- (void)markSendingMessageId:(int64_t)messageId chatId:(int64_t)chatId;
- (TGSendState)stateForMessageId:(int64_t)messageId inChat:(int64_t)chatId;
- (NSString *)failureReasonForMessageId:(int64_t)messageId inChat:(int64_t)chatId;
- (BOOL)canRetryMessageId:(int64_t)messageId inChat:(int64_t)chatId;
- (void)adoptMessages:(NSArray *)messages inChat:(int64_t)chatId;
- (void)reset;
- (void)registerPendingMessage:(NSDictionary *)message inChat:(int64_t)chatId;
- (void)clientSendStateChanged:(NSNotification *)note;
- (void)applyFlattenedMessage:(NSDictionary *)message
					   chatId:(int64_t)chatId
				  oldMessageId:(int64_t)oldMessageId
				fallbackError:(NSDictionary *)fallback
					  publish:(BOOL)publish;
- (void)trimFinishedRecords;
- (void)publishState:(TGSendState)state
		   messageId:(int64_t)messageId
		 oldMessageId:(int64_t)oldMessageId
				error:(NSString *)error
			canRetry:(BOOL)canRetry
			  chatId:(int64_t)chatId;

@end
