#import "TGMessageRowLayout.h"
#import "TGMessageLayout.h"
#import "TGMessageMetrics.h"
#import "TGMessageCard.h"
#import "TGMessageCardView.h"
#import "TGStyle.h"
#import "TGLocalization.h"

@implementation TGMessageRowInput
@end

/// The album's tile frames as the cell reads them back with -CGRectValue.
static CGRect TGRectFromValue(NSValue *value) {
#if TARGET_OS_IPHONE
	return [value CGRectValue];
#else
	CGRect rect;
	[value getValue:&rect];
	return rect;
#endif
}

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
	if (!name.length)
		return name;
	// Official: the author, then "via @bot" (Conversation.MessageViaUser).
	NSString *via = m[@"viaBot"];
	if ([via isKindOfClass:NSString.class] && via.length)
		name = [NSString stringWithFormat:@"%@ %@", name,
				TGLocalizedFormat(@"via %@", [@"@" stringByAppendingString:via])];
	NSString *tag = m[@"senderTag"];
	if ([tag isKindOfClass:NSString.class] && tag.length)
		return [NSString stringWithFormat:@"%@ · %@", name, tag];
	return name;
}

CGSize TGMessageBodySizeForWidth(NSDictionary *m, CGFloat fontSize, CGFloat contentMaxW) {
	if ([m[@"kind"] isEqualToString:@"messageSticker"] || [m[@"kind"] isEqualToString:@"messageAnimatedEmoji"])
		return CGSizeZero;
	NSString *text = m[@"text"] ?: @"";
	if (!text.length)
		return CGSizeZero;
	return TGTextSizeWithEntities(text, m[@"entities"], TGFontAtSize(fontSize), contentMaxW);
}

CGSize TGMessageBodySize(NSDictionary *m, CGFloat fontSize) {
	return TGMessageBodySizeForWidth(m, fontSize, kBubbleMaxW - TGDoubled(kPadH));
}

NSArray *TGMessageTextsToMeasure(NSArray *messages) {
	NSMutableArray *texts = [NSMutableArray arrayWithCapacity:messages.count];
	for (NSDictionary *m in messages) {
		NSString *text = m[@"text"];
		if (![m isKindOfClass:NSDictionary.class] || ![text isKindOfClass:NSString.class] || !text.length)
			continue;
		NSArray *entities = m[@"entities"];
		NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithObject:[text copy] forKey:@"text"];
		if (m[@"kind"])
			copy[@"kind"] = m[@"kind"];
		if ([entities isKindOfClass:NSArray.class])
			copy[@"entities"] = [entities copy];
		[texts addObject:copy];
	}
	return texts;
}

void TGMeasureMessageTexts(NSArray *texts, CGFloat fontSize) {
	for (NSDictionary *m in texts)
		TGMessageBodySize(m, fontSize);
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
	CGFloat bubbleMaxW = TGMetricBubbleMaxWidthForTableWidth(tableW);
	CGFloat maxContentW = TGMetricBubbleMaxContentWidthForTableWidth(tableW);
	CGFloat textMaxW = TGMetricBubbleTextWidthForTableWidth(tableW);

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
		CGFloat width = maxContentW;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		CGFloat cardH = TGMessageCardLayout(card, width - TGDoubled(kPadH)).size.height;
		CGFloat height = TGPlaceGroupSender(layout, in.senderName, width, kPadV + cardH + kPadV + kPollStampRoom, &x);
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		return layout;
	}

	if (isChecklist) {
		CGFloat width = maxContentW;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		CGFloat height = TGPlaceGroupSender(layout, in.senderName, width, TGMessageChecklistHeight(m), &x);
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		return layout;
	}

	if (isPoll) {
		CGFloat width = maxContentW;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		CGFloat height = TGPlaceGroupSender(layout, in.senderName, width, TGMessagePollHeight(m, in.pendingVotes), &x);
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		return layout;
	}

	if (isCall) {
		NSString *line = m[@"text"] ?: @"Call";
		CGFloat textW = TGTextSize(line, TGFontSubheadStrong(), 0).width;
		CGFloat width = MIN(maxContentW, textW + kCallBubbleRoom);
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
		layout.documentFrame = CGRectMake(kPadH, forwarded + kPadV, width - TGDoubled(kPadH), docsH);

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
		// The same stamp as every other bubble: this branch kept its own
		// arithmetic and left out a sent document's ticks.
		TGMessageStampParts stamp = TGMessageStampPlace(m, width - kPadH,
				height - kPadV - TGHalf(TGMetricStampHeight));
		layout.timeFrame = stamp.text;
		layout.stampEyeFrame = stamp.eye;
		layout.stampTicksFrame = stamp.ticks;
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		return layout;
	}

	if (isContact) {
		CGFloat width = kContactBubble;
		CGFloat height = kContactBubbleH + forwarded;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		TGMessageStampParts stamp = TGMessageStampPlace(m, width - kPadH,
				forwarded + TGMetricPersonRow + TGHalf(TGMetricLineMicro));
		layout.timeFrame = stamp.text;
		layout.stampEyeFrame = stamp.eye;
		layout.stampTicksFrame = stamp.ticks;
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

	CGSize body = TGMessageBodySizeForWidth(m, in.fontSize, textMaxW);
	// The width the body was wrapped at. Buttons, a link preview or the
	// stamp can make the bubble up to 2 * kPadH wider than that; a label
	// that wide wraps into fewer lines than were measured, centres them in
	// the taller frame, and every custom emoji drawn from the top of the
	// frame on iOS 6 sat a line or more above its place.
	CGFloat bodyW = textMaxW;
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
	// A track's empty caption "fits" the stamp and put it on the title line;
	// its time belongs at the bubble's bottom right, as a file's does.
	BOOL inlineStamp = !stampOnPicture && ![kind isEqualToString:@"messageAudio"]
			&& TGMessageStampFitsInlineForWidth(m, in.fontSize, bodyW);
	NSString *lpSite = m[@"linkPreviewSite"];
	NSString *lpTitle = m[@"linkPreviewTitle"];
	NSString *lpDesc = m[@"linkPreviewDesc"];
	NSString *lpUrl = m[@"linkPreviewUrl"];
	NSString *lpAction = [m[@"linkPreviewAction"] isKindOfClass:NSString.class]
			? m[@"linkPreviewAction"] : @"";
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
	CGFloat linkActionH = 0;
	CGFloat linkSiteH = 0;
	CGFloat linkTitleH = 0;
	CGFloat linkDescH = 0;
	CGSize linkMedia = CGSizeZero;
	BOOL linkMediaLarge = NO;
	if (hasLinkPreview) {
		layout.linkSite = lpSite;
		layout.linkTitle = lpTitle;
		layout.linkDesc = lpDesc;
		layout.linkUrl = lpUrl;

		CGFloat lpTextMaxW = maxContentW - kQuoteBarWidth - TGMetricPadSmall;
		linkMedia = TGLinkPreviewMediaSize(m, lpTextMaxW);
		linkMediaLarge = [m[@"linkPreviewLarge"] boolValue] && linkMedia.width > 0;
		// A picture makes the preview as wide as a bubble gets; the small
		// one takes its corner out of the words' width.
		if (linkMedia.width > 0)
			contentW = MAX(contentW, maxContentW);
		if (linkMedia.width > 0 && !linkMediaLarge)
			lpTextMaxW -= linkMedia.width + TGMetricPadSmall;
		if (lpSite.length) {
			linkSiteH = TGMetricLineCaption;
			linkPreviewH += linkSiteH;
		}
		if (lpTitle.length) {
			CGSize ts = TGTextSize(lpTitle, TGFontCaptionStrong(), lpTextMaxW);
			linkTitleH = MIN(ts.height, TGMetricLineCaption * 2.0f);
			linkPreviewH += linkTitleH;
		}
		if (lpDesc.length) {
			CGSize ds = TGTextSize(lpDesc, TGFontCaption(), lpTextMaxW);
			linkDescH = MIN(ds.height, TGMetricLineCaption * 2.0f);
			linkPreviewH += linkDescH;
		}
		if (linkMediaLarge)
			linkPreviewH += linkMedia.height + TGMetricPadSmall;
		else if (linkMedia.width > 0)
			linkPreviewH = MAX(linkPreviewH, linkMedia.height);
		linkPreviewH += TGMetricPadSmall;
		// The button sits under the preview, outside its bar, and counts
		// as part of the preview for the bubble's height.
		if (lpAction.length)
			linkActionH = TGMetricButtonSmallH;
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
		contentW = maxContentW;
	CGFloat senderH = senderName.length ? TGMetricSenderLineHeight : TGMetricZero;
	CGFloat senderW = TGMetricZero;
	if (senderName.length){
		senderW = in.senderLineWidth ? in.senderLineWidth(senderName) : 0;
		contentW = MAX(contentW, senderW);
	}

	CGFloat bubbleW = MAX(contentW + TGDoubled(kPadH),
			timeW + TGDoubled(kPadH) + TGMetricPad);
	bubbleW = MIN(bubbleW, bubbleMaxW);

	// A photo or an album fills its bubble to kMediaInset of the edge, as
	// the official bubbles do; the text padding round it read as a heavy
	// frame. The picture keeps its proportions: it grows with the width.
	BOOL fillsBubble = (isAlbum || pic.height > 0) && !isSticker;
	if (fillsBubble){
		// The picture sets the base width, but if a caption is present the bubble expands
		// to accommodate the text up to bubbleMaxW (as in official Telegram), rather than
		// squeezing the text into a narrow portrait media column.
		CGFloat natural = (isAlbum ? collageW : pic.width) + TGDoubled(kMediaInset);
		if (senderName.length)
			natural = MAX(natural, senderW + TGDoubled(kPadH));
		if (body.height > 0) {
			CGFloat textNeeded = body.width + TGDoubled(kPadH);
			natural = MAX(natural, textNeeded);
		}
		bubbleW = MIN(natural, bubbleMaxW);
		if (body.height > 0){
			bodyW = bubbleW - TGDoubled(kPadH);
			body = TGTextSizeWithEntities(m[@"text"] ?: @"", m[@"entities"],
					TGFontAtSize(in.fontSize), bodyW);
			layout.bodySize = body;
			// Measured for the full width, the last line may not have room
			// for the stamp at this one: it gets its own line.
			inlineStamp = NO;
		}
	}
	CGFloat mediaW = bubbleW - TGDoubled(kMediaInset);
	if (fillsBubble && isAlbum && collageW > 0){
		CGFloat scale = mediaW / collageW;
		collageH = floorf(collageH * scale);
		NSMutableArray *scaled = [NSMutableArray array];
		for (NSValue *value in itemFrames){
			CGRect f = TGRectFromValue(value);
			[scaled addObject:TGRectValue(CGRectMake(floorf(f.origin.x * scale),
					floorf(f.origin.y * scale), floorf(f.size.width * scale),
					floorf(f.size.height * scale)))];
		}
		itemFrames = scaled;
		layout.albumFrames = scaled;
		collageW = mediaW;
	} else if (fillsBubble && pic.width > 0){
		CGFloat scaledH = floorf(pic.height * mediaW / pic.width);
		CGFloat maxMediaH = floorf(bubbleMaxW * 1.15f);
		if (scaledH > maxMediaH)
			scaledH = maxMediaH;
		pic = CGSizeMake(mediaW, scaledH);
	}
	BOOL captionAboveMedia = fillsBubble && body.height > 0 &&
			[m[@"captionAbove"] isKindOfClass:NSNumber.class] && [m[@"captionAbove"] boolValue];
	// Nothing above the picture (no name, forward, quote or caption) and
	// nothing under it (no caption, link preview or stamp line): the bubble's
	// padding on that side shrinks to kMediaInset.
	BOOL mediaFirst = fillsBubble && !senderName.length && forwarded <= 0 &&
			!quoted.length && !captionAboveMedia;
	BOOL mediaLast = fillsBubble && !hasLinkPreview &&
			(body.height <= 0 || captionAboveMedia);

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
			- (mediaFirst ? kPadV - kMediaInset : TGMetricZero)
			- (mediaLast ? kPadV - kMediaInset : TGMetricZero)
			+ (inlineStamp || stampOnPicture ? TGMetricZero : TGMetricLineMicro)
			+ TGMessageDecorationHeight(m, quoted != nil)
			+ (isAlbum ? (collageH + (body.height ? TGMetricPadSmall : TGMetricZero))
					   : (pic.height ? pic.height + (mediaLast ? TGMetricZero : TGMetricPadSmall) : TGMetricZero))
			+ body.height
			+ (hasLinkPreview ? (linkPreviewH + linkActionH + (body.height > 0 ? TGMetricPadSmall : TGMetricZero)) : TGMetricZero);
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

	CGFloat y = (mediaFirst ? kMediaInset : kPadV) + senderH + forwarded;
	if (quoted) {
		CGFloat quoteW = bubbleW - TGDoubled(kPadH) - TGMetricPadMedium;
		layout.quoteBarFrame = CGRectMake(kPadH, y, kQuoteBarWidth, TGDoubled(kQuoteLine));
		layout.quoteAuthorFrame = CGRectMake(kPadH + kQuoteTextInset, y, quoteW, TGMetricLineCaption);
		layout.quoteFrame = CGRectMake(kPadH + kQuoteTextInset, y + kQuoteLine, quoteW, kQuoteLine);
		y += kQuoteBlock;
	}
	CGFloat innerW = bubbleW - TGDoubled(kPadH);
	if (isAlbum) {
		CGFloat cW = fillsBubble ? mediaW : ((body.height > 0) ? innerW : collageW);
		layout.collageFrame = CGRectMake(fillsBubble ? kMediaInset : kPadH, y, cW, collageH);
		if (!body.height) {
			TGMessageStampParts plate;
			layout.mediaStampFrame = TGMessageStampPlate(m, CGRectGetMaxX(layout.collageFrame) - kMediaStampInset,
					y + collageH - TGMetricFloatingDateHeight + TGMetricLineCaption, &plate);
			layout.timeFrame = plate.text;
			layout.stampEyeFrame = plate.eye;
			layout.stampTicksFrame = plate.ticks;
		}
		y += collageH + TGMetricPadSmall;
		layout.bodyFrame = CGRectMake(kPadH, y, MIN(innerW, bodyW), body.height);
		if (body.height > 0)
			y += body.height + (hasLinkPreview ? TGMetricPadSmall : TGMetricZero);
	} else if (pic.height > 0) {
		BOOL captionAbove = [m[@"captionAbove"] isKindOfClass:[NSNumber class]] &&
				[m[@"captionAbove"] boolValue] && body.height > 0;
		if (captionAbove) {
			layout.bodyFrame = CGRectMake(kPadH, y, MIN(innerW, bodyW), body.height);
			y += body.height + TGMetricPadSmall;
		}
		CGFloat picW = fillsBubble ? mediaW : ((body.height > 0) ? innerW : pic.width);
		layout.pictureFrame = CGRectMake(fillsBubble ? kMediaInset : kPadH, y, picW, pic.height);
		if (stampOnPicture) {
			TGMessageStampParts plate;
			layout.mediaStampFrame = TGMessageStampPlate(m, CGRectGetMaxX(layout.pictureFrame) - kMediaStampInset,
					y + pic.height - TGMetricFloatingDateHeight + TGMetricLineCaption, &plate);
			layout.timeFrame = plate.text;
			layout.stampEyeFrame = plate.eye;
			layout.stampTicksFrame = plate.ticks;
		}
		if (captionAbove) {
			y += pic.height + (hasLinkPreview ? TGMetricPadSmall : TGMetricZero);
		} else {
			y += pic.height + TGMetricPadSmall;
			layout.bodyFrame = CGRectMake(kPadH, y, MIN(innerW, bodyW), body.height);
			if (body.height > 0)
				y += body.height + (hasLinkPreview ? TGMetricPadSmall : TGMetricZero);
		}
	} else {
		layout.bodyFrame = CGRectMake(kPadH, y, MIN(innerW, bodyW), body.height);
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
		BOOL mediaAbove = [m[@"linkPreviewAbove"] boolValue];
		if (linkMediaLarge){
			// show_media_above_description: the picture heads the preview,
			// otherwise it closes it.
			CGFloat mediaY = mediaAbove ? lY
					: lY + linkPreviewH - TGMetricPadSmall - linkMedia.height;
			layout.linkMediaFrame = CGRectMake(textX, mediaY, textW, linkMedia.height);
			if (mediaAbove)
				curY += linkMedia.height + TGMetricPadSmall;
		} else if (linkMedia.width > 0){
			layout.linkMediaFrame = CGRectMake(textX + textW - linkMedia.width, lY,
					linkMedia.width, linkMedia.height);
			textW -= linkMedia.width + TGMetricPadSmall;
		} else {
			layout.linkMediaFrame = CGRectZero;
		}
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
		layout.linkAction = linkActionH > 0 ? lpAction : nil;
		layout.linkActionFrame = linkActionH > 0
				? CGRectMake(kPadH, y, innerW, linkActionH) : CGRectZero;
		y += linkActionH;
	} else {
		layout.linkActionFrame = CGRectZero;
		layout.linkPreviewFrame = CGRectZero;
		layout.linkMediaFrame = CGRectZero;
	}

	// The comments footer is the bubble's last row; the time stays above it.
	CGFloat commentsH = [m[@"canComment"] boolValue] ? kCommentsBar : TGMetricZero;
	layout.commentsFrame = commentsH > 0
			? CGRectMake(TGMetricZero, bubbleH - commentsH, bubbleW, commentsH) : CGRectZero;
	CGFloat stampY = inlineStamp ? TGInlineStampY(layout.bodyFrame)
			: (bubbleH - commentsH - kPadV - TGMetricStampHeight);
	// On a picture the plate's parts are already placed above.
	if (!stampOnPicture){
		TGMessageStampParts stamp = TGMessageStampPlace(m, bubbleW - kPadH,
				stampY + TGHalf(TGMetricStampHeight));
		layout.timeFrame = stamp.text;
		layout.stampEyeFrame = stamp.eye;
		layout.stampTicksFrame = stamp.ticks;
	}

	CGFloat rowH = TGDoubled(kPadV) + TGMessageDecorationHeight(m, quoted != nil) +
			(inlineStamp || stampOnPicture ? TGMetricZero : TGMetricLineMicro)
			- (mediaFirst ? kPadV - kMediaInset : TGMetricZero)
			- (mediaLast ? kPadV - kMediaInset : TGMetricZero);
	if (in.isGroup && !mine && senderName.length)
		rowH += TGMetricSenderLineHeight;
	if (isAlbum) rowH += collageH + (body.height > 0 ? TGMetricPadSmall : TGMetricZero);
	else if (pic.height > 0) rowH += pic.height + (mediaLast ? TGMetricZero : TGMetricPadSmall);
	if (body.height > 0) rowH += body.height;
	if (hasLinkPreview) rowH += linkPreviewH + linkActionH + (body.height > 0 ? TGMetricPadSmall : TGMetricZero);
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
		CGFloat chipsW = MIN(bubbleMaxW, tableW - TGDoubled(TGMetricPad));
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


TGMessageTapPart TGMessageTapPartAt(TGMessageLayout *layout, CGPoint point) {
	CGRect bubble = layout.bubbleFrame;
	if (!CGRectContainsPoint(bubble, point))
		return TGMessageTapNone;
	CGPoint p = CGPointMake(point.x - bubble.origin.x, point.y - bubble.origin.y);
	CGRect quote = CGRectUnion(layout.quoteBarFrame, layout.quoteFrame);
	if (!CGRectIsEmpty(layout.quoteFrame) && CGRectContainsPoint(quote, p))
		return TGMessageTapQuote;
	if (!CGRectIsEmpty(layout.documentFrame) && CGRectContainsPoint(layout.documentFrame, p))
		return TGMessageTapDocument;
	if ((!CGRectIsEmpty(layout.pictureFrame) && CGRectContainsPoint(layout.pictureFrame, p)) ||
			(!CGRectIsEmpty(layout.collageFrame) && CGRectContainsPoint(layout.collageFrame, p)))
		return TGMessageTapPicture;
	return TGMessageTapBubble;
}
