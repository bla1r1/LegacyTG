//
// TGScheduledViewController - what a chat has waiting to be sent.
//
#import <UIKit/UIKit.h>
#import "TGTableViewController.h"

@interface TGScheduledViewController : TGTableViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy)   NSString *chatTitle;

@end
