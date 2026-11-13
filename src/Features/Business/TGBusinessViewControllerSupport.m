#import "TGBusinessViewController.h"
#import "TGBusinessMessagesViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGBusinessBaseViewController.h"
#import "TGBusinessStore.h"
#import "TGProfileStore.h"

//
// TGBusinessViewController.m - Telegram Business settings, the profile
// fields, the automated messages, the location/hours/intro and links to
// chat.
//
// The account-level settings are real subscriber features. The profile
// checksum through setBusinessAccount* carries a business connection id and
// is declared bot-only; when a user account tries it, Telegram answers with
// its refusal and the alert shows that sentence. The row stays visible
// because hiding it would leave a Business subscriber with a page that
// silently does less than the official client.
//


static NSString *const TGBusinessConnectionDefaultsKey = @"TGBusinessConnectionId";



#pragma mark - the shared list screen


NSString *TGBusinessStoredConnectionId(void) {
	NSString *value = [[NSUserDefaults standardUserDefaults]
			stringForKey:TGAccountDefaultsKey(TGBusinessConnectionDefaultsKey)];
	return [value isKindOfClass:NSString.class] ? value : @"";
}
void TGBusinessStoreConnectionId(NSString *connectionId) {
	[[NSUserDefaults standardUserDefaults] setObject:(connectionId ?: @"")
											  forKey:TGAccountDefaultsKey(TGBusinessConnectionDefaultsKey)];
}
