//
// TGClient+Account.h - the client surface for the account and its people: sessions, contacts, blocked users, storage stats.
//
#import "TGClient+Base.h"


@interface TGClient (AccountAutosave)

/// Telegram's gallery autosave settings. "private", "groups" and "channels"
/// each carry "photos", "videos" and "maxVideoSize"; "exceptions" is an array
/// of per-chat overrides with "chatId" and the same three fields.
/// Writes one scope's settings. `scope` is "private", "groups" or "channels".
/// Drops every per-chat exception; the three scope defaults stay.
@end
