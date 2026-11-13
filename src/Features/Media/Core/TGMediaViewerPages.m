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
static const NSInteger kZoomTag = 0x7001;


/// A view whose whole job is to keep the player layer filling it. A CALayer
/// does not autoresize, and this app rotates - the old movie view had its
/// frame set once too, and came out the wrong shape after a turn.



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
