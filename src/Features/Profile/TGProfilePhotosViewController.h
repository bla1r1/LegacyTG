//
// TGProfilePhotosViewController.h - every profile photo an account still has,
// as the shared picture grid.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGProfilePhotosViewController : TGGridRowsViewController

- (instancetype)initWithUserId:(int64_t)userId;

@end
