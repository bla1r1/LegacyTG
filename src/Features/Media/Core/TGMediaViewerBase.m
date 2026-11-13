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


/// A view whose whole job is to keep the player layer filling it. A CALayer
/// does not autoresize, and this app rotates - the old movie view had its
/// frame set once too, and came out the wrong shape after a turn.



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
