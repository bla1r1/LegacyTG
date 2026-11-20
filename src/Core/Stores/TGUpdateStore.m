//
// TGUpdateStore.m - the daily update check and the release it parses.
//
#import "TGUpdateStore.h"
#import "TGClient.h"
#import "TGDevice.h"
#import "TGLocalization.h"
#import "TGDatabaseKey.h"
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>

NSString *const TGUpdateAvailableNotification = @"TGUpdateAvailableNotification";

static NSString *const TGUpdateLastCheckKey = @"TGUpdateLastCheck";
static NSString *const TGUpdateSkippedBuildKey = @"TGUpdateSkippedBuild";
static NSString *const TGUpdateStatisticsKey = @"TGUsageStatisticsEnabled";
static NSString *const TGUpdateSessionOpenKey = @"TGUpdateSessionIsOpen";
static NSString *const TGUpdateActiveScreenKey = @"TGUpdateActiveScreen";
static NSString *const TGUpdateCrashMarkerKey = @"TGUpdateLastCrashMarker";

// The bot that answers the daily update check. The name is compiled in, so a
// rename needs a build. Inline mode must stay on.
static NSString *const TGUpdateBotUsername = @"LegacyTGbot";

static const NSTimeInterval TGUpdateCheckInterval = 24.0 * 60.0 * 60.0;
static const NSTimeInterval TGUpdateAccountWait = 2.0;
static const NSInteger TGUpdateAccountWaits = 15;
static const NSUInteger TGUpdateQueryLimit = 256;

#pragma mark - pure logic

/// Cut at a UTF-8 boundary, not in the middle of a multi-byte character.
static NSString *TGUpdateTruncate(NSString *text, NSUInteger limit) {
	NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
	if (data.length <= limit)
		return text;
	for (NSUInteger length = limit; length > 0; length--){
		NSData *part = [data subdataWithRange:NSMakeRange(0, length)];
		NSString *candidate = [[NSString alloc] initWithData:part
												   encoding:NSUTF8StringEncoding];
		if (candidate)
			return candidate;
	}
	return @"";
}

NSString *TGUpdateQueryStringWithTelemetry(NSString *version,
                                           NSString *build,
                                           NSString *ios,
                                           NSString *device,
                                           NSString *tier,
                                           BOOL jailbroken,
                                           NSString *language,
                                           BOOL statistics,
                                           BOOL crashed,
                                           NSString *source,
                                           NSInteger dc,
                                           NSString *crashDetail,
                                           NSString *did) {
	NSMutableString *query = [NSMutableString stringWithFormat:
			@"lt1 v=%@ b=%@ ios=%@ dev=%@ tier=%@ jb=%d lang=%@ stats=%d",
			version ?: @"", build ?: @"", ios ?: @"", device ?: @"",
			tier ?: @"", jailbroken ? 1 : 0, language ?: @"", statistics ? 1 : 0];

	if (did.length) {
		[query appendFormat:@" did=%@", did];
	}
	if (crashed) {
		[query appendString:@" cr=1"];
		if (crashDetail.length) {
			[query appendFormat:@" cdet=%@", crashDetail];
		}
	}
	if (source.length) {
		[query appendFormat:@" src=%@", source];
	}
	if (dc > 0 && dc <= 5) {
		[query appendFormat:@" dc=%ld", (long)dc];
	}

	return TGUpdateTruncate(query, TGUpdateQueryLimit);
}

NSInteger TGUpdateParseDatacenterFromBinlogData(NSData *data) {
	if (!data.length)
		return 0;
	const uint8_t *bytes = (const uint8_t *)data.bytes;
	NSUInteger len = data.length;
	const char key[] = "main_dc_id";
	const NSUInteger keyLen = sizeof(key) - 1;

	if (len < keyLen + 2)
		return 0;

	for (NSInteger i = (NSInteger)(len - keyLen - 2); i >= 0; i--) {
		if (memcmp(bytes + i, key, keyLen) == 0) {
			NSUInteger searchEnd = MIN(len, (NSUInteger)(i + keyLen + 12));
			for (NSUInteger j = (NSUInteger)(i + keyLen); j < searchEnd; j++) {
				// 1. TL string format: length 0x01 followed by ASCII digit '1'..'5'
				if (bytes[j] == 0x01 && (j + 1 < len)) {
					uint8_t val = bytes[j + 1];
					if (val >= '1' && val <= '5') {
						return (NSInteger)(val - '0');
					}
				}
				// 2. Direct ASCII digit '1'..'5' preceded by delimiter
				if (bytes[j] >= '1' && bytes[j] <= '5') {
					if (j > 0) {
						uint8_t prev = bytes[j - 1];
						if (prev == 0x00 || prev == 0x01 || prev == ':' || prev == '=' || prev == ' ') {
							return (NSInteger)(bytes[j] - '0');
						}
					}
				}
				// 3. Binary int32 (1..5 followed by three zero bytes)
				if (bytes[j] >= 1 && bytes[j] <= 5 && j + 3 < len) {
					if (bytes[j + 1] == 0 && bytes[j + 2] == 0 && bytes[j + 3] == 0) {
						return (NSInteger)bytes[j];
					}
				}
			}
		}
	}
	return 0;
}

NSInteger TGUpdateParseDatacenterFromBinlogFile(NSString *path) {
	if (!path.length)
		return 0;
	NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
	if (!handle)
		return 0;

	unsigned long long fileSize = [handle seekToEndOfFile];
	if (fileSize < 128) {
		[handle closeFile];
		return 0;
	}

	[handle seekToFileOffset:0];
	NSData *headerData = [handle readDataOfLength:128];
	if (headerData.length < 128) {
		[handle closeFile];
		return 0;
	}

	const uint8_t *h = (const uint8_t *)headerData.bytes;
	int32_t eventType = (int32_t)(h[12] | (h[13] << 8) | (h[14] << 16) | (h[15] << 24));
	if (eventType == -3) {
		uint8_t saltLen = h[0x20];
		if (saltLen == 32) {
			const uint8_t *salt = h + 0x21;
			uint8_t ivLen = h[0x44];
			if (ivLen == 16) {
				const uint8_t *iv = h + 0x45;
				NSData *customKey = [TGDatabaseKey currentKey];
				const char *keyPass = customKey.length ? (const char *)customKey.bytes : "cucumber";
				size_t keyPassLen = customKey.length ? customKey.length : 8;

				uint8_t key[32];
				CCKeyDerivationPBKDF(kCCPBKDF2, keyPass, keyPassLen, salt, 32, kCCPRFHmacAlgSHA256, 2, key, 32);

				CCCryptorRef cryptor = NULL;
				CCCryptorStatus st = CCCryptorCreateWithMode(kCCDecrypt, kCCModeCTR, kCCAlgorithmAES, ccNoPadding, iv, key, 32, NULL, 0, 0, kCCModeOptionCTR_BE, &cryptor);
				if (st == kCCSuccess && cryptor) {
					unsigned long long readLen = MIN(fileSize - 128, (unsigned long long)131072);
					[handle seekToFileOffset:128];
					NSData *encChunk = [handle readDataOfLength:(NSUInteger)readLen];
					[handle closeFile];

					NSMutableData *decChunk = [NSMutableData dataWithLength:encChunk.length];
					size_t moved = 0;
					st = CCCryptorUpdate(cryptor, encChunk.bytes, encChunk.length, decChunk.mutableBytes, decChunk.length, &moved);
					CCCryptorRelease(cryptor);
					if (st == kCCSuccess) {
						decChunk.length = moved;
						return TGUpdateParseDatacenterFromBinlogData(decChunk);
					}
					return 0;
				}
			}
		}
	}

	// Plaintext fallback (if unencrypted binlog)
	unsigned long long readLen = MIN(fileSize, (unsigned long long)131072);
	[handle seekToFileOffset:fileSize - readLen];
	NSData *tailChunk = [handle readDataToEndOfFile];
	NSInteger dc = TGUpdateParseDatacenterFromBinlogData(tailChunk);

	if (dc == 0 && fileSize > readLen) {
		[handle seekToFileOffset:0];
		NSData *headChunk = [handle readDataOfLength:(NSUInteger)readLen];
		dc = TGUpdateParseDatacenterFromBinlogData(headChunk);
	}
	[handle closeFile];
	return dc;
}

NSString *TGUpdateQueryString(NSString *version,
                              NSString *build,
                              NSString *ios,
                              NSString *device,
                              NSString *tier,
                              BOOL jailbroken,
                              NSString *language,
                              BOOL statistics) {
	return TGUpdateQueryStringWithTelemetry(version, build, ios, device, tier,
	                                        jailbroken, language, statistics,
	                                        NO, nil, 0, nil, nil);
}

BOOL TGUpdateCheckIsDue(NSDate *now, NSDate *lastCheck) {
	if (!lastCheck)
		return YES;
	return [now timeIntervalSinceDate:lastCheck] >= TGUpdateCheckInterval;
}

static NSDictionary *TGUpdateJSON(NSString *text) {
	if (![text isKindOfClass:NSString.class] || !text.length)
		return nil;
	NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
	if (!data.length)
		return nil;
	id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
	return [object isKindOfClass:NSDictionary.class] ? object : nil;
}

TGUpdateInfo *TGUpdateInfoFromInlineResults(NSArray *results,
                                            NSInteger currentBuild,
                                            NSInteger skippedBuild) {
	if (![results isKindOfClass:NSArray.class])
		return nil;

	NSDictionary *updateResult = nil;
	NSString *changelog = nil;
	for (id item in results){
		if (![item isKindOfClass:NSDictionary.class])
			continue;
		NSString *resultId = item[@"id"];
		if (![resultId isKindOfClass:NSString.class])
			continue;
		if ([resultId isEqualToString:@"update"] && !updateResult){
			updateResult = item;
		} else if ([resultId isEqualToString:@"notes"] && !changelog){
			id description = item[@"description"];
			if ([description isKindOfClass:NSString.class])
				changelog = description;
		}
	}
	if (!updateResult)
		return nil;

	NSDictionary *json = TGUpdateJSON(updateResult[@"description"]);
	if (!json)
		return nil;

	id buildValue = json[@"b"];
	NSInteger build = 0;
	if ([buildValue isKindOfClass:NSNumber.class])
		build = [buildValue integerValue];
	else if ([buildValue isKindOfClass:NSString.class])
		build = [buildValue integerValue];
	else
		return nil;

	// The answer may name an old release after a downgrade; it is not an
	// update to anything the user is already running.
	if (build <= currentBuild)
		return nil;

	id blockingValue = json[@"blocking"];
	BOOL blocking = [blockingValue respondsToSelector:@selector(boolValue)]
			? [blockingValue boolValue] : NO;
	if (!blocking && skippedBuild > 0 && build == skippedBuild)
		return nil;

	NSString *version = nil;
	id versionValue = json[@"v"];
	if ([versionValue isKindOfClass:NSString.class])
		version = versionValue;
	if (!version.length){
		id title = updateResult[@"title"];
		if ([title isKindOfClass:NSString.class])
			version = title;
	}

	NSString *minimumIOS = nil;
	id minimumValue = json[@"min_ios"];
	if ([minimumValue isKindOfClass:NSString.class])
		minimumIOS = minimumValue;

	NSString *ipaURL = nil;
	id ipaValue = json[@"ipa"];
	if ([ipaValue isKindOfClass:NSString.class])
		ipaURL = ipaValue;

	NSString *cydiaURL = nil;
	id cydiaValue = json[@"cydia"];
	if ([cydiaValue isKindOfClass:NSString.class])
		cydiaURL = cydiaValue;

	return [[TGUpdateInfo alloc] initWithVersion:version ?: @""
										   build:build
									  minimumIOS:minimumIOS ?: @""
										blocking:blocking
										  ipaURL:ipaURL ?: @""
										cydiaURL:cydiaURL ?: @""
									   changelog:changelog ?: @""];
}

#pragma mark - record

@implementation TGUpdateInfo

- (instancetype)initWithVersion:(NSString *)version
                           build:(NSInteger)build
                      minimumIOS:(NSString *)minimumIOS
                        blocking:(BOOL)blocking
                          ipaURL:(NSString *)ipaURL
                        cydiaURL:(NSString *)cydiaURL
                       changelog:(NSString *)changelog {
	self = [super init];
	if (!self)
		return nil;
	_version = [version copy];
	_build = build;
	_minimumIOS = [minimumIOS copy];
	_blocking = blocking;
	_ipaURL = [ipaURL copy];
	_cydiaURL = [cydiaURL copy];
	_changelog = [changelog copy];
	return self;
}

@end

#pragma mark - store

static NSString *TGUpdateBundleValue(NSString *key) {
	id value = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
	if ([value isKindOfClass:NSString.class])
		return value;
	return value ? [value description] : @"";
}

static NSString *TGUpdateTier(void) {
	switch ([TGDevice tier]){
		case TGDeviceTierVintage: return @"vintage";
		case TGDeviceTierLegacy:  return @"legacy";
		case TGDeviceTierModern:  return @"modern";
		default:                  return @"full";
	}
}

static BOOL TGUpdateStatisticsEnabled(void) {
	id value = [[NSUserDefaults standardUserDefaults]
			objectForKey:TGUpdateStatisticsKey];
	return value ? [value boolValue] : YES;
}

@interface TGUpdateStore ()
- (void)runCheckIfDue:(BOOL)forced waitsLeft:(NSInteger)waitsLeft;
@end

@implementation TGUpdateStore {
	BOOL _checking;
	BOOL _waitingForAccount;
}

+ (TGUpdateStore *)shared {
	static TGUpdateStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		store = [[TGUpdateStore alloc] init];
	});
	return store;
}

+ (BOOL)isJailbroken {
	return [[NSFileManager defaultManager]
			fileExistsAtPath:@"/Applications/Cydia.app"];
}

+ (NSString *)distributionSource {
	NSString *path = [[NSBundle mainBundle] bundlePath];
	if ([path hasPrefix:@"/Applications/"]) {
		return @"deb";
	}
	return @"ipa";
}

+ (void)noteActiveScreen:(NSString *)screen {
	if (!screen.length) return;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:screen forKey:TGUpdateActiveScreenKey];
}

+ (void)sessionDidStart {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:TGUpdateSessionOpenKey]) {
		NSString *lastScreen = [defaults stringForKey:TGUpdateActiveScreenKey] ?: @"App";
		[defaults setObject:[NSString stringWithFormat:@"OOM@%@", lastScreen] forKey:TGUpdateCrashMarkerKey];
	}
	[defaults setBool:YES forKey:TGUpdateSessionOpenKey];
	[defaults synchronize];
}

+ (void)sessionDidEnd {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:NO forKey:TGUpdateSessionOpenKey];
	[defaults synchronize];
}

+ (BOOL)usageStatisticsEnabled {
	return TGUpdateStatisticsEnabled();
}

+ (void)setUsageStatisticsEnabled:(BOOL)enabled {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:enabled forKey:TGUpdateStatisticsKey];
	[defaults synchronize];
}

+ (NSInteger)skippedBuild {
	return [[NSUserDefaults standardUserDefaults]
			integerForKey:TGUpdateSkippedBuildKey];
}

+ (void)skipBuild:(NSInteger)build {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setInteger:build forKey:TGUpdateSkippedBuildKey];
	[defaults synchronize];
}

+ (NSInteger)currentDatacenterId {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *defaultsKey = @"TGAccountMainDC";

	NSInteger cached = [defaults integerForKey:defaultsKey];
	if (cached >= 1 && cached <= 5)
		return cached;

	NSInteger slot = [TGClient activeAccountSlot];
	NSMutableArray *candidates = [NSMutableArray array];
	NSString *db = TGAccountResolvedDatabaseDirectory(slot);
	if (db.length)
		[candidates addObject:[db stringByAppendingPathComponent:@"td.binlog"]];

	NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	if (documents.length) {
		NSString *old = TGAccountDatabaseDirectory(documents, slot);
		if (old.length)
			[candidates addObject:[old stringByAppendingPathComponent:@"td.binlog"]];
	}

	NSLog(@"[TGUpdateStore] Looking for DC in candidates: %@", candidates);

	for (NSString *binlogPath in candidates) {
		NSInteger dc = TGUpdateParseDatacenterFromBinlogFile(binlogPath);
		if (dc >= 1 && dc <= 5) {
			NSLog(@"[TGUpdateStore] Found DC %ld in binlog: %@", (long)dc, binlogPath);
			[defaults setInteger:dc forKey:defaultsKey];
			[defaults synchronize];
			return dc;
		}
	}

	NSLog(@"[TGUpdateStore] DC not found in candidates");
	return 0;
}

static NSString *const TGUpdateDeviceIdentifierKey = @"TGUpdateDeviceIdentifier";
static NSString *const TGUpdateLastReportedBuildKey = @"TGUpdateLastReportedBuild";

+ (NSString *)deviceIdentifier {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *did = [defaults stringForKey:TGUpdateDeviceIdentifierKey];
	if (did.length == 16)
		return did;

	uint8_t bytes[8];
	arc4random_buf(bytes, sizeof(bytes));
	char hex[17];
	for (int i = 0; i < 8; i++) {
		sprintf(hex + i * 2, "%02x", bytes[i]);
	}
	hex[16] = '\0';
	did = [NSString stringWithUTF8String:hex];
	[defaults setObject:did forKey:TGUpdateDeviceIdentifierKey];
	[defaults synchronize];
	return did;
}

- (void)checkIfDue:(BOOL)forced {
	if (![NSThread isMainThread]){
		dispatch_async(dispatch_get_main_queue(), ^{
			[self checkIfDue:forced];
		});
		return;
	}
	if (_checking || _waitingForAccount)
		return;
	[self runCheckIfDue:forced waitsLeft:TGUpdateAccountWaits];
}

- (void)runCheckIfDue:(BOOL)forced waitsLeft:(NSInteger)waitsLeft {
	TGClient *client = [TGClient shared];
	if (client.authState != TGAuthStateReady)
		return;

	int64_t chatId = [client savedMessagesChatId];
	// Auth is ready before getMe names the account, and Saved Messages is
	// that id. Wait for it rather than spending the daily check on a no-op.
	if (!chatId){
		if (waitsLeft <= 0)
			return;
		_waitingForAccount = YES;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
				(int64_t)(TGUpdateAccountWait * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
			self->_waitingForAccount = NO;
			[self runCheckIfDue:forced waitsLeft:waitsLeft - 1];
		});
		return;
	}

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDate *lastCheck = [defaults objectForKey:TGUpdateLastCheckKey];
	if (![lastCheck isKindOfClass:NSDate.class])
		lastCheck = nil;

	NSString *currentBuild = TGUpdateBundleValue(@"CFBundleVersion");
	NSString *lastReportedBuild = [defaults stringForKey:TGUpdateLastReportedBuildKey];
	BOOL buildChanged = currentBuild.length && ![currentBuild isEqualToString:lastReportedBuild];

	NSInteger dc = [TGUpdateStore currentDatacenterId];
	NSInteger lastReportedDC = [defaults integerForKey:@"TGUpdateLastReportedDC"];
	BOOL dcBecameAvailable = (dc > 0 && lastReportedDC == 0);

	if (!forced && !buildChanged && !dcBecameAvailable && !TGUpdateCheckIsDue([NSDate date], lastCheck)) {
		NSLog(@"[TGUpdateStore] Check skipped (not due, lastCheck=%@, build=%@, dc=%ld)", lastCheck, currentBuild, (long)dc);
		return;
	}

	NSString *crashDetail = [defaults stringForKey:TGUpdateCrashMarkerKey];
	BOOL crashed = crashDetail.length > 0;
	NSString *source = [TGUpdateStore distributionSource];
	NSString *did = [TGUpdateStore deviceIdentifier];

	NSString *query = TGUpdateQueryStringWithTelemetry(
			TGUpdateBundleValue(@"CFBundleShortVersionString"),
			currentBuild,
			[UIDevice currentDevice].systemVersion,
			[TGDevice machine],
			TGUpdateTier(),
			[TGUpdateStore isJailbroken],
			TGAppLanguage() ?: @"",
			[TGUpdateStore usageStatisticsEnabled],
			crashed,
			source,
			dc,
			crashDetail,
			did);

	NSLog(@"[TGUpdateStore] Sending telemetry query: %@", query);

	_checking = YES;
	[client inlineQueryWithBotUsername:TGUpdateBotUsername
							   chatId:chatId
								query:query
						   completion:^(NSArray *results){
		NSLog(@"[TGUpdateStore] Telemetry response received (%lu items)", (unsigned long)results.count);
		self->_checking = NO;
		[defaults setObject:[NSDate date] forKey:TGUpdateLastCheckKey];
		if (currentBuild.length) {
			[defaults setObject:currentBuild forKey:TGUpdateLastReportedBuildKey];
		}
		if (dc > 0) {
			[defaults setInteger:dc forKey:@"TGUpdateLastReportedDC"];
		}
		if (crashed) {
			[defaults removeObjectForKey:TGUpdateCrashMarkerKey];
		}
		[defaults synchronize];
		if (!results)
			return;

		NSInteger currentBuild = [TGUpdateBundleValue(@"CFBundleVersion") integerValue];
		NSInteger skippedBuild = [TGUpdateStore skippedBuild];
		TGUpdateInfo *info = TGUpdateInfoFromInlineResults(results,
														  currentBuild,
														  skippedBuild);
		if (!info)
			return;
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGUpdateAvailableNotification
								  object:self
								userInfo:@{@"info" : info}];
		});
	}];
}

@end
