// TGChannelStoreTests.m - the similar-channels screen's store seam.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGChannelStore.h"

@interface TGChannelStoreTests : XCTestCase @end

static NSDictionary *TCHDecode(NSData *data) {
	NSString *json = [[NSString alloc] initWithData:data
										   encoding:NSUTF8StringEncoding];
	NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
	return [NSJSONSerialization JSONObjectWithData:
			[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

static NSDictionary *TCHRequest(NSString *type) {
	NSDictionary *found = nil;
	for (NSData *data in [TGClient shared].outbox){
		NSDictionary *request = TCHDecode(data);
		if ([request[@"@type"] isEqualToString:type])
			found = request;
	}
	return found;
}

@implementation TGChannelStoreTests

- (void)setUp {
	[[TGClient shared].outbox removeAllObjects];
	[[TGClient shared].pendingRequests removeAllObjects];
}

- (void)testChatInfoAsksForTheChatRecord {
	[[TGChannelStore shared] chatInfoForId:77 completion:^(NSDictionary *chat){}];
	NSDictionary *request = TCHRequest(@"getChat");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 77LL);
}

- (void)testOpenSimilarChatNamesBothChats {
	[[TGChannelStore shared] openSimilarChat:12 fromChat:77];
	NSDictionary *request = TCHRequest(@"openChatSimilarChat");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 77LL);
	XCTAssertEqual([request[@"opened_chat_id"] longLongValue], 12LL);
}

@end
