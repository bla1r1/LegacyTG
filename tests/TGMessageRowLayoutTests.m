// TGMessageRowLayoutTests.m - a chat row's frames from TGMessageRowLayout.
//
// The function was -layoutForMessage:atRow:. Moving it was checked on the
// iPod touch 4 by dumping every TGMessageLayout property of three chats
// (135 rows, 26 kinds) before and after: identical. These tests pin the
// rules that dump relied on, one kind at a time.
#import "TGTestRunner.h"
#import "TGMessageRowLayout.h"
#import "TGMessageLayout.h"
#import "TGMessageMetrics.h"

@interface TGMessageRowLayoutTests : XCTestCase @end

static TGMessageRowInput *rlInput(NSDictionary *m) {
	TGMessageRowInput *in = [[TGMessageRowInput alloc] init];
	NSMutableDictionary *message = [@{ @"id": @1, @"date": @1700000000, @"kind": @"messageText" } mutableCopy];
	[message addEntriesFromDictionary:m];
	in.message = message;
	in.tableWidth = 320;
	in.fontSize = 15;
	in.runStart = YES;
	in.runEnd = YES;
	return in;
}

@implementation TGMessageRowLayoutTests

#pragma mark - separators and service lines

- (void)testUnread_IsAFullWidthBand {
	TGMessageLayout *l = TGMessageRowLayout(rlInput(@{ @"separator": @"unread",
			@"text": @"Unread Messages", @"service": @YES }));
	XCTAssertTrue(l.isUnreadSeparator);
	XCTAssertEqual(l.bubbleFrame.size.width, (CGFloat)320);
	XCTAssertEqual(l.rowHeight, kServiceRow);
}

- (void)testService_PlateIsCentredAndADayGetsMoreAir {
	TGMessageRowInput *event = rlInput(@{ @"service": @YES, @"text": @"joined the group" });
	event.serviceWho = @"Ann";
	TGMessageLayout *l = TGMessageRowLayout(event);
	XCTAssertEqualObjects(l.serviceText, @"Ann joined the group");
	XCTAssertEqual(CGRectGetMidX(l.bubbleFrame), (CGFloat)160);
	XCTAssertEqual(l.rowHeight, kServiceEventRow);
	TGMessageLayout *day = TGMessageRowLayout(rlInput(@{ @"service": @YES,
			@"separator": @"date", @"text": @"November 11" }));
	XCTAssertTrue(day.isDateHeader);
	XCTAssertEqual(day.rowHeight, kServiceRow);
}

- (void)testZeroTableWidth_IsTheScreen {
	TGMessageRowInput *in = rlInput(@{ @"separator": @"unread", @"service": @YES });
	in.tableWidth = 0;
	XCTAssertEqual(TGMessageRowLayout(in).bubbleFrame.size.width, TGMetricScreenWidth);
}

#pragma mark - fixed-size bubbles

- (void)testPoll_SomeoneElsesInAGroupGetsANameLineAndMovesRight {
	NSDictionary *m = @{ @"kind": @"messagePoll", @"poll": @{ @"question": @"Q?",
			@"options": @[ @{ @"text": @"a" } ] } };
	TGMessageLayout *plain = TGMessageRowLayout(rlInput(m));
	TGMessageRowInput *grouped = rlInput(m);
	grouped.isGroup = YES;
	grouped.senderName = @"Ann";
	TGMessageLayout *named = TGMessageRowLayout(grouped);
	XCTAssertEqualObjects(named.senderName, @"Ann");
	XCTAssertEqual(named.bubbleFrame.size.height - plain.bubbleFrame.size.height,
			TGMetricSenderLineHeight);
	XCTAssertEqual(named.bubbleFrame.origin.x - plain.bubbleFrame.origin.x,
			kAvatarSide + TGMetricPadSmall + kTailWidth);
	XCTAssertEqual(plain.bubbleFrame.size.height, TGMessagePollHeight(m, nil));
}

- (void)testCall_WidthStaysBetweenItsLimits {
	TGMessageLayout *shortCall = TGMessageRowLayout(rlInput(@{ @"kind": @"messageCall", @"text": @"Call" }));
	XCTAssertEqual(shortCall.bubbleFrame.size.width, kCallBubbleMin);
	NSString *longText = [@"" stringByPaddingToLength:300 withString:@"Missed call " startingAtIndex:0];
	TGMessageLayout *longCall = TGMessageRowLayout(rlInput(@{ @"kind": @"messageCall", @"text": longText }));
	XCTAssertEqual(longCall.bubbleFrame.size.width, kBubbleMaxW);
}

- (void)testMineSitsRightTheirsLeft {
	TGMessageLayout *theirs = TGMessageRowLayout(rlInput(@{ @"kind": @"messageContact" }));
	TGMessageLayout *mine = TGMessageRowLayout(rlInput(@{ @"kind": @"messageContact", @"outgoing": @YES }));
	XCTAssertEqual(theirs.bubbleFrame.origin.x, TGMetricPad);
	XCTAssertEqual(CGRectGetMaxX(mine.bubbleFrame), (CGFloat)(320 - TGMetricPad));
	XCTAssertTrue(CGSizeEqualToSize(mine.bubbleFrame.size, CGSizeMake(kContactBubble, kContactBubbleH)));
}

- (void)testDocument_CaptionThatIsTheFileNameIsNotRepeated {
	TGMessageLayout *named = TGMessageRowLayout(rlInput(@{ @"kind": @"messageDocument",
			@"docName": @"report.pdf", @"text": @"report.pdf" }));
	XCTAssertTrue(CGRectIsEmpty(named.bodyFrame));
	TGMessageLayout *captioned = TGMessageRowLayout(rlInput(@{ @"kind": @"messageDocument",
			@"docName": @"report.pdf", @"text": @"see page 3" }));
	XCTAssertGreaterThan(captioned.bodyFrame.size.height, (CGFloat)0);
	XCTAssertGreaterThan(captioned.rowHeight, named.rowHeight);
}

- (void)testLocation_IsAFixedCardWhateverTheKind {
	XCTAssertTrue(TGMessageIsLocation(@{ @"kind": @"messageVenue" }));
	XCTAssertTrue(TGMessageIsLocation(@{ @"kind": @"messageText", @"lat": @50.4 }));
	XCTAssertFalse(TGMessageIsLocation(@{ @"kind": @"messageText", @"lat": [NSNull null] }));
	TGMessageLayout *l = TGMessageRowLayout(rlInput(@{ @"kind": @"messageLocation", @"lat": @50.4 }));
	XCTAssertTrue(l.isLocation);
	XCTAssertTrue(CGSizeEqualToSize(l.bubbleFrame.size, CGSizeMake(kLocationBubble, kLocationBubbleH)));
}

- (void)testAnimatedSticker_SquareOnlyOnceItsFileIsReady {
	NSDictionary *m = @{ @"kind": @"messageSticker", @"docName": @"tgs", @"photoId": @5 };
	TGMessageRowInput *ready = rlInput(m);
	ready.animatedStickerReady = YES;
	ready.imageSize = CGSizeMake(100, 100);
	XCTAssertTrue(CGSizeEqualToSize(TGMessageRowLayout(ready).bubbleFrame.size, CGSizeMake(kLottieSide, kLottieSide + TGMetricLineMicro)));
	TGMessageRowInput *waiting = rlInput(m);
	waiting.imageSize = CGSizeMake(100, 100);
	XCTAssertEqual(TGMessageRowLayout(waiting).pictureFrame.size.height, (CGFloat)100);
}

#pragma mark - plain bubbles

- (void)testText_ShortMessageKeepsTheStampOnItsLine {
	TGMessageLayout *l = TGMessageRowLayout(rlInput(@{ @"text": @"ok" }));
	XCTAssertTrue(l.inlineStamp);
	XCTAssertFalse(l.stampOnPicture);
	TGMessageLayout *two = TGMessageRowLayout(rlInput(@{ @"text": @"ok\nok" }));
	XCTAssertFalse(two.inlineStamp);
	XCTAssertGreaterThan(two.bubbleFrame.size.height, l.bubbleFrame.size.height);
}

- (void)testPhoto_WithoutCaptionCarriesTheStampOnThePicture {
	TGMessageRowInput *in = rlInput(@{ @"kind": @"messagePhoto", @"photoId": @9, @"text": @"" });
	in.imageSize = CGSizeMake(200, 150);
	TGMessageLayout *l = TGMessageRowLayout(in);
	XCTAssertTrue(l.stampOnPicture);
	XCTAssertTrue(CGSizeEqualToSize(l.pictureFrame.size, CGSizeMake(200, 150)));
	XCTAssertGreaterThan(l.mediaStampFrame.size.width, (CGFloat)0);
}

- (void)testAlbum_ThreeItemsAreOneOverTwo {
	TGMessageLayout *l = TGMessageRowLayout(rlInput(@{ @"kind": @"messagePhoto", @"isAlbum": @YES,
			@"albumMessages": @[ @{}, @{}, @{} ] }));
	XCTAssertEqual(l.albumFrames.count, (NSUInteger)3);
	XCTAssertEqual(l.collageFrame.size.height,
			TGMetricCollageTopHeight + TGMetricCollageGap + TGMetricCollageBottomHeight);
}

- (void)testReactions_AddTheirRowUnderTheBubble {
	TGMessageLayout *bare = TGMessageRowLayout(rlInput(@{ @"text": @"hi" }));
	TGMessageLayout *reacted = TGMessageRowLayout(rlInput(@{ @"text": @"hi",
			@"reactionGroups": @[ @{ @"emoji": @"x" } ] }));
	XCTAssertEqual(reacted.rowHeight - bare.rowHeight,
			TGMetricReactionChipHeight + TGMetricReactionChipTop);
	XCTAssertEqual(reacted.reactionChipsFrame.origin.y,
			CGRectGetMaxY(reacted.bubbleFrame) + TGMetricReactionChipTop);
}

- (void)testQuote_PlacesTheBlockAndItsAuthor {
	TGMessageRowInput *in = rlInput(@{ @"text": @"yes", @"replyId": @7 });
	in.replied = @{ @"id": @7, @"kind": @"messageText", @"text": @"really?" };
	in.quoteAuthor = @"Ann";
	TGMessageLayout *l = TGMessageRowLayout(in);
	XCTAssertEqualObjects(l.quoteText, @"really?");
	XCTAssertEqualObjects(l.quoteAuthor, @"Ann");
	XCTAssertEqual(l.bodyFrame.origin.y, kPadV + kQuoteBlock);
}

- (void)testSenderLine_MeasuredOnlyForAPlainBubble {
	// Measuring the line with its emoji status is the costly part on an A4;
	// a card or a poll draws its name without it.
	__block NSUInteger asked = 0;
	CGFloat (^measure)(NSString *) = ^CGFloat(NSString *line){ asked++; return 150; };
	TGMessageRowInput *poll = rlInput(@{ @"kind": @"messagePoll" });
	poll.isGroup = YES;
	poll.senderName = @"Ann";
	poll.senderLineWidth = measure;
	TGMessageRowLayout(poll);
	XCTAssertEqual(asked, (NSUInteger)0);

	TGMessageRowInput *text = rlInput(@{ @"text": @"hi", @"senderTag": @"admin" });
	text.isGroup = YES;
	text.senderName = @"Ann";
	text.senderLineWidth = measure;
	TGMessageLayout *l = TGMessageRowLayout(text);
	XCTAssertEqual(asked, (NSUInteger)1);
	XCTAssertEqualObjects(l.senderName, @"Ann · admin");
	XCTAssertEqual(l.bubbleFrame.size.width, (CGFloat)(150 + 2 * kPadH));
}

@end
