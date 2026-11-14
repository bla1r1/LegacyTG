//
// TGPageHeaderRowCell.h - TGKindPageHeader: a TGPageHeaderView as the first
// row of a page, with no card behind it.
//
#import <UIKit/UIKit.h>

@interface TGPageHeaderRowCell : UITableViewCell
+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;
+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row;
@end
