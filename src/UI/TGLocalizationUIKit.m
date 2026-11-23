#import "TGLocalizationUIKit.h"
#import "TGMessageLayout.h"
#import "TGTextRender.h"
#import "TGLocalization.h"
#import "TGEmojiPictures.h"
#import <objc/runtime.h>

// UI chrome is translated at the point UIKit receives the text. Message
// bodies are drawn by CoreGraphics, not UILabel, so user content is not
// touched. Screen-sized text that was set before the language pack finished
// loading is caught by TGLocalizeInterface(), which walks the live windows
// once the pack arrives.

static void TGLocalizationSwap(Class cls, SEL original, SEL replacement) {
	Method a = class_getInstanceMethod(cls, original);
	Method b = class_getInstanceMethod(cls, replacement);
	if (a && b)
		method_exchangeImplementations(a, b);
}

static void TGLocalizationSwapClassMethod(Class cls, SEL original, SEL replacement) {
	Method a = class_getClassMethod(cls, original);
	Method b = class_getClassMethod(cls, replacement);
	if (a && b)
		method_exchangeImplementations(a, b);
}

static void TGLocalizeSegmentTitles(UISegmentedControl *control) {
	for (NSUInteger i = 0; i < control.numberOfSegments; i++){
		NSString *title = [control titleForSegmentAtIndex:i];
		if (title.length)
			[control setTitle:TGLocalized(title) forSegmentAtIndex:i];
	}
}

void TGLocalizeViewTree(UIView *view) {
	if (!view)
		return;

	if ([view isKindOfClass:UILabel.class]){
		UILabel *label = (UILabel *)view;
		label.text = TGLocalizedOrNil(label.text);
	}
	if ([view isKindOfClass:UIButton.class]){
		UIButton *button = (UIButton *)view;
		UIControlState states[] = {
			UIControlStateNormal, UIControlStateHighlighted,
			UIControlStateSelected, UIControlStateDisabled,
		};
		for (size_t i = 0; i < sizeof(states) / sizeof(states[0]); i++){
			NSString *title = [button titleForState:states[i]];
			if (title.length)
				[button setTitle:TGLocalized(title) forState:states[i]];
		}
	}
	if ([view isKindOfClass:UITextField.class]){
		UITextField *field = (UITextField *)view;
		field.placeholder = TGLocalizedOrNil(field.placeholder);
	}
	if ([view isKindOfClass:UISearchBar.class]){
		UISearchBar *bar = (UISearchBar *)view;
		bar.placeholder = TGLocalizedOrNil(bar.placeholder);
	}
	if ([view isKindOfClass:UISegmentedControl.class])
		TGLocalizeSegmentTitles((UISegmentedControl *)view);

	for (UIView *subview in view.subviews)
		TGLocalizeViewTree(subview);
}

static void TGLocalizeNavigationItem(UINavigationItem *item) {
	if (!item)
		return;
	item.title = TGLocalizedOrNil(item.title);
	item.prompt = TGLocalizedOrNil(item.prompt);
	item.backBarButtonItem.title = TGLocalizedOrNil(item.backBarButtonItem.title);
}

static void TGLocalizeControllerTree(UIViewController *controller) {
	if (!controller)
		return;
	if (controller.tabBarItem.title.length)
		controller.tabBarItem.title = TGLocalized(controller.tabBarItem.title);
	TGLocalizeNavigationItem(controller.navigationItem);
	// Only touches views that exist: a repaint must not force a screen that
	// has never been shown to load its whole hierarchy.
	if ([controller isViewLoaded])
		TGLocalizeViewTree(controller.view);
	for (UIViewController *child in controller.childViewControllers)
		TGLocalizeControllerTree(child);
	if ([controller isKindOfClass:UINavigationController.class]){
		for (UIViewController *child in [(UINavigationController *)controller viewControllers])
			TGLocalizeControllerTree(child);
		for (UINavigationItem *item in [(UINavigationController *)controller navigationBar].items)
			TGLocalizeNavigationItem(item);
	}
	if ([controller isKindOfClass:UITabBarController.class]){
		for (UIViewController *child in [(UITabBarController *)controller viewControllers])
			TGLocalizeControllerTree(child);
		for (UITabBarItem *item in [(UITabBarController *)controller tabBar].items)
			item.title = TGLocalizedOrNil(item.title);
	}
}

void TGLocalizeInterface(void) {
	UIApplication *app = [UIApplication sharedApplication];
	for (UIWindow *window in app.windows){
		TGLocalizeViewTree(window);
		TGLocalizeControllerTree(window.rootViewController);
	}
}

#pragma mark - labels, buttons, fields

static char kTGFlagSourceKey;
static char kTGFlagLineBreakKey;
static char kTGFlagFontKey;

/// A plain UILabel while it shows a flag the system face lacks: iOS 6 UIKit
/// drew such text with stretched gaps and dropped characters, so this one
/// draws it with TGTextRender (CoreText), which joins the bundled face's
/// flags. No ivars: a label goes in and out of this class by object_setClass.
@interface TGFlagLabel : UILabel
@end

@implementation TGFlagLabel
/// The face the lines are spaced by: the label's own, not the first run's
/// emoji face UIKit gave it.
- (UIFont *)tg_pitchFont {
	return objc_getAssociatedObject(self, &kTGFlagFontKey) ?: self.font;
}

- (CGFloat)tg_linePitch {
	return ceilf([self tg_pitchFont].lineHeight);
}

- (void)drawTextInRect:(CGRect)rect {
	UIFont *face = [self tg_pitchFont];
	TGTextRenderDrawLabel(UIGraphicsGetCurrentContext(), self.attributedText, self.bounds, self.numberOfLines,
			self.textAlignment, [self tg_linePitch], face.ascender, [UIScreen mainScreen].scale);
}

// UIKit measured this text with the emoji face's metrics and gave a two-line
// preview a frame its second line did not fit in. Measured as it is drawn.
- (CGSize)sizeThatFits:(CGSize)size {
	NSUInteger lines = TGTextRenderLineCount(self.attributedText, size.width);
	if (self.numberOfLines > 0)
		lines = MIN(lines, (NSUInteger)self.numberOfLines);
	return CGSizeMake(size.width, lines * [self tg_linePitch]);
}
@end

/// Set while this file itself hands a label its flag text: UIKit then sets
/// the label's font to the first run's, OpenMoji when the text opens with a
/// flag, and taken for the app's own font that set the whole text in it.
static BOOL sApplyingFlags;

/// Leaves flag mode: the source forgotten, the line break and the font the
/// label had before put back (UIKit gave it the first run's face).
static void TGLeaveFlagMode(UILabel *label) {
	objc_setAssociatedObject(label, &kTGFlagSourceKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
	NSNumber *mode = objc_getAssociatedObject(label, &kTGFlagLineBreakKey);
	UIFont *font = objc_getAssociatedObject(label, &kTGFlagFontKey);
	objc_setAssociatedObject(label, &kTGFlagLineBreakKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(label, &kTGFlagFontKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	sApplyingFlags = YES;
	if (mode)
		label.lineBreakMode = (NSLineBreakMode)mode.integerValue;
	if (font)
		label.font = font;
	sApplyingFlags = NO;
	if (object_getClass(label) == TGFlagLabel.class) {
		object_setClass(label, UILabel.class);
		[label setNeedsDisplay];
	}
}

@implementation UILabel (TGLocalization)
+ (void)load {
	TGLocalizationSwap(self, @selector(setText:), @selector(tg_setText:));
	TGLocalizationSwap(self, @selector(setTextColor:), @selector(tg_setTextColor:));
	TGLocalizationSwap(self, @selector(setFont:), @selector(tg_setFont:));
	TGLocalizationSwap(self, @selector(setAttributedText:), @selector(tg_setAttributedText:));
}

- (void)tg_setText:(NSString *)text {
	NSString *shown = TGLocalizedOrNil(text);
	// iOS 6 draws most flags as two boxed letters; any label with one gets
	// it from the bundled emoji face (TGFlagFallbackText). The rest of the
	// text keeps the label's own face, colour and layout.
	UIFont *base = objc_getAssociatedObject(self, &kTGFlagFontKey) ?: self.font;
	NSAttributedString *flags = TGFlagFallbackText(shown, base, self.textColor);
	if (!flags) {
		if (objc_getAssociatedObject(self, &kTGFlagSourceKey) || objc_getAssociatedObject(self, &kTGFlagFontKey))
			TGLeaveFlagMode(self);
		[self tg_setText:shown];
		return;
	}
	objc_setAssociatedObject(self, &kTGFlagFontKey, base, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	sApplyingFlags = YES;
	// iOS 6 lays an attributed string out with a truncating line break on
	// one line, on a path that leaves the flag's two letters unjoined: a
	// two-line chat preview came out one line with two circled letters. A
	// label of more than one line wraps by words while it shows a flag and
	// clips at its last line.
	if (self.numberOfLines != 1 && self.lineBreakMode != NSLineBreakByWordWrapping &&
			!objc_getAssociatedObject(self, &kTGFlagLineBreakKey)) {
		objc_setAssociatedObject(self, &kTGFlagLineBreakKey, @(self.lineBreakMode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		self.lineBreakMode = NSLineBreakByWordWrapping;
	}
	[self tg_setAttributedText:flags];
	sApplyingFlags = NO;
	// Only a plain UILabel: a subclass keeps its own drawing.
	if (object_getClass(self) == UILabel.class) {
		object_setClass(self, TGFlagLabel.class);
		[self setNeedsDisplay];
	}
	objc_setAssociatedObject(self, &kTGFlagSourceKey, shown, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

// A colour or a font the app sets after the text rebuilds an attributed
// label from the label's own properties on iOS 6, the flag's face with it:
// the chat row sets its colour right after its preview.
- (void)tg_setTextColor:(UIColor *)colour {
	[self tg_setTextColor:colour];
	NSString *source = sApplyingFlags ? nil : objc_getAssociatedObject(self, &kTGFlagSourceKey);
	if (source)
		[self tg_setText:source];
}

- (void)tg_setFont:(UIFont *)font {
	[self tg_setFont:font];
	if (sApplyingFlags)
		return;
	NSString *source = objc_getAssociatedObject(self, &kTGFlagSourceKey);
	if (!source) {
		// Not showing a flag: no font to remember beyond the label's own.
		if (objc_getAssociatedObject(self, &kTGFlagFontKey))
			objc_setAssociatedObject(self, &kTGFlagFontKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		return;
	}
	objc_setAssociatedObject(self, &kTGFlagFontKey, font, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[self tg_setText:source];
}

// Attributed text from anyone else replaces the flag text for good.
- (void)tg_setAttributedText:(NSAttributedString *)text {
	if (!sApplyingFlags && objc_getAssociatedObject(self, &kTGFlagSourceKey))
		TGLeaveFlagMode(self);
	// iOS 7 draws emoji from the bundled face's pictures; a label set with
	// attributed text (names with a status, previews) gets them here.
	if (!sApplyingFlags && TGEmojiPicturesActive() && text.length){
		NSAttributedString *pictures = TGEmojiPictureText(text, self.font);
		if (pictures)
			text = pictures;
	}
	[self tg_setAttributedText:text];
}
@end

@implementation UIButton (TGLocalization)
+ (void)load {
	TGLocalizationSwap(self, @selector(setTitle:forState:), @selector(tg_setTitle:forState:));
}
- (void)tg_setTitle:(NSString *)title forState:(UIControlState)state {
	[self tg_setTitle:TGLocalizedOrNil(title) forState:state];
}
@end

@implementation UITextField (TGLocalization)
+ (void)load {
	TGLocalizationSwap(self, @selector(setPlaceholder:), @selector(tg_setPlaceholder:));
}
- (void)tg_setPlaceholder:(NSString *)placeholder {
	[self tg_setPlaceholder:TGLocalizedOrNil(placeholder)];
}
@end

@implementation UISearchBar (TGLocalization)
+ (void)load {
	TGLocalizationSwap(self, @selector(setPlaceholder:), @selector(tg_setPlaceholder:));
}
- (void)tg_setPlaceholder:(NSString *)placeholder {
	[self tg_setPlaceholder:TGLocalizedOrNil(placeholder)];
}
@end

#pragma mark - titles

@implementation UIViewController (TGLocalization)
+ (void)load {
	TGLocalizationSwap(self, @selector(setTitle:), @selector(tg_setTitle:));
}
- (void)tg_setTitle:(NSString *)title {
	[self tg_setTitle:TGLocalizedOrNil(title)];
}
@end

@implementation UINavigationItem (TGLocalization)
+ (void)load {
	TGLocalizationSwap(self, @selector(setTitle:), @selector(tg_setTitle:));
	TGLocalizationSwap(self, @selector(initWithTitle:), @selector(tg_initWithTitle:));
}
- (void)tg_setTitle:(NSString *)title {
	[self tg_setTitle:TGLocalizedOrNil(title)];
}
- (instancetype)tg_initWithTitle:(NSString *)title {
	return [self tg_initWithTitle:TGLocalizedOrNil(title)];
}
@end

@implementation UITabBarItem (TGLocalization)
+ (void)load {
	TGLocalizationSwap(self, @selector(setTitle:), @selector(tg_setTitle:));
	TGLocalizationSwap(self, @selector(initWithTitle:image:tag:),
					   @selector(tg_initWithTitle:image:tag:));
	TGLocalizationSwap(self, @selector(initWithTitle:image:selectedImage:),
					   @selector(tg_initWithTitle:image:selectedImage:));
}
- (void)tg_setTitle:(NSString *)title {
	[self tg_setTitle:TGLocalizedOrNil(title)];
}
- (instancetype)tg_initWithTitle:(NSString *)title image:(UIImage *)image tag:(NSInteger)tag {
	return [self tg_initWithTitle:TGLocalizedOrNil(title) image:image tag:tag];
}
- (instancetype)tg_initWithTitle:(NSString *)title
						   image:(UIImage *)image
				   selectedImage:(UIImage *)selectedImage {
	return [self tg_initWithTitle:TGLocalizedOrNil(title)
							image:image
					selectedImage:selectedImage];
}
@end

@implementation UIBarButtonItem (TGLocalization)
+ (void)load {
	TGLocalizationSwap(self, @selector(setTitle:), @selector(tg_setTitle:));
	TGLocalizationSwap(self, @selector(initWithTitle:style:target:action:),
					   @selector(tg_initWithTitle:style:target:action:));
}
- (void)tg_setTitle:(NSString *)title {
	[self tg_setTitle:TGLocalizedOrNil(title)];
}
- (instancetype)tg_initWithTitle:(NSString *)title
						   style:(UIBarButtonItemStyle)style
						  target:(id)target
						  action:(SEL)action {
	return [self tg_initWithTitle:TGLocalizedOrNil(title) style:style target:target action:action];
}
@end

@implementation UISegmentedControl (TGLocalization)
+ (void)load {
	TGLocalizationSwap(self, @selector(setTitle:forSegmentAtIndex:),
					   @selector(tg_setTitle:forSegmentAtIndex:));
	TGLocalizationSwap(self, @selector(initWithItems:), @selector(tg_initWithItems:));
}
- (void)tg_setTitle:(NSString *)title forSegmentAtIndex:(NSUInteger)segment {
	[self tg_setTitle:TGLocalizedOrNil(title) forSegmentAtIndex:segment];
}
- (instancetype)tg_initWithItems:(NSArray *)items {
	NSMutableArray *localized = [NSMutableArray arrayWithCapacity:items.count];
	for (id item in items){
		[localized addObject:[item isKindOfClass:NSString.class]
				? TGLocalized(item) : item];
	}
	return [self tg_initWithItems:localized];
}
@end

#pragma mark - alerts

@implementation UIAlertAction (TGLocalization)
+ (void)load {
	TGLocalizationSwapClassMethod(self, @selector(actionWithTitle:style:handler:),
								  @selector(tg_actionWithTitle:style:handler:));
}
+ (instancetype)tg_actionWithTitle:(NSString *)title
							 style:(UIAlertActionStyle)style
						   handler:(void (^)(UIAlertAction *))handler {
	return [self tg_actionWithTitle:TGLocalizedOrNil(title) style:style handler:handler];
}
@end

@implementation UIAlertController (TGLocalization)
+ (void)load {
	TGLocalizationSwapClassMethod(self, @selector(alertControllerWithTitle:message:preferredStyle:),
								  @selector(tg_alertControllerWithTitle:message:preferredStyle:));
}
+ (instancetype)tg_alertControllerWithTitle:(NSString *)title
									message:(NSString *)message
							 preferredStyle:(UIAlertControllerStyle)style {
	return [self tg_alertControllerWithTitle:TGLocalizedOrNil(title)
									 message:TGLocalizedOrNil(message)
							  preferredStyle:style];
}
@end
