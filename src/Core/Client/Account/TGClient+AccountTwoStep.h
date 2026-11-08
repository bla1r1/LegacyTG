//
// TGClient+Account.h - the client surface for the account and its people: sessions, contacts, blocked users, storage stats.
//
#import "TGClient+Base.h"


@interface TGClient (AccountTwoStep)

/// Two-step verification, written whole: the old password opens the gate, an
/// empty new one removes the password, and the recovery email rides along
/// only when `setEmailAddress` says so.
- (void)setPassword:(NSString *)oldPassword
								 new:(NSString *)newPassword
							   hint:(NSString *)hint
					setEmailAddress:(BOOL)setEmailAddress
							 email:(NSString *)recoveryEmail
						 completion:(void (^)(BOOL ok))completion;
/// The recovery address a two-step password still points at - which is also
/// TDLib's way of checking a password the user typed.
- (void)recoveryEmailAddress:(NSString *)password
				  completion:(void (^)(NSString *email))completion;
/// Point the recovery address somewhere else; TDLib confirms the new one by
/// letter, so the answer says the request landed, not that it is live.
- (void)setRecoveryEmailAddress:(NSString *)password
							 to:(NSString *)email
					 completion:(void (^)(BOOL ok))completion;

@end
