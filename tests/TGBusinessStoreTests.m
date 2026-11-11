// TGBusinessStoreTests.m - the business requests the profile pages make.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGBusinessStore.h"

@interface TGBusinessStoreTests : XCTestCase
@end

static TGClient *TGBClient(void) {
	TGClient *c = TGClient.shared;
	[c.outbox removeAllObjects];
	[c.pendingRequests removeAllObjects];
	return c;
}

static NSDictionary *TGBDecode(NSData *data) {
	NSString *json = [[NSString alloc] initWithData:data
										   encoding:NSUTF8StringEncoding];
	NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
	return [NSJSONSerialization JSONObjectWithData:
			[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

static NSDictionary *TGBRequest(TGClient *c, NSString *type) {
	NSDictionary *found = nil;
	for (NSData *data in c.outbox){
		NSDictionary *request = TGBDecode(data);
		if ([request[@"@type"] isEqualToString:type])
			found = request;
	}
	return found;
}

@implementation TGBusinessStoreTests

- (void)testAccountNameCarriesBothNamesAndTheConnection {
	TGClient *c = TGBClient();
	[[TGBusinessStore shared] setBusinessAccountName:@"Ada" last:@"Lovelace"
									   connectionId:@"conn" completion:nil];
	NSDictionary *request = TGBRequest(c, @"setBusinessAccountName");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"first_name"], @"Ada");
	XCTAssertEqualObjects(request[@"last_name"], @"Lovelace");
	XCTAssertEqualObjects(request[@"business_connection_id"], @"conn");
}

- (void)testChatLinkCreationUsesInputBusinessChatLink {
	TGClient *c = TGBClient();
	[[TGBusinessStore shared] createBusinessChatLinkWithText:@"hello"
													   title:@"Door" completion:nil];
	NSDictionary *request = TGBRequest(c, @"createBusinessChatLink");
	XCTAssertEqualObjects(request[@"link_info"][@"@type"], @"inputBusinessChatLink");
	XCTAssertEqualObjects(request[@"link_info"][@"title"], @"Door");
	XCTAssertEqualObjects(request[@"link_info"][@"text"][@"text"], @"hello");
}

- (void)testLocationIsNullWhenNoCoordinatesAreGiven {
	TGClient *c = TGBClient();
	[[TGBusinessStore shared] setBusinessLocationLatitude:nil longitude:nil
												  address:nil completion:nil];
	NSDictionary *request = TGBRequest(c, @"setBusinessLocation");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"location"], [NSNull null]);
}

@end
