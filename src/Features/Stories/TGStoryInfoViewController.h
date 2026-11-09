//
// TGStoryInfoViewController - who saw, reacted to or forwarded a story, its
// statistics, and the two-step report flow.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

typedef NS_ENUM(NSInteger, TGStoryInfoMode) {
	TGStoryInfoModeInfo = 0,
	TGStoryInfoModeReport
};

@interface TGStoryInfoViewController : TGRowsViewController

/// YES when the viewer adds this controller as a bottom panel over the story
/// instead of presenting it full screen.
@property (nonatomic, assign) BOOL overlayPanel;

- (instancetype)initWithChatId:(int64_t)chatId
					   storyId:(int32_t)storyId
						 story:(NSDictionary *)story
						  mode:(TGStoryInfoMode)mode;

@end
