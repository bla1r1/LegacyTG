//
// TGClient+Account.h - the client surface for the account and its people: sessions, contacts, blocked users, storage stats.
//
#import "TGClient+Base.h"


@interface TGClient (AccountSettings)

/// Notification settings are kept per scope rather than per chat: private
/// chats, groups and channels each have their own. `scope` is "private",
/// "groups" or "channels"; `muted` is what the switch shows.
/// Whether a scope's notifications carry the message text.
/// Forget every per-chat notification exception, as their reset row does.
@end
