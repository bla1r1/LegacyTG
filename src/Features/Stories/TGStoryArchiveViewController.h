//
// TGStoryArchiveViewController - every story a chat has ever posted.
//
#import <UIKit/UIKit.h>
#import "TGTableViewController.h"

@interface TGStoryArchiveViewController : TGTableViewController

- (instancetype)initWithChatId:(int64_t)chatId title:(NSString *)title;

@end
