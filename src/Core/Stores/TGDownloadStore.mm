//
// TGDownloadStore.mm - the download queue, its waiters and its watchdog.
//
#import "TGDownloadStore.h"
#import "TGClient.h"
#import "TGMediaSupport.h"
#import "TGClientInternal.h"

#include <mutex>
#include <unordered_map>
#include <vector>

double TGFileWaiterTimeoutSeconds = 45.0;
static const NSTimeInterval TGFileWaiterSweepOffset = 15.0 * 60.0;

@implementation TGDownloadStore

+ (instancetype)shared {
	static TGDownloadStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		store = [[TGDownloadStore alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:store
				selector:@selector(fileDownloaded:) name:TGFileDownloadedNotification object:nil];
	});
	return store;
}

// The watchdog timing: how long a waiter waits for a download answer, and how
// long a fully expired record may still hope for a late updateFile before the
// sweep retires it. Tunables, because the layout of a slow 3G reply is not
// reproducible in a test otherwise (see tests/TGClientFilesTests.m).

/// A waiter is a callback plus whether it has already been served nil by the
/// watchdog. Expired waiters stay in the record: a file that finishes
/// downloading past the timeout still reaches them on the second pass (B2 —
/// before this, the watchdog deleted the record and a late updateFile
/// notified nobody, ever).
typedef void (^TGFileWaiterBlock)(NSString *);

namespace {

struct TGFileWaiter {
	TGFileWaiterBlock callback;
	bool expired;
};

// Every record used to be an NSNumber key onto an NSMutableArray of
// NSMutableDictionaries holding a block and a boxed BOOL - five objects per
// waiter - under @synchronized on the dictionary itself, which is a global
// recursive lock keyed by object identity. A download reaches this from the
// TDLib receive thread, the watchdog from the main queue, and avatars arrive
// in bursts of dozens. Flat vectors behind one mutex of our own: no boxing,
// no object identity lookup, and the lock is visible in the code that holds
// it.
//
// ponytail: one mutex for the whole table, not one per file. A few hundred
// file ids and three threads never contend; per-id locking if that changes.
std::mutex gWaitersMutex;
std::unordered_map<int32_t, std::vector<TGFileWaiter>> gWaiters;
std::unordered_map<int32_t, int32_t> gPriorities;

}  // namespace

/// Delivers a path (or a fatal nil - an error answer) to every waiter of the
/// file and retires the record.
- (void)notifyFileWaiters:(NSInteger)fileId path:(NSString *)path {
	NSMutableArray *callbacks = nil;
	{
		std::lock_guard<std::mutex> lock(gWaitersMutex);
		auto it = gWaiters.find((int32_t)fileId);
		if (it == gWaiters.end())
			return;
		callbacks = [NSMutableArray arrayWithCapacity:it->second.size()];
		for (const TGFileWaiter &waiter : it->second){
			if (waiter.callback)
				[callbacks addObject:waiter.callback];
		}
		gWaiters.erase(it);
		gPriorities.erase((int32_t)fileId);
	}
	if (!callbacks.count)
		return;

	dispatch_async(dispatch_get_main_queue(), ^{
		for (void (^cb)(NSString *) in callbacks){
			cb(path);
		}
	});
}

/// Serves every waiter that has not run yet with a nil - the timeout reached
/// them - but keeps the record itself alive. A watcher who only stuffed a
/// file id into a "requested" set (the chat list marks its avatars that way)
/// clears the mark on nil and tries again on the next pass, while the
/// download itself keeps going: its late updateFile still calls callbacks.
- (void)expireFileWaiters:(NSInteger)fileId {
	NSMutableArray *callbacks = [NSMutableArray array];
	{
		std::lock_guard<std::mutex> lock(gWaitersMutex);
		auto it = gWaiters.find((int32_t)fileId);
		if (it == gWaiters.end())
			return;
		for (TGFileWaiter &waiter : it->second){
			if (waiter.expired)
				continue;
			waiter.expired = true;
			if (waiter.callback)
				[callbacks addObject:waiter.callback];
		}
	}
	if (!callbacks.count)
		return;

	dispatch_async(dispatch_get_main_queue(), ^{
		for (void (^cb)(NSString *) in callbacks){
			cb(nil);
		}
	});
}

/// Retires the record of a file nothing ever came back for, and whose waiters
/// have long since been served nil. A fresh (unexpired) waiter keeps the
/// record - its own watchdog will expire it and schedule another sweep.
- (void)sweepFileWaiters:(NSInteger)fileId {
	std::lock_guard<std::mutex> lock(gWaitersMutex);
	auto it = gWaiters.find((int32_t)fileId);
	if (it == gWaiters.end())
		return;
	for (const TGFileWaiter &waiter : it->second){
		if (!waiter.expired)
			return;   // a live waiter; its sweep comes later
	}
	gWaiters.erase(it);
	gPriorities.erase((int32_t)fileId);
}

/// Drops the record outright - what a cancelled download leaves behind.
- (void)releaseFileWaiters:(NSInteger)fileId {
	std::lock_guard<std::mutex> lock(gWaitersMutex);
	gWaiters.erase((int32_t)fileId);
	gPriorities.erase((int32_t)fileId);
}

- (void)removeAllFileWaiters {
	std::lock_guard<std::mutex> lock(gWaitersMutex);
	gWaiters.clear();
	gPriorities.clear();
}



/// How many waiters a file still has. Zero means no record at all.
- (NSUInteger)fileWaiterCount:(NSInteger)fileId {
	std::lock_guard<std::mutex> lock(gWaitersMutex);
	auto it = gWaiters.find((int32_t)fileId);
	return (it == gWaiters.end()) ? 0 : it->second.size();
}

- (BOOL)hasFileWaiterRecord:(NSInteger)fileId {
	std::lock_guard<std::mutex> lock(gWaitersMutex);
	return gWaiters.find((int32_t)fileId) != gWaiters.end();
}

- (NSInteger)fileWaiterPriority:(NSInteger)fileId {
	std::lock_guard<std::mutex> lock(gWaitersMutex);
	auto it = gPriorities.find((int32_t)fileId);
	return (it == gPriorities.end()) ? 0 : it->second;
}

- (void)downloadFile:(NSInteger)fileId
			priority:(NSInteger)priority
		  completion:(void (^)(NSString *path))completion {
	if (fileId <= 0){
		if (completion) completion(nil);
		return;
	}

	NSNumber *fid = @(fileId);
	BOOL sendRequest = NO;
	BOOL armWatchdog = NO;
	NSInteger storedPriority = 0;
	{
		std::lock_guard<std::mutex> lock(gWaitersMutex);
		int32_t key = (int32_t)fileId;
		auto it = gWaiters.find(key);
		if (it == gWaiters.end()){
			it = gWaiters.emplace(key, std::vector<TGFileWaiter>()).first;
			sendRequest = YES;
			armWatchdog = YES;
			storedPriority = priority;
			gPriorities[key] = (int32_t)priority;
		} else {
			auto stored = gPriorities.find(key);
			storedPriority = (stored == gPriorities.end()) ? 0 : stored->second;
			BOOL allExpired = YES;
			for (const TGFileWaiter &waiter : it->second){
				if (!waiter.expired){
					allExpired = NO;
					break;
				}
			}
			// The same file asked again at a higher rank re-raises the
			// request: TDLib orders its queue by it, which is how an
			// avatar overtakes a grid of photos (B2).
			if (priority > storedPriority){
				storedPriority = priority;
				gPriorities[key] = (int32_t)priority;
				sendRequest = YES;
			}
			// A retry after every waiter expired re-arms the watchdog - the
			// original timer already fired and cannot expire the newcomer.
			armWatchdog = allExpired;
		}
		if (completion){
			TGFileWaiter waiter;
			waiter.callback = completion;
			waiter.expired = false;
			it->second.push_back(waiter);
		}
	}

	if (sendRequest){
		[[TGClient shared] request:@{
			@"@type"       : @"downloadFile",
			@"file_id"     : fid,
			@"priority"    : @(storedPriority),
			@"offset"      : @(0),
			@"limit"       : @(0),
			@"synchronous" : @NO,
		} completion:^(NSDictionary *result){
			TGDownloadStore *me = [TGDownloadStore shared];
			if (!me) return;
			NSString *path = result[@"local"][@"path"];
			BOOL done = [result[@"local"][@"is_downloading_completed"] boolValue];
			if (done && path.length){
				[me notifyFileWaiters:fileId path:path];
			} else if ([result[@"@type"] isEqualToString:@"error"]){
				[me notifyFileWaiters:fileId path:nil];
			}
			// Anything else - a file object whose download is still in
			// progress - is waited for through updateFile updates.
		}];
	}

	// The watchdog arms on the first waiter for a file, and re-arms whenever
	// a fresh waiter lands on a record whose waiters had all expired: the
	// original timer already fired and cannot expire the newcomer.
	if (armWatchdog){
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
				(int64_t)(TGFileWaiterTimeoutSeconds * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
			[[TGDownloadStore shared] expireFileWaiters:fileId];
		});

		// The sweep is what keeps an abandoned file - a download that never
		// succeeds and never errors - from holding its record (and its
		// callbacks) in memory forever.
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
				(int64_t)((TGFileWaiterTimeoutSeconds
						+ TGFileWaiterSweepOffset) * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
			[[TGDownloadStore shared] sweepFileWaiters:fileId];
		});
	}
}

- (void)downloadFile:(NSInteger)fileId completion:(void (^)(NSString *path))completion {
	// Long-standing callers carried the lowest rank; keep their behaviour,
	// and let the paths that show something immediately (avatars, visible
	// grids) ask for more through downloadFile:priority:completion:.
	[self downloadFile:fileId priority:TGDownloadPriorityBackground
			 completion:completion];
}




- (void)fileDownloaded:(NSNotification *)note {
	int64_t fileId = [note.userInfo[@"fileId"] longLongValue];
	NSString *path = note.userInfo[@"path"];
	if (fileId)
		[self notifyFileWaiters:fileId path:path];
}

- (void)cancelDownloadOfFile:(NSInteger)fileId onlyIfPending:(BOOL)onlyIfPending {
	[[TGClient shared] send:@{
		@"@type"           : @"cancelDownloadFile",
		@"file_id"         : @(fileId),
		@"only_if_pending" : @(onlyIfPending),
	}];
	[self releaseFileWaiters:fileId];
}

@end
