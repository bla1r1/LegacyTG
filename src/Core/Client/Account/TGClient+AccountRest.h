//
// TGClient+Account.h - the client surface for the account and its people: sessions, contacts, blocked users, storage stats.
//
#import "TGClient+Base.h"


#ifdef __cplusplus
extern "C" {
#endif
/// A blocked sender's display name from its getUser / getChat answer.
NSString *TGBlockedSenderName(NSDictionary *answer);
/// YES for a deleted account: it stays in Telegram's block list but there is
/// nobody left to unblock, so the list leaves it out.
BOOL TGBlockedSenderIsDeleted(NSDictionary *answer);
#ifdef __cplusplus
}
#endif

@interface TGClient (AccountRest)

- (NSString *)nameForUserId:(int64_t)userId;
/// Full user record: "first_name", "last_name", "usernames", "phone_number".
- (void)userInfo:(int64_t)userId completion:(void (^)(NSDictionary *user))completion;
/// Shared media of a chat. `filter` is a TDLib SearchMessagesFilter type name,
/// e.g. "searchMessagesFilterPhotoAndVideo" or "searchMessagesFilterDocument".
/// Fetch a user TDLib has not volunteered yet, so a group message can be
/// attributed. `completion` runs once the name is cached.
- (void)ensureUserName:(int64_t)userId completion:(void (^)(void))completion;
/// Sign every other device out in one stroke - the sessions screen keeps the
/// per-device version.
/// The code Telegram emails when a recovery address is given. Until it goes
/// through, the old address - or none - is still the one in force.
/// The end of the road: reason is what Telegram's form asks about, the
/// password only when two-step verification is on.
/// Calls this account made or received, newest first: "userId", "chatId",
/// "messageId" (the call record in the history), "name", "outgoing",
/// "missed", "date", "duration".
/// Queries privacy rule value ("everybody", "contacts", "nobody") for setting:
/// "ShowStatus", "ShowProfilePhoto", "AllowCalls", "AllowChatInvites",
/// "ShowLinkInForwardedMessages", "ShowPhoneNumber", "ShowBirthdate".
/// Writes a rule and answers after the server accepts or refuses it. Existing
/// user/exception rules are carried over so changing the catch-all does not
/// erase them.
/// Everyone you have blocked: "id" and "name".
/// Days of inactivity before the account deletes itself.
/// Language packs this account can use: "id" and "name". `current` is the one
/// in use.
@end
