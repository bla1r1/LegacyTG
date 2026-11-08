#import <CoreGraphics/CoreGraphics.h>
#import "TGClient+Base.h"

@interface TGClient (MessagesSendWaiters)

/// Both sends end here, so the waiter shape and the file id extraction exist
/// once rather than in two copies that can drift.
- (void)registerSendWaiterForMessage:(int64_t)messageId
							  fileId:(NSInteger)fileId
							progress:(void (^)(CGFloat))progress
						  completion:(void (^)(BOOL))completion;

@end
