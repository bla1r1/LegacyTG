//
// TGThemeGridRowCell.h - the 3-column theme grid on Chat Themes.
//
// Same baked cards as the carousel, laid out in lines. The cell owns only the
// layout; TGThemeCardsRowCell owns the picture and its cache.
//
#import <UIKit/UIKit.h>

@interface TGThemeGridRowCell : UITableViewCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;
+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row;

- (void)configureWithRow:(NSDictionary *)row;
- (void)applyTheme;

@end
