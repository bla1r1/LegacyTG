//
// TGClient+Affiliate.h - Telegram's affiliate programs: the catalogue, the
// programs this account or bot has connected, and the program a channel
// shows under its posts.
//
// Every call names the affiliate it is about. `kind` is "user" (this
// account), "bot" (a bot user id) or "channel" (a chat id); the screen that
// asks for it says which id belongs in the field.
//
#import "TGClient+Base.h"

@interface TGClient (Affiliate)

/// `sort` is "profitability", "creationDate" or "revenue"; anything else
/// falls back to Telegram's default.
/// One connection. `programBotUserId` is the bot that owns the program, not
/// the affiliate the connection belongs to.
/// The chat behind a t.me affiliate link, or Telegram's refusal.
/// Sets the commission and duration a channel shows to affiliates.
@end

// vim:ft=objc
