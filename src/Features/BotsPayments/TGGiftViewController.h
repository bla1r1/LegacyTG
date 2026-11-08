//
// TGGiftViewController.h - detail screen for a received gift.
//
#import <UIKit/UIKit.h>
#import "TGTableViewController.h"

@interface TGGiftViewController : TGTableViewController

- (instancetype)initWithGift:(NSDictionary *)gift;

@end
