#import "TGRowGeometry.h"

CGFloat TGRowContentWidth(CGFloat tableWidth, BOOL grouped, BOOL legacyInsets) {
	CGFloat width = tableWidth > 0 ? tableWidth : TGMetricScreenWidth;
	if (grouped && legacyInsets)
		width -= 2.0f * TGMetricGroupedInsetLegacy;
	return width;
}

CGRect TGRowStripCellFrame(NSUInteger index, CGFloat width, NSInteger columns,
		CGFloat inset, CGFloat gap, CGFloat rowHeight, CGFloat height) {
	if (columns < 1)
		return CGRectZero;
	CGFloat usable = width - TGDoubled(inset) - gap * (CGFloat)(columns - 1);
	CGFloat side = floorf(usable / (CGFloat)columns);
	return CGRectMake(inset + (CGFloat)index * (side + gap),
			TGCenteredOrigin(rowHeight, height), side, height);
}

CGFloat TGGridContentWidthForTable(CGFloat tableWidth) {
	CGFloat width = tableWidth - TGMetricGridTableMargin;
	return width > 0 ? width : TGMetricScreenWidth - TGMetricGridTableMargin;
}

static CGFloat TGGridCaptionHeight(BOOL captions) {
	return captions ? TGMetricLineCaption + TGMetricPadTiny : 0;
}

CGFloat TGGridRowHeightForCount(CGFloat width, NSInteger columns,
		NSUInteger count, BOOL captions) {
	if (columns < 1)
		columns = 1;
	CGFloat side = TGGridTileSideForWidth(width, columns);
	if (side <= 0)
		return TGMetricRow;
	NSInteger lines = count ? (NSInteger)((count + (NSUInteger)columns - 1) /
			(NSUInteger)columns) : 1;
	return TGMetricGridInset * 2.0f +
			(CGFloat)lines * (side + TGGridCaptionHeight(captions)) +
			(CGFloat)(lines - 1) * TGMetricGridGap;
}

CGRect TGGridTileFrame(NSUInteger index, CGFloat width, NSInteger columns,
		BOOL captions) {
	if (columns < 1)
		columns = 1;
	CGFloat side = TGGridTileSideForWidth(width, columns);
	if (side <= 0)
		return CGRectZero;
	CGFloat caption = TGGridCaptionHeight(captions);
	NSInteger column = (NSInteger)index % columns;
	NSInteger line = (NSInteger)index / columns;
	return CGRectMake(TGMetricGridInset + (CGFloat)column * (side + TGMetricGridGap),
			TGMetricGridInset + (CGFloat)line * (side + caption + TGMetricGridGap),
			side, side + caption);
}

TGRowValueSplit TGRowKeepValueWhole(CGFloat titleX, CGFloat titleWidth,
		CGFloat titleNeed, CGFloat valueRight, CGFloat valueWidth,
		CGFloat valueNeed) {
	TGRowValueSplit split = { titleWidth, valueRight - valueWidth, valueWidth };
	if (valueNeed <= valueWidth)
		return split;
	// A channel's description as the value took the entire row, ran off its
	// left edge and left the title no width at all.
	CGFloat room = valueRight - titleX - TGMetricPadMedium;
	CGFloat titleKeeps = MIN(titleNeed, floorf(TGHalf(room)));
	CGFloat need = MIN(valueNeed, MAX(0, room - titleKeeps));
	split.valueWidth = need;
	split.valueX = valueRight - need;
	split.titleWidth = MAX(0, split.valueX - TGMetricPadMedium - titleX);
	return split;
}
