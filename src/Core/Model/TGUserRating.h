//
// TGUserRating.h - a user's star rating as official's profile shows it: the
// level badge by the status line and the Rating screen behind it
// (PeerInfoHeaderNode PeerInfoRatingComponent, ProfileLevelInfoScreen).
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// TDLib's userRating as @{level, rating, current, next}; "next" is absent at
/// the top level (is_maximum_level_reached). nil for no rating.
NSDictionary *TGUserRatingFrom(NSDictionary *userRating);

/// How far the bar is filled, 0...1: rating between this level's threshold
/// and the next; full at the top, half for a negative rating.
double TGUserRatingFraction(NSDictionary *rating);

/// "Level 3", or "Negative rating" below zero.
NSString *TGUserRatingLevelText(NSDictionary *rating);

/// "2,000 / 3,000", the rating over the next threshold; just the rating at
/// the top level.
NSString *TGUserRatingProgressText(NSDictionary *rating);

/// The account's own pending change: "The rating updates today.\n200 points
/// are pending." or "The rating will update in 3 days.\n…". nil when nothing
/// is pending, the date passed, or the change does not raise the rating.
NSString *TGUserRatingPendingText(NSDictionary *rating, NSDictionary *pending,
		int64_t pendingDate, NSTimeInterval now);

#ifdef __cplusplus
}
#endif
