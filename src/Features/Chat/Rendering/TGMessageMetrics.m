#import "TGMessageMetrics.h"
#import "TGLocalization.h"
#import "TGPollPresentation.h"
#import "TGPinnedLine.h"
#import "TGUIFormat.h"

CGFloat TGPollOptionRowHeight(NSDictionary *option, CGFloat rowWidth) {
	CGFloat textW = rowWidth - kPollTextColumn - kPollShareWidth - TGMetricPadTiny;
	CGFloat textH = TGTextSize(TGPollOptionText(option), TGFontSubhead(), textW).height;
	return MAX(kPollRow, textH + TGDoubled(TGMetricPadTiny));
}

static int64_t TGMessageViewCount(NSDictionary *m) {
	id raw = m[@"viewCount"];
	return [raw respondsToSelector:@selector(longLongValue)] ? [raw longLongValue] : 0;
}

NSString *TGMessageStampText(NSDictionary *m) {
	NSString *time = TGMessageStamp([m[@"date"] doubleValue], [m[@"edited"] boolValue]);
	// An imported message keeps the day it was first written
	// (Message.ImportedDateFormat).
	double imported = [m[@"importDate"] doubleValue];
	if (imported > 0)
		time = TGLocalizedFormat(@"%1$@, %2$@ Imported %3$@",
				TGAppDate(imported, NSDateFormatterShortStyle, NSDateFormatterNoStyle) ?: @"",
				TGMessageStamp(imported, NO), time);
	int64_t viewCount = TGMessageViewCount(m);
	if (viewCount <= 0)
		return time;
	NSString *count = TGCompactCount(viewCount);
	id rawSig = m[@"authorSignature"];
	NSString *sig = [rawSig isKindOfClass:NSString.class] ? rawSig : @"";
	if (sig.length > 16)
		sig = [[sig substringToIndex:16] stringByAppendingString:@"..."];
	if (sig.length > 0)
		return [NSString stringWithFormat:@"%@ %@, %@", count, sig, time];
	return [NSString stringWithFormat:@"%@ %@", count, time];
}

CGFloat TGMessageStampWidth(NSDictionary *m) {
	CGFloat w = TGTextSize(TGMessageStampText(m), TGFontMicro(), 0).width + TGMetricPadTiny;
	if (TGMessageViewCount(m) > 0)
		w += kStampEyeSide + kStampEyePad - TGMetricPadTiny;
	if ([m[@"outgoing"] boolValue])
		w += TGMetricStampTicksRoom;
	return w;
}

NSString *TGMessageBoostBadgeText(NSDictionary *m) {
	NSInteger boosts = [m[@"boostCount"] integerValue];
	if (boosts <= 0 || [m[@"outgoing"] boolValue])
		return nil;
	return boosts > 1 ? [NSString stringWithFormat:@"%ld", (long)boosts] : @"";
}

CGFloat TGMessageBoostBadgeWidth(NSDictionary *m) {
	NSString *text = TGMessageBoostBadgeText(m);
	if (!text)
		return 0;
	CGFloat w = TGMetricPadSmall + TGMetricLineMicro;
	if (text.length)
		w += TGTextSize(text, TGFontMicro(), 0).width;
	return ceilf(w);
}

CGSize TGLinkPreviewMediaSize(NSDictionary *m, CGFloat columnW) {
	if (![m[@"linkPreviewPhotoId"] isKindOfClass:NSNumber.class])
		return CGSizeZero;
	if (![m[@"linkPreviewLarge"] boolValue])
		return CGSizeMake(kLinkThumbSide, kLinkThumbSide);
	CGFloat w = [m[@"linkPreviewPhotoW"] floatValue], h = [m[@"linkPreviewPhotoH"] floatValue];
	CGFloat height = (w > 0 && h > 0) ? roundf(columnW * h / w) : roundf(columnW * 0.75f);
	return CGSizeMake(columnW, MIN(height, kImageMax));
}

BOOL TGMessageStampFitsInline(NSDictionary *m, CGFloat fontSize) {
	NSString *text = m[@"text"] ?: @"";
	if (!text.length || [text rangeOfString:@"\n"].location != NSNotFound)
		return NO;
	CGFloat room = kBubbleMaxW - TGDoubled(kPadH);
	CGFloat oneLine = TGTextSize(text, TGFontAtSize(fontSize), 0).width;
	if (oneLine > room)
		return NO;   // it wraps, so there is no short last line to share
	return oneLine + kStampGap + TGMessageStampWidth(m) <= room;
}

static BOOL TGMessageAnswers(NSDictionary *m) {
	return [m[@"replyId"] isKindOfClass:NSNumber.class];
}

NSString *TGMessageQuoteText(NSDictionary *m, NSDictionary *replied) {
	if (!TGMessageAnswers(m))
		return nil;
	NSString *inline_ = m[@"replyText"];
	if (inline_.length)
		return inline_;
	return replied ? TGDescribeMessageContent(replied) : @"...";
}

NSArray *TGMessageQuoteEntities(NSDictionary *m, NSDictionary *replied) {
	if (!TGMessageAnswers(m))
		return nil;
	NSArray *entities = nil;
	if ([m[@"replyText"] length])
		entities = m[@"quoteEntities"];
	else if ([replied[@"text"] length])
		entities = replied[@"entities"];
	return [entities isKindOfClass:NSArray.class] ? entities : nil;
}

NSString *TGMessageQuoteAuthor(NSDictionary *replied, NSString *senderName) {
	if (!replied)
		return nil;
	return [replied[@"outgoing"] boolValue] ? TGLocalized(@"You") : senderName;
}

NSString *TGMessageCommentsTitle(NSInteger count) {
	if (count <= 0)
		return TGLocalized(@"Leave a Comment");
	return TGLocalizedPlural(@"%d Comment", @"%d Comments", count);
}

CGFloat TGMessageDecorationHeight(NSDictionary *m, BOOL hasQuote) {
	CGFloat h = TGMetricZero;
	if ([m[@"forward"] length])
		h += TGMetricQuoteForwardLine;
	// Their reply block is two lines beside a stripe: the author, then what
	// they said.
	if (hasQuote)
		h += kQuoteBlock;
	// The "12 Comments" footer under a channel post.
	if ([m[@"canComment"] boolValue])
		h += kCommentsBar;
	// A bot's buttons, a row each.
	NSUInteger rows = [m[@"inlineRows"] count];
	if (rows)
		h += rows * (TGMetricBotButtonHeight + TGMetricBotButtonGap) + TGMetricBotButtonGap;
	return h;
}

CGFloat TGMessageChecklistHeight(NSDictionary *m) {
	NSDictionary *checklist = [m[@"checklist"] isKindOfClass:NSDictionary.class]
			? m[@"checklist"] : @{};
	NSString *title = [checklist[@"title"] isKindOfClass:NSString.class]
			? checklist[@"title"] : @"Checklist";
	NSArray *tasks = [checklist[@"tasks"] isKindOfClass:NSArray.class]
			? checklist[@"tasks"] : @[];

	CGFloat contentW = kBubbleMaxW - TGDoubled(kPadH);
	CGFloat textW = contentW - kChecklistTextColumn;
	CGFloat height = kPadV + TGTextSize(title, TGFontBodyStrong(), contentW).height;
	if (tasks.count)
		height += kChecklistTitleGap;
	for (id raw in tasks) {
		NSDictionary *task = [raw isKindOfClass:NSDictionary.class] ? raw : @{};
		NSString *text = [task[@"text"] isKindOfClass:NSString.class] ? task[@"text"] : @"";
		height += MAX(kChecklistRow, TGTextSize(text, TGFontBody(), textW).height);
	}
	return height + kChecklistProgressGap + kChecklistProgressLine + kChecklistStampRoom;
}

CGFloat TGMessagePollHeight(NSDictionary *m, NSIndexSet *pendingVotes) {
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

	BOOL showVote = [poll[@"allowsMultiple"] boolValue]
			&& ![poll[@"isClosed"] boolValue]
			&& !TGPollShowsResults(poll)
			&& [pendingVotes isKindOfClass:NSIndexSet.class] && pendingVotes.count > 0;
	BOOL showExplanation = TGPollShowsResults(poll) && explanation.length > 0;

	CGFloat textW = kBubbleMaxW - TGDoubled(kPadH);
	CGFloat descriptionH = description.length
			? TGTextSize(description, TGFontSubhead(), textW).height : TGMetricZero;
	CGFloat explanationH = showExplanation
			? TGTextSize(explanation, TGFontCaption(), textW).height : TGMetricZero;

	CGFloat height = kPadV + TGTextSize(question, TGFontBodyStrong(), textW).height;
	if (descriptionH > TGMetricZero)
		height += kPollDescriptionGap + descriptionH;
	height += kPollKindGap + kPollKindLine + kPollOptionsGap;
	for (NSDictionary *option in options)
		height += TGPollOptionRowHeight(option, textW);
	if (showVote)
		height += kPollVoteGap + kPollVoteHeight;
	if (explanationH > TGMetricZero)
		height += kPollExplanationGap + explanationH;
	return height + kPollFooterGap + kPollFooterLine + kPollStampRoom;
}

NSString *TGMessageServiceLine(NSDictionary *m, NSString *who, NSArray *messages) {
	id rawText = m[@"text"];
	NSString *text = [rawText isKindOfClass:NSString.class] ? rawText : @"";
	NSString *line = text;
	if (who.length && ![text hasPrefix:@"Group "] && ![text hasPrefix:@"Chat "] &&
			![text hasPrefix:@"Screenshot "] && ![text hasPrefix:@"You "])
		line = [NSString stringWithFormat:@"%@ %@", who, text];

	NSString *kind = [m[@"kind"] isKindOfClass:NSString.class] ? m[@"kind"] : @"";
	if (![kind isEqualToString:@"messagePinMessage"])
		return line;
	id rawId = m[@"pinnedMessageId"];
	if (![rawId isKindOfClass:NSNumber.class] && ![rawId isKindOfClass:NSString.class])
		return line;
	int64_t pinnedId = [rawId longLongValue];
	if (pinnedId == 0)
		return line;
	for (id candidate in messages) {
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

CGFloat TGStampEyeX(CGFloat textRight, NSString *stampText) {
	CGFloat words = TGTextSize(stampText ?: @"", TGFontMicro(), 0).width;
	return textRight - words - kStampEyePad - kStampEyeSide;
}

TGMessageStampParts TGMessageStampPlace(NSDictionary *m, CGFloat right, CGFloat midY) {
	TGMessageStampParts p;
	CGFloat lineY = midY - TGHalf(TGMetricStampHeight);
	CGFloat x = right;
	p.ticks = CGRectZero;
	if ([m[@"outgoing"] boolValue]){
		x -= TGMetricStampTicksRoom;
		p.ticks = CGRectMake(right - TGMetricTicksWidth,
				midY - TGHalf(TGMetricTicksHeight), TGMetricTicksWidth, TGMetricTicksHeight);
	}
	CGFloat textW = TGTextSize(TGMessageStampText(m), TGFontMicro(), 0).width + TGMetricPadTiny;
	x -= textW;
	p.text = CGRectMake(x, lineY, textW, TGMetricStampHeight);
	p.eye = CGRectZero;
	if (TGMessageViewCount(m) > 0){
		x = TGStampEyeX(x + textW, TGMessageStampText(m));
		p.eye = CGRectMake(x, midY - TGHalf(kStampEyeSide), kStampEyeSide, kStampEyeSide);
	}
	p.width = right - x;
	return p;
}

CGRect TGMessageStampPlate(NSDictionary *m, CGFloat right, CGFloat bottom,
		TGMessageStampParts *parts) {
	CGFloat plateH = TGMetricLineCaption;
	CGFloat midY = bottom - TGHalf(plateH);
	TGMessageStampParts placed = TGMessageStampPlace(m, right - TGMetricPadSmall, midY);
	if (parts)
		*parts = placed;
	CGFloat plateW = placed.width + TGDoubled(TGMetricPadSmall);
	return CGRectMake(right - plateW, bottom - plateH, plateW, plateH);
}
