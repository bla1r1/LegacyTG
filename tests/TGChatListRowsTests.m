//
// TGChatListRowsTests.m - the shared chat row and story strip.
//
// The chat list no longer builds a cell: it builds a TGKindChatRow. These pin
// the keys the builder writes, the two variants the list shares the kind with,
// and the launch snapshot's custom emoji surviving the round trip into a row.
//
#import "TGTestRunner.h"
#import "TGRows.h"
#import "TGChatListRowGeometry.h"

@interface TGChatListRowsTests : XCTestCase
@end

@implementation TGChatListRowsTests

- (void)testChatRowBuilderCopiesOnlyTheRowKeys {
	NSArray *emoji = @[@{@"offset" : @0, @"length" : @2,
			@"customEmojiId" : @42}];
	NSDictionary *chat = @{
		@"id" : @(-1001),
		@"title" : @"Alice",
		@"previewText" : @"See you",
		@"lastAuthor" : @"You",
		@"previewCustomEmoji" : emoji,
		@"unread" : @3,
		@"unreadMentions" : @1,
		@"markedUnread" : @NO,
		@"isMuted" : @YES,
		@"isPinned" : @YES,
		@"isOnline" : @YES,
		@"isSaved" : @NO,
		@"lastOutgoing" : @YES,
		@"lastId" : @10,
		@"readOutbox" : @9,
		@"draft" : @"",
		@"action" : @"typing...",
		@"emojiStatusId" : @77,
		@"permissions" : @{@"can_send" : @YES},
	};

	NSMutableDictionary *row = TGChatRow(chat, @"12:30");
	XCTAssertEqualObjects(row[TGRowKind], TGKindChatRow);
	XCTAssertEqualObjects(row[TGRowTitle], @"Alice");
	XCTAssertEqualObjects(row[TGRowChatId], @(-1001));
	XCTAssertEqualObjects(row[TGRowChatPreview], @"See you");
	XCTAssertEqualObjects(row[TGRowChatAuthor], @"You");
	XCTAssertEqualObjects(row[TGRowChatDate], @"12:30");
	XCTAssertEqualObjects(row[TGRowChatCustomEmoji], emoji);
	XCTAssertEqualObjects(row[TGRowChatUnread], @3);
	XCTAssertEqualObjects(row[TGRowChatMentions], @1);
	XCTAssertFalse([row[TGRowChatMarkedUnread] boolValue]);
	XCTAssertTrue([row[TGRowChatMuted] boolValue]);
	XCTAssertTrue([row[TGRowChatPinned] boolValue]);
	XCTAssertTrue([row[TGRowChatOnline] boolValue]);
	XCTAssertFalse([row[TGRowChatSaved] boolValue]);
	XCTAssertTrue([row[TGRowChatOutgoing] boolValue]);
	XCTAssertFalse([row[TGRowChatRead] boolValue],
			@"lastId 10 is past readOutbox 9, so the tick is unread");
	XCTAssertEqualObjects(row[TGRowChatAction], @"typing...");
	XCTAssertNil(row[TGRowChatDraft], @"an empty draft is not a draft");
	XCTAssertEqualObjects(row[TGRowChatStatusEmojiId], @77);
	XCTAssertNil(row[@"permissions"],
			@"the row carries no TDLib record a cell does not draw");
}

- (void)testChatRowFallsBackToTheMessageTextAndLeavesOptionalKeysOut {
	NSDictionary *chat = @{@"id" : @1, @"title" : @"Bob", @"text" : @"hi"};
	NSMutableDictionary *row = TGChatRow(chat, @"");

	XCTAssertEqualObjects(row[TGRowChatPreview], @"hi");
	XCTAssertNil(row[TGRowChatAuthor]);
	XCTAssertNil(row[TGRowChatCustomEmoji]);
	XCTAssertNil(row[TGRowChatAction]);
	XCTAssertNil(row[TGRowChatDraft]);
	XCTAssertNil(row[TGRowChatStatusEmojiId]);
	XCTAssertEqualObjects(row[TGRowChatUnread], @0);
	XCTAssertEqualObjects(row[TGRowChatMentions], @0);
}

- (void)testArchiveRowIsAChatRowVariant {
	NSMutableDictionary *row = TGArchiveChatRow(@"Archived Chats", @"2 chats");

	XCTAssertEqualObjects(row[TGRowKind], TGKindChatRow);
	XCTAssertEqualObjects(row[TGRowTitle], @"Archived Chats");
	XCTAssertEqualObjects(row[TGRowChatPreview], @"2 chats");
	XCTAssertEqualObjects(row[TGRowChatAvatarGlyph], TGChatAvatarGlyphArchive);
	XCTAssertNil(row[TGRowChatAvatarImage]);
	XCTAssertEqualObjects(row[TGRowChatUnread], @0);
	XCTAssertEqualObjects(row[TGRowChatMentions], @0);
}

- (void)testSavedMessagesRowIsAChatRowVariant {
	NSMutableDictionary *row = TGSavedMessagesChatRow(@"Saved Messages",
			@"Your own notes and forwards");

	XCTAssertEqualObjects(row[TGRowKind], TGKindChatRow);
	XCTAssertEqualObjects(row[TGRowTitle], @"Saved Messages");
	XCTAssertEqualObjects(row[TGRowChatPreview],
			@"Your own notes and forwards");
	XCTAssertEqualObjects(row[TGRowChatAvatarGlyph], TGChatAvatarGlyphSaved);
	XCTAssertTrue([row[TGRowChatSaved] boolValue]);
}

- (void)testSnapshotCustomEmojiRoundTripsIntoTheRow {
	NSArray *kept = TGSnapshotCustomEmoji(@[
		@{@"offset" : @0, @"length" : @2,
		  @"customEmojiId" : @"5206607081334906820"},
		@[@2, @2, @5206607081334906820LL],
	]);
	NSData *plist = [NSPropertyListSerialization dataFromPropertyList:kept
			format:NSPropertyListXMLFormat_v1_0 errorDescription:NULL];
	XCTAssertNotNil(plist);
	NSArray *loaded = [NSPropertyListSerialization propertyListFromData:plist
			mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
	XCTAssertEqual(loaded.count, (NSUInteger)2);

	NSDictionary *chat = @{@"id" : @5, @"title" : @"Carol",
			@"previewText" : @"ok", @"previewCustomEmoji" : loaded};
	NSMutableDictionary *row = TGChatRow(chat, @"");

	XCTAssertEqualObjects(row[TGRowChatCustomEmoji], loaded);
	XCTAssertEqualObjects(row[TGRowChatCustomEmoji][0][@"customEmojiId"],
			@5206607081334906820LL);
	XCTAssertEqualObjects(row[TGRowChatCustomEmoji][1][@"offset"], @2);
}

- (void)testStoryStripRowCarriesItsItemsAndOwnTile {
	NSDictionary *own = @{@"title" : @"My Story", @"isOwn" : @YES};
	NSArray *stories = @[@{@"title" : @"Alice", @"chatId" : @10}];
	NSMutableDictionary *row = TGStoryStripRow(stories, own);

	XCTAssertEqualObjects(row[TGRowKind], TGKindStoryStrip);
	XCTAssertEqualObjects(row[TGRowStories], stories);
	XCTAssertEqualObjects(row[TGRowOwnStory], own);
	XCTAssertNil(row[TGRowStoryTap], @"the screen attaches its own blocks");
}

@end
