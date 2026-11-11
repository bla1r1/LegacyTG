#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountSettings.h"
#import "TGClient+AccountSupport.h"


@implementation TGClient (AccountSettings)

#pragma mark - account settings

/// setScopeNotificationSettings replaces the whole record, so writing one field
/// means reading the rest back first - otherwise muting a scope silently reset
/// its preview setting, and turning previews off unmuted it.
@end
