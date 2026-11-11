//
// TGClient+Account.h - the client surface for the account and its people: sessions, contacts, blocked users, storage stats.
//
#import "TGClient+Base.h"


@interface TGClient (AccountTwoStep)

/// Two-step verification, written whole: the old password opens the gate, an
/// empty new one removes the password, and the recovery email rides along
/// only when `setEmailAddress` says so.
/// The recovery address a two-step password still points at - which is also
/// TDLib's way of checking a password the user typed.
/// The same read, with the server's refusal kept apart from an empty address.
/// Point the recovery address somewhere else; TDLib confirms the new one by
/// letter, so the answer says the request landed, not that it is live.
@end
