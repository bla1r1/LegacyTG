//
// TGRowsDataSource.h - the rendering half of TGRowsViewController.
//
// A screen that is not a table controller can still describe sections of
// TGRows and hand them to this object: it answers the table with counts,
// heights, cells and selection. TGRowsViewController keeps its own table
// methods so the screens already using it do not change; a new screen uses
// this object instead.
//
#import <Foundation/Foundation.h>
#include <TargetConditionals.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

/// The counts and heights of the row model without a table. Pure, so a host
/// test can pin them. A nil or malformed section answers zero, not a crash.
NSInteger TGRowsDataSourceSectionCount(NSArray *sections);
NSInteger TGRowsDataSourceRowCount(NSArray *sections, NSInteger section);
NSDictionary *TGRowsDataSourceRow(NSArray *sections, NSInteger section,
		NSInteger row);

/// The height the shared cells would return for `row` at `width`. A negative
/// result means the row needs a measured cell (a field, a note, a wrapping
/// title) and the data source asks that cell class.
CGFloat TGRowsDataSourceHeight(NSDictionary *row, CGFloat width);

#ifdef __cplusplus
}
#endif

#if TARGET_OS_IPHONE

@interface TGRowsDataSource : NSObject <UITableViewDataSource, UITableViewDelegate>

/// "header", "footer" and "rows", the same shape TGRowsViewController takes.
@property (nonatomic, strong) NSArray *sections;

/// The table this object answers for. Set by -initWithTableView:.
@property (nonatomic, weak, readonly) UITableView *tableView;

/// Sets itself as the table's data source and delegate. A screen may use the
/// object without a table (to prepare sections) and attach it later.
- (instancetype)initWithTableView:(UITableView *)tableView;

- (void)reloadRows;
- (NSDictionary *)rowAtIndexPath:(NSIndexPath *)indexPath;

@end

#endif

// vim:ft=objc
