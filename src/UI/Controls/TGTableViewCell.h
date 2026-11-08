//
// TGTableViewCell.h - standardized themed table view cell for LegacyTG.
// Automatically styles fonts, colours, disclosure and selection to match TGTheme.
//
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TGTableCellKind) {
	TGTableCellKindDefault,
	TGTableCellKindSubtitle,
	TGTableCellKindValue1,
};

@interface TGTableViewCell : UITableViewCell

/// Fast initialization with one of the standard styles.
+ (instancetype)cellWithStyle:(TGTableCellKind)kind reuseIdentifier:(NSString *)reuse;

/// Text shortcuts that apply proper TGStyle typography and theme colours.
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;

/// Modifiers
@property (nonatomic, assign) BOOL destructive;
@property (nonatomic, assign) BOOL checked;
@property (nonatomic, assign) BOOL showsDisclosure;

/// Attaches an inline UISwitch with a callback.
- (void)setSwitchOn:(BOOL)on onToggle:(void (^)(BOOL on))onToggle;

/// Forces theme reapplication.
- (void)applyTheme;

@end
