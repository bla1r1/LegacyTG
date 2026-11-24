//
// TGPinnedMessagesViewController.h - list of all pinned messages in a chat.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGPinnedMessagesViewController : TGRowsViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t threadId;
@property (nonatomic, copy) void (^onSelectMessage)(int64_t messageId);

@end
