#import "TGCallViewController.h"
#import "TGLocalization.h"
#import "TGCall.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGCapabilities.h"
#import "TGUIFormat.h"
#import <QuartzCore/QuartzCore.h>
#import <CommonCrypto/CommonDigest.h>
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGCallVideoEngine.h"
#import "TGCallMiniBar.h"
#import "TGCallViewController.h"

@interface TGCallMiniBar ()
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) NSTimer *timer;
@end


/// The bar a minimised call leaves at the top of the app. A call does not
/// stop when its screen is put away, and Telegram keeps a way back to it; the
/// bar is that way. It is a separate window because the call screen is gone
/// by then and the chat list must still take touches underneath.




static const CGFloat kTGCallPipWidth = 96.0f;
static const CGFloat kTGCallPipHeight = 128.0f;
static const CGFloat kTGCallFlipBtnSide = 32.0f;

// A gradient layer wants CGColorRefs; the palette hands out UIColors.
static NSArray *TGCallGradient(NSArray *colours) {
    NSMutableArray *refs = [NSMutableArray arrayWithCapacity:colours.count];
    for (UIColor *colour in colours)
        [refs addObject:(id)colour.CGColor];
    return refs;
}

typedef NS_ENUM(NSInteger, TGCallCircleStyle) {
	TGCallCircleStyleOutline = 0,
	TGCallCircleStyleFilled,
	TGCallCircleStyleSolid
};

/// Cached circle images for call buttons drawn flat with CoreGraphics.
/// Outline buttons draw a stroke of TGMetricBorderMedium and fill with
/// callControlColour on highlight. Filled and solid buttons fill the oval,
/// dimming by TGTransformScaleButtonActive on highlight.
static UIImage *TGCallCircleImage(CGFloat side, UIColor *colour, TGCallCircleStyle style, BOOL highlighted) {
	static NSMutableDictionary *cache = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		cache = [[NSMutableDictionary alloc] init];
	});

	CGFloat r = 0, g = 0, b = 0, a = 1.0f;
	if (![colour getRed:&r green:&g blue:&b alpha:&a]) {
		CGFloat w = 0;
		if ([colour getWhite:&w alpha:&a]) {
			r = w; g = w; b = w;
		} else {
			r = 1.0f; g = 1.0f; b = 1.0f; a = 1.0f;
		}
	}

	NSString *styleKey = (style == TGCallCircleStyleOutline) ? @"outline" :
						 (style == TGCallCircleStyleFilled)  ? @"filled" : @"solid";
	NSString *key = [NSString stringWithFormat:@"circle_%.0f_r%.2f_g%.2f_b%.2f_a%.2f_%@_%@",
					 side, r, g, b, a, styleKey, highlighted ? @"high" : @"norm"];
	UIImage *cached = cache[key];
	if (cached)
		return cached;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0.0f);
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	if (style == TGCallCircleStyleOutline) {
		CGFloat strokeWidth = TGMetricBorderMedium;
		CGFloat inset = TGHalf(strokeWidth);
		CGRect rect = CGRectInset(CGRectMake(0, 0, side, side), inset, inset);
		UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:rect];
		path.lineWidth = strokeWidth;

		if (highlighted) {
			[[[TGTheme shared] callControlColour] setFill];
			[path fill];
		}
		[colour setStroke];
		[path stroke];
	} else {
		CGRect rect = CGRectMake(0, 0, side, side);
		UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:rect];
		if (highlighted) {
			CGContextSetRGBFillColor(ctx,
									 r * TGTransformScaleButtonActive,
									 g * TGTransformScaleButtonActive,
									 b * TGTransformScaleButtonActive,
									 a);
			[path fill];
		} else {
			[colour setFill];
			[path fill];
		}
	}

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	if (image)
		cache[key] = image;
	return image;
}


@implementation TGCallMiniBar {
	/// Bumped on every show and hide so a completion from an older slide
	/// cannot hide a bar that a newer call has just shown.
	NSUInteger _showHideGeneration;
}

+ (instancetype)shared {
	static TGCallMiniBar *bar = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		bar = [[TGCallMiniBar alloc] init];
		// The bar names the peer of the running call. When the account changes
		// that call is gone, so hide it rather than leaving the old account's
		// name up where a tap would reopen a dead user id.
		[[NSNotificationCenter defaultCenter]
				addObserverForName:TGAccountDidSwitchNotification
							object:nil queue:[NSOperationQueue mainQueue]
					 usingBlock:^(NSNotification *note){
			[bar hide];
		}];
	});
	return bar;
}

- (void)showForUserId:(int64_t)userId name:(NSString *)name {
	self.userId = userId;
	self.peerName = name ?: @"";
	BOOL wasVisible = (self.window != nil && !self.window.hidden);
	if (!self.window)
		[self buildWindow];
	// A hide still in flight belongs to the old call; it must not remove the
	// bar that is being shown now.
	_showHideGeneration++;
	[self updateTitle];
	if (!wasVisible)
		self.window.transform = CGAffineTransformMakeTranslation(0, -self.window.bounds.size.height);
	self.window.hidden = NO;
	if (!wasVisible || !CGAffineTransformIsIdentity(self.window.transform)) {
		UIWindow *window = self.window;
		[UIView animateWithDuration:TGAnimationDurationNormal
							  delay:0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{
			window.transform = CGAffineTransformIdentity;
		} completion:nil];
	}
	[self.timer invalidate];
	self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
			selector:@selector(tick:) userInfo:nil repeats:YES];
}

- (CGRect)barFrame {
	CGRect screen = [UIScreen mainScreen].bounds;
	UIInterfaceOrientation orientation =
			[UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsLandscape(orientation))
		return CGRectMake(0, 0, screen.size.height, TGMetricCallBarHeight);
	return CGRectMake(0, 0, screen.size.width, TGMetricCallBarHeight);
}

- (void)buildWindow {
	// No root view controller: on iOS 6 it sizes its view to the whole screen
	// whatever the window's frame says, and the window does not clip, so the
	// bar was a wall over the app that the back button seemed unable to leave.
	UIWindow *window = [[UIWindow alloc] initWithFrame:[self barFrame]];
	window.windowLevel = UIWindowLevelStatusBar + 1;
	window.backgroundColor = [[TGTheme shared] accentColour];
	window.clipsToBounds = YES;

	self.button = [UIButton buttonWithType:UIButtonTypeCustom];
	self.button.frame = window.bounds;
	self.button.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleHeight;
	self.button.titleLabel.font = TGFontMetaStrong();
	[self.button setTitleColor:[[TGTheme shared] onAccentColour]
					  forState:UIControlStateNormal];
	[self.button addTarget:self action:@selector(returnToCall)
		  forControlEvents:UIControlEventTouchUpInside];
	[window addSubview:self.button];
	self.window = window;

	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(orientationChanged:)
				name:UIApplicationDidChangeStatusBarOrientationNotification
			  object:nil];
}

- (void)orientationChanged:(NSNotification *)note {
	self.window.frame = [self barFrame];
	self.button.frame = self.window.bounds;
}

- (void)updateTitle {
	NSString *name = self.peerName.length ? self.peerName : @"Call";
	TGCallState state = [TGCall shared].state;
	if (state == TGCallStatePending) {
		[self.button setTitle:[NSString stringWithFormat:@"%@  ·  %@", name, TGLocalized(@"Ringing")]
					 forState:UIControlStateNormal];
		return;
	}
	if (state == TGCallStateEstablished) {
		[self.button setTitle:[NSString stringWithFormat:@"%@  ·  %@", name,
				TGUIFormatCallDuration([[TGCall shared] duration])]
					 forState:UIControlStateNormal];
		return;
	}
	[self.button setTitle:[NSString stringWithFormat:@"%@  ·  %@", name, TGLocalized(@"Connecting...")]
				 forState:UIControlStateNormal];
}

- (void)stopClock {
	[self.timer invalidate];
	self.timer = nil;
}

- (void)tick:(NSTimer *)timer {
	TGCallState state = [TGCall shared].state;
	if (state == TGCallStateNone || state == TGCallStateEnded ||
			state == TGCallStateFailed) {
		[self hide];
		return;
	}
	[self updateTitle];
}

- (void)returnToCall {
	int64_t userId = self.userId;
	NSString *name = self.peerName;
	// The call's own direction: a screen told "incoming" would offer Accept and
	// Decline on a call this side placed and is still ringing out.
	BOOL outgoing = [TGCall shared].outgoing;
	[self hide];
	[TGCallViewController presentForUserId:userId name:name outgoing:outgoing];
}

- (void)hide {
	[self.timer invalidate];
	self.timer = nil;
	if (!self.window) {
		self.peerName = nil;
		self.userId = 0;
		return;
	}
	_showHideGeneration++;
	NSUInteger generation = _showHideGeneration;
	UIWindow *window = self.window;
	__weak typeof(self) weakSelf = self;
	[UIView animateWithDuration:TGAnimationDurationNormal
						  delay:0
						options:UIViewAnimationOptionBeginFromCurrentState
					 animations:^{
		window.transform = CGAffineTransformMakeTranslation(0, -window.bounds.size.height);
	} completion:^(BOOL finished) {
		TGCallMiniBar *me = weakSelf;
		if (!me || me->_showHideGeneration != generation)
			return;
		window.hidden = YES;
		window.transform = CGAffineTransformIdentity;
		me.window = nil;
		me.button = nil;
		me.peerName = nil;
		me.userId = 0;
	}];
}

@end
