#import "TGClient+Base.h"

@interface TGClient (Discovery)

/// Lets a user send this account unpaid messages after they paid before.
- (void)allowUnpaidMessagesFromUser:(int64_t)userId
							 refund:(BOOL)refund
						 completion:(void (^)(BOOL ok, NSString *error))completion;

/// Redeems the token a t.me link carries so one unpaid message can be sent.
- (void)applyUnpaidMessagesToken:(NSString *)token
						  forUser:(int64_t)userId
					   completion:(void (^)(BOOL ok, NSString *error))completion;

/// The senders that may carry a paid reaction in a chat.
- (void)paidReactionSendersForChat:(int64_t)chatId
						completion:(void (^)(NSArray *senders,
											 NSString *error))completion;

/// The Star price a supergroup charges per message, and the same for a live
/// story's call messages.
- (void)setChatPaidMessageStarCount:(int64_t)chatId
							  count:(int32_t)starCount
						 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setGroupCallPaidMessageStarCount:(int32_t)groupCallId
								   count:(int32_t)starCount
							  completion:(void (^)(BOOL ok,
												   NSString *error))completion;

/// Whether one direct-messages topic accepts unpaid messages, with an option
/// to refund the messages already paid for.
- (void)setDirectMessagesTopicUnpaid:(int64_t)chatId
							   topic:(int64_t)topicId
							 allowed:(BOOL)allowed
							  refund:(BOOL)refund
						  completion:(void (^)(BOOL ok, NSString *error))completion;

/// A receipt for a successful payment message.
- (void)paymentReceiptForChat:(int64_t)chatId
					  message:(int64_t)messageId
				   completion:(void (^)(NSDictionary *receipt,
										NSString *error))completion;

/// The Telegram Ads account URL for a channel or bot this account owns.
- (void)starAdAccountURLForOwner:(NSString *)ownerKind
						 ownerId:(int64_t)ownerId
					  completion:(void (^)(NSString *link, NSString *error))completion;

/// The boost count a user needs before slow mode and restrictions stop
/// applying to them, for an owned supergroup.
- (void)setSupergroupUnrestrictBoostCount:(int32_t)count
							  supergroupId:(int64_t)supergroupId
							   completion:(void (^)(BOOL ok,
													NSString *error))completion;

- (void)giveawayInfoForChat:(int64_t)chatId
					message:(int64_t)messageId
				 completion:(void (^)(NSDictionary *info, NSString *error))completion;

- (void)collectibleItemInfoForKind:(NSString *)kind
							 value:(NSString *)value
						completion:(void (^)(NSDictionary *info,
											 NSString *error))completion;

@end
