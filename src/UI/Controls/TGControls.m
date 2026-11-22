//
// TGControls.m
//
#import "TGControls.h"
#import <QuartzCore/QuartzCore.h>
#import "TGIcons.h"
#import "TGStyle.h"
#import "TGTheme.h"
#import "TGLocalization.h"

UIButton *TGGlyphButton(UIImage *image, CGRect frame, id target, SEL action) {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.frame = frame;
	if (image)
		[button setImage:image forState:UIControlStateNormal];
	if (action)
		[button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

UIButton *TGTextButton(NSString *title, UIFont *font, id target, SEL action) {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.titleLabel.font = font;
	if (title)
		[button setTitle:title forState:UIControlStateNormal];
	if (action)
		[button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

UIButton *TGRoundGlyphButton(NSString *glyph, UIColor *fill, CGFloat side, CGFloat glyphSide,
		NSString *label, id target, SEL action) {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.frame = CGRectMake(0, 0, side, side);
	[button setBackgroundImage:[TGTheme skeuomorphicButtonImageWithColor:fill
			height:side highlighted:NO cornerRadius:TGHalf(side)]
			forState:UIControlStateNormal];
	[button setBackgroundImage:[TGTheme skeuomorphicButtonImageWithColor:fill
			height:side highlighted:YES cornerRadius:TGHalf(side)]
			forState:UIControlStateHighlighted];
	[button setImage:[TGIcons glyphNamed:glyph colour:[[TGTheme shared] onAccentColour]
			side:glyphSide] forState:UIControlStateNormal];
	button.adjustsImageWhenHighlighted = NO;
	button.accessibilityLabel = TGLocalized(label);
	[button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

UIButton *TGAccentButton(NSString *title, UIFont *font, id target, SEL action) {
	TGTheme *theme = [TGTheme shared];
	UIButton *button = TGTextButton(title, font, target, action);
	[button setTitleColor:[theme onAccentColour] forState:UIControlStateNormal];
	button.backgroundColor = [theme accentColour];
	button.layer.cornerRadius = TGMetricCornerControl;
	return button;
}

UIButton *TGPlateButton(CGFloat height, id target, SEL action) {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	[button setBackgroundImage:[TGTheme skeuomorphicButtonImageWithColor:
			[[TGTheme shared] accentColour] height:height
			highlighted:YES cornerRadius:TGMetricCornerNone]
			forState:UIControlStateHighlighted];
	if (action)
		[button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

void TGPillPaint(UIButton *pill, BOOL active) {
	TGTheme *theme = [TGTheme shared];
	if (active){
		[pill setBackgroundColor:[theme accentColour]];
		[pill setTitleColor:[theme onAccentColour] forState:UIControlStateNormal];
		pill.layer.borderWidth = TGMetricBorderNone;
	} else {
		[pill setBackgroundColor:[theme cardBackgroundColour]];
		[pill setTitleColor:[theme primaryTextColour] forState:UIControlStateNormal];
		pill.layer.borderWidth = TGMetricHairline;
		pill.layer.borderColor = [theme separatorColour].CGColor;
	}
}

UIButton *TGPillButton(NSString *title, UIFont *font, CGRect frame, BOOL active,
		id target, SEL action) {
	UIButton *pill = TGTextButton(title, font, target, action);
	pill.frame = frame;
	pill.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	pill.layer.cornerRadius = TGHalf(frame.size.height);
	TGPillPaint(pill, active);
	return pill;
}

UITextView *TGReaderTextView(CGRect frame) {
	UITextView *view = [[UITextView alloc] initWithFrame:frame];
	view.editable = NO;
	if ([view respondsToSelector:@selector(setSelectable:)])
		view.selectable = YES;
	view.font = TGFontBody();
	return view;
}

UITextView *TGEditorTextView(CGRect frame) {
	UITextView *view = [[UITextView alloc] initWithFrame:frame];
	view.font = TGFontBody();
	return view;
}

UITextField *TGKeyCatcher(UIKeyboardType keyboard, id target, SEL changed) {
	UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
	field.keyboardType = keyboard;
	[field addTarget:target action:changed forControlEvents:UIControlEventEditingChanged];
	return field;
}

UISwitch *TGSwitchMake(BOOL on, id target, SEL changed) {
	UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0,
			TGMetricSwitchW, TGMetricSwitchH)];
	toggle.on = on;
	[toggle addTarget:target action:changed forControlEvents:UIControlEventValueChanged];
	return toggle;
}

UISlider *TGStepSlider(CGRect frame, NSInteger steps, NSInteger step, id target, SEL changed) {
	UISlider *slider = [[UISlider alloc] initWithFrame:frame];
	slider.minimumValue = 0;
	slider.maximumValue = steps - 1;
	slider.value = (float)step;
	if ([slider respondsToSelector:@selector(setMinimumTrackTintColor:)])
		slider.minimumTrackTintColor = [[TGTheme shared] accentColour];
	slider.continuous = YES;
	[slider addTarget:target action:changed forControlEvents:UIControlEventValueChanged];
	return slider;
}

UIActivityIndicatorView *TGSpinnerMake(void) {
	UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	spinner.hidesWhenStopped = YES;
	return spinner;
}

UIView *TGComposerStripView(CGRect frame) {
	UIView *strip = [[UIView alloc] initWithFrame:frame];
	strip.backgroundColor = [[TGTheme shared] inputBarColour];
	UIImageView *gloss = [[UIImageView alloc] initWithFrame:strip.bounds];
	gloss.image = [TGTheme skeuomorphicInputBarImageWithHeight:frame.size.height];
	gloss.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[strip addSubview:gloss];
	UIView *hair = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width,
			TGMetricBorderWidth)];
	hair.backgroundColor = [[TGTheme shared] composerHairlineColour];
	hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[strip addSubview:hair];
	return strip;
}

void TGMotionQuick(void (^changes)(void), void (^done)(BOOL finished)) {
	[UIView animateWithDuration:TGAnimationDurationFast animations:changes completion:done];
}

void TGMotionLift(void (^changes)(void), void (^done)(BOOL finished)) {
	[UIView animateWithDuration:TGAnimationDurationFast delay:0
			options:UIViewAnimationOptionCurveEaseOut animations:changes completion:done];
}

void TGMotionSheet(void (^changes)(void), void (^done)(BOOL finished)) {
	[UIView animateWithDuration:TGAnimationDurationNormal animations:changes completion:done];
}
