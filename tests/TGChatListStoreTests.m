// TGChatListStoreTests.m - the M24 row facts the chat list draws.
//
// The store keeps the compact count, the folder tag and the reaction/poll
// badge; the row model only maps them to UI keys.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGChatListStore.h"
#import "TGRows.h"

@interface TGChatListStoreTests : XCTestCase @end

@implementation TGChatListStoreTests

- (void)setUp {
	[TGClient shared].folders = @[];
}

- (void)tearDown {
	[TGClient shared].folders = @[];
}

- (void)testCompactCountStopsAt99 {
	TGChatListStore *store = [TGChatListStore shared];
	XCTAssertEqualObjects([store compactBadgeTextForCount:0], @"");
	XCTAssertEqualObjects([store compactBadgeTextForCount:1], @"1");
	XCTAssertEqualObjects([store compactBadgeTextForCount:99], @"99");
	XCTAssertEqualObjects([store compactBadgeTextForCount:100], @"99+");
	XCTAssertEqualObjects([store compactBadgeTextForCount:9999], @"99+");
}

- (void)testFolderTagMapsChatListsToNames {
	[TGClient shared].folders = @[
		@{@"id" : @(4), @"title" : @"Work"},
		@{@"id" : @(7), @"title" : @"Family"},
	];
	NSDictionary *chat = @{
		@"id" : @(10),
		@"chatLists" : @[
			@{@"@type" : @"chatListFolder", @"chat_folder_id" : @(4)},
			@{@"@type" : @"chatListFolder", @"chat_folder_id" : @(7)},
		],
	};
	XCTAssertEqualObjects([[TGChatListStore shared] folderTagForChat:chat],
			@"Work, Family");
}

- (void)testTrailingBadgeCombinesFolderReactionAndPoll {
	[TGClient shared].folders = @[@{@"id" : @(4), @"title" : @"Work"}];
	NSDictionary *chat = @{
		@"id" : @(10),
		@"chatLists" : @[@{@"@type" : @"chatListFolder", @"chat_folder_id" : @(4)}],
		@"previewReactionSummary" : @"\U0001F44D 3",
		@"previewPollVotes" : @(12),
	};
	XCTAssertEqualObjects([[TGChatListStore shared] trailingBadgeForChat:chat],
			@"Work · \U0001F44D 3 · Poll · 12");
}

- (void)testRowModelCarriesTheM24Facts {
	[TGClient shared].folders = @[@{@"id" : @(4), @"title" : @"Work"}];
	NSDictionary *chat = @{
		@"id" : @(10),
		@"title" : @"Ann",
		@"date" : @(1700000000),
		@"previewText" : @"photo",
		@"previewKind" : @"photo",
		@"previewFileId" : @(555),
		@"chatLists" : @[@{@"@type" : @"chatListFolder", @"chat_folder_id" : @(4)}],
		@"previewReactionSummary" : @"\U0001F44D 2",
	};
	NSDictionary *row = TGChatRow(chat, @"12:00");
	XCTAssertEqualObjects(row[TGRowChatPreviewKind], @"photo");
	XCTAssertEqualObjects(row[TGRowChatPreviewFileId], @(555));
	XCTAssertEqualObjects(row[TGRowChatPreviewBadge],
			@"Work · \U0001F44D 2");
}

- (void)testGroupTypingPreviewNamesTheSender {
	TGClient *c = [TGClient shared];
	c.usersById[@(5)] = @"Ann";
	c.chatsById[@(7)] = [@{@"id" : @(7), @"isGroup" : @YES} mutableCopy];
	[c handleUpdate:@{
		@"@type" : @"updateChatAction",
		@"chat_id" : @(7),
		@"sender_id" : @{@"user_id" : @(5)},
		@"action" : @{@"@type" : @"chatActionTyping"},
	}];
	XCTAssertEqualObjects(c.chatsById[@(7)][@"action"], @"Ann: typing...");
}

@end
