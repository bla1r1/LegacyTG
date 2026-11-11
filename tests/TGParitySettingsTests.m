// TGParitySettingsTests.m — settings value formatting parity.
//
// The unit strings, the privacy exception templates and the account lifetime
// are pack keys, so a value glued together by hand stayed English or drifted
// by a day. These are the pure helpers that fix that, pinned without UIKit.
#import "TGTestRunner.h"
#import "TGSettingsFormatting.h"
#import "TGStyle.h"
#import "TGPasscode.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGChatThemeStore.h"
#import "TGStoreTestSupport.h"
#import "TGAccountStore.h"
#import "TGProfileStore.h"
#import "TGSettingsStore.h"

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

- (void)testThemeList_ClassicLeadsAndDarkFilesStay {
	// Classic is always the first card; imported files keep the order
	// availableThemeFiles returned, and a dark file is a card of its own.
	NSArray *files = @[
		@{@"id" : @"file:Day.tgios-theme", @"name" : @"Day", @"dark" : @NO},
		@{@"id" : @"file:NightBlue.tgios-theme", @"name" : @"Night Blue",
		  @"dark" : @YES},
		@{@"id" : @"file:Night.attheme", @"name" : @"Night", @"dark" : @YES},
	];
	NSArray *themes = TGSettingsThemeList(files);
	XCTAssertEqual(themes.count, (NSUInteger)4);
	XCTAssertEqualObjects(themes[0][@"id"], @"classic");
	XCTAssertEqualObjects(themes[1][@"id"], @"file:Day.tgios-theme");
	XCTAssertEqualObjects(themes[2][@"id"], @"file:NightBlue.tgios-theme");
	XCTAssertEqualObjects(themes[3][@"id"], @"file:Night.attheme");
	XCTAssertFalse([themes[0][@"dark"] boolValue]);
	XCTAssertTrue(TGSettingsThemeIsDark(themes, @"file:NightBlue.tgios-theme"));
	XCTAssertFalse(TGSettingsThemeIsDark(themes, @"file:Day.tgios-theme"));
}

- (void)testChatThemesModel_EmojiGridThenBaseThemesUnderPreview {
	NSArray *emoji = @[
		@{@"id" : @"emoji:🏠", @"name" : @"🏠"},
		@{@"id" : @"emoji:🐥", @"name" : @"🐥"},
	];
	NSArray *base = @[
		@{@"id" : @"classic", @"name" : @"Classic", @"dark" : @NO},
		@{@"id" : @"file:NightBlue.tgios-theme", @"name" : @"Night Blue",
		  @"dark" : @YES},
	];
	NSArray *model = TGSettingsChatThemesModel(emoji, base, @"emoji:🏠");
	XCTAssertEqual(model.count, (NSUInteger)2);
	// "Select Theme" is the server's emoji grid; a base theme inside it was
	// the bug (reference/8).
	XCTAssertEqualObjects(model[0][@"kind"], @"emojiGrid");
	XCTAssertEqualObjects(model[0][@"header"], @"Select Theme");
	XCTAssertEqualObjects(model[0][@"themes"], emoji);
	// The base row belongs under the preview, in "Create Your Own Theme".
	XCTAssertEqualObjects(model[1][@"kind"], @"customTheme");
	XCTAssertEqualObjects(model[1][@"header"], @"Create Your Own Theme");
	XCTAssertEqualObjects(model[1][@"themes"], base);
	XCTAssertEqualObjects(model[1][@"current"], @"emoji:🏠");
}

- (void)testChatThemesModel_ClassicLeadsTheEmojiGrid {
	NSArray *emoji = @[
		@{@"id" : @"emoji:🏠", @"name" : @"🏠"},
		@{@"id" : @"emoji:🐥", @"name" : @"🐥"},
	];
	NSArray *themes = TGSettingsThemesWithClassic(emoji);
	XCTAssertEqual(themes.count, (NSUInteger)3);
	XCTAssertEqualObjects(themes[0][@"id"], @"classic");
	XCTAssertFalse([themes[0][@"emoji"] boolValue]);
	XCTAssertEqualObjects(themes[1][@"id"], @"emoji:🏠");
	// A caller that already has Classic must not get a second card.
	NSArray *once = TGSettingsThemesWithClassic(themes);
	XCTAssertEqual(once.count, (NSUInteger)3);
}

- (void)testChatThemesStrings_GoThroughThePackLookup {
	// The pack stores "Select Theme" in title case; the section header is
	// uppercased after lookup, exactly as ThemePickerController does.
	TGSetTelegramLanguageLookup(@{
		@"Select Theme" : @"ВИБЕРІТЬ ТЕМУ",
		@"Chat Themes" : @"Теми для чатів",
	});
	NSArray *model = TGSettingsChatThemesModel(@[], @[], @"classic");
	XCTAssertEqualObjects(TGSettingsHeaderText(model[0][@"header"]),
			@"ВИБЕРІТЬ ТЕМУ");
	XCTAssertEqualObjects(TGLocalized(@"Chat Themes"), @"Теми для чатів");
	TGSetTelegramLanguageLookup(nil);
}

- (void)testNightTheme_RemembersTheChoiceAndFallsBackToADarkCard {
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	[defaults removeObjectForKey:TGSettingsNightModeKey];
	[defaults removeObjectForKey:TGSettingsNightThemeKey];
	[defaults removeObjectForKey:TGSettingsDayThemeKey];

	NSArray *themes = TGSettingsThemeList(@[
		@{@"id" : @"file:Day.tgios-theme", @"name" : @"Day", @"dark" : @NO},
		@{@"id" : @"file:NightBlue.tgios-theme", @"name" : @"Night Blue",
		  @"dark" : @YES},
		@{@"id" : @"file:Night.attheme", @"name" : @"Night", @"dark" : @YES},
	]);

	// The first dark theme until the user picks another.
	XCTAssertEqualObjects(TGSettingsNightThemeId(defaults, themes),
			@"file:NightBlue.tgios-theme");
	[defaults setObject:@"file:Night.attheme" forKey:TGSettingsNightThemeKey];
	XCTAssertEqualObjects(TGSettingsNightThemeId(defaults, themes),
			@"file:Night.attheme");
	// A stored light id is not a night theme.
	[defaults setObject:@"file:Day.tgios-theme" forKey:TGSettingsNightThemeKey];
	XCTAssertEqualObjects(TGSettingsNightThemeId(defaults, themes),
			@"file:NightBlue.tgios-theme");
	XCTAssertEqualObjects(TGSettingsDayThemeId(defaults, themes), @"classic");
	[defaults setObject:@"file:Day.tgios-theme" forKey:TGSettingsDayThemeKey];
	XCTAssertEqualObjects(TGSettingsDayThemeId(defaults, themes),
			@"file:Day.tgios-theme");
	XCTAssertFalse(TGSettingsNightModeEnabled(defaults));
	[defaults setBool:YES forKey:TGSettingsNightModeKey];
	XCTAssertTrue(TGSettingsNightModeEnabled(defaults));

	[defaults removeObjectForKey:TGSettingsNightModeKey];
	[defaults removeObjectForKey:TGSettingsNightThemeKey];
	[defaults removeObjectForKey:TGSettingsDayThemeKey];
}

- (void)testEmojiThemeChoice_IsPersistedByName {
	TGChatThemeStore *store = [TGChatThemeStore shared];
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	[defaults removeObjectForKey:TGSettingsEmojiThemeKey];
	[store setCurrentThemeName:@"Sunset"];
	XCTAssertEqualObjects(store.currentThemeName, @"Sunset");
	XCTAssertEqualObjects([defaults stringForKey:TGSettingsEmojiThemeKey], @"Sunset");
	XCTAssertEqualObjects(TGChatThemeIdForName(store.currentThemeName),
			@"emoji:Sunset");
	XCTAssertEqualObjects(TGChatThemeNameFromId(@"emoji:Sunset"), @"Sunset");
	XCTAssertTrue(TGChatThemeIdIsEmoji(@"emoji:Sunset"));
	XCTAssertFalse(TGChatThemeIdIsEmoji(@"classic"));
	[store clearCurrentThemeName];
	XCTAssertNil(store.currentThemeName);
}

- (void)testTextSize_SevenStepsRoundTripThroughPoints {
	XCTAssertEqual(TGMetricMessageSizeSteps, (NSInteger)7);
	for (NSInteger step = 0; step < TGMetricMessageSizeSteps; step++){
		CGFloat size = TGMessageFontSizeForStep(step);
		CGFloat expected = TGFontMessageBaseSize + step * TGFontMessageStep;
		XCTAssertTrue(fabs(size - expected) < 0.01f,
				"step %ld must be %.1f pt, got %.1f", (long)step, expected, size);
		XCTAssertEqual(TGMessageFontSizeStep(size), step);
	}
	// A size between two steps opens on the nearer one; outside the scale
	// clamps to the ends instead of leaving the slider without a position.
	XCTAssertEqual(TGMessageFontSizeStep(TGFontMessageBaseSize + TGFontMessageStep + 0.9f), 1);
	XCTAssertEqual(TGMessageFontSizeStep(0), 0);
	XCTAssertEqual(TGMessageFontSizeStep(1000), TGMetricMessageSizeSteps - 1);
}

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
	[[TGAccountStore shared] recoveryEmailAddress:@"wrong" completionWithError:^(NSString *address, NSString *failure){
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
	[[TGProfileStore shared] privacyRule:@"ShowPhoneNumber" completion:^(NSString *rule){ value = rule; }];
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
	[[TGProfileStore shared] privacyRule:@"ShowPhoneNumber" completion:^(NSString *rule){ value = rule; }];
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
	[[TGSettingsStore shared] setPrivacyRule:@"ShowStatus" to:@"nobody" completion:^(BOOL written, NSString *error){
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

- (void)testPrivacyRuleDetails_ExtractsRuleTypeAndExceptionLists {
	TGClient *c = TPSSettingsClient();
	__block NSString *type = nil;
	__block NSArray *allows = nil;
	__block NSArray *restricts = nil;
	[[TGSettingsStore shared] privacyRuleDetails:@"ShowStatus" completion:^(NSString *ruleType, NSArray *allowUserIds, NSArray *restrictUserIds){
		type = ruleType;
		allows = allowUserIds;
		restricts = restrictUserIds;
	}];
	NSDictionary *read = TPSLastRequest(c, @"getUserPrivacySettingRules");
	XCTAssertEqualObjects(read[@"setting"][@"@type"], @"userPrivacySettingShowStatus");
	TPSAnswer(c, @{@"@type" : @"userPrivacySettingRules",
				   @"rules" : @[
					   @{@"@type" : @"userPrivacySettingRuleAllowUsers", @"user_ids" : @[@(101), @(102)]},
					   @{@"@type" : @"userPrivacySettingRuleRestrictUsers", @"user_ids" : @[@(201)]},
					   @{@"@type" : @"userPrivacySettingRuleAllowContacts"}]});
	XCTAssertEqualObjects(type, @"contacts");
	XCTAssertEqual(allows.count, (NSUInteger)2);
	XCTAssertEqual(restricts.count, (NSUInteger)1);
	XCTAssertEqualObjects(allows[0], @(101));
	XCTAssertEqualObjects(restricts[0], @(201));
}

- (void)testSetPrivacyRule_WithExplicitAllowAndRestrictUsers {
	TGClient *c = TPSSettingsClient();
	__block BOOL done = NO;
	[[TGSettingsStore shared] setPrivacyRule:@"ShowProfilePhoto"
				 type:@"nobody"
		 allowUserIds:@[@(501)]
	  restrictUserIds:@[@(601), @(602)]
		   completion:^(BOOL ok, NSString *error){
		done = ok;
	}];
	NSDictionary *req = TPSLastRequest(c, @"setUserPrivacySettingRules");
	XCTAssertEqualObjects(req[@"setting"][@"@type"], @"userPrivacySettingShowProfilePhoto");
	NSArray *rules = req[@"rules"][@"rules"];
	XCTAssertEqual(rules.count, (NSUInteger)3);
	XCTAssertEqualObjects(rules[0][@"@type"], @"userPrivacySettingRuleAllowUsers");
	XCTAssertEqualObjects(rules[1][@"@type"], @"userPrivacySettingRuleRestrictUsers");
	XCTAssertEqualObjects(rules[2][@"@type"], @"userPrivacySettingRuleRestrictAll");
	TPSAnswer(c, @{@"@type" : @"ok"});
	XCTAssertTrue(done);
}

- (void)testSetOption_IntegerStorageOptions {
	TGClient *c = TPSSettingsClient();
	[[TGSettingsStore shared] setOption:@"storage_max_files_size" integerValue:5368709120LL];
	NSDictionary *req = TPSLastRequest(c, @"setOption");
	XCTAssertEqualObjects(req[@"name"], @"storage_max_files_size");
	XCTAssertEqualObjects(req[@"value"][@"@type"], @"optionValueInteger");
	XCTAssertEqualObjects(req[@"value"][@"value"], @(5368709120LL));
}

- (void)testAppearancePreview_UsesTheOfficialPackKeys {
	// The 2019 preview sentences and the account name must never come back.
	NSDictionary *lookup = @{
		@"Zakhar" : @"Захар",
		@"Good morning! 👋" : @"Доброго ранку! 👋",
		@"It's almost noon..." : @"Вже ніби день...",
		@"It's morning in Tokyo 😎" : @"А в Токіо ранок 😎",
	};
	TGSetTelegramLanguageLookup(lookup);
	NSDictionary *texts = TGSettingsAppearancePreviewTexts();
	XCTAssertEqualObjects(texts[@"author"], @"Захар");
	XCTAssertEqualObjects(texts[@"reply"], @"Доброго ранку! 👋");
	XCTAssertEqualObjects(texts[@"incoming"], @"Вже ніби день...");
	XCTAssertEqualObjects(texts[@"outgoing"], @"А в Токіо ранок 😎");
	TGSetTelegramLanguageLookup(nil);
}

- (void)testThemeDisplayName_StripsExtensionsAndTrailingDots {
	XCTAssertEqualObjects(TGSettingsThemeDisplayName(
			@{@"id" : @"file:Night.attheme", @"name" : @"Night.attheme"}),
			@"Night");
	XCTAssertEqualObjects(TGSettingsThemeDisplayName(
			@{@"id" : @"file:Blue.tgios-theme", @"name" : @"Blue Butter."}),
			@"Blue Butter");
	XCTAssertEqualObjects(TGSettingsThemeDisplayName(
			@{@"id" : @"file:Day.tgios-theme"}), @"Day");
	XCTAssertEqualObjects(TGSettingsThemeDisplayName(
			@{@"id" : @"classic"}), @"Classic");
}

- (void)testThemeList_UsesDisplayNamesNotFileNames {
	NSArray *themes = TGSettingsThemeList(@[
		@{@"id" : @"file:Night.attheme", @"name" : @"Night.attheme",
		  @"dark" : @YES},
	]);
	XCTAssertEqualObjects(themes[1][@"name"], @"Night");
	XCTAssertEqualObjects(TGSettingsThemeDisplayName(themes[1]), @"Night");
}

- (void)testBackgrounds_FilterToTheThemeSideAndKeepUnknowns {
	NSArray *backgrounds = @[
		@{@"id" : @1, @"isDark" : @NO},
		@{@"id" : @2, @"isDark" : @YES},
		@{@"id" : @3, @"isDark" : @YES},
		@{@"id" : @4},                       // no side: keep rather than hide
	];
	NSArray *dark = TGSettingsBackgroundsForDarkTheme(backgrounds, YES);
	NSArray *light = TGSettingsBackgroundsForDarkTheme(backgrounds, NO);
	XCTAssertEqual(dark.count, (NSUInteger)3);
	XCTAssertEqual(light.count, (NSUInteger)2);
	XCTAssertEqualObjects([dark valueForKey:@"id"], (@[@2, @3, @4]));
	XCTAssertEqualObjects([light valueForKey:@"id"], (@[@1, @4]));
}

- (void)testLocalTextures_AreInTheWallpaperGridModel {
	NSArray *local = TGSettingsLocalWallpaperItems();
	XCTAssertEqual(local.count, (NSUInteger)5);
	XCTAssertEqualObjects([local valueForKey:@"title"], (@[@"Paper Grain",
			@"Pinstripes", @"Classic Linen", @"Parchment", @"Game Center Felt"]));
	XCTAssertEqualObjects([local valueForKey:@"localWallpaperType"],
			(@[@(TGWallpaperTypePaperGrain), @(TGWallpaperTypePinstripes),
			   @(TGWallpaperTypeLinen), @(TGWallpaperTypeParchment),
			   @(TGWallpaperTypeFelt)]));

	NSArray *server = @[@{@"id" : @7, @"typeName" : @"wallpaper"}];
	NSArray *grid = TGSettingsWallpaperGridItems(local, server);
	XCTAssertEqual(grid.count, (NSUInteger)6);
	XCTAssertEqualObjects([grid.lastObject objectForKey:@"id"], @7);
	XCTAssertEqualObjects([grid[0] objectForKey:@"title"], @"Paper Grain");
}

- (void)testClassicThemeRoles_AreNotClear {
	NSDictionary *roles = TGClassicThemeRoleColours();
	for (NSString *key in @[@"accent", @"text", @"bubbleMine",
			@"bubbleTheirs", @"bubbleMineText", @"bubbleTheirsText"]){
		UIColor *colour = roles[key];
		XCTAssertNotNil(colour, @"Classic role %@ is missing", key);
		XCTAssertGreaterThan(CGColorGetAlpha(colour.CGColor), 0.99f,
				@"Classic role %@ is transparent", key);
	}
}

- (void)testAutoNightSchedule_WrapsMidnightAndIsEndExclusive {
	// 22:00 to 07:00.
	XCTAssertTrue(TGSettingsAutoNightShouldBeDark(23 * 60, 22 * 60, 7 * 60));
	XCTAssertTrue(TGSettingsAutoNightShouldBeDark(0, 22 * 60, 7 * 60));
	XCTAssertTrue(TGSettingsAutoNightShouldBeDark(6 * 60 + 59, 22 * 60, 7 * 60));
	XCTAssertFalse(TGSettingsAutoNightShouldBeDark(7 * 60, 22 * 60, 7 * 60));
	XCTAssertFalse(TGSettingsAutoNightShouldBeDark(12 * 60, 22 * 60, 7 * 60));

	// 08:00 to 17:00 does not wrap.
	XCTAssertTrue(TGSettingsAutoNightShouldBeDark(8 * 60, 8 * 60, 17 * 60));
	XCTAssertTrue(TGSettingsAutoNightShouldBeDark(16 * 60 + 59, 8 * 60, 17 * 60));
	XCTAssertFalse(TGSettingsAutoNightShouldBeDark(17 * 60, 8 * 60, 17 * 60));

	// Equal ends are an empty window, not permanent night.
	XCTAssertFalse(TGSettingsAutoNightShouldBeDark(12 * 60, 9 * 60, 9 * 60));
}

- (void)testAutoNightMode_LabelAndStoredTimes {
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	[defaults removeObjectForKey:TGSettingsAutoNightModeKey];
	[defaults removeObjectForKey:TGSettingsAutoNightFromKey];
	[defaults removeObjectForKey:TGSettingsAutoNightToKey];
	XCTAssertEqual(TGSettingsAutoNightMode(defaults),
			TGSettingsAutoNightModeDisabled);
	XCTAssertEqualObjects(TGSettingsAutoNightModeLabel(defaults), @"Disabled");
	XCTAssertEqual(TGSettingsAutoNightMinute(defaults,
			TGSettingsAutoNightFromKey, TGSettingsAutoNightDefaultFrom),
			TGSettingsAutoNightDefaultFrom);

	TGSettingsSetAutoNightMode(defaults, TGSettingsAutoNightModeScheduled);
	XCTAssertEqualObjects(TGSettingsAutoNightModeLabel(defaults), @"Scheduled");
	[defaults setInteger:90 forKey:TGSettingsAutoNightFromKey];
	XCTAssertEqual(TGSettingsAutoNightMinute(defaults,
			TGSettingsAutoNightFromKey, TGSettingsAutoNightDefaultFrom), 90);
	[defaults setInteger:24 * 60 forKey:TGSettingsAutoNightFromKey];
	XCTAssertEqual(TGSettingsAutoNightMinute(defaults,
			TGSettingsAutoNightFromKey, TGSettingsAutoNightDefaultFrom),
			TGSettingsAutoNightDefaultFrom);

	[defaults removeObjectForKey:TGSettingsAutoNightModeKey];
	[defaults removeObjectForKey:TGSettingsAutoNightFromKey];
	[defaults removeObjectForKey:TGSettingsAutoNightToKey];
}

@end
