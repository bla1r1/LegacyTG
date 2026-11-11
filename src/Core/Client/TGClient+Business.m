//
// TGClient+Business.m - the Telegram Business requests.
//
// The shape here follows td_api.tl exactly. The account settings carry no
// connection id because TDLib applies them to the signed-in user; the
// profile and message calls do carry one because TDLib declares them for
// business bots. Sending them from a user account is still the honest
// request: Telegram answers with its own refusal, and the screen prints
// that sentence instead of hiding a row nobody can use.
//
#import "TGClient+Business.h"
#import "TGClientInternal.h"

/// A business chat link is returned as a full t.me URL. The info request
/// names only the part after the slash.
NSString *TGBusinessLinkName(NSString *link) {
	NSString *name = link ?: @"";
	for (NSString *prefix in @[@"https://t.me/", @"http://t.me/", @"t.me/"]){
		if ([name hasPrefix:prefix]){
			name = [name substringFromIndex:prefix.length];
			break;
		}
	}
	return name;
}

@implementation TGClient (Business)

#pragma mark - features and connection

#pragma mark - account profile

#pragma mark - links to chat

#pragma mark - account settings

#pragma mark - business messages

@end

// vim:ft=objc
