//
// TGClient+Account.h - the client surface for the account and its people: sessions, contacts, blocked users, storage stats.
//
#import "TGClient+Base.h"


@interface TGClient (AccountReactions)

/// The last reaction notification record Telegram sent. nil until
/// updateReactionNotificationSettings arrives.
@property (nonatomic, readonly) NSDictionary *reactionNotificationSettings;
/// Whether a message reaction may raise a notification. Telegram's default
/// is on; the stored record only turns it off by naming the "none" source.
@property (nonatomic, readonly) BOOL reactionNotificationsEnabled;
/// Turn message-reaction notifications on or off without disturbing the
/// story and poll sources or the chosen sound. Answered so the switch can
/// put itself back if Telegram refuses.
- (void)setReactionNotificationsEnabled:(BOOL)enabled
                             completion:(void (^)(BOOL ok))completion;

@end
