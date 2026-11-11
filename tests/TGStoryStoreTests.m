// TGStoryStoreTests.m - story requests from the Stories screens.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGStoryStore.h"

@interface TGStoryStoreTests : XCTestCase
@end

static TGClient *TGSYClient(void) {
	TGClient *c = TGClient.shared;
	[c.outbox removeAllObjects];
	[c.pendingRequests removeAllObjects];
	return c;
}

static NSDictionary *TGSYDecode(NSData *data) {
	NSString *json = [[NSString alloc] initWithData:data
										   encoding:NSUTF8StringEncoding];
	NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
	return [NSJSONSerialization JSONObjectWithData:
			[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

static NSDictionary *TGSYRequest(TGClient *c, NSString *type) {
	NSDictionary *found = nil;
	for (NSData *data in c.outbox){
		NSDictionary *request = TGSYDecode(data);
		if ([request[@"@type"] isEqualToString:type])
			found = request;
	}
	return found;
}

@implementation TGStoryStoreTests

- (void)testAlbumsAskForTheChatAlbums {
	TGClient *c = TGSYClient();
	[[TGStoryStore shared] storyAlbumsForChat:5 completion:nil];
	NSDictionary *request = TGSYRequest(c, @"getChatStoryAlbums");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 5LL);
}

- (void)testStealthActivatesThroughItsOwnMethod {
	TGClient *c = TGSYClient();
	[[TGStoryStore shared] activateStoryStealthModeWithCompletion:nil];
	XCTAssertNotNil(TGSYRequest(c, @"activateStoryStealthMode"));
}

- (void)testCloseStoryNamesThePosterChat {
	TGClient *c = TGSYClient();
	[[TGStoryStore shared] closeStory:7 fromChat:9 completion:nil];
	NSDictionary *request = TGSYRequest(c, @"closeStory");
	XCTAssertEqual([request[@"story_id"] integerValue], 7);
	XCTAssertEqual([request[@"story_poster_chat_id"] longLongValue], 9LL);
}

@end
