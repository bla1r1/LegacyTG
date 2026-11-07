//
// TGGiftFlattenTests.m - test gift dictionary flattening down to row and viewer fields.
//
#import "TGTestRunner.h"
#import "TGGiftFlatten.h"

@interface TGGiftFlattenTests : XCTestCase @end

static NSDictionary *gfRegularSticker(NSString *thumbFormat, NSNumber *thumbFileId,
									  NSString *stickerFormat, NSNumber *stickerFileId,
									  NSString *emoji) {
	NSMutableDictionary *thumb = nil;
	if (thumbFormat && thumbFileId) {
		thumb = [NSMutableDictionary dictionaryWithDictionary:@{
			@"format" : @{@"@type" : thumbFormat},
			@"file"   : @{@"id" : thumbFileId},
		}];
	}
	NSMutableDictionary *stk = [NSMutableDictionary dictionaryWithDictionary:@{
		@"format"  : @{@"@type" : stickerFormat ?: @"stickerFormatWebp"},
		@"sticker" : @{@"id" : stickerFileId ?: @(0)},
		@"emoji"   : emoji ?: @"",
	}];
	if (thumb)
		stk[@"thumbnail"] = thumb;
	return stk;
}

static NSDictionary *gfSampleRegular(void) {
	return @{
		@"@type"            : @"receivedGift",
		@"received_gift_id" : @"rg_100",
		@"sender_id"        : @{@"@type" : @"messageSenderUser", @"user_id" : @(12345)},
		@"text"             : @{@"@type" : @"formattedText", @"text" : @"Happy Birthday!"},
		@"date"             : @(1700000000),
		@"is_private"       : @YES,
		@"is_saved"         : @YES,
		@"is_pinned"        : @NO,
		@"can_be_upgraded"  : @YES,
		@"can_be_transferred": @NO,
		@"was_refunded"     : @NO,
		@"sell_star_count"  : @(25),
		@"gift"             : @{
			@"@type" : @"sentGiftRegular",
			@"gift"  : @{
				@"@type"      : @"gift",
				@"id"         : @(999),
				@"star_count" : @(50),
				@"sticker"    : gfRegularSticker(@"thumbnailFormatJpeg", @(101),
												 @"stickerFormatWebp", @(202), @"🎂"),
			},
		},
	};
}

static NSDictionary *gfSampleCollectible(void) {
	return @{
		@"@type"            : @"receivedGift",
		@"received_gift_id" : @"rg_col_200",
		@"sender_id"        : @{@"@type" : @"messageSenderChat", @"chat_id" : @(-100123)},
		@"text"             : @{@"@type" : @"formattedText", @"text" : @"Rare item for you"},
		@"date"             : @(1700005000),
		@"is_private"       : @NO,
		@"is_saved"         : @YES,
		@"is_pinned"        : @YES,
		@"can_be_upgraded"  : @NO,
		@"can_be_transferred": @YES,
		@"was_refunded"     : @NO,
		@"sell_star_count"  : @(500),
		@"gift"             : @{
			@"@type" : @"sentGiftUpgraded",
			@"gift"  : @{
				@"@type"   : @"upgradedGift",
				@"id"      : @(888),
				@"title"   : @"Spooky Pumpkin",
				@"number"  : @(42),
				@"model"   : @{
					@"name"    : @"Jack-o-Lantern",
					@"sticker" : gfRegularSticker(@"thumbnailFormatPng", @(303),
												  @"stickerFormatWebp", @(404), @"🎃"),
				},
				@"symbol"  : @{
					@"name" : @"Ghost",
				},
				@"backdrop": @{
					@"name"   : @"Haunted Sunset",
					@"colors" : @{
						@"center_color" : @(0xFFAA00),
						@"edge_color"   : @(0x330066),
						@"symbol_color" : @(0xFFFFFF),
						@"text_color"   : @(0xFFEEDD),
					},
				},
			},
		},
	};
}

@implementation TGGiftFlattenTests

- (void)testFlatten_NilReturnsNil {
	NSDictionary *d = TGFlattenReceivedGift(nil);
	XCTAssertTrue(d == nil);
}

- (void)testFlatten_NonDictReturnsNil {
	NSDictionary *d = TGFlattenReceivedGift((id)@"not a dict");
	XCTAssertTrue(d == nil);
}

- (void)testFlatten_EmptyDictDefaultsCleanly {
	NSDictionary *d = TGFlattenReceivedGift(@{});
	XCTAssertTrue(d != nil);
	XCTAssertEqualObjects(d[@"receivedGiftId"], @"");
	XCTAssertEqualObjects(d[@"senderUserId"], @(0));
	XCTAssertEqualObjects(d[@"senderChatId"], @(0));
	XCTAssertEqualObjects(d[@"date"], @(0));
	XCTAssertEqualObjects(d[@"note"], @"");
	XCTAssertFalse([d[@"isPrivate"] boolValue]);
	XCTAssertFalse([d[@"isSaved"] boolValue]);
	XCTAssertFalse([d[@"isPinned"] boolValue]);
	XCTAssertFalse([d[@"canBeUpgraded"] boolValue]);
	XCTAssertFalse([d[@"canBeTransferred"] boolValue]);
	XCTAssertFalse([d[@"wasRefunded"] boolValue]);
	XCTAssertEqualObjects(d[@"sellStarCount"], @(0));
	XCTAssertFalse([d[@"isCollectible"] boolValue]);
}

- (void)testFlatten_RegularGiftCommonFields {
	NSDictionary *d = TGFlattenReceivedGift(gfSampleRegular());
	XCTAssertTrue(d != nil);
	XCTAssertEqualObjects(d[@"receivedGiftId"], @"rg_100");
	XCTAssertEqualObjects(d[@"senderUserId"], @(12345));
	XCTAssertEqualObjects(d[@"senderChatId"], @(0));
	XCTAssertEqualObjects(d[@"date"], @(1700000000));
	XCTAssertEqualObjects(d[@"note"], @"Happy Birthday!");
	XCTAssertTrue([d[@"isPrivate"] boolValue]);
	XCTAssertTrue([d[@"isSaved"] boolValue]);
	XCTAssertFalse([d[@"isPinned"] boolValue]);
	XCTAssertTrue([d[@"canBeUpgraded"] boolValue]);
	XCTAssertFalse([d[@"canBeTransferred"] boolValue]);
	XCTAssertFalse([d[@"wasRefunded"] boolValue]);
	XCTAssertEqualObjects(d[@"sellStarCount"], @(25));
	XCTAssertFalse([d[@"isCollectible"] boolValue]);
}

- (void)testFlatten_RegularGiftSpecificFields {
	NSDictionary *d = TGFlattenReceivedGift(gfSampleRegular());
	XCTAssertEqualObjects(d[@"giftId"], @(999));
	XCTAssertEqualObjects(d[@"starCount"], @(50));
	XCTAssertEqualObjects(d[@"emoji"], @"🎂");
	XCTAssertEqualObjects(d[@"thumbFileId"], @(101));
	XCTAssertEqualObjects(d[@"stickerFileId"], @(202));
	XCTAssertEqualObjects(d[@"stickerFormat"], @"webp");
}

- (void)testFlatten_CollectibleGiftCommonFields {
	NSDictionary *d = TGFlattenReceivedGift(gfSampleCollectible());
	XCTAssertTrue(d != nil);
	XCTAssertEqualObjects(d[@"receivedGiftId"], @"rg_col_200");
	XCTAssertEqualObjects(d[@"senderUserId"], @(0));
	XCTAssertEqualObjects(d[@"senderChatId"], @(-100123));
	XCTAssertEqualObjects(d[@"date"], @(1700005000));
	XCTAssertEqualObjects(d[@"note"], @"Rare item for you");
	XCTAssertFalse([d[@"isPrivate"] boolValue]);
	XCTAssertTrue([d[@"isSaved"] boolValue]);
	XCTAssertTrue([d[@"isPinned"] boolValue]);
	XCTAssertFalse([d[@"canBeUpgraded"] boolValue]);
	XCTAssertTrue([d[@"canBeTransferred"] boolValue]);
	XCTAssertFalse([d[@"wasRefunded"] boolValue]);
	XCTAssertEqualObjects(d[@"sellStarCount"], @(500));
	XCTAssertTrue([d[@"isCollectible"] boolValue]);
}

- (void)testFlatten_CollectibleGiftSpecificFields {
	NSDictionary *d = TGFlattenReceivedGift(gfSampleCollectible());
	XCTAssertEqualObjects(d[@"title"], @"Spooky Pumpkin");
	XCTAssertEqualObjects(d[@"number"], @(42));
	XCTAssertEqualObjects(d[@"modelName"], @"Jack-o-Lantern");
	XCTAssertEqualObjects(d[@"modelThumbFileId"], @(303));
	XCTAssertEqualObjects(d[@"modelStickerFileId"], @(404));
	XCTAssertEqualObjects(d[@"modelStickerFormat"], @"webp");
	XCTAssertEqualObjects(d[@"symbolName"], @"Ghost");
	XCTAssertEqualObjects(d[@"backdropName"], @"Haunted Sunset");
	XCTAssertEqualObjects(d[@"backdropCenterColor"], @(0xFFAA00));
	XCTAssertEqualObjects(d[@"backdropEdgeColor"], @(0x330066));
	XCTAssertEqualObjects(d[@"backdropTextColor"], @(0xFFEEDD));
}

- (void)testFlatten_RegularGiftStickerFormats {
	NSDictionary *inTgs = @{
		@"gift" : @{
			@"gift" : @{
				@"sticker" : gfRegularSticker(nil, nil, @"stickerFormatTgs", @(201), @""),
			},
		},
	};
	NSDictionary *dTgs = TGFlattenReceivedGift(inTgs);
	XCTAssertEqualObjects(dTgs[@"stickerFileId"], @(201));
	XCTAssertEqualObjects(dTgs[@"stickerFormat"], @"tgs");

	NSDictionary *inWebm = @{
		@"gift" : @{
			@"gift" : @{
				@"sticker" : gfRegularSticker(nil, nil, @"stickerFormatWebm", @(202), @""),
			},
		},
	};
	NSDictionary *dWebm = TGFlattenReceivedGift(inWebm);
	XCTAssertEqualObjects(dWebm[@"stickerFileId"], @(202));
	XCTAssertEqualObjects(dWebm[@"stickerFormat"], @"webm");
}

- (void)testFlatten_CollectibleGiftModelStickerFormats {
	NSDictionary *inTgs = @{
		@"gift" : @{
			@"@type" : @"sentGiftUpgraded",
			@"gift"  : @{
				@"@type" : @"upgradedGift",
				@"model" : @{
					@"sticker" : gfRegularSticker(nil, nil, @"stickerFormatTgs", @(301), @""),
				},
			},
		},
	};
	NSDictionary *dTgs = TGFlattenReceivedGift(inTgs);
	XCTAssertEqualObjects(dTgs[@"modelStickerFileId"], @(301));
	XCTAssertEqualObjects(dTgs[@"modelStickerFormat"], @"tgs");

	NSDictionary *inWebm = @{
		@"gift" : @{
			@"@type" : @"sentGiftUpgraded",
			@"gift"  : @{
				@"@type" : @"upgradedGift",
				@"model" : @{
					@"sticker" : gfRegularSticker(nil, nil, @"stickerFormatWebm", @(302), @""),
				},
			},
		},
	};
	NSDictionary *dWebm = TGFlattenReceivedGift(inWebm);
	XCTAssertEqualObjects(dWebm[@"modelStickerFileId"], @(302));
	XCTAssertEqualObjects(dWebm[@"modelStickerFormat"], @"webm");
}

- (void)testFlatten_NoteFromFormattedText {
	NSDictionary *in = @{
		@"text" : @{@"@type" : @"formattedText", @"text" : @"Hello from note"},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"note"], @"Hello from note");
	XCTAssertEqualObjects(d[@"message"], @"Hello from note");
}

- (void)testFlatten_NoteDirectStringFallback {
	NSDictionary *in = @{@"text" : @"Direct note string"};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"note"], @"Direct note string");
}

- (void)testFlatten_NoteLegacyMessageFallback {
	NSDictionary *in = @{
		@"message" : @{@"text" : @"Old message format"},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"note"], @"Old message format");
}

- (void)testFlatten_NoteMissingLeavesEmptyStringAndNoMessageAlias {
	NSDictionary *d = TGFlattenReceivedGift(@{});
	XCTAssertEqualObjects(d[@"note"], @"");
	XCTAssertTrue(d[@"message"] == nil);
}

- (void)testFlatten_NSNullReceivedGiftId {
	NSDictionary *in = @{@"received_gift_id" : [NSNull null]};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"receivedGiftId"], @"");
}

- (void)testFlatten_NumericReceivedGiftIdConvertedToString {
	NSDictionary *in = @{@"received_gift_id" : @(123456)};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"receivedGiftId"], @"123456");
}

- (void)testFlatten_NSNullSenderId {
	NSDictionary *in = @{@"sender_id" : [NSNull null]};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"senderUserId"], @(0));
	XCTAssertEqualObjects(d[@"senderChatId"], @(0));
}

- (void)testFlatten_StringSenderUserId {
	NSDictionary *in = @{
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @"9876543210"},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"senderUserId"], @(9876543210LL));
}

- (void)testFlatten_StringSenderChatId {
	NSDictionary *in = @{
		@"sender_id" : @{@"@type" : @"messageSenderChat", @"chat_id" : @"-1009876543210"},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"senderChatId"], @(-1009876543210LL));
}

- (void)testFlatten_NSNullDateHandled {
	NSDictionary *in = @{@"date" : [NSNull null]};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"date"], @(0));
}

- (void)testFlatten_StringDateParsed {
	NSDictionary *in = @{@"date" : @"1700123456"};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"date"], @(1700123456));
}

- (void)testFlatten_NSNullBooleansDefaultFalse {
	NSDictionary *in = @{
		@"is_private"        : [NSNull null],
		@"is_saved"          : [NSNull null],
		@"is_pinned"         : [NSNull null],
		@"can_be_upgraded"   : [NSNull null],
		@"can_be_transferred": [NSNull null],
		@"was_refunded"      : [NSNull null],
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertFalse([d[@"isPrivate"] boolValue]);
	XCTAssertFalse([d[@"isSaved"] boolValue]);
	XCTAssertFalse([d[@"isPinned"] boolValue]);
	XCTAssertFalse([d[@"canBeUpgraded"] boolValue]);
	XCTAssertFalse([d[@"canBeTransferred"] boolValue]);
	XCTAssertFalse([d[@"wasRefunded"] boolValue]);
}

- (void)testFlatten_NSNullSellStarCount {
	NSDictionary *in = @{@"sell_star_count" : [NSNull null]};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"sellStarCount"], @(0));
}

- (void)testFlatten_StringSellStarCount {
	NSDictionary *in = @{@"sell_star_count" : @"750"};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"sellStarCount"], @(750));
}

- (void)testFlatten_MissingThumbnailWebpStickerFallsBackToStickerFileId {
	NSDictionary *in = @{
		@"gift" : @{
			@"@type" : @"sentGiftRegular",
			@"gift"  : @{
				@"sticker" : gfRegularSticker(nil, nil, @"stickerFormatWebp", @(555), @"⭐"),
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"thumbFileId"], @(555));
	XCTAssertEqualObjects(d[@"stickerFileId"], @(555));
}

- (void)testFlatten_MissingThumbnailTgsStickerYieldsNoPictureId {
	NSDictionary *in = @{
		@"gift" : @{
			@"@type" : @"sentGiftRegular",
			@"gift"  : @{
				@"sticker" : gfRegularSticker(nil, nil, @"stickerFormatTgs", @(666), @"🚀"),
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertTrue(d[@"thumbFileId"] == nil);
	XCTAssertEqualObjects(d[@"stickerFileId"], @(666));
}

- (void)testFlatten_MissingThumbnailWebmStickerYieldsNoPictureId {
	NSDictionary *in = @{
		@"gift" : @{
			@"@type" : @"sentGiftRegular",
			@"gift"  : @{
				@"sticker" : gfRegularSticker(nil, nil, @"stickerFormatWebm", @(777), @"🎉"),
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertTrue(d[@"thumbFileId"] == nil);
	XCTAssertEqualObjects(d[@"stickerFileId"], @(777));
}

- (void)testFlatten_JpegThumbnailYieldsPictureId {
	NSDictionary *in = @{
		@"gift" : @{
			@"gift" : @{
				@"sticker" : gfRegularSticker(@"thumbnailFormatJpeg", @(111),
											  @"stickerFormatTgs", @(222), @""),
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"thumbFileId"], @(111));
	XCTAssertEqualObjects(d[@"stickerFileId"], @(222));
}

- (void)testFlatten_PngThumbnailYieldsPictureId {
	NSDictionary *in = @{
		@"gift" : @{
			@"gift" : @{
				@"sticker" : gfRegularSticker(@"thumbnailFormatPng", @(112),
											  @"stickerFormatTgs", @(223), @""),
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"thumbFileId"], @(112));
}

- (void)testFlatten_WebpThumbnailYieldsPictureId {
	NSDictionary *in = @{
		@"gift" : @{
			@"gift" : @{
				@"sticker" : gfRegularSticker(@"thumbnailFormatWebp", @(113),
											  @"stickerFormatTgs", @(224), @""),
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"thumbFileId"], @(113));
}

- (void)testFlatten_TgsThumbnailIgnoredForPictureIdAndFallsBackToWebpSticker {
	NSDictionary *in = @{
		@"gift" : @{
			@"gift" : @{
				@"sticker" : gfRegularSticker(@"thumbnailFormatTgs", @(114),
											  @"stickerFormatWebp", @(333), @""),
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"thumbFileId"], @(333));
}

- (void)testFlatten_TgsThumbnailWithTgsStickerYieldsNoPictureId {
	NSDictionary *in = @{
		@"gift" : @{
			@"gift" : @{
				@"sticker" : gfRegularSticker(@"thumbnailFormatTgs", @(114),
											  @"stickerFormatTgs", @(333), @""),
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertTrue(d[@"thumbFileId"] == nil);
}

- (void)testFlatten_CollectibleMissingModelThumbnailWebpFallsBackToSticker {
	NSDictionary *in = @{
		@"gift" : @{
			@"@type" : @"sentGiftUpgraded",
			@"gift"  : @{
				@"@type"  : @"upgradedGift",
				@"number" : @(1),
				@"model"  : @{
					@"sticker" : gfRegularSticker(nil, nil, @"stickerFormatWebp", @(888), @""),
				},
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertTrue([d[@"isCollectible"] boolValue]);
	XCTAssertEqualObjects(d[@"modelThumbFileId"], @(888));
}

- (void)testFlatten_CollectibleTgsModelStickerYieldsNoPictureId {
	NSDictionary *in = @{
		@"gift" : @{
			@"@type" : @"sentGiftUpgraded",
			@"gift"  : @{
				@"@type"  : @"upgradedGift",
				@"model"  : @{
					@"sticker" : gfRegularSticker(nil, nil, @"stickerFormatTgs", @(999), @""),
				},
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertTrue(d[@"modelThumbFileId"] == nil);
}

- (void)testFlatten_CollectibleStringNumberHandled {
	NSDictionary *in = @{
		@"gift" : @{
			@"@type" : @"sentGiftUpgraded",
			@"gift"  : @{
				@"number" : @"77",
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"number"], @(77));
}

- (void)testFlatten_CollectibleNumberFromUniqueGiftNumberFallback {
	NSDictionary *in = @{
		@"unique_gift_number" : @(99),
		@"gift" : @{
			@"@type" : @"sentGiftUpgraded",
			@"gift"  : @{
				@"title" : @"Diamond Ring",
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"number"], @(99));
}

- (void)testFlatten_CollectibleNSNullBackdropAndColors {
	NSDictionary *in = @{
		@"gift" : @{
			@"@type" : @"sentGiftUpgraded",
			@"gift"  : @{
				@"backdrop" : [NSNull null],
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"backdropName"], @"");
	XCTAssertTrue(d[@"backdropCenterColor"] == nil);
	XCTAssertTrue(d[@"backdropEdgeColor"] == nil);
	XCTAssertTrue(d[@"backdropTextColor"] == nil);
}

- (void)testFlatten_CollectibleStringBackdropColors {
	NSDictionary *in = @{
		@"gift" : @{
			@"@type" : @"sentGiftUpgraded",
			@"gift"  : @{
				@"backdrop" : @{
					@"colors" : @{
						@"center_color" : @"16711680", // 0xFF0000
						@"edge_color"   : @"65280",    // 0x00FF00
						@"text_color"   : @"255",      // 0x0000FF
					},
				},
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"backdropCenterColor"], @(16711680));
	XCTAssertEqualObjects(d[@"backdropEdgeColor"], @(65280));
	XCTAssertEqualObjects(d[@"backdropTextColor"], @(255));
}

- (void)testFlatten_RegularGiftStringIdAndStarCount {
	NSDictionary *in = @{
		@"gift" : @{
			@"gift" : @{
				@"id"         : @"1234567890",
				@"star_count" : @"999",
			},
		},
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertEqualObjects(d[@"giftId"], @(1234567890LL));
	XCTAssertEqualObjects(d[@"starCount"], @(999LL));
}

- (void)testFlatten_NSNullGiftHandled {
	NSDictionary *in = @{
		@"received_gift_id" : @"rg_null",
		@"gift"             : [NSNull null],
	};
	NSDictionary *d = TGFlattenReceivedGift(in);
	XCTAssertFalse([d[@"isCollectible"] boolValue]);
	XCTAssertEqualObjects(d[@"giftId"], @(0));
	XCTAssertEqualObjects(d[@"starCount"], @(0));
	XCTAssertEqualObjects(d[@"emoji"], @"");
}

@end
