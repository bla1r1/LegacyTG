//
// TGUpdateRouter.m - request replies vs real updates, plus coalescing.
//
#import "TGUpdateRouter.h"
#import "TGTransport.h"

@interface TGUpdateRouter ()
@property (nonatomic, strong) TGUpdateCoalescer *coalescer;
@end

NSString *const TGMessagesChangedNotification = @"TGMessagesChangedNotification";

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

- (void)noteMessagesChangedInChat:(int64_t)chatId {
	if (chatId == 0)
		return;
	static NSMutableSet *dirty = nil;
	static BOOL scheduled = NO;
	@synchronized (self){
		if (!dirty)
			dirty = [NSMutableSet set];
		[dirty addObject:@(chatId)];
		if (scheduled)
			return;
		scheduled = YES;
	}
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
		NSArray *chatIds = nil;
		@synchronized (self){
			chatIds = dirty.allObjects;
			[dirty removeAllObjects];
			scheduled = NO;
		}
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGMessagesChangedNotification
							  object:self
							userInfo:@{@"chatIds" : chatIds ?: @[]}];
	});
}

- (void)reset {
	self.batchingUpdates = NO;
	self.chatsNeedRebuild = NO;
	[self.coalescer reset];
}

@end

// vim:ft=objc
