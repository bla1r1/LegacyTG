//
// TGDMTopicViewController - one topic in a channel direct messages chat:
// the topic record, its history, and the actions Telegram allows on it.
//
#import <UIKit/UIKit.h>
#import "TGTableViewController.h"

@interface TGDMTopicViewController : TGTableViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t topicId;
@property (nonatomic, strong) NSDictionary *topic;
@property (nonatomic, copy)   NSString *chatTitle;

@end
