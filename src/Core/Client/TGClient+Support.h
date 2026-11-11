//
// TGClient+Support.h - Telegram's support identity and the optional note a
// person can attach to their support request.
//
// getSupportName and the two UserSupportInfo calls are support-staff
// plumbing: a normal account often gets Telegram's refusal. The Settings
// page sends them and prints that sentence rather than hiding the row.
//
#import "TGClient+Base.h"

@interface TGClient (Support)

/// "message", "author" and "date" for one user's support note.
/// Sets the note; the answer is the updated UserSupportInfo.
@end

// vim:ft=objc
