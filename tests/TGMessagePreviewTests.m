// TGMessagePreviewTests.m — the chat list's one-line preview.
//
// Every row in the list is a sentence about the last message, and the words
// come from TDLib fields nested by content type. A renamed key does not
// crash; it silently produces a generic word, which is the kind of failure
// nobody notices until the list reads wrong. These tests pin the wording
// and, for the fields that carry it, where it is read from.
#import "TGTestRunner.h"
#import "TGClientInternal.h"

@interface TGMessagePreviewTests : XCTestCase @end

static NSDictionary *pvMessage(NSDictionary *content, NSDictionary *extra) {
	NSMutableDictionary *m = [@{
		@"@type"       : @"message",
		@"id"          : @(5),
		@"is_outgoing" : @NO,
		@"content"     : content ?: @{},
	} mutableCopy];
	for (NSString *key in extra)
		m[key] = extra[key];
	return m;
}

static NSDictionary *pvFormatted(NSString *text) {
	return @{@"@type" : @"formattedText", @"text" : text ?: @""};
}

static NSString *pvPreview(NSDictionary *content) {
	return TGKnownMessagePreview(pvMessage(content, nil));
}

@implementation TGMessagePreviewTests

#pragma mark - text and plain media

- (void)testText_CarriesStraightThrough {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageText",
								   @"text" : pvFormatted(@"hello")}), @"hello");
}

- (void)testPhoto_WithoutCaption {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messagePhoto"}), @"Photo");
}

- (void)testVideo_WithoutCaption {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageVideo"}), @"Video");
}

- (void)testAnimation_IsGIF {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageAnimation"}), @"GIF");
}

- (void)testVoiceNote_Label {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageVoiceNote"}), @"Voice message");
}

- (void)testVideoNote_Label {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageVideoNote"}), @"Video message");
}

#pragma mark - sticker and document

- (void)testSticker_WithEmoji {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageSticker",
								   @"sticker" : @{@"emoji" : @"\U0001F600"}}),
						  @"\U0001F600 Sticker");
}

- (void)testSticker_WithoutEmoji {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageSticker",
								   @"sticker" : @{}}), @"Sticker");
}

- (void)testDocument_FileName {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageDocument",
								   @"document" : @{@"file_name" : @"deck.pdf"}}),
						  @"deck.pdf");
}

- (void)testDocument_WithoutFileNameIsFile {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageDocument",
								   @"document" : @{}}), @"File");
}

#pragma mark - audio

- (void)testAudio_PerformerAndTitle {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageAudio",
								   @"audio" : @{@"performer" : @"Queen",
												@"title" : @"Bohemian Rhapsody"}}),
						  @"Queen \u2013 Bohemian Rhapsody");
}

- (void)testAudio_PerformerOnly {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageAudio",
								   @"audio" : @{@"performer" : @"Queen",
												@"title" : @""}}), @"Queen");
}

- (void)testAudio_TitleOnly {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageAudio",
								   @"audio" : @{@"performer" : @"",
												@"title" : @"Bohemian Rhapsody"}}),
						  @"Bohemian Rhapsody");
}

- (void)testAudio_NeitherPartIsMusic {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageAudio",
								   @"audio" : @{}}), @"Music");
}

#pragma mark - people and places

- (void)testContact_FirstAndLastName {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageContact",
								   @"contact" : @{@"first_name" : @"Taras",
												  @"last_name" : @"Shevchenko"}}),
						  @"Taras Shevchenko");
}

- (void)testContact_FirstNameOnly {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageContact",
								   @"contact" : @{@"first_name" : @"Taras",
												  @"last_name" : @""}}), @"Taras");
}

- (void)testLocation_Label {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageLocation",
								   @"location" : @{@"latitude" : @(50.45),
												   @"longitude" : @(30.52)}}),
						  @"Location");
}

- (void)testLiveLocation_ItsOwnContentType {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageLiveLocation",
								   @"location" : @{@"location" : @{},
												   @"live_period" : @(900)}}),
						  @"Live Location");
}

- (void)testLiveLocation_LocationWithLivePeriod {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageLocation",
								   @"location" : @{@"latitude" : @(50.45),
												   @"longitude" : @(30.52)},
								   @"live_period" : @(900)}),
						  @"Live Location");
}

- (void)testVenue_Title {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageVenue",
								   @"venue" : @{@"title" : @"Cafe Kyiv"}}),
						  @"Cafe Kyiv");
}

- (void)testVenue_WithoutTitle {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageVenue",
								   @"venue" : @{}}), @"Venue");
}

#pragma mark - polls, checklists, dice, games

- (void)testPoll_Regular {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messagePoll",
								   @"poll" : @{@"question" : pvFormatted(@"Tea or coffee?"),
												@"type" : @{@"@type" : @"pollTypeRegular"}}}),
						  @"\U0001F4CA Tea or coffee?");
}

- (void)testPoll_Quiz {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messagePoll",
								   @"poll" : @{@"question" : pvFormatted(@"2 + 2?"),
												@"type" : @{@"@type" : @"pollTypeQuiz"}}}),
						  @"\U0001F4CA Quiz: 2 + 2?");
}

- (void)testChecklist_Title {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageChecklist",
								   @"list" : @{@"title" : pvFormatted(@"Groceries")}}),
						  @"\u2611\uFE0F Groceries");
}

- (void)testDice_ItsEmoji {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageDice",
								   @"emoji" : @"\U0001F3B2"}), @"\U0001F3B2");
}

- (void)testGame_Title {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageGame",
								   @"game" : @{@"title" : @"Chess"}}),
						  @"\U0001F3AE Chess");
}

#pragma mark - commerce and gifts

- (void)testInvoice_ProductTitle {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageInvoice",
								   @"product_info" : @{@"title" : @"Premium"}}),
						  @"Premium");
}

- (void)testPaidMedia_Label {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messagePaidMedia"}), @"Paid media");
}

- (void)testPaidMedia_CaptionWins {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messagePaidMedia",
								   @"caption" : pvFormatted(@"behind the scenes")}),
						  @"behind the scenes");
}

- (void)testGiveaway_Label {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageGiveaway"}), @"Giveaway");
}

- (void)testGiveawayWinners_Label {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageGiveawayWinners"}),
						  @"Giveaway results");
}

- (void)testGift_Label {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageGift"}), @"\U0001F381 Gift");
}

- (void)testUpgradedGift_Title {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageUpgradedGift",
								   @"gift" : @{@"title" : @"Delicious Cake"}}),
						  @"\U0001F381 Delicious Cake");
}

#pragma mark - stories and emoji

- (void)testStory_Label {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageStory"}), @"Story");
}

- (void)testAnimatedEmoji_ItsEmoji {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageAnimatedEmoji",
								   @"emoji" : @"\U0001F44D"}), @"\U0001F44D");
}

#pragma mark - calls

- (void)testCall_Missed {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageCall",
								   @"discard_reason" : @{@"@type" : @"callDiscardReasonMissed"},
								   @"is_video" : @NO}), @"Missed call");
}

- (void)testCall_DeclinedCountsAsMissed {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageCall",
								   @"discard_reason" : @{@"@type" : @"callDiscardReasonDeclined"},
								   @"is_video" : @NO}), @"Missed call");
}

- (void)testCall_Incoming {
	XCTAssertEqualObjects(TGKnownMessagePreview(pvMessage(@{
			@"@type" : @"messageCall",
			@"discard_reason" : @{@"@type" : @"callDiscardReasonHungUp"},
			@"is_video" : @NO}, nil)), @"Incoming call");
}

- (void)testCall_Outgoing {
	XCTAssertEqualObjects(TGKnownMessagePreview(pvMessage(@{
			@"@type" : @"messageCall",
			@"discard_reason" : @{@"@type" : @"callDiscardReasonHungUp"},
			@"is_video" : @NO}, @{@"is_outgoing" : @YES})), @"Outgoing call");
}

- (void)testCall_IncomingVideo {
	XCTAssertEqualObjects(TGKnownMessagePreview(pvMessage(@{
			@"@type" : @"messageCall",
			@"discard_reason" : @{@"@type" : @"callDiscardReasonHungUp"},
			@"is_video" : @YES}, nil)), @"Incoming video call");
}

- (void)testCall_OutgoingVideo {
	XCTAssertEqualObjects(TGKnownMessagePreview(pvMessage(@{
			@"@type" : @"messageCall",
			@"discard_reason" : @{@"@type" : @"callDiscardReasonHungUp"},
			@"is_video" : @YES}, @{@"is_outgoing" : @YES})),
						  @"Outgoing video call");
}

- (void)testCall_MissedVideo {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageCall",
								   @"discard_reason" : @{@"@type" : @"callDiscardReasonMissed"},
								   @"is_video" : @YES}), @"Missed video call");
}

#pragma mark - captions beat the label

- (void)testPhoto_CaptionWins {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messagePhoto",
								   @"caption" : pvFormatted(@"at the sea")}),
						  @"at the sea");
}

- (void)testDocument_CaptionWins {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageDocument",
								   @"caption" : pvFormatted(@"the slides"),
								   @"document" : @{@"file_name" : @"deck.pdf"}}),
						  @"the slides");
}

- (void)testVideo_CaptionWins {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageVideo",
								   @"caption" : pvFormatted(@"first steps")}),
						  @"first steps");
}

- (void)testVoiceNote_CaptionWins {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageVoiceNote",
								   @"caption" : pvFormatted(@"listen")}), @"listen");
}

- (void)testAnimation_CaptionWins {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageAnimation",
								   @"caption" : pvFormatted(@"funny")}), @"funny");
}

- (void)testAudio_CaptionWins {
	XCTAssertEqualObjects(pvPreview(@{@"@type" : @"messageAudio",
								   @"caption" : pvFormatted(@"our song"),
								   @"audio" : @{@"performer" : @"Queen",
												@"title" : @"Bohemian Rhapsody"}}),
						  @"our song");
}

#pragma mark - edges

- (void)testUnknownContent_IsNil {
	// A type no TDLib release has: nil, so the caller falls back to its name.
	XCTAssertTrue(TGKnownMessagePreview(@{@"content" : @{@"@type" : @"messageMeteorShowerStarted"}}) == nil);
}

- (void)testMessageIdAsString_DoesNotChangePreview {
	XCTAssertEqualObjects(TGKnownMessagePreview(@{
			@"@type" : @"message",
			@"id" : @"5368324170671202286",
			@"content" : @{@"@type" : @"messagePhoto"}}), @"Photo");
}

- (void)testMessageIdAsNumber_DoesNotChangePreview {
	XCTAssertEqualObjects(TGKnownMessagePreview(@{
			@"@type" : @"message",
			@"id" : @(5368324170671202286LL),
			@"content" : @{@"@type" : @"messageVideo"}}), @"Video");
}

@end
