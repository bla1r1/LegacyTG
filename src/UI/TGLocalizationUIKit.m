#import "TGLocalizationUIKit.h"
#import "TGLocalization.h"
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

@implementation UILabel (TGLocalization)
+ (void)load {
	TGLocalizationSwap(self, @selector(setText:), @selector(tg_setText:));
}
- (void)tg_setText:(NSString *)text {
	[self tg_setText:TGLocalizedOrNil(text)];
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
