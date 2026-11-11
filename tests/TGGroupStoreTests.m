// TGGroupStoreTests.m - the group store owns the requests the screens used
// to build themselves. These check the shapes on the wire, not the screens.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGGroupStore.h"

@interface TGGroupStoreTests : XCTestCase
@end

static TGClient *TGGClient(void) {
	TGClient *c = TGClient.shared;
	[c.outbox removeAllObjects];
	[c.pendingRequests removeAllObjects];
	return c;
}

static NSDictionary *TGGDecode(NSData *data) {
	NSString *json = [[NSString alloc] initWithData:data
										   encoding:NSUTF8StringEncoding];
	NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
	return [NSJSONSerialization JSONObjectWithData:
			[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

static NSDictionary *TGGRequest(TGClient *c, NSString *type) {
	NSDictionary *found = nil;
	for (NSData *data in c.outbox){
		NSDictionary *request = TGGDecode(data);
		if ([request[@"@type"] isEqualToString:type])
			found = request;
	}
	return found;
}

@implementation TGGroupStoreTests

- (void)testCreateInviteLinkCarriesTheLimitAndName {
	TGClient *c = TGGClient();
	[[TGGroupStore shared] createInviteLinkForChat:77 name:@"door"
									   memberLimit:100 completion:nil];
	NSDictionary *request = TGGRequest(c, @"createChatInviteLink");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 77LL);
	XCTAssertEqualObjects(request[@"name"], @"door");
	XCTAssertEqual([request[@"member_limit"] integerValue], 100LL);
}

- (void)testSetMemberBuildsAStatusObject {
	TGClient *c = TGGClient();
	[[TGGroupStore shared] setMember:12 inChat:77 status:@"administrator"
						  completion:nil];
	NSDictionary *request = TGGRequest(c, @"setChatMemberStatus");
	XCTAssertEqualObjects(request[@"status"][@"@type"],
						  @"chatMemberStatusAdministrator");
	XCTAssertEqualObjects(request[@"member_id"][@"@type"],
						  @"messageSenderUser");
	XCTAssertEqual([request[@"member_id"][@"user_id"] longLongValue], 12LL);
}

- (void)testBanUsesBanChatMemberAndRevoke {
	TGClient *c = TGGClient();
	[[TGGroupStore shared] banMember:12 inChat:77 revokeMessages:YES
						  completion:nil];
	NSDictionary *request = TGGRequest(c, @"banChatMember");
	XCTAssertNotNil(request);
	XCTAssertTrue([request[@"revoke_messages"] boolValue]);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 77LL);
}

- (void)testForumTopicsAskForTheFirstHundred {
	TGClient *c = TGGClient();
	[[TGGroupStore shared] forumTopicsForChat:77 completion:nil];
	NSDictionary *request = TGGRequest(c, @"getForumTopics");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 77LL);
	XCTAssertEqual([request[@"limit"] integerValue], 100LL);
	XCTAssertEqualObjects(request[@"query"], @"");
}

- (void)testSetChatTitleUsesSetChatTitle {
	TGClient *c = TGGClient();
	[[TGGroupStore shared] setChat:77 title:@"Renamed" completion:nil];
	NSDictionary *request = TGGRequest(c, @"setChatTitle");
	XCTAssertEqualObjects(request[@"title"], @"Renamed");
	XCTAssertEqual([request[@"chat_id"] longLongValue], 77LL);
}

@end
