#import "TGClient+MessagesUpload.h"
#import "TGClient+MessagesInternal.h"
#import "TGClientInternal.h"

@implementation TGClient (MessagesUpload)

#pragma mark - a round note on its way

/// A handful of waiters at most, so walking them costs less than an index by
/// file id that has to stay in step with the completions.
- (void)noteUploadProgress:(NSInteger)fileId fraction:(float)fraction {
	for (NSNumber *key in self.noteSendWaiters){
		NSMutableDictionary *waiter = self.noteSendWaiters[key];
		if ([waiter[@"fileId"] integerValue] != fileId)
			continue;
		CGFloat value = MAX(0.0f, MIN(1.0f, fraction));
		waiter[@"fraction"] = @(value);
		void (^progress)(CGFloat) = waiter[@"progress"];
		if (progress)
			progress(value);
	}
}

- (CGFloat)sendProgressForMessage:(int64_t)messageId {
	NSDictionary *waiter = self.noteSendWaiters[@(messageId)];
	return waiter ? [waiter[@"fraction"] doubleValue] : 0;
}

- (void)registerSendWaiterForMessage:(int64_t)messageId
							  fileId:(NSInteger)fileId
							progress:(void (^)(CGFloat))progress
						  completion:(void (^)(BOOL))completion {
	if (!progress && !completion)
		return;
	if (!self.noteSendWaiters)
		self.noteSendWaiters = [NSMutableDictionary dictionary];
	NSMutableDictionary *waiter = [NSMutableDictionary dictionary];
	waiter[@"fileId"] = @(fileId);
	waiter[@"fraction"] = @0;
	if (progress)
		waiter[@"progress"] = [progress copy];
	if (completion)
		waiter[@"completion"] = [completion copy];
	self.noteSendWaiters[@(messageId)] = waiter;
}

- (void)noteSendFinished:(int64_t)messageId sent:(BOOL)sent {
	NSDictionary *waiter = self.noteSendWaiters[@(messageId)];
	if (!waiter)
		return;
	void (^completion)(BOOL) = waiter[@"completion"];
	// Out before the call: a repeated update must not answer twice.
	[self.noteSendWaiters removeObjectForKey:@(messageId)];
	if (completion)
		completion(sent);
}

@end
