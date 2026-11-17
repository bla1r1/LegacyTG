//
// TGProfileLevelViewController.h - the Rating screen behind a profile's level
// badge (official ProfileLevelInfoScreen): the level and its points, the
// account's own pending change, and what moves the rating.
//
#import "TGRowsViewController.h"

@interface TGProfileLevelViewController : TGRowsViewController

/// `rating` and `pending` as TGUserRatingFrom gives them; `pending` only for
/// the account's own profile. `name` is someone else's, nil for one's own.
- (instancetype)initWithRating:(NSDictionary *)rating
					   pending:(NSDictionary *)pending
				   pendingDate:(int64_t)pendingDate
						  name:(NSString *)name;

@end
