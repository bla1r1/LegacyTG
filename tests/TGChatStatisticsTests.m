// TGChatStatisticsTests.m - getChatStatistics as official's statistics
// screen lists it (StatisticsUI GroupStatsController, ChannelStatsController,
// StatsOverviewItem).
#import "TGTestRunner.h"
#import "TGChatStatistics.h"

@interface TGChatStatisticsTests : XCTestCase @end

static NSDictionary *csValue(double now, double previous) {
	return @{ @"@type" : @"statisticalValue", @"value" : @(now), @"previous_value" : @(previous),
			  @"growth_rate_percentage" : @0 };
}

static NSDictionary *csRow(NSArray *rows, NSString *section, NSUInteger index) {
	NSUInteger seen = 0;
	for (NSDictionary *row in rows)
		if ([row[@"section"] isEqualToString:section] && seen++ == index)
			return row;
	return nil;
}

@implementation TGChatStatisticsTests

- (void)testValue_ChangeAgainstPreviousPeriod {
	XCTAssertEqualObjects(TGStatValueText(csValue(1050, 1000)), @"1050 +50 (5.00%)");
	XCTAssertEqualObjects(TGStatValueText(csValue(900, 1000)), @"900 -100 (10.00%)");
	XCTAssertEqualObjects(TGStatValueText(csValue(10, 0)), @"10");
	XCTAssertEqualObjects(TGStatValueText(nil), @"-");
}

- (void)testGroup_TopMembersAdminsInviters {
	NSArray *rows = TGChatStatisticsRows(@{ @"@type" : @"chatStatisticsSupergroup",
		@"top_senders" : @[ @{ @"user_id" : @1, @"sent_message_count" : @12, @"average_character_count" : @40 } ],
		@"top_administrators" : @[ @{ @"user_id" : @2, @"deleted_message_count" : @3,
				@"banned_user_count" : @1, @"restricted_user_count" : @0 } ],
		@"top_inviters" : @[ @{ @"user_id" : @3, @"added_member_count" : @7 } ],
	}, ^NSString *(int64_t userId){ return userId == 1 ? @"Ann" : (userId == 2 ? @"Bob" : nil); }, nil);
	XCTAssertEqualObjects(csRow(rows, @"TOP MEMBERS", 0)[@"title"], @"Ann");
	XCTAssertEqualObjects(csRow(rows, @"TOP MEMBERS", 0)[@"detail"], @"12 messages, 40 symbols per message");
	XCTAssertEqualObjects(csRow(rows, @"TOP ADMINS", 0)[@"detail"], @"3 deletions, 1 kick");
	XCTAssertEqualObjects(csRow(rows, @"TOP INVITERS", 0)[@"title"], @"Deleted Account");
	XCTAssertEqualObjects(csRow(rows, @"TOP INVITERS", 0)[@"detail"], @"7 invitations");
}

- (void)testChannel_StoryMeansAndRecentPosts {
	NSDictionary *result = @{ @"@type" : @"chatStatisticsChannel",
		@"mean_story_view_count" : csValue(30, 20),
		@"recent_interactions" : @[
			@{ @"object_type" : @{ @"@type" : @"chatStatisticsObjectTypeMessage", @"message_id" : @(77) },
			   @"view_count" : @(1200), @"forward_count" : @(3), @"reaction_count" : @(0) },
			@{ @"object_type" : @{ @"@type" : @"chatStatisticsObjectTypeStory", @"story_id" : @(5) },
			   @"view_count" : @(0), @"forward_count" : @(0), @"reaction_count" : @(0) } ] };
	NSArray *rows = TGChatStatisticsRows(result, nil, ^NSString *(int64_t messageId){
		return messageId == 77 ? @"Launch day" : nil;
	});
	BOOL storyMean = NO;
	for (NSDictionary *row in rows)
		if ([row[@"title"] isEqualToString:@"Views Per Story"])
			storyMean = [row[@"detail"] isEqualToString:@"30 +10 (50.00%)"];
	XCTAssertTrue(storyMean);
	XCTAssertEqualObjects(csRow(rows, @"RECENT POSTS", 0)[@"title"], @"Launch day");
	XCTAssertEqualObjects(csRow(rows, @"RECENT POSTS", 0)[@"detail"], @"1200 views, 3 forwards");
	XCTAssertEqualObjects(csRow(rows, @"RECENT POSTS", 1)[@"title"], @"Story");
	XCTAssertEqualObjects(csRow(rows, @"RECENT POSTS", 1)[@"detail"], @"No views");
	XCTAssertEqualObjects(TGChatStatisticsPostIds(result), (@[@77]));
}

@end
