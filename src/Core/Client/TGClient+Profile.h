//
// TGClient+Profile - the profile surface between two people: the private
// note, who is a close friend, the read-date switch, suggested photos and
// birthdays, the sharing theme, and the account's own accent colours.
//
#import "TGClient+Base.h"
#import <UIKit/UIKit.h>

@interface TGClient (Profile)

/// A note only this account can see, kept on the other person's profile.
/// An empty note removes it.
/// The ids of every close friend, in Telegram's order.
/// Replaces the whole close-friends list. Telegram accepts contacts only, so
/// a refusal carries the server's reason.
/// Whether other people see when this account has read their messages.
/// Suggests a birthday the other person may accept; it does not change the
/// profile until they do.
/// Sends a picture to the other person as a suggested profile photo.
/// Sets the picture only this account sees for a contact. A nil path removes
/// the personal picture.
/// The tab the account's profile opens on: "posts", "gifts", "media",
/// "files", "links", "music", "voice" or "gifs".
/// Drops the close-birthday strip for 24 hours.
/// Contacts Telegram says have a birthday nearby. Kept live by
/// updateContactCloseBirthdays.
/// The account Telegram names as support, with the server's refusal when it
/// cannot.
/// Accent colour ids to offer, in Telegram's order. 0-6 are always valid;
/// updateAccentColors adds the rest.
/// The two colours this account has selected. -1 means the profile colour is
/// off, which Telegram expresses as -1.
/// The same two ids plus the two background-emoji ids. Setting a colour has to
/// hand these back to TDLib untouched, otherwise a colour change erases the
/// emoji pattern already on the account.
/// The server's colour for one accent id, from the updateAccentColors record.
/// Nil when the record has not arrived for that id yet; callers draw a neutral
/// tile until it does.
/// Picking a colour must keep the background emoji the account already has.
/// These read the current ids first and pass them through, so a caller cannot
/// send 0 by forgetting them.
/// Backgrounds the sharing screen can use: each is a dictionary with "id",
/// "name" and "colors". A refusal carries the server's sentence.
/// Sets the theme of the screen shown when this account's link is shared.
/// `backdropId` 0 with `useDefault` YES asks Telegram for its own background.
/// Returns the sharing screen to the default theme.
/// The colour a person's name is drawn in: the accent they chose, from their
/// user record, or the id-based colour while the record has not arrived.
- (UIColor *)nameColourForUser:(int64_t)userId;

@end
