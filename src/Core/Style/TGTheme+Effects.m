//
// TGTheme+Effects - depth: glass, shadows, gloss, bevels.
//
// This is the file to read when something looks "frosted" or "embossed".
//
// There is deliberately no GPU blur anywhere (no UIVisualEffectView, no
// CoreImage): this app targets A5/A6 chips where an offscreen blur eats the
// whole frame budget (DESIGN_SPEC.md, performance section). Frost and glass
// are imitated with translucent flat colours instead - the callout family
// below is a full kit for that: the plate, its recessed tray, hairline
// border, etched dividers and the two-stop gloss reflection.
//
// Drawing those materials onto pixels is the engine's job (TGTheme+Drawing.m).
//
#import "TGThemeInternal.h"
#import "TGStyle.h"

#define rgb TGThemeRGB

@implementation TGTheme (Effects)

#pragma mark - frosted glass (the "blur" substitute)

- (UIColor *)calloutBackgroundColour {
	///< the satin glass plate behind popup callouts and reaction bars
	// iOS 6 authentic dark satin glass for callout menus
	return [UIColor colorWithRed:0x1C / 255.0f green:0x1D / 255.0f blue:0x21 / 255.0f alpha:0.95f];
}

- (UIColor *)calloutTrayColour {
	///< recessed dark well for reactions
	return [UIColor colorWithWhite:0.0f alpha:0.25f];
}

- (UIColor *)calloutBorderColour {
	return [UIColor colorWithWhite:1.0f alpha:0.18f];
}

- (UIColor *)calloutDividerDarkColour {
	///< etched dark groove
	return [UIColor colorWithWhite:0.0f alpha:0.50f];
}

- (UIColor *)calloutDividerLightColour {
	///< etched specular highlight
	return [UIColor colorWithWhite:1.0f alpha:0.12f];
}

- (UIColor *)calloutTextColour {
	return [UIColor whiteColor];
}

- (UIColor *)calloutTextShadowColour {
	return [UIColor colorWithWhite:0.0f alpha:0.6f];
}

- (UIColor *)calloutIconColour {
	return [UIColor colorWithWhite:0.92f alpha:1.0f];
}

- (UIColor *)calloutGlossTopColour {
	///< specular top reflection for callout popup menu
	if ([self isDark])
		return [UIColor colorWithWhite:1.0f alpha:0.04f];
	return TGRole(@"calloutGlossTop", [UIColor colorWithWhite:1.0f alpha:0.65f]);
}

- (UIColor *)calloutGlossBottomColour {
	///< specular fade for callout popup menu
	if ([self isDark])
		return [UIColor clearColor];
	return TGRole(@"calloutGlossBottom", [UIColor colorWithWhite:1.0f alpha:0.10f]);
}

#pragma mark - shadows and etching

- (UIColor *)skeuoShineColour {
	return [UIColor colorWithWhite:1.0f alpha:0.18f];   ///< shine on iOS 6 buttons
}

// Both text shadows are an iOS 6 habit. Clear from iOS 7, so the many labels
// that set them (bubbles, titles, captions) go flat without each one asking.
- (UIColor *)etchedTextShadowColour {
	if (![TGTheme drawsSkeuomorphicChrome])
		return [UIColor clearColor];
	return [UIColor colorWithWhite:1.0f alpha:0.7f];    ///< light drop shadow under text
}

- (UIColor *)navBarTextShadowColour {
	if (![TGTheme drawsSkeuomorphicChrome])
		return [UIColor clearColor];
	return [UIColor colorWithWhite:0.0f alpha:0.4f];    ///< dark shadow under nav titles
}

- (UIColor *)buttonHighlightColour {
	return [[self accentColour] colorWithAlphaComponent:0.4f];
}

#pragma mark - bubble bevels and geometry

- (UIColor *)skeuoBubbleMineBorderColour {
	///< soft celestial blue stroke in light, hairline blue-white in dark
	if ([self isDark]) return [self bubbleBorderColour];
	return rgb(0x99, 0xC4, 0xE8);
}

- (UIColor *)skeuoBubbleTheirsBorderColour {
	///< tactile outer border on theirs
	if ([self isDark]) return [self bubbleBorderColour];
	return rgb(0xB0, 0xB0, 0xB6);
}

- (CGFloat)bubbleCornerRadius {
	return TGMetricCornerBubbleSkeuo;
}

- (CGFloat)bubbleJoinedCornerRadius {
	return TGMetricCornerBubbleJoined;
}

- (CGFloat)bubbleBorderWidth {
	return TGMetricBorderWidth;         ///< 0 when flat
}

@end

// vim:ft=objc
