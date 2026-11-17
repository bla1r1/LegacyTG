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

- (void)testStamp_BusinessBotNameBeforeTheTime {
	// Parity: official signs a Business bot's reply with the bot's name by
	// the time (StringForMessageTimestampStatus.swift).
	NSString *time = TGMessageStampText(@{ @"date": @1700000000 });
	NSString *stamp = TGMessageStampText(@{ @"date": @1700000000, @"businessBotName": @"Shop Bot" });
	XCTAssertEqualObjects(stamp, [@"Shop Bot, " stringByAppendingString:time]);
}

// Parity: a reply to one checklist task quotes the task
// (official ChatMessageReplyInfoNode, innerSubject .todoItem).
- (void)testQuote_ChecklistTask {
	NSDictionary *replied = @{ @"checklist" : @{ @"tasks" : @[
		@{ @"taskId" : @1, @"text" : @"Buy milk" },
		@{ @"taskId" : @2, @"text" : @"Call Ann" } ] } };
	NSDictionary *m = @{ @"replyId" : @5, @"replyTaskId" : @2 };
	XCTAssertEqualObjects(TGMessageQuotedTask(m, replied), @"Call Ann");
	XCTAssertEqualObjects(TGMessageQuoteText(m, replied), @"Call Ann");
	XCTAssertNil(TGMessageQuotedTask(@{ @"replyId" : @5 }, replied));
	XCTAssertNil(TGMessageQuotedTask(@{ @"replyId" : @5, @"replyTaskId" : @9 }, replied));
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
	CGFloat expected = TGMetricQuoteForwardLine + kQuoteBlock + kCommentsBar +
			2 * (TGMetricBotButtonHeight + TGMetricBotButtonGap) + TGMetricBotButtonGap;
	XCTAssertEqual(TGMessageDecorationHeight(m, YES), expected);
	XCTAssertEqual(TGMessageDecorationHeight(m, NO), expected - kQuoteBlock);
}

- (void)testComments_TitleSpacesTheCount {
	XCTAssertEqualObjects(TGMessageCommentsTitle(12), @"12 Comments");
	XCTAssertEqualObjects(TGMessageCommentsTitle(1), @"1 Comment");
	XCTAssertEqualObjects(TGMessageCommentsTitle(0), @"Leave a Comment");
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


#pragma mark - parity fields

// Message.ImportedDateFormat: the first day comes before "Imported".
- (void)testStamp_ImportedMessageKeepsItsFirstDate {
	NSString *plain = TGMessageStampText(@{@"date" : @1700000000});
	NSString *imported = TGMessageStampText(@{@"date" : @1700000000, @"importDate" : @1600000000});
	XCTAssertTrue([imported rangeOfString:@" Imported "].location != NSNotFound, @"%@", imported);
	XCTAssertTrue([imported hasSuffix:plain]);
	XCTAssertTrue(TGMessageStampWidth(@{@"date" : @1700000000, @"importDate" : @1600000000})
			> TGMessageStampWidth(@{@"date" : @1700000000}));
}

- (void)testBoostBadge_OnlyIncomingAndCountPastOne {
	XCTAssertNil(TGMessageBoostBadgeText(@{}));
	XCTAssertNil(TGMessageBoostBadgeText(@{@"boostCount" : @3, @"outgoing" : @YES}));
	XCTAssertEqualObjects(TGMessageBoostBadgeText(@{@"boostCount" : @1}), @"");
	XCTAssertEqualObjects(TGMessageBoostBadgeText(@{@"boostCount" : @3}), @"3");
	XCTAssertTrue(TGMessageBoostBadgeWidth(@{@"boostCount" : @3}) >
			TGMessageBoostBadgeWidth(@{@"boostCount" : @1}));
	XCTAssertEqual(TGMessageBoostBadgeWidth(@{}), (CGFloat)0);
}

- (void)testLinkPreviewMedia_LargeFillsTheColumnSmallIsTheCorner {
	XCTAssertTrue(CGSizeEqualToSize(TGLinkPreviewMediaSize(@{}, 200), CGSizeZero));
	NSDictionary *small = @{@"linkPreviewPhotoId" : @5, @"linkPreviewPhotoW" : @800,
			@"linkPreviewPhotoH" : @400, @"linkPreviewLarge" : @NO};
	XCTAssertEqual(TGLinkPreviewMediaSize(small, 200).width, kLinkThumbSide);
	NSMutableDictionary *large = [small mutableCopy];
	large[@"linkPreviewLarge"] = @YES;
	CGSize size = TGLinkPreviewMediaSize(large, 200);
	XCTAssertEqual(size.width, (CGFloat)200);
	XCTAssertEqual(size.height, (CGFloat)100);
}


// The eye sits its own gap from the count, not that plus the label's slack:
// "after the views the gap is large" on every channel post.
- (void)testStampEye_GapIsTheEyePadOnly {
	NSDictionary *post = @{@"date" : @1700000000, @"viewCount" : @1800000};
	TGMessageStampParts p = TGMessageStampPlace(post, 300, 50);
	CGFloat words = TGTextSize(TGMessageStampText(post), TGFontMicro(), 0).width;
	CGFloat textStart = CGRectGetMaxX(p.text) - words;
	XCTAssertTrue(fabs(textStart - CGRectGetMaxX(p.eye) - kStampEyePad) < 0.01, @"gap %f", textStart - CGRectGetMaxX(p.eye));
	XCTAssertTrue(fabs(p.width - (300 - p.eye.origin.x)) < 0.01);
}

@end
