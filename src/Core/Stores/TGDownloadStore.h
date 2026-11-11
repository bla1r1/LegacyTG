//
// TGDownloadStore.h - the single owner of the download queue and its waiters.
//
#import <Foundation/Foundation.h>
#import "TGDownloadPriority.h"

extern double TGFileWaiterTimeoutSeconds;

@interface TGDownloadStore : NSObject

+ (TGDownloadStore *)shared;

- (void)downloadFile:(NSInteger)fileId completion:(void (^)(NSString *path))completion;
- (void)downloadFile:(NSInteger)fileId priority:(NSInteger)priority
          completion:(void (^)(NSString *path))completion;
- (void)cancelDownloadOfFile:(NSInteger)fileId onlyIfPending:(BOOL)onlyIfPending;

- (void)notifyFileWaiters:(NSInteger)fileId path:(NSString *)path;
- (void)expireFileWaiters:(NSInteger)fileId;
- (void)sweepFileWaiters:(NSInteger)fileId;
- (void)releaseFileWaiters:(NSInteger)fileId;
- (void)removeAllFileWaiters;
- (NSUInteger)fileWaiterCount:(NSInteger)fileId;
- (BOOL)hasFileWaiterRecord:(NSInteger)fileId;
- (NSInteger)fileWaiterPriority:(NSInteger)fileId;

@end
