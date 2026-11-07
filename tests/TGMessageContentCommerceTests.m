// TGMessageContentCommerceTests.m — the commerce half of a bubble.
//
// Paid media, invoices, giveaways and gifts are drawn from numbers and file
// ids read out of nested TDLib objects. A renamed key there is invisible:
// the bubble simply draws a zero, so every field the flattening promises is
// asserted against the schema's spelling here.
#import "TGTestRunner.h"
#import "TGMessageContentCommerce.h"

static NSDictionary *tfile(id fid) {
	return @{@"@type" : @"file", @"id" : fid};
}

static NSDictionary *tsize(id fid, int width, int height) {
	return @{@"@type" : @"photoSize", @"type" : @"x", @"photo" : tfile(fid),
			 @"width" : @(width), @"height" : @(height)};
}

static NSDictionary *tphoto(NSArray *sizes) {
	return @{@"@type" : @"photo", @"sizes" : sizes};
}

static NSDictionary *tuser(id uid) {
	return @{@"@type" : @"messageSenderUser", @"user_id" : uid};
}

static NSDictionary *tsticker(id fileId, id thumbId) {
	NSMutableDictionary *sticker = [@{
		@"@type" : @"sticker",
		@"sticker" : tfile(fileId),
	} mutableCopy];
	if (thumbId)
		sticker[@"thumbnail"] = @{@"@type" : @"thumbnail", @"file" : tfile(thumbId)};
	return sticker;
}

@interface TGMessageContentCommerceTests : XCTestCase @end

@implementation TGMessageContentCommerceTests

#pragma mark - paid media

- (void)testPaidMedia_FullPhotoWithLiveVideoAndCaption {
	NSData *mini = [@"hi" dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *content = @{
		@"@type" : @"messagePaidMedia",
		@"star_count" : @(75),
		@"caption" : @{@"@type" : @"formattedText", @"text" : @"see this"},
		@"show_caption_above_media" : @YES,
		@"media" : @[
			@{@"@type" : @"paidMediaPhoto",
			  @"photo" : @{@"@type" : @"photo",
						   @"minithumbnail" : @{@"@type" : @"minithumbnail",
											   @"data" : @"aGk="},
						   @"sizes" : @[tsize(@11, 100, 50), tsize(@22, 800, 400)]},
			  @"video" : @{@"@type" : @"video", @"duration" : @7,
						   @"thumbnail" : @{@"@type" : @"thumbnail", @"file" : tfile(@33)},
						   @"video" : tfile(@44)}},
			@{@"@type" : @"paidMediaUnsupported"},
		],
	};

	NSDictionary *paid = TGFlattenCommerceContent(content)[@"paidMedia"];
	XCTAssertEqualObjects(paid[@"caption"], @"see this");
	XCTAssertTrue([paid[@"captionAbove"] boolValue]);
	XCTAssertEqual([paid[@"starCount"] longLongValue], 75LL);

	NSArray *items = paid[@"items"];
	XCTAssertEqual(items.count, (NSUInteger)2);
	NSDictionary *photo = items[0];
	XCTAssertEqualObjects(photo[@"kind"], @"photo");
	XCTAssertEqual([photo[@"width"] intValue], 800);
	XCTAssertEqual([photo[@"height"] intValue], 400);
	XCTAssertEqual([photo[@"duration"] intValue], 7);
	XCTAssertEqual([photo[@"photoFileId"] longLongValue], 22LL);
	XCTAssertEqual([photo[@"thumbFileId"] longLongValue], 33LL);
	XCTAssertEqual([photo[@"videoFileId"] longLongValue], 44LL);
	XCTAssertEqualObjects(photo[@"minithumbnail"], mini);
	XCTAssertEqualObjects(items[1][@"kind"], @"unsupported");
}

- (void)testPaidMedia_PreviewDecodesThumbnailAndStringStarCount {
	NSData *mini = [@"hi" dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *content = @{
		@"@type" : @"messagePaidMedia",
		@"star_count" : @"42",
		@"media" : @[@{@"@type" : @"paidMediaPreview",
					   @"width" : @320, @"height" : @240, @"duration" : @12,
					   @"minithumbnail" : @{@"@type" : @"minithumbnail",
										   @"width" : @32, @"height" : @24,
										   @"data" : @"aGk="}}],
	};

	NSDictionary *paid = TGFlattenCommerceContent(content)[@"paidMedia"];
	XCTAssertEqual([paid[@"starCount"] longLongValue], 42LL);
	XCTAssertEqualObjects(paid[@"caption"], @"");
	XCTAssertFalse([paid[@"captionAbove"] boolValue]);

	NSDictionary *item = paid[@"items"][0];
	XCTAssertEqualObjects(item[@"kind"], @"preview");
	XCTAssertEqual([item[@"width"] intValue], 320);
	XCTAssertEqual([item[@"height"] intValue], 240);
	XCTAssertEqual([item[@"duration"] intValue], 12);
	XCTAssertEqualObjects(item[@"minithumbnail"], mini);
	XCTAssertEqual([item[@"photoFileId"] longLongValue], 0LL);
}

- (void)testPaidMedia_VideoVariant {
	NSDictionary *content = @{
		@"@type" : @"messagePaidMedia",
		@"media" : @[@{@"@type" : @"paidMediaVideo",
					   @"start_timestamp" : @3,
					   @"video" : @{@"@type" : @"video",
									@"width" : @1280, @"height" : @720,
									@"duration" : @65,
									@"thumbnail" : @{@"@type" : @"thumbnail",
													 @"file" : tfile(@55)},
									@"video" : tfile(@66)}}],
	};

	NSDictionary *item = TGFlattenCommerceContent(content)[@"paidMedia"][@"items"][0];
	XCTAssertEqualObjects(item[@"kind"], @"video");
	XCTAssertEqual([item[@"width"] intValue], 1280);
	XCTAssertEqual([item[@"height"] intValue], 720);
	XCTAssertEqual([item[@"duration"] intValue], 65);
	XCTAssertEqual([item[@"thumbFileId"] longLongValue], 55LL);
	XCTAssertEqual([item[@"videoFileId"] longLongValue], 66LL);
	XCTAssertTrue(item[@"minithumbnail"] == nil);
}

- (void)testPaidMedia_UnsupportedAndAbsentMediaKeepDefaults {
	NSDictionary *paid = TGFlattenCommerceContent(@{@"@type" : @"messagePaidMedia"})[@"paidMedia"];
	XCTAssertEqual([paid[@"starCount"] longLongValue], 0LL);
	XCTAssertEqualObjects(paid[@"caption"], @"");
	XCTAssertEqualObjects(paid[@"items"], @[]);

	NSDictionary *item = TGFlattenCommerceContent(@{
		@"@type" : @"messagePaidMedia",
		@"media" : @[@{@"@type" : @"paidMediaUnsupported"}],
	})[@"paidMedia"][@"items"][0];
	XCTAssertEqualObjects(item[@"kind"], @"unsupported");
	XCTAssertEqual([item[@"width"] intValue], 0);
	XCTAssertEqual([item[@"photoFileId"] longLongValue], 0LL);
	XCTAssertEqual([item[@"thumbFileId"] longLongValue], 0LL);
	XCTAssertEqual([item[@"videoFileId"] longLongValue], 0LL);
}

- (void)testPaidMedia_CaptionAboveFalseWhenAbsent {
	NSDictionary *paid = TGFlattenCommerceContent(@{
		@"@type" : @"messagePaidMedia",
		@"caption" : @{@"@type" : @"formattedText", @"text" : @"paid"},
	})[@"paidMedia"];
	XCTAssertEqualObjects(paid[@"caption"], @"paid");
	XCTAssertFalse([paid[@"captionAbove"] boolValue]);
}

#pragma mark - invoice

- (void)testInvoice_FullObject {
	NSDictionary *content = @{
		@"@type" : @"messageInvoice",
		@"currency" : @"USD",
		@"total_amount" : @(1999),
		@"start_parameter" : @"invoice-7",
		@"is_test" : @YES,
		@"need_shipping_address" : @YES,
		@"receipt_message_id" : @(88),
		@"paid_media" : @{@"@type" : @"paidMediaUnsupported"},
		@"product_info" : @{
			@"@type" : @"productInfo",
			@"title" : @"Sticker pack",
			@"description" : @{@"@type" : @"formattedText", @"text" : @"ten stickers"},
			@"photo" : tphoto(@[tsize(@9, 100, 100), tsize(@8, 500, 500)]),
		},
	};

	NSDictionary *invoice = TGFlattenCommerceContent(content)[@"invoice"];
	XCTAssertEqualObjects(invoice[@"title"], @"Sticker pack");
	XCTAssertEqualObjects(invoice[@"description"], @"ten stickers");
	XCTAssertEqual([invoice[@"photoFileId"] longLongValue], 8LL);
	XCTAssertEqualObjects(invoice[@"currency"], @"USD");
	XCTAssertEqual([invoice[@"totalAmount"] longLongValue], 1999LL);
	XCTAssertEqualObjects(invoice[@"startParameter"], @"invoice-7");
	XCTAssertTrue([invoice[@"isTest"] boolValue]);
	XCTAssertTrue([invoice[@"needShipping"] boolValue]);
	XCTAssertEqual([invoice[@"receiptMessageId"] longLongValue], 88LL);
	XCTAssertTrue([invoice[@"hasPaidMedia"] boolValue]);
}

- (void)testInvoice_MinimalKeepsZeroValues {
	NSDictionary *invoice = TGFlattenCommerceContent(@{@"@type" : @"messageInvoice"})[@"invoice"];
	XCTAssertEqualObjects(invoice[@"title"], @"");
	XCTAssertEqualObjects(invoice[@"description"], @"");
	XCTAssertEqual([invoice[@"photoFileId"] longLongValue], 0LL);
	XCTAssertEqualObjects(invoice[@"currency"], @"");
	XCTAssertEqual([invoice[@"totalAmount"] longLongValue], 0LL);
	XCTAssertEqualObjects(invoice[@"startParameter"], @"");
	XCTAssertFalse([invoice[@"isTest"] boolValue]);
	XCTAssertFalse([invoice[@"needShipping"] boolValue]);
	XCTAssertEqual([invoice[@"receiptMessageId"] longLongValue], 0LL);
	XCTAssertFalse([invoice[@"hasPaidMedia"] boolValue]);
}

- (void)testInvoice_LargestPhotoWinsByAreaNotOrder {
	NSDictionary *invoice = TGFlattenCommerceContent(@{
		@"@type" : @"messageInvoice",
		@"product_info" : @{@"@type" : @"productInfo",
							@"photo" : tphoto(@[tsize(@1, 1000, 1000), tsize(@2, 2000, 100)])},
	})[@"invoice"];
	XCTAssertEqual([invoice[@"photoFileId"] longLongValue], 1LL);
}

- (void)testInvoice_Int64FieldsAsStrings {
	NSDictionary *invoice = TGFlattenCommerceContent(@{
		@"@type" : @"messageInvoice",
		@"total_amount" : @"1234567890123",
		@"receipt_message_id" : @"5368324170671202286",
		@"product_info" : @{@"@type" : @"productInfo",
							@"photo" : tphoto(@[tsize(@"777", 10, 10)])},
	})[@"invoice"];
	XCTAssertEqual([invoice[@"totalAmount"] longLongValue], 1234567890123LL);
	XCTAssertEqual([invoice[@"receiptMessageId"] longLongValue], 5368324170671202286LL);
	XCTAssertEqual([invoice[@"photoFileId"] longLongValue], 777LL);
}

- (void)testInvoice_NullPaidMediaIsNoPaidMedia {
	NSDictionary *invoice = TGFlattenCommerceContent(@{
		@"@type" : @"messageInvoice",
		@"paid_media" : [NSNull null],
	})[@"invoice"];
	XCTAssertFalse([invoice[@"hasPaidMedia"] boolValue]);
}

#pragma mark - giveaway

- (void)testGiveaway_FullPremiumGiveaway {
	NSDictionary *content = @{
		@"@type" : @"messageGiveaway",
		@"winner_count" : @(10),
		@"parameters" : @{
			@"@type" : @"giveawayParameters",
			@"boosted_chat_id" : @(-1001234567890LL),
			@"additional_chat_ids" : @[@111, @222],
			@"winners_selection_date" : @(1700000000),
			@"only_new_members" : @YES,
			@"has_public_winners" : @YES,
			@"country_codes" : @[@"DE", @"FR"],
			@"prize_description" : @"For the fans",
		},
		@"prize" : @{@"@type" : @"giveawayPrizePremium", @"month_count" : @12},
		@"sticker" : tsticker(@99, @98),
	};

	NSDictionary *giveaway = TGFlattenCommerceContent(content)[@"giveaway"];
	XCTAssertEqual([giveaway[@"winnerCount"] longLongValue], 10LL);
	XCTAssertEqual([giveaway[@"winnersSelectionDate"] longLongValue], 1700000000LL);
	XCTAssertTrue([giveaway[@"onlyNewMembers"] boolValue]);
	XCTAssertTrue([giveaway[@"hasPublicWinners"] boolValue]);
	XCTAssertEqualObjects(giveaway[@"countryCodes"], (@[@"DE", @"FR"]));
	XCTAssertEqualObjects(giveaway[@"prizeDescription"], @"For the fans");
	XCTAssertEqual([giveaway[@"additionalChatIds"][0] longLongValue], 111LL);
	XCTAssertEqual([giveaway[@"additionalChatIds"][1] longLongValue], 222LL);
	XCTAssertEqual([giveaway[@"boostedChatId"] longLongValue], -1001234567890LL);
	XCTAssertEqual([giveaway[@"premiumMonths"] longLongValue], 12LL);
	XCTAssertEqual([giveaway[@"starCount"] longLongValue], 0LL);
	XCTAssertEqual([giveaway[@"stickerFileId"] longLongValue], 99LL);
}

- (void)testGiveaway_MinimalKeepsZeroValues {
	NSDictionary *giveaway = TGFlattenCommerceContent(@{@"@type" : @"messageGiveaway"})[@"giveaway"];
	XCTAssertEqual([giveaway[@"winnerCount"] longLongValue], 0LL);
	XCTAssertEqual([giveaway[@"winnersSelectionDate"] longLongValue], 0LL);
	XCTAssertFalse([giveaway[@"onlyNewMembers"] boolValue]);
	XCTAssertFalse([giveaway[@"hasPublicWinners"] boolValue]);
	XCTAssertEqualObjects(giveaway[@"countryCodes"], @[]);
	XCTAssertEqualObjects(giveaway[@"prizeDescription"], @"");
	XCTAssertEqualObjects(giveaway[@"additionalChatIds"], @[]);
	XCTAssertEqual([giveaway[@"boostedChatId"] longLongValue], 0LL);
	XCTAssertEqual([giveaway[@"premiumMonths"] longLongValue], 0LL);
	XCTAssertEqual([giveaway[@"starCount"] longLongValue], 0LL);
	XCTAssertEqual([giveaway[@"stickerFileId"] longLongValue], 0LL);
}

- (void)testGiveaway_Int64StringsInParameters {
	NSDictionary *giveaway = TGFlattenCommerceContent(@{
		@"@type" : @"messageGiveaway",
		@"parameters" : @{@"@type" : @"giveawayParameters",
						  @"boosted_chat_id" : @"-1001234567890",
						  @"additional_chat_ids" : @[@"111", @222]},
	})[@"giveaway"];
	XCTAssertEqual([giveaway[@"boostedChatId"] longLongValue], -1001234567890LL);
	XCTAssertEqual([giveaway[@"additionalChatIds"][0] longLongValue], 111LL);
	XCTAssertEqual([giveaway[@"additionalChatIds"][1] longLongValue], 222LL);
}

- (void)testGiveaway_StarsPrizeUsesStarCount {
	NSDictionary *giveaway = TGFlattenCommerceContent(@{
		@"@type" : @"messageGiveaway",
		@"prize" : @{@"@type" : @"giveawayPrizeStars", @"star_count" : @"5000"},
	})[@"giveaway"];
	XCTAssertEqual([giveaway[@"premiumMonths"] longLongValue], 0LL);
	XCTAssertEqual([giveaway[@"starCount"] longLongValue], 5000LL);
}

#pragma mark - giveaway winners

- (void)testGiveawayWinners_FullObject {
	NSDictionary *giveaway = TGFlattenCommerceContent(@{
		@"@type" : @"messageGiveawayWinners",
		@"boosted_chat_id" : @(-100777),
		@"giveaway_message_id" : @(55),
		@"additional_chat_count" : @(3),
		@"actual_winners_selection_date" : @(1700000100),
		@"only_new_members" : @YES,
		@"was_refunded" : @NO,
		@"prize" : @{@"@type" : @"giveawayPrizeStars", @"star_count" : @900},
		@"prize_description" : @"Five stars each",
		@"winner_count" : @(20),
		@"winner_user_ids" : @[@1, @2, @3],
		@"unclaimed_prize_count" : @(2),
	})[@"giveawayWinners"];

	XCTAssertEqual([giveaway[@"boostedChatId"] longLongValue], -100777LL);
	XCTAssertEqual([giveaway[@"giveawayMessageId"] longLongValue], 55LL);
	XCTAssertEqual([giveaway[@"actualWinnersSelectionDate"] longLongValue], 1700000100LL);
	XCTAssertEqual([giveaway[@"winnerCount"] longLongValue], 20LL);
	XCTAssertEqual([giveaway[@"unclaimedPrizeCount"] longLongValue], 2LL);
	XCTAssertEqual([giveaway[@"winnerUserIds"] count], (NSUInteger)3);
	XCTAssertEqual([giveaway[@"winnerUserIds"][2] longLongValue], 3LL);
	XCTAssertTrue([giveaway[@"onlyNewMembers"] boolValue]);
	XCTAssertFalse([giveaway[@"wasRefunded"] boolValue]);
	XCTAssertEqual([giveaway[@"premiumMonths"] longLongValue], 0LL);
	XCTAssertEqual([giveaway[@"starCount"] longLongValue], 900LL);
	XCTAssertEqualObjects(giveaway[@"prizeDescription"], @"Five stars each");
}

- (void)testGiveawayWinners_MinimalKeepsZeroValues {
	NSDictionary *giveaway = TGFlattenCommerceContent(
			@{@"@type" : @"messageGiveawayWinners"})[@"giveawayWinners"];
	XCTAssertEqual([giveaway[@"boostedChatId"] longLongValue], 0LL);
	XCTAssertEqual([giveaway[@"giveawayMessageId"] longLongValue], 0LL);
	XCTAssertEqual([giveaway[@"actualWinnersSelectionDate"] longLongValue], 0LL);
	XCTAssertEqual([giveaway[@"winnerCount"] longLongValue], 0LL);
	XCTAssertEqual([giveaway[@"unclaimedPrizeCount"] longLongValue], 0LL);
	XCTAssertEqualObjects(giveaway[@"winnerUserIds"], @[]);
	XCTAssertFalse([giveaway[@"onlyNewMembers"] boolValue]);
	XCTAssertFalse([giveaway[@"wasRefunded"] boolValue]);
	XCTAssertEqual([giveaway[@"premiumMonths"] longLongValue], 0LL);
	XCTAssertEqual([giveaway[@"starCount"] longLongValue], 0LL);
	XCTAssertEqualObjects(giveaway[@"prizeDescription"], @"");
}

- (void)testGiveawayWinners_Int64IdsAsStrings {
	NSDictionary *giveaway = TGFlattenCommerceContent(@{
		@"@type" : @"messageGiveawayWinners",
		@"boosted_chat_id" : @"-1001234567890",
		@"giveaway_message_id" : @"5368324170671202286",
		@"winner_user_ids" : @[@"7612345678", @"9876543210"],
	})[@"giveawayWinners"];
	XCTAssertEqual([giveaway[@"boostedChatId"] longLongValue], -1001234567890LL);
	XCTAssertEqual([giveaway[@"giveawayMessageId"] longLongValue], 5368324170671202286LL);
	XCTAssertEqual([giveaway[@"winnerUserIds"][0] longLongValue], 7612345678LL);
	XCTAssertEqual([giveaway[@"winnerUserIds"][1] longLongValue], 9876543210LL);
}

- (void)testGiveawayWinners_PremiumPrizeUsesMonthCount {
	NSDictionary *giveaway = TGFlattenCommerceContent(@{
		@"@type" : @"messageGiveawayWinners",
		@"prize" : @{@"@type" : @"giveawayPrizePremium", @"month_count" : @6},
	})[@"giveawayWinners"];
	XCTAssertEqual([giveaway[@"premiumMonths"] longLongValue], 6LL);
	XCTAssertEqual([giveaway[@"starCount"] longLongValue], 0LL);
}

#pragma mark - gift

- (void)testGift_FullObject {
	NSDictionary *gift = TGFlattenCommerceContent(@{
		@"@type" : @"messageGift",
		@"gift" : @{@"@type" : @"gift", @"id" : @(5368324170671202286LL),
					@"star_count" : @(500),
					@"sticker" : tsticker(@1001, @1002)},
		@"sender_id" : tuser(@111),
		@"receiver_id" : tuser(@222),
		@"text" : @{@"@type" : @"formattedText", @"text" : @"happy birthday"},
		@"sell_star_count" : @(250),
		@"is_private" : @YES,
		@"is_saved" : @YES,
		@"can_be_upgraded" : @YES,
		@"was_converted" : @NO,
		@"was_upgraded" : @YES,
	})[@"gift"];

	XCTAssertEqual([gift[@"giftId"] longLongValue], 5368324170671202286LL);
	XCTAssertEqual([gift[@"stickerFileId"] longLongValue], 1001LL);
	XCTAssertEqual([gift[@"stickerThumbFileId"] longLongValue], 1002LL);
	XCTAssertEqual([gift[@"starCount"] longLongValue], 500LL);
	XCTAssertEqualObjects(gift[@"text"], @"happy birthday");
	XCTAssertEqual([gift[@"senderUserId"] longLongValue], 111LL);
	XCTAssertEqual([gift[@"receiverUserId"] longLongValue], 222LL);
	XCTAssertTrue([gift[@"isPrivate"] boolValue]);
	XCTAssertTrue([gift[@"isSaved"] boolValue]);
	XCTAssertTrue([gift[@"canBeUpgraded"] boolValue]);
	XCTAssertFalse([gift[@"wasConverted"] boolValue]);
	XCTAssertTrue([gift[@"wasUpgraded"] boolValue]);
	XCTAssertEqual([gift[@"sellStarCount"] longLongValue], 250LL);
}

- (void)testGift_MinimalKeepsZeroValues {
	NSDictionary *gift = TGFlattenCommerceContent(@{@"@type" : @"messageGift"})[@"gift"];
	XCTAssertEqual([gift[@"giftId"] longLongValue], 0LL);
	XCTAssertEqual([gift[@"stickerFileId"] longLongValue], 0LL);
	XCTAssertEqual([gift[@"stickerThumbFileId"] longLongValue], 0LL);
	XCTAssertEqual([gift[@"starCount"] longLongValue], 0LL);
	XCTAssertEqualObjects(gift[@"text"], @"");
	XCTAssertEqual([gift[@"senderUserId"] longLongValue], 0LL);
	XCTAssertEqual([gift[@"receiverUserId"] longLongValue], 0LL);
	XCTAssertFalse([gift[@"isPrivate"] boolValue]);
	XCTAssertFalse([gift[@"isSaved"] boolValue]);
	XCTAssertFalse([gift[@"canBeUpgraded"] boolValue]);
	XCTAssertFalse([gift[@"wasConverted"] boolValue]);
	XCTAssertFalse([gift[@"wasUpgraded"] boolValue]);
	XCTAssertEqual([gift[@"sellStarCount"] longLongValue], 0LL);
}

- (void)testGift_Int64IdsAsStrings {
	NSDictionary *gift = TGFlattenCommerceContent(@{
		@"@type" : @"messageGift",
		@"gift" : @{@"@type" : @"gift", @"id" : @"5368324170671202286",
					@"sticker" : tsticker(@"1001", nil)},
		@"sender_id" : tuser(@"111"),
	})[@"gift"];
	XCTAssertEqual([gift[@"giftId"] longLongValue], 5368324170671202286LL);
	XCTAssertEqual([gift[@"stickerFileId"] longLongValue], 1001LL);
	XCTAssertEqual([gift[@"senderUserId"] longLongValue], 111LL);
	XCTAssertEqual([gift[@"stickerThumbFileId"] longLongValue], 0LL);
}

- (void)testGift_ChatSenderHasNoUserId {
	NSDictionary *gift = TGFlattenCommerceContent(@{
		@"@type" : @"messageGift",
		@"sender_id" : @{@"@type" : @"messageSenderChat", @"chat_id" : @(-100555)},
	})[@"gift"];
	XCTAssertEqual([gift[@"senderUserId"] longLongValue], 0LL);
}

#pragma mark - upgraded gift

- (void)testUpgradedGift_FullObject {
	NSDictionary *upgraded = TGFlattenCommerceContent(@{
		@"@type" : @"messageUpgradedGift",
		@"gift" : @{
			@"@type" : @"upgradedGift",
			@"id" : @(5368324170671202286LL),
			@"title" : @"Plush Pepe",
			@"number" : @(42),
			@"model" : @{@"@type" : @"upgradedGiftModel",
						 @"name" : @"Pepe",
						 @"sticker" : tsticker(@2001, nil)},
			@"symbol" : @{@"@type" : @"upgradedGiftSymbol", @"name" : @"Crown"},
			@"backdrop" : @{@"@type" : @"upgradedGiftBackdrop",
							@"name" : @"Midnight",
							@"colors" : @{@"@type" : @"upgradedGiftBackdropColors",
										  @"center_color" : @(0x112233),
										  @"edge_color" : @(0x445566)}},
		},
		@"sender_id" : tuser(@111),
		@"receiver_id" : tuser(@222),
		@"is_saved" : @YES,
		@"can_be_transferred" : @YES,
		@"was_transferred" : @NO,
	})[@"upgradedGift"];

	XCTAssertEqualObjects(upgraded[@"title"], @"Plush Pepe");
	XCTAssertEqual([upgraded[@"number"] longLongValue], 42LL);
	XCTAssertEqualObjects(upgraded[@"modelName"], @"Pepe");
	XCTAssertEqual([upgraded[@"modelStickerFileId"] longLongValue], 2001LL);
	XCTAssertEqualObjects(upgraded[@"symbolName"], @"Crown");
	XCTAssertEqualObjects(upgraded[@"backdropName"], @"Midnight");
	XCTAssertEqual([upgraded[@"backdropCenterColor"] longLongValue], 0x112233LL);
	XCTAssertEqual([upgraded[@"backdropEdgeColor"] longLongValue], 0x445566LL);
	XCTAssertEqual([upgraded[@"senderUserId"] longLongValue], 111LL);
	XCTAssertEqual([upgraded[@"receiverUserId"] longLongValue], 222LL);
	XCTAssertTrue([upgraded[@"isSaved"] boolValue]);
	XCTAssertTrue([upgraded[@"canBeTransferred"] boolValue]);
	XCTAssertFalse([upgraded[@"wasTransferred"] boolValue]);
}

- (void)testUpgradedGift_MinimalKeepsZeroValues {
	NSDictionary *upgraded = TGFlattenCommerceContent(
			@{@"@type" : @"messageUpgradedGift"})[@"upgradedGift"];
	XCTAssertEqualObjects(upgraded[@"title"], @"");
	XCTAssertEqual([upgraded[@"number"] longLongValue], 0LL);
	XCTAssertEqualObjects(upgraded[@"modelName"], @"");
	XCTAssertEqual([upgraded[@"modelStickerFileId"] longLongValue], 0LL);
	XCTAssertEqualObjects(upgraded[@"symbolName"], @"");
	XCTAssertEqualObjects(upgraded[@"backdropName"], @"");
	XCTAssertEqual([upgraded[@"backdropCenterColor"] longLongValue], 0LL);
	XCTAssertEqual([upgraded[@"backdropEdgeColor"] longLongValue], 0LL);
	XCTAssertEqual([upgraded[@"senderUserId"] longLongValue], 0LL);
	XCTAssertEqual([upgraded[@"receiverUserId"] longLongValue], 0LL);
	XCTAssertFalse([upgraded[@"isSaved"] boolValue]);
	XCTAssertFalse([upgraded[@"canBeTransferred"] boolValue]);
	XCTAssertFalse([upgraded[@"wasTransferred"] boolValue]);
}

- (void)testUpgradedGift_NumberAsString {
	NSDictionary *upgraded = TGFlattenCommerceContent(@{
		@"@type" : @"messageUpgradedGift",
		@"gift" : @{@"@type" : @"upgradedGift", @"title" : @"Durov's Cap",
					@"number" : @"777"},
	})[@"upgradedGift"];
	XCTAssertEqualObjects(upgraded[@"title"], @"Durov's Cap");
	XCTAssertEqual([upgraded[@"number"] longLongValue], 777LL);
}

- (void)testUpgradedGift_MissingAttributesStayEmpty {
	NSDictionary *upgraded = TGFlattenCommerceContent(@{
		@"@type" : @"messageUpgradedGift",
		@"gift" : @{@"@type" : @"upgradedGift", @"title" : @"Bare"},
	})[@"upgradedGift"];
	XCTAssertEqualObjects(upgraded[@"modelName"], @"");
	XCTAssertEqual([upgraded[@"modelStickerFileId"] longLongValue], 0LL);
	XCTAssertEqualObjects(upgraded[@"symbolName"], @"");
	XCTAssertEqualObjects(upgraded[@"backdropName"], @"");
	XCTAssertEqual([upgraded[@"backdropCenterColor"] longLongValue], 0LL);
}

#pragma mark - everything else

- (void)testNonCommerceContentReturnsNil {
	NSDictionary *content = @{@"@type" : @"messageText",
							  @"text" : @{@"@type" : @"formattedText", @"text" : @"hi"}};
	XCTAssertTrue(TGFlattenCommerceContent(content) == nil);
	XCTAssertTrue(TGFlattenCommerceContent(@{@"@type" : @"messagePhoto"}) == nil);
}

- (void)testEmptyOrNilContentReturnsNil {
	XCTAssertTrue(TGFlattenCommerceContent(nil) == nil);
	XCTAssertTrue(TGFlattenCommerceContent(@{}) == nil);
}

@end
