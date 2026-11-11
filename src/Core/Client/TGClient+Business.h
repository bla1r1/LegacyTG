//
// TGClient+Business.h - Telegram Business settings, chat links and the
// business-bot message wire.
//
// The account-level settings (location, opening hours, greeting and away
// messages, intro, links to chat) are what Telegram Business subscribers
// change from Settings. The account profile and the message calls carry a
// business connection id: TDLib marks them "for bots only", so a user
// account gets Telegram's refusal and the screen shows it rather than
// pretending the row is not there.
//
#import "TGClient+Base.h"

/// The part after t.me/ in a business chat link. getBusinessChatLinkInfo
/// names the link, not its URL.
FOUNDATION_EXPORT NSString *TGBusinessLinkName(NSString *link);

@interface TGClient (Business)

/// getBusinessFeatures. `source` is a businessFeature* type name or nil for
/// the Settings page; the answer is the feature type names Telegram lists.
/// The business_info half of this account's getUserFullInfo. Empty until a
/// Business subscription fills it in.
/// getBusinessConnection. Bot-only in TDLib; a user account's refusal is
/// returned as `error` and shown on the connection screen.
#pragma mark - account profile (business connection)

/// An empty path removes the photo, which TDLib spells as a null photo.
#pragma mark - links to chat

#pragma mark - account settings

/// A nil latitude removes the location; TDLib spells that as a null object.
/// `intervals` are dictionaries with "start_minute" and "end_minute",
/// counted from Monday 00:00 in a week. Nil or empty removes the schedule.
/// `recipients` is a businessRecipients dictionary; nil means every
/// one-to-one chat. Off sends the null settings that disable the greeting.
/// `schedule` is "always", "outside" or "custom"; custom uses the two int32
/// dates. Off sends the null settings that disable the away message.
/// The intro people see before they start a chat. Empty title and message
/// remove it. The sticker is a local image path, or nil for none.
#pragma mark - business messages (business connection)

/// A `livePeriod` of zero stops the live location.
/// TDLib takes null for no markup; this is the request that clears one.
@end

// vim:ft=objc
