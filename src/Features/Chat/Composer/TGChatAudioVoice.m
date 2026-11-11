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


@implementation TGChatViewController (TGChatAudioVoice)

#pragma mark - voice

/// Send is for typed text, the microphone for everything else - showing both
/// at once would leave one of them dead.
/// Send takes the microphone's place once there is something to send, and
/// the two cross over with a quick scale rather than blinking.
- (void)inputChanged {
	// Every edit goes through here after the field's own delegate has run, so
	// programmatic edits (formatting, drafts, send) resize the bar too.
	[self updateComposerHeightAnimated:NO];
	[self reportTyping];
	// Asked after the typing settles rather than per keystroke: one request
	// per link, and the answer is thrown away if the text moved on.
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(refreshLinkPreview)
											   object:nil];
	[self performSelector:@selector(refreshLinkPreview) withObject:nil
			   afterDelay:0.7];
	BOOL hasText = self.input.text.length > 0;
	UIButton *coming = hasText ? self.sendButton : self.micButton;
	UIButton *going = hasText ? self.micButton : self.sendButton;
	if (!coming.hidden && going.hidden)
		return;

	if (!self.view.window){
		coming.hidden = NO;
		going.hidden = YES;
		return;
	}
	CGAffineTransform small = CGAffineTransformMakeScale(TGTransformScaleSmall, TGTransformScaleSmall);
	coming.hidden = NO;
	coming.alpha = TGAlphaTransparent;
	coming.transform = small;
	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		coming.alpha = TGAlphaOpaque;
		coming.transform = CGAffineTransformIdentity;
		going.alpha = TGAlphaTransparent;
		going.transform = small;
	} completion:^(BOOL finished){
		// Settle on whatever the text says now; it may have changed again
		// while this ran.
		BOOL text = self.input.text.length > 0;
		self.sendButton.hidden = !text;
		self.micButton.hidden = text;
		for (UIButton *button in @[self.sendButton, self.micButton]){
			button.alpha = 1;
			button.transform = CGAffineTransformIdentity;
		}
	}];
}

/// Their recording panel: a red dot, the running time, "Slide to cancel", and
/// the microphone grown into a disc with a halo around it.
- (void)showRecordPanel {
	CGRect bar = self.inputBar.frame;
	TGTheme *theme = [TGTheme shared];
	if (!self.recordPanel){
		self.recordPanel = [[TGRecordBar alloc] initWithFrame:bar];

		self.recordCancelSlideLabel = [[UILabel alloc] initWithFrame:
				CGRectMake(kRecordSlideX, TGCenteredOrigin(kInputHeight, TGMetricLineRow),
						bar.size.width - kRecordSlideRoom, TGMetricLineRow)];
		self.recordCancelSlideLabel.text = @"Slide to cancel";
		self.recordCancelSlideLabel.font = TGFontBody();
		self.recordCancelSlideLabel.textColor = [theme secondaryTextColour];
		self.recordCancelSlideLabel.backgroundColor = [UIColor clearColor];
		self.recordCancelSlideLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.recordPanel addSubview:self.recordCancelSlideLabel];

		// Cancel, send and pause wait for the lock: until then a finger is
		// welded to the mic and none of them can be reached.
		self.recordCancelButton = self.recordPanel.cancelButton;
		[self.recordCancelButton addTarget:self action:@selector(recordCancel) forControlEvents:UIControlEventTouchUpInside];
		self.recordSendButton = self.recordPanel.sendButton;
		[self.recordSendButton addTarget:self action:@selector(recordFinish) forControlEvents:UIControlEventTouchUpInside];
		self.recordPauseButton = self.recordPanel.pauseButton;
		[self.recordPauseButton addTarget:self action:@selector(recordPauseToggled)
				  forControlEvents:UIControlEventTouchUpInside];

		// Classic halo and disc (original design)
		CGFloat halo = TGMetricRecordHaloSide, disc = TGMetricRow;
		UIView *ring = [[UIView alloc] initWithFrame:
				CGRectMake(bar.size.width - halo + TGMetricPadSmall, TGCenteredOrigin(kInputHeight, halo), halo, halo)];
		ring.backgroundColor = [theme accentColour];
		ring.alpha = TGAlphaRingTrack;
		ring.layer.cornerRadius = TGHalf(TGMetricRecordHaloSide);
		ring.tag = 0x81C1;
		ring.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self.recordPanel addSubview:ring];

		UIImageView *button = [[UIImageView alloc] initWithFrame:CGRectMake(
				CGRectGetMidX(ring.frame) - TGHalf(disc), TGCenteredOrigin(kInputHeight, disc), disc, disc)];
		button.backgroundColor = [theme accentColour];
		button.layer.cornerRadius = TGHalf(TGMetricRow);
		button.tag = 0x81C2;
		button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self.recordPanel addSubview:button];
	}

	sIsLocked = NO;
	sIsCancelled = NO;
	sDragDeltaX = 0;
	sSendInFlight = NO;
	self.recordCancelButton.hidden = YES;
	self.recordSendButton.hidden = YES;
	if (self.recordPauseButton){
		self.recordPauseButton.hidden = YES;
		// The pause disc keeps the state of the last recording on it; a fresh
		// one starts unpaused.
		[self.recordPauseButton setImage:[TGIcons pause] forState:UIControlStateNormal];
	}
	self.recordCancelSlideLabel.hidden = NO;
	self.recordCancelSlideLabel.transform = CGAffineTransformIdentity;
	self.recordCancelSlideLabel.alpha = TGAlphaOpaque;
	[self.recordPanel viewWithTag:0x81C1].hidden = NO;
	[self.recordPanel viewWithTag:0x81C2].hidden = NO;
	// From the first hundredth of the hold the disc says what is being recorded.
	((UIImageView *)[self.recordPanel viewWithTag:0x81C2]).image = self.videoNoteMode
			? [TGIcons glyphNamed:@"video" colour:[theme onAccentColour] side:TGMetricMenuGlyph]
			: [TGIcons microphoneOfSide:TGMetricRow colour:[theme onAccentColour]];

	self.recordPanel.frame = bar;
	[self.recordPanel showSeconds:0 paused:NO];
	self.recordPanel.userInteractionEnabled = NO;
	[self.view addSubview:self.recordPanel];

	// The "Rice Grain" lock capsule directly above mic button (Image 2)
	if (!self.recordLockView) {
		CGFloat pillW = TGMetricVoicePillWidth, pillH = TGMetricVoicePillHeight;
		CGFloat pillX = bar.origin.x + bar.size.width - pillW - TGMetricVoiceLockMaxShift;
		CGFloat pillY = bar.origin.y - pillH - TGMetricPadMedium;
		UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(pillX, pillY, pillW, pillH)];
		pill.backgroundColor = [[TGTheme shared] recordLockColour];
		pill.layer.cornerRadius = TGHalf(pillW); // Rounded rice grain capsule
		pill.clipsToBounds = YES;

		UIImageView *lockIcon = [[UIImageView alloc] initWithFrame:
				CGRectMake(TGCenteredOrigin(pillW, kRecordLockGlyph), TGMetricPad,
						kRecordLockGlyph, kRecordLockGlyph)];
		lockIcon.image = [TGIcons lockOfSide:kRecordLockGlyph
									  colour:[[TGTheme shared] onMediaColour]];
		lockIcon.backgroundColor = [UIColor clearColor];
		[pill addSubview:lockIcon];

		UIImageView *arrow = [[UIImageView alloc] initWithFrame:
				CGRectMake(TGCenteredOrigin(pillW, kRecordLockArrow), kRecordLockArrowY,
						kRecordLockArrow, kRecordLockArrow)];
		arrow.image = [TGIcons glyphNamed:@"chevronUp"
									  colour:[[TGTheme shared] secondaryTextColour]
										side:kRecordLockArrow];
		arrow.backgroundColor = [UIColor clearColor];
		[pill addSubview:arrow];

		self.recordLockView = pill;
	}
	if (!self.recordOnceButton){
		self.recordOnceButton = [TGRecordBar onceButton];
		[self.recordOnceButton addTarget:self action:@selector(toggleRecordOnce)
						forControlEvents:UIControlEventTouchUpInside];
	}
	// Above the lock, where Telegram puts the one-time choice: tapping it
	// makes the note self-destruct ten seconds after it is opened.
	CGFloat onceSide = TGMetricRow;
	CGFloat pillH = TGMetricVoicePillHeight;
	CGFloat onceY = bar.origin.y - pillH - TGMetricPadMedium - onceSide - TGMetricPadSmall;
	self.recordOnceButton.frame = CGRectMake(
			bar.origin.x + bar.size.width - onceSide - TGMetricVoiceLockMaxShift,
			onceY, onceSide, onceSide);
	[self.view addSubview:self.recordOnceButton];

	self.recordLockView.alpha = TGAlphaTransparent;
	self.recordLockView.transform = CGAffineTransformMakeTranslation(0, kRecordLockRest);
	[self.view addSubview:self.recordLockView];
	[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
		self.recordLockView.alpha = TGAlphaOpaque;
		self.recordLockView.transform = CGAffineTransformIdentity;
	}];
}

- (void)hideRecordPanel {
	self.table.scrollEnabled = YES;
	[self.recordPanel removeFromSuperview];
	[self.recordLockView removeFromSuperview];
	self.recordLockView = nil;
	[self.recordOnceButton removeFromSuperview];
	self.recordOnceButton = nil;
	sIsLocked = NO;
	sIsCancelled = NO;
	sDragDeltaX = 0;
	self.recordCancelSlideLabel.transform = CGAffineTransformIdentity;
	self.recordCancelSlideLabel.alpha = TGAlphaOpaque;
}

- (void)lockRecording {
	if (sIsLocked) return;
	sIsLocked = YES;
	self.table.scrollEnabled = YES;
	self.recordPanel.userInteractionEnabled = YES;

	[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
		self.recordLockView.alpha = TGAlphaTransparent;
		self.recordLockView.transform = CGAffineTransformMakeTranslation(0, -kRecordLockLift);
	} completion:^(BOOL finished) {
		[self.recordLockView removeFromSuperview];
		self.recordLockView = nil;
	}];

	self.recordCancelSlideLabel.hidden = YES;
	[self.recordPanel viewWithTag:0x81C1].hidden = YES;
	[self.recordPanel viewWithTag:0x81C2].hidden = YES;

	self.recordCancelButton.hidden = NO;
	self.recordSendButton.hidden = NO;
	self.recordPauseButton.hidden = NO;
}

- (void)updateRecordModeIcon {
	UIImage *video = [TGIcons glyphNamed:@"video"
								  colour:[[TGTheme shared] secondaryTextColour]
									side:TGMetricMenuGlyph];
	[self.micButton setImage:(self.videoNoteMode ? video : [TGIcons microphone])
					forState:UIControlStateNormal];
}

/// The mode outlives the chat: Telegram writes it down the moment it changes,
/// and the next chat opens on whatever the last recording was.
- (void)toggleRecordMode {
	self.videoNoteMode = !self.videoNoteMode;
	[[NSUserDefaults standardUserDefaults] setBool:self.videoNoteMode
											forKey:kRecordVideoModeKey];
	[UIView transitionWithView:self.micButton duration:TGAnimationDurationNormal
					   options:UIViewAnimationOptionTransitionFlipFromLeft
					animations:^{ [self updateRecordModeIcon]; }
					completion:nil];
	[self showRecordModeHint];
}

/// A tap that changed nothing a person could read would look like a dead button.
- (void)showRecordModeHint {
	UILabel *hint = [[UILabel alloc] init];
	hint.text = self.videoNoteMode ? @"Hold to record video"
								   : @"Hold to record voice. Tap for video.";
	hint.font = TGFontCaption();
	hint.textColor = [[TGTheme shared] onMediaColour];
	hint.backgroundColor = [[TGTheme shared] mediaOverlayColour];
	hint.textAlignment = NSTextAlignmentCenter;
	hint.layer.cornerRadius = TGMetricCornerMedium;
	CGFloat width = [hint.text sizeWithFont:hint.font].width + TGDoubled(TGMetricPadLarge);
	CGRect bar = self.inputBar.frame;
	hint.frame = CGRectMake(bar.size.width - width - TGMetricPad,
			CGRectGetMinY(bar) - TGMetricTextFieldH, width, TGMetricButtonSmallH);
	hint.alpha = TGAlphaTransparent;
	[self.view addSubview:hint];
	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		hint.alpha = TGAlphaOpaque;
	} completion:^(BOOL finished){
		[UIView animateWithDuration:TGAnimationDurationSlow delay:kRecordHintSeconds options:0 animations:^{
			hint.alpha = TGAlphaTransparent;
		} completion:^(BOOL gone){
			[hint removeFromSuperview];
		}];
	}];
}

/// Telegram waits a beat before it starts writing, and so do we: the touch
/// lands, the clock runs, and only a finger still down kRecordToggleTapSeconds
/// later becomes a recording. A tap never touches the recorder at all.
- (void)recordTouchDown:(UIButton *)btn withEvent:(UIEvent *)event {
	self.recordBeganAt = [NSDate date];
	sIsCancelled = NO;
	sIsLocked = NO;
	sDragDeltaX = 0;
	UITouch *touch = [[event allTouches] anyObject];
	if (touch) {
		sTouchStart = [touch locationInView:self.view];
	} else {
		sTouchStart = CGPointMake(self.view.bounds.size.width - TGMetricVoiceDragDeadzone, CGRectGetMidY(self.inputBar.frame));
	}
	// The recorder waits for Telegram's beat; the composer does not. Making
	// the strip and sweeping any open keyboard away is instant, so the hold
	// reads from the first hundredth of it.
	[self.input resignFirstResponder];
	if (self.stickerPanel && !self.stickerPanel.hidden)
		[self hideStickerPanel];
	[self showRecordPanel];

	// The block-taking timer name is iOS 10+, which this app is older than:
	// the selector form is the one the device has, and a one-shot timer
	// invalidates itself, so its hold on self lasts the beat and no longer.
	[self.recordStartPendingTimer invalidate];
	self.recordStartPendingTimer = [NSTimer timerWithTimeInterval:kRecordToggleTapSeconds
			target:self
			selector:@selector(recordStartPendingFired:)
			userInfo:nil
			repeats:NO];
	[[NSRunLoop currentRunLoop] addTimer:self.recordStartPendingTimer
			forMode:NSRunLoopCommonModes];
}

- (void)recordStartPendingFired:(NSTimer *)timer {
	if (timer != self.recordStartPendingTimer)
		return;
	self.recordStartPendingTimer = nil;
	if (sIsCancelled)
		return;   // the touch was taken away while the beat ran
	self.table.scrollEnabled = NO;
	[self recordStart];
}

- (void)recordTouchUp:(UIButton *)btn withEvent:(UIEvent *)event {
	if (self.videoNoteOverlayActive)
		return;
	self.table.scrollEnabled = YES;
	[self invalidatePendingRecordStart];
	if (sIsLocked || sIsCancelled)
		return;
	if (sSendInFlight)
		return;

	NSTimeInterval held = self.recordBeganAt
			? -[self.recordBeganAt timeIntervalSinceNow] : 1.0;
	self.recordBeganAt = nil;

	// A tap, not a hold: the recorder was never given the signal, so the
	// touch is free to mean what Telegram's short tap means - voice note
	// recording and round video recording trade places.
	if (held < kRecordToggleTapSeconds && sDragDeltaX < TGMetricVoiceDragDeadzone
			&& ![[TGVoiceRecorder shared] recording]){
		[self hideRecordPanel];
		[self toggleRecordMode];
		return;
	}

	// Released while dragged towards cancel -> cancel
	if (sDragDeltaX >= TGMetricVoiceDragDeadzone) {
		[self recordCancel];
		return;
	}

	[self recordFinish];
}

- (void)recordTouchCancel {
	self.table.scrollEnabled = YES;
	[self invalidatePendingRecordStart];
	if (sIsLocked) return;
	[self recordCancel];
}

- (void)recordDrag:(UIButton *)btn withEvent:(UIEvent *)event {
	if (self.videoNoteOverlayActive || sIsCancelled) return;
	UITouch *touch = [[event allTouches] anyObject];
	if (!touch) return;
	CGPoint pt = [touch locationInView:self.view];

	if (!sIsLocked) {
		CGFloat deltaX = sTouchStart.x - pt.x;
		CGFloat deltaY = sTouchStart.y - pt.y;
		sDragDeltaX = deltaX;

		// A long slide left while the recorder is still waiting is a cancel
		// of the intent.
		if (deltaX >= TGMetricVoiceSlideCancelDistance
				&& ![[TGVoiceRecorder shared] recording]){
			[self invalidatePendingRecordStart];
			return;
		}

		// 1. Slide UP into the rice grain to lock
		if (deltaY >= TGMetricVoiceLockDistance || pt.y <= CGRectGetMinY(self.inputBar.frame) - TGMetricVoiceLockMargin) {
			if ([self recorderIsRecording])
				[self lockRecording];
			return;
		} else if (deltaY > TGMetricZero && self.recordLockView) {
			CGFloat shift = -MIN(deltaY * TGDampingVoiceLock, TGMetricVoiceLockMaxShift);
			self.recordLockView.transform = CGAffineTransformMakeTranslation(0, shift);
		}

		// 2. Slide LEFT to cancel
		if (deltaX >= TGMetricVoiceSlideCancelDistance) {
			sIsCancelled = YES;
			[self recordCancel];
			return;
		} else if (deltaX > TGMetricZero) {
			CGFloat shift = MIN(deltaX * TGDampingVoiceCancel, TGMetricVoiceSlideMaxShift);
			self.recordCancelSlideLabel.transform = CGAffineTransformMakeTranslation(-shift, 0);
			self.recordCancelSlideLabel.alpha = MAX(TGAlphaVoiceCancelMin, TGAlphaOpaque - (deltaX / TGMetricVoiceSlideCancelDistance));
		} else {
			self.recordCancelSlideLabel.transform = CGAffineTransformIdentity;
			self.recordCancelSlideLabel.alpha = TGAlphaOpaque;
		}
	}
}

- (void)recordStart {
	if (self.videoNoteMode){
		NSLog(@"TGVideoNote: recordStart video mode");
		if (![[TGVideoNoteRecorder shared] start]){
			[self hideRecordPanel];
			[self showPlaybackFailure];
			return;
		}
		self.inputBar.hidden = YES;
		// The hold's strip stays under the overlay while it fades in, so the
		// bottom of the screen never shows a gap; the shot must not include it.
		self.recordPanel.hidden = YES;
		self.recordLockView.hidden = YES;
		self.recordOnceButton.hidden = YES;
		// The overlay covers the navigation bar too, so the backdrop has to
		// hold it: a shot of the chat alone came out stretched to fit.
		UIView *shown = (self.tabBarController ?: self.navigationController ?: self).view;
		CGRect covered = [shown convertRect:[UIScreen mainScreen].applicationFrame fromView:nil];
		UIGraphicsBeginImageContextWithOptions(covered.size, YES, 0.0f);
		CGContextTranslateCTM(UIGraphicsGetCurrentContext(), -covered.origin.x, -covered.origin.y);
		[shown.layer renderInContext:UIGraphicsGetCurrentContext()];
		UIImage *background = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		self.videoNoteOverlayActive = YES;
		self.recordPanel.hidden = NO;
		self.recordLockView.hidden = NO;
		self.recordOnceButton.hidden = NO;
		NSLog(@"TGVideoNote: presenting overlay");
		TGVideoNoteViewController *recorder = [[TGVideoNoteViewController alloc]
				initWithChatId:self.chatId threadId:self.threadId background:background];
		__weak typeof(self) weakSelf = self;
		recorder.onSend = ^(BOOL once){
			[weakSelf sendRecordedNoteOnce:once];
		};
		recorder.onDismiss = ^{
			weakSelf.videoNoteOverlayActive = NO;
			weakSelf.inputBar.hidden = NO;
			// The hold that led here left its strip, the lock and the "1" behind
			// the overlay; the next voice note builds them again.
			[weakSelf hideRecordPanel];
			weakSelf.table.scrollEnabled = YES;
			// Not from here: this block belongs to the recorder being released.
			dispatch_async(dispatch_get_main_queue(), ^{
				weakSelf.videoNoteOverlay = nil;
			});
		};
		// Over the whole app, tab bar included: this is a part of the chat, not
		// a place of its own, and a child added to a navigation controller
		// would land in its stack.
		UIView *hostView = (self.tabBarController ?: self.navigationController ?: self).view;
		// Under the status bar, whatever the host's own view does about it.
		recorder.overlayFrame = covered;
		[hostView addSubview:recorder.view];
		recorder.view.autoresizingMask = UIViewAutoresizingFlexibleWidth |
				UIViewAutoresizingFlexibleHeight;
		self.videoNoteOverlay = recorder;
		return;
	}
	if (![[TGVoiceRecorder shared] start]){
		[self hideRecordPanel];
		[self showPlaybackFailure];
		return;
	}
	if (!self.recordPanel.superview)
		[self showRecordPanel];   // the beat fired late; the strip is already up
	self.recordTimer = [NSTimer timerWithTimeInterval:0.1
											   target:self
											 selector:@selector(recordTick)
											 userInfo:nil
											  repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:self.recordTimer forMode:NSRunLoopCommonModes];
}

- (void)recordTick {
	BOOL paused = [[TGVoiceRecorder shared] paused];
	NSTimeInterval d = self.videoNoteMode
			? [TGVideoNoteRecorder shared].duration
			: [TGVoiceRecorder shared].duration;
	[self.recordPanel showSeconds:d paused:paused];
	if (((NSInteger)(d * 10)) % 10 < 1)
		NSLog(@"TGVoiceRecorder: clock %.1f s (recording=%d paused=%d)",
				d, [[TGVoiceRecorder shared] recording], paused);

	if (!sIsLocked && !paused) {
		UIView *ring = [self.recordPanel viewWithTag:0x81C1];
		if (ring) {
			CGFloat pulse = TGAlphaOpaque + TGAnimationPulseAmplitude * fabsf(sinf((float)d * (float)M_PI));
			ring.transform = CGAffineTransformMakeScale(pulse, pulse);
		}
	}
}

- (void)recordFinish {
	// The touch-up path and the send disc can race; the first one in sends,
	// the second finds the recorder already closed and does nothing.
	if (sSendInFlight)
		return;
	sSendInFlight = YES;
	self.table.scrollEnabled = YES;
	[self.recordTimer invalidate];
	self.recordTimer = nil;
	[self hideRecordPanel];

	if (self.videoNoteMode){
		// The note's own send path stops the recorder: it needs the duration
		// before the stop to show the row at its real length.
		[self sendRecordedNoteOnce:self.recordOnce];
		sSendInFlight = NO;
		return;
	}

	__weak typeof(self) weakSelf = self;
	void (^done)(NSString *, NSTimeInterval) = ^(NSString *path, NSTimeInterval seconds){
		TGChatViewController *me = weakSelf;
		if (!me || !path || seconds < 0.5)
			return;   // a stray tap is not a message (me == nil after the send)
		[me clearComposeState];
		[[TGSendStore shared] sendVoiceAtPath:path
								  duration:(NSInteger)seconds
									toChat:me.chatId
									thread:me.threadId
								  viewOnce:me.recordOnce
								  progress:^(CGFloat fraction){
			(void)fraction;
			TGChatViewController *strong = weakSelf;
			if (strong)
				[strong refreshSendRings];
		} accepted:nil completion:^(BOOL sent){
			(void)sent;
			TGChatViewController *strong = weakSelf;
			if (strong)
				[strong refreshSendRings];
		}];
	};
	[[TGVoiceRecorder shared] stopWithCompletion:done];
	sSendInFlight = NO;
}

/// The note is on its way the instant Send is tapped: the row goes in before
/// the transcode, at the size it will keep. The recorder's export fills the
/// first half of the ring and TDLib's upload the second.
- (void)sendRecordedNoteOnce:(BOOL)once {
	TGVideoNoteRecorder *recorder = [TGVideoNoteRecorder shared];
	NSTimeInterval recorded = recorder.duration;

	int64_t rowId = (1LL << 52) + (++sLocalNoteRowCounter);
	NSDictionary *row = @{
		@"id"        : @(rowId),
		@"chatId"    : @(self.chatId),
		@"senderId"  : @([[TGMessageStore shared].me[@"id"] longLongValue]),
		@"outgoing"  : @YES,
		@"date"      : @((NSInteger)[[NSDate date] timeIntervalSince1970]),
		@"kind"      : @"messageVideoNote",
		@"duration"  : @((NSInteger)ceil(recorded)),
		@"sending"   : @YES,
		@"viewOnce"  : @(once),
		@"localNote" : @YES,
	};
	int64_t localId = rowId;
	self.pendingNoteRowId = rowId;
	self.pendingNoteRealId = 0;
	self.pendingNoteProgress = 0;
	self.pendingNoteCancelled = NO;

	// The same append the live update uses, so the row is laid out, grouped
	// and scrolled to exactly like one that arrived from TDLib.
	[self.streamStore appendNewerMessages:@[row]];
	self.rawMessages = [self.streamStore messages];
	self.messages = [self groupedMessagesFromMessages:self.rawMessages];
	[self.table reloadData];
	[self scrollToBottomAnimated:YES];

	__weak typeof(self) weakSelf = self;
	recorder.onExportProgress = ^(CGFloat fraction){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		if (me.pendingNoteRowId == localId)
			me.pendingNoteProgress = fraction * 0.5f;
		[me refreshSendRings];
	};

	__block int64_t sentMessageId = 0;
	// Strong self on purpose: leaving the chat must not cancel the note.
	[recorder stopWithCompletion:^(NSString *path, NSTimeInterval seconds){
		recorder.onExportProgress = nil;
		if (seconds < 0.5){
			// A stray tap: there is no note, so there is nothing to report.
			BOOL current = (self.pendingNoteRowId == localId);
			[self removeLocalNoteRowWithId:localId];
			if (current){
				self.pendingNoteRealId = 0;
				self.pendingNoteProgress = 0;
			}
			[self refreshSendRings];
			return;
		}
		if (!path){
			BOOL current = (self.pendingNoteRowId == localId);
			[self removeLocalNoteRowWithId:localId];
			if (current){
				self.pendingNoteRealId = 0;
				self.pendingNoteProgress = 0;
			}
			[self refreshSendRings];
			[TGAlertSheet showMessage:@"Your message was not sent. Tap \"Resend\" to send this message."
								 title:nil inView:self.view];
			return;
		}
		// The X landed just as the transcode finished; the row is already
		// gone, so the request must not leave either.
		if (self.pendingNoteCancelled){
			BOOL current = (self.pendingNoteRowId == localId);
			[self removeLocalNoteRowWithId:localId];
			if (current)
				self.pendingNoteProgress = 0;
			[self refreshSendRings];
			return;
		}
		[[TGSendStore shared] sendVideoNoteAtPath:path
									  duration:(NSInteger)ceil(seconds)
										length:recorder.noteSide
										toChat:self.chatId
										thread:self.threadId
									  viewOnce:once
								   thumbnail:recorder.thumbnailPath
									progress:^(CGFloat fraction){
			if (self.pendingNoteRowId == 0 || self.pendingNoteRowId == localId)
				self.pendingNoteProgress = 0.5f + 0.5f * fraction;
			[self refreshSendRings];
		} accepted:^(int64_t messageId){
			// The X landed while sendMessage was already on the wire: the
			// request cannot be taken back, but its result can be deleted.
			// The cancel waits a turn because the waiter is registered after
			// this block returns, and the cancel's own completion is what
			// clears the pending state.
			if (self.pendingNoteCancelled){
				sentMessageId = messageId;
				self.pendingNoteRealId = messageId;
				__weak typeof(self) weakChat = self;
				dispatch_async(dispatch_get_main_queue(), ^{
					[[TGSendStore shared] cancelSendingMessage:messageId
													inChat:weakChat.chatId];
				});
				return;
			}
			// updateNewMessage has already appended the real row, or will;
			// only the local one is ours to take out.
			sentMessageId = messageId;
			[self removeLocalNoteRowWithId:localId];
			self.pendingNoteRealId = messageId;
			[self refreshSendRings];
		} completion:^(BOOL sent){
			BOOL cancelled = self.pendingNoteCancelled;
			[self removeLocalNoteRowWithId:localId];
			if (sentMessageId && self.pendingNoteRealId == sentMessageId)
				self.pendingNoteRealId = 0;
			if (self.pendingNoteRowId == 0)
				self.pendingNoteProgress = 0;
			[self refreshSendRings];
			if (!sent && !cancelled)
				[TGAlertSheet showMessage:@"Your message was not sent. Tap \"Resend\" to send this message."
									 title:nil inView:self.view];
		}];
	}];
}

/// Takes the local row out and rebuilds the two arrays the same way the
/// deletion branch of onMessage does.
- (void)removeLocalNoteRow {
	[self removeLocalNoteRowWithId:self.pendingNoteRowId];
}

/// The id is explicit so a completion that lands while a second note is
/// already waiting cannot take that newer row out by mistake.
- (void)removeLocalNoteRowWithId:(int64_t)rowId {
	if (rowId <= 0)
		return;
	if (self.pendingNoteRowId == rowId)
		self.pendingNoteRowId = 0;
	if (![self.streamStore removeMessageId:rowId])
		return;
	self.rawMessages = [self.streamStore messages];
	self.messages = [self groupedMessagesFromMessages:self.rawMessages];
	[self.table reloadData];
}

/// A progress tick touches only the visible rings. Reloading the table several
/// times a second on an A4 is visible as a stutter.
- (void)refreshSendRings {
	for (UITableViewCell *tableCell in self.table.visibleCells){
		if (![tableCell isKindOfClass:TGBubbleCell.class])
			continue;
		TGBubbleCell *cell = (TGBubbleCell *)tableCell;
		NSIndexPath *indexPath = [self.table indexPathForCell:cell];
		if (!indexPath || indexPath.row >= (NSInteger)self.messages.count)
			continue;
		NSDictionary *m = self.messages[indexPath.row];
		if ([m[@"sending"] boolValue])
			[cell showSendRingWithProgress:[self ringProgressForMessage:m]];
		else
			[cell hideSendRing];
	}
}

- (CGFloat)ringProgressForMessage:(NSDictionary *)m {
	if (![m[@"sending"] boolValue])
		return 0;
	if ([m[@"localNote"] boolValue])
		return self.pendingNoteProgress;

	int64_t messageId = [m[@"id"] longLongValue];
	CGFloat fraction = [[TGSendStore shared] sendProgressForMessage:messageId];
	// A voice note is upload only; a round note spends the first half of the
	// same line being transcoded.
	if ([m[@"kind"] isEqualToString:@"messageVoiceNote"])
		return fraction;
	return 0.5f + 0.5f * fraction;
}

/// A tap on a sending row takes it back instead of playing it.
- (void)cancelSendingRow:(NSDictionary *)m {
	if (![m[@"sending"] boolValue])
		return;
	if ([m[@"localNote"] boolValue]){
		TGVideoNoteRecorder *recorder = [TGVideoNoteRecorder shared];
		recorder.onExportProgress = nil;
		[recorder cancel];
		self.pendingNoteCancelled = YES;
		self.pendingNoteProgress = 0;
		self.pendingNoteRealId = 0;
		[self removeLocalNoteRow];
		[self refreshSendRings];
		return;
	}

	int64_t messageId = [m[@"id"] longLongValue];
	if (messageId <= 0)
		return;
	if (self.pendingNoteRealId == messageId){
		self.pendingNoteRealId = 0;
		self.pendingNoteProgress = 0;
	}
	[[TGSendStore shared] cancelSendingMessage:messageId inChat:self.chatId];
}

/// The one-time choice from above the record lock acts on what is being
/// recorded right now: view once is what Telegram sends when "1" is picked,
/// a messageTelegram keeps only until the other side opened it - not a
/// countdown timer of its own.
- (void)toggleRecordOnce {
	self.recordOnce = !self.recordOnce;
	[TGRecordBar setOnce:self.recordOnce onButton:self.recordOnceButton];
}

/// The pause disc beside send. Both halves the pause has: the first tap stops
/// the encoder and the clock, the second carries on where it stopped - one
/// note comes out of it either way.
- (void)recordPauseToggled {
	TGVoiceRecorder *recorder = [TGVoiceRecorder shared];
	if (!recorder.recording)
		return;
	if (recorder.paused){
		[recorder resume];
		[self.recordPauseButton setImage:[TGIcons pause] forState:UIControlStateNormal];
	} else {
		[recorder pause];
		[self.recordPauseButton setImage:[TGIcons play] forState:UIControlStateNormal];
	}
}

- (void)recordCancel {
	self.table.scrollEnabled = YES;
	[self invalidatePendingRecordStart];
	if (![self recorderIsRecording]){
		// Nothing was ever committed to disk - the touch went away before
		// the recorder did.
		return;
	}
	sIsCancelled = YES;
	[self.recordTimer invalidate];
	self.recordTimer = nil;
	[self hideRecordPanel];
	if (self.videoNoteMode)
		[[TGVideoNoteRecorder shared] cancel];
	else
		[[TGVoiceRecorder shared] cancel];
	[self clearComposeState];
}

- (BOOL)recorderIsRecording {
	return [[TGVoiceRecorder shared] recording]
			|| [[TGVideoNoteRecorder shared] recording];
}

- (void)invalidatePendingRecordStart {
	[self.recordStartPendingTimer invalidate];
	self.recordStartPendingTimer = nil;
}


@end
