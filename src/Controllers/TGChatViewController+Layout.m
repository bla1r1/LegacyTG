#import "TGPerf.h"
#import "TGChatViewControllerInternal.h"
#import "TGCapabilities.h"
#import "TGStyle.h"
#import "TGDevShowcase.h"
#import "TGPollPresentation.h"
#import "TGPinnedLine.h"
#import "TGUIFormat.h"

CGFloat TGPollOptionRowHeight(NSDictionary *option, CGFloat rowWidth) {
	CGFloat textW = rowWidth - kPollTextColumn - kPollShareWidth - TGMetricPadTiny;
	CGFloat textH = TGTextSize(TGPollOptionText(option), TGFontSubhead(), textW).height;
	return MAX(kPollRow, textH + TGDoubled(TGMetricPadTiny));
}
#import "TGBase64.h"

UIColor *TGSenderColour(int64_t userId) {
	// The colour the person picked in their own profile, as Telegram draws it;
	// the id-based slot of their placeholder avatar until their record is here.
	return [[TGClient shared] nameColourForUser:userId];
}

@implementation TGChatViewController (Layout)

#pragma mark - geometry

/// Size of the text inside a bubble, and of the bubble itself.
/// The quote block a reply carries, and the "forwarded from" line above it.
- (NSString *)quoteTextFor:(NSDictionary *)m {
	NSNumber *replyId = m[@"replyId"];
	if (![replyId isKindOfClass:NSNumber.class])
		return nil;
	NSString *inline_ = m[@"replyText"];
	if (inline_.length)
		return inline_;
	NSDictionary *fetched = self.quotes[replyId];
	if (!fetched)
		return @"...";
	return TGDescribeMessageContent(fetched);
}

/// Who wrote the message being answered. Only known once the original has been
/// fetched; TDLib's inline quote carries the text but not the author.
- (NSString *)quoteAuthorFor:(NSDictionary *)m {
	NSNumber *replyId = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
	if (!replyId)
		return nil;
	NSDictionary *original = self.quotes[replyId];
	if (!original)
		return nil;
	if ([original[@"outgoing"] boolValue])
		return @"You";
	return [[TGClient shared] nameForUserId:[original[@"senderId"] longLongValue]];
}

- (CGFloat)decorationHeightFor:(NSDictionary *)m {
	CGFloat h = TGMetricZero;
	if ([m[@"forward"] length])
		h += TGMetricQuoteForwardLine;
	// Their reply block is two lines beside a stripe: the author, then what
	// they said.
	if ([self quoteTextFor:m])
		h += kQuoteBlock;
	// The "12 Comments" bar under a channel post.
	if ([m[@"canComment"] boolValue])
		h += TGMetricLineBody;
	// A bot's buttons, a row each.
	NSUInteger rows = [m[@"inlineRows"] count];
	if (rows)
		h += rows * (TGMetricBotButtonHeight + TGMetricBotButtonGap) + TGMetricBotButtonGap;
	return h;
}

/// "12:29" for incoming, "12:29 ✓✓" for outgoing, "12:29 edited" when the
/// message has been changed - the line Telegram tucks into the corner of the
/// bubble. The mark follows the clock; a prefix moves every stamp two words in.
/// Channel posts and forwarded posts with views show their view count and signature.
- (NSString *)stampFor:(NSDictionary *)m {
	NSString *time = TGMessageStamp([m[@"date"] doubleValue], [m[@"edited"] boolValue]);
	int64_t viewCount = 0;
	id rawViews = m[@"viewCount"];
	if ([rawViews respondsToSelector:@selector(longLongValue)]) {
		viewCount = [rawViews longLongValue];
	}
	if (viewCount > 0) {
		NSString *count = TGCompactCount(viewCount);
		NSString *sig = @"";
		id rawSig = m[@"authorSignature"];
		if ([rawSig isKindOfClass:NSString.class]) {
			sig = (NSString *)rawSig;
		}
		if (sig.length > 16) {
			sig = [[sig substringToIndex:16] stringByAppendingString:@"..."];
		}
		if (sig.length > 0) {
			return [NSString stringWithFormat:@"%@, %@ %@", sig, count, time];
		}
		return [NSString stringWithFormat:@"%@ %@", count, time];
	}
	return time;
}

- (CGFloat)timeWidthFor:(NSDictionary *)m {
	CGFloat w = TGTextSize([self stampFor:m], TGFontMicro(), 0).width + TGMetricPadTiny;
	int64_t viewCount = 0;
	id rawViews = m[@"viewCount"];
	if ([rawViews respondsToSelector:@selector(longLongValue)]) {
		viewCount = [rawViews longLongValue];
	}
	if (viewCount > 0) {
		w += kStampEyeSide + kStampEyePad;
	}
	if ([m[@"outgoing"] boolValue])
		w += TGMetricStampTicksRoom;
	return w;
}

/// Telegram puts the stamp at the end of the last line when it fits there,
/// and only drops it to its own line when it does not. Anything else leaves a
/// gap under short messages, which is what looked wrong.
- (BOOL)stampFitsInlineFor:(NSDictionary *)m {
	NSString *text = m[@"text"] ?: @"";
	if (!text.length || [text rangeOfString:@"\n"].location != NSNotFound)
		return NO;

	CGFloat oneLine = TGTextSize(text,
			TGFontAtSize([TGTheme shared].messageFontSize), 0).width;
	if (oneLine > kBubbleMaxW - TGDoubled(kPadH))
		return NO;   // it wraps, so there is no short last line to share

	return (oneLine + kStampGap + [self timeWidthFor:m]) <= (kBubbleMaxW - TGDoubled(kPadH));
}

/// Configures forwarded message attribution header and returns its height.
- (CGFloat)layoutForwardIn:(TGBubbleCell *)cell
				   message:(NSDictionary *)m
					 width:(CGFloat)width
{
	NSString *from = m[@"forward"];
	if (![from length]){
		cell.forwardLabel.hidden = YES;
		return 0;
	}

	TGTheme *theme = [TGTheme shared];
	cell.forwardLabel.hidden = NO;
	CGFloat topY = kPadV;
	if (self.isGroup && ![m[@"outgoing"] boolValue]) {
		topY += TGMetricSenderLineHeight;
	}
	cell.forwardLabel.frame = CGRectMake(kPadH, topY, width - TGDoubled(kPadH), TGMetricSenderLineHeight);

	NSString *line = [NSString stringWithFormat:@"Forwarded from %@", from];
	if ([cell.forwardLabel respondsToSelector:@selector(setAttributedText:)]){
		NSMutableAttributedString *styled =
				[[NSMutableAttributedString alloc] initWithString:line];
		[styled addAttribute:NSForegroundColorAttributeName
					   value:[theme secondaryTextColour]
					   range:NSMakeRange(0, line.length)];
		[styled addAttribute:NSForegroundColorAttributeName
					   value:[theme accentColour]
					   range:NSMakeRange(15, from.length)];
		[styled addAttribute:NSFontAttributeName
					   value:TGFontMetaStrong()
					   range:NSMakeRange(15, from.length)];
		cell.forwardLabel.attributedText = styled;
	} else {
		cell.forwardLabel.textColor = [theme accentColour];
		cell.forwardLabel.text = line;
	}
	return TGMetricQuoteForwardLine;
}

/// A checklist's title, one row per task and the progress line under them.
/// The cell places the same stack from the same constants.
- (CGFloat)checklistHeightFor:(NSDictionary *)m {
	NSDictionary *checklist = [m[@"checklist"] isKindOfClass:NSDictionary.class]
			? m[@"checklist"] : @{};
	NSString *title = [checklist[@"title"] isKindOfClass:NSString.class]
			? checklist[@"title"] : @"Checklist";
	NSArray *tasks = [checklist[@"tasks"] isKindOfClass:NSArray.class]
			? checklist[@"tasks"] : @[];

	CGFloat contentW = kBubbleMaxW - TGDoubled(kPadH);
	CGFloat textW = contentW - kChecklistTextColumn;
	CGSize titleSize = TGTextSize(title, TGFontBodyStrong(), contentW);

	CGFloat height = kPadV + titleSize.height;
	if (tasks.count)
		height += kChecklistTitleGap;
	for (id raw in tasks) {
		NSDictionary *task = [raw isKindOfClass:NSDictionary.class] ? raw : @{};
		NSString *text = [task[@"text"] isKindOfClass:NSString.class]
				? task[@"text"] : @"";
		CGFloat textH = TGTextSize(text, TGFontBody(), textW).height;
		height += MAX(kChecklistRow, textH);
	}
	height += kChecklistProgressGap + kChecklistProgressLine + kChecklistStampRoom;
	return height;
}

/// Question, then the description and kind line, one row per option, a Vote
/// button for a multiple-answer draft, the quiz explanation and the votes
/// line. The cell places the same stack from the same constants, so this
/// height and that layout cannot drift.
- (CGFloat)pollHeightFor:(NSDictionary *)m {
	NSDictionary *poll = [m[@"poll"] isKindOfClass:NSDictionary.class]
			? m[@"poll"] : @{
				@"question"        : [m[@"pollQuestion"] isKindOfClass:NSString.class]
						? m[@"pollQuestion"] : @"Poll",
				@"options"         : [m[@"pollOptions"] isKindOfClass:NSArray.class]
						? m[@"pollOptions"] : @[],
				@"totalVoterCount" : [m[@"pollTotal"] isKindOfClass:NSNumber.class]
						? m[@"pollTotal"] : @0,
				@"isClosed"        : [m[@"pollClosed"] isKindOfClass:NSNumber.class]
						? m[@"pollClosed"] : @NO,
			};
	NSString *question = [poll[@"question"] isKindOfClass:NSString.class]
			? poll[@"question"] : @"Poll";
	NSString *description = [poll[@"description"] isKindOfClass:NSString.class]
			? poll[@"description"] : @"";
	NSString *explanation = [poll[@"explanation"] isKindOfClass:NSString.class]
			? poll[@"explanation"] : @"";
	NSArray *options = [poll[@"options"] isKindOfClass:NSArray.class]
			? poll[@"options"] : @[];

	NSNumber *key = @([m[@"id"] longLongValue]);
	NSMutableIndexSet *pending = self.pendingPollVotes[key];
	BOOL showVote = [poll[@"allowsMultiple"] boolValue]
			&& ![poll[@"isClosed"] boolValue]
			&& !TGPollShowsResults(poll)
			&& [pending isKindOfClass:NSIndexSet.class] && pending.count > 0;
	BOOL showExplanation = TGPollShowsResults(poll) && explanation.length > 0;

	CGFloat textW = kBubbleMaxW - TGDoubled(kPadH);
	CGSize questionSize = TGTextSize(question, TGFontBodyStrong(), textW);
	CGFloat descriptionH = description.length
			? TGTextSize(description, TGFontSubhead(), textW).height
			: TGMetricZero;
	CGFloat explanationH = showExplanation
			? TGTextSize(explanation, TGFontCaption(), textW).height
			: TGMetricZero;

	CGFloat height = kPadV + questionSize.height;
	if (descriptionH > TGMetricZero)
		height += kPollDescriptionGap + descriptionH;
	height += kPollKindGap + kPollKindLine + kPollOptionsGap;
	for (NSDictionary *option in options)
		height += TGPollOptionRowHeight(option, textW);
	if (showVote)
		height += kPollVoteGap + kPollVoteHeight;
	if (explanationH > TGMetricZero)
		height += kPollExplanationGap + explanationH;
	height += kPollFooterGap + kPollFooterLine + kPollStampRoom;
	return height;
}

/// The service line as drawn: who acted, and for a pin, the quoted message
/// once it is loaded. The service text is made in Core, which cannot see the
/// chat's messages, so the quote is added here at display time.
- (NSString *)serviceLineForMessage:(NSDictionary *)m {
	NSString *separator = m[@"separator"];
	NSString *who = separator ? nil
			: [[TGClient shared] nameForUserId:[m[@"senderId"] longLongValue]];
	id rawText = m[@"text"];
	NSString *text = [rawText isKindOfClass:NSString.class] ? rawText : @"";
	NSString *line = text;
	if (who.length && ![text hasPrefix:@"Group "] && ![text hasPrefix:@"Chat "] &&
			![text hasPrefix:@"Screenshot "] && ![text hasPrefix:@"You "]) {
		line = [NSString stringWithFormat:@"%@ %@", who, text];
	}

	NSString *kind = [m[@"kind"] isKindOfClass:NSString.class] ? m[@"kind"] : @"";
	if (![kind isEqualToString:@"messagePinMessage"])
		return line;

	id rawId = m[@"pinnedMessageId"];
	if (![rawId isKindOfClass:NSNumber.class] && ![rawId isKindOfClass:NSString.class])
		return line;
	int64_t pinnedId = [rawId longLongValue];
	if (pinnedId == 0)
		return line;

	for (id candidate in self.messages) {
		if (![candidate isKindOfClass:NSDictionary.class])
			continue;
		id candidateId = candidate[@"id"];
		if (![candidateId isKindOfClass:NSNumber.class] &&
				![candidateId isKindOfClass:NSString.class])
			continue;
		if ([candidateId longLongValue] == pinnedId)
			return TGPinnedLine(line, candidate);
	}
	return line;
}

/// A picture with no caption carries its own stamp on a plate, so the bubble
/// does not need a strip of empty space under it for one. Caption above puts
/// the picture at the bottom of the bubble, so the stamp sits on it too.
- (BOOL)stampSitsOnPictureFor:(NSDictionary *)m {
	if ([m[@"captionAbove"] isKindOfClass:[NSNumber class]] && [m[@"captionAbove"] boolValue])
		return YES;
	if ([m[@"isAlbum"] boolValue] && [self bodySizeFor:m].height == 0)
		return YES;
	return [self imageSizeFor:m].height > 0 && [self bodySizeFor:m].height == 0 &&
		   ![m[@"kind"] isEqualToString:@"messageVideoNote"];
}

- (CGSize)bodySizeFor:(NSDictionary *)m {
	if ([m[@"kind"] isEqualToString:@"messageSticker"] || [m[@"kind"] isEqualToString:@"messageAnimatedEmoji"])
		return CGSizeZero;
	NSString *text = m[@"text"] ?: @"";
	if (!text.length)
		return CGSizeZero;
	return TGTextSizeWithEntities(text, m[@"entities"], TGFontAtSize([TGTheme shared].messageFontSize),
			kBubbleMaxW - TGDoubled(kPadH));
}

static UIImage *TGImageFromMinithumbnail(id mini) {
	NSData *data = nil;
	if ([mini isKindOfClass:NSData.class]) {
		data = (NSData *)mini;
	} else if ([mini isKindOfClass:NSDictionary.class]) {
		NSString *b64 = mini[@"data"];
		if ([b64 isKindOfClass:NSString.class] && b64.length)
			data = TGBase64Decode(b64);
	} else if ([mini isKindOfClass:NSString.class]) {
		data = TGBase64Decode((NSString *)mini);
	}
	if (data.length) {
		return [UIImage imageWithData:data];
	}
	return nil;
}

- (UIImage *)imageFor:(NSDictionary *)m {
	UIImage *map = self.maps[m[@"id"]];
	if (map)
		return map;
	if ([m[@"paidPreview"] boolValue]) {
		NSNumber *msgId = m[@"id"];
		if ([msgId isKindOfClass:NSNumber.class]) {
			UIImage *cached = self.images[msgId];
			if (cached)
				return cached;
		}
		id mini = nil;
		NSDictionary *paid = m[@"paidMedia"];
		if ([paid isKindOfClass:NSDictionary.class]) {
			NSArray *items = paid[@"items"];
			if ([items isKindOfClass:NSArray.class] && items.count > 0 && [items[0] isKindOfClass:NSDictionary.class]) {
				mini = items[0][@"minithumbnail"];
			}
		}
		if (!mini) {
			mini = m[@"minithumbnail"];
		}
		UIImage *decoded = TGImageFromMinithumbnail(mini);
		if (decoded) {
			if ([msgId isKindOfClass:NSNumber.class]) {
				self.images[msgId] = decoded;
			}
			return decoded;
		}
	}
	NSNumber *fileId = m[@"photoId"];
	if ([fileId isKindOfClass:NSNumber.class]) {
		UIImage *cached = self.images[fileId];
		if (cached)
			return cached;
#if TG_DEV
		if (fileId.longLongValue < 0 || TGIsDevChat(self.chatId)) {
			UIImage *fixture = [TGDevShowcase imageForPhotoId:fileId.longLongValue];
			if (fixture)
				return fixture;
		}
#endif
	}
	return nil;
}

- (CGSize)imageSizeFor:(NSDictionary *)m {
	CGFloat w = 0, h = 0;
	if ([m[@"paidPreview"] boolValue] && [m[@"mediaWidth"] floatValue] > 0 && [m[@"mediaHeight"] floatValue] > 0) {
		w = [m[@"mediaWidth"] floatValue];
		h = [m[@"mediaHeight"] floatValue];
	} else {
		UIImage *img = [self imageFor:m];
		if (img) {
			w = img.size.width;
			h = img.size.height;
		} else if ([m[@"mediaWidth"] floatValue] > 0 && [m[@"mediaHeight"] floatValue] > 0) {
			w = [m[@"mediaWidth"] floatValue];
			h = [m[@"mediaHeight"] floatValue];
		} else if ([m[@"photoId"] isKindOfClass:NSNumber.class]) {
			w = kImageMax;
			h = kImageMax * TGMetricMediaRatioLandscape;
		}
	}
	if (w <= 0 || h <= 0)
		return CGSizeZero;

	CGFloat scale = MIN(kImageMax / w, kImageMax / h);
	scale = MIN(scale, TGMetricScaleFull);
	return CGSizeMake(floorf(w * scale), floorf(h * scale));
}

/// Cards, polls and checklists from someone else in a group say who sent
/// them, like every other bubble: a name line on top, the avatar beside the
/// bubble's foot. Returns the bubble height with the name line in it.
- (CGFloat)placeGroupSender:(TGMessageLayout *)layout message:(NSDictionary *)m
					   mine:(BOOL)mine width:(CGFloat)width height:(CGFloat)height x:(CGFloat *)x {
	NSString *senderName = (self.isGroup && !mine)
			? [[TGClient shared] nameForUserId:[m[@"senderId"] longLongValue]] : nil;
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

- (TGMessageLayout *)layoutForMessage:(NSDictionary *)m atRow:(NSInteger)row {
	NSNumber *msgId = m[@"id"];
	BOOL runStart = [self runStartsAtRow:row];
	BOOL runEnd = [self runEndsAtRow:row];
	if (msgId) {
		TGMessageLayout *hit = self.layoutCache[msgId];
		// Loading older or newer history re-groups the whole array, so a
		// message that opened a run can end up in the middle of one. Its
		// height moves with the run gap while its cached frames do not, and
		// the two drift apart into bubbles that overlap their neighbours.
		if (hit && hit.runStart == runStart && hit.runEnd == runEnd)
			return hit;
	}

	TGMessageLayout *layout = [[TGMessageLayout alloc] init];
	double layoutStart = TGPerfNow();
	layout.runStart = runStart;
	layout.runEnd = runEnd;
	CGFloat tableW = self.table.bounds.size.width;
	if (tableW <= 0) tableW = TGMetricScreenWidth;

	BOOL mine = [m[@"outgoing"] boolValue];
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
	TGMessageCard *card = (isService && !isCommunityCard) ? nil : TGChatCardForRow(m);
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
	layout.stamp = [self stampFor:m];
	layout.timeWidth = [self timeWidthFor:m];

	NSString *separator = m[@"separator"];
	if ([separator isEqualToString:@"unread"]) {
		// A full-width bar, not a plate: it marks a place, not an event.
		layout.isService = YES;
		layout.bubbleFrame = CGRectMake(TGMetricZero, TGCenteredOrigin(kServiceRow, kUnreadBar),
				tableW, kUnreadBar);
		layout.bodyFrame = CGRectMake(TGMetricZero, TGCenteredOrigin(kUnreadBar, TGMetricLineBody),
				tableW, TGMetricLineBody);
		layout.rowHeight = kServiceRow;
		return layout;
	}

	if (isService && !layout.isCard) {
		NSString *line = [self serviceLineForMessage:m];
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
		if (msgId) self.layoutCache[msgId] = layout;
		return layout;
	}

	if (card) {
		CGFloat width = kBubbleMaxW;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		CGFloat cardH = TGMessageCardLayout(card, width - TGDoubled(kPadH)).size.height;
		CGFloat height = [self placeGroupSender:layout message:m mine:mine width:width
				height:kPadV + cardH + kPadV + kPollStampRoom x:&x];
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		if (msgId) self.layoutCache[msgId] = layout;
		return layout;
	}

	if (isChecklist) {
		CGFloat width = kBubbleMaxW;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		CGFloat height = [self placeGroupSender:layout message:m mine:mine width:width
				height:[self checklistHeightFor:m] x:&x];
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		if (msgId) self.layoutCache[msgId] = layout;
		return layout;
	}

	if (isPoll) {
		CGFloat width = kBubbleMaxW;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		CGFloat height = [self placeGroupSender:layout message:m mine:mine width:width
				height:[self pollHeightFor:m] x:&x];
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		if (msgId) self.layoutCache[msgId] = layout;
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
		if (msgId) self.layoutCache[msgId] = layout;
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
		if (msgId) self.layoutCache[msgId] = layout;
		return layout;
	}

	if (isContact) {
		CGFloat width = kContactBubble;
		CGFloat height = kContactBubbleH + forwarded;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		if (msgId) self.layoutCache[msgId] = layout;
		return layout;
	}

	if (isLocation) {
		NSNumber *lat = m[@"lat"], *lon = m[@"lon"];
		if ([lat isKindOfClass:NSNumber.class] && [lon isKindOfClass:NSNumber.class] && !self.maps[m[@"id"]]) {
			self.maps[m[@"id"]] = [self mapCardForLatitude:lat.doubleValue longitude:lon.doubleValue];
		}
		CGFloat width = kLocationBubble;
		CGFloat height = kLocationBubbleH + forwarded;
		CGFloat x = mine ? (tableW - width - TGMetricPad) : TGMetricPad;
		layout.bubbleFrame = CGRectMake(x, TGMetricBubbleRowInset, width, height);
		layout.rowHeight = height + TGDoubled(TGMetricBubbleRowInset);
		if (msgId) self.layoutCache[msgId] = layout;
		return layout;
	}

	CGSize body = [self bodySizeFor:m];
	CGSize pic  = [self imageSizeFor:m];
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
		layout.stamp = [self stampFor:m];
		if (msgId) self.layoutCache[msgId] = layout;
		return layout;
	}

	BOOL hasAnimatedStickerPath = self.lottiePaths[m[@"docId"]] != nil;
	BOOL isAnimatedFormat = [m[@"docName"] isEqualToString:@"tgs"] || [m[@"docName"] isEqualToString:@"webm"];
	if ([TGCapabilities canPlayAnimatedStickers] && isAnimatedFormat && hasAnimatedStickerPath) {
		CGFloat side = kLottieSide;
		layout.bubbleFrame = CGRectMake(mine ? (tableW - side - TGMetricPad) : TGMetricPad,
				TGMetricBubbleRowInset, side, side + TGMetricLineMicro);
		layout.rowHeight = side + TGMetricLineMicro + TGDoubled(TGMetricBubbleRowInset);
		if (msgId) self.layoutCache[msgId] = layout;
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
			[itemFrames addObject:[NSValue valueWithCGRect:CGRectMake(0, 0, halfW, collageH)]];
			[itemFrames addObject:[NSValue valueWithCGRect:CGRectMake(halfW + gap, 0, halfW, collageH)]];
		} else if (count == 3) {
			CGFloat topH = TGMetricCollageTopHeight;
			CGFloat botH = TGMetricCollageBottomHeight;
			collageH = topH + gap + botH;
			[itemFrames addObject:[NSValue valueWithCGRect:CGRectMake(0, 0, collageW, topH)]];
			[itemFrames addObject:[NSValue valueWithCGRect:CGRectMake(0, topH + gap, halfW, botH)]];
			[itemFrames addObject:[NSValue valueWithCGRect:CGRectMake(halfW + gap, topH + gap, halfW, botH)]];
		} else {
			CGFloat halfH = TGMetricCollageQuadHeight;
			collageH = TGDoubled(halfH) + gap;
			[itemFrames addObject:[NSValue valueWithCGRect:CGRectMake(0, 0, halfW, halfH)]];
			[itemFrames addObject:[NSValue valueWithCGRect:CGRectMake(halfW + gap, 0, halfW, halfH)]];
			[itemFrames addObject:[NSValue valueWithCGRect:CGRectMake(0, halfH + gap, halfW, halfH)]];
			[itemFrames addObject:[NSValue valueWithCGRect:CGRectMake(halfW + gap, halfH + gap, halfW, halfH)]];
		}
		layout.albumFrames = itemFrames;
	}

	int64_t senderId = [m[@"senderId"] longLongValue];
	NSString *senderName = (self.isGroup && !mine) ? [[TGClient shared] nameForUserId:senderId] : nil;
	NSString *senderTag = m[@"senderTag"];
	if (senderName.length && [senderTag isKindOfClass:NSString.class] && senderTag.length)
		senderName = [NSString stringWithFormat:@"%@ · %@", senderName, senderTag];

	BOOL stampOnPicture = [self stampSitsOnPictureFor:m];
	BOOL inlineStamp = !stampOnPicture && [self stampFitsInlineFor:m];
	NSString *lpSite = m[@"linkPreviewSite"];
	NSString *lpTitle = m[@"linkPreviewTitle"];
	NSString *lpDesc = m[@"linkPreviewDesc"];
	NSString *lpUrl = m[@"linkPreviewUrl"];
	BOOL hasLinkPreview = !isService && (lpTitle.length > 0 || lpDesc.length > 0 || lpSite.length > 0);
	if (hasLinkPreview) inlineStamp = NO;
	CGFloat timeW = [self timeWidthFor:m];
	CGFloat contentW = MAX(body.width, pic.width);
	if (isAlbum)
		contentW = MAX(contentW, collageW);
	NSString *quoted = [self quoteTextFor:m];
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
	if (senderName.length) {
		CGFloat senderW = TGTextSize(senderName, TGFontMetaStrong(), 0).width;
		contentW = MAX(contentW, senderW);
	}

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

	stampOnPicture = [self stampSitsOnPictureFor:m];
	CGFloat bubbleH = TGDoubled(kPadV) + senderH
			+ (inlineStamp || stampOnPicture ? TGMetricZero : TGMetricLineMicro)
			+ [self decorationHeightFor:m]
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
	CGFloat top = [self continuesAlbumAtRow:row] ? TGMetricZero : TGMetricBubbleRowInset;

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
	layout.stamp = [self stampFor:m];
	layout.quoteText = quoted;
	layout.quoteAuthor = [self quoteAuthorFor:m];

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

	CGFloat rowH = TGDoubled(kPadV) + [self decorationHeightFor:m] +
			(inlineStamp || stampOnPicture ? TGMetricZero : TGMetricLineMicro);
	if (self.isGroup && !mine && senderName.length)
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
	// A slow row names its kind, so scrolling or the initial burst can be
	// associated with what exactly measured heavy.
	TGPerfReport("layout", kind.length ? [kind UTF8String] : "?",
			layoutStart, 20.0);

	if (msgId) self.layoutCache[msgId] = layout;
	return layout;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *m = self.messages[indexPath.row];
	TGMessageLayout *layout = [self layoutForMessage:m atRow:indexPath.row];
	return layout.rowHeight + [self runHeightChangeAtRow:indexPath.row layout:layout];
}

@end
