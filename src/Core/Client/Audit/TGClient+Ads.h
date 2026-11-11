#import "TGClient+Base.h"

@interface TGClient (Ads)

/// Tells Telegram the advertisement was opened: its name, its media or its
/// full-screen video. The answer is Telegram's, usually just ok.
/// Reports a sponsored message. An empty option id asks Telegram for the
/// reason list; the answer says whether it wants a choice, accepted the
/// report, hid ads, or requires Premium.
/// The account-wide switch. Telegram ignores it for non-Premium accounts,
/// where sponsored messages are always shown; the server's answer says so.
/// The owner's switch for one channel. `supergroupId` is the supergroup id,
/// not the chat id; the screen says so where it asks.
/// Sponsored chats in search results. Each row is "uniqueId", "chatId",
/// "sponsorInfo" and "additionalInfo".
/// Advertisements that play before or under one video message. Each row is
/// "uniqueId", "text", "minDisplayDuration", "maxDisplayDuration",
/// "canBeReported", "title", "sponsor" and "additionalInfo".
@end
