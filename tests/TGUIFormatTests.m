// TGUIFormatTests.m - the shared strings the auth, call, scheduled and
// forward screens print. Every one is a pure function, so the format is
// pinned here instead of being checked by eye on four screens.
#import "TGTestRunner.h"
#import "TGUIFormat.h"
#import "TGPhoneNumberRules.h"

@interface TGUIFormatTests : XCTestCase
@end
@implementation TGUIFormatTests

- (void)testCallDuration {
	XCTAssertEqualObjects(TGUIFormatCallDuration(0), @"0:00");
	XCTAssertEqualObjects(TGUIFormatCallDuration(7), @"0:07");
	XCTAssertEqualObjects(TGUIFormatCallDuration(65), @"1:05");
	XCTAssertEqualObjects(TGUIFormatCallDuration(3729), @"1:02:09");
	XCTAssertEqualObjects(TGUIFormatCallDuration(-4), @"0:00");
}

/// A national number that starts with its own calling code is not a pasted
/// full number: Kyrgyz 996 xxx xxx lost its first 996, every Kazakh 7xx
/// lost its 7, so Telegram was asked for a number that does not exist.
- (void)testFullPhoneKeepsNationalDigitsThatRepeatTheCode {
	XCTAssertEqualObjects(TGUIFormatFullPhone(@"+996", @"996 123 456"),
			@"+996996123456");
	XCTAssertEqualObjects(TGUIFormatFullPhone(@"+7", @"701 123 4567"),
			@"+77011234567");
	XCTAssertEqualObjects(TGUIFormatFullPhone(@"+996", @"996996123456"),
			@"+996996123456");
	XCTAssertEqualObjects(TGUIFormatFullPhone(@"+7", @"77011234567"),
			@"+77011234567");
}

/// Typed digits never move to the code field on a guess: Kyrgyz 555... read
/// as Brazil, 99x as a second +996, Russian 916... as India.
- (void)testTypedNationalNumberIsNotInternational {
	XCTAssertFalse(TGPhoneNumberLooksInternational(@"555123456"));
	XCTAssertFalse(TGPhoneNumberLooksInternational(@"996123456"));
	XCTAssertFalse(TGPhoneNumberLooksInternational(@"9161234567"));
	XCTAssertFalse(TGPhoneNumberLooksInternational(@"631234567"));
	XCTAssertTrue(TGPhoneNumberLooksInternational(@"+996555123456"));
	XCTAssertTrue(TGPhoneNumberLooksInternational(@"00996555123456"));
}

/// The calling code of a number after +: one digit for +1 and +7, so
/// +7 701... is Kazakhstan and not +770.
- (void)testCallingCodeLength {
	XCTAssertEqual(TGPhoneCallingCodeLength(@"996555123456"), (NSUInteger)3);
	XCTAssertEqual(TGPhoneCallingCodeLength(@"77011234567"), (NSUInteger)1);
	XCTAssertEqual(TGPhoneCallingCodeLength(@"15550109999"), (NSUInteger)1);
	XCTAssertEqual(TGPhoneCallingCodeLength(@"4915112345678"), (NSUInteger)2);
	XCTAssertEqual(TGPhoneCallingCodeLength(@""), (NSUInteger)0);
}

- (void)testFullPhoneKeepsOnePrefix {
	XCTAssertEqualObjects(TGUIFormatFullPhone(@"+380", @"0671234567"),
			@"+380671234567");
	XCTAssertEqualObjects(TGUIFormatFullPhone(@"+380", @"380671234567"),
			@"+380671234567");
	XCTAssertEqualObjects(TGUIFormatFullPhone(@"380", @"67 123 4567"),
			@"+380671234567");
	XCTAssertEqualObjects(TGUIFormatFullPhone(@"+1", @"(555) 010-9999"),
			@"+15550109999");
	XCTAssertEqualObjects(TGUIFormatFullPhone(@"", @"5550109999"),
			@"+5550109999");
	XCTAssertEqualObjects(TGUIFormatFullPhone(@"+39", @"06 1234 5678"),
			@"+390612345678");
}

- (void)testForwardSearchIgnoresCaseAndAccents {
	XCTAssertTrue(TGUIFormatChatMatches(@"Zürich", @"zurich"));
	XCTAssertTrue(TGUIFormatChatMatches(@"Saved Messages", @""));
	XCTAssertTrue(TGUIFormatChatMatches(@"Team Kyiv", @"kyiv"));
	XCTAssertFalse(TGUIFormatChatMatches(@"Team Kyiv", @"lviv"));
	XCTAssertFalse(TGUIFormatChatMatches(nil, @"x"));
}

- (void)testScheduledRelative {
	XCTAssertEqualObjects(TGUIFormatScheduledRelative(1000, 1000), @"in less than a minute");
	XCTAssertEqualObjects(TGUIFormatScheduledRelative(1000 + 1800, 1000), @"in 30 min");
	XCTAssertEqualObjects(TGUIFormatScheduledRelative(1000 + 2 * 3600 + 15 * 60, 1000),
			@"in 2 h 15 min");
	XCTAssertEqualObjects(TGUIFormatScheduledRelative(1000 + 3 * 86400, 1000), @"in 3 d");
	XCTAssertEqualObjects(TGUIFormatScheduledRelative(0, 1000), @"");
}

- (void)testScheduledWhenNamesTodayAndTomorrow {
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDate *nowDate = [NSDate date];
	NSDate *today = [calendar dateFromComponents:
			[calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit |
								   NSDayCalendarUnit) fromDate:nowDate]];
	NSTimeInterval base = [today timeIntervalSince1970] + 12 * 3600;
	NSString *todayText = TGUIFormatScheduledWhen(base, base);
	NSString *tomorrowText = TGUIFormatScheduledWhen(base + 86400, base);
	XCTAssertTrue([todayText hasPrefix:@"Today at "]);
	XCTAssertTrue([tomorrowText hasPrefix:@"Tomorrow at "]);
	XCTAssertEqualObjects(TGUIFormatScheduledWhen(0, base), @"");
}

- (void)testCompactCount {
	// 0..999 as is
	XCTAssertEqualObjects(TGCompactCount(0), @"0");
	XCTAssertEqualObjects(TGCompactCount(42), @"42");
	XCTAssertEqualObjects(TGCompactCount(999), @"999");
	// 1K..10K with 1 decimal place, drop .0
	XCTAssertEqualObjects(TGCompactCount(1000), @"1K");
	XCTAssertEqualObjects(TGCompactCount(1049), @"1K");
	XCTAssertEqualObjects(TGCompactCount(1050), @"1.1K");
	XCTAssertEqualObjects(TGCompactCount(1234), @"1.2K");
	XCTAssertEqualObjects(TGCompactCount(9949), @"9.9K");
	XCTAssertEqualObjects(TGCompactCount(9950), @"10K");
	// 10K..1M without decimal places
	XCTAssertEqualObjects(TGCompactCount(10000), @"10K");
	XCTAssertEqualObjects(TGCompactCount(12345), @"12K");
	XCTAssertEqualObjects(TGCompactCount(999499), @"999K");
	// Rollover to 1M and rounding
	XCTAssertEqualObjects(TGCompactCount(999500), @"1M");
	XCTAssertEqualObjects(TGCompactCount(999999), @"1M");
	XCTAssertEqualObjects(TGCompactCount(1000000), @"1M");
	// Below 10M with 1 decimal place
	XCTAssertEqualObjects(TGCompactCount(1234567), @"1.2M");
	XCTAssertEqualObjects(TGCompactCount(9949999), @"9.9M");
	XCTAssertEqualObjects(TGCompactCount(9950000), @"10M");
	// 10M and above
	XCTAssertEqualObjects(TGCompactCount(12345678), @"12M");
	// Billions
	XCTAssertEqualObjects(TGCompactCount(1500000000), @"1.5B");
}

- (void)testChatDate_EmptyForNoDateAndTheTimeToday {
	XCTAssertEqualObjects(TGUIFormatChatDate(0, 1700000000), @"");
	NSString *today = TGUIFormatChatDate(1700000000 - 60, 1700000000);
	XCTAssertTrue([today containsString:@":"], @"%@", today);
}

- (void)testDate_FollowsTheLanguageNotThePhone {
	// Noon UTC keeps the day in every time zone.
	NSString *en = TGUIFormatDate(1699963200, NSDateFormatterMediumStyle,
			NSDateFormatterNoStyle, @"en_US");
	NSString *ru = TGUIFormatDate(1699963200, NSDateFormatterMediumStyle,
			NSDateFormatterNoStyle, @"ru");
	XCTAssertTrue([en containsString:@"Nov"], @"%@", en);
	XCTAssertTrue([ru containsString:@"нояб"], @"%@", ru);
	// The cache keys on the language: asking English again is still English.
	XCTAssertEqualObjects(TGUIFormatDate(1699963200, NSDateFormatterMediumStyle,
			NSDateFormatterNoStyle, @"en_US"), en);
	XCTAssertNil(TGUIFormatDate(0, NSDateFormatterMediumStyle,
			NSDateFormatterNoStyle, @"en_US"));
}

- (void)testBytes_UnderAKilobyteInBytes {
	XCTAssertEqualObjects(TGBytesForLanguage(512, @"en"), @"512 B");
	XCTAssertEqualObjects(TGBytesForLanguage(1536, @"en"), @"2 KB");
	XCTAssertEqualObjects(TGBytesForLanguage(1572864, @"en"), @"1.5 MB");
}


#pragma mark - date entities (textEntityTypeDateTime)

- (void)testDateEntity_RelativeReadsInTheReadersClock {
	NSDictionary *relative = @{@"@type" : @"dateTimeFormattingTypeRelative"};
	XCTAssertEqualObjects(TGDateEntityText(1000000 - 7200, relative, 1000000), @"2 hours ago");
	XCTAssertEqualObjects(TGDateEntityText(1000000 + 172800, relative, 1000000), @"in 2 days");
	XCTAssertEqualObjects(TGDateEntityText(1000000 - 1, relative, 1000000), @"1 second ago");
	XCTAssertEqualObjects(TGDateEntityText(1000000 + 90, relative, 1000000), @"in 2 minutes");
}

- (void)testDateEntity_NoFormattingKeepsTheSendersWords {
	XCTAssertNil(TGDateEntityText(1000000, nil, 1000000));
	XCTAssertNil(TGDateEntityText(1000000, (id)[NSNull null], 1000000));
	NSDictionary *nothing = @{@"@type" : @"dateTimeFormattingTypeAbsolute",
		@"time_precision" : @{@"@type" : @"dateTimePartPrecisionNone"},
		@"date_precision" : @{@"@type" : @"dateTimePartPrecisionNone"}};
	XCTAssertNil(TGDateEntityText(1000000, nothing, 1000000));
}

- (void)testDateEntity_AbsoluteJoinsDayAndTime {
	NSDictionary *both = @{@"@type" : @"dateTimeFormattingTypeAbsolute",
		@"time_precision" : @{@"@type" : @"dateTimePartPrecisionShort"},
		@"date_precision" : @{@"@type" : @"dateTimePartPrecisionLong"},
		@"show_day_of_week" : @YES};
	NSString *text = TGDateEntityText(1763200000, both, 0);
	XCTAssertTrue([text rangeOfString:@" at "].location != NSNotFound, @"%@", text);
	NSDictionary *timeOnly = @{@"@type" : @"dateTimeFormattingTypeAbsolute",
		@"time_precision" : @{@"@type" : @"dateTimePartPrecisionShort"},
		@"date_precision" : @{@"@type" : @"dateTimePartPrecisionNone"}};
	XCTAssertEqual([TGDateEntityText(1763200000, timeOnly, 0) rangeOfString:@" at "].location,
			(NSUInteger)NSNotFound);
}

// A swapped date changes the text's length; an entity after it must move
// with it or its bold lands on the wrong words.
- (void)testApplyDateEntities_MovesLaterEntities {
	NSString *text = @"at X then bold";
	NSArray *entities = @[
		@{@"offset" : @3, @"length" : @1, @"type" : @{@"@type" : @"textEntityTypeDateTime",
			@"unix_time" : @(1000000 - 7200),
			@"formatting_type" : @{@"@type" : @"dateTimeFormattingTypeRelative"}}},
		@{@"offset" : @10, @"length" : @4, @"type" : @{@"@type" : @"textEntityTypeBold"}},
	];
	NSArray *moved = nil;
	NSString *out = TGApplyDateEntities(text, entities, 1000000, &moved);
	XCTAssertEqualObjects(out, @"at 2 hours ago then bold");
	XCTAssertEqual([moved[0][@"length"] integerValue], (NSInteger)11);
	XCTAssertEqualObjects([out substringWithRange:NSMakeRange([moved[1][@"offset"] integerValue],
			[moved[1][@"length"] integerValue])], @"bold");
	XCTAssertNil(TGApplyDateEntities(text, @[entities[1]], 1000000, &moved));
}

- (void)testMediaTimestampLink_RoundTrips {
	XCTAssertEqual(TGMediaTimestampFromLink(TGMediaTimestampLink(42)), 42);
	XCTAssertEqual(TGMediaTimestampFromLink(@"https://t.me/x"), -1);
}

@end
