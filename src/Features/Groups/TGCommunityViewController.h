//
// TGCommunityViewController.h - one community: its full record, its chats and
// the four writes Telegram allows the owner.
//
#import "TGFeatureListViewController.h"

@interface TGCommunityViewController : TGFeatureListViewController

/// `community` is the updateCommunity row the list tapped, or a row built
/// from the create answer. The id is what every request uses.
- (instancetype)initWithCommunity:(NSDictionary *)community;

@end
