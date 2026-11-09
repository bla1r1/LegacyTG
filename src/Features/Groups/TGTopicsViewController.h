//
// TGTopicsViewController - topic list controller for forum supergroups.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGTopicsViewController : TGRowsViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy)   NSString *chatTitle;

@end
