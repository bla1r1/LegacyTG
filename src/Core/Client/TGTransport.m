//
// TGTransport.m - the only place that loads and talks to libtdjson.
//
#import "TGTransport.h"
#import "TGGhostMode.h"
#import "TGJson.h"
#include <dlfcn.h>

/// Every request in the log is 340 lines at launch, up to 65 a second, each one
/// formatted and written to syslogd on the A4's one core. Turned on when a trace
/// is wanted: itglegacy://bench/pref/TGVerboseClientLog/1
static BOOL TGTransportVerboseLog(void) {
	static BOOL verbose;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"TGVerboseClientLog"];
	});
	return verbose;
}

/// How long the receive thread rests when TDLib has nothing: 20 ms.
static const int64_t kIdlePollNanoseconds = 20 * NSEC_PER_MSEC;

@interface TGTransport ()
@property (nonatomic, strong) NSMutableArray *outbox;
@property (nonatomic, strong) NSLock *outboxLock;
@property (nonatomic, strong) dispatch_semaphore_t outboxSignal;
@property (nonatomic, strong) NSMutableDictionary *pendingRequests;
@property (nonatomic, assign) unsigned long requestSeq;
@property (nonatomic, assign) void *handle;
@property (nonatomic, assign) void *client;
@property (nonatomic, assign) td_send_fn td_send;
@property (nonatomic, assign) td_recv_fn td_recv;
@property (nonatomic, assign) td_exec_fn td_exec;
@property (nonatomic, assign) BOOL available;
@property (nonatomic, assign) BOOL running;
@end

@implementation TGTransport

+ (instancetype)shared {
	static TGTransport *transport = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		transport = [[TGTransport alloc] init];
		transport.outbox = [NSMutableArray array];
		transport.pendingRequests = [NSMutableDictionary dictionary];
		transport.outboxLock = [[NSLock alloc] init];
		transport.outboxSignal = dispatch_semaphore_create(0);
	});
	return transport;
}

- (BOOL)start {
	if (self.running)
		return self.available;

	NSString *path = [[NSBundle mainBundle].bundlePath
			stringByAppendingPathComponent:@"libtdjson.dylib"];

	// armv7 carries TDLib as a dylib beside the binary: linked statically its
	// __TEXT goes past the 16MB a Thumb branch can reach. arm64 has no such
	// limit and no dylib was ever built for it, so there TDLib is linked in
	// and the symbols are already in this image - which is what RTLD_DEFAULT
	// searches. One lookup handles both.
	self.handle = dlopen(path.UTF8String, RTLD_NOW | RTLD_LOCAL);
	void *lookup = self.handle ?: RTLD_DEFAULT;
	if (!self.handle)
		NSLog(@"TGClient: no libtdjson.dylib (%s) - looking in the app itself",
				dlerror());

	td_create_fn create = dlsym(lookup, "td_json_client_create");
	td_exec_fn   exec   = dlsym(lookup, "td_json_client_execute");
	self.td_exec = exec;
	self.td_send = dlsym(lookup, "td_json_client_send");
	self.td_recv = dlsym(lookup, "td_json_client_receive");
	if (!create || !self.td_send || !self.td_recv){
		NSLog(@"TGClient: missing td_json_client_* symbols");
		return NO;
	}

	if (exec)
		exec(NULL, "{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":1}");

	self.client = create();
	if (!self.client){
		NSLog(@"TGClient: td_json_client_create returned NULL");
		return NO;
	}

	self.available = YES;
	self.running = YES;

	// TDLib runs single-threaded on armv7 (no thread-local storage), so its
	// scheduler only advances while we are inside td_json_client_receive.
	// Keep one thread parked in it.
	[NSThread detachNewThreadSelector:@selector(receiveLoop) toTarget:self withObject:nil];

	NSLog(@"TGClient: started");
	return YES;
}

- (void)receiveLoop {
	while (self.running){
		@autoreleasepool {
			[self drainOutbox];

			// The single-threaded client ignores this timeout and comes back at
			// once, so without the wait this thread spins on the only core. Poll
			// at 50 Hz: a send cuts the wait short, and a socket is read on the
			// next round, which is too soon for anyone to notice.
			const char *res = self.td_recv(self.client, 0.02);
			if (!res){
				while (dispatch_semaphore_wait(self.outboxSignal, DISPATCH_TIME_NOW) == 0)
					;
				dispatch_semaphore_wait(self.outboxSignal,
						dispatch_time(DISPATCH_TIME_NOW, kIdlePollNanoseconds));
				continue;
			}

			NSMutableArray *batch = [NSMutableArray arrayWithCapacity:32];

			NSError *err = nil;
			size_t resLen = strlen(res);
			NSDictionary *obj = TGJsonParseUpdate(res, resLen, &err);
			if ([obj isKindOfClass:NSDictionary.class]){
				[batch addObject:obj];
			} else if (err){
				NSLog(@"TGClient: bad JSON: %@", err);
			}

			while (batch.count < 64 && self.running){
				const char *next = self.td_recv(self.client, 0.002);
				if (!next)
					break;
				size_t nextLen = strlen(next);
				NSDictionary *nextObj = TGJsonParseUpdate(next, nextLen, nil);
				if ([nextObj isKindOfClass:NSDictionary.class]){
					[batch addObject:nextObj];
				}
			}

			if (batch.count > 0){
				NSArray *updates = [batch copy];
				dispatch_async(dispatch_get_main_queue(), ^{
					if (self.onUpdateBatch)
						self.onUpdateBatch(updates);
				});
			}
		}
	}

	void (*destroy)(void *) = dlsym(self.handle ?: RTLD_DEFAULT, "td_json_client_destroy");
	if (destroy && self.client)
		destroy(self.client);
	self.client = NULL;
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.onClosed)
			self.onClosed();
	});
}

- (void)send:(NSDictionary *)request {
	if (TGGhostModeOn() && TGGhostModeBlocks(request))
		return;
	NSMutableData *z = TGJsonSerializeForSend(request);
	if (!z){
		NSLog(@"TGClient: cannot encode %@", request);
		return;
	}

	[self.outboxLock lock];
	[self.outbox addObject:z];
	[self.outboxLock unlock];
	dispatch_semaphore_signal(self.outboxSignal);
}

/// Runs on the receive thread only.
- (void)drainOutbox {
	if (!self.available)
		return;

	NSArray *pending;
	[self.outboxLock lock];
	pending = [self.outbox copy];
	[self.outbox removeAllObjects];
	[self.outboxLock unlock];

	for (NSData *d in pending) {
		if (TGTransportVerboseLog())
			NSLog(@"TGClient: >>> SEND: %@",
					[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]);
		self.td_send(self.client, d.bytes);
	}
}

- (void)request:(NSDictionary *)request completion:(void (^)(NSDictionary *))completion {
	if (!completion){
		[self send:request];
		return;
	}
	if (TGGhostModeOn() && TGGhostModeBlocks(request)){
		// The caller is told it worked, so a screen does not hang on an answer.
		dispatch_async(dispatch_get_main_queue(), ^{
			completion(@{@"@type" : @"ok"});
		});
		return;
	}
	NSString *extra = [NSString stringWithFormat:@"r%lu", (unsigned long)(++self.requestSeq)];
	self.pendingRequests[extra] = [completion copy];

	NSMutableDictionary *withExtra = [request mutableCopy];
	withExtra[@"@extra"] = extra;
	[self send:withExtra];
}

#if TG_DEV
- (void)testSetReceive:(td_recv_fn)recv running:(BOOL)running available:(BOOL)available {
	self.td_recv = recv;
	self.running = running;
	self.available = available;
}

- (void)testStop {
	self.running = NO;
}

- (void)testSetExecute:(td_exec_fn)exec {
	self.td_exec = exec;
}

- (void)testSetAvailable:(BOOL)available {
	self.available = available;
}

- (void)testSetRunning:(BOOL)running {
	self.running = running;
}
#endif

- (void)reset {
	[self.pendingRequests removeAllObjects];
	self.requestSeq = 0;
	[self.outboxLock lock];
	[self.outbox removeAllObjects];
	[self.outboxLock unlock];
}

- (void)markClosed {
	self.running = NO;
}

- (NSDictionary *)executeSynchronously:(NSDictionary *)request {
	if (!self.td_exec || !request)
		return nil;
	NSData *json = [NSJSONSerialization dataWithJSONObject:request options:0 error:nil];
	if (!json)
		return nil;
	const char *answer = self.td_exec(NULL, [[[NSString alloc]
			initWithData:json encoding:NSUTF8StringEncoding] UTF8String]);
	if (!answer)
		return nil;
	NSData *data = [[NSString stringWithUTF8String:answer]
			dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:data
														   options:0 error:nil];
	return [parsed isKindOfClass:NSDictionary.class] ? parsed : nil;
}

@end

// vim:ft=objc
