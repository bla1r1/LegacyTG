//
// TGAccountStore.m - the one instance the account pages share.
//
#import "TGAccountStore.h"

@implementation TGAccountStore

+ (instancetype)shared {
	static TGAccountStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		store = [[TGAccountStore alloc] init];
	});
	return store;
}

@end
