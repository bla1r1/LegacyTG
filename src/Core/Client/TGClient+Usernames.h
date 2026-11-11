//
// TGClient+Usernames.h - the account's usernames, a supergroup's username
// and the switches on the group profile that change what the group is.
//
// The two halves share a shape TDLib names usernames: active, disabled and
// one editable name. An account and a supergroup take the same three requests
// with different ids, so the screens that draw them are cousins too.
//
#import "TGClient+Base.h"

@interface TGClient (Usernames)

#pragma mark - the account

/// The signed-in account's usernames object from getMe: "active_usernames",
/// "disabled_usernames" and "editable_username". Nil when Telegram refuses.
/// Turns one of the account's names on or off. The editable name cannot be
/// switched off, and Telegram says so in `error`.
/// The order of the active names as they are shown on the profile. Every
/// currently active name has to be in `usernames`.
#pragma mark - a supergroup or channel

/// One read of everything the group settings screen draws: the username
/// object, the mode switches from getSupergroup and the two facts that only
/// live in full info (hidden members and the main profile tab). Nil when the
/// chat is not a supergroup or Telegram refuses.
/// The editable username of a supergroup or channel. An empty string removes
/// it; the active names Telegram keeps are left alone.
/// Switches off every active name but the editable one.
/// Forum mode. Turning it off also clears the tabs, which TDLib ignores while
/// is_forum is false. Discussion groups cannot be converted and answer an error.
/// New members need an administrator's approval. `apply_to_invite_links` is
/// sent as YES so the switch means the same thing for existing links.
/// `guardBotUserId` is the bot already guarding the group, or 0; sending 0
/// would quietly remove one that was there.
/// Non-administrators stop being able to list members. Only a group whose
/// full info says can_hide_members accepts it.
/// Converts the group to a broadcast group: members read, administrators post.
/// TDLib has no inverse, so the row asks before sending it.
/// The channel's automatic translation switch. A boost level can be required,
/// and Telegram's refusal carries that reason in `error`.
/// The first tab a channel profile opens on. `tab` is "posts", "media",
/// "files", "links", "music", "voice" or "gifs".
#pragma mark - default administrator rights

/// One of the presets the default-rights page offers: "readonly", "standard",
/// "posting" or "full". The whole chatAdministratorRights object is built,
/// because TDLib has no default for its booleans.
+ (NSDictionary *)administratorRightsForPreset:(NSString *)preset;

/// Telegram keeps one default set for groups and one for channels, and applies
/// it when this bot is added as an administrator. Both are bot-only requests;
/// a user account gets the server's refusal, which the screen shows.
@end
