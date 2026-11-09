//
// TGUpdateStore.h - what the update screen and the app delegate may ask.
//
// The check itself, the skipped build and the usage-statistics switch live
// behind this header. Views never touch TGClient for any of it.
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Posted on the main queue with the TGUpdateInfo in userInfo[@"info"] when a
/// usable update arrives.
extern NSString *const TGUpdateAvailableNotification;

/// The exact line M45 sends: lt1 v=.. b=.. ios=.. dev=.. tier=.. jb=.. lang=..
/// stats=.., capped at 256 UTF-8 bytes.
NSString *TGUpdateQueryString(NSString *version,
                              NSString *build,
                              NSString *ios,
                              NSString *device,
                              NSString *tier,
                              BOOL jailbroken,
                              NSString *language,
                              BOOL statistics);

/// YES when no check has run yet or the last one is at least a day old.
BOOL TGUpdateCheckIsDue(NSDate *now, NSDate *lastCheck);

@class TGUpdateInfo;

/// Parses the two inline results. Nil when there is no newer build, when the
/// update JSON is malformed, or when the build is the one the user skipped
/// and the release is not blocking.
TGUpdateInfo *TGUpdateInfoFromInlineResults(NSArray *results,
                                            NSInteger currentBuild,
                                            NSInteger skippedBuild);

#ifdef __cplusplus
}
#endif

/// One release the bot named. Immutable: a screen only reads it.
@interface TGUpdateInfo : NSObject

@property (nonatomic, copy, readonly) NSString *version;
@property (nonatomic, assign, readonly) NSInteger build;
@property (nonatomic, copy, readonly) NSString *minimumIOS;
@property (nonatomic, assign, readonly, getter=isBlocking) BOOL blocking;
@property (nonatomic, copy, readonly) NSString *ipaURL;
@property (nonatomic, copy, readonly) NSString *cydiaURL;
@property (nonatomic, copy, readonly) NSString *changelog;

- (instancetype)initWithVersion:(NSString *)version
                           build:(NSInteger)build
                      minimumIOS:(NSString *)minimumIOS
                        blocking:(BOOL)blocking
                          ipaURL:(NSString *)ipaURL
                        cydiaURL:(NSString *)cydiaURL
                       changelog:(NSString *)changelog;

@end

@interface TGUpdateStore : NSObject

+ (TGUpdateStore *)shared;

/// Runs the bot check when it is due, or always when `forced`. Any error is
/// silent; the next due check tries again.
- (void)checkIfDue:(BOOL)forced;

/// /Applications/Cydia.app. The screen opens the cydia URL only here.
+ (BOOL)isJailbroken;

/// On by default: an absent defaults value means YES.
+ (BOOL)usageStatisticsEnabled;
+ (void)setUsageStatisticsEnabled:(BOOL)enabled;

/// The build the user pressed Skip on, or 0. A blocking release ignores it.
+ (NSInteger)skippedBuild;
+ (void)skipBuild:(NSInteger)build;

@end
