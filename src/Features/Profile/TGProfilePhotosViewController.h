//
// TGProfilePhotosViewController.h - every profile photo an account still has,
// one to a row, each removable by swipe.
//
#import <UIKit/UIKit.h>
#import "TGTableViewController.h"

@interface TGProfilePhotosViewController : TGTableViewController

- (instancetype)initWithUserId:(int64_t)userId;

@end
