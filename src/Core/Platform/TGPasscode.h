//
// TGPasscode.h - App passcode lock management and security.
//
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const TGPasscodeDidChangeNotification;
FOUNDATION_EXPORT NSString *const TGPasscodeDidLockNotification;
FOUNDATION_EXPORT NSString *const TGPasscodeDidUnlockNotification;

@interface TGPasscode : NSObject

+ (BOOL)hasPasscode;
/// NO for a wrong PIN, and NO without looking while retryDelay is running.
/// A PIN stored by an older build (bare SHA-256 in the defaults) is moved to
/// the keychain record the first time it is entered correctly.
+ (BOOL)verifyPasscode:(NSString *)pin;
/// Seconds until the next entry is looked at: 0 for the first four wrong
/// entries, then 1, 5, 15 and 60 minutes. Survives a relaunch.
+ (NSTimeInterval)retryDelay;
+ (void)setPasscode:(NSString *)pin;
+ (void)clearPasscode;

/// Seconds before the app locks itself while backgrounded:
/// 0: immediately
/// 60: 1 minute
/// 300: 5 minutes (default)
/// 3600: 1 hour
/// -1: disabled
+ (NSInteger)autoLockTimeout;
+ (void)setAutoLockTimeout:(NSInteger)seconds;
+ (NSString *)autoLockTitleForSeconds:(NSInteger)seconds;

+ (BOOL)isLocked;
+ (void)setLocked:(BOOL)locked;
+ (void)noteAppBackgrounded;
+ (BOOL)shouldLockOnForeground;

@end
