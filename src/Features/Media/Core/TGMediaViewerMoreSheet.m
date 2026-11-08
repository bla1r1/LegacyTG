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

@implementation TGMediaViewer (TGMediaViewerMoreSheet)

#pragma mark - the More sheet

/// The view controller a share sheet or the forward picker presents from.
/// The viewer is not one - it lives in the window directly - so the top of
/// the window's own stack stands in.
- (UIViewController *)hostController {
	UIWindow *window = self.window ?: [UIApplication sharedApplication].keyWindow;
	UIViewController *top = window.rootViewController;
	while (top.presentedViewController)
		top = top.presentedViewController;
	return top;
}

/// Telegram's gallery keeps file actions behind the header's More button, not
/// behind a hold: the hold is the message menu, this is what can be done with
/// the picture itself.
- (void)moreTapped {
	NSDictionary *m = [self currentItem];
	if (!m)
		return;

	// TDLib's can_be_saved is NO in a protected chat and for one-time media:
	// the picture may be looked at, not shared, saved or copied.
	BOOL saveable = !TGViewerItemLocked(m);
	NSMutableArray *choices = saveable
			? [NSMutableArray arrayWithObjects:@"Share", @"Forward", @"Copy Caption", nil]
			: [NSMutableArray array];
	NSInteger destructive = -1;
	if ([self currentFileId]){
		if (saveable){
			[choices addObject:@"Save to Camera Roll"];
			[choices addObject:@"Add to Downloads"];
		}
		[choices addObject:@"File Info"];
		[choices addObject:@"Delete from Device"];
		destructive = (NSInteger)choices.count - 1;
	}
	if ([m[@"hasStickers"] boolValue])
		[choices addObject:@"Sticker Packs..."];

	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices title:@"Media"
			 destructiveIndex:destructive inView:self.backdrop
					 onChoice:^(NSInteger index){
		TGMediaViewer *me = weakSelf;
		if (!me)
			return;
		NSString *what = choices[(NSUInteger)index];
		if ([what isEqualToString:@"Share"])
			[me shareCurrent];
		else if ([what isEqualToString:@"Forward"])
			[me forwardCurrent];
		else if ([what isEqualToString:@"Copy Caption"])
			[me copyCaption];
		else if ([what isEqualToString:@"Save to Camera Roll"])
			[me saveCurrent];
		else if ([what isEqualToString:@"Add to Downloads"])
			[me addCurrentToDownloads];
		else if ([what isEqualToString:@"File Info"])
			[me showFileInfo];
		else if ([what isEqualToString:@"Delete from Device"])
			[me deleteCurrentFromDevice];
		else if ([what isEqualToString:@"Sticker Packs..."])
			[me showStickerPacksOfFile:[me currentFileId].integerValue];
	}];
}

- (void)shareCurrent {
	if (TGViewerItemLocked([self currentItem]))
		return;
	UIImage *image = self.originals[@(self.index)];
	if (!image && ![self.placeholderPages containsObject:@(self.index)]){
		UIView *page = self.pages[@(self.index)];
		image = [(UIImageView *)[page viewWithTag:kZoomTag + 1] image];
	}
	if (image){
		[self presentShareItems:@[image]];
		return;
	}

	NSNumber *fileId = [self currentFileId];
	if (!fileId){
		[self copyCaption];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGMediaStore shared] downloadFile:fileId.integerValue completion:^(NSString *path){
		dispatch_async(dispatch_get_main_queue(), ^{
			TGMediaViewer *me = weakSelf;
			if (!me)
				return;
			if (!path.length){
				[TGAlertSheet showMessage:@"The file is not downloaded yet."
									  title:@"Share" inView:me.backdrop];
				return;
			}
			[me presentShareItems:@[[NSURL fileURLWithPath:path]]];
		});
	}];
}

- (void)presentShareItems:(NSArray *)items {
	UIViewController *top = [self hostController];
	if (!top || !items.count)
		return;
	UIActivityViewController *share = [[UIActivityViewController alloc]
			initWithActivityItems:items applicationActivities:nil];
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
		[share respondsToSelector:@selector(popoverPresentationController)]){
		share.popoverPresentationController.sourceView = self.backdrop;
		share.popoverPresentationController.sourceRect = CGRectMake(
				TGHalf(self.backdrop.bounds.size.width),
				TGHalf(self.backdrop.bounds.size.height), 0, 0);
	}
	[top presentViewController:share animated:YES completion:nil];
}

- (void)forwardCurrent {
	NSDictionary *m = [self currentItem];
	int64_t messageId = [m[@"id"] longLongValue];
	int64_t fromChat = self.chatId;
	if (!messageId || !fromChat){
		[TGAlertSheet showMessage:@"This item cannot be forwarded from the viewer."
							  title:@"Forward" inView:self.backdrop];
		return;
	}
	UIViewController *top = [self hostController];
	if (!top)
		return;

	TGForwardPicker *picker = [[TGForwardPicker alloc] init];
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(int64_t toChatId){
		if (!toChatId)
			return;
		[[TGClient shared] forwardMessages:@[@(messageId)]
								  fromChat:fromChat toChat:toChatId];
		TGMediaViewer *me = weakSelf;
		UIView *host = me.backdrop ?: [UIApplication sharedApplication].keyWindow;
		[TGSnackbar showInView:host text:@"Forwarded" seconds:2 onCommit:nil];
	};
	UINavigationController *nav = [[UINavigationController alloc]
			initWithRootViewController:picker];
	[top presentViewController:nav animated:YES completion:nil];
}

- (void)copyCaption {
	NSString *caption = [self currentItem][@"text"];
	if (!caption.length){
		[TGAlertSheet showMessage:@"This item has no caption."
							  title:@"Copy Caption" inView:self.backdrop];
		return;
	}
	[UIPasteboard generalPasteboard].string = caption;
	[TGSnackbar showInView:self.backdrop text:@"Caption copied" seconds:2 onCommit:nil];
}

- (void)addCurrentToDownloads {
	NSNumber *fileId = [self currentFileId];
	NSDictionary *m = [self currentItem];
	if (!fileId || !m)
		return;
	[[TGClient shared] addFileToDownloads:fileId.integerValue
								   inChat:self.chatId
								  message:[m[@"id"] longLongValue]];
	[TGSnackbar showInView:self.backdrop text:@"Added to Downloads" seconds:2
				  onCommit:nil];
}

- (void)showFileInfo {
	NSNumber *fileId = [self currentFileId];
	if (!fileId)
		return;
	dispatch_async(dispatch_get_main_queue(), ^{
		[TGFileInfoViewController presentForFile:fileId.integerValue
										fromView:self.backdrop];
	});
}

- (void)deleteCurrentFromDevice {
	NSNumber *fileId = [self currentFileId];
	if (!fileId)
		return;
	[[TGClient shared] deleteLocalFile:fileId.integerValue];
	[TGSnackbar showInView:self.backdrop text:@"Deleted from this device"
					 seconds:2 onCommit:nil];
}


@end
