// TGUserRatingTests.m - the star rating official shows behind a profile's
// level badge (PeerInfoRatingComponent, ProfileLevelInfoScreen).
#import "TGTestRunner.h"
#import "TGUserRating.h"

@interface TGUserRatingTests : XCTestCase @end

static NSDictionary *urRating(int level, long long rating, long long current, long long next, BOOL top) {
	return TGUserRatingFrom(@{@"@type" : @"userRating", @"level" : @(level), @"rating" : @(rating),
			@"current_level_rating" : @(current), @"next_level_rating" : @(next),
			@"is_maximum_level_reached" : @(top)});
}

@implementation TGUserRatingTests

- (void)testLevelBarAndPoints {
	NSDictionary *r = urRating(2, 2000, 1000, 3000, NO);
	XCTAssertEqualObjects(TGUserRatingLevelText(r), @"Level 2");
	XCTAssertTrue(fabs(TGUserRatingFraction(r) - 0.5) < 0.001);
	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	f.numberStyle = NSNumberFormatterDecimalStyle;
	XCTAssertEqualObjects(TGUserRatingProgressText(r), ([NSString stringWithFormat:@"%@ / %@",
			[f stringFromNumber:@2000], [f stringFromNumber:@3000]]));
}

- (void)testTopLevelHasNoNextAndAFullBar {
	NSDictionary *r = urRating(10, 90000, 80000, 0, YES);
	XCTAssertNil(r[@"next"]);
	XCTAssertTrue(fabs(TGUserRatingFraction(r) - 1.0) < 0.001);
	XCTAssertFalse([TGUserRatingProgressText(r) containsString:@"/"]);
}

- (void)testNegativeRatingSaysSo {
	NSDictionary *r = urRating(-1, -100, -1, 0, NO);
	XCTAssertEqualObjects(TGUserRatingLevelText(r), @"Negative rating");
	XCTAssertTrue(fabs(TGUserRatingFraction(r) - 0.5) < 0.001);
	XCTAssertNil(TGUserRatingFrom(nil));
}

- (void)testPendingChangeSaysWhenAndHowMuch {
	NSDictionary *r = urRating(2, 2000, 1000, 3000, NO);
	NSDictionary *more = urRating(2, 2200, 1000, 3000, NO);
	NSTimeInterval now = 1700000000;
	XCTAssertEqualObjects(TGUserRatingPendingText(r, more, (int64_t)now + 3600, now),
			@"The rating updates today.\n200 points are pending.");
	XCTAssertEqualObjects(TGUserRatingPendingText(r, more, (int64_t)now + 3 * 86400 + 60, now),
			@"The rating will update in 3 days.\n200 points are pending.");
	XCTAssertNil(TGUserRatingPendingText(r, more, (int64_t)now - 10, now), @"a passed date is no news");
	XCTAssertNil(TGUserRatingPendingText(r, r, (int64_t)now + 3600, now), @"nothing gained, nothing said");
}

@end
