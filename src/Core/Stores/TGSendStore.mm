//
// TGSendStore.mm - the C++ table behind TGSendStore.h.
//
// One record per tracked message, keyed by chat and message id. The table is
// small - a few dozen entries while sends are in flight - and it is the only
// place that answers "is this bubble failed, and why". Requests go through the
// client; state comes back through updateMessageSendSucceeded /
// updateMessageSendFailed, which the client reposts as a notification.
//
#import "TGSendStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+MessagesInternal.h"
#include <string>
#include <unordered_map>

NSString *const TGSendStoreMessageStateChangedNotification =
		@"TGSendStoreMessageStateChangedNotification";
NSString *const TGSendStoreChatIdKey = @"chatId";
NSString *const TGSendStoreMessageIdKey = @"messageId";
NSString *const TGSendStoreOldMessageIdKey = @"oldMessageId";
NSString *const TGSendStoreStateKey = @"state";
NSString *const TGSendStoreErrorKey = @"error";
NSString *const TGSendStoreCanRetryKey = @"canRetry";

namespace {

struct TGSendKey {
	int64_t chatId;
	int64_t messageId;

	bool operator==(const TGSendKey &other) const {
		return chatId == other.chatId && messageId == other.messageId;
	}
};

struct TGSendKeyHash {
	size_t operator()(const TGSendKey &key) const {
		size_t chat = std::hash<int64_t>()(key.chatId);
		size_t message = std::hash<int64_t>()(key.messageId);
		return chat * 31 + message;
	}
};

struct TGSendRecord {
	TGSendState state;
	bool canRetry;
	std::string error;
};

/// TDLib's canonical spelling is messageSendingStateFailed; the flattened
/// dictionary the client posts carries the two facts this table needs.
TGSendState TGStateFromMessage(NSDictionary *message) {
	if (![message isKindOfClass:NSDictionary.class])
		return TGSendStateUnknown;
	if ([message[@"failed"] boolValue])
		return TGSendStateFailed;
	if ([message[@"sending"] boolValue])
		return TGSendStateSending;
	return TGSendStateSent;
}

NSString *TGErrorMessage(NSDictionary *message, NSDictionary *fallback) {
	NSString *reason = [message[@"errorMessage"] isKindOfClass:NSString.class]
			? message[@"errorMessage"] : @"";
	if (reason.length)
		return reason;
	id text = fallback[@"message"];
	if (![text isKindOfClass:NSString.class])
		text = fallback[@"error_message"];
	return [text isKindOfClass:NSString.class] ? text : @"";
}

}  // namespace

@interface TGSendStore () {
	std::unordered_map<TGSendKey, TGSendRecord, TGSendKeyHash> _states;
}
@end

@implementation TGSendStore

+ (instancetype)shared {
	static TGSendStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		store = [[TGSendStore alloc] init];
	});
	return store;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver:self
				selector:@selector(clientSendStateChanged:)
					name:TGMessageSendStateChangedNotification
				  object:nil];
	}
	return self;
}

#pragma mark - outbound requests

- (void)sendFormattedText:(NSDictionary *)formattedText
				   toChat:(int64_t)chatId
				   thread:(int64_t)threadId
				  replyTo:(int64_t)replyToId
		  schedulingState:(NSDictionary *)schedulingState {
	[self sendFormattedText:formattedText toChat:chatId thread:threadId
					replyTo:replyToId schedulingState:schedulingState silent:NO];
}

- (void)sendFormattedText:(NSDictionary *)formattedText
				   toChat:(int64_t)chatId
				   thread:(int64_t)threadId
				  replyTo:(int64_t)replyToId
		  schedulingState:(NSDictionary *)schedulingState
				   silent:(BOOL)silent {
	NSDictionary *options = (silent || schedulingState[@"@type"])
			? [TGClient messageSendOptionsSilent:silent schedulingState:schedulingState]
			: nil;
	__weak __typeof__(self) weakSelf = self;
	[[TGClient shared] sendFormattedText:formattedText
								  toChat:chatId
								  thread:threadId
								 replyTo:replyToId
						 schedulingState:schedulingState
								 options:options
							  completion:^(NSDictionary *message) {
		[weakSelf registerPendingMessage:message inChat:chatId];
	}];
}

- (void)sendText:(NSString *)text
		  toChat:(int64_t)chatId
		  thread:(int64_t)threadId
		 replyTo:(int64_t)replyToId
 schedulingState:(NSDictionary *)schedulingState {
	[self sendText:text toChat:chatId thread:threadId replyTo:replyToId
   schedulingState:schedulingState silent:NO];
}

- (void)sendText:(NSString *)text
		  toChat:(int64_t)chatId
		  thread:(int64_t)threadId
		 replyTo:(int64_t)replyToId
 schedulingState:(NSDictionary *)schedulingState
		   silent:(BOOL)silent {
	NSDictionary *options = (silent || schedulingState[@"@type"])
			? [TGClient messageSendOptionsSilent:silent schedulingState:schedulingState]
			: nil;
	__weak __typeof__(self) weakSelf = self;
	[[TGClient shared] sendText:text
						toChat:chatId
						thread:threadId
					   replyTo:replyToId
					 scheduled:schedulingState
					   options:options
					completion:^(NSDictionary *message) {
		[weakSelf registerPendingMessage:message inChat:chatId];
	}];
}

- (void)sendAnimation:(NSDictionary *)animation toChat:(int64_t)chatId thread:(int64_t)threadId {
	[self sendAnimation:animation caption:@"" toChat:chatId thread:threadId];
}

- (void)sendAnimation:(NSDictionary *)animation caption:(NSString *)caption
			  toChat:(int64_t)chatId thread:(int64_t)threadId {
	if (animation[@"queryId"] && animation[@"resultId"]){
		[[TGClient shared] send:@{
			@"@type"             : @"sendInlineQueryResultMessage",
			@"chat_id"           : @(chatId),
			@"message_thread_id" : @(threadId),
			@"query_id"          : animation[@"queryId"],
			@"result_id"         : animation[@"resultId"],
		}];
		return;
	}
	if (!animation[@"fileId"])
		return;
	[[TGClient shared] send:@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"message_thread_id"    : @(threadId),
		// Same nesting as stickers: inputMessageAnimation takes an
		// inputAnimation, and that is what holds the InputFile.
		@"input_message_content": @{
			@"@type"     : @"inputMessageAnimation",
			@"caption"   : [caption ?: @"" length]
					? TGFormattedText(caption) : [NSNull null],
			@"animation" : @{
				@"@type"     : @"inputAnimation",
				@"animation" : @{@"@type" : @"inputFileId", @"id" : animation[@"fileId"]},
				@"duration"  : animation[@"duration"] ?: @0,
				@"width"     : animation[@"width"] ?: @0,
				@"height"    : animation[@"height"] ?: @0,
			},
		},
	}];
}

- (void)sendChecklist:(NSString *)title tasks:(NSArray *)tasks
			   toChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] sendChecklist:title tasks:tasks toChat:chatId completion:completion];
}

- (void)sendContactNamed:(NSString *)name phone:(NSString *)phone toChat:(int64_t)chatId {
	if (!phone.length)
		return;
	[[TGClient shared] send:@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"input_message_content": @{
			@"@type"   : @"inputMessageContact",
			@"contact" : @{
				@"@type"        : @"contact",
				@"phone_number" : phone,
				@"first_name"   : name ?: @"",
				@"user_id"      : @(0),
			},
		},
	}];
}

- (void)sendEphemeralText:(NSString *)text toChat:(int64_t)chatId
			 receiverUserId:(int64_t)receiverUserId
			ephemeralReplyId:(NSInteger)ephemeralReplyId
				 completion:(void (^)(NSDictionary *message, NSString *error))completion {
	[[TGClient shared] sendEphemeralText:text toChat:chatId
						 receiverUserId:receiverUserId
						ephemeralReplyId:ephemeralReplyId
							 completion:completion];
}

- (void)sendLiveLocation:(NSInteger)seconds latitude:(double)latitude
			   longitude:(double)longitude toChat:(int64_t)chatId
			  completion:(void (^)(int64_t messageId))completion {
	[[TGClient shared] request:@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"input_message_content": @{
			@"@type"    : @"inputMessageLiveLocation",
			@"location" : @{
				@"@type"       : @"liveLocation",
				@"location"    : @{@"@type"     : @"location",
								   @"latitude"  : @(latitude),
								   @"longitude" : @(longitude)},
				@"live_period" : @(seconds),
				@"heading"     : @(0),
				@"proximity_alert_radius" : @(0),
			},
		},
	} completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"id"] longLongValue]);
	}];
}

- (void)sendLocation:(double)latitude longitude:(double)longitude toChat:(int64_t)chatId {
	[[TGClient shared] send:@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"input_message_content": @{
			@"@type"    : @"inputMessageLocation",
			@"location" : @{
				@"@type"     : @"location",
				@"latitude"  : @(latitude),
				@"longitude" : @(longitude),
			},
		},
	}];
}

- (void)sendPhotoAlbumAtPaths:(NSArray *)paths caption:(NSString *)caption
					   toChat:(int64_t)chatId thread:(int64_t)threadId {
	if (!paths.count)
		return;
	NSMutableArray *contents = [NSMutableArray array];
	for (NSUInteger i = 0; i < MIN(paths.count, (NSUInteger)10); i++){
		NSString *path = paths[i];
		if (![path isKindOfClass:NSString.class] || !path.length)
			continue;
		[contents addObject:@{
			@"@type"   : @"inputMessagePhoto",
			@"photo"   : @{@"@type" : @"inputFileLocal", @"path" : path},
			@"caption" : TGFormattedText(i == 0 ? caption : nil),
		}];
	}
	if (!contents.count)
		return;
	[[TGClient shared] send:@{
		@"@type"                  : @"sendMessageAlbum",
		@"chat_id"                : @(chatId),
		@"message_thread_id"      : @(threadId),
		@"input_message_contents" : contents,
	}];
}

- (void)sendPhotoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce toChat:(int64_t)chatId {
	[self sendPhotoAtPath:path viewOnce:viewOnce seconds:0 toChat:chatId];
}

- (void)sendPhotoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce seconds:(NSInteger)seconds
				 toChat:(int64_t)chatId {
	if (!path.length)
		return;
	id destruct = viewOnce
			? (seconds > 0
					? @{@"@type" : @"messageSelfDestructTypeTimer",
						@"self_destruct_time" : @(seconds)}
					: @{@"@type" : @"messageSelfDestructTypeImmediately"})
			: [NSNull null];
	[[TGClient shared] send:@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"input_message_content": @{
			@"@type" : @"inputMessagePhoto",
			@"photo" : @{
				@"@type" : @"inputPhoto",
				@"photo" : @{@"@type" : @"inputFileLocal", @"path" : path},
			},
			@"self_destruct_type" : destruct,
		},
	}];
}

- (void)sendQuickReplyShortcutMessages:(NSInteger)shortcutId toChat:(int64_t)chatId
							 sendingId:(int32_t)sendingId
							completion:(void (^)(NSArray *messages, NSString *error))completion {
	[[TGClient shared] sendQuickReplyShortcutMessages:shortcutId toChat:chatId
											sendingId:sendingId completion:completion];
}

- (void)sendRichMessageDraft:(NSString *)text toChat:(int64_t)chatId
					 topicId:(int32_t)topicId draftId:(int64_t)draftId
					 canStop:(BOOL)canStop keepOnStop:(BOOL)keepOnStop
				  completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] sendRichMessageDraft:text toChat:chatId topicId:topicId
									draftId:draftId canStop:canStop
								 keepOnStop:keepOnStop completion:completion];
}

- (void)sendStickerWithFileId:(NSInteger)fileId toChat:(int64_t)chatId thread:(int64_t)threadId {
	[[TGClient shared] send:@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"message_thread_id"    : @(threadId),
		@"input_message_content": @{
			@"@type"   : @"inputMessageSticker",
			@"sticker" : @{
				@"@type"   : @"inputSticker",
				@"sticker" : @{@"@type" : @"inputFileId", @"id" : @(fileId)},
				@"width"   : @512,
				@"height"  : @512,
			},
			@"emoji"   : @"",
		},
	}];
	// Sending does not put it in Recently Used on its own, so the strip never
	// filled up as stickers were sent.
	[[TGClient shared] send:@{
		@"@type"       : @"addRecentSticker",
		@"is_attached" : @NO,
		@"sticker"     : @{@"@type" : @"inputFileId", @"id" : @(fileId)},
	}];
}

- (void)sendText:(NSString *)text toChat:(int64_t)chatId thread:(int64_t)threadId {
	[[TGClient shared] sendText:text toChat:chatId thread:threadId];
}

- (void)sendVideoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce toChat:(int64_t)chatId {
	[self sendVideoAtPath:path viewOnce:viewOnce seconds:0 toChat:chatId];
}

- (void)sendVideoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce seconds:(NSInteger)seconds
				 toChat:(int64_t)chatId {
	if (!path.length)
		return;
	id destruct = viewOnce
			? (seconds > 0
					? @{@"@type" : @"messageSelfDestructTypeTimer",
						@"self_destruct_time" : @(seconds)}
					: @{@"@type" : @"messageSelfDestructTypeImmediately"})
			: [NSNull null];
	[[TGClient shared] send:@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"input_message_content": @{
			@"@type" : @"inputMessageVideo",
			@"video" : @{
				@"@type" : @"inputVideo",
				@"video" : @{@"@type" : @"inputFileLocal", @"path" : path},
			},
			@"self_destruct_type" : destruct,
		},
	}];
}

- (void)sendDocumentAtPath:(NSString *)path caption:(NSString *)caption
					toChat:(int64_t)chatId thread:(int64_t)threadId {
	if (!path.length)
		return;
	NSString *text = [caption ?: @"" stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	[[TGClient shared] send:@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"message_thread_id"    : @(threadId),
		@"input_message_content": @{
			@"@type"    : @"inputMessageDocument",
			@"document" : @{
				@"@type"      : @"inputDocument",
				@"document"   : @{@"@type" : @"inputFileLocal", @"path" : path},
				@"force_file" : @YES,
			},
			@"caption"  : text.length ? TGFormattedText(text) : [NSNull null],
		},
	}];
}

- (void)sendAudioAtPath:(NSString *)path title:(NSString *)title
			  performer:(NSString *)performer duration:(NSInteger)seconds
				caption:(NSString *)caption toChat:(int64_t)chatId thread:(int64_t)threadId {
	if (!path.length)
		return;
	NSString *text = [caption ?: @"" stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	[[TGClient shared] send:@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"message_thread_id"    : @(threadId),
		@"input_message_content": @{
			@"@type" : @"inputMessageAudio",
			@"audio" : @{
				@"@type"     : @"inputAudio",
				@"audio"     : @{@"@type" : @"inputFileLocal", @"path" : path},
				@"duration"  : @(MAX(0, seconds)),
				@"title"     : title ?: @"",
				@"performer" : performer ?: @"",
			},
			@"caption" : text.length ? TGFormattedText(text) : [NSNull null],
		},
	}];
}

- (void)sendVideoNoteAtPath:(NSString *)path duration:(NSInteger)seconds
					 length:(NSInteger)length toChat:(int64_t)chatId thread:(int64_t)threadId
				   viewOnce:(BOOL)viewOnce thumbnail:(NSString *)thumbnailPath
				   progress:(void (^)(CGFloat progress))progress
				   accepted:(void (^)(int64_t messageId))accepted
				 completion:(void (^)(BOOL sent))completion {
	if (!path.length){
		if (completion)
			completion(NO);
		return;
	}
	id destruct = viewOnce
			? @{@"@type" : @"messageSelfDestructTypeImmediately"}
			: [NSNull null];
	// A note with no thumbnail is a black circle to everyone who receives it;
	// null is what the schema takes when the recorder could not make one.
	id thumbnail = [NSNull null];
	if (thumbnailPath.length){
		thumbnail = @{
			@"@type"     : @"inputThumbnail",
			@"thumbnail" : @{@"@type" : @"inputFileLocal", @"path" : thumbnailPath},
			@"width"     : @240,
			@"height"    : @240,
		};
	}
	[[TGClient shared] request:@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"message_thread_id"    : @(threadId),
		@"input_message_content": @{
			@"@type" : @"inputMessageVideoNote",
			@"video_note" : @{
				@"@type" : @"inputVideoNote",
				@"video_note" : @{@"@type" : @"inputFileLocal", @"path" : path},
				@"duration" : @(seconds),
				@"length" : @(length),
				@"thumbnail" : thumbnail,
			},
			@"self_destruct_type" : destruct,
		},
	} completion:^(NSDictionary *result){
		if ([result[@"@type"] isEqualToString:@"error"]){
			NSLog(@"TGSendStore: video note rejected: %@ %@",
					result[@"code"], result[@"message"]);
			if (completion)
				completion(NO);
			return;
		}
		NSLog(@"TGSendStore: video note accepted, message %@", result[@"id"]);
		int64_t messageId = [result[@"id"] longLongValue];
		if (messageId <= 0){
			// Without the pending id there is no update that could ever say
			// how the send ended.
			if (completion)
				completion(NO);
			return;
		}
		// The result is the whole message; its video note names the local
		// file TDLib will upload, which is what updateFile reports progress on.
		NSDictionary *content = [result[@"content"] isKindOfClass:NSDictionary.class]
				? result[@"content"] : nil;
		NSDictionary *note = [content[@"video_note"] isKindOfClass:NSDictionary.class]
				? content[@"video_note"] : nil;
		NSDictionary *video = [note[@"video"] isKindOfClass:NSDictionary.class]
				? note[@"video"] : nil;
		if (accepted)
			accepted(messageId);
		[[TGClient shared] registerSendWaiterForMessage:messageId
									fileId:(video ? [video[@"id"] integerValue] : 0)
								  progress:progress completion:completion];
	}];
}

- (void)sendVoiceAtPath:(NSString *)path duration:(NSInteger)seconds
				 toChat:(int64_t)chatId thread:(int64_t)threadId viewOnce:(BOOL)viewOnce
			   progress:(void (^)(CGFloat progress))progress
			   accepted:(void (^)(int64_t messageId))accepted
			 completion:(void (^)(BOOL sent))completion {
	if (!path.length){
		if (completion)
			completion(NO);
		return;
	}

	NSDictionary *attributes = [[NSFileManager defaultManager]
			attributesOfItemAtPath:path error:nil];
	NSLog(@"TGSendStore: sending voice %@ (%llu bytes, %lds, once %d) to %lld",
			path.lastPathComponent, [attributes fileSize], (long)seconds,
			viewOnce, chatId);

	// The one-time mode is written the way their clients do it: a timer of
	// 0x7fffffff, whose whole meaning is "gone the moment it is opened".
	id destruct = viewOnce
			? @{@"@type" : @"messageSelfDestructTypeImmediately"}
			: [NSNull null];

	// Answered rather than fire-and-forget: a rejected voice note is silent
	// otherwise, and the file it points at lives in a temporary directory.
	[[TGClient shared] request:@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"message_thread_id"    : @(threadId),
		@"input_message_content": @{
			@"@type"      : @"inputMessageVoiceNote",
			@"voice_note" : @{
				@"@type"      : @"inputVoiceNote",
				@"voice_note" : @{@"@type" : @"inputFileLocal", @"path" : path},
				@"duration"   : @(seconds),
				@"waveform"   : @"",
			},
			@"caption"    : [NSNull null],
			@"self_destruct_type" : destruct,
		},
	} completion:^(NSDictionary *result){
		if ([result[@"@type"] isEqualToString:@"error"]){
			NSLog(@"TGSendStore: voice rejected: %@ %@",
					result[@"code"], result[@"message"]);
			if (completion)
				completion(NO);
			return;
		}
		NSLog(@"TGSendStore: voice accepted, message %@", result[@"id"]);
		int64_t messageId = [result[@"id"] longLongValue];
		if (messageId <= 0){
			if (completion)
				completion(NO);
			return;
		}
		if (accepted)
			accepted(messageId);
		NSDictionary *content = [result[@"content"] isKindOfClass:NSDictionary.class]
				? result[@"content"] : nil;
		NSDictionary *note = [content[@"voice_note"] isKindOfClass:NSDictionary.class]
				? content[@"voice_note"] : nil;
		NSDictionary *voice = [note[@"voice"] isKindOfClass:NSDictionary.class]
				? note[@"voice"] : nil;
		[[TGClient shared] registerSendWaiterForMessage:messageId
									fileId:(voice ? [voice[@"id"] integerValue] : 0)
								  progress:progress completion:completion];
	}];
}

- (CGFloat)sendProgressForMessage:(int64_t)messageId {
	return [[TGClient shared] sendProgressForMessage:messageId];
}

- (void)cancelSendingMessage:(int64_t)messageId inChat:(int64_t)chatId {
	if (!messageId)
		return;
	[self deleteMessages:@[@(messageId)] inChat:chatId revoke:YES];
	// Nothing is left to wait for: the person took the message back, so the
	// waiter answers YES and the chat can drop its sending row.
	[[TGClient shared] noteSendFinished:messageId sent:YES];
}

- (void)setSchedulingState:(NSDictionary *)state forMessage:(int64_t)messageId
					inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
	// An optional object reads back as the JSON null TDLib documents for
	// "send immediately", which is not a dictionary.
	id value = state[@"@type"] ? state : [NSNull null];
	[[TGClient shared] request:@{
		@"@type"            : @"editMessageSchedulingState",
		@"chat_id"          : @(chatId),
		@"message_id"       : @(messageId),
		@"scheduling_state" : value,
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)editMessageText:(int64_t)messageId
				 inChat:(int64_t)chatId
		  formattedText:(NSDictionary *)formattedText {
	[[TGClient shared] editMessage:messageId
							inChat:chatId
					 formattedText:formattedText];
}

- (void)deleteMessages:(NSArray *)messageIds
				inChat:(int64_t)chatId
				revoke:(BOOL)revoke {
	if (!messageIds.count)
		return;
	[[TGClient shared] send:@{
		@"@type"        : @"deleteMessages",
		@"chat_id"      : @(chatId),
		@"message_ids"  : messageIds,
		@"revoke"       : @(revoke),
	}];

	// The rows are gone; keeping their failure records would make a reused id
	// look failed on another message.
	for (NSNumber *value in messageIds) {
		int64_t messageId = [value respondsToSelector:@selector(longLongValue)]
				? [value longLongValue] : 0;
		if (messageId <= 0)
			continue;
		TGSendKey key = {chatId, messageId};
		_states.erase(key);
		[self publishState:TGSendStateUnknown
				   messageId:messageId
				 oldMessageId:0
						error:@""
					canRetry:NO
					  chatId:chatId];
	}
}

- (void)resendMessages:(NSArray *)messageIds inChat:(int64_t)chatId {
	if (!messageIds.count)
		return;
	[[TGClient shared] send:@{
		@"@type"       : @"resendMessages",
		@"chat_id"     : @(chatId),
		@"message_ids" : messageIds,
	}];
	for (NSNumber *value in messageIds) {
		int64_t messageId = [value respondsToSelector:@selector(longLongValue)]
				? [value longLongValue] : 0;
		if (messageId > 0)
			[self markSendingMessageId:messageId chatId:chatId];
	}
}

- (void)retryMessageId:(int64_t)messageId inChat:(int64_t)chatId {
	if (messageId <= 0)
		return;
	[self resendMessages:@[@(messageId)] inChat:chatId];
}

- (void)markSendingMessageId:(int64_t)messageId chatId:(int64_t)chatId {
	TGSendKey key = {chatId, messageId};
	auto found = _states.find(key);
	BOOL changed = found == _states.end() ||
			found->second.state != TGSendStateSending ||
			!found->second.error.empty() || found->second.canRetry;
	TGSendRecord record;
	record.state = TGSendStateSending;
	record.canRetry = NO;
	record.error.clear();
	_states[key] = record;
	if (changed)
		[self publishState:TGSendStateSending
				   messageId:messageId
				 oldMessageId:0
						error:@""
					canRetry:NO
					  chatId:chatId];
}

#pragma mark - state

- (TGSendState)stateForMessageId:(int64_t)messageId inChat:(int64_t)chatId {
	if (messageId <= 0)
		return TGSendStateUnknown;
	TGSendKey key = {chatId, messageId};
	auto found = _states.find(key);
	return found == _states.end() ? TGSendStateUnknown : found->second.state;
}

- (NSString *)failureReasonForMessageId:(int64_t)messageId inChat:(int64_t)chatId {
	if (messageId <= 0)
		return @"";
	TGSendKey key = {chatId, messageId};
	auto found = _states.find(key);
	if (found == _states.end() || found->second.error.empty())
		return @"";
	return [NSString stringWithUTF8String:found->second.error.c_str()] ?: @"";
}

- (BOOL)canRetryMessageId:(int64_t)messageId inChat:(int64_t)chatId {
	if (messageId <= 0)
		return NO;
	TGSendKey key = {chatId, messageId};
	auto found = _states.find(key);
	return found != _states.end() && found->second.canRetry;
}

- (void)adoptMessages:(NSArray *)messages inChat:(int64_t)chatId {
	if (![messages isKindOfClass:NSArray.class] || !messages.count)
		return;
	for (NSDictionary *raw in messages) {
		if (![raw isKindOfClass:NSDictionary.class])
			continue;
		// A history page is already flattened; a raw TDLib message is still
		// accepted so the same entry point can seed from either shape.
		NSDictionary *message = [raw[@"@type"] isEqualToString:@"message"]
				? TGFlattenMessage(raw) : raw;
		int64_t messageId = [message[@"id"] longLongValue];
		if (messageId <= 0)
			continue;
		// Only the two states a history page can carry that the bubble cannot
		// read for itself. A sent message needs no record at all.
		TGSendState state = TGStateFromMessage(message);
		if (state != TGSendStateFailed && state != TGSendStateSending)
			continue;
		TGSendKey key = {chatId, messageId};
		if (_states.find(key) != _states.end())
			continue;  // a live update is newer than the page
		TGSendRecord record;
		record.state = state;
		record.canRetry = state == TGSendStateFailed &&
				(!message[@"canRetry"] || [message[@"canRetry"] boolValue]);
		NSString *reason = TGErrorMessage(message, nil);
		record.error = reason.UTF8String ?: "";
		_states[key] = record;
	}
}

- (void)reset {
	_states.clear();
}

#pragma mark - updates

/// A sendMessage answer is the pending message itself: its id is what the
/// later updateMessageSendSucceeded/Failed will name.
- (void)registerPendingMessage:(NSDictionary *)message inChat:(int64_t)chatId {
	if (![message isKindOfClass:NSDictionary.class])
		return;
	if (![message[@"@type"] isEqualToString:@"message"])
		return;
	int64_t messageId = [message[@"id"] longLongValue];
	if (messageId <= 0)
		return;
	NSDictionary *flat = TGFlattenMessage(message);
	[self applyFlattenedMessage:flat
						 chatId:chatId
					  oldMessageId:0
					fallbackError:nil
						publish:YES];
}

/// The client reposts updateMessageSendSucceeded/Failed here. `error` is the
/// update's own record, which the message's sending_state may not repeat.
- (void)clientSendStateChanged:(NSNotification *)note {
	NSDictionary *message = note.userInfo[@"message"];
	if (![message isKindOfClass:NSDictionary.class])
		return;
	int64_t chatId = [note.userInfo[@"chatId"] longLongValue];
	int64_t oldId = [note.userInfo[@"oldMessageId"] longLongValue];
	id error = note.userInfo[@"error"];
	NSDictionary *fallback = [error isKindOfClass:NSDictionary.class]
			? error : nil;
	[self applyFlattenedMessage:message
						 chatId:chatId
					  oldMessageId:oldId
					fallbackError:fallback
						publish:YES];
}

- (void)applyFlattenedMessage:(NSDictionary *)message
					   chatId:(int64_t)chatId
				  oldMessageId:(int64_t)oldMessageId
				fallbackError:(NSDictionary *)fallback
					  publish:(BOOL)publish {
	if (![message isKindOfClass:NSDictionary.class])
		return;
	int64_t messageId = [message[@"id"] longLongValue];
	if (messageId <= 0)
		return;

	NSString *reason = TGErrorMessage(message, fallback);
	TGSendState state = TGStateFromMessage(message);
	BOOL canRetry = state == TGSendStateFailed &&
			(!message[@"canRetry"] || [message[@"canRetry"] boolValue]);

	// A successful send keeps the message but renames it. The old id is the
	// one the bubble has been using, and leaving its record behind would make
	// a later reuse of that temporary id look like somebody else's failure.
	TGSendKey key = {chatId, messageId};
	auto found = _states.find(key);
	BOOL hadNew = found != _states.end();
	BOOL hadOld = NO;
	if (oldMessageId > 0 && oldMessageId != messageId) {
		TGSendKey oldKey = {chatId, oldMessageId};
		hadOld = _states.find(oldKey) != _states.end();
		_states.erase(oldKey);
	}

	// Sends that never went through the store (stickers, photos, forwards)
	// still report success here. A success needs no row of its own: keeping
	// one for every message would grow the table for no reader.
	if (state == TGSendStateSent && !hadNew && !hadOld)
		return;

	BOOL changed = hadOld || !hadNew ||
			found->second.state != state ||
			found->second.canRetry != canRetry ||
			found->second.error != (reason.UTF8String ?: "");

	TGSendRecord record;
	record.state = state;
	record.canRetry = canRetry;
	record.error = reason.UTF8String ?: "";
	_states[key] = record;
	[self trimFinishedRecords];

	if (publish && changed) {
		[self publishState:state
				   messageId:messageId
				 oldMessageId:(oldMessageId > 0 && oldMessageId != messageId
							? oldMessageId : 0)
						error:reason
					canRetry:canRetry
					  chatId:chatId];
	}
}

/// Sent records are history the bubbles no longer ask about. A long session
/// would otherwise keep one per message; 256 is more than the chat draws.
- (void)trimFinishedRecords {
	if (_states.size() < 256)
		return;
	for (auto it = _states.begin(); it != _states.end() && _states.size() >= 200; ) {
		if (it->second.state == TGSendStateSent)
			it = _states.erase(it);
		else
			++it;
	}
}

- (void)publishState:(TGSendState)state
		   messageId:(int64_t)messageId
		 oldMessageId:(int64_t)oldMessageId
				error:(NSString *)error
			canRetry:(BOOL)canRetry
			  chatId:(int64_t)chatId {
	NSMutableDictionary *info = [@{
		TGSendStoreChatIdKey    : @(chatId),
		TGSendStoreMessageIdKey : @(messageId),
		TGSendStoreStateKey     : @(state),
		TGSendStoreErrorKey     : error ?: @"",
		TGSendStoreCanRetryKey  : @(canRetry),
	} mutableCopy];
	if (oldMessageId > 0)
		info[TGSendStoreOldMessageIdKey] = @(oldMessageId);
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGSendStoreMessageStateChangedNotification
						  object:self
						userInfo:info];
}

@end
