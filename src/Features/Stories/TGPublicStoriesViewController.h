//
// TGPublicStoriesViewController - public story discovery by tag, location
// and venue. Every result opens in the same viewer as a chat's stories.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGPublicStoriesViewController : TGRowsViewController

/// A tag typed in the search bar is carried here and searched at once.
- (instancetype)initWithTag:(NSString *)tag;

@end
