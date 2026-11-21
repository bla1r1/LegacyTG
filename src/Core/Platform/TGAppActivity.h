//
// TGAppActivity.h - whether the app is on screen, for work that only matters
// to someone looking.
//
// With Background Connection on, a silent audio loop keeps the process and
// TDLib running after the Home button, and everything that ran on screen kept
// running: sticker loops at 20-30 fps, the chat list re-laid out on every
// update, and TDLib was never told the app had left the screen.
//
#import <Foundation/Foundation.h>

/// Posted on the main thread when the app goes to or comes back from the
/// background; read TGAppInBackground() for which.
FOUNDATION_EXPORT NSString *const TGAppActivityChangedNotification;

FOUNDATION_EXPORT BOOL TGAppInBackground(void);

/// Called by the app delegate only. Posts the notification on a change.
FOUNDATION_EXPORT void TGAppSetInBackground(BOOL background);

/// TDLib's "online" option: true on screen, false behind it, as official
/// clients set it. This client never set it at all.
FOUNDATION_EXPORT NSDictionary *TGOnlineOptionRequest(BOOL online);
