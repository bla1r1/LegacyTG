//
// TGUpdateStore.m - the daily update check and the release it parses.
//
#import "TGUpdateStore.h"
#import "TGClient.h"
#import "TGDevice.h"
#import "TGLocalization.h"
#import <UIKit/UIKit.h>

NSString *const TGUpdateAvailableNotification = @"TGUpdateAvailableNotification";

static NSString *const TGUpdateLastCheckKey = @"TGUpdateLastCheck";
static NSString *const TGUpdateSkippedBuildKey = @"TGUpdateSkippedBuild";
static NSString *const TGUpdateStatisticsKey = @"TGUsageStatisticsEnabled";

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

NSString *TGUpdateQueryString(NSString *version,
                              NSString *build,
                              NSString *ios,
                              NSString *device,
                              NSString *tier,
                              BOOL jailbroken,
                              NSString *language,
                              BOOL statistics) {
	NSString *query = [NSString stringWithFormat:
			@"lt1 v=%@ b=%@ ios=%@ dev=%@ tier=%@ jb=%d lang=%@ stats=%d",
			version ?: @"", build ?: @"", ios ?: @"", device ?: @"",
			tier ?: @"", jailbroken ? 1 : 0, language ?: @"", statistics ? 1 : 0];
	return TGUpdateTruncate(query, TGUpdateQueryLimit);
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
	if (!forced && !TGUpdateCheckIsDue([NSDate date], lastCheck))
		return;

	NSString *query = TGUpdateQueryString(
			TGUpdateBundleValue(@"CFBundleShortVersionString"),
			TGUpdateBundleValue(@"CFBundleVersion"),
			[UIDevice currentDevice].systemVersion,
			[TGDevice machine],
			TGUpdateTier(),
			[TGUpdateStore isJailbroken],
			TGAppLanguage() ?: @"",
			[TGUpdateStore usageStatisticsEnabled]);

	_checking = YES;
	[client inlineQueryWithBotUsername:TGUpdateBotUsername
							   chatId:chatId
								query:query
						   completion:^(NSArray *results){
		self->_checking = NO;
		[defaults setObject:[NSDate date] forKey:TGUpdateLastCheckKey];
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
