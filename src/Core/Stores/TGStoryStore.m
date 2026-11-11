//
// TGStoryStore.m - the shared instance.
//
#import "TGStoryStore.h"

@implementation TGStoryStore

+ (instancetype)shared {
	static TGStoryStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ store = [[TGStoryStore alloc] init]; });
	return store;
}

@end

// vim:ft=objc
