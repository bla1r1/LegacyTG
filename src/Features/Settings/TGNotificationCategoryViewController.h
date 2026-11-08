//
// TGNotificationCategoryViewController.h - one notification category.
//
// Official opens a per-category screen from Private Chats, Groups and
// Channels: the scope switch, message preview, sound, then the chats that
// override the scope. The list is one table because iOS 6 has no modern
// settings stack.
//
#import <UIKit/UIKit.h>
#import "TGTableViewController.h"

@interface TGNotificationCategoryViewController : TGTableViewController

/// `scope` is the client's short name: private, groups or channels.
- (instancetype)initWithScope:(NSString *)scope title:(NSString *)title;

@end
