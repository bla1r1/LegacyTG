#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountTwoStep.h"
#import "TGClient+AccountSupport.h"


@implementation TGClient (AccountTwoStep)

#pragma mark - two-step verification

/// The password written whole. A wrong old password is the error here, and
/// the screen above is what says that to a human. An empty new password is
/// how the password comes off, not a refusal to write one.
/// What a recovery address says - and whether the password that asked for it
/// was right, because a wrong one is answered with an empty class where the
/// email would have been.
/// Point the recovery address somewhere else. TDLib confirms the new one by
/// letter afterwards, so the answer says the request landed, not that the
/// address is live.
@end
