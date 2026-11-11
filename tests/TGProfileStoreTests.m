// TGProfileStoreTests.m - the profile screen's store seam.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGProfileStore.h"

@interface TGProfileStoreTests : XCTestCase @end

static NSDictionary *TPSLastRequest(NSString *type) {
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

@implementation TGProfileStoreTests

- (void)setUp {
	[[TGClient shared].outbox removeAllObjects];
	[[TGClient shared].pendingRequests removeAllObjects];
}

- (void)testMeIsTheClientsOwn {
	[TGClient shared].me = @{@"id" : @(1001), @"first_name" : @"Ann"};
	XCTAssertEqualObjects([TGProfileStore shared].me, [TGClient shared].me);
}

- (void)testSetBioWritesTheRequest {
	[[TGProfileStore shared] setBio:@"hello" completion:^(BOOL ok, NSString *error){}];
	NSDictionary *request = TPSLastRequest(@"setBio");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"bio"], @"hello");
}

- (void)testBlockingUserNamesTheSender {
	[[TGProfileStore shared] setUser:5 blocked:YES completion:^(BOOL ok){}];
	NSDictionary *request = TPSLastRequest(@"setMessageSenderBlockList");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"sender_id"][@"user_id"] longLongValue], 5LL);
	XCTAssertEqualObjects(request[@"block_list"][@"@type"], @"blockListMain");
}

- (void)testAccentIdsComeFromTheClient {
	[TGClient shared].accentColorIds = @[ @1, @2 ];
	XCTAssertEqualObjects([TGProfileStore shared].availableAccentColorIds,
						  (@[ @1, @2 ]));
}

@end
