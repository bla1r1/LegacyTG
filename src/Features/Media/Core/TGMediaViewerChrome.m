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
#import "TGLocalization.h"
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

@implementation TGMediaViewer (TGMediaViewerChrome)

#pragma mark - chrome

/// The viewer lives in a backdrop nobody lays out, so chrome and pages are
/// rebuilt from the window's present bounds whenever they change. The pages
/// keep their pictures - a rotated album does not download again.
- (void)relayoutViewer {
	if (!self.backdrop)
		return;
	CGRect bounds = self.window.bounds;
	self.backdrop.frame = bounds;
	self.pager.frame = bounds;
	self.pager.contentSize = CGSizeMake(bounds.size.width * self.items.count,
										bounds.size.height);
	self.pager.contentOffset = CGPointMake(bounds.size.width * self.index, 0);

	for (NSNumber *key in self.pages) {
		NSInteger i = key.integerValue;
		UIScrollView *zoom = self.pages[key];
		zoom.frame = CGRectMake(bounds.size.width * i, 0,
				bounds.size.width, bounds.size.height);
		zoom.zoomScale = TGMetricZoomMin;
		UIImageView *picture = [zoom viewWithTag:kZoomTag + 1];
		picture.frame = zoom.bounds;
		[zoom viewWithTag:kZoomTag + kSpinnerOffset].center =
				CGPointMake(TGHalf(zoom.bounds.size.width), TGHalf(zoom.bounds.size.height));
	}

	[self.topBar removeFromSuperview];   self.topBar = nil;
	self.counterLabel = nil;             self.dateLabel = nil;
	self.authorAvatar = nil;             self.moreButton = nil;
	[self.bottomBar removeFromSuperview]; self.bottomBar = nil;
	self.captionLabel = nil;             self.playButton = nil;
	self.scrubber = nil;                 self.timeLabel = nil;
	[self.thumbStrip removeFromSuperview]; self.thumbStrip = nil;
	self.thumbButtons = nil;
	[self buildChrome];
	[self buildThumbStrip];
	[self refreshChrome];
}

- (void)buildChrome {
	CGRect bounds = self.backdrop.bounds;
	UIColor *plate = [[TGTheme shared] mediaOverlayColour];

	UIApplication *app = [UIApplication sharedApplication];
	CGFloat statusRoom = app.statusBarHidden ? 0 : MIN(app.statusBarFrame.size.width,
			app.statusBarFrame.size.height);
	[self.statusPlate removeFromSuperview];
	self.statusPlate = nil;
	if (statusRoom > 0){
		self.statusPlate = [[UIView alloc] initWithFrame:
				CGRectMake(0, 0, bounds.size.width, statusRoom)];
		self.statusPlate.backgroundColor = plate;
		[self.backdrop addSubview:self.statusPlate];
	}
	self.topBar = [[UIView alloc] initWithFrame:
			CGRectMake(0, statusRoom, bounds.size.width, kTopBar)];
	self.topBar.backgroundColor = plate;
	[self.backdrop addSubview:self.topBar];

	UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
	close.frame = CGRectMake(kChromeInset,
			TGCenteredOrigin(kTopBar, TGMetricViewerHeaderIcon),
			TGMetricViewerHeaderIcon, TGMetricViewerHeaderIcon);
	[close setImage:[TGIcons glyphNamed:@"close" colour:[[TGTheme shared] onMediaColour]
								  side:TGMetricPadLarge]
		   forState:UIControlStateNormal];
	[close addTarget:self action:@selector(dismiss)
	 forControlEvents:UIControlEventTouchUpInside];
	[self.topBar addSubview:close];

	self.moreButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.moreButton.frame = CGRectMake(
			bounds.size.width - kChromeInset - TGMetricViewerHeaderIcon,
			TGCenteredOrigin(kTopBar, TGMetricViewerHeaderIcon),
			TGMetricViewerHeaderIcon, TGMetricViewerHeaderIcon);
	[self.moreButton setImage:[TGIcons glyphNamed:@"more" colour:[[TGTheme shared] onMediaColour]
										   side:TGMetricPadLarge]
					 forState:UIControlStateNormal];
	[self.moreButton addTarget:self action:@selector(moreTapped)
			  forControlEvents:UIControlEventTouchUpInside];
	[self.topBar addSubview:self.moreButton];

	self.authorAvatar = [[UIImageView alloc] initWithFrame:CGRectMake(
			CGRectGetMaxX(close.frame) + TGMetricViewerHeaderGap,
			TGCenteredOrigin(kTopBar, TGMetricViewerAvatarSide),
			TGMetricViewerAvatarSide, TGMetricViewerAvatarSide)];
	self.authorAvatar.contentMode = UIViewContentModeScaleAspectFill;
	self.authorAvatar.clipsToBounds = YES;
	self.authorAvatar.layer.cornerRadius = TGHalf(TGMetricViewerAvatarSide);
	self.authorAvatar.backgroundColor = [[TGTheme shared] fileTileColour];
	[self.topBar addSubview:self.authorAvatar];

	CGFloat labelsX = CGRectGetMaxX(self.authorAvatar.frame) + TGMetricViewerHeaderGap;
	CGFloat labelsW = CGRectGetMinX(self.moreButton.frame) - labelsX -
			TGMetricViewerHeaderGap;
	CGFloat labelsTop = TGCenteredOrigin(kTopBar,
			TGMetricLineBody + TGMetricLineMicro);

	self.counterLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(labelsX, labelsTop, labelsW, TGMetricLineBody)];
	self.counterLabel.font = TGFontBodyStrong();
	self.counterLabel.textAlignment = NSTextAlignmentLeft;
	self.counterLabel.textColor = [[TGTheme shared] onMediaColour];
	self.counterLabel.backgroundColor = [UIColor clearColor];
	self.counterLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.topBar addSubview:self.counterLabel];

	self.dateLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(labelsX, labelsTop + TGMetricLineBody, labelsW,
					TGMetricLineMicro)];
	self.dateLabel.font = TGFontMicro();
	self.dateLabel.textAlignment = NSTextAlignmentLeft;
	self.dateLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.dateLabel.backgroundColor = [UIColor clearColor];
	self.dateLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.topBar addSubview:self.dateLabel];

	self.bottomBar = [[UIView alloc] initWithFrame:
			CGRectMake(0, bounds.size.height - kBottomBar, bounds.size.width, kBottomBar)];
	self.bottomBar.backgroundColor = plate;
	[self.backdrop addSubview:self.bottomBar];

	self.captionLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(kCaptionInset, kChromeInset,
					bounds.size.width - TGMetricViewerCaptionMarginRight, kCaptionHeight)];
	self.captionLabel.font = TGFontCaption();
	self.captionLabel.numberOfLines = 2;
	self.captionLabel.textColor = [[TGTheme shared] onMediaColour];
	self.captionLabel.backgroundColor = [UIColor clearColor];
	[self.bottomBar addSubview:self.captionLabel];

	UIButton *save = [UIButton buttonWithType:UIButtonTypeCustom];
	save.frame = CGRectMake(bounds.size.width - kSaveWidth - kCaptionInset - TGMetricBorderThick,
			kChromeInset, kSaveWidth, kCaptionHeight);
	[save setTitle:@"Save" forState:UIControlStateNormal];
	save.titleLabel.font = TGFontBody();
	[save setBackgroundImage:[TGTheme buttonImageForStyle:TGButtonStyleSecondary highlighted:NO height:kCaptionHeight] forState:UIControlStateNormal];
	[save setBackgroundImage:[TGTheme buttonImageForStyle:TGButtonStyleSecondary highlighted:YES height:kCaptionHeight] forState:UIControlStateHighlighted];
	save.layer.cornerRadius = TGMetricCornerControl;
	save.clipsToBounds = YES;
	[save addTarget:self action:@selector(saveCurrent)
	 forControlEvents:UIControlEventTouchUpInside];
	[self.bottomBar addSubview:save];
	self.saveButton = save;

	// The video strip lives in the bottom bar and only appears on a video page.
	self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.playButton.frame = CGRectMake(TGMetricPad, kStripTop, kPlayWidth, kStripHeight);
	[self.playButton setImage:[self playGlyph] forState:UIControlStateNormal];
	self.playButton.tintColor = [[TGTheme shared] onMediaColour];
	[self.playButton addTarget:self action:@selector(toggleMovie)
			  forControlEvents:UIControlEventTouchUpInside];
	self.playButton.hidden = YES;
	[self.bottomBar addSubview:self.playButton];

	self.scrubber = [[UISlider alloc] initWithFrame:
			CGRectMake(kScrubberLeft, kStripTop,
					bounds.size.width - TGMetricViewerScrubberMarginRight, kStripHeight)];
	self.scrubber.minimumTrackTintColor = [[TGTheme shared] accentColour];
	[self.scrubber setThumbImage:[TGTheme skeuomorphicSliderThumbWithRadius:TGHalf(TGMetricSliderThumbD)] forState:UIControlStateNormal];
	[self.scrubber setMinimumTrackImage:[TGTheme skeuomorphicSliderTrackImageFilled:YES] forState:UIControlStateNormal];
	[self.scrubber setMaximumTrackImage:[TGTheme skeuomorphicSliderTrackImageFilled:NO] forState:UIControlStateNormal];
	[self.scrubber addTarget:self action:@selector(scrubberMoved)
			forControlEvents:UIControlEventValueChanged];
	self.scrubber.hidden = YES;
	[self.bottomBar addSubview:self.scrubber];

	self.timeLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(bounds.size.width - kClockWidth - kChromeInset - TGMetricPadTiny,
					kStripTop, kClockWidth, kStripHeight)];
	self.timeLabel.font = TGFontMicro();
	self.timeLabel.textColor = [[TGTheme shared] onMediaColour];
	self.timeLabel.textAlignment = NSTextAlignmentRight;
	self.timeLabel.backgroundColor = [UIColor clearColor];
	self.timeLabel.hidden = YES;
	[self.bottomBar addSubview:self.timeLabel];
}

- (UIImage *)playGlyph {
	return [TGIcons image:[TGIcons play] filledWith:[[TGTheme shared] onMediaColour]];
}

- (UIImage *)pauseGlyph {
	return [TGIcons image:[TGIcons pause] filledWith:[[TGTheme shared] onMediaColour]];
}

- (void)buildThumbStrip {
	if (!self.isAlbum || self.items.count <= 1)
		return;

	CGRect bounds = self.backdrop.bounds;
	CGFloat y = bounds.size.height - kBottomBar - kThumbStripH;
	self.thumbStrip = [[UIScrollView alloc] initWithFrame:
			CGRectMake(0, y, bounds.size.width, kThumbStripH)];
	self.thumbStrip.showsHorizontalScrollIndicator = NO;
	self.thumbStrip.showsVerticalScrollIndicator = NO;
	self.thumbStrip.backgroundColor = [UIColor clearColor];
	self.thumbStrip.clipsToBounds = NO;
	self.thumbButtons = [NSMutableArray arrayWithCapacity:self.items.count];

	CGFloat itemTotal = self.items.count * kThumbSide + (self.items.count - 1) * kThumbGap;
	CGFloat startX = (itemTotal < bounds.size.width) ? TGCenteredOrigin(bounds.size.width, itemTotal) : kThumbGap;

	for (NSUInteger i = 0; i < self.items.count; i++) {
		CGFloat x = startX + i * (kThumbSide + kThumbGap);
		UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
		btn.frame = CGRectMake(x, TGCenteredOrigin(kThumbStripH, kThumbSide), kThumbSide, kThumbSide);
		btn.tag = (NSInteger)i;
		btn.layer.cornerRadius = TGMetricCornerSmall;
		btn.layer.masksToBounds = YES;
		btn.imageView.contentMode = UIViewContentModeScaleAspectFill;
		btn.adjustsImageWhenHighlighted = NO;
		[btn addTarget:self action:@selector(thumbTapped:) forControlEvents:UIControlEventTouchUpInside];
		[self.thumbStrip addSubview:btn];
		[self.thumbButtons addObject:btn];
		[self fetchThumbnailForIndex:i into:btn];
	}

	CGFloat contentW = MAX(bounds.size.width, startX + self.items.count * (kThumbSide + kThumbGap) - kThumbGap + startX);
	self.thumbStrip.contentSize = CGSizeMake(contentW, kThumbStripH);
	[self.backdrop addSubview:self.thumbStrip];
	[self updateThumbStripSelection:NO];
}

- (void)fetchThumbnailForIndex:(NSUInteger)idx into:(UIButton *)btn {
	NSDictionary *item = self.items[idx];
	NSNumber *fileId = item[@"photoId"] ?: (item[@"thumbId"] ?: item[@"docId"]);
	if (![fileId isKindOfClass:NSNumber.class])
		return;

#if TG_DEV
	if (fileId.longLongValue < 0) {
		UIImage *fixture = [TGDevShowcase imageForPhotoId:fileId.longLongValue];
		if (fixture) {
			[btn setImage:fixture forState:UIControlStateNormal];
			return;
		}
	}
#endif

	__weak typeof(self) weakSelf = self;
	__weak UIButton *weakBtn = btn;
	[[TGMediaStore shared] downloadFile:fileId.integerValue priority:TGDownloadPriorityOnScreen completion:^(NSString *path){
		if (!path.length) return;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			UIImage *img = [UIImage imageWithContentsOfFile:path];
			if (!img && [path.pathExtension.lowercaseString isEqualToString:@"webp"])
				img = [UIImage convertFromWebP:path compressedData:nil error:nil];
			if (!img) return;
			dispatch_async(dispatch_get_main_queue(), ^{
				if (weakBtn.tag == (NSInteger)idx) {
					[weakBtn setImage:img forState:UIControlStateNormal];
				}
			});
		});
	}];
}

- (void)updateThumbStripSelection:(BOOL)animated {
	if (!self.thumbButtons.count)
		return;

	// The ring is a layer property and snaps; the dimming is alpha, which the
	// render server eases, so the strip still reads as moving with the page.
	for (UIButton *btn in self.thumbButtons) {
		BOOL selected = (btn.tag == self.index);
		if (selected) {
			btn.layer.borderWidth = 2.0f;
			btn.layer.borderColor = [[TGTheme shared] onMediaColour].CGColor;
		} else {
			btn.layer.borderWidth = 0.0f;
			btn.layer.borderColor = [UIColor clearColor].CGColor;
		}
	}
	void (^dim)(void) = ^{
		for (UIButton *btn in self.thumbButtons)
			btn.alpha = (btn.tag == self.index) ? TGAlphaOpaque : TGAlphaDimmed;
	};
	if (animated)
		[UIView animateWithDuration:TGAnimationDurationFast animations:dim];
	else
		dim();

	if (self.index >= 0 && self.index < (NSInteger)self.thumbButtons.count) {
		UIButton *curr = self.thumbButtons[self.index];
		CGFloat targetX = curr.center.x - TGHalf(self.thumbStrip.bounds.size.width);
		CGFloat maxX = MAX(0.0f, self.thumbStrip.contentSize.width - self.thumbStrip.bounds.size.width);
		targetX = MAX(0.0f, MIN(targetX, maxX));
		[self.thumbStrip setContentOffset:CGPointMake(targetX, 0) animated:animated];
	}
}

- (void)thumbTapped:(UIButton *)btn {
	[self gotoPage:btn.tag animated:YES];
}

/// One page-change path for the thumb strip, the tap zones and a programmatic
/// move. Leaving a video's page stops it first, which is what keeps a movie
/// from playing behind a picture two pages away.
- (void)gotoPage:(NSInteger)idx animated:(BOOL)animated {
	if (idx < 0 || idx >= (NSInteger)self.items.count || idx == self.index)
		return;
	if (self.moviePage != NSNotFound && idx != self.moviePage)
		[self stopMovie];

	self.index = idx;
	[self.pager setContentOffset:CGPointMake(self.pager.bounds.size.width * idx, 0)
						animated:animated];
	[self loadPagesAround:idx];
	if (animated)
		[self fadeChromeText];
	[self refreshChrome];
	[self updateThumbStripSelection:animated];
}

/// The counter and the date change while the pages are still sliding, so the
/// new text dissolves in rather than snapping. A CATransition is done by the
/// render server and costs the main thread nothing after the call.
- (void)fadeChromeText {
	for (UILabel *label in @[self.counterLabel ?: [NSNull null],
							 self.dateLabel ?: [NSNull null],
							 self.captionLabel ?: [NSNull null]]){
		if (![label isKindOfClass:UILabel.class])
			continue;
		CATransition *fade = [CATransition animation];
		fade.type = kCATransitionFade;
		fade.duration = TGAnimationDurationFast;
		[label.layer addAnimation:fade forKey:@"tg.text"];
	}
}

/// Telegram's viewer splits the picture into three: the left third goes back,
/// the right third goes on, and the middle shows or hides the chrome. A tap
/// on a control never reaches here - the delegate below refuses it.
- (void)tapAt:(UITapGestureRecognizer *)tap {
	if (self.items.count < 2){
		[self toggleChrome];
		return;
	}
	CGPoint where = [tap locationInView:self.backdrop];
	CGFloat width = self.backdrop.bounds.size.width;
	if (where.x < width / 3.0f){
		if (self.index > 0)
			[self gotoPage:self.index - 1 animated:YES];
		return;
	}
	if (where.x > width - width / 3.0f){
		if (self.index < (NSInteger)self.items.count - 1)
			[self gotoPage:self.index + 1 animated:YES];
		return;
	}
	[self toggleChrome];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture
		shouldReceiveTouch:(UITouch *)touch {
	// A tap, a hold or a drag that starts on a button belongs to the button.
	UIView *view = touch.view;
	while (view && view != self.backdrop){
		if ([view isKindOfClass:UIControl.class])
			return NO;
		view = view.superview;
	}
	return YES;
}

- (void)toggleChrome {
	self.chromeHidden = !self.chromeHidden;
	[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
		self.topBar.alpha = self.chromeHidden ? 0 : 1;
		self.bottomBar.alpha = self.chromeHidden ? 0 : 1;
		self.thumbStrip.alpha = self.chromeHidden ? 0 : 1;
	}];
}

- (void)refreshChrome {
	NSDictionary *item = self.items[self.index];

	static NSDateFormatter *when = nil;
	if (!when){
		when = [[NSDateFormatter alloc] init];
		when.dateStyle = NSDateFormatterMediumStyle;
		when.timeStyle = NSDateFormatterShortStyle;
	}
	NSString *language = TGAppLanguage();
	when.locale = language.length
			? [NSLocale localeWithLocaleIdentifier:language]
			: [NSLocale currentLocale];
	int64_t senderId = [item[@"senderId"] longLongValue];
	NSString *sender = [[TGMediaStore shared] nameForUserId:senderId];
	NSString *date = [when stringFromDate:
			[NSDate dateWithTimeIntervalSince1970:[item[@"date"] doubleValue]]];
	self.counterLabel.text = sender.length ? sender : @"Media";
	NSString *counter = TGLocalizedFormat(@"%1$@ of %2$@",
			@(self.index + 1), @(self.items.count));
	self.dateLabel.text = [NSString stringWithFormat:@"%@ · %@", counter, date];
	[self refreshAvatarForUserId:senderId title:sender];

	NSString *text = [item[@"text"] isKindOfClass:NSString.class] ? item[@"text"] : @"";
	NSArray *entities = [item[@"entities"] isKindOfClass:NSArray.class] ? item[@"entities"] : nil;
	if (entities.count && text.length) {
		self.captionLabel.attributedText = TGAttributedMessageText(text, entities, self.captionLabel.font, self.captionLabel.textColor);
	} else {
		self.captionLabel.text = text;
	}
	self.saveButton.hidden = TGViewerItemLocked(item);

	BOOL isVideo = [item[@"kind"] isEqualToString:@"messageVideo"];
	BOOL isAnim = [item[@"kind"] isEqualToString:@"messageAnimation"];
	self.playButton.hidden = !isVideo && !isAnim;
	self.scrubber.hidden = !isVideo;
	self.timeLabel.hidden = !isVideo;
	self.captionLabel.frame = CGRectMake(kCaptionInset, kChromeInset,
			self.backdrop.bounds.size.width - TGMetricViewerCaptionMarginRight,
			(isVideo || isAnim) ? kCaptionHeight - TGMetricPadSmall : kCaptionHeight);
}

/// The header's picture follows the sender, not the message: every page from
/// one person in a group carries the same face. A photo id is read from the
/// account map; the initials stand in until it arrives.
- (void)refreshAvatarForUserId:(int64_t)userId title:(NSString *)title {
	self.avatarFileId = nil;
	NSString *initial = [TGIcons initialsForTitle:title];
	self.authorAvatar.image = [TGIcons avatarWithInitials:initial
													size:TGMetricViewerAvatarSide
												colourId:userId];
	if (userId <= 0)
		return;
	NSNumber *fileId = [[TGMediaStore shared] photoFileIdForUserId:userId];
	if (![fileId isKindOfClass:NSNumber.class] || fileId.integerValue <= 0)
		return;
	self.avatarFileId = fileId;

	__weak typeof(self) weakSelf = self;
	__weak UIImageView *weakAvatar = self.authorAvatar;
	[[TGMediaStore shared] downloadFile:fileId.integerValue
							  priority:TGDownloadPriorityOnScreen
							completion:^(NSString *path){
		if (!path.length)
			return;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			UIImage *image = [UIImage imageWithContentsOfFile:path];
			if (!image)
				return;
			image = [TGIcons decodedImage:image
					fittingSize:CGSizeMake(TGMetricViewerAvatarSide,
										   TGMetricViewerAvatarSide)
							 fill:YES scale:[UIScreen mainScreen].scale];
			if (!image)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				TGMediaViewer *me = weakSelf;
				if (me && [me.avatarFileId isEqual:fileId])
					weakAvatar.image = image;
			});
		});
	}];
}


@end
