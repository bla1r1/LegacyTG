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

@implementation TGMediaViewer (TGMediaViewerVideo)

#pragma mark - video

- (void)toggleMovie {
	if (self.softPlayer){
		if (self.softPlayer.isPlaying){
			[self.softPlayer pause];
			[self.playButton setImage:[self playGlyph] forState:UIControlStateNormal];
		} else {
			[self.softPlayer play];
			[self.playButton setImage:[self pauseGlyph] forState:UIControlStateNormal];
		}
		return;
	}
	if (self.player){
		// rate rather than a playback state: AVPlayer has no "playing" flag,
		// and a rate of zero is what paused means.
		if (self.player.rate > TGPlaybackSpeedStopped){
			[self.player pause];
			[self.playButton setImage:[self playGlyph] forState:UIControlStateNormal];
		} else {
			[self.player play];
			[self.playButton setImage:[self pauseGlyph] forState:UIControlStateNormal];
		}
		return;
	}

	NSDictionary *item = self.items[self.index];
	NSNumber *fileId = [self fileIdForItem:item];
	if (!fileId)
		return;

	self.triedMovieCopy = NO;
	self.triedSoftMovie = NO;
	self.timeLabel.text = @"...";
	__weak typeof(self) weakSelf = self;
	NSInteger fetchingPage = self.index;
	[self beginLoadingPage:fetchingPage];
	[[TGMediaStore shared] downloadFile:fileId.integerValue completion:^(NSString *path){
		[weakSelf endLoadingPage:fetchingPage];
		if (!path.length){
			weakSelf.timeLabel.text = @"--:--";
			return;
		}
		[weakSelf startMovieAtPath:path];
	}];
}

/// A layer in the page, playing where it was put. The controls above it are
/// the viewer's own, as the voice note's are: nothing here is the system's.
- (void)startMovieAtPath:(NSString *)path {
	UIView *page = self.pages[@(self.index)];
	if (!page)
		return;
	[self stopMovie];
	self.currentMoviePath = path;
	self.triedSoftMovie = NO;

	NSDictionary *item = self.items[self.index];
	self.movieLoops = [item[@"kind"] isEqualToString:@"messageAnimation"];

	// A GIF has no sound and should not duck what is already playing; a video
	// takes the session over, as any player does.
	if (!self.movieLoops){
		[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
											   error:nil];
		[[AVAudioSession sharedInstance] setActive:YES error:nil];
	}

	AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:
			[NSURL fileURLWithPath:path]];
	self.player = [AVPlayer playerWithPlayerItem:playerItem];
	self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;

	self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
	self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;

	self.playerView = [[TGMediaPlayerView alloc] initWithFrame:page.bounds];
	self.playerView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
									   UIViewAutoresizingFlexibleHeight;
	self.playerView.backgroundColor = [UIColor clearColor];
	self.playerView.playerLayer = self.playerLayer;
	[page addSubview:self.playerView];

	self.moviePage = self.index;
	[self.playButton setImage:[self pauseGlyph] forState:UIControlStateNormal];

	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(movieFinished)
				name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];

	[self.player play];
	self.movieTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self
			selector:@selector(movieTicked) userInfo:nil repeats:YES];
}

/// Seconds, or a negative number while the item is still working out how
/// long it is - which it does not know until it is ready to play.
- (NSTimeInterval)movieDuration {
	if (self.softPlayer)
		return self.softPlayer.duration > 0 ? self.softPlayer.duration : -1;
	AVPlayerItem *item = self.player.currentItem;
	if (!item)
		return -1;
	CMTime duration = item.duration;
	if (CMTIME_IS_INDEFINITE(duration) || !CMTIME_IS_VALID(duration))
		return -1;
	return CMTimeGetSeconds(duration);
}

- (NSTimeInterval)moviePosition {
	if (self.softPlayer)
		return self.softPlayer.position;
	if (!self.player)
		return 0;
	CMTime now = self.player.currentTime;
	return CMTIME_IS_VALID(now) ? CMTimeGetSeconds(now) : 0;
}

- (void)showVideoFormatAlert {
	[TGAlertSheet showMessage:@"An error occurred."
						title:@"Video" inView:self.backdrop];
}

/// The one place that decides what the software player gets: the smallest
/// copy Telegram offered, or the file already on disk when it is inside the
/// measured 720-pixel limit. Everything else ends at the alert.
- (void)startSoftPlaybackAfterFailure {
	NSDictionary *item = self.items[self.index];
	if (![item isKindOfClass:NSDictionary.class]){
		[self showVideoFormatAlert];
		return;
	}
	NSNumber *copy = item[@"videoFallbackId"];
	if ([copy isKindOfClass:NSNumber.class]){
		__weak typeof(self) weakSelf = self;
		NSInteger page = self.index;
		[self beginLoadingPage:page];
		[[TGMediaStore shared] downloadFile:copy.integerValue completion:^(NSString *path){
			[weakSelf endLoadingPage:page];
			if (!weakSelf || weakSelf.index != page)
				return;
			if (path.length)
				[weakSelf startSoftMovieAtPath:path];
			else
				[weakSelf showVideoFormatAlert];
		}];
		return;
	}
	// docWidth/docHeight are the chosen file's size; mediaWidth/mediaHeight
	// are the original's, which can be 1080 even when the file on disk is 480.
	int longSide = MAX([item[@"docWidth"] intValue], [item[@"docHeight"] intValue]);
	if (longSide <= 0)
		longSide = MAX([item[@"mediaWidth"] intValue], [item[@"mediaHeight"] intValue]);
	if (self.currentMoviePath.length && longSide > 0 &&
		longSide <= kSoftVideoMaxLongSide){
		[self startSoftMovieAtPath:self.currentMoviePath];
		return;
	}
	[self showVideoFormatAlert];
}

/// AVPlayer says nothing on its own when it cannot decode a file: the picture
/// stays black and the clock never moves. Vintage hands the file to FFmpeg;
/// every other tier tries one smaller copy and then says so.
- (void)movieFailed {
	NSLog(@"video playback: %@", self.player.currentItem.error);
	if ([TGDevice tier] == TGDeviceTierVintage && !self.triedSoftMovie){
		self.triedSoftMovie = YES;
		[self stopMovie];
		self.timeLabel.text = @"...";
		[self startSoftPlaybackAfterFailure];
		return;
	}
	NSNumber *copy = self.items[self.index][@"videoFallbackId"];
	[self stopMovie];
	self.timeLabel.text = @"--:--";
	if (self.triedMovieCopy || ![copy isKindOfClass:NSNumber.class]){
		[self showVideoFormatAlert];
		return;
	}
	self.triedMovieCopy = YES;
	self.timeLabel.text = @"...";
	__weak typeof(self) weakSelf = self;
	NSInteger page = self.index;
	[self beginLoadingPage:page];
	[[TGMediaStore shared] downloadFile:copy.integerValue completion:^(NSString *path){
		[weakSelf endLoadingPage:page];
		if (path.length && weakSelf.index == page)
			[weakSelf startMovieAtPath:path];
	}];
}

/// Same page, same controls, same looping rule as the AVPlayer path. The GL
/// view replaces the player layer where the page's picture already sits.
- (void)startSoftMovieAtPath:(NSString *)path {
	UIView *page = self.pages[@(self.index)];
	if (!page || !path.length){
		[self showVideoFormatAlert];
		return;
	}
	[self stopMovie];
	self.currentMoviePath = path;

	NSDictionary *item = self.items[self.index];
	self.movieLoops = [item[@"kind"] isEqualToString:@"messageAnimation"];
	if (!self.movieLoops){
		[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
											   error:nil];
		[[AVAudioSession sharedInstance] setActive:YES error:nil];
	}

	TGSoftVideoPlayer *soft = [[TGSoftVideoPlayer alloc] initWithPath:path];
	if (!soft){
		[self showVideoFormatAlert];
		return;
	}
	soft.loops = self.movieLoops;
	soft.view.frame = page.bounds;
	soft.view.autoresizingMask = UIViewAutoresizingFlexibleWidth |
								 UIViewAutoresizingFlexibleHeight;
	[page addSubview:soft.view];

	self.softPlayer = soft;
	self.moviePage = self.index;
	[self.playButton setImage:[self pauseGlyph] forState:UIControlStateNormal];

	__weak typeof(self) weakSelf = self;
	__weak TGSoftVideoPlayer *weakSoft = soft;
	soft.finished = ^{
		TGMediaViewer *me = weakSelf;
		if (!me || me.softPlayer != weakSoft)
			return;
		[me.playButton setImage:[me playGlyph] forState:UIControlStateNormal];
		me.scrubber.value = 0;
	};
	soft.failed = ^(NSError *error){
		TGMediaViewer *me = weakSelf;
		if (!me || me.softPlayer != weakSoft)
			return;
		NSLog(@"video playback (software): %@", error);
		[me stopMovie];
		me.timeLabel.text = @"--:--";
		[me showVideoFormatAlert];
	};

	[soft play];
	self.movieTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self
			selector:@selector(movieTicked) userInfo:nil repeats:YES];
}

- (void)movieTicked {
	if (self.softPlayer){
		NSTimeInterval duration = [self movieDuration];
		if (duration <= 0)
			return;
		NSTimeInterval at = [self moviePosition];
		if (!self.scrubber.tracking)
			self.scrubber.value = (float)(at / duration);
		NSInteger left = (NSInteger)MAX(0.0, duration - at);
		self.timeLabel.text = [NSString stringWithFormat:@"-%ld:%02ld",
				(long)(left / 60), (long)(left % 60)];
		return;
	}
	if (self.player.currentItem.status == AVPlayerItemStatusFailed){
		[self movieFailed];
		return;
	}
	NSTimeInterval duration = [self movieDuration];
	if (duration <= 0)
		return;
	NSTimeInterval at = [self moviePosition];
	if (!self.scrubber.tracking)
		self.scrubber.value = (float)(at / duration);
	NSInteger left = (NSInteger)MAX(0.0, duration - at);
	self.timeLabel.text = [NSString stringWithFormat:@"-%ld:%02ld",
			(long)(left / 60), (long)(left % 60)];
}

/// Exact, which is the point of the change: MPMoviePlayerController seeks to
/// the nearest keyframe, so a drag landed up to half a second from where the
/// finger was.
- (void)scrubberMoved {
	NSTimeInterval duration = [self movieDuration];
	if (duration <= 0)
		return;
	if (self.softPlayer){
		[self.softPlayer seekToTime:self.scrubber.value * duration];
		return;
	}
	CMTime target = CMTimeMakeWithSeconds(self.scrubber.value * duration,
										  NSEC_PER_SEC);
	[self.player seekToTime:target
			toleranceBefore:kCMTimeZero
			 toleranceAfter:kCMTimeZero];
}

- (void)movieFinished {
	if (self.movieLoops){
		[self.player seekToTime:kCMTimeZero];
		[self.player play];
		return;
	}
	[self.playButton setImage:[self playGlyph] forState:UIControlStateNormal];
	self.scrubber.value = 0;
	[self.player seekToTime:kCMTimeZero];
}

- (void)stopMovie {
	[self.movieTimer invalidate];
	self.movieTimer = nil;
	if (self.softPlayer){
		// Drop the callbacks first: stop must not run the viewer's failure
		// path while the page is being torn down.
		self.softPlayer.finished = nil;
		self.softPlayer.failed = nil;
		[self.softPlayer stop];
		[self.softPlayer.view removeFromSuperview];
		self.softPlayer = nil;
	}
	if (self.player){
		[[NSNotificationCenter defaultCenter] removeObserver:self
				name:AVPlayerItemDidPlayToEndTimeNotification
				object:self.player.currentItem];
		[self.player pause];
		[self.playerView removeFromSuperview];
		self.playerView = nil;
		self.playerLayer = nil;
		self.player = nil;
	}
	self.moviePage = NSNotFound;
	self.movieLoops = NO;
	[self.playButton setImage:[self playGlyph] forState:UIControlStateNormal];
	self.scrubber.value = 0;
}


@end
