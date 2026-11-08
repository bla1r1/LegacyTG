//
// TGContactSort.h - the presence order and the two sorts of the Contacts list.
//
// Keep the ordering out of the controller so the host tests can check the same
// functions the list uses; the ordering bug (an old exact timestamp
// outranking "last seen recently") is a data decision, not a UIKit one.
//
#import <Foundation/Foundation.h>

/// Lower ranks sort first. Online, Recently, Last Week, Last Month, Offline
/// (with an exact timestamp), then anything unknown. An offline timestamp is
/// older than every coarse privacy bucket, so it must rank below them.
FOUNDATION_EXPORT NSInteger TGContactPresenceRank(NSDictionary *status);

/// The last-seen order the Contacts list applies. Presence rank first, then
/// the newer exact timestamp among offline contacts, then the name.
FOUNDATION_EXPORT NSComparisonResult TGContactCompareByLastSeen(NSDictionary *a,
																NSDictionary *b);

/// The same contacts in the order the list displays them.
FOUNDATION_EXPORT NSArray *TGContactsSortedByLastSeen(NSArray *users);
FOUNDATION_EXPORT NSArray *TGContactsSortedByName(NSArray *users);

/// The name a contact row shows: full name, else @username, else the number.
FOUNDATION_EXPORT NSString *TGContactDisplayName(NSDictionary *user);
