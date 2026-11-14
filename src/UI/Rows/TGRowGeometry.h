//
// TGRowGeometry.h - the arithmetic of the shared rows, out of the cells so a
// host test can check it.
//
// Two audit defects of 2026-11-14 were here: the swatch and tile grids laid
// out across the table's width instead of the cell's (iOS 6 insets grouped
// cells by 10 pt a side), and a long value took the whole row from its title.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "TGStyle.h"

#ifdef __cplusplus
extern "C" {
#endif

/// The width a cell's content has in a table `tableWidth` wide. Before iOS 7
/// a grouped table insets its cells by TGMetricGroupedInsetLegacy a side.
FOUNDATION_EXPORT CGFloat TGRowContentWidth(CGFloat tableWidth, BOOL grouped,
		BOOL legacyInsets);

/// One of `columns` equal cells across `width`, after `inset` on both sides
/// and `gap` between cells; `height` tall, centred in a row `rowHeight` tall.
FOUNDATION_EXPORT CGRect TGRowStripCellFrame(NSUInteger index, CGFloat width,
		NSInteger columns, CGFloat inset, CGFloat gap, CGFloat rowHeight,
		CGFloat height);

/// The side of one square tile in a line of `columns`, after the cell inset
/// and the gaps. Rounded down so a fractional point never overflows the card.
static inline CGFloat TGGridTileSideForWidth(CGFloat width, NSInteger columns) {
	if (columns < 1)
		return 0;
	CGFloat usable = width - TGMetricGridInset * 2.0f -
			(CGFloat)(columns - 1) * TGMetricGridGap;
	if (usable <= 0)
		return 0;
	return floorf(usable / (CGFloat)columns);
}

/// The content width of a grid cell in a table `tableWidth` wide; the screen
/// width when the table has not been laid out yet.
FOUNDATION_EXPORT CGFloat TGGridContentWidthForTable(CGFloat tableWidth);

/// The height of a grid row of `count` tiles; TGMetricRow when no tile fits.
FOUNDATION_EXPORT CGFloat TGGridRowHeightForCount(CGFloat width,
		NSInteger columns, NSUInteger count, BOOL captions);

/// Tile `index` in a grid `width` wide, caption line included. CGRectZero
/// when no tile fits.
FOUNDATION_EXPORT CGRect TGGridTileFrame(NSUInteger index, CGFloat width,
		NSInteger columns, BOOL captions);

/// A Value1 row's title and value side by side. The value keeps its full
/// width as long as the title keeps its own words or half the row, whichever
/// is less.
typedef struct {
	CGFloat titleWidth;
	CGFloat valueX;
	CGFloat valueWidth;
} TGRowValueSplit;

FOUNDATION_EXPORT TGRowValueSplit TGRowKeepValueWhole(CGFloat titleX,
		CGFloat titleWidth, CGFloat titleNeed, CGFloat valueRight,
		CGFloat valueWidth, CGFloat valueNeed);

/// The centred column every page header and empty state is: a picture, a
/// title, a subtitle under it, a paragraph, a button. A part with no size
/// is left out together with the gap before it, so a header without art or
/// an empty state without a title still sits evenly.
typedef struct {
	CGRect art, title, subtitle, text, button;
	/// From `top` to the bottom of the last part, plus TGMetricPadLarge.
	CGFloat height;
} TGCentredStack;

FOUNDATION_EXPORT TGCentredStack TGCentredStackPlace(CGFloat width, CGFloat top,
		CGFloat artSide, CGFloat titleHeight, CGFloat subtitleHeight,
		CGFloat textHeight, CGSize button);

/// An empty state's column: centred in `height`, never closer to the top
/// than TGMetricPadWide.
FOUNDATION_EXPORT TGCentredStack TGEmptyStatePlace(CGSize size, CGFloat artSide,
		CGFloat titleHeight, CGFloat subtitleHeight, CGSize button);

/// The width a centred line of the column may use.
FOUNDATION_EXPORT CGFloat TGCentredStackTextWidth(CGFloat width);

#ifdef __cplusplus
}
#endif
