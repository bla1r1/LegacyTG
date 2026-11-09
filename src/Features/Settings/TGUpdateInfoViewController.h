//
// TGUpdateInfoViewController.h - the modal that names a newer build and its
// changelog.
//
#import "TGRowsViewController.h"

@class TGUpdateInfo;

@interface TGUpdateInfoViewController : TGRowsViewController

- (instancetype)initWithUpdateInfo:(TGUpdateInfo *)info;

@end
