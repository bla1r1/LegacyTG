// TGLiveLocationTests.m — the status line under a live location map.
//
// The bubble is only useful if it says the same thing the official client
// says: whether sharing is still on, how long is left, when it last moved and
// which way the phone faces. These tests pin the wording, the sector edges and
// the defaults that keep a missing TDLib field away from a label.
#import "TGTestRunner.h"
#import "TGLiveLocation.h"

@interface TGLiveLocationTests : XCTestCase @end

static NSDictionary *llLive(id period, id heading, id radius, id expires) {
	NSNumber *livePeriod = @([period longLongValue]);
	return @{
		@"livePeriod"     : livePeriod,
		@"heading"        : @([heading longLongValue]),
		@"proximityRadius": @([radius longLongValue]),
		@"expiresIn"      : @([expires longLongValue]),
		@"isForever"      : @([livePeriod longLongValue] == 0x7FFFFFFFLL),
	};
}

/// A location whose whole period is `period` seconds and which has `left`
/// seconds to run at `now`, with sentDate fixed at 1000.
static NSString *llStatusWithLeft(double period, double left) {
	return TGLiveLocationStatus(llLive(@(period), @0, @0, @(period)),
			1000.0, 1000.0 + period - left);
}

@implementation TGLiveLocationTests

#pragma mark - flatten

- (void)testFlatten_FullLiveLocationReadsNestedKeys {
	NSDictionary *out = TGFlattenLiveLocation(@{
		@"@type"     : @"messageLiveLocation",
		@"expires_in": @900,
		@"location"  : @{
			@"@type"                 : @"liveLocation",
			@"location"              : @{@"latitude" : @50.45, @"longitude" : @30.52},
			@"live_period"           : @900,
			@"heading"               : @45,
			@"proximity_alert_radius": @500,
		},
	});

	XCTAssertTrue(out != nil);
	XCTAssertEqual([out[@"livePeriod"] longLongValue], 900LL);
	XCTAssertEqual([out[@"heading"] longLongValue], 45LL);
	XCTAssertEqual([out[@"proximityRadius"] longLongValue], 500LL);
	XCTAssertEqual([out[@"expiresIn"] longLongValue], 900LL);
	XCTAssertFalse([out[@"isForever"] boolValue]);
}

- (void)testFlatten_StringNumbersAreAccepted {
	NSDictionary *out = TGFlattenLiveLocation(@{
		@"@type"     : @"messageLiveLocation",
		@"expires_in": @"3200",
		@"location"  : @{
			@"live_period"           : @"3600",
			@"heading"               : @"225",
			@"proximity_alert_radius": @"1500",
		},
	});

	XCTAssertEqual([out[@"livePeriod"] longLongValue], 3600LL);
	XCTAssertEqual([out[@"heading"] longLongValue], 225LL);
	XCTAssertEqual([out[@"proximityRadius"] longLongValue], 1500LL);
	XCTAssertEqual([out[@"expiresIn"] longLongValue], 3200LL);
}

- (void)testFlatten_MissingFieldsDefaultToZero {
	NSDictionary *out = TGFlattenLiveLocation(@{
		@"@type"   : @"messageLiveLocation",
		@"location": @{@"@type" : @"liveLocation"},
	});

	XCTAssertTrue(out != nil);
	XCTAssertEqual([out[@"livePeriod"] longLongValue], 0LL);
	XCTAssertEqual([out[@"heading"] longLongValue], 0LL);
	XCTAssertEqual([out[@"proximityRadius"] longLongValue], 0LL);
	XCTAssertEqual([out[@"expiresIn"] longLongValue], 0LL);
	XCTAssertFalse([out[@"isForever"] boolValue]);
}

- (void)testFlatten_NSNullLocationDefaultsToZero {
	NSDictionary *out = TGFlattenLiveLocation(@{
		@"@type"     : @"messageLiveLocation",
		@"location"  : [NSNull null],
		@"expires_in": [NSNull null],
	});

	XCTAssertEqual([out[@"livePeriod"] longLongValue], 0LL);
	XCTAssertEqual([out[@"heading"] longLongValue], 0LL);
	XCTAssertEqual([out[@"proximityRadius"] longLongValue], 0LL);
	XCTAssertEqual([out[@"expiresIn"] longLongValue], 0LL);
}

- (void)testFlatten_GarbageScalarsDefaultToZero {
	NSDictionary *out = TGFlattenLiveLocation(@{
		@"@type"     : @"messageLiveLocation",
		@"expires_in": @[],
		@"location"  : @{
			@"live_period"           : [NSNull null],
			@"heading"               : @{@"value" : @1},
			@"proximity_alert_radius": @"not a number",
		},
	});

	XCTAssertEqual([out[@"livePeriod"] longLongValue], 0LL);
	XCTAssertEqual([out[@"heading"] longLongValue], 0LL);
	XCTAssertEqual([out[@"proximityRadius"] longLongValue], 0LL);
	XCTAssertEqual([out[@"expiresIn"] longLongValue], 0LL);
}

- (void)testFlatten_ForeverPeriodIsFlagged {
	NSDictionary *out = TGFlattenLiveLocation(@{
		@"@type"   : @"messageLiveLocation",
		@"location": @{@"live_period" : @(0x7FFFFFFF)},
	});

	XCTAssertTrue([out[@"isForever"] boolValue]);
	XCTAssertEqual([out[@"livePeriod"] longLongValue], 0x7FFFFFFFLL);
}

- (void)testFlatten_StringForeverPeriodIsFlagged {
	NSDictionary *out = TGFlattenLiveLocation(@{
		@"@type"   : @"messageLiveLocation",
		@"location": @{@"live_period" : @"2147483647"},
	});

	XCTAssertTrue([out[@"isForever"] boolValue]);
}

- (void)testFlatten_TopLevelPeriodAndHeadingFallback {
	NSDictionary *out = TGFlattenLiveLocation(@{
		@"@type"    : @"messageLiveLocation",
		@"live_period": @600,
		@"heading"  : @90,
		@"location": @{@"@type" : @"liveLocation"},
	});

	XCTAssertEqual([out[@"livePeriod"] longLongValue], 600LL);
	XCTAssertEqual([out[@"heading"] longLongValue], 90LL);
}

- (void)testFlatten_OtherContentReturnsNil {
	XCTAssertTrue(TGFlattenLiveLocation(@{
		@"@type"   : @"messageLocation",
		@"location": @{@"latitude" : @1, @"longitude" : @2},
	}) == nil);
}

- (void)testFlatten_NonDictionaryReturnsNil {
	XCTAssertTrue(TGFlattenLiveLocation(nil) == nil);
	XCTAssertTrue(TGFlattenLiveLocation((NSDictionary *)[NSNull null]) == nil);
}

#pragma mark - status

- (void)testStatus_ForeverSaysLiveLocation {
	XCTAssertEqualObjects(TGLiveLocationStatus(
			llLive(@(0x7FFFFFFF), @0, @0, @(0x7FFFFFFF)), 1000.0, 2000.0),
			@"Live location");
}

- (void)testStatus_ForeverIgnoresZeroExpiresIn {
	XCTAssertEqualObjects(TGLiveLocationStatus(
			llLive(@(0x7FFFFFFF), @0, @0, @0), 1000.0, 2000.0),
			@"Live location");
}

- (void)testStatus_ExpiredWhenExpiresInIsZero {
	XCTAssertEqualObjects(TGLiveLocationStatus(
			llLive(@900, @0, @0, @0), 1000.0, 1200.0),
			@"Live location ended");
}

- (void)testStatus_ExpiredWhenClockReachesTheEnd {
	XCTAssertEqualObjects(TGLiveLocationStatus(
			llLive(@900, @0, @0, @900), 1000.0, 1900.0),
			@"Live location ended");
}

- (void)testStatus_ExpiredWhenClockPassesTheEnd {
	XCTAssertEqualObjects(TGLiveLocationStatus(
			llLive(@900, @0, @0, @900), 1000.0, 1901.0),
			@"Live location ended");
}

- (void)testStatus_59SecondsSaysOneMinute {
	XCTAssertEqualObjects(llStatusWithLeft(3600.0, 59.0), @"Live location, 1 min left");
}

- (void)testStatus_60SecondsSaysOneMinute {
	XCTAssertEqualObjects(llStatusWithLeft(3600.0, 60.0), @"Live location, 1 min left");
}

- (void)testStatus_119SecondsSaysOneMinute {
	XCTAssertEqualObjects(llStatusWithLeft(3600.0, 119.0), @"Live location, 1 min left");
}

- (void)testStatus_120SecondsSaysTwoMinutes {
	XCTAssertEqualObjects(llStatusWithLeft(3600.0, 120.0), @"Live location, 2 min left");
}

- (void)testStatus_3599SecondsSays59Minutes {
	XCTAssertEqualObjects(llStatusWithLeft(3600.0, 3599.0), @"Live location, 59 min left");
}

- (void)testStatus_3600SecondsSaysOneHour {
	XCTAssertEqualObjects(llStatusWithLeft(7200.0, 3600.0), @"Live location, 1 h left");
}

- (void)testStatus_HoursAndMinutes {
	XCTAssertEqualObjects(llStatusWithLeft(7200.0, 3900.0), @"Live location, 1 h 5 min left");
}

- (void)testStatus_WholeHoursOmitMinutes {
	XCTAssertEqualObjects(llStatusWithLeft(7200.0, 7200.0), @"Live location, 2 h left");
}

- (void)testStatus_FourteenMinutesExample {
	XCTAssertEqualObjects(llStatusWithLeft(900.0, 840.0), @"Live location, 14 min left");
}

- (void)testStatus_ShorterExpiresInWins {
	NSDictionary *live = llLive(@3600, @0, @0, @120);
	XCTAssertEqualObjects(TGLiveLocationStatus(live, 1000.0, 1000.0),
			@"Live location, 2 min left");
}

- (void)testStatus_NilInfoSaysEnded {
	XCTAssertEqualObjects(TGLiveLocationStatus(nil, 1000.0, 2000.0),
			@"Live location ended");
}

- (void)testStatus_GarbageInfoSaysEnded {
	NSDictionary *live = @{
		@"livePeriod"     : [NSNull null],
		@"heading"        : @"north",
		@"proximityRadius": @[],
		@"expiresIn"      : [NSNull null],
		@"isForever"      : [NSNull null],
	};
	XCTAssertEqualObjects(TGLiveLocationStatus(live, 1000.0, 2000.0),
			@"Live location ended");
}

- (void)testStatus_StringPeriodFromFlatten {
	NSDictionary *live = TGFlattenLiveLocation(@{
		@"@type"     : @"messageLiveLocation",
		@"expires_in": @"7200",
		@"location"  : @{@"live_period" : @"7200"},
	});
	XCTAssertEqualObjects(TGLiveLocationStatus(live, 1000.0, 4600.0),
			@"Live location, 1 h left");
}

#pragma mark - updated

- (void)testUpdated_ZeroIsNil {
	XCTAssertTrue(TGLiveLocationUpdated(0, 2000.0) == nil);
}

- (void)testUpdated_ThirtySecondsIsJustNow {
	XCTAssertEqualObjects(TGLiveLocationUpdated(1000.0, 1030.0),
			@"updated just now");
}

- (void)testUpdated_59SecondsIsJustNow {
	XCTAssertEqualObjects(TGLiveLocationUpdated(1000.0, 1059.0),
			@"updated just now");
}

- (void)testUpdated_60SecondsIsOneMinuteAgo {
	XCTAssertEqualObjects(TGLiveLocationUpdated(1000.0, 1060.0),
			@"updated 1 min ago");
}

- (void)testUpdated_3599SecondsIs59MinutesAgo {
	XCTAssertEqualObjects(TGLiveLocationUpdated(1000.0, 4599.0),
			@"updated 59 min ago");
}

- (void)testUpdated_3600SecondsIsOneHourAgo {
	XCTAssertEqualObjects(TGLiveLocationUpdated(1000.0, 4600.0),
			@"updated 1 h ago");
}

- (void)testUpdated_TwoHoursAgo {
	XCTAssertEqualObjects(TGLiveLocationUpdated(1000.0, 8200.0),
			@"updated 2 h ago");
}

- (void)testUpdated_FiveMinutesAgo {
	XCTAssertEqualObjects(TGLiveLocationUpdated(1000.0, 1300.0),
			@"updated 5 min ago");
}

- (void)testUpdated_FutureEditIsJustNow {
	XCTAssertEqualObjects(TGLiveLocationUpdated(2000.0, 1000.0),
			@"updated just now");
}

#pragma mark - heading

- (void)testHeading_ZeroIsUnknown {
	XCTAssertTrue(TGLiveLocationHeading(0) == nil);
}

- (void)testHeading_SectorCentres {
	NSArray *degrees = @[@5, @45, @90, @135, @180, @225, @270, @315];
	NSArray *names = @[@"N", @"NE", @"E", @"SE", @"S", @"SW", @"W", @"NW"];
	for (NSUInteger i = 0; i < degrees.count; i++)
		XCTAssertEqualObjects(TGLiveLocationHeading([degrees[i] longLongValue]),
				names[i]);
}

- (void)testHeading_SectorEdges {
	NSArray *degrees = @[@22, @23, @67, @68, @112, @113, @157, @158,
			@202, @203, @247, @248, @292, @293, @337];
	NSArray *names = @[@"N", @"NE", @"NE", @"E", @"E", @"SE", @"SE", @"S",
			@"S", @"SW", @"SW", @"W", @"W", @"NW", @"NW"];
	for (NSUInteger i = 0; i < degrees.count; i++)
		XCTAssertEqualObjects(TGLiveLocationHeading([degrees[i] longLongValue]),
				names[i]);
}

- (void)testHeading_22IsNorth {
	XCTAssertEqualObjects(TGLiveLocationHeading(22), @"N");
}

- (void)testHeading_23IsNortheast {
	XCTAssertEqualObjects(TGLiveLocationHeading(23), @"NE");
}

- (void)testHeading_337IsNorthwest {
	XCTAssertEqualObjects(TGLiveLocationHeading(337), @"NW");
}

- (void)testHeading_338IsNorth {
	XCTAssertEqualObjects(TGLiveLocationHeading(338), @"N");
}

- (void)testHeading_360IsNorth {
	XCTAssertEqualObjects(TGLiveLocationHeading(360), @"N");
}

- (void)testHeading_NegativeDegreesWrap {
	XCTAssertEqualObjects(TGLiveLocationHeading(-90), @"W");
}

#pragma mark - radius

- (void)testRadius_ZeroIsNil {
	XCTAssertTrue(TGLiveLocationRadius(0) == nil);
}

- (void)testRadius_NegativeIsNil {
	XCTAssertTrue(TGLiveLocationRadius(-100) == nil);
}

- (void)testRadius_500Meters {
	XCTAssertEqualObjects(TGLiveLocationRadius(500), @"Alert within 500 m");
}

- (void)testRadius_999Meters {
	XCTAssertEqualObjects(TGLiveLocationRadius(999), @"Alert within 999 m");
}

- (void)testRadius_1000MetersIsOneKilometre {
	XCTAssertEqualObjects(TGLiveLocationRadius(1000), @"Alert within 1 km");
}

- (void)testRadius_1500MetersIsOnePointFiveKilometres {
	XCTAssertEqualObjects(TGLiveLocationRadius(1500), @"Alert within 1.5 km");
}

- (void)testRadius_2000MetersIsTwoKilometres {
	XCTAssertEqualObjects(TGLiveLocationRadius(2000), @"Alert within 2 km");
}

- (void)testRadius_JustUnderTwoKilometresReadsTwo {
	XCTAssertEqualObjects(TGLiveLocationRadius(1999), @"Alert within 2 km");
	XCTAssertEqualObjects(TGLiveLocationRadius(1050), @"Alert within 1.1 km");
}

@end
