//
// TGThemeCardsRowCell.h - the horizontal theme carousel and the baked card.
//
// The Appearance page and the Chat Themes page draw the same card; this file
// owns that drawing and its cache. The grid cell asks for the same picture.
//
#import <UIKit/UIKit.h>

/// One theme card, baked per size and selection state.
UIImage *TGAppearanceThemeCardImage(NSDictionary *entry, BOOL selected,
		CGSize size, BOOL showsName);

@interface TGThemeCardsRowCell : UITableViewCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;
+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row;

- (void)configureWithRow:(NSDictionary *)row;
- (void)applyTheme;

@end
