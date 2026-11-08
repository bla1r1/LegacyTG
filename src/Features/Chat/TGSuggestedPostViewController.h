//
// TGSuggestedPostViewController.h - one suggested post: its price and date,
// and the two answers Telegram accepts.
//
#import "TGFeatureListViewController.h"

@interface TGSuggestedPostViewController : TGFeatureListViewController

- (instancetype)initWithChatId:(int64_t)chatId messageId:(int64_t)messageId;

@end
