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

/// A picture saved by an earlier run is decoded straight from disk: the
/// launch-time getCustomEmojiStickers answer took 5.6 s on the 4S.
- (void)testImageForId_KnownPathSkipsTheServerBatch {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ces-known.webp"];
	[[NSData dataWithBytes:"x" length:1] writeToFile:file atomically:YES];
	store.knownPaths[@"4242"] = file;
	XCTAssertNil([store imageForId:4242LL side:20]);
	XCTAssertEqualObjects(store.paths[@(4242LL)], file);
	XCTAssertFalse([store.queued containsObject:@(4242LL)],
			@"no getCustomEmojiStickers for an emoji already on disk");
	[[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
}

/// A path that has gone (TDLib cleaned its files) falls back to the server.
- (void)testImageForId_MissingKnownFileAsksTheServer {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	store.knownPaths[@"4243"] = @"/nonexistent/ces.webp";
	XCTAssertNil([store imageForId:4243LL side:20]);
	XCTAssertTrue([store.queued containsObject:@(4243LL)]);
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

- (void)testReceiveStickers_RequestsThumbWithOnScreenPriority {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	TGClient *client = [TGClient shared];
	[client.outbox removeAllObjects];

	NSArray *stickers = @[
		cesRow(2001LL, 6001LL, @"tgs", 7001LL),
	];
	[store receiveStickers:stickers forIds:@[@(2001LL)]];

	NSDictionary *found = nil;
	for (NSData *d in client.outbox) {
		NSString *json = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
		NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
		NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
		if ([dict[@"@type"] isEqualToString:@"downloadFile"] && [dict[@"file_id"] isEqual:@(7001LL)]) {
			found = dict;
			break;
		}
	}
	XCTAssertNotNil(found, @"Thumbnail download request must be dispatched");
	XCTAssertEqual([found[@"priority"] integerValue], TGDownloadPriorityOnScreen,
				   @"Custom emoji thumbnail must download at OnScreen priority, not Avatar priority");
}

- (void)testDecodeFailure_ClearsWantedAndRecordsFailed {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	store.wanted[@(9999LL)] = [NSMutableSet setWithObject:@(20)];
	[store decodePath:@"/nonexistent/emoji.webp" forId:9999LL side:20];
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.5];
	while (![store.failed containsObject:@(9999LL)] && [deadline timeIntervalSinceNow] > 0) {
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	}
	XCTAssertNil(store.wanted[@(9999LL)], @"failed decode must be removed from wanted");
	XCTAssertTrue([store.failed containsObject:@(9999LL)], @"failed decode must be recorded in failed");
}

@end
