//
// TGMessageStore+History.m - the history requests the Chat owns.
//
// The paging window and the offset math stay in the chat view; this file owns
// the TDLib calls, the forum/thread fallback and the flattening of each page.
//
#import "TGMessageStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+SavedMessages.h"

@implementation TGMessageStore (History)

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
	if ([[TGClient shared] chatIsSavedMessages:chatId]){
		[[TGClient shared] historyForSavedTopic:threadId fromMessageId:0
										  limit:limit completion:completion];
		return;
	}

	// A forum topic has a topic call of its own. A plain supergroup thread
	// has no forum id, so an error falls back to the message-thread call.
	[[TGClient shared] request:@{
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
		[[TGClient shared] request:@{
			@"@type"           : @"getMessageThreadHistory",
			@"chat_id"         : @(chatId),
			@"message_id"      : @(threadId),
			@"from_message_id" : @(0),
			@"offset"          : @(0),
			@"limit"           : @(limit),
		} completion:^(NSDictionary *threadResult){
			NSArray *threadMsgs = threadResult[@"messages"];
			if (![threadMsgs isKindOfClass:NSArray.class]){
				NSLog(@"TGMessageStore: thread history -> %@", threadResult[@"@type"]);
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

- (void)historyForChat:(int64_t)chatId
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *))completion {
	[self historyForChat:chatId fromMessageId:0 limit:limit completion:completion];
}

- (void)historyForChat:(int64_t)chatId
         fromMessageId:(int64_t)fromMessageId
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *))completion {
	[self historyForChat:chatId fromMessageId:fromMessageId offset:0
				   limit:limit completion:completion];
}

- (void)historyForChat:(int64_t)chatId
       aroundMessageId:(int64_t)messageId
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *))completion {
	// Offset 0 starts just before from_message_id and leaves it out, so a jump
	// fetched the page next to its target and then could not find it (B28).
	[self historyForChat:chatId fromMessageId:messageId offset:-(limit / 2)
				   limit:limit completion:completion];
}

- (void)newerHistoryForChat:(int64_t)chatId
              fromMessageId:(int64_t)fromMessageId
                      limit:(NSInteger)limit
                 completion:(void (^)(NSArray *))completion {
	[self historyForChat:chatId fromMessageId:fromMessageId offset:-limit
				   limit:limit completion:completion];
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
	[[TGClient shared] request:@{
		@"@type"           : @"getChatHistory",
		@"chat_id"         : @(chatId),
		@"from_message_id" : @(fromMessageId),
		@"offset"          : @(offset),
		@"limit"           : @(limit),
		@"only_local"      : @NO,
	} completion:^(NSDictionary *result){
		NSArray *msgs = result[@"messages"];

		if (![msgs isKindOfClass:NSArray.class] || msgs.count == 0){
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

		[self fetchHistoryChunkForChat:chatId
						 fromMessageId:oldest
								offset:0
								 limit:limit - collected.count
							 collected:collected
							completion:completion];
	}];
}

@end
