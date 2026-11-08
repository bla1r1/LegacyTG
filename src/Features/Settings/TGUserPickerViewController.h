//
// TGUserPickerViewController.h - contact picker for privacy exception lists.
//
#import <UIKit/UIKit.h>
#import "TGTableViewController.h"

@interface TGUserPickerViewController : TGTableViewController

- (instancetype)initWithSelectedUserIds:(NSSet *)userIds title:(NSString *)title;

@property (nonatomic, copy) void (^onDone)(NSSet *selectedUserIds);

@end
