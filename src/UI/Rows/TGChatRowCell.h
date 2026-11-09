//
// TGChatRowCell.h - the one row that draws a conversation.
//
// The chat list used to grow this cell beside its table; it is the list row
// every client has: a picture, a name with a status badge, a date, two lines
// of preview, and the unread/pin marks at the trailing edge. Screens hand it a
// TGKindChatRow and nothing else; the archive and Saved Messages rows are two
// variants of the same kind.
//
#import <UIKit/UIKit.h>
#import "TGStyle.h"
#import "TGRows.h"

static const CGFloat kRowHeight = TGMetricChatRow;
static const CGFloat kAvatar    = TGMetricChatAvatar;

@interface TGChatRowCell : UITableViewCell

/// The row height: every chat row is TGMetricChatRow.
+ (CGFloat)heightForRow:(NSDictionary *)row;

/// Dequeues, configures and returns the cell in one call.
+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row;

/// The same configuration for a cell instance the caller already owns.
- (void)configureWithRow:(NSDictionary *)row;

/// Repaints from the row the cell last drew.
- (void)applyTheme;

/// Boxes the row's trailing accessories (TGChatRowAccessories) for
/// TGRowChatLayout. The controller calls this once per row so the cell's
/// -layoutSubviews only applies frames, never runs the geometry again.
+ (NSValue *)accessoriesValueForRow:(NSDictionary *)row width:(CGFloat)width;

/// The table's own row actions start at iOS 8. Before that the list swipes a
/// row itself: three trailing buttons (Pin, Mute, Delete) on a left swipe,
/// and one leading button (Read/Unread) on a right swipe.
- (void)revealSwipeActionsWithTrailingTitles:(NSArray *)trailingTitles
                             trailingColours:(NSArray *)trailingColours
                               leadingTitles:(NSArray *)leadingTitles
                              leadingColours:(NSArray *)leadingColours
                                      target:(id)target
                                      action:(SEL)action;
- (void)revealSwipeActionsWithTitles:(NSArray *)titles
                             colours:(NSArray *)colours
                              target:(id)target
                              action:(SEL)action;
- (void)setSwipeActionsOffset:(CGFloat)offset;
- (void)openTrailingSwipeActionsAnimated:(BOOL)animated;
- (void)openLeadingSwipeActionsAnimated:(BOOL)animated;
- (void)openSwipeActionsAnimated:(BOOL)animated;
- (void)closeSwipeActionsAnimated:(BOOL)animated;
/// The side the emoji status is drawn at, to ask the store for that size.
+ (CGFloat)statusSide;
@property (nonatomic, readonly) BOOL swipeActionsOpen;
@property (nonatomic, readonly) CGFloat swipeActionsWidth;
@property (nonatomic, readonly) CGFloat trailingActionsWidth;
@property (nonatomic, readonly) CGFloat leadingActionsWidth;

@end
