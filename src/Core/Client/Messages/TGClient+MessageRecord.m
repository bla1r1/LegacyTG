#import "TGClient+MessageRecord.h"
#import "TGClient+MessagesInternal.h"
#import "TGClientInternal.h"

@implementation TGClient (MessageRecord)

#pragma mark - the message as a record

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

@end
