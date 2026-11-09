//
// TGStoryStripRowCell.h - the horizontal story strip above a list.
//
// The cell owns only its drawing: the screen hands it a TGKindStoryStrip row
// whose item dictionaries already carry a decoded avatar, because a view that
// reached for TGClient would be a second place that knows how avatars are
// fetched. The chat list uses it now; the profile can hand it the same row.
//
#import <UIKit/UIKit.h>
#import "TGRows.h"

@interface TGStoryStripRowCell : UITableViewCell

/// The strip's height.
+ (CGFloat)heightForRow:(NSDictionary *)row;

/// Allocates and configures one for a table header, where no reuse pool exists.
+ (instancetype)cellForRow:(NSDictionary *)row;

/// Dequeues, configures and returns the cell in one call.
+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row;

- (void)configureWithRow:(NSDictionary *)row;

/// Repaints from the row the cell last drew.
- (void)applyTheme;

@end
