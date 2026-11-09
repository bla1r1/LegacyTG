#import "TGBubbleBackImage.h"
#import "TGPerf.h"
#import "TGLocalization.h"
#import "TGChatViewControllerInternal.h"
#import "TGMessageCellFactory.h"
#import "TGNameWithStatus.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "TGCapabilities.h"
#import "TGStyle.h"
#import "TGMusicPlayer.h"
#import "TGMessageAudienceViewController.h"
#import "TGCustomEmojiStore.h"
#import "TGStickerBudget.h"
#import "TGDevice.h"

@implementation TGChatViewController (Cells)

/// Documents, voice notes, polls, cards and locations place their stamp with
/// TGPlaceStamp, which leaves room for the eye only when it is showing; the
/// text path shows it itself. A channel post of any of those kinds turns the
/// eye on here and places the stamp again so the count and the eye line up.
- (void)placeViewsEyeIn:(TGBubbleCell *)cell message:(NSDictionary *)m
				 layout:(TGMessageLayout *)layout mine:(BOOL)mine {
	if (layout.isService || !cell.viewsEye.hidden || !cell.time.text.length || cell.time.hidden)
		return;
	if ([m[@"viewCount"] longLongValue] <= 0)
		return;
	TGTheme *theme = [TGTheme shared];
	cell.viewsEye.image = [TGIcons glyphNamed:@"eye"
									  colour:(mine ? [theme timeMineColour] : [theme timeColour])
										side:kStampEyeSide];
	cell.viewsEye.hidden = NO;
	TGPlaceStamp(cell, layout.bubbleFrame, layout.timeWidth, mine);
	if (mine)
		TGPlaceTicks(cell, layout.bubbleFrame);
	[cell.bubble bringSubviewToFront:cell.viewsEye];
}

static const NSUInteger kMaxCustomEmojiPerBubble = 3;
static char kTGReactionChipInfoKey;

#pragma mark - table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *m = self.messages[indexPath.row];
	BOOL mine = [m[@"outgoing"] boolValue];
	// One row has a sixtieth of a second if the scroll is to hold 60 fps, and
	// a thirtieth before it is visibly jerky on an A4. Anything over that
	// names itself and its kind in the log; under it this costs one
	// mach_absolute_time.
	double cellStart = TGPerfNow();
	TGMessageLayout *layout = [self layoutForMessage:m atRow:indexPath.row];

	// The shared factory owns the elements: bubble, service plate, day header
	// and unread band. It resets a reused cell and places the base from the
	// cached layout; a service element is complete and returns here.
	TGMessageCellKind kind = TGMessageCellKindForMessage(m, layout);
	// A service line names the sender and, for a pin, quotes the message;
	// both can resolve after the plate was measured. Refresh the words here,
	// as the old in-screen service branch did, without re-measuring frames.
	if (layout.isService && !layout.isUnreadSeparator)
		layout.serviceText = [self serviceLineForMessage:m];
	UITableViewCell *ready = [TGMessageCellFactory cellForTableView:tableView
															 message:m
															  layout:layout];
	if (kind != TGMessageCellKindBubble) {
		TGPerfReport("cell", [m[@"kind"] UTF8String], cellStart, 33.0);
		return ready;
	}
	TGBubbleCell *cell = (TGBubbleCell *)ready;

	// A row that is not the standard bubble path (service, audio, round note)
	// still inherits the previous message's chips unless they are hidden
	// before the branch returns.
	UIView *reactionChips = [cell.contentView viewWithTag:0x9005];
	reactionChips.hidden = YES;
	UIImageView *senderStatus = (UIImageView *)[cell.bubble viewWithTag:0x9006];
	senderStatus.hidden = YES;

	// 1. Who wrote it. This runs before the service and audio branches
	// return: the layout indents the bubble by the avatar column and keeps a
	// line for the name whether or not the branch draws one, so a track or a
	// voice note skipping it looked shifted under an empty strip.
	int64_t senderId = [m[@"senderId"] longLongValue];
	if (layout.senderName.length) {
		cell.senderAvatar.hidden = NO;
		cell.senderAvatar.image = [TGIcons roundedImage:[self avatarForUser:senderId name:layout.senderName]
												   size:layout.senderAvatarFrame.size
												 radius:TGHalf(layout.senderAvatarFrame.size.width)
												corners:UIRectCornerAllCorners];
		cell.senderAvatar.frame = layout.senderAvatarFrame;

		cell.sender.hidden = NO;
		int64_t statusId = [[TGClient shared] emojiStatusIdForUser:senderId];
		cell.sender.attributedText = TGNameWithStatus(layout.senderName, statusId, cell.sender.font, TGSenderColour(senderId));
		cell.sender.frame = layout.senderFrame;
	}

	// 2. Card-like bubbles (polls, checklists, documents, contacts, locations).
	// Pure service events, day headers and the unread band never reach here:
	// the factory returned their element already.
	if ([self configureServiceCell:cell message:m layout:layout isMine:mine indexPath:indexPath]) {
		[self placeViewsEyeIn:cell message:m layout:layout mine:mine];
		UITableViewCell *done = [self finalizeCell:cell message:m layout:layout isMine:mine];
		TGPerfReport("cell", [m[@"kind"] UTF8String], cellStart, 33.0);
		return done;
	}

	// 3. Audio cells (calls, audio tracks, voice notes)
	if ([self configureAudioCell:cell message:m layout:layout isMine:mine indexPath:indexPath]) {
		[self placeViewsEyeIn:cell message:m layout:layout mine:mine];
		UITableViewCell *done = [self finalizeCell:cell message:m layout:layout isMine:mine];
		TGPerfReport("cell", [m[@"kind"] UTF8String], cellStart, 33.0);
		return done;
	}

	TGTheme *theme = [TGTheme shared];
	UIColor *bodyColor = mine ? [theme bubbleMineTextColour] : [theme bubbleTheirsTextColour];

	// 4. Round video notes or animated stickers
	if ([self configureRoundOrStickerCell:cell message:m layout:layout isMine:mine]) {
		UITableViewCell *done = [self finalizeCell:cell message:m layout:layout isMine:mine];
		TGPerfReport("cell", [m[@"kind"] UTF8String], cellStart, 33.0);
		return done;
	}

	// 5. Quote headers & replies
	cell.quoteBar.hidden = YES;
	cell.quote.hidden = YES;
	cell.quoteAuthor.hidden = YES;

	[self layoutForwardIn:cell message:m width:layout.bubbleFrame.size.width];

	if (layout.quoteText) {
		cell.quoteBar.hidden = NO;
		cell.quoteBar.backgroundColor = [theme accentColour];
		cell.quoteBar.frame = layout.quoteBarFrame;

		cell.quoteAuthor.hidden = NO;
		cell.quoteAuthor.font = TGFontCaptionStrong();
		cell.quoteAuthor.textColor = [theme accentColour];
		NSString *qAuthor = layout.quoteAuthor ?: TGLocalized(@"Reply");
		int64_t authorStatusId = [self quoteAuthorStatusIdFor:m];
		cell.quoteAuthor.attributedText = TGNameWithStatus(qAuthor, authorStatusId, cell.quoteAuthor.font, [theme accentColour]);
		cell.quoteAuthor.frame = layout.quoteAuthorFrame;

		cell.quote.hidden = NO;
		cell.quote.numberOfLines = 1;
		cell.quote.font = TGFontCaption();
		cell.quote.textColor = bodyColor;
		if (layout.quoteEntities.count) {
			cell.quote.attributedText = TGAttributedMessageText(layout.quoteText, layout.quoteEntities, cell.quote.font, cell.quote.textColor);
		} else {
			cell.quote.text = layout.quoteText;
		}
		cell.quote.frame = layout.quoteFrame;

		NSNumber *replyId = [m[@"replyId"] isKindOfClass:NSNumber.class]
				? m[@"replyId"] : nil;
		__weak typeof(self) weakCells = self;
		cell.onQuoteTapped = replyId ? ^{
			[weakCells jumpToReplyById:replyId.longLongValue];
		} : nil;
	}

	cell.mediaStamp.hidden = YES;

	// 6. Media thumbnails & photo albums
	[self configureMediaForCell:cell message:m layout:layout isMine:mine];

	// 7. Message body text
	cell.body.hidden = (layout.bodySize.height == 0 || layout.isSticker);
	cell.body.numberOfLines = 0;
	cell.body.lineBreakMode = NSLineBreakByWordWrapping;
	cell.body.font = TGFontAtSize([TGTheme shared].messageFontSize);
	NSArray *entities = m[@"entities"];
	if (entities.count) {
		cell.body.attributedText = TGAttributedMessageTextRevealing(m[@"text"], entities, TGFontAtSize([TGTheme shared].messageFontSize), bodyColor, [self.revealedSpoilers containsObject:m[@"id"] ?: @0]);
	} else {
		TGSetBodyText(cell.body, m[@"text"], bodyColor);
	}
	cell.body.frame = layout.bodyFrame;
	[self configureCustomEmojiInCell:cell message:m layout:layout];

	// 7b. Link preview block
	if (!CGRectIsEmpty(layout.linkPreviewFrame)) {
		cell.linkPreviewBar.hidden = NO;
		cell.linkPreviewBar.backgroundColor = [theme accentColour];
		cell.linkPreviewBar.frame = layout.linkBarFrame;

		if (layout.linkSite.length) {
			cell.linkPreviewSite.hidden = NO;
			cell.linkPreviewSite.textColor = [theme accentColour];
			cell.linkPreviewSite.text = layout.linkSite;
			cell.linkPreviewSite.frame = layout.linkSiteFrame;
		}

		if (layout.linkTitle.length) {
			cell.linkPreviewTitle.hidden = NO;
			cell.linkPreviewTitle.textColor = [theme primaryTextColour];
			cell.linkPreviewTitle.text = layout.linkTitle;
			cell.linkPreviewTitle.frame = layout.linkTitleFrame;
		}

		if (layout.linkDesc.length) {
			cell.linkPreviewDesc.hidden = NO;
			cell.linkPreviewDesc.textColor = [theme secondaryTextColour];
			cell.linkPreviewDesc.text = layout.linkDesc;
			cell.linkPreviewDesc.frame = layout.linkDescFrame;
		}

		cell.linkPreviewButton.hidden = NO;
		cell.linkPreviewButton.frame = layout.linkPreviewFrame;
		cell.linkPreviewUrl = layout.linkUrl;
	}

	__weak typeof(self) weakSelf = self;
	cell.onLinkTapped = ^(NSString *url) {
		[weakSelf handleOpenLink:url];
	};

	// 8. Reactions: pills under the bubble, one per group. A group with a
	// single named reactor shows that person's face beside the emoji, which
	// is what makes "who reacted" answerable without opening anything.
	[self configureReactionChipsForCell:cell message:m layout:layout];

	// 8b. Comments, under a channel post that has a discussion group
	UIButton *comments = (UIButton *)[cell.bubble viewWithTag:0x9003];
	if ([m[@"canComment"] boolValue]) {
		if (!comments) {
			comments = [UIButton buttonWithType:UIButtonTypeCustom];
			comments.tag = 0x9003;
			comments.titleLabel.font = TGFontCaptionStrong();
			comments.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
			[comments addTarget:self action:@selector(commentsTapped:)
			   forControlEvents:UIControlEventTouchUpInside];
			// The arrow sits at the bubble's right edge, apart from the
			// count (ChatMessageCommentFooterContentNode).
			UILabel *arrow = [[UILabel alloc] init];
			arrow.tag = 0x9005;
			arrow.text = @"\u203A";
			arrow.font = TGFontCaptionStrong();
			arrow.textAlignment = NSTextAlignmentRight;
			arrow.backgroundColor = [UIColor clearColor];
			arrow.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
					UIViewAutoresizingFlexibleHeight;
			[comments addSubview:arrow];
			[cell.bubble addSubview:comments];
		}
		NSInteger count = [m[@"replyCount"] integerValue];
		NSString *label = nil;
		if (count <= 0)
			label = TGLocalized(@"Leave a Comment");
		else {
			label = TGLocalizedFormat(@"[%@]Comments", @(count));
			label = [label stringByReplacingOccurrencesOfString:@"[" withString:@""];
			label = [label stringByReplacingOccurrencesOfString:@"]" withString:@""];
		}
		comments.hidden = NO;
		[comments setTitle:label forState:UIControlStateNormal];
		[comments setImage:[TGIcons glyphNamed:@"chat"
									   colour:[theme accentColour]
										 side:TGMetricLineCaption]
				  forState:UIControlStateNormal];
		comments.titleEdgeInsets = UIEdgeInsetsMake(0, TGMetricPadSmall, 0, 0);
		[comments setTitleColor:[theme accentColour] forState:UIControlStateNormal];
		CGFloat below = layout.bodyFrame.origin.y + layout.bodySize.height + TGMetricPadTiny;
		comments.frame = CGRectMake(kPadH, below,
				layout.bubbleFrame.size.width - TGDoubled(kPadH), TGMetricLineCaption);
		UILabel *arrow = (UILabel *)[comments viewWithTag:0x9005];
		arrow.textColor = [theme accentColour];
		arrow.frame = CGRectMake(comments.bounds.size.width - TGMetricLineCaption, 0,
				TGMetricLineCaption, comments.bounds.size.height);
	} else {
		comments.hidden = YES;
	}

	// 8c. A bot's inline buttons, rebuilt per message: they are rare enough
	// that keeping a pool of them per cell is not worth its bookkeeping.
	UIView *keys = [cell.bubble viewWithTag:0x9004];
	NSArray *rows = m[@"inlineRows"];
	if (rows.count) {
		if (!keys) {
			keys = [[UIView alloc] init];
			keys.tag = 0x9004;
			[cell.bubble addSubview:keys];
		}
		for (UIView *old in [keys.subviews copy])
			[old removeFromSuperview];
		CGFloat top = layout.bodyFrame.origin.y + layout.bodySize.height + TGMetricBotButtonGap
				+ ([m[@"canComment"] boolValue] ? TGMetricLineBody : 0);
		CGFloat width = layout.bubbleFrame.size.width - TGDoubled(kPadH);
		keys.frame = CGRectMake(kPadH, top, width,
				rows.count * (TGMetricBotButtonHeight + TGMetricBotButtonGap));
		for (NSUInteger r = 0; r < rows.count; r++) {
			NSArray *row = rows[r];
			CGFloat w = (width - TGMetricBotButtonGap * (row.count - 1)) / row.count;
			for (NSUInteger c = 0; c < row.count; c++) {
				NSDictionary *b = row[c];
				UIButton *key = [UIButton buttonWithType:UIButtonTypeCustom];
				key.frame = CGRectMake(c * (w + TGMetricBotButtonGap),
						r * (TGMetricBotButtonHeight + TGMetricBotButtonGap), w, TGMetricBotButtonHeight);
				key.tag = (NSInteger)(r * 16 + c);
				key.backgroundColor = [theme cardBackgroundColour];
				key.layer.cornerRadius = TGMetricCornerSmall;
				key.layer.borderWidth = TGMetricBorderWidth;
				key.layer.borderColor = [theme separatorColour].CGColor;
				key.titleLabel.font = TGFontCaptionStrong();
				key.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
				BOOL works = ![b[@"kind"] isEqualToString:@"unsupported"];
				[key setTitle:b[@"text"] forState:UIControlStateNormal];
				[key setTitleColor:(works ? [theme accentColour] : [theme secondaryTextColour])
						  forState:UIControlStateNormal];
				[key addTarget:self action:@selector(botButtonTapped:)
			  forControlEvents:UIControlEventTouchUpInside];
				[keys addSubview:key];
			}
		}
		keys.hidden = NO;
	} else {
		keys.hidden = YES;
	}

	// 9. Time & delivery ticks
	BOOL onPicture = !cell.mediaStamp.hidden;
	int64_t viewCount = 0;
	id rawViews = m[@"viewCount"];
	if ([rawViews respondsToSelector:@selector(longLongValue)]) {
		viewCount = [rawViews longLongValue];
	}
	if (viewCount > 0 && !onPicture && ![self albumContinuesAfterRow:indexPath.row]) {
		cell.viewsEye.hidden = NO;
		UIColor *eyeCol = mine ? [theme timeMineColour] : [theme timeColour];
		cell.viewsEye.image = [TGIcons glyphNamed:@"eye" colour:eyeCol side:kStampEyeSide];
		// The layout reserved the eye's room at the stamp's start; left of it
		// is the last line of text.
		CGFloat eyeX = layout.timeFrame.origin.x;
		CGFloat eyeY = layout.timeFrame.origin.y + TGCenteredOrigin(TGMetricStampHeight, kStampEyeSide);
		cell.viewsEye.frame = CGRectMake(eyeX, eyeY, kStampEyeSide, kStampEyeSide);
		[cell.bubble bringSubviewToFront:cell.viewsEye];
	} else if (viewCount > 0 && onPicture) {
		cell.viewsEye.hidden = NO;
		cell.viewsEye.image = [TGIcons glyphNamed:@"eye" colour:[theme onMediaColour] side:kStampEyeSide];
		CGFloat eyeX = layout.mediaStampFrame.origin.x + TGMetricPadSmall;
		CGFloat eyeY = layout.mediaStampFrame.origin.y + TGCenteredOrigin(layout.mediaStampFrame.size.height, kStampEyeSide);
		cell.viewsEye.frame = CGRectMake(eyeX, eyeY, kStampEyeSide, kStampEyeSide);
		[cell.bubble bringSubviewToFront:cell.viewsEye];
	} else {
		cell.viewsEye.hidden = YES;
	}

	cell.time.text = (onPicture || [self albumContinuesAfterRow:indexPath.row]) ? @"" : layout.stamp;
	cell.time.textColor = mine ? [theme timeMineColour] : [theme timeColour];
	cell.time.frame = layout.timeFrame;
	if (!cell.viewsEye.hidden && !onPicture) {
		CGRect timeFrame = layout.timeFrame;
		timeFrame.origin.x += kStampEyeSide + kStampEyePad;
		timeFrame.size.width -= kStampEyeSide + kStampEyePad;
		cell.time.frame = timeFrame;
	}

	cell.ticks.hidden = !mine;
	if (mine && onPicture) {
		cell.ticks.image = [self ticksForMessage:m white:YES];
		cell.ticks.frame = CGRectMake(CGRectGetMaxX(cell.mediaStamp.frame) - TGMetricMediaStampCheckPhotoInset,
									  CGRectGetMidY(cell.mediaStamp.frame) - TGHalf(TGMetricTicksHeight),
									  TGMetricTicksWidth, TGMetricTicksHeight);
		[cell.bubble bringSubviewToFront:cell.ticks];
	} else if (mine) {
		cell.ticks.image = [self ticksForMessage:m white:NO];
		cell.ticks.frame = CGRectMake(layout.bubbleFrame.size.width - kPadH - TGMetricTicksWidth,
				layout.timeFrame.origin.y + TGCenteredOrigin(TGMetricStampHeight, TGMetricTicksHeight),
				TGMetricTicksWidth, TGMetricTicksHeight);
		[cell.bubble bringSubviewToFront:cell.ticks];
	}
	[cell.bubble bringSubviewToFront:cell.time];

	// 10. Text shadows on the printed plate; service/sticker/round rows sit
	// shell-flat and cast nothing.
	if (!layout.isService && !layout.isSticker && !layout.isRound) {
		cell.shineBar.hidden = YES;
		cell.shineGradientLayer.hidden = YES;
		UIColor *bodyColor = mine ? [theme bubbleMineTextColour] : [theme bubbleTheirsTextColour];
		cell.body.textColor = bodyColor;
		cell.body.shadowColor = [theme etchedTextShadowColour];
		cell.body.shadowOffset = TGMetricShadowOffsetEtched;
		cell.time.textColor = mine ? [theme timeMineColour] : [theme timeColour];
		cell.time.shadowColor = [theme etchedTextShadowColour];
		cell.time.shadowOffset = TGMetricShadowOffsetEtched;
	} else {
		cell.shineBar.hidden = YES;
		cell.shineGradientLayer.hidden = YES;
		cell.body.shadowColor = nil;
		cell.body.shadowOffset = CGSizeZero;
		cell.time.shadowColor = nil;
		cell.time.shadowOffset = CGSizeZero;
	}

	UITableViewCell *done = [self finalizeCell:cell message:m layout:layout isMine:mine];
	TGPerfReport("cell", [m[@"kind"] UTF8String], cellStart, 33.0);
	return done;
}

/// The row's message, found from the button's place in the table.
- (void)commentsTapped:(UIButton *)button {
	CGPoint at = [button convertPoint:CGPointZero toView:self.table];
	NSIndexPath *path = [self.table indexPathForRowAtPoint:at];
	if (path && path.row < (NSInteger)self.messages.count)
		[self openCommentsForMessage:self.messages[path.row]];
}

#pragma mark - ticks

- (UIImage *)ticksForMessage:(NSDictionary *)m white:(BOOL)white {
	// Until Telegram has the message there is nothing to tick: their clients
	// put a clock in the same place, on notes and voice alike.
	if ([m[@"sending"] boolValue])
		return [TGIcons clockTicksWhite:white];
	NSString *state = m[@"state"];
	if ([state isEqualToString:@"read"]) {
		return white ? [TGIcons ticksWhite:YES] : [TGIcons ticksColour:[[TGTheme shared] ticksColour] read:YES];
	}
	return white ? [TGIcons ticksWhite:NO] : [TGIcons ticksColour:[[TGTheme shared] ticksColour] read:NO];
}

- (void)configureCustomEmojiInCell:(TGBubbleCell *)cell message:(NSDictionary *)m layout:(TGMessageLayout *)layout {
	if (![TGCapabilities canPlayAnimatedStickers] || ![TGCapabilities animatedStickersWanted]) {
		[cell stopCustomEmojiAnimations];
		return;
	}
	if (cell.body.hidden || !cell.body.attributedText.length) {
		[cell stopCustomEmojiAnimations];
		return;
	}

	TGStickerBudget budget = TGStickerBudgetForMemory([TGCapabilities memoryMB]);
	if (budget.frameCap <= 0) {
		[cell stopCustomEmojiAnimations];
		return;
	}

	NSArray *emojiRects = TGCustomEmojiRectsInText(cell.body.attributedText, layout.bodyFrame.size.width);
	if (!emojiRects.count) {
		[cell stopCustomEmojiAnimations];
		return;
	}

	// On single-core hardware the decode must not contend with the drag.
	BOOL scrollSettled = [TGDevice tier] != TGDeviceTierVintage ||
			!(self.table.isDragging || self.table.isDecelerating);

	NSUInteger maxEmoji = MIN(kMaxCustomEmojiPerBubble, emojiRects.count);
	NSUInteger activeCount = 0;

	for (NSUInteger i = 0; i < maxEmoji; i++) {
		NSDictionary *entry = emojiRects[i];
		int64_t emojiId = [entry[@"id"] longLongValue];
		NSValue *rectVal = entry[@"rect"];
		if (![rectVal isKindOfClass:NSValue.class])
			continue;
		CGRect rect = CGRectZero;
		[rectVal getValue:&rect];
		if (CGRectIsEmpty(rect))
			continue;

		NSDictionary *anim = [[TGCustomEmojiStore shared] animationForId:emojiId];
		if (!anim) {
			// Static WebP or still resolving: the inline glyph underneath serves as fallback.
			continue;
		}

		NSNumber *fileId = anim[@"fileId"];
		if (![fileId isKindOfClass:NSNumber.class] || fileId.longLongValue <= 0)
			continue;

		NSString *animPath = self.lottiePaths[fileId];
		if (!animPath.length) {
			if (![self.imagesRequested containsObject:fileId]) {
				[self.imagesRequested addObject:fileId];
				__weak typeof(self) weakSelf = self;
				[[TGClient shared] downloadFile:fileId.integerValue
									   priority:TGDownloadPriorityOnScreen
									 completion:^(NSString *path) {
					TGChatViewController *me = weakSelf;
					if (!me) return;
					if (path) me.lottiePaths[fileId] = path;
					[me.imagesRequested removeObject:fileId];
					[me reloadTableDebounced];
				}];
			}
			continue;
		}

		TGLottieView *view = [cell customEmojiViewAtIndex:activeCount];
		view.frame = rect;
		__weak typeof(self) weakSelf = self;
		view.onStickerReady = ^{ [weakSelf reloadTableDebounced]; };
		BOOL playable = [view loadStickerFile:animPath];
		view.hidden = !playable;
		if (playable && scrollSettled) {
			[view play];
		}
		activeCount++;
	}

	[cell hideCustomEmojiViewsFromIndex:activeCount];
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)tableCell forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (![tableCell isKindOfClass:TGBubbleCell.class]) return;
	TGBubbleCell *cell = (TGBubbleCell *)tableCell;
	[cell stopLoopingVideo];
	[cell stopCustomEmojiAnimations];
}

#pragma mark - runs

static BOOL TGSameRun(NSDictionary *a, NSDictionary *b) {
	if (!a || !b)
		return NO;
	if ([a[@"service"] boolValue] || [b[@"service"] boolValue])
		return NO;
	if ([a[@"outgoing"] boolValue] != [b[@"outgoing"] boolValue])
		return NO;
	if ([a[@"senderId"] longLongValue] != [b[@"senderId"] longLongValue])
		return NO;
	return fabs([a[@"date"] doubleValue] - [b[@"date"] doubleValue]) < 300;
}

- (BOOL)runStartsAtRow:(NSInteger)row {
	if (row <= 0 || row >= (NSInteger)self.messages.count)
		return YES;
	return !TGSameRun(self.messages[row - 1], self.messages[row]);
}

- (BOOL)runEndsAtRow:(NSInteger)row {
	if (row < 0 || row + 1 >= (NSInteger)self.messages.count)
		return YES;
	return !TGSameRun(self.messages[row], self.messages[row + 1]);
}

- (CGFloat)runShiftAtRow:(NSInteger)row layout:(TGMessageLayout *)layout {
	if (layout.isService || fabs(layout.bubbleFrame.origin.y - TGMetricBubbleRowInset) > TGMetricEpsilon)
		return TGMetricZero;
	return ([self runStartsAtRow:row] ? TGMetricBubbleRunGapStart : TGMetricBubbleRunGapInner) - TGMetricBubbleRowInset;
}

- (CGFloat)runHeightChangeAtRow:(NSInteger)row layout:(TGMessageLayout *)layout {
	if (layout.isService || fabs(layout.bubbleFrame.origin.y - TGMetricBubbleRowInset) > TGMetricEpsilon)
		return TGMetricZero;
	CGFloat above = [self runStartsAtRow:row] ? TGMetricBubbleRunGapStart : TGMetricBubbleRunGapInner;
	CGFloat below = [self runEndsAtRow:row] ? TGMetricBubbleRunGapStart : TGMetricBubbleRunGapInner;
	return (above - TGMetricBubbleRowInset) + (below - TGMetricBubbleRowInset);
}

static const CGFloat kTailCurveSpan   = 12.0f;
static const CGFloat kTailCurveAnchor = 5.0f;
static const CGFloat kTailCurveLift   = 2.0f;
static const CGFloat kTailCurveWaist  = 6.0f;
static const CGFloat kTailCurveInBow  = 2.4f;
static const CGFloat kTailCurveOutBow = 3.6f;

static UIBezierPath *TGBubbleUnifiedPath(CGSize size, CGFloat tl, CGFloat tr, CGFloat br, CGFloat bl, BOOL hasTail, BOOL mine) {
	CGFloat cap = TGHalf(MIN(size.width, size.height));
	tl = MIN(tl, cap); tr = MIN(tr, cap); br = MIN(br, cap); bl = MIN(bl, cap);
	CGFloat w = size.width, h = size.height;
	CGFloat tw = kTailWidth;

	UIBezierPath *path = [UIBezierPath bezierPath];
	if (!hasTail) {
		[path moveToPoint:CGPointMake(tl, 0)];
		[path addLineToPoint:CGPointMake(w - tr, 0)];
		[path addArcWithCenter:CGPointMake(w - tr, tr) radius:tr startAngle:-M_PI_2 endAngle:0 clockwise:YES];
		[path addLineToPoint:CGPointMake(w, h - br)];
		[path addArcWithCenter:CGPointMake(w - br, h - br) radius:br startAngle:0 endAngle:M_PI_2 clockwise:YES];
		[path addLineToPoint:CGPointMake(bl, h)];
		[path addArcWithCenter:CGPointMake(bl, h - bl) radius:bl startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
		[path addLineToPoint:CGPointMake(0, tl)];
		[path addArcWithCenter:CGPointMake(tl, tl) radius:tl startAngle:M_PI endAngle:M_PI * 1.5 clockwise:YES];
		[path closePath];
		return path;
	}

	if (!mine) {
		CGFloat W = w + tw;
		[path moveToPoint:CGPointMake(tw + tl, 0)];
		[path addLineToPoint:CGPointMake(W - tr, 0)];
		[path addArcWithCenter:CGPointMake(W - tr, tr) radius:tr startAngle:-M_PI_2 endAngle:0 clockwise:YES];
		[path addLineToPoint:CGPointMake(W, h - br)];
		[path addArcWithCenter:CGPointMake(W - br, h - br) radius:br startAngle:0 endAngle:M_PI_2 clockwise:YES];
		[path addLineToPoint:CGPointMake(tw + kTailCurveSpan, h)];

		[path addCurveToPoint:CGPointMake(TGMetricZero, h)
				controlPoint1:CGPointMake(tw + kTailCurveAnchor, h)
				controlPoint2:CGPointMake(tw - kTailCurveOutBow, h - kTailCurveLift)];
		[path addCurveToPoint:CGPointMake(tw, h - kTailHeight)
				controlPoint1:CGPointMake(tw - kTailCurveInBow, h - kTailCurveWaist)
				controlPoint2:CGPointMake(tw, h - kTailHeight)];

		[path addLineToPoint:CGPointMake(tw, tl)];
		[path addArcWithCenter:CGPointMake(tw + tl, tl) radius:tl startAngle:M_PI endAngle:M_PI * 1.5 clockwise:YES];
		[path closePath];
	} else {
		[path moveToPoint:CGPointMake(tl, 0)];
		[path addLineToPoint:CGPointMake(w - tr, 0)];
		[path addArcWithCenter:CGPointMake(w - tr, tr) radius:tr startAngle:-M_PI_2 endAngle:0 clockwise:YES];
		[path addLineToPoint:CGPointMake(w, h - kTailHeight)];

		[path addCurveToPoint:CGPointMake(w + tw, h)
				controlPoint1:CGPointMake(w, h - kTailCurveWaist)
				controlPoint2:CGPointMake(w + kTailCurveOutBow, h - kTailCurveLift)];
		[path addCurveToPoint:CGPointMake(w - kTailCurveSpan, h)
				controlPoint1:CGPointMake(w, h)
				controlPoint2:CGPointMake(w - kTailCurveAnchor, h)];

		[path addLineToPoint:CGPointMake(bl, h)];
		[path addArcWithCenter:CGPointMake(bl, h - bl) radius:bl startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
		[path addLineToPoint:CGPointMake(0, tl)];
		[path addArcWithCenter:CGPointMake(tl, tl) radius:tl startAngle:M_PI endAngle:M_PI * 1.5 clockwise:YES];
		[path closePath];
	}
	return path;
}

/// Room the gradient keeps between the caps. The middle is scaled, not
/// tiled, so the gradient runs top to bottom of any bubble without a seam.
static const CGFloat kBubbleBackMiddle = 24.0f;

/// The corner radii one bubble of a run gets: a run's first bubble rounds its
/// top fully, the last one carries the tail on the sender's side.
static void TGBubbleCorners(TGTheme *theme, BOOL mine, BOOL first, BOOL last,
		CGFloat *tl, CGFloat *tr, CGFloat *br, CGFloat *bl) {
	CGFloat big = [theme bubbleCornerRadius];
	CGFloat small = [theme bubbleJoinedCornerRadius];
	CGFloat top = first ? big : small;
	*tl = mine ? big : top;
	*tr = mine ? top : big;
	*br = mine ? (last ? 0 : small) : big;
	*bl = mine ? big : (last ? 0 : small);
}

static UIImage *sBubbleCache[8];
static __weak TGTheme *sCachedTheme = nil;

void TGBubbleFlushCache(void) {
	for (int i = 0; i < 8; i++)
		sBubbleCache[i] = nil;
	sCachedTheme = nil;
}

/// Every bubble background there is - mine or theirs, first of a run or not,
/// tailed or not - is one of eight pictures, drawn once.
UIImage *TGBubbleBackImage(TGTheme *theme, BOOL mine, BOOL first, BOOL last) {
	if (sCachedTheme != theme) {
		for (int i = 0; i < 8; i++)
			sBubbleCache[i] = nil;
		sCachedTheme = theme;
	}
	unsigned slot = (mine ? 1u : 0u) | (first ? 2u : 0u) | (last ? 4u : 0u);
	if (sBubbleCache[slot])
		return sBubbleCache[slot];

	CGFloat tl, tr, br, bl;
	TGBubbleCorners(theme, mine, first, last, &tl, &tr, &br, &bl);
	CGFloat tw = last ? kTailWidth : 0;
	// Caps hold every curve; what is left between them is straight edge and
	// gradient, which is all a stretch may touch.
	CGFloat left = mine ? MAX(tl, bl) : tw + MAX(tl, last ? kTailCurveSpan : bl);
	CGFloat right = mine ? tw + MAX(tr, last ? kTailCurveSpan : br) : MAX(tr, br);
	CGFloat top = MAX(tl, tr);
	CGFloat bottom = MAX(MAX(bl, br), last ? kTailHeight : 0);
	CGSize ref = CGSizeMake(left + 1 + right, top + kBubbleBackMiddle + bottom);

	UIBezierPath *path = TGBubbleUnifiedPath(CGSizeMake(ref.width - tw, ref.height),
			tl, tr, br, bl, last, mine);
	NSArray *colours = mine ? [theme skeuoBubbleMineGradientColours]
							: [theme skeuoBubbleTheirsGradientColours];
	UIColor *edge = mine ? [theme skeuoBubbleMineBorderColour] : [theme skeuoBubbleTheirsBorderColour];

	UIGraphicsBeginImageContextWithOptions(ref, NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	[path addClip];
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colours, NULL);
	CGContextDrawLinearGradient(ctx, gradient, CGPointZero, CGPointMake(0, ref.height), 0);
	CGGradientRelease(gradient);
	CGColorSpaceRelease(space);
	// Stroked inside the clip, so only the inner half of the line shows -
	// exactly what the masked 1 pt shape layer drew.
	[edge setStroke];
	path.lineWidth = 1.0f;
	[path stroke];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	sBubbleCache[slot] = [image resizableImageWithCapInsets:UIEdgeInsetsMake(top, left, bottom, right)
										resizingMode:UIImageResizingModeStretch];
	return sBubbleCache[slot];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)tableCell forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (![tableCell isKindOfClass:TGBubbleCell.class] || indexPath.row >= (NSInteger)self.messages.count)
		return;
	TGBubbleCell *cell = (TGBubbleCell *)tableCell;
	cell.tail.hidden = YES;

	NSDictionary *m = self.messages[indexPath.row];
	TGMessageLayout *layout = [self layoutForMessage:m atRow:indexPath.row];
	[self startGifIfWantedIn:cell message:m];
	NSInteger row = indexPath.row;
	BOOL first = [self runStartsAtRow:row];
	BOOL last = [self runEndsAtRow:row];

	CGFloat shift = [self runShiftAtRow:row layout:layout];
	if (shift != 0) {
		CGRect b = cell.bubble.frame;
		b.origin.y = layout.bubbleFrame.origin.y + shift;
		cell.bubble.frame = b;
		if (!cell.senderAvatar.hidden) {
			CGRect a = cell.senderAvatar.frame;
			a.origin.y = layout.senderAvatarFrame.origin.y + shift;
			cell.senderAvatar.frame = a;
		}
		if (!cell.checkbox.hidden) {
			CGRect c = cell.checkbox.frame;
			c.origin.y = CGRectGetMidY(b) - TGHalf(c.size.height);
			cell.checkbox.frame = c;
		}
	}

	if (!last && !cell.senderAvatar.hidden)
		cell.senderAvatar.hidden = YES;

	TGTheme *theme = [TGTheme shared];
	UIColor *fill = cell.bubble.backgroundColor;
	BOOL plain = !fill || CGColorGetAlpha(fill.CGColor) < TGAlphaEpsilon;
	if (plain || layout.isService || layout.isSticker || layout.isRound) {
		[cell parkHiddenViews];
		return;
	}

	BOOL mine = [m[@"outgoing"] boolValue];
	CGSize size = cell.bubble.bounds.size;
	CGRect backFrame = cell.bubble.bounds;
	if (last) {
		backFrame = mine ? CGRectMake(0, 0, size.width + kTailWidth, size.height)
						 : CGRectMake(-kTailWidth, 0, size.width + kTailWidth, size.height);
	}

	cell.bubble.clipsToBounds = NO;
	cell.bubble.layer.cornerRadius = TGMetricCornerNone;
	cell.bubble.layer.borderWidth = 0;
	cell.bubble.layer.borderColor = [UIColor clearColor].CGColor;
	cell.bubble.backgroundColor = [UIColor clearColor];
	cell.bubbleBack.image = TGBubbleBackImage(theme, mine, first, last);
	cell.bubbleBack.frame = backFrame;
	cell.bubbleBack.hidden = NO;

	cell.shineBar.hidden = YES;
	cell.shineGradientLayer.hidden = YES;

	cell.tail.hidden = YES;

	[cell parkHiddenViews];
}

/// The chips under a bubble. One group per pill; a group with exactly one
/// named reactor carries that person's small round picture before the glyph,
/// and every other group says the emoji and the count. Pills sit side by side
/// and stop at the bubble's edge, which is one line in every chat Telegram
/// draws this way.
- (void)configureReactionChipsForCell:(TGBubbleCell *)cell
							  message:(NSDictionary *)m
							   layout:(TGMessageLayout *)layout {
	NSArray *groups = m[@"reactionGroups"];
	UIView *holder = [cell.contentView viewWithTag:0x9005];
	if (![groups isKindOfClass:NSArray.class] || !groups.count){
		holder.hidden = YES;
		return;
	}

	if (!holder){
		holder = [[UIView alloc] initWithFrame:CGRectZero];
		holder.tag = 0x9005;
		holder.backgroundColor = [UIColor clearColor];
		[cell.contentView addSubview:holder];
	}
	holder.hidden = NO;
	holder.frame = layout.reactionChipsFrame;
	for (UIView *old in [holder.subviews copy])
		[old removeFromSuperview];

	TGTheme *theme = [TGTheme shared];
	CGFloat maxW = holder.bounds.size.width;
	CGFloat x = TGMetricZero;
	for (NSDictionary *group in groups){
		NSString *emoji = group[@"emoji"];
		int64_t customEmojiId = [group[@"customEmojiId"] longLongValue];
		NSInteger count = [group[@"count"] integerValue];
		int64_t userId = [group[@"userId"] longLongValue];
		BOOL single = (count == 1 && userId > 0);

		BOOL isCustom = (customEmojiId != 0);
		CGFloat emojiSide = TGMetricReactionChipAvatar;
		UIImage *customEmojiImg = isCustom
				? [[TGCustomEmojiStore shared] imageForId:customEmojiId side:emojiSide] : nil;

		NSString *text = nil;
		CGFloat chipW = TGMetricZero;

		if (customEmojiImg) {
			text = single ? @"" : [NSString stringWithFormat:@"%ld", (long)count];
			chipW = TGDoubled(TGMetricReactionChipInset) + emojiSide;
			if (single)
				chipW += TGMetricReactionChipAvatar + TGMetricReactionChipGap;
			if (text.length)
				chipW += TGMetricReactionChipGap + TGTextSize(text, TGFontCaption(), 0).width;
		} else {
			NSString *glyph = emoji.length ? emoji : @"\u2605";
			text = single ? glyph
					: [NSString stringWithFormat:@"%@ %ld", glyph, (long)count];
			chipW = TGTextSize(text, TGFontCaption(), 0).width
					+ TGDoubled(TGMetricReactionChipInset);
			if (single)
				chipW += TGMetricReactionChipAvatar + TGMetricReactionChipGap;
		}

		chipW = MIN(chipW, maxW);
		if (x > TGMetricZero && x + chipW > maxW)
			break;

		BOOL chosen = [group[@"chosen"] boolValue];
		UIView *chip = [[UIView alloc] initWithFrame:CGRectMake(x, TGMetricZero,
				chipW, TGMetricReactionChipHeight)];
		chip.backgroundColor = chosen ? [theme reactionChipMineColour]
									  : [theme reactionChipColour];
		chip.layer.cornerRadius = TGHalf(TGMetricReactionChipHeight);
		chip.layer.borderWidth = TGMetricBorderWidth;
		chip.layer.borderColor = (chosen ? [theme reactionChipMineBorderColour]
										 : [theme reactionChipBorderColour]).CGColor;
		chip.userInteractionEnabled = YES;

		CGFloat textX = TGMetricReactionChipInset;
		if (single){
			UIImage *avatar = [self avatarForUser:userId name:group[@"name"]];
			CGFloat side = TGMetricReactionChipAvatar;
			UIImageView *face = [[UIImageView alloc] initWithFrame:CGRectMake(
					TGMetricReactionChipInset,
					TGCenteredOrigin(TGMetricReactionChipHeight, side), side, side)];
			face.image = [TGIcons roundedImage:avatar
										  size:CGSizeMake(side, side)
										radius:TGHalf(side)
									   corners:UIRectCornerAllCorners];
			face.contentMode = UIViewContentModeScaleAspectFill;
			[chip addSubview:face];
			textX += side + TGMetricReactionChipGap;
		}

		if (customEmojiImg) {
			UIImageView *emojiView = [[UIImageView alloc] initWithFrame:CGRectMake(
					textX, TGCenteredOrigin(TGMetricReactionChipHeight, emojiSide),
					emojiSide, emojiSide)];
			emojiView.image = customEmojiImg;
			emojiView.contentMode = UIViewContentModeScaleAspectFit;
			[chip addSubview:emojiView];
			textX += emojiSide;
			if (text.length)
				textX += TGMetricReactionChipGap;
		}

		if (text.length) {
			UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(textX,
					TGMetricZero, chipW - textX - TGMetricReactionChipInset,
					TGMetricReactionChipHeight)];
			label.font = TGFontCaption();
			label.text = text;
			label.textColor = [theme primaryTextColour];
			label.backgroundColor = [UIColor clearColor];
			[chip addSubview:label];
		}

		[chip addGestureRecognizer:[[UITapGestureRecognizer alloc]
				initWithTarget:self action:@selector(reactionChipTapped:)]];
		objc_setAssociatedObject(chip, &kTGReactionChipInfoKey, @{
			@"message"       : m,
			@"emoji"         : emoji ?: @"",
			@"customEmojiId" : group[@"customEmojiId"] ?: @(0),
		}, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		[holder addSubview:chip];
		x += chipW + TGMetricReactionChipGap;
	}
}

- (void)reactionChipTapped:(UITapGestureRecognizer *)tap {
	NSDictionary *info = objc_getAssociatedObject(tap.view, &kTGReactionChipInfoKey);
	if (!info)
		return;
	[self showReactorsOfMessage:info[@"message"]
						  emoji:info[@"emoji"]
				  customEmojiId:[info[@"customEmojiId"] longLongValue]];
}

@end
