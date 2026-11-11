//
// TGClient+EmojiStatus - the badge beside a name: the lists Telegram offers
// for an account and for a chat, and the two requests that wear one.
//
#import "TGClient+Base.h"

/// The custom emoji id a TDLib emojiStatus draws, or 0: a gift status
/// falls back to its model's emoji, as Telegram draws it.
FOUNDATION_EXPORT int64_t TGEmojiStatusCustomEmojiId(NSDictionary *status);

@interface TGClient (EmojiStatus)

/// The custom emoji id of a cached user's status, or 0 if none or not cached.
- (int64_t)emojiStatusIdForUser:(int64_t)userId;

/// The custom emoji id of a cached chat's status, or 0 if none or not cached.
- (int64_t)emojiStatusIdForChat:(int64_t)chatId;

/// Up to eight statuses Telegram places after the default Premium badge.
/// Each entry is an NSNumber custom-emoji id.
/// The statuses any account may wear. NSNumber custom-emoji ids.
/// Recently worn statuses as dictionaries: "emojiId", "expirationDate" and
/// "kind" ("customEmoji", "upgradedGift" or "unknown").
/// The same for a chat's badge. Telegram allows a narrower set there, so the
/// picker reads the chat lists rather than the account ones.
/// Statuses Telegram refuses as a chat badge. The picker draws them greyed
/// out instead of offering a request that is certain to fail.
/// Wear `customEmojiId` until `expirationDate` (unix seconds, 0 for no end).
/// An id of 0 takes the badge off, which TDLib spells as a null status.
/// A bot may change someone else's badge. The screen sends it and shows the
/// server's refusal for an ordinary account, which is the honest answer.
/// A group's or channel's badge. An id of 0 clears it.
@end
