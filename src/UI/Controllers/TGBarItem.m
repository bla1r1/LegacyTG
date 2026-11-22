//
// TGBarItem.m
//
#import "TGBarItem.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGLocalization.h"

@implementation TGBarItem

// Titles go in as English: UIBarButtonItem (TGLocalization) translates every
// initWithTitle: on the way in.
+ (UIBarButtonItem *)itemWithRole:(TGBarRole)role target:(id)target action:(SEL)action {
	if (TGBarRoleIsSystemItem(role)){
		UIBarButtonSystemItem system = role == TGBarRoleSearch ? UIBarButtonSystemItemSearch
				: role == TGBarRoleCompose ? UIBarButtonSystemItemCompose
				: UIBarButtonSystemItemAdd;
		UIBarButtonItem *item = [[UIBarButtonItem alloc]
				initWithBarButtonSystemItem:system target:target action:action];
		item.accessibilityLabel = TGLocalized(TGBarRoleLabel(role));
		return item;
	}
	NSString *glyph = TGBarRoleGlyph(role);
	if (glyph && TGBarRoleIsBare(role)){
		CGFloat side = TGMetricButtonMediumH;
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.frame = CGRectMake(0, 0, side, side);
		[button setImage:[TGIcons glyphNamed:glyph
				colour:[[TGTheme shared] barButtonColour] side:side]
				forState:UIControlStateNormal];
		[button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
		button.accessibilityLabel = TGLocalized(TGBarRoleLabel(role));
		return [self itemWithView:button];
	}
	if (glyph)
		return [self itemWithGlyph:glyph label:TGBarRoleLabel(role)
							target:target action:action];
	return [self itemWithTitle:TGBarRoleTitle(role) primary:TGBarRoleIsPrimary(role)
						target:target action:action];
}

+ (UIBarButtonItem *)itemWithTitle:(NSString *)title
						   primary:(BOOL)primary
							target:(id)target
							action:(SEL)action {
	return [[UIBarButtonItem alloc] initWithTitle:title
			style:primary ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered
		   target:target action:action];
}

+ (UIBarButtonItem *)plainItemWithTitle:(NSString *)title
								target:(id)target
								action:(SEL)action {
	return [[UIBarButtonItem alloc] initWithTitle:title
			style:UIBarButtonItemStylePlain target:target action:action];
}

+ (UIBarButtonItem *)itemWithGlyph:(NSString *)glyph
							 label:(NSString *)label
							target:(id)target
							action:(SEL)action {
	UIImage *image = [TGIcons glyphNamed:glyph
								  colour:[[TGTheme shared] barButtonColour]
									side:TGMetricMenuGlyph];
	return [self itemWithImage:image label:label target:target action:action];
}

+ (UIBarButtonItem *)itemWithImage:(UIImage *)image
							 label:(NSString *)label
							target:(id)target
							action:(SEL)action {
	UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:image
			style:UIBarButtonItemStylePlain target:target action:action];
	item.accessibilityLabel = TGLocalized(label);
	return item;
}

+ (UIBarButtonItem *)itemWithView:(UIView *)view {
	return [[UIBarButtonItem alloc] initWithCustomView:view];
}

+ (UIBarButtonItem *)activityItem {
	UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	[spinner startAnimating];
	return [[UIBarButtonItem alloc] initWithCustomView:spinner];
}

+ (UIBarButtonItem *)flexibleSpace {
	return [[UIBarButtonItem alloc]
			initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
								 target:nil action:nil];
}

+ (void)setRole:(TGBarRole)role
	 onController:(UIViewController *)controller
		   target:(id)target
		   action:(SEL)action {
	UIBarButtonItem *item = [self itemWithRole:role target:target action:action];
	if (TGBarRoleSide(role) == TGBarSideLeft)
		controller.navigationItem.leftBarButtonItem = item;
	else
		controller.navigationItem.rightBarButtonItem = item;
}

+ (CGRect)frameOfItem:(UIBarButtonItem *)item
		 onController:(UIViewController *)controller
				 side:(TGBarSide)side
			   inView:(UIView *)host {
	// -view is not public before iOS 11 but answers on 6 through 12; a
	// custom view is the public way in. Either is a real frame; the corner
	// of the bar is the honest guess when neither is there.
	UIView *view = item.customView;
	if (!view && [item respondsToSelector:@selector(view)]){
		id v = [item valueForKey:@"view"];
		if ([v isKindOfClass:UIView.class])
			view = v;
	}
	if (view.window)
		return [view convertRect:view.bounds toView:host];
	UINavigationBar *bar = controller.navigationController.navigationBar;
	if (!bar)
		return CGRectZero;
	return [bar convertRect:TGBarItemFallbackRect(bar.bounds, side) toView:host];
}

@end
