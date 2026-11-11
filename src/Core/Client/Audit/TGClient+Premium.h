#import "TGClient+Base.h"

@interface TGClient (Premium)

/// The feature and limit lists on the Premium page. Each feature is its type
/// name; each limit keeps "type", "defaultValue" and "premiumValue".
/// Tells Telegram a Premium feature card was opened.
/// One limit's free and Premium values, as "type", "defaultValue" and
/// "premiumValue".
/// Premium stickers, examples and the month-specific info sticker.
/// Checks a Premium gift code without redeeming it. The answer keeps
/// "monthCount", "dayCount", "isFromGiveaway", "userId" and "useDate".
/// Tells Telegram the Premium subscribe button was pressed. The purchase
/// itself is the App Store's, which this build does not carry; the signal is
/// still real and is what the server logs.
@end
