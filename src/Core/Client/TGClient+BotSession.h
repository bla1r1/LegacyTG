//
// TGClient+BotSession.h - the calls a bot account makes: answering the
// queries Telegram sends it, its command and menu-button records, the
// managed-bot token, and the Web App host calls a bot is allowed to send.
//
// A user session may name every one of these, and Telegram decides. The Bot
// Console sends the real request and prints whatever came back, including the
// refusal; nothing here pretends a user account is a bot.
//
#import "TGClient+Base.h"

@interface TGClient (BotSession)

#pragma mark - session and passkeys

/// TDLib's bot sign-in. Only valid while the client is waiting for a phone
/// number; in a ready user session Telegram answers with its refusal, which
/// is the honest result the console shows.
/// The text Telegram uses to explain passkey support to this client.
/// Passkeys registered on this account. Each row keeps "id", "name",
/// "additionDate", "lastUsageDate" and "softwareIconCustomEmojiId".
/// Registers a passkey. `attestationObject` is base64: TDLib's JSON carries
/// bytes as base64, and the OS passkey sheet is not part of this build.
/// Finishes a passkey sign-in with the credential the authenticator produced.
/// The three byte fields are base64, as the OS would hand them over.
#pragma mark - commands and menu button

/// "default" or "chat". A chat scope needs `chatId`; the server refuses a
/// chat command list from an account that cannot manage it.
/// Each element is a dictionary with "command", "description" and optional
/// "ephemeral", or a bare command string.
/// The menu button Telegram shows beside a bot. `botUserId` is the bot's
/// user id, not this account's.
/// A text/URL menu button. TDLib's BotMenuButton is one concrete shape, so
/// both fields are required; an empty button is not a request this schema
/// can express.
#pragma mark - managed bot

/// The token of a bot this account manages. `revoke` asks Telegram to rotate
/// it, which invalidates the old one everywhere.
/// "isRestricted" and "addedUserIds" as Telegram holds them.
/// A bot tells Telegram how many updates are still queued. The count and the
/// last error text are the bot's own report; a user account usually gets a
/// refusal, which is what the console shows.
#pragma mark - query answers

/// An empty option list with Telegram's error text is a valid answer for a
/// shipping query this bot cannot fulfil.
/// Replaces a callback's message with an ephemeral one. The content is a
/// plain text message; the callback id is the bot's own.
#pragma mark - Web App host

@end

// vim:ft=objc
