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

@implementation TGMediaViewer (TGMediaViewerPages)

#pragma mark - pages

/// The file this item *is*, not the one it shows. A video message carries both
/// - "docId" is the video and "photoId" is its poster frame - so preferring
/// photoId handed the movie player a JPEG and it sat there doing nothing.
- (NSNumber *)fileIdForItem:(NSDictionary *)item {
	BOOL isVideo = [item[@"kind"] isEqualToString:@"messageVideo"] || [item[@"kind"] isEqualToString:@"messageAnimation"];
	NSNumber *fileId = isVideo ? item[@"docId"] : (item[@"bigPhotoId"] ?: item[@"photoId"]);
	if ([fileId isKindOfClass:NSNumber.class])
		return fileId;
	// A photo with no photoId, or a video with no docId: fall back to whatever
	// the other key holds rather than showing nothing at all.
	fileId = isVideo ? item[@"photoId"] : item[@"docId"];
	return [fileId isKindOfClass:NSNumber.class] ? fileId : nil;
}

/// Only the page in view and its two neighbours are built. Everything else is
/// dropped, so paging through a long chat does not walk the device out of
/// memory one full-size picture at a time.
- (void)loadPagesAround:(NSInteger)centre {
	CGRect bounds = self.backdrop.bounds;

	for (NSNumber *key in [self.pages allKeys]){
		NSInteger i = key.integerValue;
		if (labs(i - centre) <= 1)
			continue;
		[(UIView *)self.pages[key] removeFromSuperview];
		[self.pages removeObjectForKey:key];
		[self.originals removeObjectForKey:key];
		[self.placeholderPages removeObject:key];
		while ([self.loading containsObject:key])
			[self.loading removeObject:key];
		// Without this a page scrolled back to was built empty and never asked
		// again, because its file still counted as requested.
		NSNumber *dropped = [self fileIdForItem:self.items[i]];
		if (dropped)
			[self.requested removeObject:dropped];
	}

	for (NSInteger i = MAX(0, centre - 1);
		 i <= MIN((NSInteger)self.items.count - 1, centre + 1); i++){
		if (self.pages[@(i)])
			continue;

		UIScrollView *zoom = [[UIScrollView alloc] initWithFrame:
				CGRectMake(bounds.size.width * i, 0, bounds.size.width, bounds.size.height)];
		zoom.minimumZoomScale = TGMetricZoomMin;
		zoom.maximumZoomScale = TGMetricZoomMax;
		zoom.delegate = self;
		zoom.showsHorizontalScrollIndicator = NO;
		zoom.showsVerticalScrollIndicator = NO;
		zoom.tag = kZoomTag;

		UIImageView *picture = [[UIImageView alloc] initWithFrame:zoom.bounds];
		picture.contentMode = UIViewContentModeScaleAspectFit;
		picture.tag = kZoomTag + 1;
		[zoom addSubview:picture];

		[self.pager addSubview:zoom];
		self.pages[@(i)] = zoom;

		[self fetchOriginalForPage:i into:picture];
	}
}


@end
