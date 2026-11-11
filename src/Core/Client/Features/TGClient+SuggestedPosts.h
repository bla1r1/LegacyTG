#import "TGClient+Base.h"

@interface TGClient (SuggestedPosts)

#pragma mark - suggested posts and actions

/// The message's suggested-post record: "price", "sendDate", "state",
/// "canBeApproved" and "canBeDeclined". Nil when the message is not one.
- (void)suggestedPostForMessage:(int64_t)messageId
                         inChat:(int64_t)chatId
                     completion:(void (^)(NSDictionary *post, NSString *error))completion;

- (void)approveSuggestedPost:(int64_t)messageId
                      inChat:(int64_t)chatId
                    sendDate:(NSInteger)sendDate
                  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)declineSuggestedPost:(int64_t)messageId
                      inChat:(int64_t)chatId
                     comment:(NSString *)comment
                  completion:(void (^)(BOOL ok, NSString *error))completion;

/// SuggestedAction objects from updateSuggestedActions. Rows keep Telegram's
/// object under "action" and add a readable "title".
@property (nonatomic, readonly) NSArray *suggestedActions;

@end
