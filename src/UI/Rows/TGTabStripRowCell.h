//
// TGTabStripRowCell.h - the horizontal tab strip shared by profile panes.
//
// The row carries the tabs (title and kind), the selected kind and its blocks.
// The cell owns the scrolling, selection colour and the underline, and keeps
// its horizontal offset across a table reload.
//
#import <UIKit/UIKit.h>

@interface TGTabStripRowCell : UITableViewCell <UIScrollViewDelegate>

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;
+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row;

- (void)configureWithRow:(NSDictionary *)row;
- (void)applyTheme;

@end

// vim:ft=objc
