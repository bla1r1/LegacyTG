//
// TGUpdateRouter.m - request replies vs real updates, plus coalescing.
//
#import "TGUpdateRouter.h"
#import "TGTransport.h"

@interface TGUpdateRouter ()
@property (nonatomic, strong) TGUpdateCoalescer *coalescer;
@end

@implementation TGUpdateRouter

+ (instancetype)shared {
	static TGUpdateRouter *router = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		router = [[TGUpdateRouter alloc] init];
		router.coalescer = [[TGUpdateCoalescer alloc] initWithIntervalMs:100];
		__weak TGUpdateRouter *weakSelf = router;
		[router.coalescer setFlushHandler:^(NSSet *dirtyChatIds, NSSet *dirtyUserIds,
											BOOL orderChanged) {
			TGUpdateRouter *me = weakSelf;
			if (!me)
				return;
			if ((orderChanged || dirtyChatIds.count > 0) && me.onChatsRebuilt)
				me.onChatsRebuilt();
		}];
		[router.coalescer setMessagesHandler:^(NSDictionary *messageIdsByChat) {
			TGUpdateRouter *me = weakSelf;
			if (!me || !me.onMessageNudged)
				return;
			for (NSNumber *chatId in messageIdsByChat)
				me.onMessageNudged([chatId longLongValue]);
		}];
	});
	return router;
}

- (void)routeBatch:(NSArray *)batch {
	NSMutableArray *updates = [NSMutableArray arrayWithCapacity:batch.count];
	for (NSDictionary *obj in batch){
		if (![obj isKindOfClass:NSDictionary.class])
			continue;
		if ([self deliverResponse:obj])
			continue;
		[updates addObject:obj];
	}
	if (!updates.count)
		return;

	self.batchingUpdates = YES;
	for (NSDictionary *obj in updates){
		if (self.onUpdate)
			self.onUpdate(obj);
	}
	self.batchingUpdates = NO;

	if (self.chatsNeedRebuild){
		self.chatsNeedRebuild = NO;
		if (self.onChatsRebuilt)
			self.onChatsRebuilt();
	}
}

- (BOOL)deliverResponse:(NSDictionary *)obj {
	NSString *extra = obj[@"@extra"];
	if (![extra isKindOfClass:NSString.class])
		return NO;
	void (^completion)(NSDictionary *) = [TGTransport shared].pendingRequests[extra];
	if (!completion)
		return NO;
	[[TGTransport shared].pendingRequests removeObjectForKey:extra];
	completion(obj);
	return YES;
}

- (void)reset {
	self.batchingUpdates = NO;
	self.chatsNeedRebuild = NO;
	[self.coalescer reset];
}

@end

// vim:ft=objc
