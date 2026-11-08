#import "TGMediaViewer.h"
#import "TGMediaPlayerView.h"
#import "TGMediaStore.h"
#import "TGClient.h"
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

@implementation TGMediaViewer (TGMediaViewerSaving)

#pragma mark - saving

/// The flattened message on screen, or nil past the ends of the album.
- (NSDictionary *)currentItem {
	if (self.index < 0 || self.index >= (NSInteger)self.items.count)
		return nil;
	return self.items[self.index];
}

/// The file behind the page: a document for a video, the largest photo
/// otherwise. Fixture ids are negative and have no file to act on.
- (NSNumber *)currentFileId {
	NSDictionary *m = [self currentItem];
	NSNumber *fileId = m[@"docId"] ?: m[@"photoId"];
	if (![fileId isKindOfClass:NSNumber.class] || fileId.longLongValue <= 0)
		return nil;
	return fileId;
}

/// Holding the picture offers what belongs to the file rather than to the
/// message: a place in the download list their Download Manager reads, and
/// the local copy going away. Both have to name the chat and the message, so
/// the viewer is the only place that has all three.
- (void)mediaHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	NSNumber *fileId = [self currentFileId];
	if (!fileId)
		return;
	NSDictionary *m = [self currentItem];

	NSMutableArray *choices = [NSMutableArray arrayWithObjects:@"Add to Downloads",
							   @"File Info", @"Delete from Device", nil];
	// Media that other stickers were attached to knows which packs they came
	// from; TDLib answers that by the media file's own id.
	if ([m[@"hasStickers"] boolValue])
		[choices addObject:@"Sticker Packs..."];

	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices
						title:@"File"
			 destructiveIndex:2
					   inView:self.backdrop
					 onChoice:^(NSInteger index){
		TGMediaViewer *me = weakSelf;
		UIView *host = me.backdrop ?: [UIApplication sharedApplication].keyWindow;
		NSString *what = choices[(NSUInteger)index];
		if ([what isEqualToString:@"Sticker Packs..."]){
			[me showStickerPacksOfFile:fileId.integerValue];
			return;
		}
		if ([what isEqualToString:@"File Info"]){
			// The action sheet must be gone before the info sheet presents.
			dispatch_async(dispatch_get_main_queue(), ^{
				[TGFileInfoViewController presentForFile:fileId.integerValue fromView:host];
			});
			return;
		}
		if ([what isEqualToString:@"Add to Downloads"]){
			[[TGClient shared] addFileToDownloads:fileId.integerValue
											inChat:me.chatId
										   message:[m[@"id"] longLongValue]];
			[TGSnackbar showInView:host text:@"Added to Downloads" seconds:2 onCommit:nil];
			return;
		}
		[[TGClient shared] deleteLocalFile:fileId.integerValue];
		[TGSnackbar showInView:host text:@"Deleted from this device" seconds:2 onCommit:nil];
	}];
}

/// The packs the stickers on this media belong to, with the packs this
/// account does not have offered for install.
- (void)showStickerPacksOfFile:(NSInteger)fileId {
	__weak typeof(self) weakSelf = self;
	[[TGStickerStore shared] attachedStickerSetsOfFile:fileId completion:^(NSArray *sets){
		TGMediaViewer *me = weakSelf;
		UIView *host = me.backdrop ?: [UIApplication sharedApplication].keyWindow;
		NSArray *list = [sets isKindOfClass:NSArray.class] ? sets : @[];
		if (!list.count){
			[TGAlertSheet showMessage:@"This media carries no sticker packs."
								  title:@"Sticker Packs" inView:host];
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *set in list){
			NSString *title = [set[@"title"] length] ? set[@"title"] : @"Pack";
			NSString *state = [set[@"installed"] boolValue] ? @"" : @"  ·  tap to add";
			[rows addObject:[NSString stringWithFormat:@"%@%@", title, state]];
		}
		[TGAlertSheet showChoices:rows
							title:@"Sticker Packs"
				   destructiveIndex:-1
						   inView:host
						 onChoice:^(NSInteger index){
			NSDictionary *set = list[(NSUInteger)index];
			if ([set[@"installed"] boolValue])
				return;
			[[TGStickerStore shared] setStickerSet:set[@"id"] installed:YES archived:NO];
			[TGSnackbar showInView:host text:@"Sticker pack added" seconds:2 onCommit:nil];
		}];
	}];
}

- (void)saveCurrent {
	NSDictionary *item = [self currentItem];
	if (TGViewerItemLocked(item))
		return;
	BOOL isVideo = [item[@"kind"] isEqualToString:@"messageVideo"];
	if (isVideo){
		NSNumber *fileId = [self currentFileId];
		if (!fileId)
			return;
		__weak typeof(self) weakSelf = self;
		[[TGMediaStore shared] downloadFile:fileId.integerValue completion:^(NSString *path){
			dispatch_async(dispatch_get_main_queue(), ^{
				TGMediaViewer *me = weakSelf;
				if (!me)
					return;
				if (!path.length){
					[TGAlertSheet showMessage:@"The video is not downloaded yet."
										  title:@"Save" inView:me.backdrop];
					return;
				}
				UISaveVideoAtPathToSavedPhotosAlbum(path, me,
						@selector(video:didFinishSavingWithError:contextInfo:), NULL);
			});
		}];
		return;
	}

	UIImage *image = self.originals[@(self.index)];
	if (!image && ![self.placeholderPages containsObject:@(self.index)]){
		UIView *page = self.pages[@(self.index)];
		image = [(UIImageView *)[page viewWithTag:kZoomTag + 1] image];
	}
	if (!image)
		return;
	UIImageWriteToSavedPhotosAlbum(image, self,
			@selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)video:(NSString *)path didFinishSavingWithError:(NSError *)error
   contextInfo:(void *)contextInfo {
	[TGAlertSheet showMessage:(error ? @"Could not save" : @"Saved to Camera Roll")
						title:nil
					   inView:(self.backdrop ?: [UIApplication sharedApplication].keyWindow)];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error
  contextInfo:(void *)contextInfo {
	// The viewer is an NSObject, not a view: passing it here asked a plain
	// object for its bounds and brought the app down the moment a picture
	// finished saving. Its backdrop is the view on screen.
	[TGAlertSheet showMessage:(error ? @"Could not save" : @"Saved to Camera Roll")
						title:nil
					   inView:(self.backdrop ?: [UIApplication sharedApplication].keyWindow)];
}

- (void)dealloc {
	[self restoreSource];
	[self.movieTimer invalidate];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
