#import "TGMediaViewer.h"
#import "TGMediaPlayerView.h"
#import "TGMediaStore.h"
#import "TGDevice.h"
#import "TGSoftVideoPlayer.h"
#import "TGStickerStore.h"
#import "TGSnackbar.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "UIImage+WebP.h"
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGDevShowcase.h"
#import "TGFileInfoViewController.h"
#import "TGForwardPicker.h"
#import "TGMessageLayout.h"
#import "TGMediaViewerInternal.h"


// The chrome sits over the picture rather than beside it, which is what makes
// the picture the whole screen. Both strips fade out on a tap and come back on
// the next one, as theirs do.
static const CGFloat kTopBar    = TGMetricViewerTopBar;
static const CGFloat kBottomBar = TGMetricViewerBottomBar;
static const NSInteger kZoomTag = 0x7001;
static const NSInteger kSpinnerOffset = 2;   // kZoomTag + 2 is a page's spinner

/// The top bar stacks the counter over the date; Done sits beside them. The
/// bottom bar carries the caption, Save, and - on a video - a transport strip
/// under both. These are this viewer's own, named here rather than in TGStyle.
static const CGFloat kChromeInset   = TGMetricPadSmall;
static const CGFloat kCaptionInset  = TGMetricPadMedium + TGMetricPadTiny;
static const CGFloat kCaptionHeight = 34.0f;
static const CGFloat kSaveWidth     = 68.0f;
static const CGFloat kStripTop      = 38.0f;
static const CGFloat kStripHeight   = 22.0f;
static const CGFloat kPlayWidth     = 30.0f;
static const CGFloat kScrubberLeft  = 42.0f;
static const CGFloat kClockWidth    = 52.0f;
static const CGFloat kThumbSide     = 42.0f;
static const CGFloat kThumbGap      = 6.0f;
static const CGFloat kThumbStripH   = 54.0f;
/// The software decoder is measured at 480x480; anything over 720 on its
/// long side (1080x1080 is 19-25 fps) is not attempted.
static const int kSoftVideoMaxLongSide = 720;

/// A view whose whole job is to keep the player layer filling it. A CALayer
/// does not autoresize, and this app rotates - the old movie view had its
/// frame set once too, and came out the wrong shape after a turn.


/// Pages come from chats, profiles and galleries; only a chat message says
/// whether it may leave, and only an explicit NO locks it.
static BOOL TGViewerItemLocked(NSDictionary *item) {
	id saveable = item[@"canBeSaved"];
	return [saveable isKindOfClass:NSNumber.class] && ![saveable boolValue];
}


// vim:ft=objc

@implementation TGMediaViewer (TGMediaViewerPresenting)

#pragma mark - presenting

- (void)present {
	self.self_ = self;      // nothing else owns this while it is up

	// The viewer is the whole screen, as Telegram's is: the status bar goes
	// while it is up. Where the system keeps it (a view controller decides
	// from iOS 7), buildChrome leaves it room instead.
	UIApplication *app = [UIApplication sharedApplication];
	self.statusBarWasHidden = app.statusBarHidden;
	[app setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];

	self.window = app.keyWindow;
	CGRect bounds = self.window.bounds;

	// A window-sized view and nobody owning it but itself: no layout pass
	// comes through here, so a rotation is carried by this notification.
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(relayoutViewer)
			name:UIApplicationDidChangeStatusBarOrientationNotification
			object:nil];

	self.backdrop = [[UIView alloc] initWithFrame:bounds];
	// Clear to start with, and brought up to the backdrop colour by the open
	// transition. Fading the view's alpha instead would fade the grown picture
	// and the chrome with it.
	self.backdrop.backgroundColor = [UIColor clearColor];
	[self.window addSubview:self.backdrop];

	self.pager = [[UIScrollView alloc] initWithFrame:bounds];
	self.pager.pagingEnabled = YES;
	self.pager.delegate = self;
	self.pager.showsHorizontalScrollIndicator = NO;
	self.pager.contentSize = CGSizeMake(bounds.size.width * self.items.count,
										bounds.size.height);
	self.pager.contentOffset = CGPointMake(bounds.size.width * self.index, 0);
	[self.backdrop addSubview:self.pager];

	[self buildChrome];
	if (self.isAlbum) {
		[self buildThumbStrip];
	}

	UITapGestureRecognizer *single = [[UITapGestureRecognizer alloc]
			initWithTarget:self action:@selector(tapAt:)];
	single.delegate = self;
	[self.backdrop addGestureRecognizer:single];

	// Two taps is how a picture is zoomed everywhere else, and this viewer
	// had only the pinch - which needs two hands on a phone being held.
	UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc]
			initWithTarget:self action:@selector(doubleTapped:)];
	doubleTap.numberOfTapsRequired = 2;
	[self.backdrop addGestureRecognizer:doubleTap];
	[single requireGestureRecognizerToFail:doubleTap];

	// A flick down closed it at once, whatever the finger had been doing.
	// A drag is better: the picture comes with the finger, the backdrop
	// thins as it goes, and letting go before it has gone far enough puts
	// it back - so the gesture can be changed halfway through.
	UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc]
			initWithTarget:self action:@selector(dragged:)];
	drag.delegate = self;
	[self.backdrop addGestureRecognizer:drag];

	// The file's own lot - the download list, the copy on this device - is
	// not a message action: it follows the picture, whichever page is up.
	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(mediaHeld:)];
	hold.minimumPressDuration = 0.5;
	[self.backdrop addGestureRecognizer:hold];

	[self loadPagesAround:self.index];
	[self refreshChrome];

	self.startIndex = self.index;
	[self runOpenTransition];
}


@end
