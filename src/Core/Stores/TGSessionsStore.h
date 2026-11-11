//
// TGSessionsStore.h - the other devices signed into this account.
//
// The Devices and Sessions pages name a session and what to do to it; the
// store owns the request shapes (getActiveSessions, terminateSession,
// terminateAllOtherSessions, toggleSessionCanAccept*) and the timeout.
// Nothing about a session is cached here: Telegram is the only list.
//
#import <Foundation/Foundation.h>
#import "TGClientNotifications.h"

@interface TGSessionsStore : NSObject

+ (instancetype)shared;

/// Other devices signed into this account: "id", "name", "platform", "ip",
/// "isCurrent", "isUnconfirmed", "acceptSecretChats", "canAcceptCalls",
/// "lastActive".
- (void)sessionsWithCompletion:(void (^)(NSArray *sessions))completion;

/// The same list plus the idle timeout Telegram stores for the account.
- (void)sessionsWithInactiveTtlCompletion:(void (^)(NSArray *sessions,
												  NSInteger ttlDays))completion;

- (void)terminateSession:(long long)sessionId;

/// Signs out every device except this one.
- (void)terminateAllOtherSessions:(void (^)(BOOL ok))completion;

/// Confirms a login Telegram flagged as unconfirmed, which is what the
/// updateUnconfirmedSession row in Devices is for.
- (void)confirmSession:(long long)sessionId;

/// A device that should not ring can be told so without signing it out.
- (void)toggleSession:(long long)sessionId
	   canAcceptCalls:(BOOL)canAccept
		   completion:(void (^)(BOOL ok, NSString *error))completion;

/// Whether the device may receive secret chats. TDLib answers with an update.
- (void)toggleSession:(int64_t)sessionId canAcceptSecretChats:(BOOL)can;

/// How many idle days a session gets before it is signed out, 1-366. The
/// screen re-reads the list because the server owns the stored value.
- (void)setInactiveSessionTtlDays:(NSInteger)days
					   completion:(void (^)(BOOL ok, NSString *error))completion;

@end
