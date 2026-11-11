//
// TGUpdateRouter.h - decides what an incoming TDLib object is.
//
// A reply to one of our requests goes to its completion and stops there. A
// real update is batched on the main queue and handed to one handler; the
// coalescer turns the chat/user churn into one rebuild per 100 ms.
//
#import <Foundation/Foundation.h>
#import "TGUpdateBatcher.hpp"

@interface TGUpdateRouter : NSObject

+ (instancetype)shared;

/// Set by TGClient: the object is a real update, not a request reply.
@property (nonatomic, copy) void (^onUpdate)(NSDictionary *obj);
/// One rebuild after a batch that changed the list order.
@property (nonatomic, copy) void (^onChatsRebuilt)(void);
/// Message-level churn from the coalescer: (chatId, nil, 0).
@property (nonatomic, copy) void (^onMessageNudged)(int64_t chatId);

/// Main queue: routes request replies and batches the rest.
- (void)routeBatch:(NSArray *)batch;
/// YES when the object was an answer to a pending request.
- (BOOL)deliverResponse:(NSDictionary *)obj;

@property (nonatomic, readonly) TGUpdateCoalescer *coalescer;
@property (nonatomic, assign) BOOL batchingUpdates;
@property (nonatomic, assign) BOOL chatsNeedRebuild;

- (void)reset;

@end
