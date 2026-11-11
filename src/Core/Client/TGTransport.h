//
// TGTransport.h - the TDLib runtime: one client, one receive loop, one outbox.
//
// Nothing above this file talks to libtdjson. TGClient owns the caches and
// the update fan-out; this class only carries JSON in and out and matches an
// answer to the request that asked for it.
//
#import <Foundation/Foundation.h>

typedef void *(*td_create_fn)(void);
typedef void  (*td_send_fn)(void *client, const char *request);
typedef const char *(*td_recv_fn)(void *client, double timeout);
typedef const char *(*td_exec_fn)(void *client, const char *request);

@interface TGTransport : NSObject

+ (instancetype)shared;

/// Loads libtdjson, creates the client and parks the receive thread. Returns
/// NO when the dylib or its symbols are missing.
- (BOOL)start;

/// Runs on the receive thread only: every parsed object batch is handed to
/// this block on the main queue.
@property (nonatomic, copy) void (^onUpdateBatch)(NSArray *batch);
/// Called on the main queue after TDLib closed the client.
@property (nonatomic, copy) void (^onClosed)(void);

/// Queues one request. Safe from any thread; the receive thread sends it.
- (void)send:(NSDictionary *)request;
/// Queues a request and keeps its completion until the answer with @extra.
- (void)request:(NSDictionary *)request completion:(void (^)(NSDictionary *))completion;
/// td_json_client_execute, for the few functions that answer synchronously.
- (NSDictionary *)executeSynchronously:(NSDictionary *)request;

/// Empties the request queue when the account changes.
- (void)reset;

/// Marks the receive loop finished when TDLib reports authorization closed.
- (void)markClosed;

@property (nonatomic, readonly) BOOL available;
@property (nonatomic, readonly) BOOL running;
@property (nonatomic, readonly) NSMutableArray *outbox;
@property (nonatomic, readonly) NSMutableDictionary *pendingRequests;

#if TG_DEV
/// Test hook: point the receive loop at a counting reader without TDLib.
- (void)testSetReceive:(td_recv_fn)recv running:(BOOL)running available:(BOOL)available;
- (void)testStop;
- (void)testSetExecute:(td_exec_fn)exec;
- (void)testSetAvailable:(BOOL)available;
- (void)testSetRunning:(BOOL)running;
- (void)receiveLoop;
#endif

@end
