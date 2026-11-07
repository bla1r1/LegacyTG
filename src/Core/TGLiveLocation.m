//
// TGLiveLocation.m - the line under a live location map: whether sharing is
// still on, how long it has left, which way the phone faces and how close the
// proximity alert is. Foundation only, so the same words can be measured by
// the layout pass and drawn by the bubble.
//
#import "TGLiveLocation.h"
#include <math.h>

/// TDLib sends 0x7FFFFFFF as live_period when the user chose "until stopped".
/// It is a length of time, not a date, so it never runs out with the clock.
static const long long TGLiveLocationForeverPeriod = 0x7FFFFFFFLL;

static NSDictionary *TGLiveLocationDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

/// Every scalar may arrive as a JSON string or an NSNull. nil means "absent",
/// which lets the caller try the other spelling of the same field; a value that
/// is present but unreadable still becomes 0 rather than leaking NSNull.
static id TGLiveLocationNumberSource(id value) {
	if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class])
		return value;
	return nil;
}

static NSNumber *TGLiveLocationNumber(id value) {
	return @([TGLiveLocationNumberSource(value) longLongValue]);
}

NSDictionary *TGFlattenLiveLocation(NSDictionary *content) {
	if (![content isKindOfClass:NSDictionary.class])
		return nil;
	if (![content[@"@type"] isEqualToString:@"messageLiveLocation"])
		return nil;

	// The live fields sit one level down, under `location` of type
	// liveLocation; some call sites also keep live_period at the top.
	NSDictionary *location = TGLiveLocationDict(content[@"location"]);

	id period = TGLiveLocationNumberSource(location[@"live_period"]);
	if (!period)
		period = TGLiveLocationNumberSource(content[@"live_period"]);

	id heading = TGLiveLocationNumberSource(location[@"heading"]);
	if (!heading)
		heading = TGLiveLocationNumberSource(content[@"heading"]);

	id radius = TGLiveLocationNumberSource(location[@"proximity_alert_radius"]);
	if (!radius)
		radius = TGLiveLocationNumberSource(content[@"proximity_alert_radius"]);

	NSNumber *livePeriod = TGLiveLocationNumber(period);
	return @{
		@"livePeriod"     : livePeriod,
		@"heading"        : TGLiveLocationNumber(heading),
		@"proximityRadius": TGLiveLocationNumber(radius),
		@"expiresIn"      : TGLiveLocationNumber(content[@"expires_in"]),
		@"isForever"      : @([livePeriod longLongValue] == TGLiveLocationForeverPeriod),
	};
}

NSString *TGLiveLocationStatus(NSDictionary *live, NSTimeInterval sentDate, NSTimeInterval now) {
	NSDictionary *info = [live isKindOfClass:NSDictionary.class] ? live : @{};
	if ([info[@"isForever"] boolValue])
		return @"Live location";

	double expiresIn = [info[@"expiresIn"] doubleValue];
	if (expiresIn <= 0)
		return @"Live location ended";

	double remaining = expiresIn;
	double livePeriod = [info[@"livePeriod"] doubleValue];
	if (livePeriod > 0) {
		double byPeriod = sentDate + livePeriod - now;
		if (byPeriod <= 0)
			return @"Live location ended";
		// expires_in is TDLib's own countdown from the message's last update and
		// the period is the same moment worked out from the send date. The
		// smaller one never offers time the server has already spent.
		if (byPeriod < remaining)
			remaining = byPeriod;
	}

	if (remaining < 120)
		return @"Live location, 1 min left";

	long long minutes = (long long)(remaining / 60.0);
	if (minutes < 60)
		return [NSString stringWithFormat:@"Live location, %lld min left", minutes];

	long long hours = minutes / 60;
	long long rest = minutes % 60;
	if (rest == 0)
		return [NSString stringWithFormat:@"Live location, %lld h left", hours];
	return [NSString stringWithFormat:@"Live location, %lld h %lld min left", hours, rest];
}

NSString *TGLiveLocationUpdated(NSTimeInterval editDate, NSTimeInterval now) {
	if (editDate <= 0)
		return nil;

	NSTimeInterval age = now - editDate;
	if (age < 0)
		age = 0;

	if (age < 60)
		return @"updated just now";
	if (age < 3600) {
		long long minutes = (long long)(age / 60.0);
		return [NSString stringWithFormat:@"updated %lld min ago", minutes];
	}
	long long hours = (long long)(age / 3600.0);
	return [NSString stringWithFormat:@"updated %lld h ago", hours];
}

NSString *TGLiveLocationHeading(int64_t degrees) {
	// 0 is the schema's "heading unknown", while a full 360 is due north.
	if (degrees == 0)
		return nil;

	int64_t normalized = degrees % 360;
	if (normalized < 0)
		normalized += 360;

	static NSString *const directions[8] = {
		@"N", @"NE", @"E", @"SE", @"S", @"SW", @"W", @"NW"
	};
	// Each sector is 45 degrees wide and centred on its direction, so N spans
	// 338..22 and NE starts at 23.
	int64_t sector = ((normalized + 22) / 45) % 8;
	return directions[sector];
}

NSString *TGLiveLocationRadius(int64_t meters) {
	if (meters <= 0)
		return nil;
	if (meters < 1000)
		return [NSString stringWithFormat:@"Alert within %lld m", meters];
	// Rounded to a tenth first, so 1999 m reads "2 km", not "2.0 km".
	long long tenths = (long long)llround(meters / 100.0);
	if (tenths % 10 == 0)
		return [NSString stringWithFormat:@"Alert within %lld km", tenths / 10];
	return [NSString stringWithFormat:@"Alert within %lld.%lld km", tenths / 10, tenths % 10];
}
