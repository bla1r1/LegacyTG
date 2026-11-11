// TGStarsStoreTests.m - the request shapes the Premium, Stars and gift
// screens depend on.
//
// TDJSON is never loaded in this binary: every call lands in the client's
// outbox as JSON, so the test reads the same @type and fields the server
// would. The store owns the bodies, not a forwarder.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGStarsStore.h"

@interface TGStarsStoreTests : XCTestCase
@end

static TGClient *TGStarsTestClient(void) {
	TGClient *c = TGClient.shared;
	[c.outbox removeAllObjects];
	[c.pendingRequests removeAllObjects];
	return c;
}

static NSDictionary *TGStarsTestDecode(NSData *data) {
	NSString *json = [[NSString alloc] initWithData:data
										   encoding:NSUTF8StringEncoding];
	NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
	return [NSJSONSerialization JSONObjectWithData:
			[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

/// The last request of `type`, @extra included: request: adds it.
static NSDictionary *TGStarsTestRequest(TGClient *c, NSString *type) {
	NSDictionary *found = nil;
	for (NSData *data in c.outbox){
		NSDictionary *request = TGStarsTestDecode(data);
		if ([request[@"@type"] isEqualToString:type])
			found = request;
	}
	return found;
}

@implementation TGStarsStoreTests

- (void)setUp {
	[super setUp];
	TGStarsTestClient();
}

#pragma mark - affiliate programs

- (void)testAffiliateSearchRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] searchAffiliateProgramsForKind:@"channel"
												botUserId:0
												   chatId:42
												 sortOrder:@"revenue"
												   offset:@""
													limit:20
											   completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"searchAffiliatePrograms");
	XCTAssertNotNil(request);
	NSDictionary *affiliate = request[@"affiliate"];
	XCTAssertEqualObjects(affiliate[@"@type"], @"affiliateTypeChannel");
	XCTAssertEqual([affiliate[@"chat_id"] longLongValue], 42LL);
	XCTAssertEqualObjects(request[@"sort_order"][@"@type"],
						  @"affiliateProgramSortOrderRevenue");
	XCTAssertEqualObjects(request[@"offset"], @"");
	XCTAssertEqual([request[@"limit"] intValue], 20);
}

- (void)testAffiliateConnectRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] connectAffiliateProgramForKind:@"bot"
												botUserId:77
												   chatId:0
										  programBotUserId:88
											   completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"connectAffiliateProgram");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"affiliate"][@"@type"], @"affiliateTypeBot");
	XCTAssertEqual([request[@"affiliate"][@"user_id"] longLongValue], 77LL);
	XCTAssertEqual([request[@"bot_user_id"] longLongValue], 88LL);
}

- (void)testAffiliateChannelProgramRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] setChatAffiliateProgram:42
							   commissionPerMille:300
									   monthCount:12
									   completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"setChatAffiliateProgram");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 42LL);
	NSDictionary *parameters = request[@"parameters"];
	XCTAssertEqualObjects(parameters[@"@type"], @"affiliateProgramParameters");
	XCTAssertEqual([parameters[@"commission_per_mille"] intValue], 300);
	XCTAssertEqual([parameters[@"month_count"] intValue], 12);
}

#pragma mark - ads and speech

- (void)testSponsoredClickRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] clickSponsoredMessage:15
										  inChat:7
									   mediaClick:YES
									fromFullscreen:NO
										completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"clickChatSponsoredMessage");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 7LL);
	XCTAssertEqual([request[@"message_id"] longLongValue], 15LL);
	XCTAssertTrue([request[@"is_media_click"] boolValue]);
	XCTAssertFalse([request[@"from_fullscreen"] boolValue]);
}

- (void)testSponsoredReportRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] reportSponsoredMessage:15
										   inChat:7
										   option:@"reason"
									   completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"reportChatSponsoredMessage");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"option_id"], @"reason");
}

- (void)testVideoAdvertisementRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] videoAdvertisementsForChat:7
											  message:9
										   completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"getVideoMessageAdvertisements");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 7LL);
	XCTAssertEqual([request[@"message_id"] longLongValue], 9LL);
}

- (void)testSpeechRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] recognizeSpeechInChat:7 message:9 completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"recognizeSpeech");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 7LL);
	XCTAssertEqual([request[@"message_id"] longLongValue], 9LL);
}

#pragma mark - Premium, Stars and revenue

- (void)testPremiumStickersClampRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] premiumStickersWithLimit:500 completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"getPremiumStickers");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"limit"] intValue], 100);
}

- (void)testStarTransactionsRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] starTransactionsForOwner:@"chat"
											ownerId:42
										  direction:@"incoming"
											 offset:@"next"
											  limit:500
										 completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"getStarTransactions");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"owner_id"][@"@type"], @"messageSenderChat");
	XCTAssertEqual([request[@"owner_id"][@"chat_id"] longLongValue], 42LL);
	XCTAssertEqualObjects(request[@"direction"][@"@type"],
						  @"transactionDirectionIncoming");
	XCTAssertEqualObjects(request[@"offset"], @"next");
	XCTAssertEqual([request[@"limit"] intValue], 100);
}

- (void)testChatRevenueTransactionsRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] chatRevenueTransactionsForChat:7
												   offset:@""
													limit:20
											   completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"getChatRevenueTransactions");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 7LL);
	XCTAssertEqual([request[@"limit"] intValue], 20);
}

- (void)testStarRevenueStatisticsRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] starRevenueStatisticsForOwner:@"user"
												 ownerId:3
													dark:NO
											  completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"getStarRevenueStatistics");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"owner_id"][@"@type"],
						  @"messageSenderUser");
	XCTAssertEqual([request[@"owner_id"][@"user_id"] longLongValue], 3LL);
	XCTAssertFalse([request[@"is_dark"] boolValue]);
}

#pragma mark - gifts and auctions

- (void)testGiftCollectionRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] giftCollectionsForOwner:@"chat"
										   ownerId:9
										completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"getGiftCollections");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"owner_id"][@"@type"], @"messageSenderChat");
	XCTAssertEqual([request[@"owner_id"][@"chat_id"] longLongValue], 9LL);
}

- (void)testGiftResaleSearchRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] searchGiftsForResaleFromGift:5
												  order:@"price"
												 offset:@""
												  limit:20
											 completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"searchGiftsForResale");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"gift_id"] longLongValue], 5LL);
	XCTAssertEqualObjects(request[@"order"][@"@type"],
						  @"giftForResaleOrderPrice");
	XCTAssertTrue([request[@"for_stars"] boolValue]);
	XCTAssertFalse([request[@"for_crafting"] boolValue]);
}

- (void)testGiftAuctionStateRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] giftAuctionStateForAuction:@"auction-1"
										   completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"getGiftAuctionState");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"auction_id"], @"auction-1");
}

#pragma mark - boosts and paid messages

- (void)testBoostChatRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] boostChat:7 slotIds:@[@1, @2] completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"boostChat");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 7LL);
	XCTAssertEqualObjects(request[@"slot_ids"], (@[@1, @2]));
}

- (void)testChatBoostStatusRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] chatBoostStatusForChat:7 completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"getChatBoostStatus");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 7LL);
}

- (void)testPaidMessageStarCountRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] setChatPaidMessageStarCount:7 count:5 completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"setChatPaidMessageStarCount");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 7LL);
	XCTAssertEqual([request[@"paid_message_star_count"] intValue], 5);
}

- (void)testGiveawayInfoRequestShape {
	TGClient *c = TGStarsTestClient();
	[[TGStarsStore shared] giveawayInfoForChat:7 message:9 completion:nil];
	NSDictionary *request = TGStarsTestRequest(c, @"getGiveawayInfo");
	XCTAssertEqual([request[@"chat_id"] longLongValue], 7LL);
	XCTAssertEqual([request[@"message_id"] longLongValue], 9LL);
}

@end
