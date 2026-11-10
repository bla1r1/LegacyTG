#import "TGClient+MessageRecord.h"
#import "TGClient+MessagesInternal.h"
#import "TGClientInternal.h"
#import "TGMessageStore.h"

@implementation TGClient (MessageRecord)

#pragma mark - the message as a record

- (void)addLocalTextMessage:(NSString *)text
					 toChat:(int64_t)chatId
				 completion:(void (^)(int64_t messageId))completion {
	if (!text.length){
		if (completion) completion(0);
		return;
	}
	int64_t userId = [self.me[@"id"] longLongValue];
	if (!userId){
		if (completion) completion(0);
		return;
	}
	[self request:@{
		@"@type"                  : @"addLocalMessage",
		@"chat_id"                : @(chatId),
		@"sender_id"              : @{@"@type" : @"messageSenderUser",
									  @"user_id" : @(userId)},
		@"reply_to"               : [NSNull null],
		@"disable_notification"   : @YES,
		@"input_message_content"  : @{@"@type" : @"inputMessageText",
									  @"text" : TGFormattedText(text)},
	} completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"id"] longLongValue]);
	}];
}

- (void)clickAnimatedEmojiMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(void (^)(NSString *emoji))completion {
	[[TGMessageStore shared] clickAnimatedEmojiMessage:messageId inChat:chatId completion:completion];
}

- (void)clearReplyMarkupOfMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(void (^)(BOOL ok))completion {
	[[TGMessageStore shared] clearReplyMarkupOfMessage:messageId inChat:chatId completion:completion];
}

- (void)callbackQueryMessage:(int64_t)messageId
					  inChat:(int64_t)chatId
			 callbackQueryId:(int64_t)callbackQueryId
				  completion:(void (^)(NSDictionary *message))completion {
	[self request:@{
		@"@type"             : @"getCallbackQueryMessage",
		@"chat_id"           : @(chatId),
		@"message_id"        : @(messageId),
		@"callback_query_id" : @(callbackQueryId),
	} completion:^(NSDictionary *result){
		if (!completion)
			return;
		if ([result[@"@type"] isEqualToString:@"message"])
			completion(TGFlattenMessage(result));
		else
			completion(nil);
	}];
}

- (void)localMessageWithId:(int64_t)messageId
					inChat:(int64_t)chatId
				completion:(void (^)(NSDictionary *message))completion {
	[self request:@{
		@"@type"      : @"getMessageLocally",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result){
		if (!completion)
			return;
		if ([result[@"@type"] isEqualToString:@"message"])
			completion(TGFlattenMessage(result));
		else
			completion(nil);
	}];
}

/// The MessageTopic a chat view's threadId names: a Saved Messages topic, a
/// forum topic, or an ordinary message thread. Null when the whole chat is
/// meant, which is what a non-forum chat without a thread passes.
static id TGMessageTopicForThread(TGClient *client, int64_t chatId, int64_t threadId) {
	if (threadId == 0)
		return [NSNull null];
	if ([client chatIsSavedMessages:chatId])
		return @{@"@type" : @"messageTopicSavedMessages",
				 @"saved_messages_topic_id" : @(threadId)};
	if ([client.chatsById[@(chatId)][@"isForum"] boolValue])
		return @{@"@type" : @"messageTopicForum",
				 @"forum_topic_id" : @(threadId)};
	return @{@"@type" : @"messageTopicThread",
			 @"message_thread_id" : @(threadId)};
}

- (void)positionOfMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
				   thread:(int64_t)threadId
			   completion:(void (^)(NSInteger position))completion {
	[self request:@{
		@"@type"      : @"getChatMessagePosition",
		@"chat_id"    : @(chatId),
		@"topic_id"   : TGMessageTopicForThread(self, chatId, threadId),
		@"filter"     : @{@"@type" : @"searchMessagesFilterEmpty"},
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"count"] integerValue]);
	}];
}

- (void)sparsePositionsInChat:(int64_t)chatId
				fromMessageId:(int64_t)fromMessageId
					   thread:(int64_t)threadId
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *messageIds))completion {
	// This call has no MessageTopic field, only a saved-topic id; a forum's
	// positions stay chat-wide because the schema gives no topic filter.
	int64_t savedTopicId = [self chatIsSavedMessages:chatId] ? threadId : 0;
	[self request:@{
		@"@type"                  : @"getChatSparseMessagePositions",
		@"chat_id"                : @(chatId),
		@"filter"                 : @{@"@type" : @"searchMessagesFilterEmpty"},
		@"from_message_id"        : @(fromMessageId),
		@"limit"                  : @(MAX((NSInteger)50, MIN(limit, (NSInteger)2000))),
		@"saved_messages_topic_id": @(savedTopicId),
	} completion:^(NSDictionary *result){
		if (!completion)
			return;
		NSArray *positions = [result[@"positions"] isKindOfClass:NSArray.class]
				? result[@"positions"] : @[];
		completion(positions);
	}];
}

- (void)statisticsOfMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
				 completion:(void (^)(NSDictionary *statistics))completion {
	[[TGMessageStore shared] statisticsOfMessage:messageId inChat:chatId completion:completion];
}

- (void)reportViewOfMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
				timeInViewMs:(NSInteger)timeInViewMs
		  activeTimeInViewMs:(NSInteger)activeTimeInViewMs
				 heightRatio:(NSInteger)heightPerMille
			   seenRangeRatio:(NSInteger)seenPerMille
				 completion:(void (^)(BOOL ok))completion {
	[[TGMessageStore shared] reportViewOfMessage:messageId inChat:chatId timeInViewMs:timeInViewMs activeTimeInViewMs:activeTimeInViewMs heightRatio:heightPerMille seenRangeRatio:seenPerMille completion:completion];
}

- (void)setReactions:(NSArray *)emojis
		   onMessage:(int64_t)messageId
			  inChat:(int64_t)chatId
		  completion:(void (^)(BOOL ok))completion {
	NSMutableArray *types = [NSMutableArray array];
	for (NSString *emoji in emojis)
		if ([emoji isKindOfClass:NSString.class] && emoji.length)
			[types addObject:@{@"@type" : @"reactionTypeEmoji",
							   @"emoji" : emoji}];
	[self request:@{
		@"@type"          : @"setMessageReactions",
		@"chat_id"        : @(chatId),
		@"message_id"     : @(messageId),
		@"reaction_types" : types,
		@"is_big"         : @NO,
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)personalChatHistoryForUser:(int64_t)userId
							 limit:(NSInteger)limit
						completion:(void (^)(NSArray *messages))completion {
	[self request:@{
		@"@type"   : @"getPersonalChatHistory",
		@"user_id" : @(userId),
		@"limit"   : @(MAX((NSInteger)1, MIN(limit, (NSInteger)20))),
	} completion:^(NSDictionary *result){
		NSArray *msgs = result[@"messages"];
		if (![msgs isKindOfClass:NSArray.class]){
			if (completion) completion(@[]);
			return;
		}
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:msgs.count];
		for (NSDictionary *m in msgs)
			[out addObject:TGFlattenMessage(m)];
		if (completion) completion(out);
	}];
}

@end
