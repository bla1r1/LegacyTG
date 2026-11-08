#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGContactSort.h"
#import "TGGroupLogic.h"
#import "TGProfileLogic.h"

/// The last request of one type in the outbox, parsed as the client sends it.
/// A completion-driven call must still be answerable through handleUpdate,
/// which is the path a real TDLib reply takes.
static NSDictionary *peopleTestRequest(TGClient *c, NSString *type) {
	NSDictionary *found = nil;
	for (NSData *d in c.outbox){
		NSString *json = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
		NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
		NSDictionary *request = [NSJSONSerialization JSONObjectWithData:
				[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
		if ([request[@"@type"] isEqualToString:type])
			found = request;
	}
	return found;
}

static void peopleTestReply(TGClient *c, NSDictionary *request, NSDictionary *answer) {
	NSMutableDictionary *reply = [answer mutableCopy];
	reply[@"@extra"] = request[@"@extra"];
	[c handleUpdate:reply];
}

@interface TGParityPeopleTests : XCTestCase @end

@implementation TGParityPeopleTests

- (void)testPresence_OfflineTimestampNeverOutranksCoarseBuckets {
	NSDictionary *offline = @{@"@type" : @"userStatusOffline",
							  @"was_online" : @1000};
	XCTAssertEqual(TGContactPresenceRank(offline), 5);
	XCTAssertGreaterThan(TGContactPresenceRank(offline),
			TGContactPresenceRank(@{@"@type" : @"userStatusRecently"}));
	XCTAssertGreaterThan(TGContactPresenceRank(offline),
			TGContactPresenceRank(@{@"@type" : @"userStatusLastWeek"}));
	XCTAssertGreaterThan(TGContactPresenceRank(offline),
			TGContactPresenceRank(@{@"@type" : @"userStatusLastMonth"}));
}

- (void)testPresence_OnlineThenBucketsThenUnknown {
	XCTAssertEqual(TGContactPresenceRank(@{@"@type" : @"userStatusOnline"}), 0);
	XCTAssertEqual(TGContactPresenceRank(@{@"@type" : @"userStatusRecently"}), 2);
	XCTAssertEqual(TGContactPresenceRank(@{@"@type" : @"userStatusLastWeek"}), 3);
	XCTAssertEqual(TGContactPresenceRank(@{@"@type" : @"userStatusLastMonth"}), 4);
	XCTAssertEqual(TGContactPresenceRank(nil), 6);
}

/// The list sorts through TGContactsSortedByLastSeen; the array below is in
/// the order the old comparator produced (offline timestamp first).
- (void)testLastSeenSort_PutsOfflineAfterEveryCoarseBucket {
	NSArray *users = @[
		@{@"id" : @1, @"first_name" : @"Old",
		  @"status" : @{@"@type" : @"userStatusOffline", @"was_online" : @1000}},
		@{@"id" : @2, @"first_name" : @"Recent",
		  @"status" : @{@"@type" : @"userStatusRecently"}},
		@{@"id" : @3, @"first_name" : @"Week",
		  @"status" : @{@"@type" : @"userStatusLastWeek"}},
		@{@"id" : @4, @"first_name" : @"Month",
		  @"status" : @{@"@type" : @"userStatusLastMonth"}},
		@{@"id" : @5, @"first_name" : @"Online",
		  @"status" : @{@"@type" : @"userStatusOnline"}},
	];
	NSArray *sorted = TGContactsSortedByLastSeen(users);
	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *user in sorted)
		[ids addObject:user[@"id"]];
	XCTAssertEqualObjects(ids, (@[@5, @2, @3, @4, @1]));
}

- (void)testLastSeenSort_NewerOfflineTimestampWins {
	NSArray *users = @[
		@{@"id" : @1, @"first_name" : @"Older",
		  @"status" : @{@"@type" : @"userStatusOffline", @"was_online" : @1000}},
		@{@"id" : @2, @"first_name" : @"Newer",
		  @"status" : @{@"@type" : @"userStatusOffline", @"was_online" : @2000}},
	];
	NSArray *sorted = TGContactsSortedByLastSeen(users);
	XCTAssertEqualObjects([sorted valueForKey:@"id"], (@[@2, @1]));
}

- (void)testNameSort_UsesTheDisplayName {
	NSArray *users = @[
		@{@"id" : @1, @"first_name" : @"Zoe"},
		@{@"id" : @2, @"first_name" : @"Ann"},
	];
	NSArray *sorted = TGContactsSortedByName(users);
	XCTAssertEqualObjects([sorted valueForKey:@"id"], (@[@2, @1]));
}

- (void)testClearHistory_TodayIsLocalMidnightToNow {
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *parts = [[NSDateComponents alloc] init];
	parts.year = 2026;
	parts.month = 11;
	parts.day = 8;
	parts.hour = 15;
	parts.minute = 30;
	NSDate *now = [calendar dateFromComponents:parts];
	NSDateComponents *day = [[NSDateComponents alloc] init];
	day.year = 2026;
	day.month = 11;
	day.day = 8;
	NSInteger midnight = (NSInteger)[[calendar dateFromComponents:day]
			timeIntervalSince1970];
	NSInteger minDate = -1, maxDate = -1;
	TGClearHistoryWindowForChoice(2, now, &minDate, &maxDate);
	XCTAssertEqual(minDate, midnight);
	XCTAssertEqual(maxDate, (NSInteger)[now timeIntervalSince1970]);
}

- (void)testClearHistory_WeekAndMonthUseRollingDays {
	NSDate *now = [NSDate dateWithTimeIntervalSince1970:2000000000];
	NSInteger minDate = -1, maxDate = -1;
	TGClearHistoryWindowForChoice(0, now, &minDate, &maxDate);
	XCTAssertEqual(minDate, 0);
	XCTAssertEqual(maxDate, 2000000000 - 7 * 86400);
	TGClearHistoryWindowForChoice(1, now, &minDate, &maxDate);
	XCTAssertEqual(minDate, 0);
	XCTAssertEqual(maxDate, 2000000000 - 30 * 86400);
}

- (void)testInviteLink_RevokedPrimaryIsSkipped {
	NSArray *links = @[
		@{@"link" : @"https://t.me/revoked", @"primary" : @YES, @"revoked" : @YES},
		@{@"link" : @"https://t.me/alive", @"primary" : @NO, @"revoked" : @NO},
	];
	XCTAssertEqualObjects(TGInviteLinkPreferred(links)[@"link"],
			@"https://t.me/alive");
}

- (void)testInviteLink_AllRevokedHasNoMainLink {
	NSArray *links = @[
		@{@"link" : @"https://t.me/one", @"primary" : @YES, @"revoked" : @YES},
		@{@"link" : @"https://t.me/two", @"primary" : @NO, @"revoked" : @YES},
	];
	XCTAssertNil(TGInviteLinkPreferred(links));
}

- (void)testBlockUser_CompletionFollowsTheServerAnswer {
	TGClient *c = TGClient.shared;
	[c.outbox removeAllObjects];
	__block NSInteger calls = 0;
	__block BOOL answer = NO;
	[c setUser:42 blocked:YES completion:^(BOOL ok){
		calls++;
		answer = ok;
	}];
	XCTAssertEqual(calls, 0, "the completion waits for TDLib, not the tap");
	NSDictionary *request = peopleTestRequest(c, @"setMessageSenderBlockList");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"sender_id"][@"@type"], @"messageSenderUser");
	XCTAssertEqualObjects(request[@"sender_id"][@"user_id"], @42);
	XCTAssertEqualObjects(request[@"block_list"][@"@type"], @"blockListMain");
	XCTAssertTrue([request[@"@extra"] hasPrefix:@"r"]);

	peopleTestReply(c, request, @{@"@type" : @"ok"});
	XCTAssertEqual(calls, 1);
	XCTAssertTrue(answer);
}

- (void)testBlockUser_FailedAnswerDoesNotReportSuccess {
	TGClient *c = TGClient.shared;
	[c.outbox removeAllObjects];
	__block NSInteger calls = 0;
	__block BOOL answer = YES;
	[c setUser:-500 blocked:NO completion:^(BOOL ok){
		calls++;
		answer = ok;
	}];
	NSDictionary *request = peopleTestRequest(c, @"setMessageSenderBlockList");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"sender_id"][@"@type"], @"messageSenderChat");
	XCTAssertEqualObjects(request[@"sender_id"][@"chat_id"], @-500);
	XCTAssertEqualObjects(request[@"block_list"], [NSNull null]);

	peopleTestReply(c, request, @{@"@type" : @"error", @"message" : @"block failed"});
	XCTAssertEqual(calls, 1);
	XCTAssertFalse(answer);
}

#pragma mark - members

- (void)testMemberRowName_TrimsAndFallsBackToTheCaller {
	XCTAssertEqualObjects(TGMemberRowName(@{@"name" : @"  Ann "}), @"Ann");
	XCTAssertNil(TGMemberRowName(@{@"name" : @"   "}));
	XCTAssertNil(TGMemberRowName(@{}));
}

#pragma mark - group info card

- (void)testProfileShortLink_NormalisesToTheTMeAddress {
	XCTAssertEqualObjects(TGProfileShortLinkText(@"t.me/durov"),
			@"https://t.me/durov");
	XCTAssertEqualObjects(TGProfileShortLinkText(@"https://telegram.me/joinchat/abc"),
			@"https://t.me/joinchat/abc");
	XCTAssertEqualObjects(TGProfileShortLinkText(@"https://t.me/+abc"),
			@"https://t.me/+abc");
	XCTAssertEqualObjects(TGProfileShortLinkText(@"durov"),
			@"https://t.me/durov");
	// A non-Telegram address is not an invite link and must not be rewritten.
	XCTAssertEqualObjects(TGProfileShortLinkText(@"https://example.com/x"),
			@"https://example.com/x");
	XCTAssertNil(TGProfileShortLinkText(@"   "));
}

- (void)testProfileGroupInfoRows_OfficialOrderAndShortLink {
	NSArray *rows = TGProfileGroupInfoRows(@{
		@"communityId"    : @5,
		@"communityName"  : @"Crew",
		@"communitySubtitle" : @"Community with 2 chats",
		@"inviteLink"     : @"t.me/+abc",
		@"description"    : @"About the group",
		@"canManage"      : @YES,
		@"isChannel"      : @NO,
		@"linkedChatTitle": @"Discussion",
	});
	XCTAssertEqualObjects([rows valueForKey:@"kind"],
			(@[@"community", @"invite", @"about", @"settings", @"linkedChat"]));
	XCTAssertEqualObjects(rows[1][@"value"], @"https://t.me/+abc");
	XCTAssertEqualObjects(rows[3][@"label"], @"Group Settings");
}

- (void)testProfileGroupInfoRows_PublicUsernameIsTheLink {
	NSArray *rows = TGProfileGroupInfoRows(@{
		@"inviteLink" : @"https://t.me/+abc",
		@"username"   : @"@durov",
		@"isChannel"  : @YES,
	});
	XCTAssertEqualObjects(rows[0][@"kind"], @"invite");
	XCTAssertEqualObjects(rows[0][@"value"], @"https://t.me/durov");
	XCTAssertEqualObjects(rows[0][@"label"], @"Link");
}

- (void)testProfileGroupInfoRows_EmptyCardHasNoLinkRow {
	NSArray *rows = TGProfileGroupInfoRows(@{@"isChannel" : @YES});
	XCTAssertEqual(rows.count, (NSUInteger)0);
}

#pragma mark - media search

- (void)testMediaSearch_FiltersTheLoadedRowsAndCancelRestores {
	NSArray *rows = @[
		@{@"docName" : @"Report.pdf"},
		@{@"audioTitle" : @"Night", @"audioPerformer" : @"Daft Punk"},
		@{@"text" : @"https://example.com/story"},
	];
	XCTAssertEqualObjects(TGProfileMediaRowsMatchingQuery(rows, @"", @"files"), rows);
	XCTAssertEqual(TGProfileMediaRowsMatchingQuery(rows, @"report", @"files").count,
			(NSUInteger)1);
	XCTAssertEqual(TGProfileMediaRowsMatchingQuery(rows, @"DAFT", @"music").count,
			(NSUInteger)1);
	XCTAssertEqual(TGProfileMediaRowsMatchingQuery(rows, @"story", @"links").count,
			(NSUInteger)1);
	XCTAssertEqual(TGProfileMediaRowsMatchingQuery(rows, @"no-such-thing", @"files").count,
			(NSUInteger)0);
	// Photos are a grid without a bar search; a stale query must not hide it.
	XCTAssertEqual(TGProfileMediaRowsMatchingQuery(rows, @"report", @"media").count,
			(NSUInteger)3);
}

@end
