// TGMessageStoreTests.m - the Chat message boundary forwards to the client.
//
// The store is the only type a Chat screen imports. Until a method grows its
// own state, it must answer exactly what TGClient answers, including the
// properties and callbacks the chat hands back.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGMessageStore.h"

@interface TGMessageStoreTests : XCTestCase @end

@implementation TGMessageStoreTests

- (void)setUp {
	[[TGClient shared].outbox removeAllObjects];
}

- (void)testReadPropertiesAreTheClientsOwn {
	[TGClient shared].me = @{@"id" : @(1001), @"first_name" : @"Ann"};
	XCTAssertEqual([TGMessageStore shared].savedMessagesChatId,
				   [TGClient shared].savedMessagesChatId);
	XCTAssertEqualObjects([TGMessageStore shared].me, [TGClient shared].me);
	XCTAssertEqualObjects([TGMessageStore shared].chats, [TGClient shared].chats);
}

- (void)testMessageActionsReachTheOutbox {
	[[TGMessageStore shared] reactTo:5 inChat:7 emoji:@"\U0001F44D"];

	NSDictionary *request = nil;
	for (NSData *data in [TGClient shared].outbox){
		NSString *json = [[NSString alloc] initWithData:data
											   encoding:NSUTF8StringEncoding];
		NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
		NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:
				[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
		if ([parsed[@"@type"] isEqualToString:@"addMessageReaction"])
			request = parsed;
	}
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"message_id"] longLongValue], 5LL);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 7LL);
}

- (void)testCallbacksAreTheClientSlots {
	__block int64_t seenChat = 0;
	[TGMessageStore shared].onMessage = ^(int64_t chatId, NSDictionary *message,
			int64_t deletedId){
		seenChat = chatId;
	};
	XCTAssertNotNil([TGClient shared].onMessage);
	[TGClient shared].onMessage(42, nil, 0);
	XCTAssertEqual(seenChat, 42LL);
	[TGMessageStore shared].onMessage = nil;
	XCTAssertNil([TGClient shared].onMessage);
}

/// Chats stack (chat > profile > Send Message). With one slot the inner chat
/// took the feed and cleared it on the way out; the outer one heard nothing
/// after that. Each screen has a listener of its own now.
- (void)testTwoChatListenersEachHearTheirOwnChat {
	TGMessageStore *store = [TGMessageStore shared];
	TGClient *c = [TGClient shared];
	__block NSInteger outer = 0, inner = 0, typing = 0;
	id outerToken = [store addListenerForChat:10
			onMessage:^(NSDictionary *message, int64_t deletedId){ outer++; }
			onChatAction:^(NSString *action){ typing++; }
			onSecretChat:nil];
	id innerToken = [store addListenerForChat:20
			onMessage:^(NSDictionary *message, int64_t deletedId){ inner++; }
			onChatAction:nil onSecretChat:nil];

	[c handleUpdate:@{@"@type" : @"updateMessageContent", @"chat_id" : @(10), @"message_id" : @(1)}];
	[c handleUpdate:@{@"@type" : @"updateMessageContent", @"chat_id" : @(20), @"message_id" : @(2)}];
	XCTAssertEqual(outer, (NSInteger)1);
	XCTAssertEqual(inner, (NSInteger)1);

	// The inner chat is popped. The outer one goes on hearing.
	[store removeChatListener:innerToken];
	[c handleUpdate:@{@"@type" : @"updateMessageContent", @"chat_id" : @(10), @"message_id" : @(1)}];
	[c handleUpdate:@{@"@type" : @"updateMessageContent", @"chat_id" : @(20), @"message_id" : @(2)}];
	XCTAssertEqual(outer, (NSInteger)2);
	XCTAssertEqual(inner, (NSInteger)1);

	[c handleUpdate:@{@"@type" : @"updateChatAction", @"chat_id" : @(10),
					  @"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @(7)},
					  @"action" : @{@"@type" : @"chatActionTyping"}}];
	XCTAssertEqual(typing, (NSInteger)1);

	[store removeChatListener:outerToken];
	[c handleUpdate:@{@"@type" : @"updateMessageContent", @"chat_id" : @(10), @"message_id" : @(1)}];
	XCTAssertEqual(outer, (NSInteger)2);
}

- (void)testClassSchedulingHelpersAnswerTheSameRecords {
	XCTAssertEqualObjects([TGMessageStore scheduledWhenOnline],
						  [TGClient scheduledWhenOnline]);
	XCTAssertEqualObjects([TGMessageStore scheduledAtDate:1700000000],
						  [TGClient scheduledAtDate:1700000000]);
	XCTAssertEqualObjects([TGMessageStore scheduledAtDate:1700000000 repeatPeriod:86400],
						  [TGClient scheduledAtDate:1700000000 repeatPeriod:86400]);
	XCTAssertEqual([[TGMessageStore scheduledAtDate:1700000000 repeatPeriod:86400][@"repeat_period"]
			integerValue], 86400LL);
}

- (void)testStoreAnswersTheDeclaredSelectorAtRuntime {
	XCTAssertTrue([[TGMessageStore shared]
			respondsToSelector:@selector(titleForChat:)]);
	XCTAssertTrue([[TGMessageStore shared]
			respondsToSelector:@selector(reactTo:inChat:emoji:)]);
}


- (void)testBotCommandRows_FlattenEveryBot {
	NSArray *rows = TGBotCommandRows(@[
		@{@"bot_user_id" : @7, @"commands" : @[@{@"command" : @"start", @"description" : @"Go"}]},
		@{@"bot_user_id" : @8, @"commands" : @[@{@"command" : @"help", @"description" : @"?"},
											   @{@"command" : @"", @"description" : @"dropped"}]}]);
	XCTAssertEqual(rows.count, (NSUInteger)2);
	XCTAssertEqualObjects(rows[1][@"command"], @"help");
	XCTAssertEqualObjects(rows[1][@"botId"], @8);
	XCTAssertEqual(TGBotCommandRows((id)[NSNull null]).count, (NSUInteger)0);
}

- (void)testPinnedMessagesBuildsSearchFilter {
	[[TGMessageStore shared] pinnedMessagesForChat:555 completion:nil];
	NSDictionary *request = nil;
	for (NSData *data in [TGClient shared].outbox){
		NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
		NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:
				[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
		if ([parsed[@"@type"] isEqualToString:@"searchChatMessages"])
			request = parsed;
	}
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"chat_id"], @(555));
	XCTAssertEqualObjects(request[@"filter"][@"@type"], @"searchMessagesFilterPinned");
}

- (void)testQueryInlineBotBuildsSearchPublicChatRequest {
	[[TGMessageStore shared] queryInlineBot:@"gif" query:@"cat" inChat:777 completion:nil];
	NSDictionary *request = nil;
	for (NSData *data in [TGClient shared].outbox){
		NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
		NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:
				[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
		if ([parsed[@"@type"] isEqualToString:@"searchPublicChat"])
			request = parsed;
	}
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"username"], @"gif");
}

@end
