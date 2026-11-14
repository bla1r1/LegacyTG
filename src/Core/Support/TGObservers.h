#import <Foundation/Foundation.h>

/// A block observer that is removed when its owner is deallocated.
///
/// `-addObserverForName:object:queue:usingBlock:` returns a token, and
/// `removeObserver:self` in dealloc does not remove it: a screen that threw
/// the token away left one live observer behind for every time it was opened.
/// The block must not hold the owner strongly, or neither ever goes away.
@interface TGObservers : NSObject

/// Delivered on the main queue, for any sender.
+ (void)observe:(NSString *)name owner:(id)owner
	 usingBlock:(void (^)(NSNotification *note))block;

@end
