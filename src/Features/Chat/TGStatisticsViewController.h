//
// TGStatisticsViewController.h - a channel's or a group's statistics:
// the overview numbers, then official's graph sections in its order.
//
#import "TGRowsViewController.h"

@interface TGStatisticsViewController : TGRowsViewController

/// `rows` are the store's answer: number rows ("title", "detail") and graph
/// rows ("title" is the section, "graph" TDLib's StatisticalGraph).
- (instancetype)initWithChatId:(int64_t)chatId rows:(NSArray *)rows;

@end
