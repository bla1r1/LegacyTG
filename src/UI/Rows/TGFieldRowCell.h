//
// TGFieldRowCell.h - the one cell that draws a single-line or multiline field.
//
// The row is data (TGRows); this cell owns the UITextField/UITextView, the
// placeholder, the optional prefix and clear button, the official character
// counter, and the theme repaint. TGRowsViewController forwards the table
// lifecycle and keeps typing across a section rebuild.
//
#import <UIKit/UIKit.h>

@class TGFieldRowCell;

@protocol TGFieldRowCellDelegate <NSObject>
@optional
- (void)fieldRowCell:(TGFieldRowCell *)cell didChangeText:(NSString *)text;
- (void)fieldRowCellDidBeginEditing:(TGFieldRowCell *)cell;
- (void)fieldRowCellDidEndEditing:(TGFieldRowCell *)cell;
@end

@interface TGFieldRowCell : UITableViewCell <UITextFieldDelegate, UITextViewDelegate>

@property (nonatomic, weak) id<TGFieldRowCellDelegate> fieldDelegate;
@property (nonatomic, readonly) UITextField *textField;
@property (nonatomic, readonly) UITextView *textView;
@property (nonatomic, copy) NSString *fieldIdentifier;

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;
+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row
					   rowIndex:(NSInteger)rowIndex totalRows:(NSInteger)totalRows;

- (void)configureWithRow:(NSDictionary *)row rowIndex:(NSInteger)rowIndex
			   totalRows:(NSInteger)totalRows;
- (void)applyTheme;
- (void)focus;
- (NSString *)text;

@end

/// A plain caption row, used for an answer under a field (username status).
@interface TGNoteRowCell : UITableViewCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;
+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row;
- (void)configureWithRow:(NSDictionary *)row;
- (void)applyTheme;

@end

/// The edit-profile picture: a round avatar and the Change/Set Photo action.
@interface TGPhotoRowCell : UITableViewCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;
+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row;
- (void)configureWithRow:(NSDictionary *)row;
- (void)applyTheme;

@end

/// A row with a picture on the left and a tick on the right: wallpaper presets.
@interface TGImageCheckRowCell : UITableViewCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;
+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row;
- (void)configureWithRow:(NSDictionary *)row;
- (void)applyTheme;

@end
