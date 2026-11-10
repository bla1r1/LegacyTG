// TGSearchStoreTests.m - the search screen's seam writes the lists it owns.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGSearchStore.h"
#import "TGChatListStore.h"

@interface TGSearchStoreTests : XCTestCase @end

static NSDictionary *TGSLastRequest(NSString *type) {
	NSDictionary *found = nil;
	for (NSData *data in [TGClient shared].outbox){
		NSString *json = [[NSString alloc] initWithData:data
											   encoding:NSUTF8StringEncoding];
		NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
		NSDictionary *request = [NSJSONSerialization JSONObjectWithData:
				[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
		if ([request[@"@type"] isEqualToString:type])
			found = request;
	}
	return found;
}

@implementation TGSearchStoreTests

- (void)setUp {
	[[TGClient shared].outbox removeAllObjects];
}

- (void)testForgetRecentlyFoundChatWritesTheRemoval {
	[[TGSearchStore shared] forgetRecentlyFoundChat:7];
	NSDictionary *request = TGSLastRequest(@"removeRecentlyFoundChat");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 7LL);
}

- (void)testRememberFoundChatWritesTheAddition {
	[[TGSearchStore shared] rememberFoundChat:9];
	NSDictionary *request = TGSLastRequest(@"addRecentlyFoundChat");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 9LL);
}

- (void)testRemoveSearchedForTagIgnoresAnEmptyTag {
	[[TGSearchStore shared] removeSearchedForTag:@""];
	XCTAssertNil(TGSLastRequest(@"removeSearchedForTag"));

	[[TGSearchStore shared] removeSearchedForTag:@"news"];
	NSDictionary *request = TGSLastRequest(@"removeSearchedForTag");
	XCTAssertEqualObjects(request[@"tag"], @"news");
}

- (void)testSearchStoreUsesTheChatListChats {
	XCTAssertEqualObjects([TGSearchStore shared].chats,
						  [TGChatListStore shared].chats);
}

- (void)testDefaultsKeyIsPerAccount {
	NSString *key = [[TGSearchStore shared] defaultsKeyForSearchBase:@"recent"];
	XCTAssertTrue([key hasPrefix:@"recent"]);
}

@end
