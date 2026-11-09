//
// TGMessageResultRowCell.h - the official ChatListSearch message item.
//
// A message hit is not a chat row: the name sits above the hit text and the
// date sits at the trailing edge of the name. One cell draws that shape for
// global search and public post search.
//
#import <UIKit/UIKit.h>

@interface TGMessageResultRowCell : UITableViewCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;
+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row;
- (void)applyTheme;

@end
