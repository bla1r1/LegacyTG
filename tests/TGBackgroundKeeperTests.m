//
// TGBackgroundKeeperTests.m - background keepalive and memory purge unit tests.
//
#import "TGTestRunner.h"
#import "TGBackgroundKeeper.h"
#import "TGSettingsStore.h"
#import "TGPeerStore.h"
#import "TGChatListStore.h"

@interface TGBackgroundKeeperTests : XCTestCase
@end

@implementation TGBackgroundKeeperTests

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
