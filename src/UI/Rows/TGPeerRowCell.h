//
// TGPeerRowCell.h - the one row that draws a person or a chat.
//
// Nine screens grew their own version of this: picture, name, one line under
// it and one accessory. This cell owns the avatar lookup, the emoji status
// after the name, the online subtitle colour and the row's single re-draw
// when a picture arrives. Screens hand it a TGPeerRow and nothing else.
//
#import <UIKit/UIKit.h>

@interface TGPeerRowCell : UITableViewCell

/// The row height: TGRowHeight when the screen set one, otherwise the
/// shared person row height.
+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;

/// Dequeues, configures and returns the cell in one call.
+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row;

/// The same configuration for a subclass that already owns a cell instance.
- (void)configureWithRow:(NSDictionary *)row inTable:(UITableView *)tableView;

/// Repaints from the row the cell last drew.
- (void)applyTheme;

@end
