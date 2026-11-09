//
// TGPictureRowCell.h - the one row with a square picture, two lines and a value.
//
// A profile's Files, Music, Links and Voice panes, a chat's shared media list
// and any other "thumbnail, title, subtitle, trailing" list use this cell. The
// screen hands it the picture; the cell never asks a store or TDLib.
//
#import <UIKit/UIKit.h>

@interface TGPictureRowCell : UITableViewCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;
+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row;

- (void)configureWithRow:(NSDictionary *)row;
- (void)applyTheme;

@end

// vim:ft=objc
