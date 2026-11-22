//
// AppDelegate+Walk.h - the emulator walk's two routes (scripts/emu.sh walk),
// kept out of AppDelegate+URL, which is at its size limit. Dev builds only.
//
#import "AppDelegate.h"

@interface AppDelegate (Walk)

/// YES when `url` was itglegacy://reset or itglegacy://vc/...; always NO
/// without TG_DEV.
- (BOOL)tg_handleWalkURL:(NSURL *)url;

@end
