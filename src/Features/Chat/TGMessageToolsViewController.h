//
// TGMessageToolsViewController.h - the per-message half of the Tier 2 tools:
// checklists, suggested posts, fact checks and the AI/rich calls that read
// one message.
//
#import "TGFeatureListViewController.h"

@interface TGMessageToolsViewController : TGFeatureListViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t messageId;
@property (nonatomic, copy) NSString *messageText;
@property (nonatomic, assign) BOOL isChecklist;
@property (nonatomic, assign) BOOL hasSuggestedPost;
@property (nonatomic, copy) NSString *factCheck;
@property (nonatomic, copy) NSString *chatTitle;

@end
