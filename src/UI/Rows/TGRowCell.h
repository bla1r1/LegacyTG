//
// TGRowCell.h - the one cell family that renders a TGRows row.
//
// Fonts, insets, icon tiles, separators, accessory, selection and theme
// repaint live here so a screen never builds a UITableViewCell by hand.
//
#import <UIKit/UIKit.h>

@interface TGRowCell : UITableViewCell

/// The row's height from TGStyle. The controller forwards here.
+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;

/// Reuses or creates the cell that fits the row's kind and returns it ready.
+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row
					   rowIndex:(NSInteger)rowIndex
					   totalRows:(NSInteger)totalRows;

/// Applies the row's fonts, colours, accessory and toggle block.
- (void)configureWithRow:(NSDictionary *)row
				rowIndex:(NSInteger)rowIndex
			   totalRows:(NSInteger)totalRows;

/// Repaints from the row the cell last rendered.
- (void)applyTheme;

/// The appended options: TGRowDetailColour, TGRowCentred, the raw-text flags
/// and an image accessory. Applied after the row's own configure so a screen
/// never paints its labels.
- (void)applyAppendedOptions:(NSDictionary *)row;

@end
