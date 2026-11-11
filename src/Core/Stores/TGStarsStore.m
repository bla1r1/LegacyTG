//
// TGStarsStore.m - the one instance the Premium, Stars and gift screens share.
//
#import "TGStarsStore.h"

@implementation TGStarsStore

+ (instancetype)shared {
	static TGStarsStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		store = [[TGStarsStore alloc] init];
	});
	return store;
}

@end
