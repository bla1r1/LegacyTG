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

@implementation TGMediaViewer (TGMediaViewerProgress)

#pragma mark - progress

/// Counts work in flight for a page and shows a white spinner while there is
/// any. The spinner waits TGAnimationDurationNormal before it fades in, so a
/// picture that is already on disk never flashes one.
- (void)beginLoadingPage:(NSInteger)page {
	[self.loading addObject:@(page)];
	[self refreshSpinnerForPage:page];
}

- (void)endLoadingPage:(NSInteger)page {
	if (![NSThread isMainThread]){
		dispatch_async(dispatch_get_main_queue(), ^{ [self endLoadingPage:page]; });
		return;
	}
	[self.loading removeObject:@(page)];
	[self refreshSpinnerForPage:page];
}

- (void)refreshSpinnerForPage:(NSInteger)page {
	UIScrollView *zoom = self.pages[@(page)];
	if (!zoom)
		return;
	UIActivityIndicatorView *spinner = (UIActivityIndicatorView *)
			[zoom viewWithTag:kZoomTag + kSpinnerOffset];
	if ([self.loading countForObject:@(page)] == 0){
		[spinner stopAnimating];
		[spinner removeFromSuperview];
		return;
	}
	if (spinner)
		return;
	spinner = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	spinner.tag = kZoomTag + kSpinnerOffset;
	spinner.center = CGPointMake(TGHalf(zoom.bounds.size.width), TGHalf(zoom.bounds.size.height));
	spinner.userInteractionEnabled = NO;
	spinner.alpha = TGAlphaTransparent;
	[zoom addSubview:spinner];
	[spinner startAnimating];
	[UIView animateWithDuration:TGAnimationDurationNormal
						  delay:TGAnimationDurationNormal
						options:0
					 animations:^{ spinner.alpha = TGAlphaOpaque; }
					 completion:nil];
}

/// The original replaces whatever the page was showing. On screen it dissolves
/// in; a hard swap from a blurry thumbnail to the sharp one reads as a glitch.
- (void)showOriginal:(UIImage *)image inPicture:(UIImageView *)picture page:(NSInteger)page {
	UIView *zoom = self.pages[@(page)];
	if (!zoom || [zoom viewWithTag:kZoomTag + 1] != picture)
		return;     // the page was dropped while this was decoding
	self.originals[@(page)] = image;
	[self.placeholderPages removeObject:@(page)];
	if (picture.window){
		CATransition *fade = [CATransition animation];
		fade.type = kCATransitionFade;
		fade.duration = TGAnimationDurationNormal;
		[picture.layer addAnimation:fade forKey:@"tg.original"];
	}
	picture.image = image;
}

/// Downloads and displays full-resolution media, using thumbnail as placeholder.
- (void)fetchOriginalForPage:(NSInteger)page into:(UIImageView *)picture {
	NSDictionary *item = self.items[page];
	NSNumber *fileId = [self fileIdForItem:item];
	if (!fileId)
		return;

#if TG_DEV
	if (fileId.longLongValue < 0) {
		UIImage *fixture = [TGDevShowcase imageForPhotoId:fileId.longLongValue];
		if (fixture) {
			self.originals[@(page)] = fixture;
			picture.image = fixture;
			return;
		}
	}
#endif

	CGSize screen = self.backdrop.bounds.size;
	CGFloat scale = [UIScreen mainScreen].scale;

	BOOL isVideo = [item[@"kind"] isEqualToString:@"messageVideo"];
	BOOL isAnim = [item[@"kind"] isEqualToString:@"messageAnimation"];
	if (isVideo || isAnim){
		// A video/GIF poster frame is its thumbnail; the file itself is only
		// fetched when the play button is pressed (or auto-started for GIFs).
		NSNumber *thumb = item[@"photoId"];
		if ([thumb isKindOfClass:NSNumber.class]){
			__weak typeof(self) posterSelf = self;
			[self beginLoadingPage:page];
			[[TGMediaStore shared] downloadFile:thumb.integerValue completion:^(NSString *path){
				if (!path.length){
					[posterSelf endLoadingPage:page];
					return;
				}
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					UIImage *poster = [TGIcons decodedImage:[UIImage imageWithContentsOfFile:path]
												fittingSize:screen fill:NO scale:scale];
					dispatch_async(dispatch_get_main_queue(), ^{
						TGMediaViewer *me = posterSelf;
						if (poster && me && !picture.image)
							picture.image = poster;
						[me endLoadingPage:page];
					});
				});
			}];
		}
		if (isAnim && page == self.index){
			[self toggleMovie];
		}
		return;
	}

	if ([self.requested containsObject:fileId])
		return;
	[self.requested addObject:fileId];

	__weak typeof(self) weakSelf = self;
	[self beginLoadingPage:page];
	[[TGMediaStore shared] downloadFile:fileId.integerValue completion:^(NSString *path){
		if (!path.length){
			[weakSelf endLoadingPage:page];
			return;
		}
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			UIImage *image = [UIImage imageWithContentsOfFile:path];
			if (!image && [path.pathExtension.lowercaseString isEqualToString:@"webp"])
				image = [UIImage convertFromWebP:path compressedData:nil error:nil];
			// Fitted to the screen rather than the bubble: a 4S has 512MB and
			// a 3000px photo decoded whole is most of what is left of it.
			image = [TGIcons decodedImage:image fittingSize:screen fill:NO scale:scale];
			dispatch_async(dispatch_get_main_queue(), ^{
				TGMediaViewer *me = weakSelf;
				if (image)
					[me showOriginal:image inPicture:picture page:page];
				[me endLoadingPage:page];
			});
		});
	}];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
	return (scrollView == self.pager) ? nil : [scrollView viewWithTag:kZoomTag + 1];
}

/// A picture smaller than the screen sticks to the top left as it is zoomed
/// out, which is the usual scroll view behaviour and the wrong one here.
- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
	if (scrollView == self.pager)
		return;
	UIView *picture = [scrollView viewWithTag:kZoomTag + 1];
	if (!picture)
		return;
	CGSize bounds = scrollView.bounds.size;
	CGRect frame = picture.frame;
	frame.origin.x = frame.size.width  < bounds.width
			? TGCenteredOrigin(bounds.width, frame.size.width) : 0;
	frame.origin.y = frame.size.height < bounds.height
			? TGCenteredOrigin(bounds.height, frame.size.height) : 0;
	picture.frame = frame;
}

/// The page the pager is on, which is where a zoom or a drag applies.
- (UIScrollView *)currentPage {
	return self.pages[@(self.index)];
}

- (void)doubleTapped:(UITapGestureRecognizer *)tap {
	UIScrollView *page = [self currentPage];
	if (!page)
		return;
	if (page.zoomScale > page.minimumZoomScale + TGAlphaEpsilon){
		[page setZoomScale:page.minimumZoomScale animated:YES];
		return;
	}
	// Zoomed about the point that was tapped rather than about the middle,
	// so the thing being looked at stays where it is.
	CGPoint at = [tap locationInView:[page viewWithTag:kZoomTag + 1]];
	CGFloat scale = MIN(page.maximumZoomScale, TGMetricZoomDoubleTap);
	CGSize size = page.bounds.size;
	[page zoomToRect:CGRectMake(at.x - TGHalf(size.width / scale),
								at.y - TGHalf(size.height / scale),
								size.width / scale, size.height / scale)
			animated:YES];
}

/// The drag only belongs to the viewer while the page is not zoomed; once it
/// is, the scroll view owns every pan inside it.
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
	if (![gesture isKindOfClass:UIPanGestureRecognizer.class])
		return YES;
	UIScrollView *page = [self currentPage];
	if (page && page.zoomScale > page.minimumZoomScale + TGAlphaEpsilon)
		return NO;
	// Downwards only: sideways is the pager's, and it has to stay the
	// pager's or the viewer closes while flicking between pictures.
	CGPoint velocity = [(UIPanGestureRecognizer *)gesture velocityInView:self.backdrop];
	return fabs(velocity.y) > fabs(velocity.x);
}

- (void)dragged:(UIPanGestureRecognizer *)drag {
	UIScrollView *page = [self currentPage];
	if (!page)
		return;

	CGPoint moved = [drag translationInView:self.backdrop];

	if (drag.state == UIGestureRecognizerStateBegan){
		self.dragging = YES;
		self.dragOrigin = page.center;
		// The chrome is in the way of a picture being thrown off screen.
		[UIView animateWithDuration:TGAnimationDurationFast animations:^{
			self.topBar.alpha = TGAlphaTransparent;
			self.bottomBar.alpha = TGAlphaTransparent;
			self.thumbStrip.alpha = TGAlphaTransparent;
		}];
		return;
	}

	if (drag.state == UIGestureRecognizerStateChanged){
		page.center = CGPointMake(self.dragOrigin.x + TGHalf(moved.x),
								  self.dragOrigin.y + moved.y);
		// Thinner the further it has gone, down to a third - what is behind
		// the picture is where the drag is heading.
		CGFloat fade = TGAlphaOpaque - MIN(TGMetricViewerMaxFadeRatio, fabs(moved.y) / TGMetricViewerFadeDistance);
		self.backdrop.backgroundColor = [[[TGTheme shared] mediaViewerBackdropColour] colorWithAlphaComponent:fade];
		return;
	}

	if (drag.state != UIGestureRecognizerStateEnded &&
		drag.state != UIGestureRecognizerStateCancelled)
		return;

	self.dragging = NO;
	CGFloat velocity = [drag velocityInView:self.backdrop].y;
	BOOL leaves = fabs(moved.y) > TGMetricViewerDismissDistance || fabs(velocity) > TGMetricViewerDismissVelocity;
	if (leaves){
		// It keeps going the way it was thrown rather than stopping where
		// the finger let go.
		CGFloat direction = (moved.y > 0 || velocity > 0) ? 1 : -1;
		[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
			page.center = CGPointMake(page.center.x, self.dragOrigin.y +
					direction * self.backdrop.bounds.size.height);
			self.backdrop.backgroundColor = [UIColor clearColor];
		} completion:^(BOOL done){
			[self dismissWithZoom:NO];
		}];
		return;
	}

	[UIView animateWithDuration:TGAnimationDurationMedium animations:^{
		page.center = self.dragOrigin;
		self.backdrop.backgroundColor = [[TGTheme shared] mediaViewerBackdropColour];
		self.topBar.alpha = self.chromeHidden ? 0 : 1;
		self.bottomBar.alpha = self.chromeHidden ? 0 : 1;
		self.thumbStrip.alpha = self.chromeHidden ? 0 : 1;
	}];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView != self.pager)
		return;
	NSInteger page = (NSInteger)roundf(scrollView.contentOffset.x /
			MAX(TGMetricScaleFull, scrollView.bounds.size.width));
	page = MIN(MAX(page, 0), (NSInteger)self.items.count - 1);
	if (page == self.index)
		return;

	// Leaving a video's page has to stop it, or it goes on playing behind a
	// picture two pages away.
	if (self.moviePage != NSNotFound && page != self.moviePage)
		[self stopMovie];

	self.index = page;
	[self loadPagesAround:page];
	[self fadeChromeText];
	[self refreshChrome];
	[self updateThumbStripSelection:YES];
}


@end
