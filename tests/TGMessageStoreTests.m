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

@end
