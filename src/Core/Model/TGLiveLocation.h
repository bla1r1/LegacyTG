//
// TGLiveLocation - what a live location bubble says under the map: whether
// it is still moving, how long it has left, when it last moved, which way
// it faces and the proximity alert. Foundation only.
//
#import <Foundation/Foundation.h>

/// The live keys of a `messageLiveLocation` content, or nil for any other
/// content: livePeriod, heading, proximityRadius, expiresIn (NSNumbers,
/// 0 when absent), isForever (BOOL NSNumber, live_period == 0x7FFFFFFF).
FOUNDATION_EXPORT NSDictionary *TGFlattenLiveLocation(NSDictionary *content);

/// "Live location", "Live location, 14 min left" or "Live location ended".
/// `live` is TGFlattenLiveLocation's result; dates are Unix seconds.
FOUNDATION_EXPORT NSString *TGLiveLocationStatus(NSDictionary *live, NSTimeInterval sentDate, NSTimeInterval now);

/// "updated 5 min ago", or nil when the location was never edited.
FOUNDATION_EXPORT NSString *TGLiveLocationUpdated(NSTimeInterval editDate, NSTimeInterval now);

/// "NE" and friends, or nil when the heading is unknown (0).
FOUNDATION_EXPORT NSString *TGLiveLocationHeading(int64_t degrees);

/// "Alert within 500 m", or nil when no alert is set.
FOUNDATION_EXPORT NSString *TGLiveLocationRadius(int64_t meters);
