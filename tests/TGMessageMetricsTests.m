// TGMessageMetricsTests.m - the chat row's measurements that moved out of
// TGChatViewController+Layout.m. The screen state they read (loaded quotes,
// loaded messages, pending votes, the font size) is an argument now.
#import "TGTestRunner.h"
#import "TGMessageMetrics.h"

@interface TGMessageMetricsTests : XCTestCase @end

@implementation TGMessageMetricsTests

#pragma mark - stamp

- (void)testStamp_ViewsAndSignatureComeBeforeTheTime {
	NSDictionary *plain = @{ @"date": @1700000000 };
	NSString *time = TGMessageStampText(plain);
	XCTAssertTrue(time.length > 0);
	NSDictionary *post = @{ @"date": @1700000000, @"viewCount": @2200000,
			@"authorSignature": @"A very long signature name" };
	NSString *stamp = TGMessageStampText(post);
	XCTAssertTrue([stamp hasSuffix:[@", " stringByAppendingString:time]]);
	XCTAssertTrue([stamp rangeOfString:@"A very long sign..."].location != NSNotFound);
	XCTAssertFalse([stamp hasPrefix:@"A very"]);
}

- (void)testStamp_WidthCarriesTheEyeAndTheTicks {
	NSDictionary *in = @{ @"date": @1700000000 };
	NSDictionary *out = @{ @"date": @1700000000, @"outgoing": @YES };
	XCTAssertEqual(TGMessageStampWidth(out) - TGMessageStampWidth(in), TGMetricStampTicksRoom);
	NSDictionary *viewed = @{ @"date": @1700000000, @"viewCount": @5 };
	XCTAssertGreaterThan(TGMessageStampWidth(viewed),
			TGMessageStampWidth(in) + kStampEyeSide);
}

- (void)testStamp_InlineOnlyOnOneShortLine {
	XCTAssertTrue(TGMessageStampFitsInline(@{ @"date": @1700000000, @"text": @"ok" }, 15));
	XCTAssertFalse(TGMessageStampFitsInline(@{ @"date": @1700000000, @"text": @"a\nb" }, 15));
	XCTAssertFalse(TGMessageStampFitsInline(@{ @"date": @1700000000, @"text": @"" }, 15));
	NSString *wraps = [@"" stringByPaddingToLength:400 withString:@"word " startingAtIndex:0];
	XCTAssertFalse(TGMessageStampFitsInline(@{ @"date": @1700000000, @"text": wraps }, 15));
}

#pragma mark - quote

- (void)testQuote_NothingForAMessageThatAnswersNothing {
	XCTAssertNil(TGMessageQuoteText(@{ @"text": @"hi" }, nil));
	XCTAssertNil(TGMessageQuoteEntities(@{ @"text": @"hi" }, nil));
	XCTAssertEqual(TGMessageDecorationHeight(@{}, NO), TGMetricZero);
}

- (void)testQuote_InlineQuoteWinsThenTheLoadedOriginalThenDots {
	NSDictionary *inlineQuote = @{ @"replyId": @7, @"replyText": @"quoted",
			@"quoteEntities": @[ @1 ] };
	XCTAssertEqualObjects(TGMessageQuoteText(inlineQuote, nil), @"quoted");
	XCTAssertEqualObjects(TGMessageQuoteEntities(inlineQuote, nil), (@[ @1 ]));

	NSDictionary *reply = @{ @"replyId": @7 };
	XCTAssertEqualObjects(TGMessageQuoteText(reply, nil), @"...");
	NSDictionary *original = @{ @"id": @7, @"kind": @"messageText", @"text": @"orig",
			@"entities": @[ @2 ] };
	XCTAssertEqualObjects(TGMessageQuoteText(reply, original), @"orig");
	XCTAssertEqualObjects(TGMessageQuoteEntities(reply, original), (@[ @2 ]));
}

- (void)testQuote_AuthorIsKnownOnlyOnceTheOriginalIs {
	XCTAssertNil(TGMessageQuoteAuthor(nil, @"Alice"));
	XCTAssertEqualObjects(TGMessageQuoteAuthor(@{ @"outgoing": @NO }, @"Alice"), @"Alice");
	XCTAssertEqualObjects(TGMessageQuoteAuthor(@{ @"outgoing": @YES }, @"Alice"), @"You");
}

- (void)testDecoration_EachPartAddsItsHeight {
	NSDictionary *m = @{ @"forward": @"Bob", @"canComment": @YES,
			@"inlineRows": @[ @[], @[] ] };
	CGFloat expected = TGMetricQuoteForwardLine + kQuoteBlock + TGMetricLineBody +
			2 * (TGMetricBotButtonHeight + TGMetricBotButtonGap) + TGMetricBotButtonGap;
	XCTAssertEqual(TGMessageDecorationHeight(m, YES), expected);
	XCTAssertEqual(TGMessageDecorationHeight(m, NO), expected - kQuoteBlock);
}

#pragma mark - poll and checklist

- (void)testPoll_VoteButtonOnlyForAPendingMultipleAnswerDraft {
	NSDictionary *m = @{ @"id": @1, @"poll": @{ @"question": @"Q?", @"allowsMultiple": @YES,
			@"options": @[ @{ @"text": @"a" }, @{ @"text": @"b" } ] } };
	CGFloat idle = TGMessagePollHeight(m, nil);
	CGFloat drafting = TGMessagePollHeight(m, [NSIndexSet indexSetWithIndex:0]);
	XCTAssertEqual(drafting - idle, kPollVoteGap + kPollVoteHeight);
	XCTAssertEqual(TGMessagePollHeight(m, [NSIndexSet indexSet]), idle);
}

- (void)testPoll_EachOptionAddsAtLeastARow {
	NSDictionary *one = @{ @"poll": @{ @"question": @"Q?", @"options": @[ @{ @"text": @"a" } ] } };
	NSDictionary *two = @{ @"poll": @{ @"question": @"Q?",
			@"options": @[ @{ @"text": @"a" }, @{ @"text": @"b" } ] } };
	XCTAssertGreaterThanOrEqual(TGMessagePollHeight(two, nil) - TGMessagePollHeight(one, nil),
			kPollRow);
}

- (void)testChecklist_EachTaskAddsAtLeastARow {
	NSDictionary *none = @{ @"checklist": @{ @"title": @"T", @"tasks": @[] } };
	NSDictionary *two = @{ @"checklist": @{ @"title": @"T",
			@"tasks": @[ @{ @"text": @"x" }, @{ @"text": @"y" } ] } };
	XCTAssertGreaterThanOrEqual(TGMessageChecklistHeight(two) - TGMessageChecklistHeight(none),
			kChecklistTitleGap + 2 * kChecklistRow);
}

#pragma mark - service line

- (void)testService_NamesWhoActedExceptOnSelfDescribingLines {
	XCTAssertEqualObjects(TGMessageServiceLine(@{ @"text": @"joined the group" }, @"Ann", nil),
			@"Ann joined the group");
	XCTAssertEqualObjects(TGMessageServiceLine(@{ @"text": @"Group created" }, @"Ann", nil),
			@"Group created");
	XCTAssertEqualObjects(TGMessageServiceLine(@{ @"text": @"Today" }, nil, nil), @"Today");
}

- (void)testService_PinQuotesTheLoadedMessage {
	NSDictionary *pin = @{ @"text": @"pinned a message", @"kind": @"messagePinMessage",
			@"pinnedMessageId": @9 };
	NSArray *loaded = @[ @{ @"id": @9, @"kind": @"messageText", @"text": @"Hello world" } ];
	XCTAssertEqualObjects(TGMessageServiceLine(pin, @"Ann", nil), @"Ann pinned a message");
	XCTAssertEqualObjects(TGMessageServiceLine(pin, @"Ann", loaded), @"Ann pinned \"Hello world\"");
}

@end
