#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountOptions.h"
#import "TGClient+AccountSupport.h"


@implementation TGClient (AccountOptions)

#pragma mark - options

/// Fetches profile stories (pinned profile stories falling back to active 24h stories).
/// Their Edit Profile has a birthday row; TDLib keeps it as three numbers and
/// a zero day means it is not set. Year is optional, which is why it is only
/// written when it is there.
/// The signed-in account's own birthday as TDLib stores it: "day", "month",
/// "year" (0 when unset).
/// Their profile page leads with this, and there was no way to set a picture
/// from the app at all - only to look at one already set from another client.
@end
