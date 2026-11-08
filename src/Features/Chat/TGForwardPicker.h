//
// TGForwardPicker - choose a chat to forward into.
//
#import <UIKit/UIKit.h>

@interface TGForwardPicker : UITableViewController
@property (nonatomic, copy) void (^onPicked)(int64_t chatId);
/// The chat the messages came from; it is not a destination and never appears
/// in the recent strip.
@property (nonatomic, assign) int64_t sourceChatId;
@end
