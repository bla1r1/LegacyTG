//
// TGPasscode.m - App passcode lock management and security.
//
#import "TGPasscode.h"
#import <CommonCrypto/CommonDigest.h>

NSString *const TGPasscodeDidChangeNotification = @"TGPasscodeDidChangeNotification";
NSString *const TGPasscodeDidLockNotification   = @"TGPasscodeDidLockNotification";
NSString *const TGPasscodeDidUnlockNotification = @"TGPasscodeDidUnlockNotification";

static NSString *const kPrefPasscodeHash  = @"TGPasscodeHash";
static NSString *const kPrefAutoLockSecs  = @"TGPasscodeAutoLockSecs";

static BOOL s_isLocked = NO;
static NSTimeInterval s_backgroundTime = 0;

static NSString *TGHashPIN(NSString *pin) {
	if (!pin.length) return @"";
	const char *str = [pin UTF8String];
	unsigned char result[CC_SHA256_DIGEST_LENGTH];
	CC_SHA256(str, (CC_LONG)strlen(str), result);
	NSMutableString *hash = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
	for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
		[hash appendFormat:@"%02x", result[i]];
	}
	return hash;
}

@implementation TGPasscode

+ (BOOL)hasPasscode {
	NSString *hash = [[NSUserDefaults standardUserDefaults] stringForKey:kPrefPasscodeHash];
	return hash.length > 0;
}

+ (BOOL)verifyPasscode:(NSString *)pin {
	if (!pin.length) return NO;
	NSString *savedHash = [[NSUserDefaults standardUserDefaults] stringForKey:kPrefPasscodeHash];
	if (!savedHash.length) return NO;
	NSString *inputHash = TGHashPIN(pin);
	return [savedHash isEqualToString:inputHash];
}

+ (void)setPasscode:(NSString *)pin {
	if (!pin.length) {
		[self clearPasscode];
		return;
	}
	NSString *hash = TGHashPIN(pin);
	[[NSUserDefaults standardUserDefaults] setObject:hash forKey:kPrefPasscodeHash];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:TGPasscodeDidChangeNotification object:nil];
}

+ (void)clearPasscode {
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kPrefPasscodeHash];
	[[NSUserDefaults standardUserDefaults] synchronize];
	s_isLocked = NO;
	[[NSNotificationCenter defaultCenter] postNotificationName:TGPasscodeDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:TGPasscodeDidUnlockNotification object:nil];
}

+ (NSInteger)autoLockTimeout {
	id val = [[NSUserDefaults standardUserDefaults] objectForKey:kPrefAutoLockSecs];
	if (!val) return 300; // default 5 min
	return [val integerValue];
}

+ (void)setAutoLockTimeout:(NSInteger)seconds {
	[[NSUserDefaults standardUserDefaults] setInteger:seconds forKey:kPrefAutoLockSecs];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)autoLockTitleForSeconds:(NSInteger)seconds {
	// Zero is what older builds stored for "Immediately"; the official option
	// set has no such choice, and 0 now means Disabled. A negative value is
	// the value the current page writes for Disabled.
	if (seconds <= 0) return @"Disabled";
	if (seconds == 60) return @"If away for 1 min";
	if (seconds == 300) return @"If away for 5 min";
	if (seconds == 3600) return @"If away for 1 hour";
	if (seconds == 18000) return @"If away for 5 hours";
	return [NSString stringWithFormat:@"If away for %ld min", (long)(seconds / 60)];
}

+ (BOOL)isLocked {
	return s_isLocked && [self hasPasscode];
}

+ (void)setLocked:(BOOL)locked {
	if (![self hasPasscode]) {
		s_isLocked = NO;
		return;
	}
	s_isLocked = locked;
	if (locked) {
		[[NSNotificationCenter defaultCenter] postNotificationName:TGPasscodeDidLockNotification object:nil];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:TGPasscodeDidUnlockNotification object:nil];
	}
}

+ (void)noteAppBackgrounded {
	if (![self hasPasscode]) return;
	NSInteger timeout = [self autoLockTimeout];
	if (timeout < 0) return; // disabled
	s_backgroundTime = [NSDate timeIntervalSinceReferenceDate];
}

+ (BOOL)shouldLockOnForeground {
	if (![self hasPasscode]) return NO;
	if (s_isLocked) return YES;
	NSInteger timeout = [self autoLockTimeout];
	// Zero is a legacy "lock immediately" value; it now means Disabled like
	// every negative value, so an existing installation does not surprise
	// the user with a lock the page calls Disabled.
	if (timeout <= 0) return NO;
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (s_backgroundTime > 0 && (now - s_backgroundTime) >= (NSTimeInterval)timeout) {
		s_isLocked = YES;
		return YES;
	}
	return NO;
}

@end
