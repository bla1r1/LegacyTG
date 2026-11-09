//
// TGProfileHeaderRowCell.h - the account header row: avatar, name, handle.
//
// Settings' top row and any other account card share this drawing. The screen
// supplies the decoded avatar or a loader; the cell never asks TDLib itself.
//
#import <UIKit/UIKit.h>

@interface TGProfileHeaderRowCell : UITableViewCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;
+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row;

- (void)configureWithRow:(NSDictionary *)row;
- (void)applyTheme;

@end
