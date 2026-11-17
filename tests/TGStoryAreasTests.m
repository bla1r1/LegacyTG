// TGStoryAreasTests.m - tappable story areas and the pinned stories order
// (official StoryItemSetContainerComponent hit test, the profile stories pane).
#import "TGTestRunner.h"
#import "TGStoryAreas.h"

@interface TGStoryAreasTests : XCTestCase @end

static NSDictionary *saArea(double x, double y, double w, double h, double rotation, NSDictionary *type) {
	return @{ @"@type" : @"storyArea",
			  @"position" : @{ @"@type" : @"areaPosition", @"x_percentage" : @(x), @"y_percentage" : @(y),
					@"width_percentage" : @(w), @"height_percentage" : @(h),
					@"rotation_angle" : @(rotation), @"corner_radius_percentage" : @0 },
			  @"type" : type };
}

@implementation TGStoryAreasTests

- (void)testAreas_LinkAndMessageKept_OthersLeftOut {
	NSArray *areas = TGStoryAreasFromTD(@[
		saArea(50, 50, 20, 10, 0, @{ @"@type" : @"storyAreaTypeLink", @"url" : @"https://t.me/x" }),
		saArea(20, 20, 10, 10, 0, @{ @"@type" : @"storyAreaTypeMessage", @"chat_id" : @(-100), @"message_id" : @(7) }),
		saArea(80, 80, 10, 10, 0, @{ @"@type" : @"storyAreaTypeWeather", @"temperature" : @(3), @"emoji" : @"x" }),
	]);
	XCTAssertEqual(areas.count, (NSUInteger)2);
	XCTAssertEqualObjects(areas[0][@"kind"], @"link");
	XCTAssertEqualObjects(areas[0][@"url"], @"https://t.me/x");
	XCTAssertTrue(fabs([areas[0][@"w"] doubleValue] - 0.2) < 0.0001);
	XCTAssertEqualObjects(areas[1][@"kind"], @"message");
	XCTAssertEqualObjects(areas[1][@"messageId"], @7);
}

- (void)testHit_CentreAndTenthMargin {
	NSArray *areas = TGStoryAreasFromTD(@[
		saArea(50, 50, 20, 10, 0, @{ @"@type" : @"storyAreaTypeLink", @"url" : @"u" }) ]);
	CGRect picture = CGRectMake(0, 0, 100, 200);
	XCTAssertNotNil(TGStoryAreaAt(areas, CGPointMake(50, 100), picture));
	XCTAssertNotNil(TGStoryAreaAt(areas, CGPointMake(60.5, 100), picture));   // inside the 1.1 growth
	XCTAssertNil(TGStoryAreaAt(areas, CGPointMake(62, 100), picture));
	XCTAssertNil(TGStoryAreaAt(areas, CGPointMake(50, 112), picture));
}

- (void)testHit_RotationTurnsTheArea {
	NSArray *areas = TGStoryAreasFromTD(@[
		saArea(50, 50, 40, 5, 90, @{ @"@type" : @"storyAreaTypeLink", @"url" : @"u" }) ]);
	CGRect picture = CGRectMake(0, 0, 100, 100);
	XCTAssertNotNil(TGStoryAreaAt(areas, CGPointMake(50, 30), picture));
	XCTAssertNil(TGStoryAreaAt(areas, CGPointMake(30, 50), picture));
}

- (void)testPinnedFirst_InPinnedOrder {
	NSArray *stories = @[ @{ @"storyId" : @1 }, @{ @"storyId" : @2 }, @{ @"storyId" : @3 } ];
	NSArray *out = TGStoriesPinnedFirst(stories, @[ @3, @2 ]);
	XCTAssertEqualObjects(out[0][@"storyId"], @3);
	XCTAssertEqualObjects(out[1][@"storyId"], @2);
	XCTAssertEqualObjects(out[2][@"storyId"], @1);
	XCTAssertTrue([out[0][@"isPinned"] boolValue]);
	XCTAssertFalse([out[2][@"isPinned"] boolValue]);
	XCTAssertEqualObjects(TGStoriesPinnedFirst(stories, nil), stories);
}

@end
