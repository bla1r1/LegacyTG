//
// TGAppActivity.m
//
#import "TGAppActivity.h"

NSString *const TGAppActivityChangedNotification = @"TGAppActivityChangedNotification";

static BOOL sInBackground;

BOOL TGAppInBackground(void) {
	return sInBackground;
}

void TGAppSetInBackground(BOOL background) {
	if (sInBackground == background)
		return;
	sInBackground = background;
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGAppActivityChangedNotification object:nil];
}

NSDictionary *TGOnlineOptionRequest(BOOL online) {
	return @{
		@"@type" : @"setOption",
		@"name"  : @"online",
		@"value" : @{@"@type" : @"optionValueBoolean", @"value" : @(online)},
	};
}
