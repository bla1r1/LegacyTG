#import "TGClient+Messages.h"
#import "TGClient+MessagesInternal.h"
#import "TGClientInternal.h"
#import "TGSendStore.h"
#import "TGMessageStore.h"

@implementation TGClient (Messages)

#pragma mark - messages

- (void)historyForChat:(int64_t)chatId
                thread:(int64_t)threadId
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *))completion {
	[[TGMessageStore shared] historyForChat:chatId thread:threadId limit:limit completion:completion];
}

/// Presses a callback button. The bot answers with a line to show
/// ("text", as an alert when "alert"), a link to open ("url"), or nothing.
- (void)pressCallbackButton:(NSDictionary *)button
					 inChat:(int64_t)chatId
				  messageId:(int64_t)messageId
				 completion:(void (^)(NSString *text, BOOL alert, NSString *url,
									  NSString *error))completion {
	[self request:@{@"@type" : @"getCallbackQueryAnswer",
					@"chat_id" : @(chatId),
					@"message_id" : @(messageId),
					// A game button asks for the game's page, not for data.
					@"payload" : [button[@"gameShortName"] length]
						? @{@"@type" : @"callbackQueryPayloadGame",
							@"game_short_name" : button[@"gameShortName"]}
						: @{@"@type" : @"callbackQueryPayloadData",
							@"data" : button[@"data"] ?: @""}}
	   completion:^(NSDictionary *answer){
		if (!completion)
			return;
		if (![answer[@"@type"] isEqualToString:@"callbackQueryAnswer"]) {
			NSString *message = answer[@"message"];
			completion(nil, NO, nil, message.length ? message : @"The bot did not answer.");
			return;
		}
		completion(answer[@"text"], [answer[@"show_alert"] boolValue], answer[@"url"], nil);
	}];
}

/// A login button signs the user into the bot's site. Telegram either hands
/// the link back at once ("url") or wants the user to agree first
/// ("confirmDomain"), after which confirmLoginButton: fetches the link.
- (void)loginURLForButton:(NSDictionary *)button
				   inChat:(int64_t)chatId
				messageId:(int64_t)messageId
			   completion:(void (^)(NSString *url, NSString *confirmDomain,
									NSString *error))completion {
	[self request:@{@"@type" : @"getLoginUrlInfo",
					@"chat_id" : @(chatId),
					@"message_id" : @(messageId),
					@"button_id" : button[@"buttonId"] ?: @0}
	   completion:^(NSDictionary *info){
		if (!completion)
			return;
		NSString *t = info[@"@type"];
		if ([t isEqualToString:@"loginUrlInfoOpen"])
			completion(info[@"url"], nil, nil);
		else if ([t isEqualToString:@"loginUrlInfoRequestConfirmation"])
			completion(nil, info[@"domain"] ?: info[@"url"], nil);
		else
			// No login on offer: the button's plain address still opens.
			completion(button[@"url"], nil, nil);
	}];
}

- (void)confirmLoginButton:(NSDictionary *)button
					inChat:(int64_t)chatId
				 messageId:(int64_t)messageId
				completion:(void (^)(NSString *url, NSString *error))completion {
	[self request:@{@"@type" : @"getLoginUrl",
					@"chat_id" : @(chatId),
					@"message_id" : @(messageId),
					@"button_id" : button[@"buttonId"] ?: @0,
					@"allow_write_access" : @NO}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		NSString *url = result[@"url"];
		completion(url.length ? url : nil, url.length ? nil : (result[@"message"] ?: @"An error occurred."));
	}];
}

/// The keyboard a bot left on this chat, or nil. The chat names the message
/// that carries it; it is fetched once and kept on the chat record.
- (void)replyKeyboardForChat:(int64_t)chatId completion:(void (^)(NSDictionary *keyboard))completion {
	NSMutableDictionary *chat = self.chatsById[@(chatId)];
	id kept = chat[@"replyKeyboard"];
	if (kept) {
		if (completion) completion([kept isKindOfClass:NSDictionary.class] ? kept : nil);
		return;
	}
	int64_t messageId = [chat[@"replyMarkupMessageId"] longLongValue];
	if (!messageId) {
		if (completion) completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getMessage", @"chat_id" : @(chatId), @"message_id" : @(messageId)}
	   completion:^(NSDictionary *m){
		NSDictionary *keyboard = TGFlattenReplyMarkup(m[@"reply_markup"])[@"replyKeyboard"];
		self.chatsById[@(chatId)][@"replyKeyboard"] = keyboard ?: [NSNull null];
		if (completion) completion(keyboard);
	}];
}

/// The comments under a channel post live in its discussion group, as a
/// thread there. TDLib answers with that group's chat id and the thread id,
/// which is what a chat screen opens with; `error` is set instead when the
/// post has no comments to open.
- (void)commentThreadForChat:(int64_t)chatId
				   messageId:(int64_t)messageId
				  completion:(void (^)(int64_t discussionChatId, int64_t threadId,
									   NSString *error))completion {
	[self request:@{@"@type" : @"getMessageThread",
					@"chat_id" : @(chatId),
					@"message_id" : @(messageId)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		int64_t discussion = [result[@"chat_id"] longLongValue];
		int64_t thread = [result[@"message_thread_id"] longLongValue];
		if (![result[@"@type"] isEqualToString:@"messageThreadInfo"] || !discussion || !thread) {
			NSString *message = result[@"message"];
			completion(0, 0, message.length ? message : @"These comments cannot be opened.");
			return;
		}
		completion(discussion, thread, nil);
	}];
}

- (void)searchMessages:(NSString *)query completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type"  : @"searchMessages",
		@"query"  : query ?: @"",
		@"limit"  : @(50),
		@"offset" : @"",
	} completion:^(NSDictionary *result){
		TGClient *me = weakSelf;
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *m in result[@"messages"]){
			NSMutableDictionary *flat = [TGFlattenMessage(m) mutableCopy];
			if (!flat) continue;
			int64_t chatId = [m[@"chat_id"] longLongValue];
			flat[@"chatId"] = @(chatId);
			flat[@"chatTitle"] = [me titleForChat:chatId] ?: @"";
			[out addObject:flat];
		}
		if (completion) completion(out);
	}];
}

- (void)searchInChat:(int64_t)chatId query:(NSString *)query
          completion:(void (^)(NSArray *))completion {
	// A secret chat answers its own spelling: searchChatMessages refuses
	// a non-empty query there, searchSecretMessages is the one TDLib takes.
	NSDictionary *info = self.chatsById[@(chatId)];
	BOOL secret = [info[@"isSecret"] boolValue];
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type"           : secret ? @"searchSecretMessages"
									: @"searchChatMessages",
		@"chat_id"         : @(chatId),
		@"query"           : query ?: @"",
		@"offset"          : secret ? @"" : @(0),
		@"limit"           : @(50),
	} completion:^(NSDictionary *result){
		TGClient *me = weakSelf;
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *m in result[@"messages"]){
			NSDictionary *flat = TGFlattenMessage(m);
			if (flat) [out addObject:flat];
		}
		if (completion) completion(out);
	}];
}

/// Title of a chat we already know about, for search results that name it.
- (NSString *)titleForChat:(int64_t)chatId {
	for (NSDictionary *c in self.chats)
		if ([c[@"id"] longLongValue] == chatId)
			return c[@"title"];
	for (NSDictionary *c in self.archivedChats)
		if ([c[@"id"] longLongValue] == chatId)
			return c[@"title"];
	return nil;
}

- (void)historyForChat:(int64_t)chatId
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *))completion {
    [self historyForChat:chatId fromMessageId:0 limit:limit completion:completion];
}

- (void)historyForChat:(int64_t)chatId
         fromMessageId:(int64_t)fromMessageId
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *))completion {
	[[TGMessageStore shared] historyForChat:chatId fromMessageId:fromMessageId limit:limit completion:completion];
}

- (void)historyForChat:(int64_t)chatId
       aroundMessageId:(int64_t)messageId
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *))completion {
	[[TGMessageStore shared] historyForChat:chatId aroundMessageId:messageId limit:limit completion:completion];
}

- (void)newerHistoryForChat:(int64_t)chatId
              fromMessageId:(int64_t)fromMessageId
                      limit:(NSInteger)limit
                 completion:(void (^)(NSArray *))completion {
	[[TGMessageStore shared] newerHistoryForChat:chatId fromMessageId:fromMessageId limit:limit completion:completion];
}

- (void)historyForChat:(int64_t)chatId
         fromMessageId:(int64_t)fromMessageId
                offset:(NSInteger)offset
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *))completion {
	// getChatHistory returns only what TDLib already holds, and picks the
	// batch size itself - a first call on a cold chat often answers with one
	// message. Walk backwards (or forwards if offset < 0) until we have enough.
	NSMutableArray *collected = [NSMutableArray array];
	[self fetchHistoryChunkForChat:chatId
					 fromMessageId:fromMessageId
							offset:offset
							 limit:limit
						 collected:collected
						completion:completion];
}

- (void)fetchHistoryChunkForChat:(int64_t)chatId
                   fromMessageId:(int64_t)fromMessageId
                          offset:(NSInteger)offset
                           limit:(NSInteger)limit
                       collected:(NSMutableArray *)collected
                      completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type"           : @"getChatHistory",
		@"chat_id"         : @(chatId),
		@"from_message_id" : @(fromMessageId),
		@"offset"          : @(offset),
		@"limit"           : @(limit),
		@"only_local"      : @NO,
	} completion:^(NSDictionary *result){
		TGClient *me = weakSelf;
		NSArray *msgs = result[@"messages"];

		if (!me || ![msgs isKindOfClass:NSArray.class] || msgs.count == 0){
			// End of the chat, or an error - hand back what we have, oldest
			// first, which is the order a chat view wants.
			if (completion)
				completion([[collected reverseObjectEnumerator] allObjects]);
			return;
		}

		for (NSDictionary *m in msgs)
			[collected addObject:TGFlattenMessage(m)];

		if (offset < 0){
			// Fetching newer messages: TDLib returns messages newest first.
			// Reverse them so they are in chronological order (oldest first).
			if (completion)
				completion([[collected reverseObjectEnumerator] allObjects]);
			return;
		}

		int64_t oldest = [[msgs lastObject][@"id"] longLongValue];
		if ((NSInteger)collected.count >= limit || oldest == 0){
			if (completion)
				completion([[collected reverseObjectEnumerator] allObjects]);
			return;
		}

		[me fetchHistoryChunkForChat:chatId
					   fromMessageId:oldest
							  offset:0
							   limit:limit - collected.count
						   collected:collected
						  completion:completion];
	}];
}

- (void)sendText:(NSString *)text toChat:(int64_t)chatId {
	[self sendText:text toChat:chatId thread:0];
}

- (void)sendText:(NSString *)text toChat:(int64_t)chatId thread:(int64_t)threadId {
	[self sendText:text toChat:chatId thread:threadId replyTo:0];
}

- (void)sendText:(NSString *)text toChat:(int64_t)chatId
          thread:(int64_t)threadId replyTo:(int64_t)replyToId {
	NSMutableDictionary *request = [@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"message_thread_id"    : @(threadId),
		@"input_message_content": @{
			@"@type" : @"inputMessageText",
			// The markup the user typed is read here rather than sent as
			// literal asterisks.
			@"text"  : TGFormattedText(text),
		},
	} mutableCopy];

	if (replyToId != 0)
		request[@"reply_to"] = @{@"@type" : @"inputMessageReplyToMessage",
								 @"message_id" : @(replyToId)};

	[self send:request];
}

/// The same send held back: at a date, or the moment the other side is next
/// online. TDLib carries it as a scheduling state on the request itself, and
/// echoes back a message that is pending rather than sent.
- (void)sendText:(NSString *)text toChat:(int64_t)chatId
           thread:(int64_t)threadId replyTo:(int64_t)replyToId
        scheduled:(NSDictionary *)schedulingState {
	[self sendText:text toChat:chatId thread:threadId replyTo:replyToId
		 scheduled:schedulingState completion:nil];
}

- (void)sendText:(NSString *)text toChat:(int64_t)chatId
           thread:(int64_t)threadId replyTo:(int64_t)replyToId
        scheduled:(NSDictionary *)schedulingState
      completion:(void (^)(NSDictionary *message))completion {
	NSMutableDictionary *request = [@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"message_thread_id"    : @(threadId),
		@"input_message_content": @{
			@"@type" : @"inputMessageText",
			@"text"  : @{@"@type" : @"formattedText", @"text" : text ?: @""},
		},
	} mutableCopy];

	if (replyToId != 0)
		request[@"reply_to"] = @{@"@type" : @"inputMessageReplyToMessage",
								 @"message_id" : @(replyToId)};
	if (schedulingState[@"@type"])
		request[@"scheduling_state"] = schedulingState;

	if (!completion){
		[self send:request];
		return;
	}
	[self request:request completion:^(NSDictionary *result){
		completion([result[@"@type"] isEqualToString:@"message"] ? result : nil);
	}];
}

/// At a wall-clock date. The date is int32 seconds, which is what the
/// request carries.
+ (NSDictionary *)scheduledAtDate:(NSTimeInterval)date {
	return @{@"@type"     : @"messageSchedulingStateSendAtDate",
			 @"send_date" : @(date),
			 @"repeat_period" : @(0)};
}

/// The moment the other side is next seen. Private chats only; TDLib
/// refuses it anywhere else, and the error is the answer.
+ (NSDictionary *)scheduledWhenOnline {
	return @{@"@type" : @"messageSchedulingStateSendWhenOnline"};
}

/// What a chat has waiting. The answer is a message list flattened exactly
/// as the history is, so the same rows draw from both.
- (void)scheduledMessagesInChat:(int64_t)chatId
					 completion:(void (^)(NSArray *messages))completion {
	[self request:@{@"@type" : @"getChatScheduledMessages", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *m in result[@"messages"]){
			NSDictionary *flat = TGFlattenMessage(m);
			if (flat)
				[out addObject:flat];
		}
		if (completion) completion(out);
	}];
}

/// A scheduling state can change while there is nothing to send yet: null
/// sends it now - TDLib's own meaning of the field - and a state moves it.
- (void)setSchedulingState:(NSDictionary *)state
			 forMessage:(int64_t)messageId
					inChat:(int64_t)chatId
				completion:(void (^)(BOOL ok))completion {
	[[TGSendStore shared] setSchedulingState:state forMessage:messageId inChat:chatId completion:completion];
}

- (void)forwardMessages:(NSArray *)messageIds
               fromChat:(int64_t)fromChatId
                 toChat:(int64_t)toChatId {
	[[TGMessageStore shared] forwardMessages:messageIds fromChat:fromChatId toChat:toChatId];
}

- (NSDictionary *)markdownParsed:(NSDictionary *)formattedText {
	if (![formattedText isKindOfClass:[NSDictionary class]])
		return formattedText;
	NSDictionary *parsed = [self executeSynchronously:@{
		@"@type" : @"parseMarkdown",
		@"text"  : formattedText,
	}];
	if ([parsed isKindOfClass:[NSDictionary class]] && [parsed[@"@type"] isEqualToString:@"formattedText"])
		return parsed;
	return formattedText;
}

- (NSDictionary *)markdownForEditing:(NSDictionary *)formattedText {
	if (![formattedText isKindOfClass:[NSDictionary class]])
		return formattedText;
	NSDictionary *result = [self executeSynchronously:@{
		@"@type" : @"getMarkdownText",
		@"text"  : formattedText,
	}];
	if ([result isKindOfClass:[NSDictionary class]] && [result[@"@type"] isEqualToString:@"formattedText"])
		return result;
	return formattedText;
}

- (void)sendFormattedText:(NSDictionary *)formattedText toChat:(int64_t)chatId
				   thread:(int64_t)threadId replyTo:(int64_t)replyToId {
	[self sendFormattedText:formattedText toChat:chatId thread:threadId
					replyTo:replyToId schedulingState:nil completion:nil];
}

- (void)sendFormattedText:(NSDictionary *)formattedText toChat:(int64_t)chatId
				   thread:(int64_t)threadId replyTo:(int64_t)replyToId
		  schedulingState:(NSDictionary *)schedulingState
			   completion:(void (^)(NSDictionary *message))completion {
	NSDictionary *empty = @{@"@type" : @"formattedText", @"text" : @"", @"entities" : @[]};
	NSDictionary *textPayload = [formattedText isKindOfClass:[NSDictionary class]] ? formattedText : empty;

	NSMutableDictionary *request = [@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"message_thread_id"    : @(threadId),
		@"input_message_content": @{
			@"@type" : @"inputMessageText",
			@"text"  : textPayload,
		},
	} mutableCopy];

	if (replyToId != 0)
		request[@"reply_to"] = @{@"@type" : @"inputMessageReplyToMessage",
								 @"message_id" : @(replyToId)};
	if (schedulingState[@"@type"])
		request[@"scheduling_state"] = schedulingState;

	if (!completion){
		[self send:request];
		return;
	}
	[self request:request completion:^(NSDictionary *result){
		completion([result[@"@type"] isEqualToString:@"message"] ? result : nil);
	}];
}

- (void)editMessage:(int64_t)messageId inChat:(int64_t)chatId formattedText:(NSDictionary *)formattedText {
	NSDictionary *empty = @{@"@type" : @"formattedText", @"text" : @"", @"entities" : @[]};
	NSDictionary *textPayload = [formattedText isKindOfClass:[NSDictionary class]] ? formattedText : empty;

	[self send:@{
		@"@type"                : @"editMessageText",
		@"chat_id"              : @(chatId),
		@"message_id"           : @(messageId),
		@"input_message_content": @{
			@"@type" : @"inputMessageText",
			@"text"  : textPayload,
		},
	}];
}

- (void)editMessage:(int64_t)messageId inChat:(int64_t)chatId text:(NSString *)text {
	[self send:@{
		@"@type"                : @"editMessageText",
		@"chat_id"              : @(chatId),
		@"message_id"           : @(messageId),
		@"input_message_content": @{
			@"@type" : @"inputMessageText",
			@"text"  : TGFormattedText(text),
		},
	}];
}

/// The caption under a picture, a video or a file. A separate request from
/// editing text, which is why only text could be edited before.
- (void)editCaption:(NSString *)caption
		  ofMessage:(int64_t)messageId
			 inChat:(int64_t)chatId
		 completion:(void (^)(BOOL ok))completion {
	[[TGMessageStore shared] editCaption:caption ofMessage:messageId
								  inChat:chatId completion:completion];
}

/// Replaces the picture itself, keeping the message where it is in the
/// history. The caption travels with it: editMessageMedia takes the whole
/// content, so leaving the caption out would clear it.
- (void)editPhotoAtPath:(NSString *)path
				caption:(NSString *)caption
			  ofMessage:(int64_t)messageId
				 inChat:(int64_t)chatId
			 completion:(void (^)(BOOL ok))completion {
	[[TGMessageStore shared] editPhotoAtPath:path caption:caption ofMessage:messageId inChat:chatId completion:completion];
}

/// Several pictures as one message. Their own client sends up to ten; the
/// album is one request, so the pictures arrive together rather than as a
/// run of separate messages that happen to be next to each other.
///
/// Only the first picture carries the caption - TDLib refuses an album where
/// more than one does.
- (void)sendPhotoAlbumAtPaths:(NSArray *)paths
					  caption:(NSString *)caption
					   toChat:(int64_t)chatId
					   thread:(int64_t)threadId {
	[[TGSendStore shared] sendPhotoAlbumAtPaths:paths caption:caption
										 toChat:chatId thread:threadId];
}

- (void)messageWithId:(int64_t)messageId
               inChat:(int64_t)chatId
           completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getMessage",
					@"chat_id" : @(chatId),
					@"message_id" : @(messageId)}
	   completion:^(NSDictionary *m){
		if (completion)
			completion([m[@"@type"] isEqualToString:@"message"]
					? TGFlattenMessage(m) : nil);
	}];
}

- (void)recentStickersWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getRecentStickers", @"is_attached" : @NO}
	   completion:^(NSDictionary *result){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *sticker in result[@"stickers"]){
			NSDictionary *info = TGStickerInfo(sticker);
			if (info)
				[out addObject:info];
		}
		if (completion) completion(out);
	}];
}

- (void)sendStickerWithFileId:(NSInteger)fileId toChat:(int64_t)chatId thread:(int64_t)threadId {
	[[TGSendStore shared] sendStickerWithFileId:fileId toChat:chatId thread:threadId];
}

- (void)sendVoiceAtPath:(NSString *)path duration:(NSInteger)seconds
                 toChat:(int64_t)chatId thread:(int64_t)threadId {
	[self sendVoiceAtPath:path duration:seconds toChat:chatId thread:threadId
				 viewOnce:NO];
}

- (void)sendVoiceAtPath:(NSString *)path duration:(NSInteger)seconds
				 toChat:(int64_t)chatId thread:(int64_t)threadId
			   viewOnce:(BOOL)viewOnce {
	[self sendVoiceAtPath:path duration:seconds toChat:chatId thread:threadId
				 viewOnce:viewOnce progress:nil accepted:nil completion:nil];
}

- (void)sendVoiceAtPath:(NSString *)path duration:(NSInteger)seconds
				 toChat:(int64_t)chatId thread:(int64_t)threadId
			   viewOnce:(BOOL)viewOnce
			   progress:(void (^)(CGFloat))progress
			   accepted:(void (^)(int64_t))accepted
			 completion:(void (^)(BOOL))completion {
	[[TGSendStore shared] sendVoiceAtPath:path duration:seconds toChat:chatId thread:threadId viewOnce:viewOnce progress:progress accepted:accepted completion:completion];
}

- (void)sendVideoNoteAtPath:(NSString *)path duration:(NSInteger)seconds
					 length:(NSInteger)length
					 toChat:(int64_t)chatId thread:(int64_t)threadId
				   viewOnce:(BOOL)viewOnce {
	// The fire-and-forget shape the older callers and their tests use.
	[self sendVideoNoteAtPath:path duration:seconds length:length toChat:chatId
					   thread:threadId viewOnce:viewOnce progress:nil completion:nil];
}

- (void)sendVideoNoteAtPath:(NSString *)path duration:(NSInteger)seconds
					 length:(NSInteger)length
					 toChat:(int64_t)chatId thread:(int64_t)threadId
				   viewOnce:(BOOL)viewOnce
				   progress:(void (^)(CGFloat))progress
				 completion:(void (^)(BOOL))completion {
	[self sendVideoNoteAtPath:path duration:seconds length:length toChat:chatId
					   thread:threadId viewOnce:viewOnce thumbnail:nil
					 progress:progress accepted:nil completion:completion];
}

- (void)sendVideoNoteAtPath:(NSString *)path duration:(NSInteger)seconds
					 length:(NSInteger)length
					 toChat:(int64_t)chatId thread:(int64_t)threadId
				   viewOnce:(BOOL)viewOnce
				thumbnail:(NSString *)thumbnailPath
				   progress:(void (^)(CGFloat))progress
				   accepted:(void (^)(int64_t))accepted
				 completion:(void (^)(BOOL))completion {
	[[TGSendStore shared] sendVideoNoteAtPath:path duration:seconds length:length toChat:chatId thread:threadId viewOnce:viewOnce thumbnail:thumbnailPath progress:progress accepted:accepted completion:completion];
}

- (void)cancelSendingMessage:(int64_t)messageId inChat:(int64_t)chatId {
	[[TGSendStore shared] cancelSendingMessage:messageId inChat:chatId];
}

- (void)sendVideoAtPath:(NSString *)path toChat:(int64_t)chatId {
	[self sendVideoAtPath:path viewOnce:NO toChat:chatId];
}

- (void)sendVideoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce toChat:(int64_t)chatId {
	[[TGSendStore shared] sendVideoAtPath:path viewOnce:viewOnce toChat:chatId];
}

- (void)sendLocation:(double)latitude longitude:(double)longitude toChat:(int64_t)chatId {
	[[TGSendStore shared] sendLocation:latitude longitude:longitude toChat:chatId];
}

/// A place that keeps changing, for `seconds` more. The send is answered
/// with the message itself, whose id is what every later edit answers
/// through - the one misstep here is a fire-and-forget send, which leaves
/// the live location orphaned, editable by nobody.
- (void)sendLiveLocation:(NSInteger)seconds
			latitude:(double)latitude
			longitude:(double)longitude
				  toChat:(int64_t)chatId
			 completion:(void (^)(int64_t messageId))completion {
	[[TGSendStore shared] sendLiveLocation:seconds latitude:latitude
								  longitude:longitude toChat:chatId
								 completion:completion];
}

/// The moving pin, moved again, for `seconds` more of its period - and 0 is
/// the stop that takes it off the map. Without the id the edit is refused,
/// because a pin nobody can move is a lie on the map.
- (void)editLiveLocationOfMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
						 latitude:(double)latitude
						longitude:(double)longitude
					   livePeriod:(NSInteger)seconds
					   completion:(void (^)(BOOL ok))completion {
	[[TGMessageStore shared] editLiveLocationOfMessage:messageId inChat:chatId latitude:latitude longitude:longitude livePeriod:seconds completion:completion];
}

- (void)sendContactNamed:(NSString *)name phone:(NSString *)phone toChat:(int64_t)chatId {
	[[TGSendStore shared] sendContactNamed:name phone:phone toChat:chatId];
}

- (void)sendPhotoAtPath:(NSString *)path toChat:(int64_t)chatId {
	[self sendPhotoAtPath:path viewOnce:NO toChat:chatId];
}

- (void)sendPhotoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce toChat:(int64_t)chatId {
	[[TGSendStore shared] sendPhotoAtPath:path viewOnce:viewOnce toChat:chatId];
}

- (void)votePoll:(int64_t)messageId inChat:(int64_t)chatId options:(NSArray *)optionIds {
	[[TGMessageStore shared] votePoll:messageId inChat:chatId options:optionIds];
}

- (void)markChecklistTask:(int64_t)taskId done:(BOOL)done inMessage:(int64_t)messageId chat:(int64_t)chatId {
	[[TGMessageStore shared] markChecklistTask:taskId done:done inMessage:messageId chat:chatId];
}

@end
