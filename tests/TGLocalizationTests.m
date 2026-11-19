// TGLocalizationTests.m - the lookup rules, pinned without a phone.
//
// The pack is keyed by English values. Exact text must win, a case-only
// difference may use the folded map, and an ambiguous fold must not guess.
#import "TGTestRunner.h"
#import "TGTermsAge.h"
#import "TGLocalization.h"

@interface TGLocalizationTests : XCTestCase @end

@implementation TGLocalizationTests

- (void)setUp {
	[super setUp];
	TGSetAppLanguage(nil);
	TGSetTelegramLanguageLookup(nil);
	TGSetTelegramLanguagePlurals(nil);
}

- (void)tearDown {
	TGSetTelegramLanguageLookup(nil);
	TGSetTelegramLanguagePlurals(nil);
	TGSetAppLanguage(nil);
	[super tearDown];
}

/// A pack that arrives unchanged at launch must be recognised, or every
/// screen is walked and relabelled again on the main thread.
/// The pack cache is written as a binary plist. A writer that called itself
/// once grew the app to ~190 MB on a 4S; this would never return.
- (void)testPackCacheIsWrittenAsBinaryPlist {
	TGSetAppLanguage(@"xx-test");
	NSString *path = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
			NSUserDomainMask, YES) firstObject]
			stringByAppendingPathComponent:@"localization-xx-test.plist"];
	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	TGSetTelegramLanguageLookup(@{@"Chats" : @"Чаты"});
	NSData *head = nil;
	for (int i = 0; i < 300 && head.length < 6; i++){
		[NSThread sleepForTimeInterval:0.01];
		NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
		head = [file readDataOfLength:6];
		[file closeFile];
	}
	XCTAssertEqualObjects(head, [@"bplist" dataUsingEncoding:NSASCIIStringEncoding]);
	XCTAssertEqualObjects([NSDictionary dictionaryWithContentsOfFile:path][@"Chats"], @"Чаты");
	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	TGSetTelegramLanguageLookup(nil);
	TGSetAppLanguage(nil);
}

- (void)testSamePackIsRecognisedAndAChangedOneIsNot {
	NSDictionary *lookup = @{@"Chats" : @"Чаты", @"Settings" : @"Настройки"};
	NSDictionary *plurals = @{@"%d chats" : @{@"one" : @"%d чат"}};
	TGSetTelegramLanguageLookup(lookup);
	TGSetTelegramLanguagePlurals(plurals);
	XCTAssertTrue(TGTelegramLanguageMatches([lookup copy], [plurals copy]));
	XCTAssertFalse(TGTelegramLanguageMatches(@{@"Chats" : @"Чаты"}, plurals));
	XCTAssertFalse(TGTelegramLanguageMatches(lookup, @{}));
	TGSetTelegramLanguageLookup(nil);
	XCTAssertFalse(TGTelegramLanguageMatches(@{}, @{}),
			@"no pack installed is never 'the same pack'");
}

- (void)testExactValueWins {
	TGSetTelegramLanguageLookup(@{
		@"Settings" : @"НАСТРОЙКИ",
		@"SETTINGS" : @"ДРУГОЕ",
	});
	XCTAssertEqualObjects((id)TGLocalized(@"Settings"), (id)@"НАСТРОЙКИ");
}

- (void)testCaseOnlyDifferenceUsesFoldedMap {
	TGSetTelegramLanguageLookup(@{@"SLOW MODE" : @"МЕДЛЕННЫЙ РЕЖИМ"});
	XCTAssertEqualObjects((id)TGLocalized(@"Slow Mode"), (id)@"МЕДЛЕННЫЙ РЕЖИМ");
}

- (void)testAmbiguousFoldIsNotGuessed {
	TGSetTelegramLanguageLookup(@{
		@"Chat" : @"ЧАТ",
		@"CHAT" : @"ДРУГОЕ",
	});
	XCTAssertEqualObjects((id)TGLocalized(@"chat"), (id)@"chat");
}

- (void)testRememberedMissTranslatesOnceThePackHasTheString {
	// A miss is remembered (every chat label used to fold and search again);
	// a pack that arrives after it, exact or only by case, still wins.
	XCTAssertEqualObjects(TGLocalized(@"Zebra crossing"), @"Zebra crossing");
	XCTAssertEqualObjects(TGLocalized(@"ZEBRA CROSSING"), @"ZEBRA CROSSING");
	XCTAssertEqualObjects(TGLocalized(@"Zebra crossing"), @"Zebra crossing");
	TGSetTelegramLanguageLookup(@{@"Zebra crossing" : @"Зебра"});
	XCTAssertEqualObjects(TGLocalized(@"Zebra crossing"), @"Зебра");
	XCTAssertEqualObjects(TGLocalized(@"ZEBRA CROSSING"), @"Зебра");
	TGSetTelegramLanguageLookup(nil);
	XCTAssertEqualObjects(TGLocalized(@"Zebra crossing"), @"Zebra crossing");
}

- (void)testLongMessageTextStaysEnglishAndIntact {
	// Message bodies reach TGLocalized through UILabel; the hash walks long
	// ones in 128-unit chunks.
	NSMutableString *body = [NSMutableString string];
	for (int i = 0; i < 300; i++)
		[body appendFormat:@"word%d ", i];
	XCTAssertEqualObjects(TGLocalized(body), body);
	XCTAssertEqualObjects(TGLocalized(body), body);
}

- (void)testUnknownStaysEnglish {
	TGSetTelegramLanguageLookup(@{@"Settings" : @"НАСТРОЙКИ"});
	XCTAssertEqualObjects((id)TGLocalized(@"LegacyTG only"), (id)@"LegacyTG only");
}

- (void)testEmptyIsEmpty {
	XCTAssertEqualObjects((id)TGLocalized(@""), (id)@"");
	XCTAssertEqualObjects((id)TGLocalized(nil), (id)@"");
}

- (void)testFormatUsesTranslatedString {
	TGSetTelegramLanguageLookup(@{@"%ld chats" : @"%ld чатов"});
	XCTAssertEqualObjects((id)TGLocalizedFormat(@"%ld chats", (long)3), (id)@"3 чатов");
}

- (void)testRussianPluralForms {
	TGSetAppLanguage(@"ru");
	TGSetTelegramLanguageLookup(@{});
	TGSetTelegramLanguagePlurals(@{
		@"%d chats" : @{
			@"one" : @"%d чат",
			@"few" : @"%d чата",
			@"many" : @"%d чатов",
			@"other" : @"%d чата",
		},
	});
	XCTAssertEqualObjects((id)TGLocalizedPlural(@"%d chat", @"%d chats", 1), (id)@"1 чат");
	XCTAssertEqualObjects((id)TGLocalizedPlural(@"%d chat", @"%d chats", 2), (id)@"2 чата");
	XCTAssertEqualObjects((id)TGLocalizedPlural(@"%d chat", @"%d chats", 5), (id)@"5 чатов");
	XCTAssertEqualObjects((id)TGLocalizedPlural(@"%d chat", @"%d chats", 11), (id)@"11 чатов");
	XCTAssertEqualObjects((id)TGLocalizedPlural(@"%d chat", @"%d chats", 21), (id)@"21 чат");
}

- (void)testPluralFallsBackToEnglish {
	XCTAssertEqualObjects((id)TGLocalizedPlural(@"%d chat", @"%d chats", 1), (id)@"1 chat");
	XCTAssertEqualObjects((id)TGLocalizedPlural(@"%d chat", @"%d chats", 2), (id)@"2 chats");
}

- (void)testPluralValueUsesStringTemplates {
	TGSetAppLanguage(@"ru");
	TGSetTelegramLanguageLookup(@{});
	TGSetTelegramLanguagePlurals(@{
		@"%@ months" : @{
			@"one" : @"%@ месяц",
			@"few" : @"%@ месяца",
			@"many" : @"%@ месяцев",
			@"other" : @"%@ месяца",
		},
	});
	XCTAssertEqualObjects((id)TGLocalizedPluralValue(@"%@ month", @"%@ months", @"1", 1),
			(id)@"1 месяц");
	XCTAssertEqualObjects((id)TGLocalizedPluralValue(@"%@ month", @"%@ months", @"3", 3),
			(id)@"3 месяца");
	XCTAssertEqualObjects((id)TGLocalizedPluralValue(@"%@ month", @"%@ months", @"5", 5),
			(id)@"5 месяцев");
}

// Parity: the zero and two forms a pack carries for Arabic, Hebrew,
// Slovenian and Irish are picked by CLDR's rules, as official's
// StringPluralization does; the old rules stay for everything else.
- (void)testPluralCategory_ZeroAndTwoLanguages {
	XCTAssertEqualObjects(TGPluralCategory(0, @"ar"), @"zero");
	XCTAssertEqualObjects(TGPluralCategory(2, @"ar"), @"two");
	XCTAssertEqualObjects(TGPluralCategory(5, @"ar"), @"few");
	XCTAssertEqualObjects(TGPluralCategory(11, @"ar"), @"many");
	XCTAssertEqualObjects(TGPluralCategory(100, @"ar"), @"other");
	XCTAssertEqualObjects(TGPluralCategory(2, @"he"), @"two");
	XCTAssertEqualObjects(TGPluralCategory(102, @"sl"), @"two");
	XCTAssertEqualObjects(TGPluralCategory(8, @"ga"), @"many");
	XCTAssertEqualObjects(TGPluralCategory(3, @"ru"), @"few");
	XCTAssertEqualObjects(TGPluralCategory(2, @"en"), @"other");
	XCTAssertEqualObjects(TGPluralCategory(1, @"en"), @"one");
}

// Parity: terms with a minimum age ask official's Age Verification first.
- (void)testTermsAgeConfirmation {
	XCTAssertEqualObjects(TGTermsAgeConfirmation(16), @"Tap Agree to confirm that you are 16 or over.");
	XCTAssertNil(TGTermsAgeConfirmation(0));
}

@end
