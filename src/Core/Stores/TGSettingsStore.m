//
// TGSettingsStore.m - the one instance the settings pages share.
//
// The store keeps no cache of its own: every read goes to the client's account
// record and every write is a TDLib request, so two pages cannot disagree
// about what an option is set to. The categories hold the request bodies.
//
#import "TGSettingsStore.h"

@implementation TGSettingsStore

+ (instancetype)shared {
	static TGSettingsStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		store = [[TGSettingsStore alloc] init];
	});
	return store;
}

@end
