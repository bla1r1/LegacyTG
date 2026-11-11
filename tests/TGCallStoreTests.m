// TGCallStoreTests.m - group-call requests from the call screens.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGCallStore.h"

@interface TGCallStoreTests : XCTestCase
@end

static TGClient *TGCCClient(void) {
	TGClient *c = TGClient.shared;
	[c.outbox removeAllObjects];
	[c.pendingRequests removeAllObjects];
	return c;
}

static NSDictionary *TGCCDecode(NSData *data) {
	NSString *json = [[NSString alloc] initWithData:data
										   encoding:NSUTF8StringEncoding];
	NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
	return [NSJSONSerialization JSONObjectWithData:
			[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

static NSDictionary *TGCCRequest(TGClient *c, NSString *type) {
	NSDictionary *found = nil;
	for (NSData *data in c.outbox){
		NSDictionary *request = TGCCDecode(data);
		if ([request[@"@type"] isEqualToString:type])
			found = request;
	}
	return found;
}

@implementation TGCallStoreTests

- (void)testLeaveCarriesTheGroupCallId {
	TGClient *c = TGCCClient();
	[[TGCallStore shared] leaveGroupCall:42 completion:nil];
	NSDictionary *request = TGCCRequest(c, @"leaveGroupCall");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"group_call_id"] integerValue], 42);
}

- (void)testEndCarriesTheGroupCallId {
	TGClient *c = TGCCClient();
	[[TGCallStore shared] endGroupCall:7 completion:nil];
	NSDictionary *request = TGCCRequest(c, @"endGroupCall");
	XCTAssertEqual([request[@"group_call_id"] integerValue], 7);
}

- (void)testJoinParametersAreAPureBuilder {
	NSDictionary *parameters = TGGroupCallJoinParameters(0, @"", NO, NO);
	XCTAssertEqualObjects(parameters[@"@type"], @"groupCallJoinParameters");
	XCTAssertEqualObjects(TGGroupCallInput(9, 10)[@"id"], @9);
}

@end
