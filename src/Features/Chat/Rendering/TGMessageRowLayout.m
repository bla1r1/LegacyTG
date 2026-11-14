#import "TGMessageRowLayout.h"
#import "TGMessageLayout.h"
#import "TGMessageMetrics.h"
#import "TGMessageCard.h"
#import "TGMessageCardView.h"
#import "TGStyle.h"

@implementation TGMessageRowInput
@end

/// The album's tile frames as the cell reads them back with -CGRectValue.
static NSValue *TGRectValue(CGRect rect) {
#if TARGET_OS_IPHONE
	return [NSValue valueWithCGRect:rect];
#else
	return [NSValue valueWithBytes:&rect objCType:@encode(CGRect)];
#endif
}

BOOL TGMessageIsLocation(NSDictionary *m) {
	NSString *kind = m[@"kind"];
	return [kind isEqualToString:@"messageLocation"] ||
			[kind isEqualToString:@"messageVenue"] ||
			[kind isEqualToString:@"messageLiveLocation"] ||
			(![m[@"lat"] isKindOfClass:NSNull.class] && [m[@"lat"] doubleValue] != 0);
}

BOOL TGMessageRowWantsCard(NSDictionary *m) {
	return ![m[@"service"] boolValue] ||
			[m[@"kind"] isEqualToString:@"messageChatAddedToCommunity"];
}

NSString *TGMessageSenderLine(NSString *name, NSDictionary *m) {
	NSString *tag = m[@"senderTag"];
	if (name.length && [tag isKindOfClass:NSString.class] && tag.length)
		return [NSString stringWithFormat:@"%@ · %@", name, tag];
	return name;
}

CGSize TGMessageBodySize(NSDictionary *m, CGFloat fontSize) {
	if ([m[@"kind"] isEqualToString:@"messageSticker"] || [m[@"kind"] isEqualToString:@"messageAnimatedEmoji"])
		return CGSizeZero;
	NSString *text = m[@"text"] ?: @"";
	if (!text.length)
		return CGSizeZero;
	return TGTextSizeWithEntities(text, m[@"entities"], TGFontAtSize(fontSize),
			kBubbleMaxW - TGDoubled(kPadH));
}

BOOL TGMessageStampOnPicture(NSDictionary *m, CGSize imageSize, CGFloat fontSize) {
	if ([m[@"captionAbove"] isKindOfClass:[NSNumber class]] && [m[@"captionAbove"] boolValue])
		return YES;
	if ([m[@"isAlbum"] boolValue] && TGMessageBodySize(m, fontSize).height == 0)
		return YES;
	return imageSize.height > 0 && TGMessageBodySize(m, fontSize).height == 0 &&
		   ![m[@"kind"] isEqualToString:@"messageVideoNote"];
}

/// Cards, polls and checklists from someone else in a group say who sent
/// them, like every other bubble: a name line on top, the avatar beside the
/// bubble's foot. Returns the bubble height with the name line in it.
static CGFloat TGPlaceGroupSender(TGMessageLayout *layout, NSString *senderName,
		CGFloat width, CGFloat height, CGFloat *x) {
	if (!senderName.length)
		return height;
	height += TGMetricSenderLineHeight;
	*x += kAvatarSide + TGMetricPadSmall + kTailWidth;
	layout.senderName = senderName;
	layout.senderFrame = CGRectMake(kPadH, kPadV, width - TGDoubled(kPadH), TGMetricLineMicro);
	layout.senderAvatarFrame = CGRectMake(TGMetricPad,
			MAX(TGMetricPadTiny, TGMetricBubbleRowInset + height - kAvatarSide), kAvatarSide, kAvatarSide);
	return height;
}

TGMessageLayout *TGMessageRowLayout(TGMessageRowInput *in) {
	NSDictionary *m = in.message;
	TGMessageLayout *layout = [[TGMessageLayout alloc] init];
	layout.runStart = in.runStart;
	layout.runEnd = in.runEnd;
	CGFloat tableW = in.tableWidth;
	if (tableW <= 0) tableW = TGMetricScreenWidth;

	BOOL mine = [m[@"outgoing"] boolValue];
	layout.mine = mine;
	NSString *kind = m[@"kind"];
	BOOL isSticker = [kind isEqualToString:@"messageSticker"] || [kind isEqualToString:@"messageAnimatedEmoji"];
	// A dice that came with its sticker draws like one: the thumbnail has no
	// bubble fill, border or caption while the animation file arrives. A dice
	// without a sticker keeps its value text.
	if ([kind isEqualToString:@"messageDice"] &&
		([m[@"docName"] length] || [m[@"photoId"] isKindOfClass:NSNumber.class]))
		isSticker = YES;
	BOOL isVoice = [kind isEqualToString:@"messageVoiceNote"];
	BOOL isRound = [kind isEqualToString:@"messageVideoNote"];
	BOOL isService = [m[@"service"] boolValue];
	BOOL isPoll = [kind isEqualToString:@"messagePoll"];
	BOOL isChecklist = [kind isEqualToString:@"messageChecklist"];
	// A track is a document with a title and a performer of its own. It was
	// drawn as the document it also is, which is why music looked like a file.
	BOOL isTrack = [kind isEqualToString:@"messageAudio"];
	BOOL isCall = [kind isEqualToString:@"messageCall"];
	BOOL isDoc = [kind isEqualToString:@"messageDocument"];
	BOOL isContact = [kind isEqualToString:@"messageContact"];
	BOOL isLocation = [kind isEqualToString:@"messageLocation"] ||
					  [kind isEqualToString:@"messageVenue"] ||
					  [kind isEqualToString:@"messageLiveLocation"] ||
					  (![m[@"lat"] isKindOfClass:NSNull.class] && [m[@"lat"] doubleValue] != 0);
	BOOL isAlbum = [m[@"isAlbum"] boolValue];

	layout.isService = isService;
	layout.isSticker = isSticker;
	layout.isVoice = isVoice;
	layout.isRound = isRound;
	layout.isPoll = isPoll;
	layout.isChecklist = isChecklist;
	BOOL isCommunityCard = [kind isEqualToString:@"messageChatAddedToCommunity"];
	(void)isCommunityCard;
	TGMessageCard *card = TGMessageRowWantsCard(m) ? in.card : nil;
	layout.isCard = card != nil;
	layout.isService = isService && !layout.isCard;
	layout.isTrack = isTrack;
	layout.isCall = isCall;
	layout.isDoc = isDoc;
	layout.isContact = isContact;
	layout.isLocation = isLocation;
	layout.isAlbum = isAlbum;

	CGFloat forwarded = [m[@"forward"] length] ? TGMetricQuoteForwardLine : TGMetricZero;
	layout.fwdHeight = forwarded;
	layout.stamp = TGMessageStampText(m);
	layout.timeWidth = TGMessageStampWidth(m);

	NSString *separator = m[@"separator"];
	if ([separator isEqualToString:@"unread"]) {
		// A full-width bar, not a plate: it marks a place, not an event.
		layout.isService = YES;
		layout.isUnreadSeparator = YES;
		layout.serviceText = [m[@"text"] isKindOfClass:NSString.class] ? m[@"text"] : @"";
		layout.bubbleFrame = CGRectMake(TGMetricZero, TGCenteredOrigin(kServiceRow, kUnreadBar),
				tableW, kUnreadBar);
		layout.bodyFrame = CGRectMake(TGMetricZero, TGCenteredOrigin(kUnreadBar, TGMetricLineBody),
				tableW, TGMetricLineBody);
		layout.rowHeight = kServiceRow;
		return layout;
	}

	if (isService && !layout.isCard) {
		NSString *line = TGMessageServiceLine(m, in.serviceWho, in.messages);
		layout.serviceText = line;
		layout.isDateHeader = separator != nil;
		UIFont *font = TGFontMeta();
		CGFloat textW = MIN(TGTextSize(line, font, 0).width,
				tableW - TGDoubled(kServicePlateMargin));
		CGFloat plateW = textW + TGDoubled(kServicePlatePad);
		// A day plate gets a little more air than an event in the chat.
		CGFloat top = separator ? kServiceGap : kServiceEventGap;
		layout.bubbleFrame = CGRectMake(TGCenteredOrigin(tableW, plateW), top, plateW, kServicePlate);
		layout.bodyFrame = CGRectMake(TGMetricZero, TGCenteredOrigin(kServicePlate, TGMetricLineSubhead),
				plateW, TGMetricLineSubhead);
		layout.rowHeight = separator ? kServiceRow : kServiceEventRow;
		return layout;
	}

	if (card) {
		CGFloat width = kBubbleMaxW;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		CGFloat cardH = TGMessageCardLayout(card, width - TGDoubled(kPadH)).size.height;
		CGFloat height = TGPlaceGroupSender(layout, in.senderName, width, kPadV + cardH + kPadV + kPollStampRoom, &x);
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		return layout;
	}

	if (isChecklist) {
		CGFloat width = kBubbleMaxW;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		CGFloat height = TGPlaceGroupSender(layout, in.senderName, width, TGMessageChecklistHeight(m), &x);
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		return layout;
	}

	if (isPoll) {
		CGFloat width = kBubbleMaxW;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		CGFloat height = TGPlaceGroupSender(layout, in.senderName, width, TGMessagePollHeight(m, in.pendingVotes), &x);
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		return layout;
	}

	if (isCall) {
		NSString *line = m[@"text"] ?: @"Call";
		CGFloat textW = TGTextSize(line, TGFontSubheadStrong(), 0).width;
		CGFloat width = MIN(kBubbleMaxW, textW + kCallBubbleRoom);
		width = MAX(kCallBubbleMin, width);
		CGFloat height = kCallBubble + forwarded;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		return layout;
	}

	if (isDoc) {
		CGFloat width = kDocBubble;
		NSUInteger docCount = 1;
		if (isAlbum && [m[@"albumMessages"] isKindOfClass:NSArray.class]) {
			docCount = [m[@"albumMessages"] count];
			if (docCount == 0) docCount = 1;
		}
		CGFloat docsH = docCount * kFileTile + (docCount > 1 ? (docCount - 1) * TGMetricPadSmall : 0);
		CGFloat height = docsH + TGDoubled(kPadV) + forwarded;

		NSString *caption = m[@"caption"];
		if (!caption.length && [m[@"text"] length]) {
			NSString *docName = m[@"docName"] ?: @"";
			NSString *text = m[@"text"];
			if (docName.length == 0 || ![text hasPrefix:docName]) {
				caption = text;
			}
		}

		CGSize capSize = CGSizeZero;
		if (caption.length) {
			capSize = TGTextSizeWithEntities(caption, m[@"entities"], TGFontBody(), width - TGDoubled(kPadH));
			height += capSize.height + TGMetricPadSmall;
		}
		height += TGMetricStampHeight;

		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		if (capSize.height > 0) {
			layout.bodyFrame = CGRectMake(kPadH, forwarded + kPadV + docsH + TGMetricPadSmall,
										  width - TGDoubled(kPadH), capSize.height);
		} else {
			layout.bodyFrame = CGRectZero;
		}
		CGFloat eyeRoom = 0;
		int64_t viewCount = [m[@"viewCount"] respondsToSelector:@selector(longLongValue)] ? [m[@"viewCount"] longLongValue] : 0;
		if (viewCount > 0) {
			eyeRoom = kStampEyeSide + kStampEyePad;
		}
		layout.timeFrame = CGRectMake(width - layout.timeWidth - kPadH + eyeRoom,
									  height - kPadV - TGMetricStampHeight,
									  layout.timeWidth - eyeRoom, TGMetricStampHeight);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		return layout;
	}

	if (isContact) {
		CGFloat width = kContactBubble;
		CGFloat height = kContactBubbleH + forwarded;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		return layout;
	}

	if (isLocation) {
		CGFloat width = kLocationBubble;
		CGFloat height = kLocationBubbleH + forwarded;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		return layout;
	}

	CGSize body = TGMessageBodySize(m, in.fontSize);
	CGSize pic  = in.imageSize;
	layout.bodySize = body;
	layout.picSize = pic;

	if (isRound) {
		CGFloat side = kRoundSide;
		layout.picSize = CGSizeMake(side, side);
		layout.bubbleFrame = CGRectMake(mine ? (tableW - side - TGMetricPad) : TGMetricPad,
				TGMetricBubbleRowInset, side, side);
		// The stamp line lives under the circle now: every other bubble
		// carries its clock under the message, and a round note hanging its
		// clock out to the side read as drifting off the row.
		layout.rowHeight = side + TGMetricStampHeight + TGMetricPadSmall
				+ TGDoubled(TGMetricBubbleRowInset);
		layout.stamp = TGMessageStampText(m);
		return layout;
	}

	BOOL isAnimatedFormat = [m[@"docName"] isEqualToString:@"tgs"] || [m[@"docName"] isEqualToString:@"webm"];
	if (isAnimatedFormat && in.animatedStickerReady) {
		CGFloat side = kLottieSide;
		layout.bubbleFrame = CGRectMake(mine ? (tableW - side - TGMetricPad) : TGMetricPad,
				TGMetricBubbleRowInset, side, side + TGMetricLineMicro);
		layout.rowHeight = side + TGMetricLineMicro + TGDoubled(TGMetricBubbleRowInset);
		return layout;
	}

	CGFloat collageW = TGMetricCollageWidth;
	CGFloat collageH = TGMetricZero;
	NSMutableArray *itemFrames = [NSMutableArray array];

	if (isAlbum) {
		NSArray *items = m[@"albumMessages"];
		NSUInteger count = items.count;
		CGFloat gap = TGMetricCollageGap;
		CGFloat halfW = TGHalf(collageW - gap);

		if (count <= 2) {
			collageH = TGMetricCollageHeightDual;
			[itemFrames addObject:TGRectValue(CGRectMake(0, 0, halfW, collageH))];
			[itemFrames addObject:TGRectValue(CGRectMake(halfW + gap, 0, halfW, collageH))];
		} else if (count == 3) {
			CGFloat topH = TGMetricCollageTopHeight;
			CGFloat botH = TGMetricCollageBottomHeight;
			collageH = topH + gap + botH;
			[itemFrames addObject:TGRectValue(CGRectMake(0, 0, collageW, topH))];
			[itemFrames addObject:TGRectValue(CGRectMake(0, topH + gap, halfW, botH))];
			[itemFrames addObject:TGRectValue(CGRectMake(halfW + gap, topH + gap, halfW, botH))];
		} else {
			CGFloat halfH = TGMetricCollageQuadHeight;
			collageH = TGDoubled(halfH) + gap;
			[itemFrames addObject:TGRectValue(CGRectMake(0, 0, halfW, halfH))];
			[itemFrames addObject:TGRectValue(CGRectMake(halfW + gap, 0, halfW, halfH))];
			[itemFrames addObject:TGRectValue(CGRectMake(0, halfH + gap, halfW, halfH))];
			[itemFrames addObject:TGRectValue(CGRectMake(halfW + gap, halfH + gap, halfW, halfH))];
		}
		layout.albumFrames = itemFrames;
	}

	NSString *senderName = TGMessageSenderLine(in.senderName, m);

	BOOL stampOnPicture = TGMessageStampOnPicture(m, in.imageSize, in.fontSize);
	BOOL inlineStamp = !stampOnPicture && TGMessageStampFitsInline(m, in.fontSize);
	NSString *lpSite = m[@"linkPreviewSite"];
	NSString *lpTitle = m[@"linkPreviewTitle"];
	NSString *lpDesc = m[@"linkPreviewDesc"];
	NSString *lpUrl = m[@"linkPreviewUrl"];
	BOOL hasLinkPreview = !isService && (lpTitle.length > 0 || lpDesc.length > 0 || lpSite.length > 0);
	if (hasLinkPreview) inlineStamp = NO;
	CGFloat timeW = TGMessageStampWidth(m);
	CGFloat contentW = MAX(body.width, pic.width);
	if (isAlbum)
		contentW = MAX(contentW, collageW);
	NSString *quoted = TGMessageQuoteText(m, in.replied);
	if (quoted || [m[@"forward"] length] || hasLinkPreview)
		contentW = MAX(contentW, kBubbleMinW);

	CGFloat linkPreviewH = 0;
	CGFloat linkSiteH = 0;
	CGFloat linkTitleH = 0;
	CGFloat linkDescH = 0;
	if (hasLinkPreview) {
		layout.linkSite = lpSite;
		layout.linkTitle = lpTitle;
		layout.linkDesc = lpDesc;
		layout.linkUrl = lpUrl;

		CGFloat textMaxW = kBubbleMaxW - TGDoubled(kPadH) - kQuoteBarWidth - TGMetricPadSmall;
		if (lpSite.length) {
			linkSiteH = TGMetricLineCaption;
			linkPreviewH += linkSiteH;
		}
		if (lpTitle.length) {
			CGSize ts = TGTextSize(lpTitle, TGFontCaptionStrong(), textMaxW);
			linkTitleH = MIN(ts.height, TGMetricLineCaption * 2.0f);
			linkPreviewH += linkTitleH;
		}
		if (lpDesc.length) {
			CGSize ds = TGTextSize(lpDesc, TGFontCaption(), textMaxW);
			linkDescH = MIN(ds.height, TGMetricLineCaption * 2.0f);
			linkPreviewH += linkDescH;
		}
		linkPreviewH += TGMetricPadSmall;
	}
	if (inlineStamp)
		contentW = MAX(contentW, body.width + kStampGap + timeW);
	if (isVoice)
		contentW = kPicBubbleW;
	// A track measured itself from its caption, which is usually empty, so
	// the bubble came out narrower than the row drawn inside it and the title
	// ran out past its own edge.
	if (isTrack)
		contentW = MAX(contentW, TGMetricTrackContent);
	// Buttons share the bubble's width; a short question would squeeze them
	// to a few points each.
	if ([m[@"inlineRows"] count])
		contentW = kBubbleMaxW;
	CGFloat senderH = senderName.length ? TGMetricSenderLineHeight : TGMetricZero;
	if (senderName.length)
		contentW = MAX(contentW, in.senderLineWidth ? in.senderLineWidth(senderName) : 0);

	CGFloat bubbleW = MAX(contentW + TGDoubled(kPadH),
			timeW + TGDoubled(kPadH) + TGMetricPad);
	bubbleW = MIN(bubbleW, kBubbleMaxW + TGDoubled(kPadH));

	// A caption under a voice note or a track, and the transcription under a
	// voice note, are text inside the same bubble. Measure them here so the
	// bubble and the row grow by the same amount the cell draws.
	CGFloat audioCaptionH = TGMetricZero;
	CGFloat audioTranscriptionH = TGMetricZero;
	CGFloat audioExtraH = TGMetricZero;
	if (isVoice || isTrack){
		CGFloat textW = bubbleW - TGDoubled(kPadH);
		NSString *caption = [m[@"caption"] isKindOfClass:NSString.class]
				? m[@"caption"] : @"";
		if (caption.length)
			audioCaptionH = TGTextSize(caption, TGFontBody(), textW).height;
		if (isVoice){
			NSString *transcription = [m[@"transcription"] isKindOfClass:NSString.class]
					? m[@"transcription"] : @"";
			if ([m[@"transcriptionPending"] boolValue])
				transcription = @"Transcribing...";
			if (transcription.length)
				audioTranscriptionH = TGTextSize(transcription, TGFontSubhead(), textW).height;
		}
		if (audioCaptionH > TGMetricZero || audioTranscriptionH > TGMetricZero)
			audioExtraH = TGMetricPadSmall + audioCaptionH
					+ ((audioCaptionH > TGMetricZero && audioTranscriptionH > TGMetricZero)
						? TGMetricPadTiny : TGMetricZero)
					+ audioTranscriptionH + TGMetricStampBottomInset;
	}

	stampOnPicture = TGMessageStampOnPicture(m, in.imageSize, in.fontSize);
	CGFloat bubbleH = TGDoubled(kPadV) + senderH
			+ (inlineStamp || stampOnPicture ? TGMetricZero : TGMetricLineMicro)
			+ TGMessageDecorationHeight(m, quoted != nil)
			+ (isAlbum ? (collageH + (body.height ? TGMetricPadSmall : TGMetricZero))
					   : (pic.height ? pic.height + TGMetricPadSmall : TGMetricZero))
			+ body.height
			+ (hasLinkPreview ? (linkPreviewH + (body.height > 0 ? TGMetricPadSmall : TGMetricZero)) : TGMetricZero);
	if (isVoice)
		bubbleH = TGMetricPersonRow + senderH
				+ ([m[@"forward"] length] ? TGMetricQuoteForwardLine : TGMetricZero)
				+ audioExtraH;
	// A track's row is fixed below, but its bubble was still measured by the
	// generic formula, so the two disagreed: the bubble ran past the row it
	// was given and sat on top of the message above it.
	if (isTrack)
		bubbleH = kTrackRow + senderH + forwarded + audioExtraH;

	CGFloat x = mine ? (tableW - bubbleW - TGMetricPad) : TGMetricPad;
	CGFloat top = in.continuesAlbum ? TGMetricZero : TGMetricBubbleRowInset;

	if (senderName.length) {
		x += kAvatarSide + TGMetricPadSmall + kTailWidth;   // the tail hangs between picture and bubble
		layout.senderName = senderName;
		layout.senderFrame = CGRectMake(kPadH, kPadV, bubbleW - TGDoubled(kPadH), TGMetricLineMicro);
		CGFloat avatarY = MAX(TGMetricPadTiny, top + bubbleH - kAvatarSide);
		layout.senderAvatarFrame = CGRectMake(TGMetricPad, avatarY, kAvatarSide, kAvatarSide);
	}

	layout.bubbleFrame = CGRectMake(x, top, bubbleW, bubbleH);
	layout.inlineStamp = inlineStamp;
	layout.stampOnPicture = stampOnPicture;
	layout.timeWidth = timeW;
	layout.stamp = TGMessageStampText(m);
	layout.quoteText = quoted;
	layout.quoteAuthor = in.quoteAuthor;
	layout.quoteEntities = TGMessageQuoteEntities(m, in.replied);

	layout.tailFrame = CGRectZero;

	CGFloat y = kPadV + senderH + forwarded;
	if (quoted) {
		CGFloat quoteW = bubbleW - TGDoubled(kPadH) - TGMetricPadMedium;
		layout.quoteBarFrame = CGRectMake(kPadH, y, kQuoteBarWidth, TGDoubled(kQuoteLine));
		layout.quoteAuthorFrame = CGRectMake(kPadH + kQuoteTextInset, y, quoteW, TGMetricLineCaption);
		layout.quoteFrame = CGRectMake(kPadH + kQuoteTextInset, y + kQuoteLine, quoteW, kQuoteLine);
		y += kQuoteBlock;
	}
	CGFloat innerW = bubbleW - TGDoubled(kPadH);
	if (isAlbum) {
		CGFloat cW = (body.height > 0) ? innerW : collageW;
		layout.collageFrame = CGRectMake(kPadH, y, cW, collageH);
		if (!body.height) {
			CGFloat plateW = timeW + (mine ? TGMetricGroupAvatarSide : TGMetricLineMicro);
			layout.mediaStampFrame = CGRectMake(kPadH + collageW - plateW - kMediaStampInset,
					y + collageH - TGMetricFloatingDateHeight, plateW, TGMetricLineCaption);
		}
		y += collageH + TGMetricPadSmall;
		layout.bodyFrame = CGRectMake(kPadH, y, innerW, body.height);
		if (body.height > 0)
			y += body.height + (hasLinkPreview ? TGMetricPadSmall : TGMetricZero);
	} else if (pic.height > 0) {
		BOOL captionAbove = [m[@"captionAbove"] isKindOfClass:[NSNumber class]] &&
				[m[@"captionAbove"] boolValue] && body.height > 0;
		if (captionAbove) {
			layout.bodyFrame = CGRectMake(kPadH, y, innerW, body.height);
			y += body.height + TGMetricPadSmall;
		}
		CGFloat picW = (body.height > 0) ? innerW : pic.width;
		layout.pictureFrame = CGRectMake(kPadH, y, picW, pic.height);
		if (stampOnPicture) {
			CGFloat plateW = timeW + (mine ? TGMetricGroupAvatarSide : TGMetricLineMicro);
			layout.mediaStampFrame = CGRectMake(kPadH + picW - plateW - kMediaStampInset,
					y + pic.height - TGMetricFloatingDateHeight, plateW, TGMetricLineCaption);
		}
		if (captionAbove) {
			y += pic.height + (hasLinkPreview ? TGMetricPadSmall : TGMetricZero);
		} else {
			y += pic.height + TGMetricPadSmall;
			layout.bodyFrame = CGRectMake(kPadH, y, innerW, body.height);
			if (body.height > 0)
				y += body.height + (hasLinkPreview ? TGMetricPadSmall : TGMetricZero);
		}
	} else {
		layout.bodyFrame = CGRectMake(kPadH, y, innerW, body.height);
		if (body.height > 0)
			y += body.height + (hasLinkPreview ? TGMetricPadSmall : TGMetricZero);
	}

	if (hasLinkPreview) {
		CGFloat lY = y;
		layout.linkPreviewFrame = CGRectMake(kPadH, lY, innerW, linkPreviewH);
		layout.linkBarFrame = CGRectMake(kPadH, lY, kQuoteBarWidth, linkPreviewH);
		CGFloat textX = kPadH + kQuoteBarWidth + TGMetricPadSmall;
		CGFloat textW = innerW - kQuoteBarWidth - TGMetricPadSmall;
		CGFloat curY = lY;
		if (linkSiteH > 0) {
			layout.linkSiteFrame = CGRectMake(textX, curY, textW, linkSiteH);
			curY += linkSiteH;
		} else {
			layout.linkSiteFrame = CGRectZero;
		}
		if (linkTitleH > 0) {
			layout.linkTitleFrame = CGRectMake(textX, curY, textW, linkTitleH);
			curY += linkTitleH;
		} else {
			layout.linkTitleFrame = CGRectZero;
		}
		if (linkDescH > 0) {
			layout.linkDescFrame = CGRectMake(textX, curY, textW, linkDescH);
			curY += linkDescH;
		} else {
			layout.linkDescFrame = CGRectZero;
		}
		y += linkPreviewH;
	} else {
		layout.linkPreviewFrame = CGRectZero;
	}

	CGFloat stampY = inlineStamp ? TGInlineStampY(layout.bodyFrame)
			: (bubbleH - kPadV - TGMetricStampHeight);
	CGFloat tickW = mine ? TGMetricStampTicksRoom : TGMetricZero;
	CGFloat eyeRoom = 0;
	int64_t viewCount = [m[@"viewCount"] respondsToSelector:@selector(longLongValue)] ? [m[@"viewCount"] longLongValue] : 0;
	if (viewCount > 0) {
		eyeRoom = kStampEyeSide + kStampEyePad;
	}
	layout.timeFrame = CGRectMake(bubbleW - timeW - kPadH + eyeRoom, stampY, timeW - tickW - eyeRoom, TGMetricStampHeight);

	CGFloat rowH = TGDoubled(kPadV) + TGMessageDecorationHeight(m, quoted != nil) +
			(inlineStamp || stampOnPicture ? TGMetricZero : TGMetricLineMicro);
	if (in.isGroup && !mine && senderName.length)
		rowH += TGMetricSenderLineHeight;
	if (isAlbum) rowH += collageH + (body.height > 0 ? TGMetricPadSmall : TGMetricZero);
	else if (pic.height > 0) rowH += pic.height + TGMetricPadSmall;
	if (body.height > 0) rowH += body.height;
	if (hasLinkPreview) rowH += linkPreviewH + (body.height > 0 ? TGMetricPadSmall : TGMetricZero);
	if (isVoice) rowH = TGMetricVoicePillHeight + forwarded + audioExtraH;
	// Fixed, like a voice note: the artwork and the two lines beside it do
	// not grow with the title, which is truncated instead.
	// One expression for the row and the bubble, so they cannot drift apart.
	if (isTrack) rowH = kTrackRow + forwarded + senderH + audioExtraH;
	// The caption sits below the row, and a sender line makes the bubble
	// taller than the pill formula above; never let the row clip it.
	if ((isVoice || isTrack) && audioExtraH > TGMetricZero)
		rowH = MAX(rowH, bubbleH);

	// Reactions sit under the bubble rather than in it, the way Telegram draws
	// them: the pill is its own object on the chat canvas. Their height is
	// therefore added to the row, not to bubbleH.
	if ([m[@"reactionGroups"] count]){
		// A voice note measured its row differently from its bubble; the
		// chips are placed from bubbleH, so the row must at least reach it.
		rowH = MAX(rowH, bubbleH);
		// Outgoing chips grow leftwards from the bubble's right edge, the way
		// Telegram keeps a narrow own message from clipping its own reaction.
		CGFloat chipsW = MIN(kBubbleMaxW, tableW - TGDoubled(TGMetricPad));
		CGFloat chipsX = mine ? (tableW - TGMetricPad - chipsW) : x;
		layout.reactionChipsFrame = CGRectMake(chipsX,
				top + bubbleH + TGMetricReactionChipTop,
				chipsW, TGMetricReactionChipHeight);
		rowH += TGMetricReactionChipHeight + TGMetricReactionChipTop;
	} else {
		layout.reactionChipsFrame = CGRectZero;
	}

	layout.rowHeight = MAX(rowH + TGDoubled(TGMetricBubbleRowInset), kBubbleRowMin);
	return layout;
}

