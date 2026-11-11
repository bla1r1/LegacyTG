#import "TGClient+Base.h"

@interface TGClient (Discovery)

/// Lets a user send this account unpaid messages after they paid before.
/// Redeems the token a t.me link carries so one unpaid message can be sent.
/// The senders that may carry a paid reaction in a chat.
/// The Star price a supergroup charges per message, and the same for a live
/// story's call messages.
/// Whether one direct-messages topic accepts unpaid messages, with an option
/// to refund the messages already paid for.
/// A receipt for a successful payment message.
/// The Telegram Ads account URL for a channel or bot this account owns.
/// The boost count a user needs before slow mode and restrictions stop
/// applying to them, for an owned supergroup.
- (void)giveawayInfoForChat:(int64_t)chatId
					message:(int64_t)messageId
				 completion:(void (^)(NSDictionary *info, NSString *error))completion;

@end
