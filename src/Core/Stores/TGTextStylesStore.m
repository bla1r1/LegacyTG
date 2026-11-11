//
// TGTextStylesStore.m - the text styles the composer can use.
//
#import "TGTextStylesStore.h"

@implementation TGTextStylesStore

+ (instancetype)shared {
	static TGTextStylesStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		store = [[TGTextStylesStore alloc] init];
	});
	return store;
}

@end
