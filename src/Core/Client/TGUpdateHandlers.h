//
// TGUpdateHandlers.h - the update switch, out of TGClient.
//
#import <Foundation/Foundation.h>

@class TGClient;

@interface TGUpdateHandlers : NSObject

+ (instancetype)shared;

/// Set by TGClient before dispatch; the handlers read and write its caches.
@property (nonatomic, weak) TGClient *client;

- (void)handleUpdate:(NSDictionary *)obj;

@end
