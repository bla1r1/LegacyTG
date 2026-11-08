//
// TGStoryAlbumsViewController - the album list and the album's stories.
//
#import <UIKit/UIKit.h>
#import "TGTableViewController.h"

@interface TGStoryAlbumsViewController : TGTableViewController

/// `storyToAdd` is an existing story the viewer wants in an album; 0 opens
/// the manager in its ordinary form.
- (instancetype)initWithChatId:(int64_t)chatId storyToAdd:(int32_t)storyId;

@end
