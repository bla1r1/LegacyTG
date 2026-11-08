// TGLocalizationTests.m - the lookup rules, pinned without a phone.
//
// The pack is keyed by English values. Exact text must win, a case-only
// difference may use the folded map, and an ambiguous fold must not guess.
#import "TGTestRunner.h"
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

@end
