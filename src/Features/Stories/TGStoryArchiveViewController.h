//
// TGStoryArchiveViewController - every story a chat has ever posted.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGStoryArchiveViewController : TGRowsViewController

- (instancetype)initWithChatId:(int64_t)chatId title:(NSString *)title;

@end
