//
// TGBackgroundKeeperTests.m - background keepalive and memory purge unit tests.
//
#import "TGTestRunner.h"
#import "TGBackgroundKeeper.h"
#import "TGAppActivity.h"
#import "TGSettingsStore.h"
#import "TGPeerStore.h"
#import "TGChatListStore.h"

@interface TGBackgroundKeeperTests : XCTestCase
@end

@implementation TGBackgroundKeeperTests

/// TDLib was never told the app left the screen: the "online" option was not
/// set at all, so a kept-alive client looked in use all night.
- (void)testOnlineOptionIsTDLibsBooleanOption {
	NSDictionary *off = TGOnlineOptionRequest(NO);
	XCTAssertEqualObjects(off[@"@type"], @"setOption");
	XCTAssertEqualObjects(off[@"name"], @"online");
	XCTAssertEqualObjects(off[@"value"][@"@type"], @"optionValueBoolean");
	XCTAssertEqualObjects(off[@"value"][@"value"], @NO);
	XCTAssertEqualObjects(TGOnlineOptionRequest(YES)[@"value"][@"value"], @YES);
}

/// Sticker loops, GIFs and the chat list pause on this notification and catch
/// up on the next one, so it fires once per change and never on a repeat.
- (void)testActivityChangePostsOncePerChange {
	TGAppSetInBackground(NO);
	__block NSInteger posts = 0;
	id token = [[NSNotificationCenter defaultCenter]
			addObserverForName:TGAppActivityChangedNotification object:nil
			queue:nil usingBlock:^(NSNotification *note){ posts++; }];
	TGAppSetInBackground(YES);
	XCTAssertTrue(TGAppInBackground());
	TGAppSetInBackground(YES);
	TGAppSetInBackground(NO);
	XCTAssertFalse(TGAppInBackground());
	[[NSNotificationCenter defaultCenter] removeObserver:token];
	XCTAssertEqual(posts, (NSInteger)2);
}

- (void)testBackgroundKeeperSingleton {
	TGBackgroundKeeper *k1 = [TGBackgroundKeeper shared];
	TGBackgroundKeeper *k2 = [TGBackgroundKeeper shared];
	XCTAssertNotNil(k1);
	XCTAssertEqualObjects(k1, k2);
}

- (void)testBackgroundKeeperStartStop {
	TGBackgroundKeeper *keeper = [TGBackgroundKeeper shared];
	[keeper stop];
	XCTAssertFalse(keeper.running);

	BOOL started = [keeper start];
	XCTAssertTrue(started);
	XCTAssertTrue(keeper.running);

	// Start while running should be idempotent
	BOOL startedAgain = [keeper start];
	XCTAssertTrue(startedAgain);
	XCTAssertTrue(keeper.running);

	[keeper stop];
	XCTAssertFalse(keeper.running);
}

- (void)testKeepAliveSettingPersistence {
	TGSettingsStore *settings = [TGSettingsStore shared];
	BOOL initial = settings.keepAliveEnabled;

	settings.keepAliveEnabled = YES;
	XCTAssertTrue(settings.keepAliveEnabled);

	settings.keepAliveEnabled = NO;
	XCTAssertFalse(settings.keepAliveEnabled);

	// Restore
	settings.keepAliveEnabled = initial;
}

- (void)testMemoryCachePurgeDoesNotCrash {
	// Calling clearMemoryCaches across stores should cleanly run with empty/populated caches
	XCTAssertNoThrow([[TGPeerStore shared] clearMemoryCaches]);
	XCTAssertNoThrow([[TGChatListStore shared] clearMemoryCaches]);
}

@end
