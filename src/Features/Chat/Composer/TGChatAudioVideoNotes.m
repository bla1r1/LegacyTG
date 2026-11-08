#import "TGChatViewControllerInternal.h"
#import "TGVideoNoteRecorder.h"
#import "TGVideoNoteViewController.h"
#import "TGPlaybackQueue.h"
#import "TGMessageStreamStore.h"
#import "TGVoiceRecorder.h"
#import "TGVoiceDecoder.h"
#import "TGMusicPlayer.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGPlayerView.h"


static CGPoint sTouchStart;
static CGFloat sDragDeltaX;
static BOOL sIsLocked;
static BOOL sIsCancelled;
static BOOL sSendInFlight;
/// The local row a note shows before TDLib knows it. Above every real and
/// pending id, so it sorts last and cannot collide with one.
static int64_t sLocalNoteRowCounter;

/// The tap-to-toggle threshold: release before it and the touch was a mode
/// switch, not a recording - Telegram waits the same beat before it starts
/// writing, so a tap never produces a stray shard of audio.
static const NSTimeInterval kRecordToggleTapSeconds = 0.25;
/// How long the hint under a mode switch stays readable.
static const NSTimeInterval kRecordHintSeconds = 1.6;


@implementation TGChatViewController (TGChatAudioVideoNotes)

#pragma mark - video notes

/// Plays a round note over the circle it belongs to, clipped to the same shape.
/// MPMoviePlayerController is the only decoder iOS 7 offers, but it does not
/// have to own the screen: its view goes in a mask of our own.
- (void)playVideoNoteAtPath:(NSString *)path row:(NSInteger)row {
	// One voice at a time, and togglePlayback looks at music first, so a track
	// left playing would take the circle's pause for itself.
	if (self.voicePlayer || [TGMusicPlayer shared].current)
		[self stopPlayback];
	[self stopVideoNote];

	if (row >= 0 && row < (NSInteger)self.messages.count){
		NSDictionary *played = self.messages[row];
		if (![played[@"outgoing"] boolValue])
			[[TGClient shared] openContentOfMessage:[played[@"id"] longLongValue]
											 inChat:self.chatId];
	}

	CGFloat side = TGMetricRoundVideoSide;
	CGRect inTable = [self.table rectForRowAtIndexPath:
			[NSIndexPath indexPathForRow:row inSection:0]];
	NSDictionary *m = self.messages[row];
	CGFloat x = [m[@"outgoing"] boolValue]
			? (self.table.bounds.size.width - side - TGMetricPad) : TGMetricPad;

	UIView *circle = [[UIView alloc] initWithFrame:
			CGRectMake(x, inTable.origin.y + TGMetricBubbleRowInset, side, side)];
	circle.layer.cornerRadius = TGHalf(side);
	circle.clipsToBounds = YES;
	circle.layer.masksToBounds = YES;
	circle.backgroundColor = [[TGTheme shared] mediaViewerBackdropColour];
	circle.tag = 0xF119;

	[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
	[[AVAudioSession sharedInstance] setActive:YES error:nil];

	MPMoviePlayerController *player = [[MPMoviePlayerController alloc]
			initWithContentURL:[NSURL fileURLWithPath:path]];
	player.controlStyle = MPMovieControlStyleNone;
	player.scalingMode = MPMovieScalingModeAspectFill;
	player.view.frame = circle.bounds;
	player.view.clipsToBounds = YES;
	player.view.userInteractionEnabled = NO;
	player.shouldAutoplay = YES;
	[circle addSubview:player.view];

	// Add progress ring
	self.videoNoteProgressLayer = [CAShapeLayer layer];
	self.videoNoteProgressLayer.frame = circle.bounds;
	self.videoNoteProgressLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(TGHalf(side), TGHalf(side))
																	  radius:TGHalf(side) - TGMetricPadTiny
																  startAngle:-M_PI_2
																	endAngle:M_PI_2 * 3
																   clockwise:YES].CGPath;
	self.videoNoteProgressLayer.strokeColor = [[TGTheme shared] accentColour].CGColor;
	self.videoNoteProgressLayer.fillColor = [UIColor clearColor].CGColor;
	self.videoNoteProgressLayer.lineWidth = TGMetricPadSmall;
	self.videoNoteProgressLayer.strokeEnd = 0.0;
	[circle.layer addSublayer:self.videoNoteProgressLayer];

	[self.table addSubview:circle];
	self.videoNotePlayer = player;

	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(videoNoteLoopNotification:)
				name:MPMoviePlayerPlaybackDidFinishNotification
			  object:player];
	[player prepareToPlay];
	[player play];
	[self applyVideoNoteRate];

	self.playingMessageId = [m[@"id"] longLongValue];
	[self showPlayerBar];
	self.playerLabel.text = @"Video message";
	[self startPlaybackTimer];
	[self.table reloadData];
}

- (void)videoNoteLoopNotification:(NSNotification *)note {
	BOOL ended = [note.userInfo[MPMoviePlayerPlaybackDidFinishReasonUserInfoKey] integerValue]
			== MPMovieFinishReasonPlaybackEnded;
	if (ended)
		[self videoNoteEnded];
	else
		[self stopVideoNote];
}

- (void)videoNoteEnded {
	int64_t ended = self.playingMessageId;
	[self stopVideoNote];
	[self playNextAfterMessage:ended];
}

/// play resets the movie player to normal speed, and a rate set before it has
/// loaded is dropped, so this runs on every tick as well.
- (void)applyVideoNoteRate {
	float wanted = self.playbackRate ?: TGPlaybackSpeedNormal;
	if (self.videoNotePlayer.playbackState == MPMoviePlaybackStatePlaying &&
		self.videoNotePlayer.currentPlaybackRate != wanted)
		self.videoNotePlayer.currentPlaybackRate = wanted;
}

- (BOOL)showsUnplayedMarkFor:(NSDictionary *)m {
	return TGShowsUnplayedMark(m, self.chatId == [[TGClient shared] savedMessagesChatId]);
}

- (void)playVideoNoteForMessage:(NSDictionary *)m atRow:(NSInteger)row {
	NSNumber *docId = m[@"docId"];
	if (![docId isKindOfClass:NSNumber.class])
		return;
	[self beginDownloadHUDForFile:[docId integerValue]];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:[docId integerValue] completion:^(NSString *path){
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf endDownloadHUD];
			if (path)
				[weakSelf playVideoNoteAtPath:path row:row];
			else
				[weakSelf showPlaybackFailure];
		});
	}];
}

/// A run of voice and round notes plays through, the way their client does. The
/// row comes into view first, because a round note plays where it sits.
- (void)playNextAfterMessage:(int64_t)messageId {
	NSInteger row = messageId ? TGNextPlayableRow(self.messages, messageId) : NSNotFound;
	if (row == NSNotFound)
		return;
	NSDictionary *next = self.messages[row];
	if ([next[@"kind"] isEqualToString:@"messageVideoNote"]){
		[self.table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]
						  atScrollPosition:UITableViewScrollPositionNone animated:YES];
		[self playVideoNoteForMessage:next atRow:row];
	} else {
		[self playVoiceNoteForMessage:next atRow:row];
	}
}

- (void)stopVideoNote {
	if (!self.videoNotePlayer)
		return;
	[[NSNotificationCenter defaultCenter] removeObserver:self
			name:MPMoviePlayerPlaybackDidFinishNotification
		  object:self.videoNotePlayer];
	[self.videoNotePlayer stop];
	[[self.table viewWithTag:0xF119] removeFromSuperview];
	[[self.view viewWithTag:0xF119] removeFromSuperview];
	self.videoNotePlayer = nil;
	self.videoNoteProgressLayer = nil;

	[self.playbackTimer invalidate];
	self.playbackTimer = nil;
	if (!self.voicePlayer) {
		self.playingMessageId = 0;
		[self hidePlayerBar];
	}
	[self.table reloadData];
}


@end
