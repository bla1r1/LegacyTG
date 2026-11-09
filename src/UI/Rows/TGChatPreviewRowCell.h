//
// TGChatPreviewRowCell.h - the Appearance sample conversation.
//
// The row is one baked picture: two bubbles, a reply quote, the sender name and
// the timestamps. Drawing happens once per theme, text size and wallpaper.
//
#import <UIKit/UIKit.h>

/// The sample picture at `width`. Exposed so the row height and the cell share
/// the same cache entry.
UIImage *TGAppearancePreviewImage(CGFloat width);

@interface TGChatPreviewRowCell : UITableViewCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;
+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row;

- (void)configureWithRow:(NSDictionary *)row;
- (void)applyTheme;

@end
