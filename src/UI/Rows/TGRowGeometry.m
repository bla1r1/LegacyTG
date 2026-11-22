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

CGRect TGGridSelectedMarkFrame(CGFloat side) {
	CGFloat mark = MAX(0, MIN(TGMetricGridSelectedMark,
			side - TGDoubled(TGMetricPadLarge)));
	return CGRectMake(TGCenteredOrigin(side, mark), TGCenteredOrigin(side, mark),
			mark, mark);
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
	// The side is rounded down; the points that leaves are split between the
	// two margins instead of all landing on the right (D19).
	CGFloat used = (CGFloat)columns * side + (CGFloat)(columns - 1) * TGMetricGridGap;
	CGFloat left = TGMetricGridInset + floorf(TGHalf(width - TGDoubled(TGMetricGridInset) - used));
	return CGRectMake(left + (CGFloat)column * (side + TGMetricGridGap),
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

CGFloat TGCentredStackTextWidth(CGFloat width) {
	return MAX(0, width - TGDoubled(TGMetricPadWide));
}

TGCentredStack TGCentredStackPlace(CGFloat width, CGFloat top,
		CGFloat artSide, CGFloat titleHeight, CGFloat subtitleHeight,
		CGFloat textHeight, CGSize button) {
	TGCentredStack s = {CGRectZero, CGRectZero, CGRectZero, CGRectZero, CGRectZero, 0};
	CGFloat lineWidth = TGCentredStackTextWidth(width);
	CGFloat y = top;
	BOOL any = NO;
	if (artSide > 0){
		s.art = CGRectMake(TGCenteredOrigin(width, artSide), y, artSide, artSide);
		y += artSide;
		any = YES;
	}
	if (titleHeight > 0){
		y += any ? TGMetricPadMedium : 0;
		s.title = CGRectMake(TGMetricPadWide, y, lineWidth, titleHeight);
		y += titleHeight;
		any = YES;
	}
	if (subtitleHeight > 0){
		// The subtitle belongs to the title: no gap when there is one.
		y += (any && titleHeight <= 0) ? TGMetricPadMedium : 0;
		s.subtitle = CGRectMake(TGMetricPadWide, y, lineWidth, subtitleHeight);
		y += subtitleHeight;
		any = YES;
	}
	if (textHeight > 0){
		y += any ? TGMetricPad : 0;
		s.text = CGRectMake(TGMetricPadWide, y, lineWidth, textHeight);
		y += textHeight;
		any = YES;
	}
	if (button.width > 0 && button.height > 0){
		y += any ? TGMetricPadLarge : 0;
		s.button = CGRectMake(TGCenteredOrigin(width, button.width), y,
				button.width, button.height);
		y += button.height;
	}
	s.height = y - top + TGMetricPadLarge;
	return s;
}

TGCentredStack TGEmptyStatePlace(CGSize size, CGFloat artSide,
		CGFloat titleHeight, CGFloat subtitleHeight, CGSize button) {
	TGCentredStack probe = TGCentredStackPlace(size.width, 0, artSide, titleHeight,
			subtitleHeight, 0, button);
	CGFloat content = probe.height - TGMetricPadLarge;
	CGFloat top = MAX(TGMetricPadWide, TGCenteredOrigin(size.height, content));
	return TGCentredStackPlace(size.width, top, artSide, titleHeight,
			subtitleHeight, 0, button);
}
