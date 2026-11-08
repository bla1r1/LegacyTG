#import "TGCallViewController.h"
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
#import "TGCallViewController.h"
#import "TGCallMiniBar.h"

@interface TGCallViewController ()
@property (nonatomic, assign) int64_t userId;
@property (nonatomic, strong) NSString *peerName;
@property (nonatomic, assign) BOOL outgoing;

@property (nonatomic, strong) UIView *bgContainer;
@property (nonatomic, strong) CAGradientLayer *bgLayer;
@property (nonatomic, strong) UILabel *emojiLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, copy) NSString *keyEmojiText;

@property (nonatomic, strong) UIView *keyCard;
@property (nonatomic, strong) UILabel *keyCardEmoji;
@property (nonatomic, strong) UILabel *keyCardTitle;
@property (nonatomic, strong) UILabel *keyCardBody;

@property (nonatomic, strong) UIButton *speakerBtn;
@property (nonatomic, strong) UIButton *videoBtn;
@property (nonatomic, strong) UIButton *micBtn;
@property (nonatomic, strong) UIButton *endBtn;
@property (nonatomic, strong) UIButton *acceptBtn;

@property (nonatomic, strong) UILabel *speakerLbl;
@property (nonatomic, strong) UILabel *videoLbl;
@property (nonatomic, strong) UILabel *micLbl;
@property (nonatomic, strong) UILabel *endLbl;
@property (nonatomic, strong) UILabel *acceptLbl;

@property (nonatomic, assign) BOOL speakerOn;
@property (nonatomic, strong) UILabel *lastCreatedLabel;

/// Which variant of the control row `updateLayoutForCallActive:` last built,
/// so a rotation rebuilds the same one instead of guessing from the state.
@property (nonatomic, assign) BOOL callRowActive;

@property (nonatomic, strong) UIView *remoteVideoContainer;
@property (nonatomic, strong) UIView *pipContainer;
@property (nonatomic, strong) UIButton *flipCameraBtn;

@property (nonatomic, strong) NSTimer *ticker;
/// When the call was answered, for the rating prompt after it; TGCall's own
/// duration is gone by then, teardown having cleared its start time.
@property (nonatomic, strong) NSDate *connectedAt;
@property (nonatomic, assign) BOOL ratedCall;
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


@implementation TGCallViewController

+ (void)previewMiniBarNamed:(NSString *)name {
	TGCallMiniBar *bar = [TGCallMiniBar shared];
	if (name){
		[bar showForUserId:0 name:name];
		[bar stopClock];
	} else {
		[bar hide];
	}
}

+ (void)presentForUserId:(int64_t)userId name:(NSString *)name outgoing:(BOOL)outgoing {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window.rootViewController) {
            for (UIWindow *candidate in [UIApplication sharedApplication].windows) {
                if (candidate.rootViewController && !candidate.hidden) {
                    window = candidate;
                    break;
                }
            }
        }
        UIViewController *top = window.rootViewController;
        if (!top)
            return;
        while (top.presentedViewController)
            top = top.presentedViewController;

        if ([top isKindOfClass:[TGCallViewController class]])
            return;

        TGCallViewController *screen = [[TGCallViewController alloc]
                initWithUserId:userId name:name outgoing:outgoing];
        [top presentViewController:screen animated:YES completion:nil];
    });
}

- (instancetype)initWithUserId:(int64_t)userId name:(NSString *)name outgoing:(BOOL)outgoing {
    if ((self = [super init])){
        _userId = userId;
        _peerName = name ?: @"";
        _outgoing = outgoing;
    }
    return self;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Background container view for the gradient
    self.bgContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    self.bgContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.bgContainer];

    // Gradient Background
    self.bgLayer = [CAGradientLayer layer];
    self.bgLayer.frame = self.bgContainer.bounds;
    self.bgLayer.colors = TGCallGradient([[TGTheme shared] callGradientColours]);
    [self.bgContainer.layer addSublayer:self.bgLayer];

    // Down the screen once, each thing under the last, so moving the avatar
    // does not leave the name sitting where it used to be. The placement
    // lives in applyChromeLayout, which the first layout pass and every
    // rotation land on.
    self.emojiLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emojiLabel.font = TGFontGlyph();
    self.emojiLabel.textAlignment = NSTextAlignmentCenter;
    self.emojiLabel.backgroundColor = [UIColor clearColor];
    // A tap opens the card that says what the four emoji are for.
    self.emojiLabel.userInteractionEnabled = YES;
    [self.emojiLabel addGestureRecognizer:[[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(showKeyCard)]];
    [self.view addSubview:self.emojiLabel];

    // Remote video view sits in front of background, but behind avatar, names, and buttons
    self.remoteVideoContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    self.remoteVideoContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.remoteVideoContainer.backgroundColor = [UIColor blackColor];
    self.remoteVideoContainer.hidden = YES;
    [self.view addSubview:self.remoteVideoContainer];

    CGFloat side = TGMetricCallAvatarSide;
    self.avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, side, side)];
    self.avatarView.layer.cornerRadius = TGHalf(side);
    self.avatarView.clipsToBounds = YES;
    self.avatarView.layer.shouldRasterize = YES;
    self.avatarView.layer.rasterizationScale = [UIScreen mainScreen].scale;
    self.avatarView.layer.borderColor = [[TGTheme shared] separatorColour].CGColor;
    self.avatarView.layer.borderWidth = 1.0f;
    self.avatarView.image = [TGIcons avatarWithInitials:[TGIcons initialsForTitle:self.peerName]
                                                   size:side colourId:self.userId];
    [self.view addSubview:self.avatarView];

    // Picture-in-Picture window for local camera preview
    self.pipContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kTGCallPipWidth, kTGCallPipHeight)];
    self.pipContainer.backgroundColor = [UIColor blackColor];
    self.pipContainer.layer.cornerRadius = TGMetricCornerControl;
    self.pipContainer.clipsToBounds = YES;
    self.pipContainer.layer.borderColor = [[TGTheme shared] separatorColour].CGColor;
    self.pipContainer.layer.borderWidth = 1.0f;
    self.pipContainer.hidden = YES;
    self.pipContainer.userInteractionEnabled = YES;
    [self.pipContainer addGestureRecognizer:[[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(switchCamera)]];
    [self.view addSubview:self.pipContainer];

    self.flipCameraBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.flipCameraBtn setImage:[TGIcons glyphNamed:@"switchCamera" colour:[[TGTheme shared] onAccentColour] side:TGMetricPadLarge] forState:UIControlStateNormal];
    [self.flipCameraBtn addTarget:self action:@selector(switchCamera) forControlEvents:UIControlEventTouchUpInside];
    self.flipCameraBtn.hidden = YES;
    [self.view addSubview:self.flipCameraBtn];

    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.nameLabel.text = self.peerName.length ? self.peerName
            : ([[TGClient shared] nameForUserId:self.userId] ?: @"Call");
    self.nameLabel.font = TGFontHero();
    self.nameLabel.textColor = [[TGTheme shared] onAccentColour];
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    self.nameLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.nameLabel];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.font = TGFontBody();
    self.statusLabel.textColor = [[TGTheme shared] callSubtitleColour];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.statusLabel];

    // Back to the chat without ending the call, leaving the bar as the way
    // back. Without it the bar could never appear.
    self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.backButton.titleLabel.font = TGFontBody();
    [self.backButton setTitle:@"Back" forState:UIControlStateNormal];
    [self.backButton setTitleColor:[[TGTheme shared] onAccentColour]
                          forState:UIControlStateNormal];
    [self.backButton setImage:[TGIcons backChevronWithColour:
            [[TGTheme shared] onAccentColour]] forState:UIControlStateNormal];
    self.backButton.imageEdgeInsets = UIEdgeInsetsMake(0, -TGMetricPadSmall, 0, 0);
    self.backButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.backButton addTarget:self action:@selector(minimise)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.backButton];

    // Shown wherever the hardware could do it; a release build answers the
    // tap with "in progress" (toggleVideo) until video calls are finished.
    BOOL canVideo = [TGCapabilities hasVideoCallHardware];

    // Not "unmute": the icon table draws that one as the notifications bell.
    self.speakerBtn = [self createButtonWithTitle:@"Speaker" icon:@"speaker"];
    self.speakerLbl = self.lastCreatedLabel;
    self.videoBtn = [self createButtonWithTitle:@"Video" icon:@"video"];
    self.videoLbl = self.lastCreatedLabel;
    if (!canVideo) {
        self.videoBtn.hidden = YES;
        self.videoLbl.hidden = YES;
    }
    self.micBtn = [self createButtonWithTitle:@"Mute" icon:@"microphone"];
    self.micLbl = self.lastCreatedLabel;
    self.endBtn = [self createButtonWithTitle:@"End" icon:@"endcall"];
    self.endLbl = self.lastCreatedLabel;

    self.acceptBtn = [self createButtonWithTitle:@"Accept" icon:@"call"];
    self.acceptLbl = self.lastCreatedLabel;
    [self.acceptBtn addTarget:self action:@selector(acceptCall) forControlEvents:UIControlEventTouchUpInside];

	TGTheme *theme = [TGTheme shared];
	UIColor *white = [theme onMediaColour];
	UIColor *red = [theme destructiveColour];
	UIColor *green = [theme callAcceptColour];
	CGFloat buttonSide = TGMetricCallButtonSide;

	[self.endBtn setBackgroundImage:TGCallCircleImage(buttonSide, red, TGCallCircleStyleSolid, NO)
						   forState:UIControlStateNormal];
	[self.endBtn setBackgroundImage:TGCallCircleImage(buttonSide, red, TGCallCircleStyleSolid, YES)
						   forState:UIControlStateHighlighted];
	self.endBtn.backgroundColor = [UIColor clearColor];

	[self.acceptBtn setBackgroundImage:TGCallCircleImage(buttonSide, green, TGCallCircleStyleSolid, NO)
							 forState:UIControlStateNormal];
	[self.acceptBtn setBackgroundImage:TGCallCircleImage(buttonSide, green, TGCallCircleStyleSolid, YES)
							 forState:UIControlStateHighlighted];
	self.acceptBtn.backgroundColor = [UIColor clearColor];

	[self.endBtn setImage:[TGIcons glyphNamed:@"endcall" colour:white
										 side:TGMetricCallGlyphSide]
				 forState:UIControlStateNormal];
	[self.acceptBtn setImage:[TGIcons glyphNamed:@"call" colour:white
										   side:TGMetricCallGlyphSide]
				   forState:UIControlStateNormal];

	[self.speakerBtn addTarget:self action:@selector(toggleSpeaker) forControlEvents:UIControlEventTouchUpInside];
	[self.micBtn addTarget:self action:@selector(toggleMute) forControlEvents:UIControlEventTouchUpInside];
	[self.videoBtn addTarget:self action:@selector(toggleVideo) forControlEvents:UIControlEventTouchUpInside];
	[self.endBtn addTarget:self action:@selector(end) forControlEvents:UIControlEventTouchUpInside];
    [self refreshControls];

    __weak typeof(self) weakSelf = self;
    [TGCall shared].onStateChanged = ^(TGCallState state){
        [weakSelf applyState:state];
    };
    [TGCall shared].onPeerVideoChanged = ^(BOOL active){
        [weakSelf updateVideoLayoutAnimated:YES];
    };

    // A screen presented again from the minimised bar must not place a second
    // call: TGCall already has one.
    if (self.outgoing && [TGCall shared].state == TGCallStateNone)
        [[TGCall shared] callUser:self.userId];

    [self applyState:[TGCall shared].state];
#if TG_DEV
    if (self.userId == 0)
        [self setupEmojis];
#endif

    self.ticker = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                   target:self
                                                 selector:@selector(tick)
                                                 userInfo:nil
                                                  repeats:YES];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!self.emojiLabel)
        return;
    [self applyChromeLayout];
    // The same row variant the call state chose, at the new width.
    [self updateLayoutForCallActive:self.callRowActive];
    [self updateVideoLayoutAnimated:NO];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isMovingFromParentViewController ||
            self.isBeingDismissed) {
        [self.ticker invalidate];
        self.ticker = nil;
    }
}

#pragma mark - chrome

- (UIButton *)createButtonWithTitle:(NSString *)title icon:(NSString *)icon {
	UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
	CGFloat side = TGMetricCallButtonSide;
	btn.frame = CGRectMake(0, 0, side, side);
	btn.layer.cornerRadius = TGHalf(side);
	btn.clipsToBounds = YES;
	btn.layer.shouldRasterize = YES;
	btn.layer.rasterizationScale = [UIScreen mainScreen].scale;
	btn.adjustsImageWhenHighlighted = NO;

	TGTheme *theme = [TGTheme shared];
	UIColor *white = [theme onMediaColour];

	[btn setBackgroundImage:TGCallCircleImage(side, white, TGCallCircleStyleOutline, NO)
				   forState:UIControlStateNormal];
	[btn setBackgroundImage:TGCallCircleImage(side, white, TGCallCircleStyleOutline, YES)
				   forState:UIControlStateHighlighted];
	btn.backgroundColor = [UIColor clearColor];

	UIImage *glyph = [icon isEqualToString:@"microphone"]
			? [TGIcons microphoneOfSide:TGMetricCallGlyphSide colour:white]
			: [TGIcons glyphNamed:icon colour:white side:TGMetricCallGlyphSide];
	if (glyph){
		[btn setImage:glyph forState:UIControlStateNormal];
	} else {
		[btn setTitle:icon forState:UIControlStateNormal];
		btn.titleLabel.font = TGFontGlyph();
	}
	[self.view addSubview:btn];

	UILabel *lbl = [[UILabel alloc] initWithFrame:
			CGRectMake(0, 0, TGMetricCallLabelWidth, TGMetricCallLabelHeight)];
	lbl.text = title;
	lbl.textColor = white;
	lbl.font = TGFontMeta();
	lbl.textAlignment = NSTextAlignmentCenter;
	lbl.backgroundColor = [UIColor clearColor];
	[self.view addSubview:lbl];

	self.lastCreatedLabel = lbl;
	return btn;
}

- (void)applyChromeLayout {
    // The emoji key, avatar, name and status stack down the screen from the
    // top; every rotation rewrites these frames from the present bounds so
    // the name never stays where a wider screen once put it.
    CGRect b = self.view.bounds;
    CGFloat gutter = TGMetricPadMedium;
    CGFloat textWidth = b.size.width - TGDoubled(gutter);
    CGFloat y = TGMetricCallEmojiTop;
    self.bgContainer.frame = b;
    self.bgLayer.frame = self.bgContainer.bounds;
    self.remoteVideoContainer.frame = b;

    self.emojiLabel.frame = CGRectMake(gutter, y, textWidth, TGMetricCallEmojiHeight);
    // iOS 7 lays the screen under the status bar; the button starts below
    // it. iOS 6 has no layout guide and no overlap.
    CGFloat statusTop = [self respondsToSelector:@selector(topLayoutGuide)]
            ? self.topLayoutGuide.length : 0;
    self.backButton.frame = CGRectMake(TGMetricPadSmall, statusTop,
            TGMetricCallLabelWidth, TGMetricRow);
    y += TGMetricCallEmojiHeight + TGMetricPadLarge;

    CGFloat side = TGMetricCallAvatarSide;
    self.avatarView.frame = CGRectMake(TGCenteredOrigin(b.size.width, side), y, side, side);
    y += side + TGMetricPadLarge;

    self.nameLabel.frame = CGRectMake(gutter, y, textWidth, TGMetricCallNameHeight);
    y += TGMetricCallNameHeight + TGMetricPadTiny;
    self.statusLabel.frame = CGRectMake(gutter, y, textWidth, TGMetricCallStatusHeight);

    if (self.keyCard)
        [self layoutKeyCardInBounds:b];
}

/// One row of round buttons, spread evenly across the width with the same air
/// at both ends, each caption centred on the button above it.
- (void)placeRow:(NSArray *)buttons captions:(NSArray *)captions atY:(CGFloat)rowY {
    CGFloat width = self.view.bounds.size.width;
    CGFloat side = TGMetricCallButtonSide;
    CGFloat count = (CGFloat)buttons.count;
    CGFloat gap = (width - side * count) / (count + 1);

    for (NSUInteger i = 0; i < buttons.count; i++){
        UIButton *button = buttons[i];
        UILabel *caption = captions[i];
        CGFloat x = gap + i * (side + gap);

        button.hidden = NO;
        caption.hidden = NO;
        button.frame = CGRectMake(x, rowY, side, side);
        caption.frame = CGRectMake(
                x + TGCenteredOrigin(side, TGMetricCallLabelWidth),
                rowY + TGMetricCallLabelGap,
                TGMetricCallLabelWidth, TGMetricCallLabelHeight);
    }
}

- (void)hideRow:(NSArray *)buttons captions:(NSArray *)captions {
    for (UIView *view in buttons) view.hidden = YES;
    for (UIView *view in captions) view.hidden = YES;
}

- (void)acceptCall {
    [[TGCall shared] accept];
    [self setStatusText:@"Connecting..."];
    [self updateLayoutForCallActive:YES];
}

- (void)updateLayoutForCallActive:(BOOL)active {
    self.callRowActive = active;
    CGRect b = self.view.bounds;
    CGFloat rowY = b.size.height - TGMetricCallTogglesBottom;
    BOOL ringing = (!self.outgoing && !active &&
                    [TGCall shared].state == TGCallStatePending);

    if (ringing){
        // Nothing to toggle until the call is yours: decline and accept, side
        // by side, the way the phone app does it.
        [self hideRow:@[self.speakerBtn, self.videoBtn, self.micBtn]
             captions:@[self.speakerLbl, self.videoLbl, self.micLbl]];
        self.endLbl.text = @"Decline";
        [self placeRow:@[self.endBtn, self.acceptBtn]
              captions:@[self.endLbl, self.acceptLbl]
                   atY:rowY];
        return;
    }

    self.acceptBtn.hidden = YES;
    self.acceptLbl.hidden = YES;
    self.endLbl.text = @"End";

    // One row, End among the others and on their line: it is the button the
    // thumb goes for, and it should not be somewhere else on the screen.
    NSMutableArray *row = [NSMutableArray arrayWithObject:self.speakerBtn];
    NSMutableArray *captions = [NSMutableArray arrayWithObject:self.speakerLbl];
    if ([TGCapabilities hasVideoCallHardware]){
        [row addObject:self.videoBtn];
        [captions addObject:self.videoLbl];
    } else {
        self.videoBtn.hidden = YES;
        self.videoLbl.hidden = YES;
    }
    [row addObjectsFromArray:@[self.micBtn, self.endBtn]];
    [captions addObjectsFromArray:@[self.micLbl, self.endLbl]];

    [self placeRow:row captions:captions atY:rowY];
}

#pragma mark - state

- (void)setStatusText:(NSString *)text {
    if (!self.view.window || [self.statusLabel.text isEqualToString:text]) {
        self.statusLabel.text = text;
        return;
    }
    // Ringing, connecting and the end reason share this one line; a crossfade
    // marks the change without moving anything around it.
    __weak typeof(self) weakSelf = self;
    [UIView transitionWithView:self.statusLabel
                      duration:TGAnimationDurationFast
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        weakSelf.statusLabel.text = text;
    } completion:nil];
}

- (void)applyState:(TGCallState)state {
    BOOL isRinging = (!self.outgoing && state == TGCallStatePending);
    [self updateLayoutForCallActive:!isRinging];
    switch (state){
        case TGCallStatePending:
            [self setStatusText:(self.outgoing ? @"Ringing..." : @"Incoming call")];
            [self setStatusPulsing:YES];
            break;
        case TGCallStateExchangingKeys:
        case TGCallStateConnecting:
            [self setStatusText:@"Connecting..."];
            [self setStatusPulsing:NO];
            [self setupEmojis];
            break;
        case TGCallStateEstablished:
            [self setStatusPulsing:NO];
            if (!self.connectedAt)
                self.connectedAt = [NSDate dateWithTimeIntervalSinceNow:
                        -[[TGCall shared] duration]];
            self.bgLayer.colors = TGCallGradient([[TGTheme shared] callGradientColoursConnected]);
            [self setupEmojis];
            [self setStatusText:[self talkTimeText]];
            [self refreshControls];
            break;
        case TGCallStateFailed:
            [self setStatusText:([TGCall shared].endReason ?: @"Call failed")];
            [self windDown];
            [self dismissShortly];
            break;
        case TGCallStateEnded:
            [self setStatusText:([TGCall shared].endReason ?: @"Call ended")];
            [self windDown];
            [self dismissShortly];
            break;
        default:
            break;
    }
}

- (NSString *)emojiKeyText {
#if TG_DEV
    // Only the callscreen/ preview has no peer; it has no key to show either.
    if (self.userId == 0)
        return @"🐶  🐱  🐭  🐹";
#endif
    NSArray *emojis = [TGCall shared].emojis;
    if (emojis.count >= 4)
        return [NSString stringWithFormat:@"%@  %@  %@  %@",
                emojis[0], emojis[1], emojis[2], emojis[3]];
    NSData *key = [TGCall shared].callKey;
    if (key.length >= 32) {
        unsigned char hash[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(key.bytes, (CC_LONG)key.length, hash);
        NSArray *list = @[@"🐶", @"🐱", @"🐭", @"🐹", @"🐰", @"🦊", @"🐻", @"🐼",
                          @"🐨", @"🐯", @"🦁", @"🐮", @"🐷", @"🐸", @"🐵"];
        return [NSString stringWithFormat:@"%@  %@  %@  %@",
                list[hash[0] % list.count], list[hash[1] % list.count],
                list[hash[2] % list.count], list[hash[3] % list.count]];
    }
    return nil;
}

- (void)setupEmojis {
    NSString *text = [self emojiKeyText];
    if (!text.length)
        return;
    self.keyEmojiText = text;
    self.emojiLabel.text = text;
    if (self.keyCard)
        self.keyCardEmoji.text = text;
}

- (void)showKeyCard {
    if (!self.keyEmojiText.length)
        return;
    if (!self.keyCard){
        self.keyCard = [[UIView alloc] initWithFrame:self.view.bounds];
        self.keyCard.backgroundColor = [[TGTheme shared] scrimColour];
        self.keyCard.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                UIViewAutoresizingFlexibleHeight;
        [self.keyCard addGestureRecognizer:[[UITapGestureRecognizer alloc]
                initWithTarget:self action:@selector(hideKeyCard)]];

        UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
        card.tag = 0xCA2D;
        card.backgroundColor = [[TGTheme shared] cardBackgroundColour];
        card.layer.cornerRadius = TGMetricCornerCard;
        [self.keyCard addSubview:card];

        self.keyCardEmoji = [[UILabel alloc] initWithFrame:CGRectZero];
        self.keyCardEmoji.text = self.keyEmojiText;
        self.keyCardEmoji.font = TGFontEmojiLarge();
        self.keyCardEmoji.textAlignment = NSTextAlignmentCenter;
        self.keyCardEmoji.backgroundColor = [UIColor clearColor];
        [card addSubview:self.keyCardEmoji];

        self.keyCardTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        self.keyCardTitle.text = @"Encrypted";
        self.keyCardTitle.font = TGFontHeader();
        self.keyCardTitle.textColor = [[TGTheme shared] primaryTextColour];
        self.keyCardTitle.textAlignment = NSTextAlignmentCenter;
        self.keyCardTitle.backgroundColor = [UIColor clearColor];
        [card addSubview:self.keyCardTitle];

        self.keyCardBody = [[UILabel alloc] initWithFrame:CGRectZero];
        self.keyCardBody.text = @"This call is end-to-end encrypted";
        self.keyCardBody.font = TGFontCaption();
        self.keyCardBody.textColor = [[TGTheme shared] secondaryTextColour];
        self.keyCardBody.textAlignment = NSTextAlignmentCenter;
        self.keyCardBody.numberOfLines = 3;
        self.keyCardBody.backgroundColor = [UIColor clearColor];
        [card addSubview:self.keyCardBody];

        UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
        close.frame = CGRectZero;
        close.tag = 0xCA2E;
        [close setTitle:@"Close" forState:UIControlStateNormal];
        [close setTitleColor:[[TGTheme shared] accentColour]
                    forState:UIControlStateNormal];
        close.titleLabel.font = TGFontRow();
        [close addTarget:self action:@selector(hideKeyCard)
                forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:close];

        self.keyCard.alpha = 0;
        [self.view addSubview:self.keyCard];
        [self layoutKeyCardInBounds:self.view.bounds];
    }
    self.keyCard.hidden = NO;
    [UIView animateWithDuration:TGAnimationDurationFast animations:^{
        self.keyCard.alpha = TGAlphaOpaque;
    }];
}

- (void)layoutKeyCardInBounds:(CGRect)b {
    CGFloat cardWidth = MIN(TGMetricCallKeyCardWidth,
            b.size.width - TGDoubled(TGMetricPadWide));
    CGFloat cardHeight = TGMetricCallKeyCardHeight;
    UIView *card = [self.keyCard viewWithTag:0xCA2D];
    card.frame = CGRectMake(TGCenteredOrigin(b.size.width, cardWidth),
            TGCenteredOrigin(b.size.height, cardHeight), cardWidth, cardHeight);
    CGFloat inner = cardWidth - TGDoubled(TGMetricPadLarge);
    self.keyCardEmoji.frame = CGRectMake(TGMetricPadLarge, TGMetricPadLarge,
            inner, TGMetricCallKeyGlyphSize + TGMetricPadLarge);
    self.keyCardTitle.frame = CGRectMake(TGMetricPadLarge,
            TGMetricPadLarge + TGMetricCallKeyGlyphSize + TGMetricPadLarge,
            inner, TGMetricLineHeader);
    self.keyCardBody.frame = CGRectMake(TGMetricPadLarge,
            TGMetricPadLarge + TGMetricCallKeyGlyphSize + TGMetricPadLarge +
                    TGMetricLineHeader + TGMetricPadSmall,
            inner, TGMetricCallKeyCardBody);
    UIButton *close = [card viewWithTag:0xCA2E];
    close.frame = CGRectMake(TGMetricPadLarge,
            cardHeight - TGMetricRow - TGMetricPadSmall,
            inner, TGMetricRow);
}

- (void)hideKeyCard {
    if (!self.keyCard)
        return;
    [UIView animateWithDuration:TGAnimationDurationFast animations:^{
        self.keyCard.alpha = TGAlphaTransparent;
    } completion:^(BOOL done){
        self.keyCard.hidden = YES;
        self.keyCard.alpha = TGAlphaOpaque;
    }];
}

- (NSString *)talkTimeText {
    return TGUIFormatCallDuration([[TGCall shared] duration]);
}

- (void)tick {
    if ([TGCall shared].state != TGCallStateEstablished)
        return;
    self.statusLabel.text = [self talkTimeText];
}

#pragma mark - controls

- (void)toggleSpeaker {
    self.speakerOn = !self.speakerOn;
    [[TGCall shared] setSpeaker:self.speakerOn];
    [self refreshControls];
}

- (void)toggleMute {
    [[TGCall shared] setMuted:![TGCall shared].muted];
    [self refreshControls];
}

- (void)toggleVideo {
    TGCall *call = [TGCall shared];
    if (![TGCapabilities canEncodeVideoCall]) {
        [TGAlertSheet showMessage:@"An error occurred."
                            title:@"Video" inView:self.view];
        return;
    }
    BOOL willEnable = !call.videoActive;
    [call setVideoEnabled:willEnable];
    [self refreshControls];
    [self updateVideoLayoutAnimated:YES];
}

- (void)switchCamera {
    [[TGCall shared] switchCamera];
}

- (void)updateVideoLayoutAnimated:(BOOL)animated {
    TGCall *call = [TGCall shared];
    BOOL hasLocalVideo = call.videoActive;
    BOOL hasRemoteVideo = call.peerVideoActive && call.videoEngine && call.videoEngine.hasRemoteVideo;

    CGRect b = self.view.bounds;
    self.bgContainer.frame = b;
    self.bgLayer.frame = self.bgContainer.bounds;
    self.remoteVideoContainer.frame = b;

    CGFloat pipMargin = TGMetricPadMedium;
    CGFloat pipY = TGMetricCallEmojiTop + TGMetricCallEmojiHeight + TGMetricPadMedium;
    self.pipContainer.frame = CGRectMake(b.size.width - kTGCallPipWidth - pipMargin, pipY, kTGCallPipWidth, kTGCallPipHeight);

    self.flipCameraBtn.frame = CGRectMake(self.pipContainer.frame.origin.x + kTGCallPipWidth - kTGCallFlipBtnSide - TGMetricPadTiny,
                                          self.pipContainer.frame.origin.y + TGMetricPadTiny,
                                          kTGCallFlipBtnSide, kTGCallFlipBtnSide);

    if (call.videoEngine) {
        UIView *remoteView = call.videoEngine.remoteVideoView;
        if (remoteView) {
            remoteView.frame = self.remoteVideoContainer.bounds;
            remoteView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            if (remoteView.superview != self.remoteVideoContainer) {
                [self.remoteVideoContainer addSubview:remoteView];
            }
            [remoteView setNeedsLayout];
            [remoteView layoutIfNeeded];
        }

        UIView *localPreview = call.videoEngine.localPreviewView;
        if (localPreview) {
            localPreview.frame = self.pipContainer.bounds;
            localPreview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            if (localPreview.superview != self.pipContainer) {
                [self.pipContainer addSubview:localPreview];
            }
            [localPreview setNeedsLayout];
            [localPreview layoutIfNeeded];
        }
    }

    [self.view bringSubviewToFront:self.pipContainer];
    [self.view bringSubviewToFront:self.flipCameraBtn];

    if (hasLocalVideo) {
        self.pipContainer.hidden = NO;
        self.flipCameraBtn.hidden = NO;
    }
    if (hasRemoteVideo) {
        self.remoteVideoContainer.hidden = NO;
    } else {
        self.avatarView.hidden = NO;
        self.bgContainer.hidden = NO;
    }

    void (^layoutBlock)(void) = ^{
        self.bgContainer.alpha = hasRemoteVideo ? 0.0f : 1.0f;
        self.remoteVideoContainer.alpha = hasRemoteVideo ? 1.0f : 0.0f;
        self.avatarView.alpha = hasRemoteVideo ? 0.0f : 1.0f;
        self.pipContainer.alpha = hasLocalVideo ? 1.0f : 0.0f;
        self.flipCameraBtn.alpha = hasLocalVideo ? 1.0f : 0.0f;
    };

    void (^completionBlock)(BOOL) = ^(BOOL finished) {
        if (!hasLocalVideo) {
            self.pipContainer.hidden = YES;
            self.flipCameraBtn.hidden = YES;
        }
        if (hasRemoteVideo) {
            self.avatarView.hidden = YES;
            self.bgContainer.hidden = YES;
        } else {
            self.remoteVideoContainer.hidden = YES;
        }
    };

    if (animated) {
        [UIView animateWithDuration:TGAnimationDurationNormal animations:layoutBlock completion:completionBlock];
    } else {
        layoutBlock();
        completionBlock(YES);
    }
}

// The buttons are flat circles: outline when idle, solid filled when active.
// Inactive controls show white glyphs; active controls show the glyph in the
// darker end of the call background.
- (void)refreshControls {
	BOOL muted = [TGCall shared].muted;
	BOOL videoActive = [TGCall shared].videoActive;
	TGTheme *theme = [TGTheme shared];
	UIColor *white = [theme onMediaColour];

	NSArray *grad = ([TGCall shared].state == TGCallStateEstablished)
			? [theme callGradientColoursConnected]
			: [theme callGradientColours];
	UIColor *dark = [grad.lastObject isKindOfClass:[UIColor class]]
			? grad.lastObject
			: [theme primaryTextColour];

	UIImage *mic = [TGIcons microphoneOfSide:TGMetricCallGlyphSide colour:white];
	UIImage *micActive = [TGIcons microphoneOffOfSide:TGMetricCallGlyphSide colour:dark];

	UIImage *spk = [TGIcons glyphNamed:(self.speakerOn ? @"speakerOn" : @"speaker")
								colour:white side:TGMetricCallGlyphSide];
	UIImage *spkActive = [TGIcons glyphNamed:(self.speakerOn ? @"speakerOn" : @"speaker")
									  colour:dark side:TGMetricCallGlyphSide];

	UIImage *vid = [TGIcons glyphNamed:@"video" colour:white side:TGMetricCallGlyphSide];
	UIImage *vidActive = [TGIcons glyphNamed:@"video" colour:dark side:TGMetricCallGlyphSide];

	[self setGlyph:mic activeGlyph:micActive on:self.micBtn active:muted];
	[self setGlyph:spk activeGlyph:spkActive on:self.speakerBtn active:self.speakerOn];
	[self setGlyph:vid activeGlyph:vidActive on:self.videoBtn active:videoActive];

	self.micLbl.text = muted ? @"Unmute" : @"Mute";
	self.speakerLbl.text = @"Speaker";
	self.videoLbl.text = @"Video";
	self.micLbl.textColor = white;
	self.speakerLbl.textColor = white;
	self.videoLbl.textColor = white;
}

// Controls swap between white outline (off) and filled white (on).
// UIKit swaps the highlighted image on touch down, giving flat press feedback.
- (void)setGlyph:(UIImage *)glyph activeGlyph:(UIImage *)activeGlyph
			  on:(UIButton *)button active:(BOOL)active {
	TGTheme *theme = [TGTheme shared];
	UIColor *white = [theme onMediaColour];
	CGFloat side = TGMetricCallButtonSide;

	if (active) {
		[button setBackgroundImage:TGCallCircleImage(side, white, TGCallCircleStyleFilled, NO)
						  forState:UIControlStateNormal];
		[button setBackgroundImage:TGCallCircleImage(side, white, TGCallCircleStyleFilled, YES)
						  forState:UIControlStateHighlighted];
		[button setImage:activeGlyph forState:UIControlStateNormal];
	} else {
		[button setBackgroundImage:TGCallCircleImage(side, white, TGCallCircleStyleOutline, NO)
						  forState:UIControlStateNormal];
		[button setBackgroundImage:TGCallCircleImage(side, white, TGCallCircleStyleOutline, YES)
						  forState:UIControlStateHighlighted];
		[button setImage:glyph forState:UIControlStateNormal];
	}
}

- (void)end {
	// Hanging up takes a moment to come back from the network; without this
	// the screen just sits there and the tap looks like it was missed.
	[self setStatusText:@"End"];
	[self setStatusPulsing:NO];
	[self windDown];
	[[TGCall shared] hangUp];
	[self dismissShortly];
}

#pragma mark - leaving the screen without ending the call

- (void)minimise {
    [[TGCallMiniBar shared] showForUserId:self.userId
                                     name:self.nameLabel.text ?: self.peerName];
    [self.ticker invalidate];
    self.ticker = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
}

/// The call is over: the controls fade out and the backdrop goes red, so the
/// second before the screen closes shows what happened.
- (void)windDown {
    [self setStatusPulsing:NO];
    self.bgLayer.colors = TGCallGradient([[TGTheme shared] callGradientColoursFailed]);
    [UIView animateWithDuration:TGAnimationDurationMedium animations:^{
        for (UIView *view in @[self.speakerBtn, self.videoBtn, self.micBtn,
                               self.acceptBtn, self.speakerLbl, self.videoLbl,
                               self.micLbl, self.acceptLbl])
            view.alpha = TGAlphaTransparent;
        self.endBtn.alpha = TGAlphaDimmed;
    }];
}

/// A slow breath on the status while it is still ringing - the one hint that
/// the call is live and not stuck.
- (void)setStatusPulsing:(BOOL)pulsing {
    if (!pulsing){
        [self.statusLabel.layer removeAnimationForKey:@"pulse"];
        self.statusLabel.alpha = TGAlphaOpaque;
        return;
    }
    if ([self.statusLabel.layer animationForKey:@"pulse"])
        return;
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = @(TGAlphaOpaque);
    fade.toValue = @(TGAlphaDisabled);
    fade.duration = TGAnimationDurationSlow;
    fade.autoreverses = YES;
    fade.repeatCount = HUGE_VALF;
    [self.statusLabel.layer addAnimation:fade forKey:@"pulse"];
}

- (void)dismissShortly {
    [self.ticker invalidate];
    self.ticker = nil;
    [self performSelector:@selector(dismissNow) withObject:nil afterDelay:1.0];
}

- (void)dismissNow {
    [TGCall shared].onStateChanged = nil;
    [[TGCallMiniBar shared] hide];
    // A call that lasted a moment is not worth asking about, and asking
    // about a call nobody answered is worse than not asking. The controller
    // is kept alive by this block only until the prompt is on screen.
    NSTimeInterval talked = self.connectedAt ? -[self.connectedAt timeIntervalSinceNow] : 0;
    TGCallViewController *me = self;
    [self dismissViewControllerAnimated:YES completion:^{
        if (talked >= 10)
            [me askForCallRatingAfter:talked];
    }];
}

/// Telegram asks five stars and, for a poor score, what went wrong; that is
/// the whole shape of sendCallRating. The sheet belongs to the window, since
/// this screen is already gone when it appears.
- (void)askForCallRatingAfter:(NSTimeInterval)seconds {
    if (self.ratedCall || ![TGCall shared].lastCallId)
        return;
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window)
        return;
    NSArray *stars = @[@"★★★★★", @"★★★★", @"★★★", @"★★", @"★"];
    __weak typeof(self) weakSelf = self;
    [TGAlertSheet showChoices:stars
                        title:@"Rate This Call"
                      message:@"Please rate the quality\nof your Telegram call"
             destructiveIndex:-1
                       inView:window
                     onChoice:^(NSInteger index){
        TGCallViewController *me = weakSelf;
        if (!me)
            return;
        int rating = (int)(5 - index);
        me.ratedCall = YES;
        if (rating <= 3){
            [TGAlertSheet showInput:@"What went wrong?"
                            message:nil
                        placeholder:@"Add a comment..."
                               text:nil
                             action:@"Submit"
                             inView:window
                         onSubmit:^(NSString *comment){
                [[TGCall shared] sendRating:rating comment:comment problems:@[]];
            }];
            return;
        }
        [[TGCall shared] sendRating:rating comment:@"" problems:@[]];
    }];
}

@end
