#import "TGClient+Base.h"

@interface TGClient (WebApps)

/// How this account opens links: in the system browser or in an in-app one.
/// This client has no in-app browser, so `displayCloseButton` is sent as NO
/// and the setting still records Telegram's choice.
/// One URL handled differently from the default.
/// The Web App catalogue a user can browse without a Web App host.
/// The three URL getters. They answer a link; opening it needs a Web App host,
/// which this client does not have, so the screen copies it instead.
/// The two keyboard-button answers a person gives a bot: share one chat, or
/// share a list of users. `sourceChat`/`sourceMessage` name the message the
/// button came from.
@end
