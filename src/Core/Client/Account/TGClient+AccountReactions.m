#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountReactions.h"
#import "TGClient+AccountSupport.h"


@implementation TGClient (AccountReactions)

#pragma mark - reactions

/// No record yet means Telegram has not answered the post-login burst; its
/// default is to show them, so the switch starts on rather than off.
@end
