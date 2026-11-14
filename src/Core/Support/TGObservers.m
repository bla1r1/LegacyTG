#import "TGObservers.h"
#import <objc/runtime.h>

@implementation TGObservers {
	NSMutableArray *_tokens;
}

+ (void)observe:(NSString *)name owner:(id)owner
	 usingBlock:(void (^)(NSNotification *note))block {
	if (!name.length || !owner || !block)
		return;
	static const char kBagKey = 0;
	TGObservers *bag = nil;
	// Screens register in viewDidLoad on the main thread; the lock is for the
	// one that does it from a store's callback.
	@synchronized (owner) {
		bag = objc_getAssociatedObject(owner, &kBagKey);
		if (!bag) {
			bag = [[TGObservers alloc] init];
			bag->_tokens = [NSMutableArray array];
			// Released with the owner's other associated objects, which is
			// when dealloc below takes the observers out.
			objc_setAssociatedObject(owner, &kBagKey, bag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
		[bag->_tokens addObject:[[NSNotificationCenter defaultCenter]
				addObserverForName:name object:nil
							 queue:[NSOperationQueue mainQueue] usingBlock:block]];
	}
}

- (void)dealloc {
	for (id token in _tokens)
		[[NSNotificationCenter defaultCenter] removeObserver:token];
}

@end
