// TGDownloadListTests.m - Settings > Downloads as official's list
// (ChatListUI ChatListSearchListPaneNode: Downloading, Recently Downloaded).
#import "TGTestRunner.h"
#import "TGDownloadList.h"

@interface TGDownloadListTests : XCTestCase @end

@implementation TGDownloadListTests

- (void)testSplitsAndOrdersNewestFirst {
	NSDictionary *model = TGDownloadListModel(@[
		@{ @"fileId" : @1, @"done" : @NO, @"addDate" : @100 },
		@{ @"fileId" : @2, @"done" : @YES, @"completeDate" : @300 },
		@{ @"fileId" : @3, @"done" : @NO, @"addDate" : @200 },
		@{ @"fileId" : @4, @"done" : @YES, @"completeDate" : @400 },
	], @{ @"active_count" : @2, @"paused_count" : @0, @"completed_count" : @2 });
	XCTAssertEqualObjects([model[@"downloading"] valueForKey:@"fileId"], (@[@3, @1]));
	XCTAssertEqualObjects([model[@"downloaded"] valueForKey:@"fileId"], (@[@4, @2]));
	XCTAssertFalse([model[@"allPaused"] boolValue]);
	XCTAssertTrue([model[@"hasCompleted"] boolValue]);
}

- (void)testAllPausedWhenPausedCoversActive {
	NSDictionary *model = TGDownloadListModel(@[ @{ @"done" : @NO, @"paused" : @YES } ],
			@{ @"active_count" : @1, @"paused_count" : @1, @"completed_count" : @0 });
	XCTAssertTrue([model[@"allPaused"] boolValue]);
	XCTAssertFalse([model[@"hasCompleted"] boolValue]);
}

@end
