#import "TGLoginLogic.h"
#import "TGStyle.h"

const CGFloat TGLoginNarrowWidth = 360.0f;

BOOL TGLoginUsesBarNext(CGFloat width) {
	return width < TGLoginNarrowWidth;
}

BOOL TGLoginShowsBottomButton(BOOL fieldStep, CGFloat width) {
	return fieldStep && !TGLoginUsesBarNext(width);
}

CGFloat TGLoginYAfterActionRow(CGFloat y, CGFloat width) {
	return TGLoginUsesBarNext(width) ? y : y + TGMetricRow + TGMetricStackStep;
}
