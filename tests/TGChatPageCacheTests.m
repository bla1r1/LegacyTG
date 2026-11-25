//
// TGChatPageCacheTests.m - the saved newest page of a chat.
//
#import "TGTestRunner.h"
#import "TGChatPageCache.h"

@interface TGChatPageCacheTests : XCTestCase @end

static NSArray *pageOf(int64_t from, int64_t to) {
	NSMutableArray *page = [NSMutableArray array];
	for (int64_t i = from; i <= to; i++)
		[page addObject:@{ @"id" : @(i), @"text" : @"x", @"reply" : [NSNull null],
				@"waveform" : [NSData dataWithBytes:"\x01\x02" length:2] }];
	return page;
}

static void waitForPage(int64_t chatId, int64_t accountId) {
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
	while (![TGChatPageCache pageForChat:chatId account:accountId] && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

@implementation TGChatPageCacheTests

- (void)tearDown {
	[[NSFileManager defaultManager] removeItemAtPath:[TGChatPageCache directoryForAccount:777] error:NULL];
	[super tearDown];
}

/// The newest thirty come back oldest first, as the chat shows them.
- (void)testSavedPage_KeepsTheNewestInOrder {
	[TGChatPageCache savePage:pageOf(1, 50) chat:5 account:777];
	waitForPage(5, 777);
	NSArray *page = [TGChatPageCache pageForChat:5 account:777];
	XCTAssertEqual(page.count, (NSUInteger)30);
	XCTAssertEqual([page.firstObject[@"id"] longLongValue], 21LL);
	XCTAssertEqual([page.lastObject[@"id"] longLongValue], 50LL);
	XCTAssertEqualObjects(page.lastObject[@"reply"], [NSNull null]);
	XCTAssertEqualObjects(page.lastObject[@"waveform"], [NSData dataWithBytes:"\x01\x02" length:2],
			@"a voice note's bytes kept their chat from a page");
	XCTAssertNil([TGChatPageCache pageForChat:6 account:777]);
}

/// A page is shown only while it still ends at the chat's newest message.
- (void)testCurrentPage_EndsAtTheNewestMessage {
	XCTAssertTrue(TGChatPageIsCurrent(pageOf(1, 5), 5));
	XCTAssertFalse(TGChatPageIsCurrent(pageOf(1, 5), 6), @"a message came since");
	XCTAssertFalse(TGChatPageIsCurrent(@[], 5));
	XCTAssertFalse(TGChatPageIsCurrent(pageOf(1, 5), 0));
}

/// A page that ends before the chat's newest message is still shown; the
/// newer ones come with TDLib's page under it. One ahead of it is not.
- (void)testUsablePage_EndsAtOrBeforeTheNewestMessage {
	XCTAssertTrue(TGChatPageIsUsable(pageOf(1, 5), 5));
	XCTAssertTrue(TGChatPageIsUsable(pageOf(1, 5), 9), @"messages came since");
	XCTAssertFalse(TGChatPageIsUsable(pageOf(1, 5), 4), @"the newest was deleted");
	XCTAssertFalse(TGChatPageIsUsable(@[], 5));
	XCTAssertEqual(TGChatPageNewestId(pageOf(3, 7)), 7LL);
}

/// The reader's own newest message is not unread, whatever its id: the line
/// the real page must place was lost behind it on the iPod.
- (void)testUnread_CountsOnlyIncomingMessagesPastTheMark {
	NSArray *page = @[ @{ @"id" : @10, @"outgoing" : @NO },
					   @{ @"id" : @20, @"outgoing" : @YES } ];
	XCTAssertFalse(TGChatPageHasUnread(page, 15), @"the mine one past the mark is read");
	XCTAssertTrue(TGChatPageHasUnread(page, 5));
	NSArray *service = @[ @{ @"id" : @30, @"service" : @YES } ];
	XCTAssertFalse(TGChatPageHasUnread(service, 5));
}

/// Only the most recently saved fifty chats keep a page.
- (void)testSavedPages_KeepTheLastFifty {
	for (int64_t chat = 1; chat <= 52; chat++) {
		[TGChatPageCache savePage:pageOf(1, 2) chat:chat account:777];
		waitForPage(chat, 777);
	}
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	XCTAssertNil([TGChatPageCache pageForChat:1 account:777]);
	XCTAssertNil([TGChatPageCache pageForChat:2 account:777]);
	XCTAssertNotNil([TGChatPageCache pageForChat:52 account:777]);
}

- (void)testSavedChats_RoundTripsChatList {
	NSArray *rows = @[ @{ @"id" : @100LL, @"title" : @"Pavel Durov" } ];
	[TGChatPageCache saveChats:rows account:777];
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
	while (![TGChatPageCache chatsForAccount:777] && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	NSArray *got = [TGChatPageCache chatsForAccount:777];
	XCTAssertEqual(got.count, (NSUInteger)1);
	XCTAssertEqualObjects(got.firstObject[@"title"], @"Pavel Durov");
}

@end
