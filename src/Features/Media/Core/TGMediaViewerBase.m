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

@implementation TGMediaViewer (TGMediaViewerBase)


+ (void)presentItems:(NSArray *)items startAt:(NSInteger)index inChat:(int64_t)chatId isAlbum:(BOOL)isAlbum {
	[self presentItems:items startAt:index inChat:chatId isAlbum:isAlbum fromView:nil];
}

+ (void)presentItems:(NSArray *)items startAt:(NSInteger)index inChat:(int64_t)chatId
			 isAlbum:(BOOL)isAlbum fromView:(UIView *)sourceView {
	NSMutableArray *media = [NSMutableArray array];
	NSInteger adjusted = 0;
	for (NSUInteger i = 0; i < items.count; i++){
		NSDictionary *m = items[i];
		NSString *kind = m[@"kind"];
		BOOL isPhoto = [kind isEqualToString:@"messagePhoto"];
		BOOL isVideo = [kind isEqualToString:@"messageVideo"] || [kind isEqualToString:@"messageAnimation"];
		if (!isPhoto && !isVideo)
			continue;
		if ((NSInteger)i <= index)
			adjusted = media.count;      // where the tapped one landed
		[media addObject:m];
	}
	if (!media.count)
		return;

	TGMediaViewer *viewer = [[TGMediaViewer alloc] init];
	viewer.items = media;
	viewer.index = MIN(MAX(adjusted, 0), (NSInteger)media.count - 1);
	viewer.chatId = chatId;
	viewer.isAlbum = isAlbum;
	viewer.sourceView = sourceView;
	[viewer present];
}

+ (void)presentItems:(NSArray *)items startAt:(NSInteger)index inChat:(int64_t)chatId {
	[self presentItems:items startAt:index inChat:chatId isAlbum:NO];
}

@end
