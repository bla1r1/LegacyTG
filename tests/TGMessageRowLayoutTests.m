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
	// The photo fills its bubble to kMediaInset of every edge (it sat in the
	// text padding, which read as a heavy frame) and keeps its proportions.
	CGFloat w = l.bubbleFrame.size.width - 2 * kMediaInset;
	XCTAssertEqual(l.pictureFrame.origin.x, kMediaInset);
	XCTAssertEqual(l.pictureFrame.origin.y, kMediaInset);
	XCTAssertEqual(l.pictureFrame.size.width, w);
	XCTAssertEqual(l.pictureFrame.size.height, floorf(150 * w / 200));
	XCTAssertEqual(CGRectGetMaxY(l.pictureFrame) + kMediaInset, l.bubbleFrame.size.height);
	// The plate sits on the photo's corner, inside it.
	XCTAssertGreaterThan(l.mediaStampFrame.size.width, (CGFloat)0);
	XCTAssertLessThanOrEqual(CGRectGetMaxX(l.mediaStampFrame), CGRectGetMaxX(l.pictureFrame));
}

- (void)testAlbum_ThreeItemsAreOneOverTwo {
	TGMessageLayout *l = TGMessageRowLayout(rlInput(@{ @"kind": @"messagePhoto", @"isAlbum": @YES,
			@"albumMessages": @[ @{}, @{}, @{} ] }));
	XCTAssertEqual(l.albumFrames.count, (NSUInteger)3);
	// One over two, scaled with the bubble's width so the album fills it.
	CGFloat scale = l.collageFrame.size.width / TGMetricCollageWidth;
	XCTAssertEqual(l.collageFrame.size.width, l.bubbleFrame.size.width - 2 * kMediaInset);
	XCTAssertEqual(l.collageFrame.size.height, floorf((TGMetricCollageTopHeight
			+ TGMetricCollageGap + TGMetricCollageBottomHeight) * scale));
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

- (void)testPhoto_LongCaptionExpandsBubbleWithoutSquishingText {
	// In official Telegram, a long caption is not squeezed down to a narrow photo's width;
	// the bubble expands to comfortably fit the text rather than collapsing to the 200 pt photo.
	NSString *caption = [@"" stringByPaddingToLength:400 withString:@"word " startingAtIndex:0];
	TGMessageRowInput *in = rlInput(@{ @"kind" : @"messagePhoto", @"photoId" : @9, @"text" : caption });
	in.imageSize = CGSizeMake(200, 150);
	TGMessageLayout *l = TGMessageRowLayout(in);
	XCTAssertGreaterThan(l.bubbleFrame.size.width, (CGFloat)(200 + 2 * kMediaInset));
	CGFloat mediaW = l.bubbleFrame.size.width - 2 * kMediaInset;
	XCTAssertEqual(l.pictureFrame.size.width, mediaW);
	XCTAssertEqual(l.pictureFrame.size.height, floorf(150.0f * mediaW / 200.0f));
	XCTAssertEqual(l.bodyFrame.size.width, l.bubbleFrame.size.width - 2 * kPadH);
	XCTAssertFalse(l.inlineStamp);
	XCTAssertGreaterThanOrEqual(l.timeFrame.origin.y, CGRectGetMaxY(l.bodyFrame));
}

- (void)testPhoto_ShortCaptionKeepsBubbleAtPhotoWidth {
	// When text is shorter than the photo, the photo width sets the bubble width.
	TGMessageRowInput *in = rlInput(@{ @"kind" : @"messagePhoto", @"photoId" : @9, @"text" : @"Hi" });
	in.imageSize = CGSizeMake(200, 150);
	TGMessageLayout *l = TGMessageRowLayout(in);
	XCTAssertEqual(l.bubbleFrame.size.width, (CGFloat)(200 + 2 * kMediaInset));
	XCTAssertEqual(l.pictureFrame.size.height, (CGFloat)150);
}

#pragma mark - the stamp

- (void)testStamp_EyeCountTimeAndTicksOnOneLineWithoutOverlap {
	// The cell moved the text right by the eye's room a second time: the
	// count drifted off its eye and the time was cut to "2.1M...".
	NSDictionary *m = @{ @"date" : @1700000000, @"viewCount" : @2100000, @"outgoing" : @YES };
	TGMessageStampParts p = TGMessageStampPlace(m, 200, 50);
	// The label keeps a 2 pt slack on its left; the eye sits over it, so the
	// gap to the count is the eye pad alone.
	XCTAssertEqual(CGRectGetMaxX(p.eye) + kStampEyePad, p.text.origin.x + TGMetricPadTiny);
	XCTAssertEqual(p.text.size.width, TGTextSize(TGMessageStampText(m), TGFontMicro(), 0).width + TGMetricPadTiny);
	XCTAssertLessThanOrEqual(CGRectGetMaxX(p.text), p.ticks.origin.x);
	XCTAssertEqual(CGRectGetMaxX(p.ticks), (CGFloat)200);
	XCTAssertEqual(CGRectGetMidY(p.text), (CGFloat)50);
	XCTAssertEqual(p.width, 200 - p.eye.origin.x);
	XCTAssertEqual(p.width, TGMessageStampWidth(m));
	TGMessageStampParts theirs = TGMessageStampPlace(@{ @"date" : @1700000000 }, 200, 50);
	XCTAssertTrue(CGRectIsEmpty(theirs.eye));
	XCTAssertTrue(CGRectIsEmpty(theirs.ticks));
	XCTAssertEqual(CGRectGetMaxX(theirs.text), (CGFloat)200);
}

- (void)testStamp_SentDocumentLeavesTheTicksTheirRoom {
	NSDictionary *m = @{ @"kind" : @"messageDocument", @"docName" : @"a.pdf", @"outgoing" : @YES };
	TGMessageLayout *l = TGMessageRowLayout(rlInput(m));
	XCTAssertFalse(CGRectIsEmpty(l.stampTicksFrame));
	XCTAssertLessThanOrEqual(CGRectGetMaxX(l.timeFrame), l.stampTicksFrame.origin.x);
}

- (void)testStamp_ContactTimeHasItsOwnLineAboveTheButtons {
	TGMessageLayout *l = TGMessageRowLayout(rlInput(@{ @"kind" : @"messageContact" }));
	XCTAssertLessThanOrEqual(CGRectGetMaxY(l.timeFrame), TGMetricPersonRow + TGMetricLineMicro);
	XCTAssertGreaterThanOrEqual(l.timeFrame.origin.y, TGMetricPersonRow);
	XCTAssertEqual(l.bubbleFrame.size.height, kContactBubbleH);
}

// Item 11: the caption of a file is not the file, and beside the bubble is
// nothing at all.
- (void)testTap_DocumentOpensOnlyFromItsTile {
	NSDictionary *m = @{ @"kind" : @"messageDocument", @"docName" : @"a.pdf", @"text" : @"a caption under the file" };
	TGMessageLayout *l = TGMessageRowLayout(rlInput(m));
	CGRect b = l.bubbleFrame;
	CGPoint onTile = CGPointMake(b.origin.x + CGRectGetMidX(l.documentFrame), b.origin.y + CGRectGetMidY(l.documentFrame));
	XCTAssertEqual(TGMessageTapPartAt(l, onTile), TGMessageTapDocument);
	CGPoint onCaption = CGPointMake(b.origin.x + CGRectGetMidX(l.documentFrame), CGRectGetMaxY(b) - 2);
	XCTAssertEqual(TGMessageTapPartAt(l, onCaption), TGMessageTapBubble);
	XCTAssertEqual(TGMessageTapPartAt(l, CGPointMake(CGRectGetMaxX(b) + 4, CGRectGetMidY(b))), TGMessageTapNone);
}

- (void)testTap_ReplyJumpsOnlyFromItsQuote {
	TGMessageRowInput *in = rlInput(@{ @"text" : @"an answer long enough to have its own line", @"replyId" : @7 });
	in.replied = @{ @"id": @7, @"kind": @"messageText", @"text": @"the question" };
	in.quoteAuthor = @"Ann";
	TGMessageLayout *l = TGMessageRowLayout(in);
	XCTAssertFalse(CGRectIsEmpty(l.quoteFrame));
	CGRect b = l.bubbleFrame;
	XCTAssertEqual(TGMessageTapPartAt(l, CGPointMake(b.origin.x + CGRectGetMidX(l.quoteFrame), b.origin.y + CGRectGetMidY(l.quoteFrame))), TGMessageTapQuote);
	XCTAssertEqual(TGMessageTapPartAt(l, CGPointMake(b.origin.x + CGRectGetMidX(l.bodyFrame), b.origin.y + CGRectGetMaxY(l.bodyFrame) - 2)), TGMessageTapBubble);
}

// The official footer: under the text and the time, across the bubble's
// bottom, never between the text and its time.
- (void)testComments_FooterIsTheLastRowUnderTheTime {
	TGMessageLayout *l = TGMessageRowLayout(rlInput(@{ @"text" : @"Major update: full support for legacy iOS vector and video stickers has landed!",
			@"forward" : @"Pavel Durov", @"canComment" : @YES, @"replyCount" : @12 }));
	CGRect f = l.commentsFrame;
	XCTAssertEqual(f.size.height, kCommentsBar);
	XCTAssertEqual(CGRectGetMaxY(f), l.bubbleFrame.size.height);
	XCTAssertEqual(f.size.width, l.bubbleFrame.size.width);
	XCTAssertLessThanOrEqual(CGRectGetMaxY(l.timeFrame), f.origin.y);
	XCTAssertLessThanOrEqual(CGRectGetMaxY(l.bodyFrame), f.origin.y);
}

- (void)testTrack_TimeSitsInsideTheBubbleBottomRight {
	TGMessageLayout *l = TGMessageRowLayout(rlInput(@{ @"kind" : @"messageAudio", @"audioTitle" : @"Midnight City",
			@"audioPerformer" : @"M83", @"duration" : @243, @"outgoing" : @YES }));
	XCTAssertGreaterThan(l.timeFrame.size.width, (CGFloat)0);
	XCTAssertLessThanOrEqual(CGRectGetMaxY(l.timeFrame), l.bubbleFrame.size.height);
	XCTAssertGreaterThanOrEqual(CGRectGetMaxY(l.timeFrame), l.bubbleFrame.size.height - kPadV - TGMetricStampHeight);
	XCTAssertLessThanOrEqual(CGRectGetMaxX(l.timeFrame), l.stampTicksFrame.origin.x);
	XCTAssertLessThanOrEqual(CGRectGetMaxX(l.stampTicksFrame), l.bubbleFrame.size.width);
}

- (void)testSenderLine_NamesTheInlineBot {
	XCTAssertEqualObjects(TGMessageSenderLine(@"Ann", @{ @"viaBot" : @"gif" }), @"Ann via @gif");
	XCTAssertEqualObjects(TGMessageSenderLine(@"Ann", @{ @"viaBot" : @"gif", @"senderTag" : @"admin" }), @"Ann via @gif · admin");
	XCTAssertEqualObjects(TGMessageSenderLine(@"Ann", @{}), @"Ann");
}

/// Official's button under a Telegram link's preview takes a row of its own
/// below the preview and adds that row to the bubble.
- (void)testLinkPreview_ActionRowSitsUnderThePreview {
	NSDictionary *m = @{ @"text": @"t.me/cats", @"linkPreviewSite": @"Telegram",
			@"linkPreviewTitle": @"Cats", @"linkPreviewUrl": @"https://t.me/cats" };
	TGMessageLayout *plain = TGMessageRowLayout(rlInput(m));
	NSMutableDictionary *withButton = [m mutableCopy];
	withButton[@"linkPreviewAction"] = @"VIEW CHANNEL";
	TGMessageLayout *button = TGMessageRowLayout(rlInput(withButton));
	XCTAssertEqualObjects(button.linkAction, @"VIEW CHANNEL");
	XCTAssertEqual(button.linkActionFrame.origin.y, CGRectGetMaxY(button.linkPreviewFrame));
	XCTAssertEqual(button.bubbleFrame.size.height - plain.bubbleFrame.size.height,
			TGMetricButtonSmallH);
	XCTAssertTrue(CGRectIsEmpty(plain.linkActionFrame));
}

- (void)testTextsToMeasure_CopiesEveryText {
	NSMutableString *text = [NSMutableString stringWithString:@"hello"];
	NSArray *messages = @[
		@{ @"id" : @1, @"kind" : @"messageText", @"text" : text,
		   @"entities" : @[ @{ @"type" : @{ @"@type" : @"textEntityTypeBold" }, @"offset" : @0, @"length" : @5 } ] },
		@{ @"id" : @2, @"kind" : @"messageText", @"text" : @"\U0001F600",
		   @"entities" : @[ @{ @"type" : @{ @"@type" : @"textEntityTypeCustomEmoji", @"custom_emoji_id" : @"7" },
							  @"offset" : @0, @"length" : @2 } ] },
		@{ @"id" : @3, @"kind" : @"messagePhoto" },
		@{ @"id" : @4, @"kind" : @"messagePhoto", @"text" : @"caption" },
	];
	NSArray *texts = TGMessageTextsToMeasure(messages);
	XCTAssertEqual(texts.count, (NSUInteger)3);
	XCTAssertEqualObjects(texts[0][@"text"], @"hello");
	XCTAssertEqual([texts[0][@"entities"] count], (NSUInteger)1);
	XCTAssertEqualObjects(texts[2][@"text"], @"caption");
	// A later edit of the store's string does not reach the measure.
	[text appendString:@" world"];
	XCTAssertEqualObjects(texts[0][@"text"], @"hello");
}

- (void)testMeasureOffMain_GivesTheSizeTheRowLayoutReads {
	NSMutableArray *messages = [NSMutableArray array];
	for (int i = 0; i < 200; i++)
		[messages addObject:@{ @"kind" : @"messageText",
				@"text" : [NSString stringWithFormat:@"line %d of a page measured on another thread \U0001F600", i] }];
	NSArray *texts = TGMessageTextsToMeasure(messages);
	dispatch_group_t group = dispatch_group_create();
	dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		TGMeasureMessageTexts(texts, 16);
	});
	// The main thread measures the same page meanwhile, as reloadData would.
	CGFloat heights[200];
	for (NSUInteger i = 0; i < messages.count; i++)
		heights[i] = TGMessageBodySize(messages[i], 16).height;
	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
	for (NSUInteger i = 0; i < messages.count; i++) {
		CGSize after = TGMessageBodySize(messages[i], 16);
		XCTAssertEqual(heights[i], after.height);
		XCTAssertTrue(after.height > 0);
	}
}

/// A message with custom emoji measures off the main thread to the size the
/// main thread gets: on the iPod touch 4 they were left for reloadData, 16%
/// of the first scroll of a chat full of them.
- (void)testCustomEmojiOffMain_SameSizeAsOnMain {
	NSDictionary *m = @{ @"kind" : @"messageText", @"text" : @"ab \U0001F600 cd",
		@"entities" : @[ @{ @"type" : @{ @"@type" : @"textEntityTypeCustomEmoji", @"custom_emoji_id" : @"77" },
						   @"offset" : @3, @"length" : @2 } ] };
	__block CGSize off = CGSizeZero;
	dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		TGMeasureMessageTexts(TGMessageTextsToMeasure(@[ m ]), 17);
		off = TGMessageBodySize(m, 17);
	});
	XCTAssertTrue(off.height > 0);
	CGSize on = TGMessageBodySize(m, 17);
	XCTAssertEqual(on.width, off.width);
	XCTAssertEqual(on.height, off.height);
}

/// Buttons widen the bubble past the width the text was wrapped at. A body
/// frame that wide rewraps into fewer lines than it is tall: UILabel centres
/// them, and the custom emoji drawn from the frame's top sat lines above
/// their places in long channel posts on the iPod touch 4.
- (void)testWideBubble_BodyKeepsTheWidthItWasMeasuredAt {
	NSMutableString *text = [NSMutableString string];
	for (int i = 0; i < 40; i++)
		[text appendString:@"words that wrap across several lines "];
	TGMessageLayout *l = TGMessageRowLayout(rlInput(@{ @"kind": @"messageText", @"text": text,
			@"inlineRows": @[ @[ @{ @"text": @"Open" } ] ] }));
	CGFloat measured = kBubbleMaxW - TGDoubled(kPadH);
	XCTAssertTrue(l.bubbleFrame.size.width > measured + TGDoubled(kPadH),
			@"the buttons are what make this bubble wide: %f", l.bubbleFrame.size.width);
	XCTAssertEqual(l.bodyFrame.size.width, measured);
	XCTAssertEqual(l.bodyFrame.size.height,
			TGTextSizeWithEntities(text, nil, TGFontAtSize(rlInput(@{}).fontSize), measured).height);
}

- (void)testIPadDetail_ProportionalBubbleWidth {
	NSMutableString *text = [NSMutableString string];
	for (int i = 0; i < 40; i++)
		[text appendString:@"iPad message words that wrap across wide lines "];
	TGMessageRowInput *in = rlInput(@{ @"kind": @"messageText", @"text": text });
	in.tableWidth = 447.0f;
	TGMessageLayout *l = TGMessageRowLayout(in);

	CGFloat expectedMaxBubble = TGMetricBubbleMaxWidthForTableWidth(447.0f);
	CGFloat expectedTextMax = TGMetricBubbleTextWidthForTableWidth(447.0f);
	XCTAssertTrue(l.bubbleFrame.size.width <= expectedMaxBubble);
	XCTAssertTrue(l.bubbleFrame.size.width > 280.0f, @"iPad bubble must be proportional and wider than iPhone 280pt cap: %f", l.bubbleFrame.size.width);
	XCTAssertTrue(l.bodyFrame.size.width <= expectedTextMax);
	XCTAssertTrue(l.bodyFrame.size.width > 250.0f, @"iPad body width wraps wider than iPhone 226pt: %f", l.bodyFrame.size.width);
}

/// A page of history is laid out on a background queue while the main
/// thread lays out rows of its own: the same answers, and the shared clock
/// formatter (not thread-safe on iOS 6) taken one at a time.
- (void)testRowLayout_OffMainMatchesMainUnderContention {
	NSMutableArray *inputs = [NSMutableArray array];
	for (int i = 0; i < 40; i++) {
		NSString *text = [NSString stringWithFormat:@"message %d with some words to wrap across a line or two", i];
		[inputs addObject:rlInput(@{ @"id": @(i + 1), @"date": @(1700000000 + i * 61), @"text": text,
				@"edited": @(i % 3 == 0), @"outgoing": @(i % 2) })];
	}
	NSMutableArray *main = [NSMutableArray array];
	for (TGMessageRowInput *in in inputs)
		[main addObject:TGMessageRowLayout(in)];
	__block BOOL same = YES;
	dispatch_apply(4, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t worker) {
		for (int round = 0; round < 5; round++)
			for (NSUInteger i = 0; i < inputs.count; i++) {
				TGMessageLayout *l = TGMessageRowLayout(inputs[i]);
				TGMessageLayout *m = main[i];
				if (l.rowHeight != m.rowHeight || !CGRectEqualToRect(l.bodyFrame, m.bodyFrame) ||
						![l.stamp isEqualToString:m.stamp])
					same = NO;
			}
	});
	XCTAssertTrue(same);
}

- (void)testEmojiMessage_StampDoesNotOverlapLastCharacter {
	NSString *text = @"\U0001F973 \U0001F97A \U0001F951 \U0001F996 \U0001F1FA\U0001F1E6";
	TGMessageLayout *l = TGMessageRowLayout(rlInput(@{
		@"text": text,
		@"outgoing": @YES,
		@"date": @1700000000
	}));

	if (l.inlineStamp) {
		CGFloat textRight = l.bodyFrame.origin.x + l.bodySize.width;
		CGFloat stampLeft = l.timeFrame.origin.x;
		if (!CGRectIsEmpty(l.stampEyeFrame))
			stampLeft = MIN(stampLeft, l.stampEyeFrame.origin.x);
		XCTAssertTrue(stampLeft >= textRight,
				@"Stamp (left %f) must not overlap or collide with text (right %f)", stampLeft, textRight);
	}
}

@end
