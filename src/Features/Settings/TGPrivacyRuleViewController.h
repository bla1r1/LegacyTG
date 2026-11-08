//
// TGPrivacyRuleViewController.h - detail screen for a privacy rule with exception lists.
//
#import <UIKit/UIKit.h>
#import "TGTableViewController.h"

@interface TGPrivacyRuleViewController : TGTableViewController

- (instancetype)initWithSetting:(NSString *)setting title:(NSString *)title;

@property (nonatomic, copy) void (^onChanged)(NSString *setting, NSString *ruleType);

@end
