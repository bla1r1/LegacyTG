#import "TGClient+Messages.h"
#import "TGClient+MessagesInternal.h"
#import "TGClientInternal.h"

@implementation TGClient (Messages)

#pragma mark - messages

- (void)historyForChat:(int64_t)chatId
                thread:(int64_t)threadId
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *))completion {
	if (threadId == 0){
		[self historyForChat:chatId limit:limit completion:completion];
		return;
	}

	// A Saved Messages topic is not a message thread; TDLib keeps its own
	// history call for it, and the thread call answers nothing there.
	if ([self chatIsSavedMessages:chatId]){
		[self historyForSavedTopic:threadId fromMessageId:0 limit:limit
						completion:completion];
		return;
	}

	// A forum topic has a topic call of its own. A plain supergroup thread
	// has no forum id, so an error falls back to the message-thread call
	// the chat used before.
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type"           : @"getForumTopicHistory",
		@"chat_id"         : @(chatId),
		@"forum_topic_id"  : @(threadId),
		@"from_message_id" : @(0),
		@"offset"          : @(0),
		@"limit"           : @(limit),
	} completion:^(NSDictionary *result){
		NSArray *msgs = result[@"messages"];
		if ([msgs isKindOfClass:NSArray.class]){
			NSMutableArray *out = [NSMutableArray arrayWithCapacity:msgs.count];
			for (NSDictionary *m in [[msgs reverseObjectEnumerator] allObjects])
				[out addObject:TGFlattenMessage(m)];
			if (completion) completion(out);
			return;
		}
		[weakSelf request:@{
			@"@type"           : @"getMessageThreadHistory",
			@"chat_id"         : @(chatId),
			@"message_id"      : @(threadId),
			@"from_message_id" : @(0),
			@"offset"          : @(0),
			@"limit"           : @(limit),
		} completion:^(NSDictionary *threadResult){
			NSArray *threadMsgs = threadResult[@"messages"];
			if (![threadMsgs isKindOfClass:NSArray.class]){
				NSLog(@"TGClient: thread history -> %@", threadResult[@"@type"]);
				if (completion) completion(@[]);
				return;
			}
			NSMutableArray *out = [NSMutableArray arrayWithCapacity:threadMsgs.count];
			for (NSDictionary *m in [[threadMsgs reverseObjectEnumerator] allObjects])
				[out addObject:TGFlattenMessage(m)];
			if (completion) completion(out);
		}];
	}];
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
		completion(url.length ? url : nil, url.length ? nil : (result[@"message"] ?: @"Telegram refused that."));
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
	[self historyForChat:chatId fromMessageId:fromMessageId offset:0 limit:limit completion:completion];
}

- (void)historyForChat:(int64_t)chatId
       aroundMessageId:(int64_t)messageId
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *))completion {
	// Offset 0 starts just before from_message_id and leaves it out, so a jump
	// fetched the page next to its target and then could not find it (B28).
	[self historyForChat:chatId fromMessageId:messageId offset:-(limit / 2) limit:limit
			  completion:completion];
}

- (void)newerHistoryForChat:(int64_t)chatId
              fromMessageId:(int64_t)fromMessageId
                      limit:(NSInteger)limit
                 completion:(void (^)(NSArray *))completion {
	[self historyForChat:chatId fromMessageId:fromMessageId offset:-limit limit:limit completion:completion];
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

	[self send:request];
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
	// An optional object reads back as the JSON null TDLib documents for
	// "send immediately", which is not a dictionary.
	id value = state[@"@type"] ? state : [NSNull null];
	[self request:@{
		@"@type"            : @"editMessageSchedulingState",
		@"chat_id"          : @(chatId),
		@"message_id"       : @(messageId),
		@"scheduling_state" : value,
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)forwardMessages:(NSArray *)messageIds
               fromChat:(int64_t)fromChatId
                 toChat:(int64_t)toChatId {
	[self send:@{
		@"@type"        : @"forwardMessages",
		@"chat_id"      : @(toChatId),
		@"from_chat_id" : @(fromChatId),
		@"message_ids"  : messageIds ?: @[],
	}];
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

	[self send:request];
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
	[self request:@{
		@"@type"      : @"editMessageCaption",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"caption"    : TGFormattedText(caption),
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

/// Replaces the picture itself, keeping the message where it is in the
/// history. The caption travels with it: editMessageMedia takes the whole
/// content, so leaving the caption out would clear it.
- (void)editPhotoAtPath:(NSString *)path
				caption:(NSString *)caption
			  ofMessage:(int64_t)messageId
				 inChat:(int64_t)chatId
			 completion:(void (^)(BOOL ok))completion {
	if (!path.length){
		if (completion) completion(NO);
		return;
	}
	[self request:@{
		@"@type"      : @"editMessageMedia",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		// No keyboard of its own; the one the message had is not ours to
		// rebuild from here, and an empty one is the honest answer.
		@"reply_markup" : @{@"@type" : @"replyMarkupInlineKeyboard",
							@"rows" : @[]},
		@"input_message_content": @{
			@"@type"   : @"inputMessagePhoto",
			@"photo"   : @{@"@type" : @"inputFileLocal", @"path" : path},
			@"caption" : TGFormattedText(caption),
		},
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
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
	[self send:@{
		@"@type"                  : @"sendMessageAlbum",
		@"chat_id"                : @(chatId),
		@"message_thread_id"      : @(threadId),
		@"input_message_contents" : contents,
	}];
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
	[self send:@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"message_thread_id"    : @(threadId),
		// This TDLib nests the file one level down: inputMessageSticker takes
		// an inputSticker, which is what carries the InputFile. Handing it the
		// InputFile directly answers "InputFile is not specified".
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
	[self send:@{@"@type"       : @"addRecentSticker",
				 @"is_attached" : @NO,
				 @"sticker"     : @{@"@type" : @"inputFileId", @"id" : @(fileId)}}];
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
	if (!path.length){
		if (completion)
			completion(NO);
		return;
	}

	NSDictionary *attributes = [[NSFileManager defaultManager]
			attributesOfItemAtPath:path error:nil];
	NSLog(@"TGClient: sending voice %@ (%llu bytes, %lds, once %d) to %lld",
			path.lastPathComponent, [attributes fileSize], (long)seconds,
			viewOnce, chatId);

	// The one-time mode is written the way their clients do it: a timer of
	// 0x7fffffff, whose whole meaning is "gone the moment it is opened".
	id destruct = viewOnce
			? @{@"@type" : @"messageSelfDestructTypeImmediately"}
			: [NSNull null];

	// Answered rather than fire-and-forget: a rejected voice note is silent
	// otherwise, and the file it points at lives in a temporary directory.
	[self request:@{
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
			NSLog(@"TGClient: voice rejected: %@ %@",
					result[@"code"], result[@"message"]);
			if (completion)
				completion(NO);
			return;
		}
		NSLog(@"TGClient: voice accepted, message %@", result[@"id"]);
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
		[self registerSendWaiterForMessage:messageId
									fileId:(voice ? [voice[@"id"] integerValue] : 0)
								  progress:progress completion:completion];
	}];
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
	[self request:@{
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
			NSLog(@"TGClient: video note rejected: %@ %@",
					result[@"code"], result[@"message"]);
			if (completion)
				completion(NO);
			return;
		}
		NSLog(@"TGClient: video note accepted, message %@", result[@"id"]);
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
		[self registerSendWaiterForMessage:messageId
									fileId:(video ? [video[@"id"] integerValue] : 0)
								  progress:progress completion:completion];
	}];
}

- (void)cancelSendingMessage:(int64_t)messageId inChat:(int64_t)chatId {
	if (!messageId)
		return;
	[self deleteMessages:@[@(messageId)] inChat:chatId revoke:YES];
	// Nothing is left to wait for: the person took the message back, so the
	// waiter answers YES and the chat can drop its sending row.
	[self noteSendFinished:messageId sent:YES];
}

- (void)sendVideoAtPath:(NSString *)path toChat:(int64_t)chatId {
	[self sendVideoAtPath:path viewOnce:NO toChat:chatId];
}

- (void)sendVideoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce toChat:(int64_t)chatId {
	if (!path.length)
		return;
	id destruct = viewOnce
			? @{@"@type" : @"messageSelfDestructTypeImmediately"}
			: [NSNull null];
	[self send:@{
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

- (void)sendLocation:(double)latitude longitude:(double)longitude toChat:(int64_t)chatId {
	[self send:@{
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

/// A place that keeps changing, for `seconds` more. The send is answered
/// with the message itself, whose id is what every later edit answers
/// through - the one misstep here is a fire-and-forget send, which leaves
/// the live location orphaned, editable by nobody.
- (void)sendLiveLocation:(NSInteger)seconds
			latitude:(double)latitude
			longitude:(double)longitude
				  toChat:(int64_t)chatId
			 completion:(void (^)(int64_t messageId))completion {
	[self request:@{
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

/// The moving pin, moved again, for `seconds` more of its period - and 0 is
/// the stop that takes it off the map. Without the id the edit is refused,
/// because a pin nobody can move is a lie on the map.
- (void)editLiveLocationOfMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
						 latitude:(double)latitude
						longitude:(double)longitude
					   livePeriod:(NSInteger)seconds
					   completion:(void (^)(BOOL ok))completion {
	if (!messageId){
		if (completion) completion(NO);
		return;
	}
	[self request:@{
		@"@type"      : @"editMessageLiveLocation",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"location"   : @{
			@"@type"       : @"liveLocation",
			@"location"    : @{@"@type"     : @"location",
							   @"latitude"  : @(latitude),
							   @"longitude" : @(longitude)},
			@"live_period" : @(seconds),
			@"heading"     : @(0),
			@"proximity_alert_radius" : @(0),
		},
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)sendContactNamed:(NSString *)name phone:(NSString *)phone toChat:(int64_t)chatId {
	if (!phone.length)
		return;
	[self send:@{
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

- (void)sendPhotoAtPath:(NSString *)path toChat:(int64_t)chatId {
	[self sendPhotoAtPath:path viewOnce:NO toChat:chatId];
}

- (void)sendPhotoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce toChat:(int64_t)chatId {
	if (!path.length)
		return;
	id destruct = viewOnce
			? @{@"@type" : @"messageSelfDestructTypeImmediately"}
			: [NSNull null];
	[self send:@{
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

- (void)votePoll:(int64_t)messageId inChat:(int64_t)chatId options:(NSArray *)optionIds {
	[self send:@{
		@"@type"      : @"setPollAnswer",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"option_ids" : optionIds ?: @[],
	}];
}

- (void)markChecklistTask:(int64_t)taskId done:(BOOL)done inMessage:(int64_t)messageId chat:(int64_t)chatId {
	NSArray *one = @[@(taskId)];
	[self send:@{
		@"@type"                      : @"markChecklistTasksAsDone",
		@"chat_id"                    : @(chatId),
		@"message_id"                 : @(messageId),
		@"marked_as_done_task_ids"    : done ? one : @[],
		@"marked_as_not_done_task_ids": done ? @[] : one,
	}];
}

@end
