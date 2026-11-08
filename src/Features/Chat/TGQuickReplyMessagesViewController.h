//
// TGQuickReplyMessagesViewController.h - one shortcut's messages: add, edit,
// delete, re-add and the shortcut's own name.
//
#import "TGFeatureListViewController.h"

@interface TGQuickReplyMessagesViewController : TGFeatureListViewController

- (instancetype)initWithShortcutId:(NSInteger)shortcutId name:(NSString *)name;

@end
