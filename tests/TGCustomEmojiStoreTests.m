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

/// The first use is inside a chat's first scroll: the saved paths are read
/// off the main thread and arrive a moment later, not inside the call.
- (void)testSavedPaths_LoadOffTheCallingThread {
	NSString *file = TGCustomEmojiPathsFile();
	NSData *before = [NSData dataWithContentsOfFile:file];
	[@{ @"7171" : @"/tmp/ces-7171.webp" } writeToFile:file atomically:YES];
	TGCustomEmojiStore *store = [[TGCustomEmojiStore alloc] init];
	XCTAssertNil(store.knownPaths[@"7171"], @"plist parsed inside init");
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
	while (!store.knownPaths[@"7171"] && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	XCTAssertEqualObjects(store.knownPaths[@"7171"], @"/tmp/ces-7171.webp");
	if (before)
		[before writeToFile:file atomically:YES];
	else
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
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
	while (!notified && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

	[[NSNotificationCenter defaultCenter] removeObserver:observer];
	XCTAssertTrue(notified);
}

/// A row redrawn while the answer is on the way must not ask again: on the
/// iPod touch 4 one chat sent the same ids three times, and every answer
/// downloaded, decoded and redrew the screen.
- (void)testIdInFlight_IsNotAskedTwice {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	[store reset];
	TGClient *client = [TGClient shared];
	[client.outbox removeAllObjects];
	SEL sendBatch = NSSelectorFromString(@"sendBatch");

	[store animationForId:3001LL];
	[store imageForId:3001LL side:17];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[store performSelector:sendBatch];
	// The same row, drawn again before TDLib has answered.
	[store animationForId:3001LL];
	[store imageForId:3001LL side:17];
	[store imageForId:3001LL side:20];
	[store performSelector:sendBatch];
#pragma clang diagnostic pop

	NSUInteger asks = 0;
	for (NSData *d in client.outbox) {
		NSString *json = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
		if ([json rangeOfString:@"getCustomEmojiStickers"].location != NSNotFound)
			asks++;
	}
	XCTAssertEqual(asks, (NSUInteger)1);
	[NSObject cancelPreviousPerformRequestsWithTarget:store];
	[store reset];
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

/// A picture an earlier run saved is read off the main thread: answered
/// synchronously, the PNG read and decode cost 4% of a chat's first scroll.
- (void)testSavedPicture_ArrivesLaterNotInTheCall {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	NSString *file = TGCustomEmojiPngThumbnailPath(5151LL, 20);
	[[NSFileManager defaultManager] createDirectoryAtPath:[file stringByDeletingLastPathComponent]
			withIntermediateDirectories:YES attributes:nil error:NULL];
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:2 pixelsHigh:2
			bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
			colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
	[[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:file atomically:YES];

	XCTAssertNil([store imageForId:5151LL side:20]);
	XCTAssertFalse([store.queued containsObject:@(5151LL)], @"no server ask for a saved picture");
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
	while (!store.pictures[TGPictureKey(5151LL, 20)] && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	XCTAssertNotNil(store.pictures[TGPictureKey(5151LL, 20)]);
	XCTAssertNotNil([store imageForId:5151LL side:20]);
	[[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
}

/// TDLib's answer for an emoji whose saved picture is still decoding does
/// not decode the source file again for the same size.
- (void)testSavedPictureDecoding_IsNotDecodedAgainFromTheSource {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	NSString *file = TGCustomEmojiPngThumbnailPath(5252LL, 20);
	[[NSFileManager defaultManager] createDirectoryAtPath:[file stringByDeletingLastPathComponent]
			withIntermediateDirectories:YES attributes:nil error:NULL];
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:2 pixelsHigh:2
			bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
			colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
	[[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:file atomically:YES];
	// Not a picture: decoding it would mark the emoji failed.
	NSString *source = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ces-5252.webp"];
	[[NSData dataWithBytes:"x" length:1] writeToFile:source atomically:YES];

	XCTAssertNil([store imageForId:5252LL side:20]);
	// The same picture measured a fraction larger elsewhere in the text.
	XCTAssertNil([store imageForId:5252LL side:20.3f]);
	[store receivePath:source forId:5252LL];
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
	while (!store.pictures[TGPictureKey(5252LL, 20)] && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	// TDLib answers again (another batch) after the picture landed.
	[store receivePath:source forId:5252LL];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	XCTAssertNotNil(store.pictures[TGPictureKey(5252LL, 20)]);
	XCTAssertFalse([store.failed containsObject:@(5252LL)], @"the source was decoded a second time");
	[NSObject cancelPreviousPerformRequestsWithTarget:store];
	[[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
	[[NSFileManager defaultManager] removeItemAtPath:source error:NULL];
}

/// Decodes asked while the table moves wait for it to stand still.
- (void)testHeldDecodes_LandAfterRelease {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	NSString *file = TGCustomEmojiPngThumbnailPath(5555LL, 20);
	[[NSFileManager defaultManager] createDirectoryAtPath:[file stringByDeletingLastPathComponent]
			withIntermediateDirectories:YES attributes:nil error:NULL];
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:2 pixelsHigh:2
			bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
			colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
	[[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:file atomically:YES];
	[store setDecodesHeld:YES];
	XCTAssertNil([store imageForId:5555LL side:20]);
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	XCTAssertNil(store.pictures[TGPictureKey(5555LL, 20)]);
	[store setDecodesHeld:NO];
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
	while (!store.pictures[TGPictureKey(5555LL, 20)] && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	XCTAssertNotNil(store.pictures[TGPictureKey(5555LL, 20)]);
	[[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
}

/// A picture saved raw comes back with the same pixels and no decoder.
- (void)testSavedBitmap_RoundTripsThePixels {
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, 3, 2, 8, 0, space, TGBitmapInfo());
	CGContextSetRGBFillColor(ctx, 1, 0, 0, 0.5);
	CGContextFillRect(ctx, CGRectMake(0, 0, 2, 2));
	CGImageRef image = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
	NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ces-rt.bgra"];
	XCTAssertTrue(TGBitmapWrite(image, file));
	CGImageRef back = TGBitmapCreate(file);
	XCTAssertTrue(back != NULL);
	XCTAssertEqual(CGImageGetWidth(back), (size_t)3);
	XCTAssertEqual(CGImageGetHeight(back), (size_t)2);
	uint32_t a[6] = {0}, b[6] = {0};
	CGContextRef ca = CGBitmapContextCreate(a, 3, 2, 8, 12, space, TGBitmapInfo());
	CGContextRef cb = CGBitmapContextCreate(b, 3, 2, 8, 12, space, TGBitmapInfo());
	CGContextDrawImage(ca, CGRectMake(0, 0, 3, 2), image);
	CGContextDrawImage(cb, CGRectMake(0, 0, 3, 2), back);
	XCTAssertEqual(memcmp(a, b, sizeof(a)), 0);
	XCTAssertTrue(TGBitmapCreate(@"/nonexistent/x.bgra") == NULL);
	[[NSData dataWithBytes:"not a bitmap at all" length:19] writeToFile:file atomically:YES];
	XCTAssertTrue(TGBitmapCreate(file) == NULL);
	CGContextRelease(ca);
	CGContextRelease(cb);
	CGImageRelease(back);
	CGImageRelease(image);
	CGColorSpaceRelease(space);
	[[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
}

/// A raw picture saved at this size is what imageForId reads.
- (void)testSavedBitmap_ArrivesWithoutTheServer {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	NSString *file = TGCustomEmojiThumbnailPath(5353LL, 20);
	XCTAssertEqualObjects(file.pathExtension, @"bgra");
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, 4, 4, 8, 0, space, TGBitmapInfo());
	CGImageRef image = CGBitmapContextCreateImage(ctx);
	XCTAssertTrue(TGBitmapWrite(image, file));
	CGImageRelease(image);
	CGContextRelease(ctx);
	CGColorSpaceRelease(space);
	XCTAssertNil([store imageForId:5353LL side:20]);
	XCTAssertFalse([store.queued containsObject:@(5353LL)]);
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
	while (!store.pictures[TGPictureKey(5353LL, 20)] && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	XCTAssertNotNil(store.pictures[TGPictureKey(5353LL, 20)]);
	[[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
}

/// A burst of pictures is one notification, not one per picture.
- (void)testLoadedBurst_IsOneNotification {
	TGCustomEmojiStore *store = [TGCustomEmojiStore shared];
	__block NSUInteger posts = 0;
	__block NSSet *ids = nil;
	id observer = [[NSNotificationCenter defaultCenter] addObserverForName:TGCustomEmojiLoadedNotification
			object:store queue:nil usingBlock:^(NSNotification *note) {
		posts++;
		ids = note.userInfo[@"ids"];
	}];
	[store receiveStickers:@[ cesRow(2001LL, 6001LL, @"tgs", 0), cesRow(2002LL, 6002LL, @"webm", 0),
			cesRow(2003LL, 6003LL, @"tgs", 0) ] forIds:@[ @(2001LL), @(2002LL), @(2003LL) ]];
	XCTAssertEqual(posts, (NSUInteger)0);
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.5];
	while ([deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	[[NSNotificationCenter defaultCenter] removeObserver:observer];
	XCTAssertEqual(posts, (NSUInteger)1);
	XCTAssertEqual(ids.count, (NSUInteger)3);
}

@end
