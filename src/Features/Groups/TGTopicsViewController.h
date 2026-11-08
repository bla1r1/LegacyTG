//
// TGTopicsViewController - topic list controller for forum supergroups.
//
#import <UIKit/UIKit.h>
#import "TGTableViewController.h"

@interface TGTopicsViewController : TGTableViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy)   NSString *chatTitle;

@end
