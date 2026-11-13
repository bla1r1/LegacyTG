//
// TGPasscode.m - App passcode lock management and security.
//
#import "TGPasscode.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>

#if TARGET_OS_IPHONE
#import <Security/Security.h>
#endif

NSString *const TGPasscodeDidChangeNotification = @"TGPasscodeDidChangeNotification";
NSString *const TGPasscodeDidLockNotification   = @"TGPasscodeDidLockNotification";
NSString *const TGPasscodeDidUnlockNotification = @"TGPasscodeDidUnlockNotification";

/// What builds up to this one stored: a bare SHA-256 of the PIN, in the
/// defaults plist. Ten thousand hashes find a four-digit PIN and the plist is
/// in every backup. Read only to move it; never written again.
static NSString *const kPrefLegacyHash    = @"TGPasscodeHash";
/// YES while a record exists. The keychain outlives a deleted app and the
/// defaults do not, so a reinstall starts without a passcode instead of
/// asking for the one a previous install set.
static NSString *const kPrefPasscodeSet   = @"TGPasscodeSet";
static NSString *const kPrefFailedCount   = @"TGPasscodeFailedAttempts";
static NSString *const kPrefRetryAfter    = @"TGPasscodeRetryAfter";
static NSString *const kPrefAutoLockSecs  = @"TGPasscodeAutoLockSecs";

/// The record: 4 bytes of round count (big endian), 16 of salt, 32 of key.
enum { kSaltSize = 16, kKeySize = 32, kRecordSize = 4 + kSaltSize + kKeySize };
/// About 0.4 s on an A4. With four digits no round count survives an offline
/// search; what protects the PIN is that the record is in the keychain, on
/// this device only, and that the screen makes a wrong guess wait.
static const uint32_t kRounds = 10000;
/// Wrong entries allowed before the wait starts, and the waits after that.
static const NSInteger kFreeAttempts = 4;
static const NSTimeInterval kRetryWaits[] = {60, 300, 900, 3600};

static BOOL s_isLocked = NO;
static NSTimeInterval s_backgroundTime = 0;

static NSString *TGLegacyHashPIN(NSString *pin) {
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

static BOOL TGDeriveKey(NSString *pin, const uint8_t *salt, uint32_t rounds,
						uint8_t key[kKeySize]) {
	const char *utf8 = pin.UTF8String;
	if (!utf8 || !rounds)
		return NO;
	return CCKeyDerivationPBKDF(kCCPBKDF2, utf8, strlen(utf8), salt, kSaltSize,
			kCCPRFHmacAlgSHA256, rounds, key, kKeySize) == kCCSuccess;
}

/// Compare without letting the time taken say how far the match got.
static BOOL TGSameBytes(const uint8_t *a, const uint8_t *b, size_t size) {
	volatile uint8_t differs = 0;
	for (size_t i = 0; i < size; i++)
		differs |= (uint8_t)(a[i] ^ b[i]);
	return differs == 0;
}

static NSData *TGRecordForPIN(NSString *pin) {
	uint8_t record[kRecordSize];
	record[0] = (uint8_t)(kRounds >> 24);
	record[1] = (uint8_t)(kRounds >> 16);
	record[2] = (uint8_t)(kRounds >> 8);
	record[3] = (uint8_t)kRounds;
	arc4random_buf(record + 4, kSaltSize);
	if (!TGDeriveKey(pin, record + 4, kRounds, record + 4 + kSaltSize))
		return nil;
	return [NSData dataWithBytes:record length:kRecordSize];
}

static BOOL TGRecordMatchesPIN(NSData *record, NSString *pin) {
	if (record.length != kRecordSize)
		return NO;
	const uint8_t *bytes = record.bytes;
	uint32_t rounds = ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) |
					  ((uint32_t)bytes[2] << 8)  |  (uint32_t)bytes[3];
	// A record is ours or it is damaged; a count nobody wrote is not obeyed.
	if (rounds == 0 || rounds > 1000000)
		return NO;
	uint8_t key[kKeySize];
	if (!TGDeriveKey(pin, bytes + 4, rounds, key))
		return NO;
	return TGSameBytes(key, bytes + 4 + kSaltSize, kKeySize);
}

#pragma mark - where the record lives

#if TARGET_OS_IPHONE

static NSMutableDictionary *TGPasscodeQuery(void) {
	return [@{
		(__bridge id)kSecClass       : (__bridge id)kSecClassGenericPassword,
		(__bridge id)kSecAttrService : @"com.legacytg.passcode",
		(__bridge id)kSecAttrAccount : @"passcode",
	} mutableCopy];
}

static NSData *TGReadRecord(void) {
	NSMutableDictionary *query = TGPasscodeQuery();
	query[(__bridge id)kSecReturnData] = @YES;
	query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
	CFTypeRef result = NULL;
	if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) == errSecSuccess && result)
		return (__bridge_transfer NSData *)result;
	return nil;
}

/// nil removes the record.
static BOOL TGWriteRecord(NSData *record) {
	NSMutableDictionary *query = TGPasscodeQuery();
	OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
	if (!record)
		return status == errSecSuccess || status == errSecItemNotFound;
	query[(__bridge id)kSecValueData] = record;
	// Not in a backup and not on another device. After first unlock, so a
	// launch in the background can still tell that a passcode is set.
	query[(__bridge id)kSecAttrAccessible] =
			(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
	return SecItemAdd((__bridge CFDictionaryRef)query, NULL) == errSecSuccess;
}

#else

static NSString *const kPrefHostRecord = @"TGPasscodeRecord";

static NSData *TGReadRecord(void) {
	return [[NSUserDefaults standardUserDefaults] dataForKey:kPrefHostRecord];
}

static BOOL TGWriteRecord(NSData *record) {
	if (record)
		[[NSUserDefaults standardUserDefaults] setObject:record forKey:kPrefHostRecord];
	else
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:kPrefHostRecord];
	return YES;
}

#endif

/// Writes the record for `pin` and drops the legacy hash. NO leaves whatever
/// was there before untouched.
static BOOL TGStorePIN(NSString *pin) {
	NSData *record = TGRecordForPIN(pin);
	if (!record || !TGWriteRecord(record))
		return NO;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:YES forKey:kPrefPasscodeSet];
	[defaults removeObjectForKey:kPrefLegacyHash];
	[defaults synchronize];
	return YES;
}

@implementation TGPasscode

+ (BOOL)hasPasscode {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	// The flag, not the record: a keychain that cannot be read right now must
	// not look like "no passcode".
	return [defaults boolForKey:kPrefPasscodeSet] ||
			[defaults stringForKey:kPrefLegacyHash].length > 0;
}

+ (NSTimeInterval)retryDelay {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSTimeInterval after = [defaults doubleForKey:kPrefRetryAfter];
	if (after <= 0)
		return 0;
	NSTimeInterval left = after - [NSDate timeIntervalSinceReferenceDate];
	if (left <= 0)
		return 0;
	// A clock set back must not turn an hour into a year.
	NSTimeInterval longest = kRetryWaits[sizeof(kRetryWaits) / sizeof(kRetryWaits[0]) - 1];
	return MIN(left, longest);
}

+ (void)noteAttempt:(BOOL)succeeded {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (succeeded){
		[defaults removeObjectForKey:kPrefFailedCount];
		[defaults removeObjectForKey:kPrefRetryAfter];
		[defaults synchronize];
		return;
	}
	NSInteger failed = [defaults integerForKey:kPrefFailedCount] + 1;
	[defaults setInteger:failed forKey:kPrefFailedCount];
	if (failed > kFreeAttempts){
		NSInteger last = (NSInteger)(sizeof(kRetryWaits) / sizeof(kRetryWaits[0])) - 1;
		NSInteger step = MIN(failed - kFreeAttempts - 1, last);
		[defaults setDouble:[NSDate timeIntervalSinceReferenceDate] + kRetryWaits[step]
					 forKey:kPrefRetryAfter];
	}
	// Written before the answer is shown: killing the app does not hand the
	// attempt back.
	[defaults synchronize];
}

+ (BOOL)verifyPasscode:(NSString *)pin {
	if (!pin.length || ![self hasPasscode]) return NO;
	if ([self retryDelay] > 0) return NO;

	BOOL matches = NO;
	NSString *legacy = [[NSUserDefaults standardUserDefaults] stringForKey:kPrefLegacyHash];
	if (legacy.length){
		matches = [legacy isEqualToString:TGLegacyHashPIN(pin)];
		// The one moment the PIN itself is in hand: move it now. If the
		// keychain refuses, the old hash stays and the next unlock tries again.
		if (matches && !TGStorePIN(pin))
			NSLog(@"TGPasscode: could not move the passcode to the keychain");
	} else {
		matches = TGRecordMatchesPIN(TGReadRecord(), pin);
	}
	[self noteAttempt:matches];
	return matches;
}

+ (void)setPasscode:(NSString *)pin {
	if (!pin.length) {
		[self clearPasscode];
		return;
	}
	if (!TGStorePIN(pin)){
		NSLog(@"TGPasscode: the keychain refused the passcode; nothing was set");
		return;
	}
	[self noteAttempt:YES];
	[[NSNotificationCenter defaultCenter] postNotificationName:TGPasscodeDidChangeNotification object:nil];
}

+ (void)clearPasscode {
	TGWriteRecord(nil);
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:kPrefPasscodeSet];
	[defaults removeObjectForKey:kPrefLegacyHash];
	[defaults removeObjectForKey:kPrefFailedCount];
	[defaults removeObjectForKey:kPrefRetryAfter];
	[defaults synchronize];
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
