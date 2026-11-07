//
// TGMessageCardTests.m - tests for message bubble card generation.
//
#import "TGTestRunner.h"
#import "TGMessageCard.h"

FOUNDATION_EXPORT NSString *TGMessageCardPrice(NSString *currency, int64_t amount);

static NSDictionary *mcRow(id rowId, NSString *key, id content) {
	NSMutableDictionary *d = [NSMutableDictionary dictionary];
	if (rowId)
		d[@"id"] = rowId;
	if (key && content)
		d[key] = content;
	return d;
}

static NSDictionary *mcUser(id userId, NSString *firstName, NSString *lastName, NSString *username, id photoFileId) {
	NSMutableDictionary *d = [NSMutableDictionary dictionary];
	if (userId)
		d[@"userId"] = userId;
	if (firstName)
		d[@"firstName"] = firstName;
	if (lastName)
		d[@"lastName"] = lastName;
	if (username)
		d[@"username"] = username;
	if (photoFileId)
		d[@"photoFileId"] = photoFileId;
	return d;
}

@interface TGMessageCardTests : XCTestCase @end

@implementation TGMessageCardTests

#pragma mark - TGMessageCardPrice

- (void)testPrice_XTR_SingleStar {
	NSString *price = TGMessageCardPrice(@"XTR", 1);
	XCTAssertEqualObjects(price, @"1 Star");
}

- (void)testPrice_XTR_PluralStars {
	NSString *price50 = TGMessageCardPrice(@"XTR", 50);
	XCTAssertEqualObjects(price50, @"50 Stars");
	NSString *price2 = TGMessageCardPrice(@"XTR", 2);
	XCTAssertEqualObjects(price2, @"2 Stars");
}

- (void)testPrice_XTR_ZeroStars {
	NSString *price0 = TGMessageCardPrice(@"XTR", 0);
	XCTAssertEqualObjects(price0, @"0 Stars");
}

- (void)testPrice_USD_ZeroAmount {
	NSString *price = TGMessageCardPrice(@"USD", 0);
	XCTAssertEqualObjects(price, @"$0.00");
}

- (void)testPrice_USD_OneCent {
	NSString *price = TGMessageCardPrice(@"USD", 1);
	XCTAssertEqualObjects(price, @"$0.01");
}

- (void)testPrice_USD_StandardAmount {
	NSString *price = TGMessageCardPrice(@"USD", 499);
	XCTAssertEqualObjects(price, @"$4.99");
	NSString *price100 = TGMessageCardPrice(@"USD", 100);
	XCTAssertEqualObjects(price100, @"$1.00");
}

- (void)testPrice_ZeroDecimal_JPY {
	NSString *price = TGMessageCardPrice(@"JPY", 500);
	XCTAssertEqualObjects(price, @"500 JPY");
	NSString *price0 = TGMessageCardPrice(@"JPY", 0);
	XCTAssertEqualObjects(price0, @"0 JPY");
}

- (void)testPrice_ZeroDecimal_KRW {
	NSString *price = TGMessageCardPrice(@"KRW", 1000);
	XCTAssertEqualObjects(price, @"1000 KRW");
}

- (void)testPrice_ZeroDecimal_AllOthers {
	NSArray *zeroCurrs = @[
		@"VND", @"CLP", @"ISK", @"UGX", @"PYG", @"XAF",
		@"XOF", @"KMF", @"GNF", @"RWF", @"DJF", @"BIF", @"VUV", @"XPF"
	];
	for (NSString *curr in zeroCurrs) {
		NSString *expected = [NSString stringWithFormat:@"750 %@", curr];
		NSString *res = TGMessageCardPrice(curr, 750);
		XCTAssertEqualObjects(res, expected);
	}
}

- (void)testPrice_TwoDecimals_EUR {
	NSString *price = TGMessageCardPrice(@"EUR", 499);
	XCTAssertEqualObjects(price, @"4.99 EUR");
	NSString *price0 = TGMessageCardPrice(@"EUR", 0);
	XCTAssertEqualObjects(price0, @"0.00 EUR");
	NSString *price1 = TGMessageCardPrice(@"EUR", 1);
	XCTAssertEqualObjects(price1, @"0.01 EUR");
}

- (void)testPrice_TwoDecimals_UAH {
	NSString *price = TGMessageCardPrice(@"UAH", 1250);
	XCTAssertEqualObjects(price, @"12.50 UAH");
}

- (void)testPrice_NilAndEmptyCurrency {
	NSString *priceNil = TGMessageCardPrice(nil, 499);
	XCTAssertEqualObjects(priceNil, @"4.99");
	NSString *priceEmpty = TGMessageCardPrice(@"", 1250);
	XCTAssertEqualObjects(priceEmpty, @"12.50");
}

#pragma mark - Non-card / Fallback inputs

- (void)testCard_NilRowReturnsNil {
	TGMessageCard *card = TGMessageCardForRow(nil);
	XCTAssertTrue(card == nil);
}

- (void)testCard_NonDictionaryReturnsNil {
	TGMessageCard *card = TGMessageCardForRow((NSDictionary *)@"just a string");
	XCTAssertTrue(card == nil);
	TGMessageCard *cardNull = TGMessageCardForRow((NSDictionary *)[NSNull null]);
	XCTAssertTrue(cardNull == nil);
}

- (void)testCard_EmptyDictionaryReturnsNil {
	TGMessageCard *card = TGMessageCardForRow(@{});
	XCTAssertTrue(card == nil);
}

- (void)testCard_PlainTextRowReturnsNil {
	TGMessageCard *card = TGMessageCardForRow(@{@"id": @123, @"text": @"hello world"});
	XCTAssertTrue(card == nil);
}

- (void)testCard_NSNullForNestedCardsReturnsNil {
	NSDictionary *row = @{
		@"id": @1,
		@"invoice": [NSNull null],
		@"giveaway": [NSNull null],
		@"giveawayWinners": [NSNull null],
		@"gift": [NSNull null],
		@"upgradedGift": [NSNull null],
		@"game": [NSNull null],
		@"sharedUsers": [NSNull null],
		@"sharedChat": [NSNull null],
		@"groupCall": [NSNull null],
		@"story": [NSNull null],
	};
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card == nil);
}

- (void)testCard_EmptyNestedDictsReturnNil {
	NSDictionary *row = @{
		@"id": @1,
		@"invoice": @{},
		@"giveaway": @{},
		@"giveawayWinners": @{},
		@"gift": @{},
		@"upgradedGift": @{},
		@"game": @{},
		@"sharedChat": @{},
		@"groupCall": @{},
		@"story": @{},
	};
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card == nil);
}

- (void)testCard_EmptySharedUsersArrayReturnsNil {
	NSDictionary *row = @{
		@"id": @1,
		@"sharedUsers": @[],
	};
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card == nil);
}

#pragma mark - Precedence

- (void)testPrecedence_InvoiceOverGame {
	NSDictionary *row = @{
		@"id": @42,
		@"invoice": @{@"title": @"Invoice Title"},
		@"game": @{@"title": @"Game Title"},
	};
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Invoice");
	XCTAssertEqualObjects(card.title, @"Invoice Title");
	XCTAssertEqual(card.action, TGMessageCardActionPay);
}

- (void)testPrecedence_InvoiceOverAll {
	NSDictionary *row = @{
		@"id": @100,
		@"invoice": @{@"title": @"Invoice"},
		@"giveaway": @{@"starCount": @10},
		@"game": @{@"title": @"Game"},
		@"story": @{@"storyId": @5},
	};
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Invoice");
}

- (void)testPrecedence_GiveawayOverGift {
	NSDictionary *row = @{
		@"id": @10,
		@"giveaway": @{@"starCount": @50},
		@"gift": @{@"giftId": @99},
	};
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Giveaway");
	XCTAssertEqual(card.action, TGMessageCardActionOpenGiveaway);
}

- (void)testPrecedence_GiveawayWinnersOverGift {
	NSDictionary *row = @{
		@"id": @11,
		@"giveawayWinners": @{@"giveawayMessageId": @88, @"winnerCount": @1},
		@"gift": @{@"giftId": @77},
	};
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Giveaway Results");
}

- (void)testPrecedence_GiftOverUpgradedGift {
	NSDictionary *row = @{
		@"id": @12,
		@"gift": @{@"giftId": @55},
		@"upgradedGift": @{@"title": @"Collectible"},
	};
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Gift");
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)55);
}

- (void)testPrecedence_UpgradedGiftOverGame {
	NSDictionary *row = @{
		@"id": @13,
		@"upgradedGift": @{@"title": @"Gem", @"number": @7},
		@"game": @{@"gameId": @33},
	};
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Collectible");
	XCTAssertEqualObjects(card.title, @"Gem #7");
}

- (void)testPrecedence_GameOverSharedUsers {
	NSDictionary *row = @{
		@"id": @14,
		@"game": @{@"gameId": @22, @"title": @"Chess"},
		@"sharedUsers": @[mcUser(@1, @"A", @"B", @"ab", @0)],
	};
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Game");
	XCTAssertEqual(card.action, TGMessageCardActionPlayGame);
}

- (void)testPrecedence_SharedUsersOverSharedChat {
	NSDictionary *row = @{
		@"id": @15,
		@"sharedUsers": @[mcUser(@1, @"Alice", @"Smith", @"alice", @0)],
		@"sharedChat": @{@"chatId": @999, @"title": @"Tech Group"},
	};
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Shared contact");
}

- (void)testPrecedence_SharedChatOverGroupCall {
	NSDictionary *row = @{
		@"id": @16,
		@"sharedChat": @{@"chatId": @777, @"title": @"Channel"},
		@"groupCall": @{@"groupCallId": @444, @"isActive": @YES},
	};
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Shared chat");
}

- (void)testPrecedence_GroupCallOverStory {
	NSDictionary *row = @{
		@"id": @17,
		@"groupCall": @{@"groupCallId": @111, @"isActive": @YES},
		@"story": @{@"storyId": @222, @"posterChatId": @333},
	};
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Voice chat");
}

#pragma mark - Invoice

- (void)testInvoice_StandardNormalFlow {
	NSDictionary *row = mcRow(@501, @"invoice", @{
		@"title": @"Premium Membership",
		@"description": @"One year access",
		@"photoFileId": @888,
		@"currency": @"USD",
		@"totalAmount": @499,
		@"isTest": @NO,
		@"receiptMessageId": @0,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Invoice");
	XCTAssertEqualObjects(card.title, @"Premium Membership");
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"One year access");
	XCTAssertEqual((int64_t)card.imageFileId, (int64_t)888);
	XCTAssertTrue(fabs(card.imageAspect - 1.0f) < 0.001f);
	XCTAssertFalse(card.imageIsRound);
	XCTAssertEqualObjects(card.buttonTitle, @"Pay $4.99");
	XCTAssertEqual(card.action, TGMessageCardActionPay);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)501);
	XCTAssertEqual((int64_t)card.actionChatId, (int64_t)0);
}

- (void)testInvoice_TestInvoiceKicker {
	NSDictionary *row = mcRow(@502, @"invoice", @{
		@"title": @"Widget",
		@"currency": @"EUR",
		@"totalAmount": @1250,
		@"isTest": @YES,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Test Invoice");
	XCTAssertEqualObjects(card.buttonTitle, @"Pay 12.50 EUR");
}

- (void)testInvoice_EmptyTitleFallsBackToInvoice {
	NSDictionary *row = mcRow(@503, @"invoice", @{
		@"title": @"",
		@"currency": @"USD",
		@"totalAmount": @0,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.title, @"Invoice");
	XCTAssertEqualObjects(card.buttonTitle, @"Pay $0.00");
}

- (void)testInvoice_ReceiptMessageIdShowsReceipt {
	NSDictionary *row = mcRow(@504, @"invoice", @{
		@"title": @"Paid Item",
		@"receiptMessageId": @12345,
		@"currency": @"USD",
		@"totalAmount": @999,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.buttonTitle, @"Receipt");
}

- (void)testInvoice_EmptyDescriptionGivesNoLines {
	NSDictionary *row = mcRow(@505, @"invoice", @{
		@"title": @"Item",
		@"description": @"",
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)0);
}

- (void)testInvoice_StringAndNumberRowId {
	NSDictionary *rowNum = mcRow(@5368324170671202286LL, @"invoice", @{
		@"title": @"Item",
	});
	NSDictionary *rowStr = mcRow(@"5368324170671202286", @"invoice", @{
		@"title": @"Item",
	});
	TGMessageCard *cardNum = TGMessageCardForRow(rowNum);
	TGMessageCard *cardStr = TGMessageCardForRow(rowStr);
	XCTAssertTrue(cardNum != nil);
	XCTAssertTrue(cardStr != nil);
	XCTAssertEqual((int64_t)cardNum.actionTargetId, (int64_t)5368324170671202286LL);
	XCTAssertEqual((int64_t)cardStr.actionTargetId, (int64_t)5368324170671202286LL);
}

#pragma mark - Giveaway

- (void)testGiveaway_StarsPrizeSingularAndPlural {
	NSDictionary *row1 = mcRow(@601, @"giveaway", @{
		@"starCount": @1,
	});
	TGMessageCard *card1 = TGMessageCardForRow(row1);
	XCTAssertTrue(card1 != nil);
	XCTAssertEqual((NSUInteger)card1.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card1.lines[0], @"1 Star");

	NSDictionary *row50 = mcRow(@602, @"giveaway", @{
		@"starCount": @50,
	});
	TGMessageCard *card50 = TGMessageCardForRow(row50);
	XCTAssertTrue(card50 != nil);
	XCTAssertEqual((NSUInteger)card50.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card50.lines[0], @"50 Stars");
}

- (void)testGiveaway_PremiumPrizeSingularWinnerSingularMonth {
	NSDictionary *row = mcRow(@603, @"giveaway", @{
		@"winnerCount": @1,
		@"premiumMonths": @1,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"1 Telegram Premium subscription for 1 month");
}

- (void)testGiveaway_PremiumPrizePluralWinnersPluralMonths {
	NSDictionary *row = mcRow(@604, @"giveaway", @{
		@"winnerCount": @5,
		@"premiumMonths": @6,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"5 Telegram Premium subscriptions for 6 months");
}

- (void)testGiveaway_PremiumPrizeSingularWinnerPluralMonths {
	NSDictionary *row = mcRow(@605, @"giveaway", @{
		@"winnerCount": @1,
		@"premiumMonths": @12,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"1 Telegram Premium subscription for 12 months");
}

- (void)testGiveaway_PremiumPrizePluralWinnersSingularMonth {
	NSDictionary *row = mcRow(@606, @"giveaway", @{
		@"winnerCount": @3,
		@"premiumMonths": @1,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"3 Telegram Premium subscriptions for 1 month");
}

- (void)testGiveaway_FullLinesAndDateFormat {
	int64_t ts = 1700000000;
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)ts];
	NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
	fmt.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
	fmt.dateFormat = @"MMM d, yyyy";
	fmt.timeZone = [NSTimeZone defaultTimeZone];
	NSString *expectedDateLine = [NSString stringWithFormat:@"Winners selected on %@", [fmt stringFromDate:date]];

	NSDictionary *row = mcRow(@607, @"giveaway", @{
		@"starCount": @100,
		@"prizeDescription": @"Exclusive badges",
		@"winnersSelectionDate": @(ts),
		@"onlyNewMembers": @YES,
		@"stickerFileId": @999,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Giveaway");
	XCTAssertEqualObjects(card.title, @"Giveaway Prizes");
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)4);
	XCTAssertEqualObjects(card.lines[0], @"100 Stars");
	XCTAssertEqualObjects(card.lines[1], @"Exclusive badges");
	XCTAssertEqualObjects(card.lines[2], expectedDateLine);
	XCTAssertEqualObjects(card.lines[3], @"Only new subscribers");
	XCTAssertEqual((int64_t)card.imageFileId, (int64_t)999);
	XCTAssertTrue(fabs(card.imageAspect - 1.0f) < 0.001f);
	XCTAssertEqualObjects(card.buttonTitle, @"Learn More");
	XCTAssertEqual(card.action, TGMessageCardActionOpenGiveaway);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)607);
}

- (void)testGiveaway_LinesCappedAtFour {
	NSDictionary *row = mcRow(@608, @"giveaway", @{
		@"starCount": @10,
		@"prizeDescription": @"A great prize",
		@"winnersSelectionDate": @1700000000,
		@"onlyNewMembers": @YES,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)4);
}

- (void)testGiveaway_NoPrizeWhenZeroStarsAndMonths {
	NSDictionary *row = mcRow(@609, @"giveaway", @{
		@"starCount": @0,
		@"premiumMonths": @0,
		@"prizeDescription": @"Mystery gift",
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"Mystery gift");
}

- (void)testGiveaway_ActionAndTarget {
	NSDictionary *row = mcRow(@777, @"giveaway", @{@"starCount": @10});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)777);
}

#pragma mark - GiveawayWinners

- (void)testGiveawayWinners_SingularWinner {
	NSDictionary *row = mcRow(@701, @"giveawayWinners", @{
		@"winnerCount": @1,
		@"giveawayMessageId": @801,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Giveaway Results");
	XCTAssertEqualObjects(card.title, @"Winners Selected!");
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"1 winner");
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)801);
}

- (void)testGiveawayWinners_PluralWinners {
	NSDictionary *row = mcRow(@702, @"giveawayWinners", @{
		@"winnerCount": @5,
		@"giveawayMessageId": @802,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"5 winners");
}

- (void)testGiveawayWinners_PrizeLineStars {
	NSDictionary *row = mcRow(@703, @"giveawayWinners", @{
		@"winnerCount": @2,
		@"starCount": @50,
		@"giveawayMessageId": @803,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)2);
	XCTAssertEqualObjects(card.lines[0], @"2 winners");
	XCTAssertEqualObjects(card.lines[1], @"50 Stars");
}

- (void)testGiveawayWinners_PrizeLinePremium {
	NSDictionary *row = mcRow(@704, @"giveawayWinners", @{
		@"winnerCount": @1,
		@"premiumMonths": @1,
		@"giveawayMessageId": @804,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)2);
	XCTAssertEqualObjects(card.lines[0], @"1 winner");
	XCTAssertEqualObjects(card.lines[1], @"1 Telegram Premium subscription for 1 month");
}

- (void)testGiveawayWinners_UnclaimedPrizesSingularAndPlural {
	NSDictionary *rowSingular = mcRow(@705, @"giveawayWinners", @{
		@"winnerCount": @1,
		@"unclaimedPrizeCount": @1,
		@"giveawayMessageId": @805,
	});
	TGMessageCard *cardS = TGMessageCardForRow(rowSingular);
	XCTAssertTrue(cardS != nil);
	XCTAssertEqual((NSUInteger)cardS.lines.count, (NSUInteger)2);
	XCTAssertEqualObjects(cardS.lines[1], @"1 unclaimed prize");

	NSDictionary *rowPlural = mcRow(@706, @"giveawayWinners", @{
		@"winnerCount": @3,
		@"unclaimedPrizeCount": @3,
		@"giveawayMessageId": @806,
	});
	TGMessageCard *cardP = TGMessageCardForRow(rowPlural);
	XCTAssertTrue(cardP != nil);
	XCTAssertEqual((NSUInteger)cardP.lines.count, (NSUInteger)2);
	XCTAssertEqualObjects(cardP.lines[1], @"3 unclaimed prizes");
}

- (void)testGiveawayWinners_WasRefunded {
	NSDictionary *row = mcRow(@707, @"giveawayWinners", @{
		@"winnerCount": @0,
		@"wasRefunded": @YES,
		@"giveawayMessageId": @807,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)2);
	XCTAssertEqualObjects(card.lines[0], @"0 winners");
	XCTAssertEqualObjects(card.lines[1], @"The giveaway was refunded");
}

- (void)testGiveawayWinners_TargetIsGiveawayMessageId {
	NSDictionary *row = mcRow(@999, @"giveawayWinners", @{
		@"winnerCount": @1,
		@"giveawayMessageId": @1234567LL,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)1234567LL);
	XCTAssertEqual(card.action, TGMessageCardActionOpenGiveaway);
	XCTAssertEqualObjects(card.buttonTitle, @"Learn More");
}

- (void)testGiveawayWinners_NoImage {
	NSDictionary *row = mcRow(@708, @"giveawayWinners", @{
		@"winnerCount": @1,
		@"giveawayMessageId": @808,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((int64_t)card.imageFileId, (int64_t)0);
}

- (void)testGiveawayWinners_CappedAtFourLines {
	NSDictionary *row = mcRow(@709, @"giveawayWinners", @{
		@"winnerCount": @2,
		@"starCount": @20,
		@"unclaimedPrizeCount": @1,
		@"wasRefunded": @YES,
		@"giveawayMessageId": @809,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)4);
	XCTAssertEqualObjects(card.lines[0], @"2 winners");
	XCTAssertEqualObjects(card.lines[1], @"20 Stars");
	XCTAssertEqualObjects(card.lines[2], @"1 unclaimed prize");
	XCTAssertEqualObjects(card.lines[3], @"The giveaway was refunded");
}

#pragma mark - Gift

- (void)testGift_StarsTitleSingular {
	NSDictionary *row = mcRow(@1, @"gift", @{@"giftId": @10, @"starCount": @1});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Gift");
	XCTAssertEqualObjects(card.title, @"1 Star");
}

- (void)testGift_StarsTitlePlural {
	NSDictionary *row = mcRow(@2, @"gift", @{@"giftId": @11, @"starCount": @25});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.title, @"25 Stars");
}

- (void)testGift_ZeroStarsTitleIsGift {
	NSDictionary *row = mcRow(@3, @"gift", @{@"giftId": @12, @"starCount": @0});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.title, @"Gift");
}

- (void)testGift_WasConvertedSingularStar {
	NSDictionary *row = mcRow(@4, @"gift", @{
		@"giftId": @13,
		@"wasConverted": @YES,
		@"sellStarCount": @1,
		@"text": @"Happy birthday!",
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)2);
	XCTAssertEqualObjects(card.lines[0], @"Happy birthday!");
	XCTAssertEqualObjects(card.lines[1], @"Converted to 1 Star");
}

- (void)testGift_WasConvertedPluralStars {
	NSDictionary *row = mcRow(@5, @"gift", @{
		@"giftId": @14,
		@"wasConverted": @YES,
		@"sellStarCount": @10,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"Converted to 10 Stars");
}

- (void)testGift_WasUpgraded {
	NSDictionary *row = mcRow(@6, @"gift", @{
		@"giftId": @15,
		@"wasUpgraded": @YES,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"Upgraded to a collectible");
}

- (void)testGift_IsSaved {
	NSDictionary *row = mcRow(@7, @"gift", @{
		@"giftId": @16,
		@"isSaved": @YES,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"Shown on the profile");
}

- (void)testGift_ThumbnailPreferredOverSticker {
	NSDictionary *row = mcRow(@8, @"gift", @{
		@"giftId": @17,
		@"stickerThumbFileId": @101,
		@"stickerFileId": @202,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((int64_t)card.imageFileId, (int64_t)101);
	XCTAssertTrue(fabs(card.imageAspect - 1.0f) < 0.001f);
}

- (void)testGift_StickerFileIdWhenNoThumbnail {
	NSDictionary *row = mcRow(@9, @"gift", @{
		@"giftId": @18,
		@"stickerThumbFileId": @0,
		@"stickerFileId": @202,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((int64_t)card.imageFileId, (int64_t)202);
}

- (void)testGift_TargetIsGiftId {
	NSDictionary *row = mcRow(@123, @"gift", @{@"giftId": @9876});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)9876);
	XCTAssertEqual(card.action, TGMessageCardActionViewGift);
	XCTAssertEqualObjects(card.buttonTitle, @"View");
}

#pragma mark - UpgradedGift

- (void)testUpgradedGift_TitleWithNumber {
	NSDictionary *row = mcRow(@201, @"upgradedGift", @{
		@"title": @"Pepe",
		@"number": @42,
		@"modelStickerFileId": @333,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Collectible");
	XCTAssertEqualObjects(card.title, @"Pepe #42");
	XCTAssertEqual((int64_t)card.imageFileId, (int64_t)333);
	XCTAssertTrue(fabs(card.imageAspect - 1.0f) < 0.001f);
	XCTAssertEqualObjects(card.buttonTitle, @"View");
	XCTAssertEqual(card.action, TGMessageCardActionViewGift);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)201);
}

- (void)testUpgradedGift_TitleWithNumberZero {
	NSDictionary *row = mcRow(@202, @"upgradedGift", @{
		@"title": @"Pepe",
		@"number": @0,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.title, @"Pepe");
}

- (void)testUpgradedGift_EmptyTitle {
	NSDictionary *row = mcRow(@203, @"upgradedGift", @{
		@"title": @"",
		@"number": @0,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.title, @"Collectible");
}

- (void)testUpgradedGift_ModelSymbolBackdropLines {
	NSDictionary *row = mcRow(@204, @"upgradedGift", @{
		@"title": @"Spike",
		@"number": @10,
		@"modelName": @"Dragon",
		@"symbolName": @"Fire",
		@"backdropName": @"Crimson",
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)3);
	XCTAssertEqualObjects(card.lines[0], @"Model: Dragon");
	XCTAssertEqualObjects(card.lines[1], @"Symbol: Fire");
	XCTAssertEqualObjects(card.lines[2], @"Backdrop: Crimson");
}

- (void)testUpgradedGift_TargetIsRowId {
	NSDictionary *row = mcRow(@8888, @"upgradedGift", @{
		@"title": @"Gift",
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)8888);
}

#pragma mark - Game

- (void)testGame_StandardProperties {
	NSDictionary *row = mcRow(@301, @"game", @{
		@"gameId": @777,
		@"title": @"Lumberjack",
		@"description": @"Chop trees quickly",
		@"photoFileId": @555,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Game");
	XCTAssertEqualObjects(card.title, @"Lumberjack");
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"Chop trees quickly");
	XCTAssertEqual((int64_t)card.imageFileId, (int64_t)555);
	XCTAssertTrue(fabs(card.imageAspect - (16.0f / 9.0f)) < 0.001f);
	XCTAssertEqualObjects(card.buttonTitle, @"Play");
	XCTAssertEqual(card.action, TGMessageCardActionPlayGame);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)777);
}

- (void)testGame_EmptyTitleFallsBackToGame {
	NSDictionary *row = mcRow(@302, @"game", @{
		@"gameId": @778,
		@"title": @"",
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.title, @"Game");
}

- (void)testGame_EmptyDescriptionGivesNoLines {
	NSDictionary *row = mcRow(@303, @"game", @{
		@"gameId": @779,
		@"title": @"Pong",
		@"description": @"",
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)0);
}

- (void)testGame_TargetIsGameId {
	NSDictionary *row = mcRow(@1001, @"game", @{
		@"gameId": @4004,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)4004);
}

#pragma mark - SharedUsers

- (void)testSharedUsers_SingleUserFullName {
	NSDictionary *user = mcUser(@101, @"John", @"Doe", @"johndoe", @55);
	NSDictionary *row = mcRow(@401, @"sharedUsers", @[user]);
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Shared contact");
	XCTAssertEqualObjects(card.title, @"John Doe");
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"@johndoe");
	XCTAssertEqual((int64_t)card.imageFileId, (int64_t)55);
	XCTAssertTrue(fabs(card.imageAspect - 1.0f) < 0.001f);
	XCTAssertTrue(card.imageIsRound);
	XCTAssertEqualObjects(card.buttonTitle, @"Open");
	XCTAssertEqual(card.action, TGMessageCardActionOpenUser);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)101);
}

- (void)testSharedUsers_SingleUserFirstNameOnly {
	NSDictionary *user = mcUser(@102, @"Alice", @"", @"alice", @0);
	NSDictionary *row = mcRow(@402, @"sharedUsers", @[user]);
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.title, @"Alice");
}

- (void)testSharedUsers_SingleUserLastNameOnly {
	NSDictionary *user = mcUser(@103, @"", @"Smith", @"smith", @0);
	NSDictionary *row = mcRow(@403, @"sharedUsers", @[user]);
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.title, @"Smith");
}

- (void)testSharedUsers_SingleUserDeletedAccount {
	NSDictionary *user = mcUser(@104, @"", @"", @"", @0);
	NSDictionary *row = mcRow(@404, @"sharedUsers", @[user]);
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.title, @"Deleted Account");
}

- (void)testSharedUsers_SingleUserHandle {
	NSDictionary *user = mcUser(@105, @"Bob", @"Lee", @"@boblee", @0);
	NSDictionary *row = mcRow(@405, @"sharedUsers", @[user]);
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.lines[0], @"@boblee");
}

- (void)testSharedUsers_SingleUserNoHandle {
	NSDictionary *user = mcUser(@106, @"Carol", @"White", @"", @0);
	NSDictionary *row = mcRow(@406, @"sharedUsers", @[user]);
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)0);
}

- (void)testSharedUsers_SingleUserTargetAndRound {
	NSDictionary *user = mcUser(@999, @"Dave", @"", @"dave", @44);
	NSDictionary *row = mcRow(@407, @"sharedUsers", @[user]);
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)999);
	XCTAssertTrue(card.imageIsRound);
}

- (void)testSharedUsers_TwoUsersPluralTitle {
	NSDictionary *u1 = mcUser(@1, @"User", @"One", @"u1", @10);
	NSDictionary *u2 = mcUser(@2, @"User", @"Two", @"u2", @20);
	NSDictionary *row = mcRow(@408, @"sharedUsers", @[u1, u2]);
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Shared contacts");
	XCTAssertEqualObjects(card.title, @"2 contacts");
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)2);
	XCTAssertEqualObjects(card.lines[0], @"User One");
	XCTAssertEqualObjects(card.lines[1], @"User Two");
	XCTAssertEqual((int64_t)card.imageFileId, (int64_t)0);
	XCTAssertFalse(card.imageIsRound);
	XCTAssertEqualObjects(card.buttonTitle, @"Open");
	XCTAssertEqual(card.action, TGMessageCardActionOpenUser);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)1);
}

- (void)testSharedUsers_MoreThanFourUsersCapped {
	NSMutableArray *users = [NSMutableArray array];
	for (int i = 1; i <= 6; i++) {
		[users addObject:mcUser(@(i * 10), [NSString stringWithFormat:@"First%d", i], [NSString stringWithFormat:@"Last%d", i], @"", @0)];
	}
	NSDictionary *row = mcRow(@409, @"sharedUsers", users);
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.title, @"6 contacts");
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)4);
	XCTAssertEqualObjects(card.lines[0], @"First1 Last1");
	XCTAssertEqualObjects(card.lines[1], @"First2 Last2");
	XCTAssertEqualObjects(card.lines[2], @"First3 Last3");
	XCTAssertEqualObjects(card.lines[3], @"First4 Last4");
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)10);
}

- (void)testSharedUsers_MultiUsersNoImage {
	NSDictionary *u1 = mcUser(@1, @"A", @"", @"", @11);
	NSDictionary *u2 = mcUser(@2, @"B", @"", @"", @22);
	NSDictionary *row = mcRow(@410, @"sharedUsers", @[u1, u2]);
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((int64_t)card.imageFileId, (int64_t)0);
}

#pragma mark - SharedChat

- (void)testSharedChat_StandardWithHandle {
	NSDictionary *row = mcRow(@501, @"sharedChat", @{
		@"chatId": @123456,
		@"title": @"Telegram Developers",
		@"username": @"tgdev",
		@"photoFileId": @88,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Shared chat");
	XCTAssertEqualObjects(card.title, @"Telegram Developers");
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"@tgdev");
	XCTAssertEqual((int64_t)card.imageFileId, (int64_t)88);
	XCTAssertTrue(fabs(card.imageAspect - 1.0f) < 0.001f);
	XCTAssertTrue(card.imageIsRound);
	XCTAssertEqualObjects(card.buttonTitle, @"Open");
	XCTAssertEqual(card.action, TGMessageCardActionOpenChat);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)123456);
}

- (void)testSharedChat_EmptyTitleFallsBackToChat {
	NSDictionary *row = mcRow(@502, @"sharedChat", @{
		@"chatId": @999,
		@"title": @"",
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.title, @"Chat");
}

- (void)testSharedChat_NoUsernameGivesNoLines {
	NSDictionary *row = mcRow(@503, @"sharedChat", @{
		@"chatId": @999,
		@"title": @"Private Channel",
		@"username": @"",
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)0);
}

- (void)testSharedChat_TargetIsChatId {
	NSDictionary *row = mcRow(@111, @"sharedChat", @{
		@"chatId": @777888,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)777888);
}

#pragma mark - GroupCall

- (void)testGroupCall_ActiveVoiceCall {
	NSDictionary *row = mcRow(@601, @"groupCall", @{
		@"groupCallId": @123,
		@"isActive": @YES,
		@"isVideo": @NO,
		@"duration": @0,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Voice chat");
	XCTAssertEqualObjects(card.title, @"Ongoing");
	XCTAssertEqualObjects(card.buttonTitle, @"Join");
	XCTAssertEqual(card.action, TGMessageCardActionJoinCall);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)123);
}

- (void)testGroupCall_EndedVideoCall {
	NSDictionary *row = mcRow(@602, @"groupCall", @{
		@"groupCallId": @124,
		@"isActive": @NO,
		@"isVideo": @YES,
		@"wasMissed": @NO,
		@"duration": @65,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Video chat");
	XCTAssertEqualObjects(card.title, @"Ended");
	XCTAssertTrue(card.buttonTitle == nil);
	XCTAssertEqual(card.action, TGMessageCardActionNone);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)0);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)1);
	XCTAssertEqualObjects(card.lines[0], @"Duration 1:05");
}

- (void)testGroupCall_MissedVideoCall {
	NSDictionary *row = mcRow(@603, @"groupCall", @{
		@"groupCallId": @125,
		@"isActive": @NO,
		@"isVideo": @YES,
		@"wasMissed": @YES,
		@"duration": @0,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Video chat");
	XCTAssertEqualObjects(card.title, @"Missed");
	XCTAssertTrue(card.buttonTitle == nil);
}

- (void)testGroupCall_DurationMinutesSeconds {
	NSDictionary *row = mcRow(@604, @"groupCall", @{
		@"groupCallId": @126,
		@"duration": @65,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.lines[0], @"Duration 1:05");
}

- (void)testGroupCall_DurationHoursMinutesSeconds {
	NSDictionary *row = mcRow(@605, @"groupCall", @{
		@"groupCallId": @127,
		@"duration": @3725,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.lines[0], @"Duration 1:02:05");
}

- (void)testGroupCall_ZeroDuration {
	NSDictionary *row = mcRow(@606, @"groupCall", @{
		@"groupCallId": @128,
		@"duration": @0,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)0);
}

- (void)testGroupCall_NegativeDuration {
	NSDictionary *row = mcRow(@607, @"groupCall", @{
		@"groupCallId": @129,
		@"duration": @(-10),
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)0);
}

- (void)testGroupCall_InactiveCallHasNilButtonAndNoAction {
	NSDictionary *row = mcRow(@608, @"groupCall", @{
		@"groupCallId": @130,
		@"isActive": @NO,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertTrue(card.buttonTitle == nil);
	XCTAssertEqual(card.action, TGMessageCardActionNone);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)0);
}

#pragma mark - Story

- (void)testStory_StandardStory {
	NSDictionary *row = mcRow(@701, @"story", @{
		@"storyId": @555,
		@"posterChatId": @666,
		@"viaMention": @NO,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.kicker, @"Story");
	XCTAssertEqualObjects(card.title, @"Story");
	XCTAssertEqual((NSUInteger)card.lines.count, (NSUInteger)0);
	XCTAssertEqual((int64_t)card.imageFileId, (int64_t)0);
	XCTAssertEqualObjects(card.buttonTitle, @"Open");
	XCTAssertEqual(card.action, TGMessageCardActionOpenStory);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)555);
	XCTAssertEqual((int64_t)card.actionChatId, (int64_t)666);
}

- (void)testStory_ViaMention {
	NSDictionary *row = mcRow(@702, @"story", @{
		@"storyId": @556,
		@"posterChatId": @667,
		@"viaMention": @YES,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqualObjects(card.title, @"Mentioned you in a story");
}

- (void)testStory_TargetsAndPosterChatId {
	NSDictionary *row = mcRow(@703, @"story", @{
		@"storyId": @10001LL,
		@"posterChatId": @20002LL,
	});
	TGMessageCard *card = TGMessageCardForRow(row);
	XCTAssertTrue(card != nil);
	XCTAssertEqual((int64_t)card.actionTargetId, (int64_t)10001LL);
	XCTAssertEqual((int64_t)card.actionChatId, (int64_t)20002LL);
}

#pragma mark - String vs Number IDs

- (void)testCard_StringVsNumberIdsAllMatch {
	// Game ID
	TGMessageCard *gNum = TGMessageCardForRow(mcRow(@1, @"game", @{@"gameId": @5368324170671202286LL}));
	TGMessageCard *gStr = TGMessageCardForRow(mcRow(@1, @"game", @{@"gameId": @"5368324170671202286"}));
	XCTAssertEqual((int64_t)gNum.actionTargetId, (int64_t)gStr.actionTargetId);

	// Chat ID
	TGMessageCard *cNum = TGMessageCardForRow(mcRow(@1, @"sharedChat", @{@"chatId": @5368324170671202286LL}));
	TGMessageCard *cStr = TGMessageCardForRow(mcRow(@1, @"sharedChat", @{@"chatId": @"5368324170671202286"}));
	XCTAssertEqual((int64_t)cNum.actionTargetId, (int64_t)cStr.actionTargetId);

	// Story ID and Chat ID
	TGMessageCard *sNum = TGMessageCardForRow(mcRow(@1, @"story", @{@"storyId": @5368324170671202286LL, @"posterChatId": @999}));
	TGMessageCard *sStr = TGMessageCardForRow(mcRow(@1, @"story", @{@"storyId": @"5368324170671202286", @"posterChatId": @"999"}));
	XCTAssertEqual((int64_t)sNum.actionTargetId, (int64_t)sStr.actionTargetId);
	XCTAssertEqual((int64_t)sNum.actionChatId, (int64_t)sStr.actionChatId);
}

@end
