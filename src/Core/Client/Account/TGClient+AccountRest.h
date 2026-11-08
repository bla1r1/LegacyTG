//
// TGClient+Account.h - the client surface for the account and its people: sessions, contacts, blocked users, storage stats.
//
#import "TGClient+Base.h"


@interface TGClient (AccountRest)

- (NSString *)nameForUserId:(int64_t)userId;
/// Full user record: "first_name", "last_name", "usernames", "phone_number".
- (void)userInfo:(int64_t)userId completion:(void (^)(NSDictionary *user))completion;
/// Shared media of a chat. `filter` is a TDLib SearchMessagesFilter type name,
/// e.g. "searchMessagesFilterPhotoAndVideo" or "searchMessagesFilterDocument".
- (void)mediaInChat:(int64_t)chatId filter:(NSString *)filter
         completion:(void (^)(NSArray *messages))completion;
- (void)mediaInChat:(int64_t)chatId filter:(NSString *)filter
      fromMessageId:(int64_t)fromMessageId limit:(NSInteger)limit
         completion:(void (^)(NSArray *messages))completion;
/// Fetch a user TDLib has not volunteered yet, so a group message can be
/// attributed. `completion` runs once the name is cached.
- (void)ensureUserName:(int64_t)userId completion:(void (^)(void))completion;
/// Sign every other device out in one stroke - the sessions screen keeps the
/// per-device version.
- (void)terminateAllOtherSessions:(void (^)(BOOL ok))completion;
/// The code Telegram emails when a recovery address is given. Until it goes
/// through, the old address - or none - is still the one in force.
- (void)checkRecoveryEmailCode:(NSString *)code
					completion:(void (^)(BOOL ok))completion;
- (void)resendRecoveryEmailCode;
/// The end of the road: reason is what Telegram's form asks about, the
/// password only when two-step verification is on.
- (void)deleteAccountWithReason:(NSString *)reason
					   password:(NSString *)password
					 completion:(void (^)(BOOL ok))completion;
/// Calls this account made or received, newest first: "userId", "chatId",
/// "messageId" (the call record in the history), "name", "outgoing",
/// "missed", "date", "duration".
- (void)recentCallsWithCompletion:(void (^)(NSArray *calls))completion;
/// Queries privacy rule value ("everybody", "contacts", "nobody") for setting:
/// "ShowStatus", "ShowProfilePhoto", "AllowCalls", "AllowChatInvites",
/// "ShowLinkInForwardedMessages", "ShowPhoneNumber", "ShowBirthdate".
- (void)privacyRule:(NSString *)setting
         completion:(void (^)(NSString *value))completion;
- (void)privacyRuleDetails:(NSString *)setting
                completion:(void (^)(NSString *ruleType, NSArray *allowUserIds, NSArray *restrictUserIds))completion;
- (void)setPrivacyRule:(NSString *)setting to:(NSString *)value;
/// Writes a rule and answers after the server accepts or refuses it. Existing
/// user/exception rules are carried over so changing the catch-all does not
/// erase them.
- (void)setPrivacyRule:(NSString *)setting to:(NSString *)value
			completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)setPrivacyRule:(NSString *)setting
                  type:(NSString *)ruleType
          allowUserIds:(NSArray *)allowUserIds
       restrictUserIds:(NSArray *)restrictUserIds
            completion:(void (^)(BOOL ok, NSString *error))completion;
/// Everyone you have blocked: "id" and "name".
- (void)blockedUsersWithCompletion:(void (^)(NSArray *users))completion;
/// Days of inactivity before the account deletes itself.
- (void)accountTtlWithCompletion:(void (^)(NSInteger days))completion;
- (void)setAccountTtlDays:(NSInteger)days;
/// Language packs this account can use: "id" and "name". `current` is the one
/// in use.
- (void)languagesWithCompletion:(void (^)(NSArray *languages, NSString *current))completion;
- (void)setLanguage:(NSString *)packId;

@end
