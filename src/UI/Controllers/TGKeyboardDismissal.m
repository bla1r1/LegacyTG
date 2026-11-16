//
// TGKeyboardDismissal.m
//
#import "TGKeyboardDismissal.h"
#import <objc/runtime.h>

static char TGKeyboardDismisserKey;

/// Target and gesture delegate, owned by the scroll view it serves.
@interface TGKeyboardDismisser : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIScrollView *scrollView;
@end

@implementation TGKeyboardDismisser

- (void)dismiss {
	[self.scrollView.window endEditing:YES];
}

- (void)panned:(UIPanGestureRecognizer *)pan {
	if (pan.state == UIGestureRecognizerStateBegan)
		[self dismiss];
}

/// A tap on something that takes the keyboard is that thing's own: ending
/// editing there would drop the keyboard the field had just asked for.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
	(void)recognizer;
	for (UIView *view = touch.view; view && view != self.scrollView; view = view.superview)
		if ([view isKindOfClass:UIControl.class] || [view isKindOfClass:UITextView.class] ||
				[view isKindOfClass:UISearchBar.class])
			return NO;
	return YES;
}

/// Row selection and the table's own recognizers keep working alongside.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer
		shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
	(void)recognizer; (void)other;
	return YES;
}

@end

void TGInstallKeyboardDismissal(UIScrollView *scrollView) {
	if (!scrollView || objc_getAssociatedObject(scrollView, &TGKeyboardDismisserKey))
		return;
	TGKeyboardDismisser *dismisser = [[TGKeyboardDismisser alloc] init];
	dismisser.scrollView = scrollView;
	objc_setAssociatedObject(scrollView, &TGKeyboardDismisserKey, dismisser, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	if ([scrollView respondsToSelector:@selector(setKeyboardDismissMode:)])
		scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
	else
		[scrollView.panGestureRecognizer addTarget:dismisser action:@selector(panned:)];

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:dismisser action:@selector(dismiss)];
	tap.cancelsTouchesInView = NO;
	tap.delegate = dismisser;
	[scrollView addGestureRecognizer:tap];
}
