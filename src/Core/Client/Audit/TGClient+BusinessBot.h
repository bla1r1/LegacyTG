#import "TGClient+Base.h"

@interface TGClient (BusinessBot)

/// The business bot connected to this account. Nil with Telegram's 404 text
/// when there is none.
/// Connects or replaces the business bot. `recipients` follows
/// businessRecipients; missing keys are false.
@end
