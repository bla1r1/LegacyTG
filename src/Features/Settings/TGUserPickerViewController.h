//
// TGUserPickerViewController.h - contact picker for privacy exception lists.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGUserPickerViewController : TGRowsViewController

- (instancetype)initWithSelectedUserIds:(NSSet *)userIds title:(NSString *)title;

@property (nonatomic, copy) void (^onDone)(NSSet *selectedUserIds);

@end
