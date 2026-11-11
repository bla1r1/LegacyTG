//
 // TGClient+SavedMessages.m - the account's own message housekeeping.
//
 // Welcome messages of a chat, the Saved Messages topics, the profile's
 // purge by date and by sender, and the permission to message a user.
 // This tail grew by accretion; every method here is one thing a user
 // taps in a profile or a topic list.
//
#import "TGClientInternal.h"

@implementation TGClient (SavedMessages)
#pragma mark - welcome messages

/// The welcome messages a supergroup or a channel shows a joiner. The load
/// answers an ok and the rows ride updateChatWelcomeMessages, which the chat
/// row already takes through applyChatUpdate's announcement - so the sheet
/// hears that, not the round trip.
#pragma mark - purge, senders and the saved topics

/// Whether a compose with this user can go through at all: "ok",
/// "paidMessages", "userDeleted" or "userRestrictsNewChats".
/// The admin's whole-range wipe: "clear what was said before date X".
/// Everything that member wrote in this chat, on every device.
/// Saved Messages topics are asked for and then ride the update of their
/// own name, which the dispatch keeps.
- (void)loadSavedMessagesTopics {
	[self request:@{@"@type" : @"loadSavedMessagesTopics", @"limit" : @(100)}
		 completion:nil];
}

- (void)labelSavedTag:(NSDictionary *)tag label:(NSString *)label {
	if (!tag)
		return;
	// The row from getSavedMessagesTags wraps the ReactionType under "tag";
	// a bare type is taken as-is so both shapes label the same tag.
	NSDictionary *type = [tag[@"tag"] isKindOfClass:NSDictionary.class]
			? tag[@"tag"] : tag;
	[self request:@{@"@type" : @"setSavedMessagesTagLabel",
					@"tag"   : type,
					@"label" : label ?: @""}
		 completion:nil];
}

- (void)toggleSavedTopicPinned:(int64_t)topicId pinned:(BOOL)pinned {
	[self request:@{@"@type"    : @"toggleSavedMessagesTopicIsPinned",
					@"saved_messages_topic_id" : @(topicId),
					@"is_pinned"               : @(pinned)}
		 completion:nil];
}

- (void)setPinnedSavedTopics:(NSArray *)topicIds {
	[self request:@{@"@type" : @"setPinnedSavedMessagesTopics",
					@"saved_messages_topic_ids" : topicIds ?: @[]}
		 completion:nil];
}

- (void)savedTopicsTags:(int64_t)topicId
			 completion:(void (^)(NSArray *tags))completion {
	[self request:@{@"@type" : @"getSavedMessagesTags",
					@"saved_messages_topic_id" : @(topicId)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"savedMessagesTags"]){
			completion(nil);
			return;
		}
		completion(result[@"tags"]);
	}];
}

- (void)searchSavedMessagesInTopic:(int64_t)topicId
							 query:(NSString *)query
							 tag:(NSDictionary *)tag
							  from:(int64_t)fromMessageId
					completion:(void (^)(NSArray *found, int64_t next))completion {
	[self request:@{
			@"@type"   : @"searchSavedMessages",
			@"saved_messages_topic_id" : @(topicId),
			@"tag"     : tag ?: [NSNull null],
			@"query"   : query ?: @"",
			@"from_message_id" : @(fromMessageId),
			@"offset"  : @(0),
			@"limit"   : @(50),
		} completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"foundChatMessages"]){
			completion(nil, 0);
			return;
		}
		id nextId = result[@"next_from_message_id"];
		NSString *next = [nextId isKindOfClass:NSString.class] ? nextId : nil;
		completion(result[@"messages"],
				   [next isKindOfClass:NSString.class] ? [next longLongValue] : 0);
	}];
}

- (void)clearSavedTopicMessagesBefore:(int64_t)topicId
							 minDate:(NSInteger)minDate
							 maxDate:(NSInteger)maxDate {
	[self request:@{@"@type" : @"deleteSavedMessagesTopicMessagesByDate",
					@"saved_messages_topic_id" : @(topicId),
					@"min_date" : @(minDate),
					@"max_date" : @(maxDate)}
		 completion:nil];
}

- (void)savedTopicMessageAtDate:(int64_t)topicId
						   date:(NSInteger)date
					 completion:(void (^)(NSDictionary *message))completion {
	[self request:@{@"@type" : @"getSavedMessagesTopicMessageByDate",
					@"saved_messages_topic_id" : @(topicId),
					@"date" : @(date)}
	   completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"@type"] isEqualToString:@"message"] ? result : nil);
	}];
}

/// A Saved Messages topic's history has its own call; getChatHistory with a
/// thread id does not know what a saved topic is.
- (void)historyForSavedTopic:(int64_t)topicId
			   fromMessageId:(int64_t)fromMessageId
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *messages))completion {
	[self request:@{@"@type" : @"getSavedMessagesTopicHistory",
					@"saved_messages_topic_id" : @(topicId),
					@"from_message_id" : @(fromMessageId),
					@"offset" : @(0),
					@"limit" : @(limit)}
	   completion:^(NSDictionary *result){
		NSArray *msgs = result[@"messages"];
		if (![msgs isKindOfClass:NSArray.class]){
			if (completion) completion(@[]);
			return;
		}
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:msgs.count];
		for (NSDictionary *m in [[msgs reverseObjectEnumerator] allObjects])
			[out addObject:TGFlattenMessage(m)];
		if (completion) completion(out);
	}];
}

/// Everything in a Saved Messages topic goes. The range calls cover a day;
/// this is the topic itself, which is what "empty it" means.
- (void)deleteSavedTopicHistory:(int64_t)topicId {
	[self send:@{@"@type" : @"deleteSavedMessagesTopicHistory",
				 @"saved_messages_topic_id" : @(topicId)}];
}

@end
