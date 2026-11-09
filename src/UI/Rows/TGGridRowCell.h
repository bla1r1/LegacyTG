//
// TGGridRowCell.h - one table row of square picture tiles.
//
// The cell draws what a TGGridRow carries: pictures (or a coloured placeholder
// with initials), a check, a lock, a badge and a caption. It never asks TDLib
// for anything; the screen hands it images already decoded by the store that
// owns them.
//
#import <UIKit/UIKit.h>
#include <TargetConditionals.h>
#import "TGStyle.h"

#ifdef __cplusplus
extern "C" {
#endif

/// How many tiles fit across `width` at `minimumTile` points. The gap and the
/// cell inset come from TGStyle, so every grid in the app breaks its line at
/// the same width.
static inline NSInteger TGGridColumnsForWidth(CGFloat width,
		CGFloat minimumTile) {
	if (width <= 0 || minimumTile <= 0)
		return 1;
	CGFloat usable = width - TGMetricGridInset * 2.0f;
	if (usable <= 0)
		return 1;
	NSInteger columns = (NSInteger)floorf((usable + TGMetricGridGap) /
			(minimumTile + TGMetricGridGap));
	if (columns < 1)
		columns = 1;
	if (columns > TGMetricGridMaxColumns)
		columns = TGMetricGridMaxColumns;
	return columns;
}

/// The side of one square tile in a line of `columns`, after the cell inset
/// and the gaps. Rounded down so a fractional point never overflows the card.
static inline CGFloat TGGridTileSideForWidth(CGFloat width,
		NSInteger columns) {
	if (columns < 1)
		return 0;
	CGFloat usable = width - TGMetricGridInset * 2.0f -
			(CGFloat)(columns - 1) * TGMetricGridGap;
	if (usable <= 0)
		return 0;
	return floorf(usable / (CGFloat)columns);
}

/// The row height for a line of tiles. A caption adds one line under the
/// square; without one the row is just the tile plus the card's inset.
static inline CGFloat TGGridRowHeightForWidth(CGFloat width,
		NSInteger columns, BOOL captions) {
	CGFloat side = TGGridTileSideForWidth(width, columns);
	if (side <= 0)
		return TGMetricRow;
	return side + TGMetricGridInset * 2.0f +
			(captions ? TGMetricLineCaption + TGMetricPadTiny : 0);
}

/// The tile under a point in the cell's content coordinates. NSNotFound for
/// the gap between two tiles, the inset, or past the last tile.
static inline NSInteger TGGridIndexAtPoint(CGPoint point, CGFloat width,
		NSInteger columns, NSInteger count) {
	if (columns < 1 || count <= 0)
		return NSNotFound;
	CGFloat side = TGGridTileSideForWidth(width, columns);
	if (side <= 0)
		return NSNotFound;
	CGFloat localX = point.x - TGMetricGridInset;
	CGFloat localY = point.y - TGMetricGridInset;
	if (localX < 0 || localY < 0 || localY > side)
		return NSNotFound;
	CGFloat pitch = side + TGMetricGridGap;
	NSInteger column = (NSInteger)floorf(localX / pitch);
	if (column < 0 || column >= columns)
		return NSNotFound;
	CGFloat offset = localX - (CGFloat)column * pitch;
	if (offset > side)
		return NSNotFound;
	return column < count ? column : NSNotFound;
}

#ifdef __cplusplus
}
#endif

#if TARGET_OS_IPHONE
@interface TGGridRowCell : UITableViewCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView;
+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row;

- (void)configureWithRow:(NSDictionary *)row;
- (void)applyTheme;

@end
#endif

// vim:ft=objc
