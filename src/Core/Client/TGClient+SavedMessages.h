//
// TGClient+SavedMessages.h - the client surface for welcome messages and the Saved Messages topics.
//
#import "TGClient+Base.h"

@interface TGClient (SavedMessages)

/// Whether a compose with this user can go through at all: "ok",
/// "paidMessages", "userDeleted" or "userRestrictsNewChats".
- (void)loadSavedMessagesTopics;

- (void)labelSavedTag:(NSDictionary *)tag label:(NSString *)label;

- (void)toggleSavedTopicPinned:(int64_t)topicId pinned:(BOOL)pinned;

- (void)setPinnedSavedTopics:(NSArray *)topicIds;

- (void)savedTopicsTags:(int64_t)topicId
			 completion:(void (^)(NSArray *tags))completion;

- (void)searchSavedMessagesInTopic:(int64_t)topicId
							 query:(NSString *)query
							 tag:(NSDictionary *)tag
							  from:(int64_t)fromMessageId
					completion:(void (^)(NSArray *found, int64_t next))completion;

- (void)clearSavedTopicMessagesBefore:(int64_t)topicId
							 minDate:(NSInteger)minDate
							 maxDate:(NSInteger)maxDate;

- (void)savedTopicMessageAtDate:(int64_t)topicId
						 date:(NSInteger)date
					completion:(void (^)(NSDictionary *message))completion;

/// A Saved Messages topic's messages, oldest first. The chat pushes its
/// threadId through this rather than the message-thread call.
- (void)historyForSavedTopic:(int64_t)topicId
			   fromMessageId:(int64_t)fromMessageId
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *messages))completion;

/// Empties a Saved Messages topic; the topic itself stays.
- (void)deleteSavedTopicHistory:(int64_t)topicId;

@end
