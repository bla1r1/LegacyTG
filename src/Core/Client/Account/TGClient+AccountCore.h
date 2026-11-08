//
// TGClient+Account.h - the client surface for the account and its people: sessions, contacts, blocked users, storage stats.
//
#import "TGClient+Base.h"


@interface TGClient (AccountCore)

/// "online", "last seen recently", "last seen at 12:30" - what a private chat
/// shows under the name. Nil for anything that is not a user.
- (void)statusForUser:(int64_t)userId completion:(void (^)(NSString *status))completion;
/// Chat id of Saved Messages, which is the signed-in user's own chat.
- (int64_t)savedMessagesChatId;
/// YES once getMe has named the active account. The dev contacts are a
/// signed-out fixture; a real account with no contacts must see its empty state.
- (BOOL)hasSignedInAccount;
/// Profile photo file id for a user, or nil if TDLib has not sent one.
- (NSNumber *)photoFileIdForUserId:(int64_t)userId;
/// The same id, asking Telegram when the user record is not cached yet. A
/// member list only carries ids and names, so every face there starts here;
/// the answer is kept in the same map photoFileIdForUserId reads.
- (void)profilePhotoFileIdForUser:(int64_t)userId
                       completion:(void (^)(NSNumber *fileId))completion;
/// Everything a profile shows that the plain user record does not carry:
/// "bio", "commonGroups" (NSNumber), "birthday" (NSString, empty when unset),
/// "canCall" and "canVideoCall" (NSNumber BOOL).
- (void)userProfile:(int64_t)userId completion:(void (^)(NSDictionary *info))completion;
/// Other devices signed into this account: "id", "name", "platform", "ip",
/// "isCurrent", "isUnconfirmed", "acceptSecretChats", "canAcceptCalls",
/// "lastActive".
- (void)sessionsWithCompletion:(void (^)(NSArray *sessions))completion;
/// The same list plus the idle timeout Telegram stores for the account.
- (void)sessionsWithInactiveTtlCompletion:(void (^)(NSArray *sessions,
												  NSInteger ttlDays))completion;
- (void)terminateSession:(long long)sessionId;
/// Confirms a login Telegram flagged as unconfirmed, which is what the
/// updateUnconfirmedSession row in Devices is for.
- (void)confirmSession:(long long)sessionId;
/// A device that should not ring can be told so without signing it out.
- (void)toggleSession:(long long)sessionId
	   canAcceptCalls:(BOOL)canAccept
		   completion:(void (^)(BOOL ok, NSString *error))completion;
/// How many idle days a session gets before it is signed out, 1-366. The
/// screen re-reads the list because the server owns the stored value.
- (void)setInactiveSessionTtlDays:(NSInteger)days
					   completion:(void (^)(BOOL ok, NSString *error))completion;
/// Change the signed-in user's own name and bio. The completion answers so the
/// edit form can stay put and report a refusal instead of popping optimistically.
- (void)setName:(NSString *)firstName
			last:(NSString *)lastName
	  completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)setBio:(NSString *)bio
	completion:(void (^)(BOOL ok, NSString *error))completion;
/// The server's limit for a bio, in characters, read with getOption. 0 means
/// the answer has not arrived; the form hides the count then.
- (void)bioLengthMaxWithCompletion:(void (^)(NSInteger maxLength))completion;
- (void)setUsername:(NSString *)username completion:(void (^)(BOOL ok))completion;

@end
