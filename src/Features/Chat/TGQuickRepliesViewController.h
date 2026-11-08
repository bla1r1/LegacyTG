//
// TGQuickRepliesViewController.h - Saved Replies: the shortcut list, its
// order, creation and the send mode the composer opens.
//
#import "TGFeatureListViewController.h"

@interface TGQuickRepliesViewController : TGFeatureListViewController

/// Non-zero puts the screen in send mode: tapping a shortcut sends its
/// messages to this chat instead of opening the editor.
@property (nonatomic, assign) int64_t sendChatId;

@end
