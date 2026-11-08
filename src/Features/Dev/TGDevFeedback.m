//
// TGDevFeedback.m - see TGDevFeedback.h.
//
#import "TGDevFeedback.h"

#if TG_DEV
#import "TGStyle.h"
#import "TGTheme.h"
#import "TGSnackbar.h"
#import <QuartzCore/QuartzCore.h>

/// Four taps sit outside anything the app itself uses (it stops at double
/// taps), so the trigger cannot be hit by accident while testing a screen.
static const NSUInteger kFeedbackTaps = 4;
static const NSUInteger kFeedbackFingers = 3;

static NSString *TGFeedbackDirectory(void) {
	NSString *caches = [NSSearchPathForDirectoriesInDomains(
			NSCachesDirectory, NSUserDomainMask, YES) firstObject];
	NSString *dir = [caches stringByAppendingPathComponent:@"feedback"];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir
			withIntermediateDirectories:YES attributes:nil error:NULL];
	return dir;
}

static UIViewController *TGFeedbackTopController(UIViewController *vc) {
	while (vc){
		if (vc.presentedViewController)
			vc = vc.presentedViewController;
		else if ([vc isKindOfClass:UINavigationController.class] &&
				((UINavigationController *)vc).topViewController)
			vc = ((UINavigationController *)vc).topViewController;
		else if ([vc isKindOfClass:UITabBarController.class] &&
				((UITabBarController *)vc).selectedViewController)
			vc = ((UITabBarController *)vc).selectedViewController;
		else
			break;
	}
	return vc;
}

#pragma mark - the canvas

@interface TGDevFeedbackCanvas : UIView <UITextFieldDelegate>
@property (nonatomic, strong) UIImage *shot;
@property (nonatomic, copy) NSString *screenClass;
@property (nonatomic, copy) NSString *screenTitle;
@property (nonatomic, strong) NSMutableArray *strokes;   // UIBezierPath
@property (nonatomic, strong) CAShapeLayer *ink;
@property (nonatomic, strong) UITextField *comment;
@property (nonatomic, strong) UIButton *verdictButton;
@property (nonatomic, assign) BOOL good;
@property (nonatomic, strong) UIView *bar;
@end

@implementation TGDevFeedbackCanvas

- (instancetype)initWithFrame:(CGRect)frame shot:(UIImage *)shot {
	if ((self = [super initWithFrame:frame])){
		TGTheme *theme = [TGTheme shared];
		_shot = shot;
		_strokes = [NSMutableArray array];
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth |
				UIViewAutoresizingFlexibleHeight;
		UIImageView *picture = [[UIImageView alloc] initWithFrame:self.bounds];
		picture.image = shot;
		picture.autoresizingMask = self.autoresizingMask;
		[self addSubview:picture];

		_ink = [CAShapeLayer layer];
		_ink.frame = self.bounds;
		_ink.strokeColor = [theme destructiveColour].CGColor;
		_ink.fillColor = nil;
		_ink.lineWidth = TGMetricBorderThick * 2;
		_ink.lineCap = kCALineCapRound;
		_ink.lineJoin = kCALineJoinRound;
		[self.layer addSublayer:_ink];

		[self buildBar];
	}
	return self;
}

- (UIButton *)barButton:(NSString *)title action:(SEL)action {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	[button setTitle:title forState:UIControlStateNormal];
	[button setTitleColor:[[TGTheme shared] onAccentColour] forState:UIControlStateNormal];
	button.titleLabel.font = TGFontCaptionStrong();
	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

/// The bar sits at the top so the keyboard never covers it.
- (void)buildBar {
	TGTheme *theme = [TGTheme shared];
	CGFloat width = self.bounds.size.width;
	CGFloat top = [UIApplication sharedApplication].statusBarFrame.size.height;
	self.bar = [[UIView alloc] initWithFrame:CGRectMake(TGMetricZero, TGMetricZero,
			width, top + TGDoubled(TGMetricRow))];
	self.bar.backgroundColor = [theme scrimColour];
	self.bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self addSubview:self.bar];

	self.comment = [[UITextField alloc] initWithFrame:CGRectMake(TGMetricPad,
			top + TGMetricPad, width - TGDoubled(TGMetricPad),
			TGMetricRow - TGDoubled(TGMetricPad))];
	self.comment.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.comment.borderStyle = UITextBorderStyleRoundedRect;
	self.comment.font = TGFontBody();
	self.comment.placeholder = @"What is wrong here (optional)";
	self.comment.returnKeyType = UIReturnKeyDone;
	self.comment.delegate = self;
	[self.bar addSubview:self.comment];

	NSArray *buttons = @[
		[self barButton:@"Cancel" action:@selector(cancel)],
		[self barButton:@"Clear" action:@selector(clearInk)],
		(self.verdictButton = [self barButton:@"Bad" action:@selector(toggleVerdict)]),
		[self barButton:@"Save" action:@selector(save)],
	];
	CGFloat slot = width / buttons.count;
	for (NSUInteger i = 0; i < buttons.count; i++){
		UIButton *button = buttons[i];
		button.frame = CGRectMake(slot * i, top + TGMetricRow, slot, TGMetricRow);
		button.autoresizingMask = UIViewAutoresizingFlexibleWidth |
				UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		[self.bar addSubview:button];
	}
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
	[field resignFirstResponder];
	return NO;
}

- (void)toggleVerdict {
	self.good = !self.good;
	[self.verdictButton setTitle:(self.good ? @"Good" : @"Bad")
						forState:UIControlStateNormal];
}

- (void)clearInk {
	[self.strokes removeAllObjects];
	self.ink.path = nil;
}

- (void)cancel {
	[self removeFromSuperview];
}

#pragma mark drawing

- (void)redrawInk {
	UIBezierPath *all = [UIBezierPath bezierPath];
	for (UIBezierPath *stroke in self.strokes)
		[all appendPath:stroke];
	self.ink.path = all.CGPath;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	[self.comment resignFirstResponder];
	CGPoint at = [[touches anyObject] locationInView:self];
	if (CGRectContainsPoint(self.bar.frame, at))
		return;
	UIBezierPath *stroke = [UIBezierPath bezierPath];
	[stroke moveToPoint:at];
	[self.strokes addObject:stroke];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	UIBezierPath *stroke = self.strokes.lastObject;
	if (!stroke)
		return;
	[stroke addLineToPoint:[[touches anyObject] locationInView:self]];
	[self redrawInk];
}

#pragma mark saving

- (void)save {
	[self.comment resignFirstResponder];
	CGSize size = self.shot.size;
	UIGraphicsBeginImageContextWithOptions(size, YES, self.shot.scale);
	[self.shot drawAtPoint:CGPointZero];
	[[[TGTheme shared] destructiveColour] setStroke];
	NSMutableArray *boxes = [NSMutableArray array];
	for (UIBezierPath *stroke in self.strokes){
		// A tap without a move is a lone moveTo: its bounds are CGRectNull,
		// whose infinities made NSJSONSerialization throw.
		CGRect bounds = stroke.bounds;
		if (CGRectIsNull(bounds) || CGRectIsInfinite(bounds))
			continue;
		stroke.lineWidth = self.ink.lineWidth;
		stroke.lineCapStyle = kCGLineCapRound;
		[stroke stroke];
		CGRect box = CGRectIntegral(bounds);
		[boxes addObject:@[@(box.origin.x), @(box.origin.y),
						   @(box.size.width), @(box.size.height)]];
	}
	UIImage *marked = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	NSDateFormatter *format = [[NSDateFormatter alloc] init];
	format.dateFormat = @"yyyyMMdd-HHmmss";
	NSString *stamp = [format stringFromDate:[NSDate date]];
	NSString *dir = TGFeedbackDirectory();
	[UIImagePNGRepresentation(marked) writeToFile:
			[dir stringByAppendingPathComponent:[stamp stringByAppendingString:@".png"]]
			atomically:YES];
	NSDictionary *note = @{
		@"stamp" : stamp,
		@"verdict" : self.good ? @"good" : @"bad",
		@"comment" : self.comment.text ?: @"",
		@"screen" : self.screenClass ?: @"",
		@"title" : self.screenTitle ?: @"",
		@"boxes" : boxes,
		@"points" : @[@(size.width), @(size.height)],
	};
	NSData *json = [NSJSONSerialization isValidJSONObject:note]
			? [NSJSONSerialization dataWithJSONObject:note
					options:NSJSONWritingPrettyPrinted error:NULL]
			: nil;
	[json writeToFile:[dir stringByAppendingPathComponent:
			[stamp stringByAppendingString:@".json"]] atomically:YES];
	NSLog(@"TGFeedback: saved %@ (%@, %@) %@", stamp, note[@"verdict"],
			note[@"screen"], note[@"comment"]);

	UIView *host = self.superview;
	[self removeFromSuperview];
	NSUInteger count = [[[NSFileManager defaultManager]
			contentsOfDirectoryAtPath:dir error:NULL]
			filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:
					@"self ENDSWITH '.json'"]].count;
	[TGSnackbar showInView:host
					  text:[NSString stringWithFormat:@"Feedback saved (%lu)",
							(unsigned long)count]
				   seconds:2
				  onCommit:nil];
}

@end

#pragma mark - the trigger

@interface TGDevFeedback () <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIWindow *window;
@end

@implementation TGDevFeedback

+ (instancetype)shared {
	static TGDevFeedback *shared = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ shared = [[TGDevFeedback alloc] init]; });
	return shared;
}

+ (void)installInWindow:(UIWindow *)window {
	TGDevFeedback *me = [self shared];
	if (!window || me.window == window)
		return;
	me.window = window;
	UITapGestureRecognizer *taps = [[UITapGestureRecognizer alloc]
			initWithTarget:me action:@selector(open:)];
	taps.numberOfTapsRequired = kFeedbackTaps;
	UITapGestureRecognizer *fingers = [[UITapGestureRecognizer alloc]
			initWithTarget:me action:@selector(open:)];
	fingers.numberOfTouchesRequired = kFeedbackFingers;
	for (UITapGestureRecognizer *gesture in @[taps, fingers]){
		// Watch only: the screen underneath keeps every touch it gets.
		gesture.cancelsTouchesInView = NO;
		gesture.delaysTouchesEnded = NO;
		gesture.delegate = me;
		[window addGestureRecognizer:gesture];
	}
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture
		shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
	return YES;
}

- (void)open:(UITapGestureRecognizer *)gesture {
	UIWindow *window = self.window;
	if (!window || gesture.state != UIGestureRecognizerStateRecognized)
		return;
	for (UIView *view in window.subviews)
		if ([view isKindOfClass:TGDevFeedbackCanvas.class])
			return;
	[window endEditing:YES];

	UIGraphicsBeginImageContextWithOptions(window.bounds.size, YES, 0);
	if ([window respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)])
		[window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
	else
		[window.layer renderInContext:UIGraphicsGetCurrentContext()];
	UIImage *shot = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	UIViewController *top = TGFeedbackTopController(window.rootViewController);
	TGDevFeedbackCanvas *canvas = [[TGDevFeedbackCanvas alloc]
			initWithFrame:window.bounds shot:shot];
	canvas.screenClass = top ? NSStringFromClass(top.class) : @"";
	canvas.screenTitle = top.title ?: top.navigationItem.title ?: @"";
	[window addSubview:canvas];
}

@end
#endif
