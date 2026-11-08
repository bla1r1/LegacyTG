//
// TGBusinessViewController.h - the Telegram Business settings page and the
// list screen every Business sub-page inherits from.
//
#import <UIKit/UIKit.h>
#import "TGBusinessRows.h"

/// The row list, theme and switch plumbing the Business pages share. A
/// subclass fills `sections` and answers `didChooseAction:` / `toggleKey:`.

/// Settings → Telegram Business.

/// The business-bot connection id, shared by the connection page and the
/// message page. A user account has none; this is where a bot session's id
/// is pasted so the screens can still send the bot-only requests.
FOUNDATION_EXPORT NSString *TGBusinessStoredConnectionId(void);
FOUNDATION_EXPORT void TGBusinessStoreConnectionId(NSString *connectionId);

// vim:ft=objc
#import "TGBusinessBaseViewController.h"
@class TGBusinessViewController, TGBusinessProfileViewController, TGBusinessChatLinksViewController, TGBusinessGreetingViewController, TGBusinessAwayViewController, TGBusinessHoursViewController, TGBusinessLocationViewController;

@interface TGBusinessIntroViewController : TGBusinessBaseViewController @end
