//
// TGGroupStore.m - the shared instance.
//
#import "TGGroupStore.h"

@implementation TGGroupStore

+ (instancetype)shared {
	static TGGroupStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ store = [[TGGroupStore alloc] init]; });
	return store;
}

@end

// vim:ft=objc
