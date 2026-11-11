#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountProfileMedia.h"
#import "TGClient+AccountSupport.h"


@implementation TGClient (AccountProfileMedia)

#pragma mark - profile photos, link, groups in common

/// A profile photo taken off the account by the id the chatPhoto carried.
/// The account's whole photo history: what the avatar tap shows, and the
/// only place a photoId worth deleting answers from.
/// The signed-in account's own t.me link - Telegram gives it only for the
/// current user, so there is no asking for someone else's.
/// The chats two accounts are in together, named off the answer itself, so
/// a tap opens it like any chat the list holds.
@end
