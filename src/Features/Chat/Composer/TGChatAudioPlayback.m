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


@implementation TGChatViewController (TGChatAudioPlayback)

#pragma mark - playback

/// Their player strip: an arrow, what is playing, a way out, and a line along
/// the bottom that fills as it goes. It sits under the header, which is where
/// a client puts it so the chat stays readable while something plays.
- (void)showPlayerBar {
	CGRect b = self.view.bounds;
	TGTheme *theme = [TGTheme shared];
	if (!self.playerBar){
		self.playerBar = [[UIView alloc] initWithFrame:
				CGRectMake(0, 0, b.size.width, kPlayerBarHeight)];
		self.playerBar.backgroundColor = [theme listBackgroundColour];
		self.playerBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

		// Album art where their player has it. A voice note has none, and
		// the view simply stays hidden for one.
		self.playerArtwork = [[UIImageView alloc] initWithFrame:
				CGRectMake(kPlayerArtX, TGCenteredOrigin(kPlayerBarHeight, kPlayerArt) - kPlayerArtLift,
						   kPlayerArt, kPlayerArt)];
		self.playerArtwork.contentMode = UIViewContentModeScaleAspectFill;
		self.playerArtwork.clipsToBounds = YES;
		self.playerArtwork.layer.cornerRadius = TGMetricCornerSmall;
		self.playerArtwork.hidden = YES;
		self.playerArtwork.userInteractionEnabled = YES;
		[self.playerArtwork addGestureRecognizer:[[UITapGestureRecognizer alloc]
				initWithTarget:self action:@selector(openFullPlayerTapped)]];
		[self.playerBar addSubview:self.playerArtwork];

		self.playerToggle = [UIButton buttonWithType:UIButtonTypeCustom];
		[TGIcons tintButton:self.playerToggle colour:[theme accentColour]];
		[self.playerToggle addTarget:self action:@selector(togglePlayback)
					forControlEvents:UIControlEventTouchUpInside];
		[self.playerBar addSubview:self.playerToggle];

		// Two lines, not one: "performer - title" on a 320pt screen truncated
		// both halves and told you neither.
		self.playerLabel = [[UILabel alloc] init];
		self.playerLabel.font = TGFontCaptionStrong();
		self.playerLabel.backgroundColor = [UIColor clearColor];
		self.playerLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.playerLabel.userInteractionEnabled = YES;
		[self.playerLabel addGestureRecognizer:[[UITapGestureRecognizer alloc]
				initWithTarget:self action:@selector(openFullPlayerTapped)]];
		[self.playerBar addSubview:self.playerLabel];

		self.playerDetail = [[UILabel alloc] init];
		self.playerDetail.font = TGFontMeta();
		self.playerDetail.textColor = [theme secondaryTextColour];
		self.playerDetail.backgroundColor = [UIColor clearColor];
		self.playerDetail.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.playerBar addSubview:self.playerDetail];

		// Elapsed over total, which the strip never said at all.
		self.playerClock = [[UILabel alloc] init];
		self.playerClock.font = TGFontMicro();
		self.playerClock.textColor = [theme secondaryTextColour];
		self.playerClock.textAlignment = NSTextAlignmentRight;
		self.playerClock.backgroundColor = [UIColor clearColor];
		self.playerClock.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self.playerBar addSubview:self.playerClock];

		self.musicPrevious = [UIButton buttonWithType:UIButtonTypeCustom];
		[TGIcons tintButton:self.musicPrevious colour:[theme accentColour]];
		self.musicPrevious.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self.musicPrevious addTarget:self action:@selector(musicPreviousTapped)
					 forControlEvents:UIControlEventTouchUpInside];
		[self.playerBar addSubview:self.musicPrevious];

		self.musicNext = [UIButton buttonWithType:UIButtonTypeCustom];
		[TGIcons tintButton:self.musicNext colour:[theme accentColour]];
		self.musicNext.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self.musicNext addTarget:self action:@selector(musicNextTapped)
				 forControlEvents:UIControlEventTouchUpInside];
		[self.playerBar addSubview:self.musicNext];

		self.playerSpeed = [UIButton buttonWithType:UIButtonTypeCustom];
		self.playerSpeed.titleLabel.font = TGFontCaption();
		self.playerSpeed.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self.playerSpeed setTitle:@"1x" forState:UIControlStateNormal];
		[self.playerSpeed setTitleColor:[theme accentColour]
							   forState:UIControlStateNormal];
		[self.playerSpeed addTarget:self action:@selector(cyclePlaybackSpeed)
				   forControlEvents:UIControlEventTouchUpInside];
		[self.playerBar addSubview:self.playerSpeed];

		self.playerClose = [UIButton buttonWithType:UIButtonTypeCustom];
		[self.playerClose setImage:[TGIcons glyphNamed:@"close"
											colour:[theme secondaryTextColour]
											  side:kRecordLockArrow]
						  forState:UIControlStateNormal];
		self.playerClose.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self.playerClose addTarget:self action:@selector(stopPlayback)
				   forControlEvents:UIControlEventTouchUpInside];
		[self.playerClose setTitleColor:[theme secondaryTextColour]
							   forState:UIControlStateNormal];
		[self.playerBar addSubview:self.playerClose];

		UIView *track = [[UIView alloc] initWithFrame:
				CGRectMake(0, kPlayerBarHeight - kPlayerProgressH, b.size.width, kPlayerProgressH)];
		track.backgroundColor = [theme separatorColour];
		track.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.playerBar addSubview:track];

		self.playerProgress = [[UIView alloc] initWithFrame:
				CGRectMake(0, kPlayerBarHeight - kPlayerProgressH, 0, kPlayerProgressH)];
		self.playerProgress.backgroundColor = [theme accentColour];
		[self.playerBar addSubview:self.playerProgress];

		// A 2pt line is nothing to aim at, so the whole strip is the target
		// and the thumb says where the finger landed.
		self.playerThumb = [[UIView alloc] initWithFrame:
				CGRectMake(-TGMetricPadSmall, kPlayerBarHeight - TGMetricPadSmall - kPlayerArtLift,
						   TGMetricPlayerThumbSide, TGMetricPlayerThumbSide)];
		self.playerThumb.backgroundColor = [theme accentColour];
		self.playerThumb.layer.cornerRadius = TGHalf(TGMetricPlayerThumbSide);
		[self.playerBar addSubview:self.playerThumb];

		[self.playerBar addGestureRecognizer:[[UITapGestureRecognizer alloc]
				initWithTarget:self action:@selector(playerBarScrubbed:)]];
		[self.playerBar addGestureRecognizer:[[UIPanGestureRecognizer alloc]
				initWithTarget:self action:@selector(playerBarScrubbed:)]];

		[self layoutPlayerBarForMusic:NO];
	}

	[self layoutPlayerBarForMusic:NO];
	self.playerLabel.textColor = [[TGTheme shared] primaryTextColour];
	self.playerLabel.text = @"Voice message";
	self.playerDetail.text = @"";
	self.playerClock.text = @"";
	self.playerArtwork.image = nil;
	self.playerProgress.frame = CGRectMake(0, kPlayerBarHeight - kPlayerProgressH,
			0, kPlayerProgressH);
	[self.playerToggle setImage:[TGIcons pause] forState:UIControlStateNormal];
	[TGIcons tintButton:self.playerToggle colour:[[TGTheme shared] accentColour]];
	[self showPlaybackRate];
	[self.view addSubview:self.playerBar];

	// Push the messages down so the strip does not cover the newest one.
	UIEdgeInsets insets = self.table.contentInset;
	insets.top += kPlayerBarHeight;
	self.table.contentInset = insets;
	self.table.scrollIndicatorInsets = insets;
}

/// Two arrangements of the same strip. A voice note has no queue and no
/// cover, so its text starts at the arrow and the corner carries the speed;
/// a track has art, previous and next, and no speed - the corner cannot hold
/// both and the queue is what a track needs.
- (void)layoutPlayerBarForMusic:(BOOL)music {
	CGFloat width = self.playerBar.bounds.size.width;
	CGFloat mid = TGCenteredOrigin(kPlayerBarHeight, kPlayerButton) - kPlayerArtLift;

	self.playerArtwork.hidden = !music;
	CGFloat textX;
	if (music){
		self.playerToggle.frame = CGRectMake(kPlayerArtX + kPlayerArt + kPlayerArtGap, mid,
				kPlayerButton, kPlayerButton);
		textX = kPlayerArtX + kPlayerArt + kPlayerArtGap + kPlayerButton + kPlayerButtonGap;
	} else {
		self.playerToggle.frame = CGRectMake(kPlayerArtX, mid, kPlayerButton, kPlayerButton);
		textX = kPlayerArtX + kPlayerButton + kPlayerArtGap;
	}

	// Right to left: close, then the queue or the speed, then the clock.
	self.playerClose.frame = CGRectMake(width - kPlayerCloseW - kPlayerButtonGap, mid,
			kPlayerCloseW, kPlayerButton);
	CGFloat rightEdge = width - kPlayerRightEdge;

	self.musicPrevious.hidden = !music;
	self.musicNext.hidden = !music;
	self.playerSpeed.hidden = music;
	if (music){
		self.musicNext.frame = CGRectMake(rightEdge - kPlayerCloseW, mid,
				kPlayerCloseW, kPlayerButton);
		self.musicPrevious.frame = CGRectMake(rightEdge - TGDoubled(kPlayerCloseW) - TGMetricPadTiny,
				mid, kPlayerCloseW, kPlayerButton);
		rightEdge -= TGDoubled(kPlayerCloseW) + TGMetricPadSmall;
	} else {
		self.playerSpeed.frame = CGRectMake(rightEdge - kPlayerSpeedW, mid,
				kPlayerSpeedW, kPlayerButton);
		rightEdge -= kPlayerSpeedW + TGMetricPadTiny;
	}

	CGFloat clockW = kPlayerClockW;
	self.playerClock.frame = CGRectMake(rightEdge - clockW, mid + kPlayerClockDrop,
			clockW, TGMetricLineMicro);
	CGFloat textW = MAX(kPlayerTextMin, rightEdge - clockW - textX - TGMetricPadSmall);

	self.playerLabel.frame = CGRectMake(textX, mid + kPlayerArtLift, textW, kPlayerTitleLine);
	self.playerDetail.frame = CGRectMake(textX, mid + kPlayerTitleLine, textW,
			kPlayerDetailLine);
}

/// "1:07 / 3:42", or just the elapsed time while the length is unknown.
static NSString *TGClockText(NSTimeInterval position, NSTimeInterval duration) {
	NSInteger at = (NSInteger)MAX(0.0, position);
	NSString *elapsed = [NSString stringWithFormat:@"%ld:%02ld",
			(long)(at / 60), (long)(at % 60)];
	if (duration <= 0)
		return elapsed;
	NSInteger total = (NSInteger)duration;
	return [NSString stringWithFormat:@"%@ / %ld:%02ld", elapsed,
			(long)(total / 60), (long)(total % 60)];
}

- (void)hidePlayerBar {
	if (!self.playerBar.superview)
		return;
	[self.playerBar removeFromSuperview];
	UIEdgeInsets insets = self.table.contentInset;
	insets.top -= kPlayerBarHeight;
	self.table.contentInset = insets;
	self.table.scrollIndicatorInsets = insets;
}

/// Five ticks a second is enough for the eye, and a tick now costs one layer
/// frame per playing row - the waveform itself is not redrawn (TGBubbleCell
/// -setWavePlayed:).
- (void)startPlaybackTimer {
	[self.playbackTimer invalidate];
	self.playbackTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
														 target:self
													   selector:@selector(playbackTick)
													   userInfo:nil
														repeats:YES];
}

- (CGFloat)playedFraction {
    TGMusicPlayer *music = [TGMusicPlayer shared];
    if (music.current && music.duration > 0)
        return (CGFloat)(music.position / music.duration);
    if (self.voicePlayer && self.voicePlayer.duration > 0)
        return (CGFloat)(self.voicePlayer.currentTime / self.voicePlayer.duration);
    if (self.videoNotePlayer && self.videoNotePlayer.duration > 0)
        return (CGFloat)(self.videoNotePlayer.currentPlaybackTime / self.videoNotePlayer.duration);
    return 0;
}

- (void)playbackTick {
	if (self.videoNotePlayer && self.videoNotePlayer.duration > 0) {
		if (self.videoNotePlayer.currentPlaybackTime >= self.videoNotePlayer.duration - 0.05) {
			[self videoNoteEnded];
			return;
		}
		[self applyVideoNoteRate];
	}
	CGFloat played = [self playedFraction];
	CGFloat barWidth = self.playerBar.bounds.size.width;
	self.playerProgress.frame = CGRectMake(0, kPlayerBarHeight - kPlayerProgressH,
			barWidth * played, kPlayerProgressH);
	self.playerThumb.center = CGPointMake(barWidth * played,
										  kPlayerBarHeight - kPlayerArtLift);

	TGMusicPlayer *music = [TGMusicPlayer shared];
	if (music.current)
		self.playerClock.text = TGClockText(music.position, music.duration);
	else if (self.voicePlayer)
		self.playerClock.text = TGClockText(self.voicePlayer.currentTime,
											self.voicePlayer.duration);

    if (self.videoNoteProgressLayer) {
        self.videoNoteProgressLayer.strokeEnd = played;
    }

	// Only the row being played changes, and reloading the whole table five
	// times a second on this hardware is visible as a stutter.
	for (UITableViewCell *cell in self.table.visibleCells){
		if (![cell isKindOfClass:TGBubbleCell.class])
			continue;
		TGBubbleCell *bubble = (TGBubbleCell *)cell;
		if (bubble.voiceMessageId != self.playingMessageId || bubble.wave.hidden)
			continue;
		[bubble setWavePlayed:played];
	}
}

/// The music strip: the same place as the voice strip, but it names the track
/// and carries the two buttons that only mean something with a queue behind
/// them. Their player puts previous and next either side of play.
- (void)showMusicBar {
	[self showPlayerBar];
	[self layoutPlayerBarForMusic:YES];
	[self.musicPrevious setImage:[TGIcons previousTrack] forState:UIControlStateNormal];
	[self.musicNext setImage:[TGIcons nextTrack] forState:UIControlStateNormal];
	[self musicChanged];
	[self startPlaybackTimer];
}

- (void)musicPreviousTapped { [[TGMusicPlayer shared] previous]; }
- (void)musicNextTapped     { [[TGMusicPlayer shared] next]; }

- (void)openFullPlayerTapped {
	if ([TGMusicPlayer shared].current) {
		[TGPlayerModalViewController presentFromViewController:self animated:YES];
	}
}

/// Called on the notification as well as directly, so the strip follows a
/// track change that came from the lock screen rather than from this screen.
- (void)musicChanged {
	TGMusicPlayer *music = [TGMusicPlayer shared];
	if (!music.current){
		if (self.musicPrevious && !self.musicPrevious.hidden)
			[self stopPlayback];
		return;
	}

	NSString *title = [music.current[@"audioTitle"] length]
			? music.current[@"audioTitle"]
			: (music.current[@"docName"] ?: @"Audio");
	self.playerLabel.textColor = [[TGTheme shared] primaryTextColour];
	self.playerLabel.text = title;
	self.playerDetail.text = [music.current[@"audioPerformer"] length]
			? music.current[@"audioPerformer"] : @"";
	self.playerClock.text = TGClockText(music.position, music.duration);

	// The cover is the one the bubble already fetched, so switching tracks
	// shows it at once rather than after a second download.
	self.playerArtwork.image = [self artworkForTrack:music.current];
	self.playerArtwork.backgroundColor = self.playerArtwork.image
			? [UIColor clearColor] : [[TGTheme shared] fileTileColour];

	[self.playerToggle setImage:(music.playing ? [TGIcons pause] : [TGIcons play])
					   forState:UIControlStateNormal];
	[TGIcons tintButton:self.playerToggle colour:[[TGTheme shared] accentColour]];
	[self.table reloadData];
}

- (void)waveformScrubbed:(UIGestureRecognizer *)gesture {
	UIView *wave = gesture.view;
	TGBubbleCell *cell = nil;
	for (UIView *view = wave; view; view = view.superview)
		if ([view isKindOfClass:TGBubbleCell.class]){
			cell = (TGBubbleCell *)view;
			break;
		}
	if (!cell)
		return;

	NSIndexPath *ip = [self.table indexPathForCell:cell];
	if (!ip || ip.row >= (NSInteger)self.messages.count)
		return;
	NSDictionary *m = self.messages[ip.row];
	if ([m[@"sending"] boolValue]){
		[self cancelSendingRow:m];
		return;
	}

	if (!self.voicePlayer || cell.voiceMessageId != self.playingMessageId){
		if (gesture.state == UIGestureRecognizerStateEnded){
			[self playVoiceNoteForMessage:m atRow:ip.row];
		}
		return;
	}

	CGFloat x = [gesture locationInView:wave].x;
	CGFloat fraction = MIN(MAX(x / MAX(TGMetricScaleFull, wave.bounds.size.width), TGAlphaTransparent), TGAlphaOpaque);
	self.voicePlayer.currentTime = fraction * self.voicePlayer.duration;
	[self playbackTick];
}

- (void)voiceDiscTapped:(UITapGestureRecognizer *)gesture {
	UIView *disc = gesture.view;
	TGBubbleCell *cell = nil;
	for (UIView *view = disc; view; view = view.superview)
		if ([view isKindOfClass:TGBubbleCell.class]){
			cell = (TGBubbleCell *)view;
			break;
		}
	if (!cell)
		return;

	NSIndexPath *ip = [self.table indexPathForCell:cell];
	if (!ip || ip.row >= (NSInteger)self.messages.count)
		return;
	NSDictionary *m = self.messages[ip.row];
	if ([m[@"sending"] boolValue]){
		[self cancelSendingRow:m];
		return;
	}
	[self playVoiceNoteForMessage:m atRow:ip.row];
}

- (void)videoNoteDiscTapped:(UITapGestureRecognizer *)gesture {
	UIView *disc = gesture.view;
	TGBubbleCell *cell = nil;
	for (UIView *view = disc; view; view = view.superview)
		if ([view isKindOfClass:TGBubbleCell.class]){
			cell = (TGBubbleCell *)view;
			break;
		}
	if (!cell)
		return;

	NSIndexPath *ip = [self.table indexPathForCell:cell];
	if (!ip || ip.row >= (NSInteger)self.messages.count)
		return;
	NSDictionary *m = self.messages[ip.row];
	if ([m[@"sending"] boolValue]){
		[self cancelSendingRow:m];
		return;
	}
	[self tableView:self.table didSelectRowAtIndexPath:ip];
}

/// 1x, 1.5x, 2x - the three their player offers. AVAudioPlayer will not change
/// rate unless it was told to expect it before playing, which is why
/// enableRate is set when the player is built rather than here.
- (void)cyclePlaybackSpeed {
	float rate = self.playbackRate ?: TGPlaybackSpeedNormal;
	self.playbackRate = (rate < TGPlaybackSpeedThresholdFast) ? TGPlaybackSpeedFast
			: ((rate < TGPlaybackSpeedThresholdDouble) ? TGPlaybackSpeedDouble : TGPlaybackSpeedNormal);
	self.voicePlayer.rate = self.playbackRate;
	[self applyVideoNoteRate];
	[self showPlaybackRate];
}

- (void)showPlaybackRate {
	float rate = self.playbackRate ?: TGPlaybackSpeedNormal;
	[self.playerSpeed setTitle:(rate < TGPlaybackSpeedThresholdFast ? @"1x" :
			(rate < TGPlaybackSpeedThresholdDouble ? @"1.5x" : @"2x"))
					  forState:UIControlStateNormal];
}

/// Tapping anywhere along the strip's line jumps there.
- (void)playerBarScrubbed:(UIGestureRecognizer *)gesture {
	CGFloat width = self.playerBar.bounds.size.width;
	CGFloat fraction = MIN(MAX([gesture locationInView:self.playerBar].x /
			MAX(TGMetricScaleFull, width), TGAlphaTransparent), TGAlphaOpaque);
	if ([TGMusicPlayer shared].current)
		[[TGMusicPlayer shared] seekToFraction:fraction];
	else if (self.voicePlayer)
		self.voicePlayer.currentTime = fraction * self.voicePlayer.duration;
	else if (self.videoNotePlayer && self.videoNotePlayer.duration > 0)
		self.videoNotePlayer.currentPlaybackTime = fraction * self.videoNotePlayer.duration;
	[self playbackTick];
}

- (void)togglePlayback {
	if ([TGMusicPlayer shared].current){
		[[TGMusicPlayer shared] togglePlayPause];
		return;
	}
	if (self.voicePlayer) {
        if (self.voicePlayer.playing){
            [self.voicePlayer pause];
            [self.playbackTimer invalidate];
            self.playbackTimer = nil;
            [self.playerToggle setImage:[TGIcons play] forState:UIControlStateNormal];
            [TGIcons tintButton:self.playerToggle colour:[[TGTheme shared] accentColour]];
        } else {
            [self.voicePlayer play];
            [self startPlaybackTimer];
            [self.playerToggle setImage:[TGIcons pause] forState:UIControlStateNormal];
            [TGIcons tintButton:self.playerToggle colour:[[TGTheme shared] accentColour]];
        }
        [self.table reloadData];
    } else if (self.videoNotePlayer) {
        if (self.videoNotePlayer.playbackState == MPMoviePlaybackStatePlaying) {
            [self.videoNotePlayer pause];
            [self.playbackTimer invalidate];
            self.playbackTimer = nil;
            [self.playerToggle setImage:[TGIcons play] forState:UIControlStateNormal];
            [TGIcons tintButton:self.playerToggle colour:[[TGTheme shared] accentColour]];
        } else {
            [self.videoNotePlayer play];
            [self applyVideoNoteRate];
            [self startPlaybackTimer];
            [self.playerToggle setImage:[TGIcons pause] forState:UIControlStateNormal];
            [TGIcons tintButton:self.playerToggle colour:[[TGTheme shared] accentColour]];
        }
    }
}

- (void)stopPlayback {
	if ([TGMusicPlayer shared].current)
		[[TGMusicPlayer shared] stop];
	[self.voicePlayer stop];
	self.voicePlayer = nil;
	if (self.videoNotePlayer)
		[self stopVideoNote];
	[self.playbackTimer invalidate];
	self.playbackTimer = nil;
	self.playingMessageId = 0;
	[self hidePlayerBar];
	[self.table reloadData];
}

- (void)audioPlayerDidFinishPlaying:(id)player successfully:(BOOL)flag {
	int64_t currentId = self.playingMessageId;
	[self stopPlayback];

	if (!flag || currentId == 0)
		return;

	[self playNextAfterMessage:currentId];
}

- (void)playVoiceNoteForMessage:(NSDictionary *)m atRow:(NSInteger)row {
	NSNumber *docId = m[@"docId"];
	if (![docId isKindOfClass:NSNumber.class])
		return;

	// Telling Telegram it was played is what turns the sender's dot blue, and
	// nothing else does it - reading the chat does not count as listening.
	if (![m[@"outgoing"] boolValue])
		[[TGMessageStore shared] openContentOfMessage:[m[@"id"] longLongValue]
										 inChat:self.chatId];

	// Tapping the one already playing is how you stop it; without this the
	// only way out was to leave the chat.
	if (self.playingMessageId == [m[@"id"] longLongValue] && self.voicePlayer){
		[self togglePlayback];
		return;
	}
	if (self.voicePlayer || self.videoNotePlayer)
		[self stopPlayback];
	[self beginDownloadHUDForFile:[docId integerValue]];
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] downloadFile:[docId integerValue] priority:32 completion:^(NSString *path){
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf endDownloadHUD];
			TGChatViewController *me = weakSelf;
			if (!me) return;
			NSLog(@"voice: file %@", path.lastPathComponent ?: @"(not downloaded)");
			if (!path){
				[me showPlaybackFailure];
				return;
			}
			NSError *err = nil;
			[[AVAudioSession sharedInstance]
					setCategory:AVAudioSessionCategoryPlayback error:nil];
			[[AVAudioSession sharedInstance] setActive:YES error:nil];
			me.voicePlayer = [[TGStreamingVoicePlayer alloc] initWithPath:path error:&err];
			if (err || !me.voicePlayer){
				NSLog(@"voice playback: %@", err);
				[me showPlaybackFailure];
				return;
			}
			NSLog(@"voice: playing %.1f s (streaming)", me.voicePlayer.duration);
			me.voicePlayer.delegate = (id<TGStreamingVoicePlayerDelegate>)me;
			me.voicePlayer.enableRate = YES;   // for the speed button
			me.voicePlayer.rate = me.playbackRate ?: TGPlaybackSpeedNormal;
			me.playingMessageId = [m[@"id"] longLongValue];
			[me.voicePlayer play];
			[me showPlayerBar];
			[me startPlaybackTimer];
			[me.table reloadData];
		});
	}];
}


@end
