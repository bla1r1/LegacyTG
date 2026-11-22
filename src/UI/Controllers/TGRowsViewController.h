//
// TGRowsViewController.h - a grouped table that renders sections of TGRows.
//
// Screens describe rows and hand them over; this controller owns the table,
// heights, selection, toggles and theme repaint.
//
#import <UIKit/UIKit.h>
#import "TGTableViewController.h"
#import "TGPageTemplate.h"

@interface TGRowsViewController : TGTableViewController

/// A screen of a List or Picker kind opens as white rows on the page; the
/// others as cards. `init` is a Settings page.
- (instancetype)initWithPageKind:(TGPageKind)kind;

/// What kind of page this is (R1). scripts/lint_pages.sh fails on a screen
/// that never says. Setting it later does not restyle the table.
@property (nonatomic, assign) TGPageKind pageKind;

/// A plain table's rows stay white on the page colour (List, Picker).
/// initWithPageKind: turns it on for those kinds; a screen that only names
/// its kind keeps the table it always had.
@property (nonatomic, assign) BOOL whiteRowsOnPage;

/// The empty state (R8): when no section has a row and one of these is set,
/// TGEmptyView takes the middle of the page. There is no "None" row.
@property (nonatomic, copy) NSString *emptyTitle;
@property (nonatomic, copy) NSString *emptySubtitle;

/// Each section is "header", "footer" and "rows".
@property (nonatomic, strong) NSArray *sections;

/// A screen whose sections intentionally mix icon and plain rows (Settings
/// does, following the official page) turns the DEBUG consistency assert off.
@property (nonatomic, assign) BOOL checksSectionIcons;

#pragma mark - flat list compatibility

/// The TGListViewController data list, on the shared controller so a migrated
/// screen can subclass TGRowsViewController directly and still hand over a
/// flat list. Entries are "title", "detail", "destructive" (NSNumber BOOL),
/// "opens" (NSNumber BOOL) and "tap" (a block). The name is listRows, not
/// rows: a screen with its own `rows` array must keep it.
@property (nonatomic, strong) NSArray *listRows;
/// The empty state's sentence for a flat list once listRows is set and holds
/// nothing; "None" when unset.
@property (nonatomic, copy) NSString *emptyText;
/// A sentence above the list, always shown when set.
@property (nonatomic, copy) NSString *listFooter;
/// A right bar button that copies the whole list as text.
@property (nonatomic, assign) BOOL offersCopy;

- (void)reloadRows;
- (void)applyTheme;
- (void)toast:(NSString *)text;

/// Field rows: move the keyboard to the row with this identifier (a return key
/// calls it to walk the form), and drop text remembered from a reload.
- (void)focusFieldWithIdentifier:(NSString *)identifier;
- (void)clearStoredFieldText;

@end

#pragma mark - grid rows

/// The same controller with TGKindGrid routing. A grid row is a picture line,
/// not a text row, so its height and cell come from TGGridRowCell. Kept as a
/// subclass so the existing row paths above stay the only ones they ever were.
@interface TGGridRowsViewController : TGRowsViewController
@end
