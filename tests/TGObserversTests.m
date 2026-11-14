// TGObserversTests.m - a block observer goes away with the object that asked
// for it. The screens used to drop the token, so every screen ever opened
// kept answering notifications.
#import "TGTestRunner.h"
#import "TGObservers.h"

@interface TGObserversTests : XCTestCase @end

@implementation TGObserversTests

- (void)testObserver_FiresWhileTheOwnerLives {
	NSObject *owner = [[NSObject alloc] init];
	__block NSInteger fired = 0;
	[TGObservers observe:@"TGObserversTestNote" owner:owner usingBlock:^(NSNotification *note){ fired++; }];
	[TGObservers observe:@"TGObserversTestNote" owner:owner usingBlock:^(NSNotification *note){ fired++; }];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"TGObserversTestNote" object:nil];

	XCTAssertEqual(fired, (NSInteger)2, @"both blocks of one owner are kept");
	(void)owner;
}

- (void)testObserver_IsRemovedWithItsOwner {
	__block NSInteger fired = 0;
	@autoreleasepool {
		NSObject *owner = [[NSObject alloc] init];
		[TGObservers observe:@"TGObserversTestNote2" owner:owner usingBlock:^(NSNotification *note){ fired++; }];
		owner = nil;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"TGObserversTestNote2" object:nil];

	XCTAssertEqual(fired, (NSInteger)0, @"a dead screen must not answer");
}

@end
