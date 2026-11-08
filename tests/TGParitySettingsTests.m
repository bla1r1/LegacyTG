// TGParitySettingsTests.m — settings value formatting parity.
//
// The unit strings, the privacy exception templates and the account lifetime
// are pack keys, so a value glued together by hand stayed English or drifted
// by a day. These are the pure helpers that fix that, pinned without UIKit.
#import "TGTestRunner.h"
#import "TGSettingsFormatting.h"
#import "TGPasscode.h"
#import "TGClient.h"
#import "TGClientInternal.h"

static TGClient *TPSSettingsClient(void) {
	TGClient *c = TGClient.shared;
	[c.outbox removeAllObjects];
	[c.pendingRequests removeAllObjects];
	return c;
}

static NSDictionary *TPSDecode(NSData *data) {
	NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
	return [NSJSONSerialization JSONObjectWithData:
			[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

static NSDictionary *TPSLastRequest(TGClient *c, NSString *type) {
	NSDictionary *found = nil;
	for (NSData *data in c.outbox)
		if ([TPSDecode(data)[@"@type"] isEqualToString:type])
			found = TPSDecode(data);
	return found;
}

static void TPSAnswer(TGClient *c, NSDictionary *answer) {
	NSDictionary *sent = nil;
	for (NSData *data in c.outbox)
		if (TPSDecode(data)[@"@extra"])
			sent = TPSDecode(data);
	if (!sent)
		return;
	NSMutableDictionary *reply = [answer mutableCopy];
	reply[@"@extra"] = sent[@"@extra"];
	[c handleUpdate:reply];
}

@interface TGParitySettingsTests : XCTestCase @end

@implementation TGParitySettingsTests

- (void)testPrivacyLabel_BaseValuesArePackWords {
	XCTAssertTrue([TGPrivacyLabel(@"everybody") isEqualToString:@"Everybody"]);
	XCTAssertTrue([TGPrivacyLabel(@"contacts") isEqualToString:@"My Contacts"]);
	XCTAssertTrue([TGPrivacyLabel(@"nobody") isEqualToString:@"Nobody"]);
	XCTAssertTrue([TGPrivacyLabel(@"") isEqualToString:@"Loading..."]);
}

- (void)testPrivacyLabel_CountsUseTheirOwnTemplates {
	// These were built by string surgery ("everybody (-3)") and then looked
	// up whole, so the count never translated.
	XCTAssertTrue([TGPrivacyLabel(@"everybody (-3)") isEqualToString:@"Everybody (-3)"]);
	XCTAssertTrue([TGPrivacyLabel(@"contacts (+4)") isEqualToString:@"My Contacts (+4)"]);
	XCTAssertTrue([TGPrivacyLabel(@"nobody (+3)") isEqualToString:@"Nobody (+3)"]);
}

- (void)testPrivacyLabel_CountTemplatesTranslateAfterTheLookup {
	// A glued "Everybody (-3)" is not a pack key. The template is, so the
	// same value must turn Russian once the pack is loaded. Entries copied
	// from the ru pack.
	NSDictionary *lookup = @{@"Everybody (-%@)" : @"Все (-%@)",
							 @"My Contacts (+%@)" : @"Контакты (+%@)",
							 @"Nobody (+%@)" : @"Никто (+%@)"};
	TGSetTelegramLanguageLookup(lookup);
	XCTAssertTrue([TGPrivacyLabel(@"everybody (-3)") isEqualToString:@"Все (-3)"]);
	XCTAssertTrue([TGPrivacyLabel(@"contacts (+4)") isEqualToString:@"Контакты (+4)"]);
	XCTAssertTrue([TGPrivacyLabel(@"nobody (+3)") isEqualToString:@"Никто (+3)"]);
	TGSetTelegramLanguageLookup(nil);
}

- (void)testBytes_UseThePackUnits {
	XCTAssertTrue([TGBytes(0) isEqualToString:@"0 KB"]);
	XCTAssertTrue([TGBytes(1024 * 1024) isEqualToString:@"1 MB"]);
	XCTAssertTrue([TGBytes(1024LL * 1024 * 1024) isEqualToString:@"1 GB"]);
}

- (void)testBytes_DecimalSeparatorFollowsTheAppLanguage {
	// The phone's locale used to decide this, so a Russian interface showed
	// "1.5 MB" on an English phone while the pack units spoke Russian.
	XCTAssertEqualObjects(TGBytesForLanguage(1536 * 1024, @"en"), @"1.5 MB");
	XCTAssertEqualObjects(TGBytesForLanguage(1536 * 1024, @"ru"), @"1,5 MB");
}

- (void)testUsernameAvailability_NamesTheFourOfficialStates {
	XCTAssertEqualObjects(TGUsernameNormalized(@" @Durov "), @"durov");
	XCTAssertFalse(TGUsernameShouldCheck(@"durov", @"durov"));
	XCTAssertFalse(TGUsernameShouldCheck(@"", @"durov"));
	XCTAssertTrue(TGUsernameShouldCheck(@"durov2", @"durov"));

	XCTAssertEqualObjects(TGUsernameAvailabilityText(@"checking", @"durov"),
						  @"Checking username...");
	XCTAssertEqualObjects(TGUsernameAvailabilityText(@"ok", @"durov"),
						  @"durov is available.");
	XCTAssertEqualObjects(TGUsernameAvailabilityText(@"occupied", @"durov"),
						  @"Sorry, this username is already taken.");
	XCTAssertEqualObjects(TGUsernameAvailabilityText(@"invalid", @"durov"),
						  @"Sorry, this username is invalid.");
	XCTAssertTrue(TGUsernameAnswerStillApplies(@"@Durov", @"durov"));
	XCTAssertFalse(TGUsernameAnswerStillApplies(@"old", @"new"));
}

- (void)testNotificationExceptions_StayInTheirCategory {
	NSDictionary *privateChat = @{@"title" : @"Alpha", @"isGroup" : @NO,
								  @"isChannel" : @NO};
	NSDictionary *group = @{@"title" : @"Beta", @"isGroup" : @YES,
							@"isChannel" : @NO};
	NSDictionary *channel = @{@"title" : @"Gamma", @"isGroup" : @YES,
							  @"isChannel" : @YES};
	NSArray *all = @[channel, privateChat, group];
	NSArray *privates = TGNotificationExceptionsForScope(all, @"private");
	NSArray *groups = TGNotificationExceptionsForScope(all, @"groups");
	NSArray *channels = TGNotificationExceptionsForScope(all, @"channels");
	XCTAssertEqual(privates.count, (NSUInteger)1);
	XCTAssertEqualObjects(privates.firstObject[@"title"], @"Alpha");
	XCTAssertEqual(groups.count, (NSUInteger)1);
	XCTAssertEqualObjects(groups.firstObject[@"title"], @"Beta");
	XCTAssertEqual(channels.count, (NSUInteger)1);
	XCTAssertEqualObjects(channels.firstObject[@"title"], @"Gamma");
}

- (void)testNotificationExceptionDetail_NamesTheMuteState {
	XCTAssertEqualObjects(TGNotificationExceptionDetail(
			@{@"notificationSettings" : @{@"mute_for" : @0}}), @"Always On");
	XCTAssertEqualObjects(TGNotificationExceptionDetail(
			@{@"notificationSettings" : @{@"mute_for" : @(3600)}}), @"Always Off");
}

- (void)testProxyStatus_ShowsConnectingThenPing {
	XCTAssertEqualObjects(TGProxyRowStatusText(YES, YES, -1, nil), @"connecting");
	XCTAssertEqualObjects(TGProxyRowStatusText(YES, NO, 0.123, nil),
						  @"connected, 123 ms ping");
	XCTAssertEqualObjects(TGProxyRowStatusText(NO, YES, -1, @"SOCKS5"),
						  @"SOCKS5, not tested");
	XCTAssertEqualObjects(TGProxyRowStatusText(NO, NO, 0.15, @"SOCKS5"),
						  @"SOCKS5, 150 ms ping");
	XCTAssertEqualObjects(TGProxyRowStatusText(NO, NO, -1, @"MTProto"),
						  @"MTProto, unavailable");
}

- (void)testSettingsDate_UsesTheSharedAppFormatter {
	// The reset date used a local NSDateFormatter medium/short style. The
	// scheduled-message formatter says "Today at ..." for the same day.
	NSTimeInterval now = 1700000000;
	XCTAssertTrue([TGSettingsDateTimeText(now, now) hasPrefix:@"Today at "]);
	XCTAssertEqualObjects(TGSettingsDateTimeText(0, now), @"—");
}

- (void)testAccountTtlDays_UseTheOfficialDayValues {
	// 3, 6 and 18 months used to become 91, 182 and 547 days.
	XCTAssertEqual(TGSettingsAccountTtlDaysForMonths(1), 30);
	XCTAssertEqual(TGSettingsAccountTtlDaysForMonths(3), 90);
	XCTAssertEqual(TGSettingsAccountTtlDaysForMonths(6), 180);
	XCTAssertEqual(TGSettingsAccountTtlDaysForMonths(12), 365);
	XCTAssertEqual(TGSettingsAccountTtlDaysForMonths(18), 548);
	XCTAssertEqual(TGSettingsAccountTtlDaysForMonths(24), 730);
}

- (void)testAccountTtlLabel_Maps548BackTo18Months {
	XCTAssertEqual(TGSettingsAccountTtlMonthsForDays(548), 18);
	XCTAssertEqual(TGSettingsAccountTtlMonthsForDays(540), 18);
	XCTAssertEqualObjects(TGSettingsAccountTtlLabel(548, YES), @"18 months");
	XCTAssertEqualObjects(TGSettingsAccountTtlLabel(90, YES), @"3 months");
	XCTAssertEqualObjects(TGSettingsAccountTtlLabel(365, YES), @"1 year");
	XCTAssertEqualObjects(TGSettingsAccountTtlLabel(0, YES), @"Off");
}

- (void)testAccountTtlLabel_UnknownIsLoadingNotOff {
	// Zero is a real value (Off); the row may only say Off after the answer.
	XCTAssertEqualObjects(TGSettingsAccountTtlLabel(0, NO), @"Loading...");
}

- (void)testDevicesValue_ZeroIsAddDeviceNotOne {
	XCTAssertEqualObjects(TGSettingsDevicesValue(0), @"Add Device");
	XCTAssertEqualObjects(TGSettingsDevicesValue(2), @"3");
}

- (void)testProxyRows_OnlySavedProxiesAreEditable {
	XCTAssertFalse(TGSettingsProxyRowEditable(0, 2));   // Use Proxy
	XCTAssertTrue(TGSettingsProxyRowEditable(1, 2));
	XCTAssertTrue(TGSettingsProxyRowEditable(2, 2));
	XCTAssertFalse(TGSettingsProxyRowEditable(3, 2));   // Add Proxy
}

- (void)testSavedMessagesRetry_StopsOffScreenOrAfterTwentyTries {
	XCTAssertTrue(TGSettingsSavedMessagesShouldRetry(0, YES));
	XCTAssertTrue(TGSettingsSavedMessagesShouldRetry(19, YES));
	XCTAssertFalse(TGSettingsSavedMessagesShouldRetry(20, YES));
	XCTAssertFalse(TGSettingsSavedMessagesShouldRetry(0, NO));
}

- (void)testStorageSelection_TogglesWholeCategoriesAndCountsOnce {
	NSArray *categories = @[
		@{@"bytes" : @(100), @"kinds" : @[@"photo", @"video"]},
		@{@"bytes" : @(40), @"kinds" : @[@"file"]},
	];
	NSMutableSet *selected = [NSMutableSet set];
	TGSettingsToggleKinds(selected, categories[0][@"kinds"]);
	XCTAssertEqual(selected.count, (NSUInteger)2);
	XCTAssertEqual(TGSettingsSelectedBytes(categories, selected), 100);

	TGSettingsToggleKinds(selected, @[@"photo"]);
	XCTAssertEqual(selected.count, (NSUInteger)1);
	TGSettingsToggleKinds(selected, @[@"photo"]);
	XCTAssertEqual(selected.count, (NSUInteger)2);
	TGSettingsToggleKinds(selected, categories[0][@"kinds"]);
	XCTAssertEqual(selected.count, (NSUInteger)0);
}

- (void)testPasscode_ZeroIsDisabledNotLockImmediately {
	// Older builds stored 0 for "Immediately"; the official choices have no
	// such option, so a stored 0 must now mean Disabled.
	[TGPasscode setPasscode:@"1234"];
	[TGPasscode setAutoLockTimeout:0];
	XCTAssertEqualObjects([TGPasscode autoLockTitleForSeconds:0], @"Disabled");
	[TGPasscode noteAppBackgrounded];
	XCTAssertFalse([TGPasscode shouldLockOnForeground]);
	[TGPasscode clearPasscode];
}

- (void)testRecoveryEmail_WrongPasswordKeepsTheServerError {
	TGClient *c = TPSSettingsClient();
	__block NSString *error = nil;
	__block NSString *email = @"not-called";
	[c recoveryEmailAddress:@"wrong" completionWithError:^(NSString *address, NSString *failure){
		email = address;
		error = failure;
	}];
	XCTAssertNotNil(TPSLastRequest(c, @"getRecoveryEmailAddress"));
	TPSAnswer(c, @{@"@type" : @"error", @"code" : @(400),
				   @"message" : @"PASSWORD_HASH_INVALID"});
	XCTAssertNil(email);
	XCTAssertEqualObjects(error, @"PASSWORD_HASH_INVALID");
}

- (void)testPrivacyRule_CountsEveryAllowExceptionKind {
	TGClient *c = TPSSettingsClient();
	__block NSString *value = nil;
	[c privacyRule:@"ShowPhoneNumber" completion:^(NSString *rule){ value = rule; }];
	NSDictionary *read = TPSLastRequest(c, @"getUserPrivacySettingRules");
	XCTAssertEqualObjects(read[@"setting"][@"@type"],
						  @"userPrivacySettingShowPhoneNumber");
	TPSAnswer(c, @{@"@type" : @"userPrivacySettingRules",
				   @"rules" : @[
					   @{@"@type" : @"userPrivacySettingRuleAllowUsers",
						 @"user_ids" : @[@(7), @(8)]},
					   @{@"@type" : @"userPrivacySettingRuleAllowChatMembers",
						 @"chat_ids" : @[@(-100)]},
					   @{@"@type" : @"userPrivacySettingRuleAllowCloseFriends"},
					   @{@"@type" : @"userPrivacySettingRuleAllowPremiumUsers"},
					   @{@"@type" : @"userPrivacySettingRuleAllowBots"},
					   @{@"@type" : @"userPrivacySettingRuleRestrictAll"}]});
	// Two users, one chat, close friends, Premium and bots: six exceptions.
	XCTAssertEqualObjects(value, @"nobody (+6)");
}

- (void)testPrivacyRule_CountsEveryRestrictExceptionKind {
	TGClient *c = TPSSettingsClient();
	__block NSString *value = nil;
	[c privacyRule:@"ShowPhoneNumber" completion:^(NSString *rule){ value = rule; }];
	TPSAnswer(c, @{@"@type" : @"userPrivacySettingRules",
				   @"rules" : @[
					   @{@"@type" : @"userPrivacySettingRuleRestrictUsers",
						 @"user_ids" : @[@(7), @(8)]},
					   @{@"@type" : @"userPrivacySettingRuleRestrictChatMembers",
						 @"chat_ids" : @[@(-100)]},
					   @{@"@type" : @"userPrivacySettingRuleRestrictCloseFriends"},
					   @{@"@type" : @"userPrivacySettingRuleRestrictPremiumUsers"},
					   @{@"@type" : @"userPrivacySettingRuleRestrictBots"},
					   @{@"@type" : @"userPrivacySettingRuleAllowAll"}]});
	XCTAssertEqualObjects(value, @"everybody (-6)");
}

- (void)testPrivacyWrite_CarriesExistingExceptionsAndReportsSuccess {
	TGClient *c = TPSSettingsClient();
	__block BOOL finished = NO;
	__block BOOL ok = NO;
	[c setPrivacyRule:@"ShowStatus" to:@"nobody" completion:^(BOOL written, NSString *error){
		finished = YES;
		ok = written;
	}];
	NSDictionary *read = TPSLastRequest(c, @"getUserPrivacySettingRules");
	XCTAssertEqualObjects(read[@"setting"][@"@type"], @"userPrivacySettingShowStatus");
	TPSAnswer(c, @{@"@type" : @"userPrivacySettingRules",
				   @"rules" : @[@{@"@type" : @"userPrivacySettingRuleAllowUsers",
								  @"user_ids" : @[@(7), @(8)]},
								@{@"@type" : @"userPrivacySettingRuleRestrictAll"}]});
	NSDictionary *written = TPSLastRequest(c, @"setUserPrivacySettingRules");
	NSArray *rules = written[@"rules"][@"rules"];
	XCTAssertEqual(rules.count, (NSUInteger)2);
	XCTAssertEqualObjects(rules[0][@"@type"], @"userPrivacySettingRuleAllowUsers");
	XCTAssertEqualObjects(rules[1][@"@type"], @"userPrivacySettingRuleRestrictAll");
	TPSAnswer(c, @{@"@type" : @"ok"});
	XCTAssertTrue(finished);
	XCTAssertTrue(ok);
}

@end
