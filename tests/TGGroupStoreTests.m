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


// A basic group admin who is not the owner promotes only whom they invited.
- (void)testPromote_BasicGroupNeedsOwnInvite {
	XCTAssertTrue(TGGroupMemberCanBePromoted(-123, NO, NO, 5, 5));
	XCTAssertFalse(TGGroupMemberCanBePromoted(-123, NO, NO, 6, 5));
	XCTAssertTrue(TGGroupMemberCanBePromoted(-123, YES, NO, 6, 5));
	XCTAssertTrue(TGGroupMemberCanBePromoted(-1001234567890LL, NO, NO, 6, 5));
}

// Parity: topics come a hundred at a time; the next page starts at
// forumTopics.next_offset_* (official loads more as the list scrolls).
- (void)testForumTopicsNextOffset_FullPageWithOffsets {
	NSMutableArray *topics = [NSMutableArray array];
	for (int i = 0; i < 100; i++) [topics addObject:@{}];
	NSDictionary *next = TGForumTopicsNextOffset(@{ @"topics" : topics,
			@"next_offset_date" : @1700000000, @"next_offset_message_id" : @55,
			@"next_offset_forum_topic_id" : @7 }, 100);
	XCTAssertEqualObjects(next[@"offset_date"], @1700000000);
	XCTAssertEqualObjects(next[@"offset_message_id"], @55);
	XCTAssertEqualObjects(next[@"offset_forum_topic_id"], @7);
}

- (void)testForumTopicsNextOffset_ShortPageOrZeroOffsetsEnd {
	XCTAssertNil(TGForumTopicsNextOffset(@{ @"topics" : @[@{}],
			@"next_offset_date" : @1, @"next_offset_message_id" : @1,
			@"next_offset_forum_topic_id" : @1 }, 100));
	NSMutableArray *topics = [NSMutableArray array];
	for (int i = 0; i < 100; i++) [topics addObject:@{}];
	XCTAssertNil(TGForumTopicsNextOffset(@{ @"topics" : topics }, 100));
}

- (void)testForumTopicsRequestNamesTheTopicOffset {
	TGClient *c = TGGClient();
	[[TGGroupStore shared] forumTopicsForChat:78 completion:nil];
	NSDictionary *request = TGGRequest(c, @"getForumTopics");
	XCTAssertNotNil(request[@"offset_forum_topic_id"]);
	XCTAssertNil(request[@"offset_message_thread_id"]);
}

@end
