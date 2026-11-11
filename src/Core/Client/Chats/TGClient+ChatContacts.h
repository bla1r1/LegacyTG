#import "TGClient+Base.h"

@interface TGClient (ChatContacts)

/// A contact nobody here has met: the import makes the user, and the id it
/// hands back is what `addContactWithUserId:` is finished with.
/// A number back in the block list, spelled as a message sender.
- (void)blockUserWithUserId:(int64_t)userId;

/// Your phone number to a mutual contact, on their offer to share it.
- (void)sharePhoneNumberWithUser:(int64_t)userId;

/// Adds someone to your Telegram contacts. The phone number is what the
/// server matches on.
/// Takes someone out of your contacts; the chat with them stays.
@end
