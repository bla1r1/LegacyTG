// TGPinnedLineTests.m - the pin service line quotes what was pinned.
//
// Core writes "Alice pinned a message" before the chat has loaded that
// message. These tests pin the display-time substitution: the first line of
// the text, cut at 20 characters, or the kind word when the message has no
// text, and every other service line left alone.
#import "TGTestRunner.h"
#import "TGPinnedLine.h"

@interface TGPinnedLineTests : XCTestCase @end

static NSDictionary *pwPinned(NSString *text, NSString *kind) {
	return @{
		@"text": text ?: @"",
		@"kind": kind ?: @"messageText",
	};
}

static NSDictionary *pwPinnedKind(NSString *kind) {
	return pwPinned(@"", kind);
}

@implementation TGPinnedLineTests

#pragma mark - text

- (void)testText_QuotesThePinnedMessage {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message",
			pwPinned(@"Hello world", @"messageText")),
			@"Alice pinned \"Hello world\"");
}

- (void)testLongText_CutsAtTwentyCharactersWithEllipsis {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message",
			pwPinned(@"123456789012345678901234567890", @"messageText")),
			@"Alice pinned \"12345678901234567890...\"");
}

- (void)testExactlyTwentyCharacters_IsNotCut {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message",
			pwPinned(@"12345678901234567890", @"messageText")),
			@"Alice pinned \"12345678901234567890\"");
}

- (void)testTwentyOneCharacters_IsCut {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message",
			pwPinned(@"123456789012345678901", @"messageText")),
			@"Alice pinned \"12345678901234567890...\"");
}

- (void)testWhitespaceText_IsTrimmedBeforeQuoting {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message",
			pwPinned(@"  Hello world  ", @"messageText")),
			@"Alice pinned \"Hello world\"");
}

#pragma mark - kind words

- (void)testEmptyText_PhotoSaysAPhoto {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message",
			pwPinnedKind(@"messagePhoto")), @"Alice pinned a photo");
}

- (void)testEmptyText_VideoSaysAVideo {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message",
			pwPinnedKind(@"messageVideo")), @"Alice pinned a video");
}

- (void)testEmptyText_VoiceNoteSaysAVoiceMessage {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message",
			pwPinnedKind(@"messageVoiceNote")), @"Alice pinned a voice message");
}

- (void)testEmptyText_StickerSaysASticker {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message",
			pwPinnedKind(@"messageSticker")), @"Alice pinned a sticker");
}

- (void)testEmptyText_AnimatedEmojiSaysASticker {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message",
			pwPinnedKind(@"messageAnimatedEmoji")), @"Alice pinned a sticker");
}

- (void)testEmptyText_PollSaysAPoll {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message",
			pwPinnedKind(@"messagePoll")), @"Alice pinned a poll");
}

- (void)testEmptyText_DocumentSaysAFile {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message",
			pwPinnedKind(@"messageDocument")), @"Alice pinned a file");
}

- (void)testEmptyText_NullTextFallsBackToTheKindWord {
	NSDictionary *pinned = @{@"text": [NSNull null], @"kind": @"messagePhoto"};
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message", pinned),
			@"Alice pinned a photo");
}

- (void)testEmptyText_UnknownKindLeavesTheLine {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message",
			pwPinnedKind(@"messageVideoNote")), @"Alice pinned a message");
}

#pragma mark - untouched lines

- (void)testMissingPinned_LeavesTheLine {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message", nil),
			@"Alice pinned a message");
}

- (void)testWrongClassPinned_LeavesTheLine {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice pinned a message", (NSDictionary *)[NSNull null]),
			@"Alice pinned a message");
}

- (void)testOtherServiceText_IsUnchanged {
	XCTAssertEqualObjects(TGPinnedLine(@"Alice joined the group",
			pwPinned(@"Hello", @"messageText")), @"Alice joined the group");
}

- (void)testNonStringServiceText_IsUnchanged {
	id notAText = [NSNull null];
	XCTAssertEqualObjects(TGPinnedLine(notAText, pwPinned(@"Hello", @"messageText")),
			notAText);
}

@end
