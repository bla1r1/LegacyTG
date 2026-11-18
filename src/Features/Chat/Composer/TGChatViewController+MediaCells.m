//
// TGChatViewController+MediaCells.m
// Bubble cell rendering for photos, albums, animated stickers, video notes, and GIFs.
//
#import "TGChatViewControllerInternal.h"
#import <QuartzCore/QuartzCore.h>
#import "TGCapabilities.h"
#import "TGLottieView.h"
#import "TGSlotMachine.h"
#import "TGDevice.h"
#import "TGStyle.h"
#import "TGLocalization.h"
#import "TGUIFormat.h"

/// A photo's corner follows its bubble's: the bubble's radius less the
/// kMediaInset between them, so the two curves stay parallel.
static CGFloat TGChatMediaCorner(void) {
	CGFloat bubble = [TGTheme drawsSkeuomorphicChrome] ? TGMetricCornerBubbleSkeuo
			: TGMetricCornerBubbleFlat;
	return bubble - kMediaInset;
}

@implementation TGChatViewController (MediaCells)

- (BOOL)configureRoundOrStickerCell:(TGBubbleCell *)cell message:(NSDictionary *)m layout:(TGMessageLayout *)layout isMine:(BOOL)mine {
	TGTheme *theme = [TGTheme shared];

	// Video note
	if (layout.isRound) {
		CGFloat side = layout.bubbleFrame.size.width;
		cell.bubble.backgroundColor = [theme fileTileColour];
		cell.bubble.layer.borderWidth = TGMetricBorderNone;
		cell.bubble.frame = layout.bubbleFrame;
		// cornerRadius rounds the tile fill for free; a clip would be an
		// offscreen pass per frame while the note scrolls. The thumbnail is
		// baked into a circle (TGIcons setRoundedImage:) so neither the bubble
		// nor the picture needs a mask or a clip.
		cell.bubble.layer.cornerRadius = TGHalf(side);
		cell.bubble.clipsToBounds = NO;
		cell.picture.hidden = NO;
		[TGIcons setRoundedImage:[self imageFor:m] inView:cell.picture
				size:CGSizeMake(side, side) radius:TGHalf(side)];
		cell.picture.backgroundColor = [theme fileTileColour];
		cell.picture.frame = CGRectMake(TGMetricZero, TGMetricZero, side, side);
		cell.picture.layer.cornerRadius = TGHalf(side);
		cell.picture.clipsToBounds = NO;
		cell.body.hidden = YES;

		cell.disc.hidden = NO;
		cell.disc.userInteractionEnabled = YES;
		CGFloat disc = kVideoDisc;
		BOOL isPlaying = (self.playingMessageId == [m[@"id"] longLongValue] && self.videoNotePlayer != nil);
		BOOL sending = [m[@"sending"] boolValue];
		cell.disc.image = sending ? [TGIcons cancelDiscOfSide:disc]
				: [TGIcons mediaDiscOfSide:disc playing:isPlaying];
		cell.disc.frame = CGRectMake(TGCenteredOrigin(side, disc), TGCenteredOrigin(side, disc), disc, disc);
		if (sending)
			[cell showSendRingWithProgress:[self ringProgressForMessage:m]];
		else
			[cell hideSendRing];
		if (!cell.disc.gestureRecognizers.count) {
			[cell.disc addGestureRecognizer:[[UITapGestureRecognizer alloc]
					initWithTarget:self action:@selector(videoNoteDiscTapped:)]];
		}
		NSInteger dur = [m[@"duration"] integerValue];
		NSString *durStr = (dur > 0) ? TGUIFormatCallDuration(dur) : @"";
		if ([m[@"viewOnce"] boolValue] || [m[@"secretMedia"] boolValue]){
			// The one-time round note wears its "1" like their chat does - the
			// clock that sent it has one opening in it.
			durStr = durStr.length ? [@"1 " stringByAppendingString:durStr] : @"1";
		}
		NSString *stamp = (layout.stamp.length && ![layout.stamp isEqualToString:@"(null)"]) ? layout.stamp : @"";

		CGRect frame = layout.bubbleFrame;
		BOOL unplayedDot = [self showsUnplayedMarkFor:m];
		CGFloat durW = durStr.length ? TGTextSize(durStr, TGFontMicro(), 0).width : 0.0f;
		CGFloat clockW = stamp.length ? TGTextSize(stamp, TGFontMicro(), 0).width : 0.0f;

		CGRect durFrame = CGRectZero, timeFrame = CGRectZero, ticksFrame = CGRectZero, dotFrame = CGRectZero;
		TGVideoNoteLayoutBottomBar(frame, durW, clockW, mine, unplayedDot,
								   &durFrame, &timeFrame, &ticksFrame, &dotFrame);

		// Duration and time sit on the wallpaper under the circle: each gets
		// the plate a photo's stamp has, or a busy pattern swallows them.
		CGRect plateInsets = CGRectInset(durFrame, -TGMetricPadSmall,
				-TGHalf(TGMetricLineCaption - TGMetricStampHeight));
		[cell.contentView addSubview:cell.mediaStamp];
		cell.mediaStamp.hidden = !durStr.length;
		cell.mediaStamp.backgroundColor = [theme mediaStampColour];
		cell.mediaStamp.textColor = [theme onMediaColour];
		cell.mediaStamp.font = TGFontMicro();
		cell.mediaStamp.text = durStr;
		cell.mediaStamp.textAlignment = NSTextAlignmentCenter;
		cell.mediaStamp.layer.cornerRadius = TGMetricCornerControl;
		cell.mediaStamp.frame = plateInsets;

		[cell.contentView addSubview:cell.time];
		cell.time.hidden = !stamp.length;
		cell.time.text = stamp;
		cell.time.textColor = [theme onMediaColour];
		cell.time.textAlignment = NSTextAlignmentLeft;
		cell.time.frame = timeFrame;

		CGRect group = timeFrame;
		if (mine)
			group = CGRectUnion(group, ticksFrame);
		if (stamp.length){
			[cell.contentView insertSubview:cell.stampPlate belowSubview:cell.time];
			cell.stampPlate.hidden = NO;
			cell.stampPlate.backgroundColor = [theme mediaStampColour];
			cell.stampPlate.frame = CGRectMake(group.origin.x - TGMetricPadSmall,
					CGRectGetMidY(timeFrame) - TGHalf(TGMetricLineCaption),
					group.size.width + TGDoubled(TGMetricPadSmall), TGMetricLineCaption);
		}

		cell.ticks.hidden = !mine;
		if (mine) {
			[cell.contentView addSubview:cell.ticks];
			cell.ticks.image = [self ticksForMessage:m white:YES];
			cell.ticks.frame = ticksFrame;
		}

		cell.unreadDot.hidden = !unplayedDot;
		if (unplayedDot){
			[cell.contentView addSubview:cell.unreadDot];
			cell.unreadDot.frame = dotFrame;
			cell.unreadDot.layer.cornerRadius = TGHalf(TGMetricUnreadDotSide);
			cell.unreadDot.backgroundColor = [theme accentColour];
		}

		return YES;
	}

	// Animated sticker (.tgs or .webm)
	BOOL isAnimSticker = [TGCapabilities canPlayAnimatedStickers] &&
		([m[@"docName"] isEqualToString:@"tgs"] || [m[@"docName"] isEqualToString:@"webm"]);
	NSString *animPath = isAnimSticker ? self.lottiePaths[m[@"docId"]] : nil;
	if (animPath) {
		CGFloat side = kLottieSide;
		__weak typeof(self) weakSelf = self;
		// A webm still decoding answers NO and reports here; one debounced
		// reload brings the decoded frame into every visible row of it.
		cell.lottie.onStickerReady = ^{ [weakSelf reloadTableDebounced]; };
		cell.bubble.backgroundColor = [UIColor clearColor];
		cell.bubble.layer.borderWidth = TGMetricBorderNone;
		cell.bubble.frame = layout.bubbleFrame;
		cell.picture.hidden = YES;
		cell.body.hidden = YES;
		cell.lottie.frame = CGRectMake(TGMetricZero, TGMetricZero, side, side);
		BOOL playable = [cell.lottie loadStickerFile:animPath];
		cell.lottie.hidden = !playable;
		// On Vintage the VP9/vector decode and the scroll share one core: a
		// sticker told to play mid-drag starts a decode that fights the scroll
		// for it. It keeps its first frame (already decoded and cached) until
		// the scroll settles and the settle reload starts the animation.
		BOOL scrollSettled = [TGDevice tier] != TGDeviceTierVintage ||
				!(self.table.isDragging || self.table.isDecelerating);
		[self placeSlotLayersIn:cell message:m playable:playable settled:scrollSettled];
		[self playStickerEffectIn:cell message:m playable:playable];
		if (playable) {
			[self playOnce:cell.lottie path:animPath settled:scrollSettled];
		} else {
			// Not playable: a .tgs not gzipped or the renderer cannot draw, a
			// .webm this decoder cannot open, or a build still running. The
			// sticker's own still comes first; the emoji glyph only while
			// that is downloading. A single animated emoji has no glyph to
			// fall back on and was a sticker-sized hole.
			int64_t emojiId = [m[@"stickerEmojiId"] longLongValue];
			UIImage *still = emojiId
					? [[TGCustomEmojiStore shared] imageForId:emojiId side:side]
					: [self imageFor:m];
			if (still) {
				[TGIcons setRoundedImage:still inView:cell.picture size:CGSizeZero
								  radius:TGMetricCornerNone];
				cell.picture.hidden = NO;
				cell.picture.backgroundColor = [UIColor clearColor];
				cell.picture.layer.cornerRadius = TGMetricCornerNone;
				cell.picture.layer.borderWidth = TGMetricBorderNone;
				cell.picture.clipsToBounds = YES;
				cell.picture.frame = cell.lottie.frame;
				[cell.bubble bringSubviewToFront:cell.picture];
			} else {
				// The store answers with TGCustomEmojiLoadedNotification.
				if (!emojiId)
					[self fetchImageForMessage:m];
				[self placeStickerEmoji:cell message:m inFrame:cell.lottie.frame];
			}
		}

		// The sticker's stamp is the whole stamp (edited, views, ticks) on
		// a plate under its right edge, placed like every other stamp. It
		// was a bare "HH:mm" on the wallpaper, with no ticks.
		TGMessageStampParts parts;
		CGRect plate = TGMessageStampPlate(m, side, layout.bubbleFrame.size.height, &parts);
		cell.stampPlate.hidden = NO;
		cell.stampPlate.backgroundColor = [theme mediaStampColour];
		cell.stampPlate.frame = plate;
		[cell.bubble insertSubview:cell.stampPlate belowSubview:cell.time];
		cell.time.text = layout.stamp;
		cell.time.textColor = [theme onMediaColour];
		cell.time.textAlignment = NSTextAlignmentRight;
		cell.time.frame = parts.text;
		cell.viewsEye.hidden = CGRectIsEmpty(parts.eye);
		if (!cell.viewsEye.hidden){
			cell.viewsEye.image = [TGIcons glyphNamed:@"eye" colour:[theme onMediaColour] side:kStampEyeSide];
			cell.viewsEye.frame = parts.eye;
		}
		cell.ticks.hidden = !mine;
		if (mine){
			cell.ticks.image = [self ticksForMessage:m white:YES];
			cell.ticks.frame = parts.ticks;
			[cell.bubble bringSubviewToFront:cell.ticks];
		}
		[cell.bubble bringSubviewToFront:cell.time];
		return YES;
	}

	return NO;
}

/// A slot machine's reels and lever over its background, in one frame. They
/// spin once per message per chat visit and rest on the result, never while
/// the A4 scrolls, and show only when all four load (TGSlotReelPlaybackFor).
/// Any other sticker clears them from a reused cell.
- (void)placeSlotLayersIn:(TGBubbleCell *)cell message:(NSDictionary *)m playable:(BOOL)playable
				  settled:(BOOL)settled {
	NSArray *layers = [m[@"slotLayers"] isKindOfClass:NSArray.class] ? m[@"slotLayers"] : @[];
	NSUInteger loaded = 0;
	for (NSUInteger i = 0; i < 4; i++) {
		NSString *path = (playable && i < layers.count) ? self.lottiePaths[layers[i]] : nil;
		TGLottieView *view = (TGLottieView *)[cell.bubble viewWithTag:TGBubbleSlotLayerTag + (NSInteger)i];
		if (!path) {
			view.hidden = YES;
			continue;
		}
		if (!view) {
			view = [[TGLottieView alloc] initWithFrame:cell.lottie.frame];
			view.tag = TGBubbleSlotLayerTag + (NSInteger)i;
			view.userInteractionEnabled = NO;
			view.holdsLastFrame = YES;
			// A reel still building answers NO; its readiness reloads the
			// row, so the machine appears once all four are in.
			__weak typeof(self) weakSelf = self;
			view.onStickerReady = ^{ [weakSelf reloadTableDebounced]; };
			[cell.bubble insertSubview:view aboveSubview:(i ? [cell.bubble viewWithTag:TGBubbleSlotLayerTag + (NSInteger)i - 1] : cell.lottie)];
		}
		view.frame = cell.lottie.frame;
		if ([view loadStickerFile:path])
			loaded++;
	}
	NSNumber *msgId = m[@"id"];
	TGSlotReelPlayback playback = TGSlotReelPlaybackFor(loaded, playable ? layers.count : 0,
			msgId && [self.spunSlotMachines containsObject:msgId], settled);
	if (playback == TGSlotReelSpin && msgId) {
		if (!self.spunSlotMachines)
			self.spunSlotMachines = [NSMutableSet set];
		[self.spunSlotMachines addObject:msgId];
	}
	for (NSUInteger i = 0; i < 4; i++) {
		TGLottieView *view = (TGLottieView *)[cell.bubble viewWithTag:TGBubbleSlotLayerTag + (NSInteger)i];
		view.hidden = playback == TGSlotReelHide || i >= layers.count;
		if (view.hidden)
			continue;
		if (playback == TGSlotReelSpin)
			[view playOnce];
		else if (playback == TGSlotReelRest)
			[view showLastFrame];
	}
}

/// A premium sticker's effect, once per message per chat visit, larger than
/// the sticker and leaning toward the bubble's open side, mirrored for an
/// incoming one (official playEffectAnimation). It goes when it has played.
- (void)playStickerEffectIn:(TGBubbleCell *)cell message:(NSDictionary *)m playable:(BOOL)playable {
	NSNumber *effectId = m[@"stickerEffectId"];
	NSNumber *msgId = m[@"id"];
	NSString *path = [effectId longLongValue] > 0 ? self.lottiePaths[effectId] : nil;
	if (!playable || !path || !msgId || ![TGCapabilities canPlayStickerEffects] ||
			[self.playedStickerEffects containsObject:msgId])
		return;
	if (!self.playedStickerEffects)
		self.playedStickerEffects = [NSMutableSet set];
	[self.playedStickerEffects addObject:msgId];

	BOOL incoming = ![m[@"outgoing"] boolValue];
	CGRect sticker = [cell.bubble convertRect:cell.lottie.frame toView:cell.contentView];
	CGFloat dx = sticker.size.width * TGMetricStickerEffectGrow - TGMetricStickerEffectPullBack;
	CGRect frame = CGRectInset(CGRectOffset(sticker, incoming ? dx : -dx, TGMetricZero),
			-sticker.size.width * TGMetricStickerEffectGrow,
			-sticker.size.height * TGMetricStickerEffectGrow);
	TGLottieView *effect = [[TGLottieView alloc] initWithFrame:frame];
	effect.tag = TGBubbleStickerEffectTag;
	effect.userInteractionEnabled = NO;
	if (incoming)
		effect.transform = CGAffineTransformMakeScale(-TGMetricScaleFull, TGMetricScaleFull);
	if (![effect loadStickerFile:path])
		return;
	cell.clipsToBounds = NO;
	cell.contentView.clipsToBounds = NO;
	[cell.contentView addSubview:effect];
	__weak TGLottieView *weakEffect = effect;
	effect.onPlayedOnce = ^{ [weakEffect removeFromSuperview]; };
	[effect playOnce];
}

/// What Telegram shows while a sticker is still a promise: the emoji it
/// stands for, drawn where the sticker would have been.
- (void)placeStickerEmoji:(TGBubbleCell *)cell message:(NSDictionary *)m inFrame:(CGRect)frame {
	NSString *emoji = m[@"extra"] ?: m[@"emoji"];
	if (!emoji.length || frame.size.height <= 0)
		return;
	// Drawn once into an image and cached per emoji and size: a colour-font
	// glyph this big is 120 ms of layout on an A4, and it used to be paid on
	// every reuse of the row.
	cell.picture.hidden = NO;
	cell.picture.backgroundColor = [UIColor clearColor];
	cell.picture.image = [TGIcons emojiGlyph:emoji side:frame.size.height];
	cell.picture.frame = frame;
	[cell.bubble bringSubviewToFront:cell.picture];
}

- (void)configureMediaForCell:(TGBubbleCell *)cell message:(NSDictionary *)m layout:(TGMessageLayout *)layout isMine:(BOOL)mine {
	TGTheme *theme = [TGTheme shared];
	NSString *kind = m[@"kind"];

	if (layout.isAlbum) {
		cell.collageView.hidden = NO;
		cell.collageView.frame = layout.collageFrame;
		cell.picture.hidden = YES;
		cell.picture.image = nil;

		NSArray *albumMsgs = m[@"albumMessages"];
		NSUInteger count = albumMsgs.count;
		NSArray *frames = layout.albumFrames;

		for (NSInteger i = 0; i < 4; i++) {
			UIImageView *iv = cell.collageViews[i];
			if (i < (NSInteger)frames.count && i < (NSInteger)count) {
				iv.hidden = NO;
				iv.frame = [frames[i] CGRectValue];
				NSDictionary *itemMsg = albumMsgs[i];
				if (![self imageFor:itemMsg])
					[self fetchImageForMessage:itemMsg];
				[TGIcons setRoundedImage:[self imageFor:itemMsg] inView:iv size:iv.frame.size
								  radius:TGMetricCornerSmall];
			} else {
				iv.hidden = YES;
				[TGIcons setRoundedImage:nil inView:iv size:CGSizeZero radius:0];
			}
		}

		if (count > 4 && frames.count >= 4) {
			cell.collageMoreLabel.hidden = NO;
			cell.collageMoreLabel.frame = [frames[3] CGRectValue];
			cell.collageMoreLabel.text = [NSString stringWithFormat:@"+%ld", (long)(count - 3)];
			[cell.collageView bringSubviewToFront:cell.collageMoreLabel];
		} else {
			cell.collageMoreLabel.hidden = YES;
		}

		__weak typeof(self) weakSelf = self;
		__weak TGBubbleCell *weakCell = cell;
		cell.onCollageItemTapped = ^(NSInteger idx) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf) return;
			if (idx >= 0 && idx < (NSInteger)albumMsgs.count) {
				NSArray *tiles = weakCell.collageViews;
				UIView *source = idx < (NSInteger)tiles.count ? tiles[idx] : nil;
				[TGMediaViewer presentItems:albumMsgs
									startAt:idx
									 inChat:strongSelf.chatId
									isAlbum:YES
								   fromView:source];
			}
		};

		if (layout.stampOnPicture) {
			cell.mediaStamp.hidden = NO;
			cell.mediaStamp.backgroundColor = [theme mediaStampColour];
			// The plate is only the plate: its eye, text and ticks are
			// placed by TGMessageStampPlace, not padded in with spaces.
			cell.mediaStamp.text = @"";
			cell.mediaStamp.frame = layout.mediaStampFrame;
			[cell.bubble bringSubviewToFront:cell.mediaStamp];
		}
	} else if (layout.picSize.height > 0) {
		cell.collageView.hidden = YES;
		cell.picture.hidden = NO;
		UIImage *img = [self imageFor:m];
		if (!img)
			[self fetchImageForMessage:m];   // evicted while off screen
		// A sticker goes in as it is (a zero size means "do not round").
		[TGIcons setRoundedImage:img inView:cell.picture
							size:layout.isSticker ? CGSizeZero : layout.pictureFrame.size
						  radius:TGChatMediaCorner()];
		// The tile shows while the rounded copy is still being drawn.
		cell.picture.backgroundColor = layout.isSticker ? [UIColor clearColor] : [theme bubblePlaceholderColour:mine];
		cell.picture.frame = layout.pictureFrame;
		cell.picture.layer.cornerRadius = layout.isSticker ? TGMetricCornerNone : TGChatMediaCorner();
		// No frame round a photo: no iOS release draws one, and the grey
		// line read as a heavy border in both themes.
		cell.picture.layer.borderWidth = TGMetricBorderNone;
		// A sticker is clipped to a plain rectangle, which is a scissor and
		// free; a photo is already rounded, so it needs no clip at all.
		cell.picture.clipsToBounds = layout.isSticker;

		// A sticker draws on nothing but its own image: no fill, no body text.
		// Until the file arrives the row is a hole in the wallpaper with a
		// clock floating in it.
		if (layout.isSticker && !img)
			[self placeStickerEmoji:cell message:m inFrame:layout.pictureFrame];

		cell.disc.hidden = ![kind isEqualToString:@"messageVideo"] && ![kind isEqualToString:@"messageAnimation"];
		if (!cell.disc.hidden) {
			CGFloat disc = kGifDisc;
			cell.disc.image = [TGIcons mediaDiscOfSide:disc playing:NO];
			// Centred on the frame the picture actually got, not on kPadH and
			// the picture's natural size: a wide bubble stretches the one and
			// leaves the other behind, which pushed the arrow off to the left.
			cell.disc.frame = CGRectMake(
					CGRectGetMinX(layout.pictureFrame) + TGCenteredOrigin(CGRectGetWidth(layout.pictureFrame), disc),
					CGRectGetMinY(layout.pictureFrame) + TGCenteredOrigin(CGRectGetHeight(layout.pictureFrame), disc),
					disc, disc);
		}

		if ([kind isEqualToString:@"messageAnimation"] && ![TGCapabilities canAutoplayGIFs]) {
			cell.icon.hidden = NO;
			cell.icon.layer.cornerRadius = TGMetricCornerSmall;
			cell.icon.backgroundColor = [[TGTheme shared] mediaOverlayColour];
			cell.icon.textColor = [[TGTheme shared] onMediaColour];
			cell.icon.font = TGFontPlate();
			cell.icon.text = [TGCapabilities gifAutoplayWanted]
					? [NSString stringWithFormat:@" %@ · %@ ", TGLocalized(@"GIF"),
							TGLocalized(@"Play")]
					: [NSString stringWithFormat:@" %@ · %@ ", TGLocalized(@"GIF"),
							TGLocalized(@"Off")];
			CGSize fits = [cell.icon sizeThatFits:CGSizeMake(layout.picSize.width, TGMetricLineCaption)];
			cell.icon.frame = CGRectMake(kPadH + kCaptionInset,
										 layout.pictureFrame.origin.y + kCaptionInset,
										 MIN(fits.width + TGMetricPad,
												 layout.picSize.width - TGDoubled(kCaptionInset)),
										 TGMetricLineCaption);
			[cell.bubble bringSubviewToFront:cell.icon];
		}

		[self placeVeilOn:cell message:m layout:layout picture:img];

		if (layout.stampOnPicture) {
			cell.mediaStamp.hidden = NO;
			cell.mediaStamp.backgroundColor = [theme mediaStampColour];
			// The plate is only the plate: its eye, text and ticks are
			// placed by TGMessageStampPlace, not padded in with spaces.
			cell.mediaStamp.text = @"";
			cell.mediaStamp.frame = layout.mediaStampFrame;
			[cell.bubble bringSubviewToFront:cell.mediaStamp];
		}
	} else {
		cell.collageView.hidden = YES;
		cell.picture.hidden = YES;
		cell.picture.image = nil;
	}
}

/// A one-time or timed picture shows "Tap to view" over a blur and opens
/// once; a spoiler shows the blur alone until it is tapped. Touches go
/// through the veil to the row, which decides between the two. Paid media
/// shows an "Unlock for N Stars" button whose tap informs that Stars are
/// not yet supported.
- (void)placeVeilOn:(TGBubbleCell *)cell message:(NSDictionary *)m
			 layout:(TGMessageLayout *)layout picture:(UIImage *)img {
	NSString *kind = m[@"kind"];
	BOOL isPaid = [m[@"paidPreview"] boolValue] || [kind isEqualToString:@"messagePaidMedia"];
	BOOL media = [kind isEqualToString:@"messagePhoto"] || [kind isEqualToString:@"messageVideo"] ||
			[kind isEqualToString:@"messageAnimation"];
	BOOL once = [m[@"viewOnce"] boolValue] || [m[@"destructSeconds"] integerValue] > 0 ||
			[m[@"secretMedia"] boolValue];
	BOOL spoiler = [m[@"hasSpoiler"] boolValue] && ![self.revealedSpoilers containsObject:m[@"id"] ?: @0];
	BOOL sensitive = [m[@"sensitive"] boolValue] && ![self.revealedSpoilers containsObject:m[@"id"] ?: @0];
	TGMediaVeilKind veil = isPaid ? TGMediaVeilKindPaid
			: !media ? TGMediaVeilKindNone
			: once ? TGMediaVeilKindViewOnce
			: sensitive ? TGMediaVeilKindSensitive
			: spoiler ? TGMediaVeilKindSpoiler : TGMediaVeilKindNone;
	if (veil == TGMediaVeilKindNone){
		cell.veilView.hidden = YES;
		return;
	}
	if (!cell.veilView){
		cell.veilView = [[TGMediaVeilView alloc] initWithFrame:CGRectZero];
		// The picture under it is rounded; a rasterised rounded clip is
		// drawn once, not on every scroll frame.
		cell.veilView.layer.cornerRadius = TGMetricCornerMedium;
		cell.veilView.layer.masksToBounds = YES;
		cell.veilView.layer.shouldRasterize = YES;
		cell.veilView.layer.rasterizationScale = [UIScreen mainScreen].scale;
	}
	if (veil == TGMediaVeilKindPaid) {
		cell.veilView.userInteractionEnabled = YES;
		int64_t starCount = [m[@"starCount"] longLongValue];
		if (!starCount && [m[@"paidMedia"] isKindOfClass:NSDictionary.class]) {
			starCount = [m[@"paidMedia"][@"starCount"] longLongValue];
		}
		cell.veilView.starCount = starCount;
		__weak typeof(self) weakSelf = self;
		cell.veilView.onTap = ^(TGMediaVeilKind k) {
			TGChatViewController *me = weakSelf;
			if (me) {
				[TGSnackbar showInView:me.view
								  text:@"Paying with Stars is not available in this app yet."
							   seconds:2 onCommit:nil];
			}
		};
	} else {
		cell.veilView.userInteractionEnabled = NO;
		cell.veilView.onTap = nil;
	}
	if (cell.veilView.superview != cell.bubble)
		[cell.bubble addSubview:cell.veilView];
	cell.veilView.frame = layout.pictureFrame;
	cell.veilView.kind = veil;
	[cell.veilView setPicture:img];
	[cell.bubble bringSubviewToFront:cell.veilView];
	cell.disc.hidden = YES;
}

#pragma mark - GIFs

static const long long kGifAutoDownloadLimit = 3 * 1024 * 1024;

- (void)startGifIfWantedIn:(TGBubbleCell *)cell message:(NSDictionary *)m {
	if (![m[@"kind"] isEqualToString:@"messageAnimation"] || cell.picture.hidden ||
		![TGCapabilities canAutoplayGIFs] || self.isEditingMessages){
		[cell stopLoopingVideo];
		// Stopped here for any reason, the row must go back to its play mark
		// instead of keeping the disc hidden from when it was looping.
		if ([m[@"kind"] isEqualToString:@"messageAnimation"] && !cell.picture.hidden &&
			cell.disc.hidden) {
			cell.disc.hidden = NO;
			cell.disc.image = [TGIcons mediaDiscOfSide:kGifDisc playing:NO];
		}
		return;
	}
	// On Vintage the decoder and the scroll share the one core. A row that
	// appears during a drag must not start a player or a download; the scroll
	// stop picks the row at the centre and calls this again for that one only.
	if ([TGDevice tier] == TGDeviceTierVintage &&
		(self.table.isDragging || self.table.isDecelerating))
		return;
	NSNumber *docId = [m[@"docId"] isKindOfClass:NSNumber.class] ? m[@"docId"] : nil;
	if (!docId)
		return;

	NSString *path = self.gifPaths[docId];
	if (path){
		NSUInteger playing = 0;
		for (UITableViewCell *visible in self.table.visibleCells)
			if (visible != cell && [visible isKindOfClass:TGBubbleCell.class] &&
				((TGBubbleCell *)visible).isPlayingLoop)
				playing++;
		if (playing >= [TGCapabilities maxConcurrentGIFs])
			return;
		[cell playLoopingVideoAtPath:path];
		cell.disc.hidden = YES;
		return;
	}

	long long size = [m[@"docSize"] longLongValue];
	if ([self.gifsRequested containsObject:docId] || size <= 0 || size > kGifAutoDownloadLimit)
		return;
	[self.gifsRequested addObject:docId];
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] downloadFile:docId.integerValue completion:^(NSString *downloaded){
		TGChatViewController *me = weakSelf;
		if (!me || !downloaded.length)
			return;
		me.gifPaths[docId] = downloaded;
		[me reloadTableDebounced];
	}];
}

@end
