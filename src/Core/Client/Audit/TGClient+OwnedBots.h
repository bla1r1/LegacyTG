#import "TGClient+Base.h"

@interface TGClient (OwnedBots)

/// YES when the cached user record says this account is a bot. The profile
/// uses it to decide whether the Bot Settings row can do anything.
/// Every bot owned by this account, as "id", "name" and "username".
/// Whether a username is free for a new bot or as a secondary name. The
/// answer is a word: "ok", "invalid", "occupied", "purchasable",
/// "tooLong", "tooShort" or "unsupported".
/// Removes an owned bot's photo. A replacement needs an uploaded photo, which
/// is the same static-photo path the profile screen already owns; this call
/// is the null half of setBotProfilePhoto.
/// The owned bot's media previews, as "fileId", "date" and "contentType".
/// Previews for one language plus the languages the bot has for them.
/// Adds a preview from a file already known to TDLib. `video` chooses the
/// video content shape; the duration and cover frame default to a still
/// preview's values when it is NO.
/// Whether an owned bot may change this account's emoji status.
/// An owned bot's verification mark on a user or chat. `kind` is "user" or
/// "chat"; an empty description uses Telegram's default wording.
/// Creates a bot managed by `managerBotId`. Returns the new user row.
/// The user's recently used inline bots.
/// Starts a bot in a chat with the deep-link parameter. Returns the sent
/// message record's id and text, or Telegram's refusal.
/// Whether a bot can be put on the attachment menu and whether it already is.
/// Whether a bot is allowed to message this account. A 404 means it may ask;
/// the error text is Telegram's.
/// Adds one inline result to a saved reply shortcut, for the inline flow the
/// composer already knows how to run.
@end
