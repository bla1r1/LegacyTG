//
// TGSimilarChannelsViewController.h - List of recommended similar channels.
//
#import <UIKit/UIKit.h>
#import "TGTableViewController.h"

@interface TGSimilarChannelsViewController : TGTableViewController

@property (nonatomic, assign) int64_t originalChatId;
@property (nonatomic, strong) NSArray *channelChatIds;

@end
