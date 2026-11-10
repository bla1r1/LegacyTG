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

@implementation TGMediaViewer (TGMediaViewerTransitions)

#pragma mark - open and close transitions

/// Where the viewer's picture lands and leaves from, as a transform. The ghost
/// is laid out at its resting frame and scaled down onto the bubble, so the
/// render server moves one texture and the main thread does nothing for the
/// length of the animation. The scale is not uniform: a bubble that crops its
/// photo is a different shape from the photo, and for 250 ms nobody sees the
/// difference.
static CGAffineTransform TGTransformOnto(CGRect resting, CGRect target) {
	CGFloat sx = target.size.width  / MAX(resting.size.width,  TGMetricScaleFull);
	CGFloat sy = target.size.height / MAX(resting.size.height, TGMetricScaleFull);
	return CGAffineTransformMake(sx, 0, 0, sy,
			CGRectGetMidX(target) - CGRectGetMidX(resting),
			CGRectGetMidY(target) - CGRectGetMidY(resting));
}

- (UIImageView *)sourceImageView {
	UIView *source = self.sourceView;
	return [source isKindOfClass:UIImageView.class] ? (UIImageView *)source : nil;
}

- (void)setEdgeChromeAlpha:(CGFloat)alpha {
	self.topBar.alpha = alpha;
	self.bottomBar.alpha = alpha;
	self.thumbStrip.alpha = alpha;
	self.statusPlate.alpha = alpha;
}

/// The chrome comes in after the picture has landed, so the eye has one thing
/// to follow at a time.
- (void)fadeInChrome {
	self.backdrop.userInteractionEnabled = YES;
	[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
		CGFloat alpha = self.chromeHidden ? TGAlphaTransparent : TGAlphaOpaque;
		self.topBar.alpha = alpha;
		self.bottomBar.alpha = alpha;
		self.thumbStrip.alpha = alpha;
		self.statusPlate.alpha = TGAlphaOpaque;
	}];
}

- (void)runOpenTransition {
	UIColor *dim = [[TGTheme shared] mediaViewerBackdropColour];
	UIImageView *source = [self sourceImageView];
	UIImage *thumb = source.image;
	CGRect from = source ? [source convertRect:source.bounds toView:self.backdrop] : CGRectZero;
	BOOL grows = thumb && thumb.size.width > 0 && thumb.size.height > 0 &&
			source.window && !source.hidden &&
			CGRectIntersectsRect(from, self.backdrop.bounds);

	[self setEdgeChromeAlpha:TGAlphaTransparent];
	// Touches during the 250 ms would meet a viewer that is half built.
	self.backdrop.userInteractionEnabled = NO;

	if (!grows){
		self.sourceView = nil;      // nothing to hide, nothing to return to
		self.pager.alpha = TGAlphaTransparent;
		[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
			self.backdrop.backgroundColor = dim;
			self.pager.alpha = TGAlphaOpaque;
		} completion:^(BOOL done){
			[self fadeInChrome];
		}];
		return;
	}

	CGRect resting = AVMakeRectWithAspectRatioInsideRect(thumb.size, self.backdrop.bounds);
	UIImageView *ghost = [[UIImageView alloc] initWithFrame:resting];
	ghost.image = thumb;
	ghost.contentMode = UIViewContentModeScaleToFill;
	ghost.userInteractionEnabled = NO;
	ghost.transform = TGTransformOnto(resting, from);
	// The pager waits until the ghost has landed: its page is still empty, and
	// its spinner would show beside a picture that is on its way.
	self.pager.alpha = TGAlphaTransparent;
	[self.backdrop insertSubview:ghost aboveSubview:self.pager];

	source.hidden = YES;
	self.sourceHidden = YES;

	__weak typeof(self) weakSelf = self;
	[UIView animateWithDuration:TGAnimationDurationMedium
						  delay:0
						options:UIViewAnimationOptionCurveEaseOut
					 animations:^{
		ghost.transform = CGAffineTransformIdentity;
		self.backdrop.backgroundColor = dim;
	} completion:^(BOOL done){
		TGMediaViewer *me = weakSelf;
		if (me)
			[me landedWithGhost:ghost thumbnail:thumb];
		else
			[ghost removeFromSuperview];
	}];
}

/// The thumbnail stays on the page as its picture until the original arrives,
/// so the swap from ghost to page is the same pixels in the same place.
- (void)landedWithGhost:(UIImageView *)ghost thumbnail:(UIImage *)thumb {
	UIImageView *picture = (UIImageView *)[[self currentPage] viewWithTag:kZoomTag + 1];
	if (picture && !picture.image){
		picture.image = thumb;
		[self.placeholderPages addObject:@(self.startIndex)];
	}
	self.pager.alpha = TGAlphaOpaque;
	[ghost removeFromSuperview];
	[self fadeInChrome];
}

/// A ghost of the picture as it is on screen now, with the rect it should
/// shrink into. Nil whenever the way back is not certain: the page was changed
/// or zoomed, the bubble has scrolled away or been reused, or the picture has
/// not arrived. Those fade instead.
- (UIImageView *)closingGhostTarget:(CGRect *)target {
	UIImageView *source = [self sourceImageView];
	if (!source || !source.window || self.dragging || self.index != self.startIndex)
		return nil;
	UIScrollView *page = [self currentPage];
	UIImageView *picture = (UIImageView *)[page viewWithTag:kZoomTag + 1];
	UIImage *image = picture.image;
	if (!image || page.zoomScale > page.minimumZoomScale + TGAlphaEpsilon)
		return nil;
	CGRect to = [source convertRect:source.bounds toView:self.backdrop];
	if (!CGRectIntersectsRect(to, self.backdrop.bounds))
		return nil;

	CGRect fit = AVMakeRectWithAspectRatioInsideRect(image.size, picture.bounds);
	UIImageView *ghost = [[UIImageView alloc] initWithFrame:
			[picture convertRect:fit toView:self.backdrop]];
	ghost.image = image;
	ghost.contentMode = UIViewContentModeScaleToFill;
	ghost.userInteractionEnabled = NO;
	*target = to;
	return ghost;
}

- (void)restoreSource {
	if (self.sourceHidden)
		self.sourceView.hidden = NO;
	self.sourceHidden = NO;
}

- (void)dismiss {
	[self dismissWithZoom:YES];
}

- (void)dismissWithZoom:(BOOL)zoom {
	if (self.dismissing)
		return;
	self.dismissing = YES;
	self.backdrop.userInteractionEnabled = NO;
	[self stopMovie];
	[[UIApplication sharedApplication] setStatusBarHidden:self.statusBarWasHidden
											withAnimation:UIStatusBarAnimationFade];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	// The completion blocks hold the backdrop rather than self: the viewer
	// holds itself up until they run, and nothing should keep it past that.
	UIView *backdrop = self.backdrop;
	__weak typeof(self) weakSelf = self;
	void (^finish)(void) = ^{
		[backdrop removeFromSuperview];
		weakSelf.self_ = nil;       // and now it can go
	};

	CGRect target = CGRectZero;
	UIImageView *ghost = zoom ? [self closingGhostTarget:&target] : nil;
	if (!ghost){
		// The bubble shows through the fading backdrop, so it comes back first.
		[self restoreSource];
		[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
			backdrop.alpha = TGAlphaTransparent;
		} completion:^(BOOL done){ finish(); }];
		return;
	}

	// The ghost is drawn over the picture it copies, so hiding the pager the
	// same instant changes nothing on screen.
	CGRect resting = ghost.frame;
	[self.backdrop insertSubview:ghost aboveSubview:self.pager];
	self.pager.hidden = YES;
	[UIView animateWithDuration:TGAnimationDurationMedium
						  delay:0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^{
		ghost.transform = TGTransformOnto(resting, target);
		backdrop.backgroundColor = [UIColor clearColor];
		[self setEdgeChromeAlpha:TGAlphaTransparent];
	} completion:^(BOOL done){
		// The ghost is a squashed copy with square corners; the bubble is the
		// real thing. Letting one dissolve into the other hides the join.
		[weakSelf restoreSource];
		[UIView animateWithDuration:TGAnimationDurationFast animations:^{
			ghost.alpha = TGAlphaTransparent;
		} completion:^(BOOL finished){ finish(); }];
	}];
}


@end
