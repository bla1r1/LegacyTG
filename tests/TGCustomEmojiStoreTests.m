//
// TGCustomEmojiStoreTests.m - tests for animated custom emoji metadata in TGCustomEmojiStore.
//
#import "TGTestRunner.h"
#import "TGCustomEmojiStore.h"
#import "TGCustomEmojiStore.m"

@interface TGCustomEmojiStoreTests : XCTestCase @end

static NSDictionary *cesRow(int64_t emojiId, int64_t fileId, NSString *format, int64_t thumbId) {
	return @{
		@"customEmojiId" : @(emojiId),
		@"fileId"        : @(fileId),
		@"format"        : format ?: @"",
		@"thumbId"       : @(thumbId),
	};
}

@implementation TGCustomEmojiStoreTests

- (void)setUp {
	[super setUp];
	[[TGCustomEmojiStore shared] reset];
}

- (void)tearDown {
	[[TGCustomEmojiStore shared] reset];
	[super tearDown];
}

- (void)testAnimationForId_UnknownIdReturnsNil {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	NSDictionary *anim = [store animationForId:987654321LL];
	XCTAssertTrue(anim == nil);
}

- (void)testAnimationForId_ZeroReturnsNil {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	NSDictionary *anim = [store animationForId:0];
	XCTAssertTrue(anim == nil);
}

- (void)testAnimationForId_TgsFormatReturnsFileIdAndFormat {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	NSArray *stickers = @[
		cesRow(1001LL, 5001LL, @"stickerFormatTgs", 0),
	];
	[store receiveStickers:stickers forIds:@[@(1001LL)]];

	NSDictionary *anim = [store animationForId:1001LL];
	XCTAssertTrue(anim != nil);
	XCTAssertEqualObjects(anim[@"fileId"], @(5001LL));
	XCTAssertEqualObjects(anim[@"format"], @"tgs");
}

- (void)testAnimationForId_WebmFormatReturnsFileIdAndFormat {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	NSArray *stickers = @[
		cesRow(1002LL, 5002LL, @"webm", 0),
	];
	[store receiveStickers:stickers forIds:@[@(1002LL)]];

	NSDictionary *anim = [store animationForId:1002LL];
	XCTAssertTrue(anim != nil);
	XCTAssertEqualObjects(anim[@"fileId"], @(5002LL));
	XCTAssertEqualObjects(anim[@"format"], @"webm");
}

- (void)testAnimationForId_WebpFormatReturnsNil {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	NSArray *stickers = @[
		cesRow(1003LL, 5003LL, @"stickerFormatWebp", 0),
	];
	[store receiveStickers:stickers forIds:@[@(1003LL)]];

	NSDictionary *anim = [store animationForId:1003LL];
	XCTAssertTrue(anim == nil);
}

- (void)testAnimationForId_ResetClearsAnimations {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	NSArray *stickers = @[
		cesRow(1004LL, 5004LL, @"tgs", 0),
	];
	[store receiveStickers:stickers forIds:@[@(1004LL)]];
	XCTAssertTrue([store animationForId:1004LL] != nil);

	[store reset];
	XCTAssertTrue([store animationForId:1004LL] == nil);
}

- (void)testAnimationForId_HandlesRawTdlibStickerShape {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	NSDictionary *rawSticker = @{
		@"full_type" : @{
			@"@type" : @"stickerFullTypeCustomEmoji",
			@"custom_emoji_id" : @"1005",
		},
		@"sticker" : @{
			@"id" : @(5005LL),
		},
		@"format" : @{
			@"@type" : @"stickerFormatTgs",
		},
	};
	[store receiveStickers:@[rawSticker] forIds:@[@(1005LL)]];

	NSDictionary *anim = [store animationForId:1005LL];
	XCTAssertTrue(anim != nil);
	XCTAssertEqualObjects(anim[@"fileId"], @(5005LL));
	XCTAssertEqualObjects(anim[@"format"], @"tgs");
}

- (void)testReceiveStickers_PostsLoadedNotificationForAnimationWithoutThumb {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	__block BOOL notified = NO;
	id observer = [[NSNotificationCenter defaultCenter]
			addObserverForName:TGCustomEmojiLoadedNotification
						object:store
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
		if ([note.userInfo[@"id"] isEqual:@(1006LL)]) {
			notified = YES;
		}
	}];

	NSArray *stickers = @[
		cesRow(1006LL, 5006LL, @"tgs", 0),
	];
	[store receiveStickers:stickers forIds:@[@(1006LL)]];

	[[NSNotificationCenter defaultCenter] removeObserver:observer];
	XCTAssertTrue(notified);
}

@end
