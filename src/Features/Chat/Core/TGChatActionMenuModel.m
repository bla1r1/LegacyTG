#import "TGChatActionMenuModel.h"
#import "TGLocalization.h"
#import "TGPollPresentation.h"
#import "TGStyle.h"
#import "TGUIFormat.h"
#include <math.h>

static NSDictionary *TGRow(NSString *title, NSString *action, NSString *icon,
		BOOL destructive) {
	if (!title.length)
		return nil;
	return @{
		@"title" : title,
		@"action" : action ?: title,
		@"icon" : icon ?: @"",
		@"destructive" : @(destructive),
	};
}

static NSString *TGMessageText(NSDictionary *message) {
	return [message[@"text"] isKindOfClass:NSString.class] ? message[@"text"] : @"";
}

static BOOL TGMessageIsService(NSDictionary *message) {
	return [message[@"service"] boolValue];
}

static BOOL TGMessageIsSaveable(NSDictionary *message) {
	return ![message[@"canBeSaved"] isEqual:@NO];
}

static BOOL TGMessageIsSticker(NSDictionary *message) {
	if (![message[@"kind"] isEqualToString:@"messageSticker"])
		return NO;
	return [message[@"docId"] isKindOfClass:NSNumber.class] ||
			[message[@"photoId"] isKindOfClass:NSNumber.class];
}

/// A message whose `text` came from the sender rather than from a media
/// placeholder. Official only offers Quote, Translate and Speak on text that
/// is actually there: a caption or a text/rich message, never a voice note
/// described as "Voice message".
static BOOL TGMessageHasBodyText(NSDictionary *message) {
	NSString *caption = [message[@"caption"] isKindOfClass:NSString.class]
			? message[@"caption"] : @"";
	if (caption.length)
		return YES;
	NSString *kind = [message[@"kind"] isKindOfClass:NSString.class]
			? message[@"kind"] : @"";
	NSString *text = TGMessageText(message);
	if ([kind isEqualToString:@"messageText"] ||
			[kind isEqualToString:@"messageRichMessage"])
		return text.length > 0;
	// A flattened row from an older caller may not name its kind; its text is
	// then the only evidence, and media rows always carry one.
	if (!kind.length)
		return text.length > 0;
	return NO;
}

static BOOL TGMessageIsChecklist(NSDictionary *message) {
	return [message[@"kind"] isEqualToString:@"messageChecklist"];
}

static CGSize TGComposerSizedText(NSString *text, CGFloat width) {
	if (!text.length || width <= 0.0f)
		return CGSizeZero;
	UIFont *font = TGFontBody();
	return [text sizeWithFont:font
			constrainedToSize:CGSizeMake(width, CGFLOAT_MAX)
				lineBreakMode:NSLineBreakByWordWrapping];
}

CGFloat TGChatComposerLineHeight(void) {
	return TGMetricLineBody;
}

NSInteger TGChatComposerMaxLines(void) {
	return TGMetricComposerMaxLines;
}

CGFloat TGChatComposerFieldHeightForLines(NSInteger lines) {
	if (lines < 1)
		lines = 1;
	if (lines > TGMetricComposerMaxLines)
		lines = TGMetricComposerMaxLines;
	return TGMetricComposerFieldMinHeight +
			((CGFloat)(lines - 1) * TGMetricLineBody);
}

NSInteger TGChatComposerLineCount(NSString *text, CGFloat width) {
	if (![text isKindOfClass:NSString.class] || !text.length)
		return 1;
	CGSize size = TGComposerSizedText(text, width);
	if (size.height <= 0.0f)
		return 1;
	NSInteger lines = (NSInteger)ceil(size.height / TGMetricLineBody);
	return MAX(1, lines);
}

CGFloat TGChatComposerBarHeightForLines(NSInteger lines) {
	return TGChatComposerFieldHeightForLines(lines) +
			TGDoubled(TGMetricComposerBarInsetV);
}

CGRect TGChatComposerFieldFrame(CGFloat barWidth, CGFloat barHeight,
		CGFloat fieldHeight) {
	CGFloat sendX = MAX(0.0f, barWidth - TGMetricSendSide -
			TGMetricComposerSendInset);
	CGFloat left = TGMetricComposerFieldLeft;
	CGFloat right = MAX(left, sendX - TGMetricPadSmall);
	CGFloat y = MAX(0.0f, barHeight - TGMetricComposerBarInsetV - fieldHeight);
	return CGRectMake(left, y, right - left, fieldHeight);
}

CGRect TGChatComposerSendFrame(CGFloat barWidth, CGFloat barHeight) {
	CGFloat x = MAX(0.0f, barWidth - TGMetricSendSide -
			TGMetricComposerSendInset);
	CGFloat y = MAX(0.0f, barHeight - TGMetricComposerBarInsetV -
			TGMetricSendSide);
	return CGRectMake(x, y, TGMetricSendSide, TGMetricSendSide);
}

CGFloat TGChatComposerTextWidth(CGFloat barWidth) {
	return MAX(1.0f, TGChatComposerFieldFrame(barWidth, TGMetricInputBarHeight,
			TGChatComposerFieldHeightForLines(1)).size.width - kFieldLeftPad - TGMetricSendSide);
}

TGChatComposerFrames TGChatComposerPlace(CGFloat width, CGFloat bottom, NSInteger lines) {
	TGChatComposerFrames f;
	f.barHeight = TGChatComposerBarHeightForLines(lines);
	f.scrolls = lines > TGChatComposerMaxLines();
	f.well = TGChatComposerFieldFrame(width, f.barHeight, TGChatComposerFieldHeightForLines(lines));
	f.send = TGChatComposerSendFrame(width, f.barHeight);
	CGFloat controlY = CGRectGetMinY(f.send);
	f.bar = CGRectMake(0, bottom - f.barHeight, width, f.barHeight);
	// The text stops short of the sticker toggle sitting in the well.
	f.text = f.well;
	f.text.size.width = MAX(0.0f, f.text.size.width - TGMetricSendSide);
	f.sticker = CGRectMake(CGRectGetMaxX(f.well) - TGMetricSendSide, controlY,
			TGMetricSendSide, TGMetricSendSide);
	f.attach = CGRectMake(kComposerInset, controlY, kAttachWidth, TGMetricSendSide);
	f.ai = CGRectMake(kComposerInset, controlY - TGMetricSendSide, kAttachWidth, TGMetricSendSide);
	f.table = CGRectMake(0, 0, width, bottom - f.barHeight);
	return f;
}

TGChatComposeBannerFrames TGChatComposeBannerPlace(CGFloat width, CGFloat barTop,
		BOOL twoLines) {
	TGChatComposeBannerFrames f;
	CGFloat textW = width - TGMetricComposeBannerTextMarginRight;
	f.plate = CGRectMake(0, barTop - kComposeBannerHeight, width, kComposeBannerHeight);
	f.stripe = CGRectMake(kBannerStripeX, kBannerStripeTop, TGMetricPadTiny,
			kComposeBannerHeight - TGDoubled(kBannerStripeTop));
	f.title = CGRectMake(kBannerTextX, twoLines ? kBannerTitleTop
			: TGHalf(kComposeBannerHeight) - TGHalf(TGMetricLineSubhead),
			textW, TGMetricLineSubhead);
	f.subtitle = CGRectMake(kBannerTextX, kBannerTitleTop + TGMetricLineSubhead,
			textW, TGMetricLineSubhead);
	f.close = CGRectMake(width - TGMetricRow, 0, TGMetricRow, kComposeBannerHeight);
	return f;
}

void TGChatComposerAboveKeyboard(CGSize viewSize, CGFloat barHeight,
		CGFloat keyboardHeight, CGRect *bar, CGRect *table) {
	*bar = CGRectMake(0, viewSize.height - barHeight - keyboardHeight, viewSize.width, barHeight);
	*table = CGRectMake(0, 0, viewSize.width, viewSize.height - barHeight - keyboardHeight);
}

#pragma mark - AI composer

NSArray<NSString *> *TGAiComposeModeTitles(void) {
	static NSArray<NSString *> *titles;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		titles = @[TGLocalized(@"Translate"), TGLocalized(@"Style"),
				TGLocalized(@"Fix")];
	});
	return titles;
}

NSArray<NSDictionary *> *TGAiComposeStyleChoices(void) {
	static NSArray<NSDictionary *> *choices;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		// These are the server style names composeTextWithAi accepts. The UI
		// shows the title-cased name, never the request key; neutral is the
		// original and is not a chip, as official does not list it either.
		NSArray *keys = @[@"formal", @"casual", @"excited"];
		NSMutableArray *rows = [NSMutableArray arrayWithCapacity:keys.count];
		for (NSString *key in keys) {
			[rows addObject:@{@"title" : key.capitalizedString, @"key" : key}];
		}
		choices = rows;
	});
	return choices;
}

static BOOL TGTextHasCodePointInRange(NSString *text, unichar first, unichar last) {
	NSUInteger limit = MIN(text.length, (NSUInteger)256);
	for (NSUInteger i = 0; i < limit; i++) {
		unichar c = [text characterAtIndex:i];
		if (c >= first && c <= last)
			return YES;
	}
	return NO;
}

static NSString *TGDetectedLanguage(NSString *text) {
	if (![text isKindOfClass:NSString.class] || !text.length)
		return nil;
	if (TGTextHasCodePointInRange(text, 0x0400, 0x04FF))
		return @"ru";
	if (TGTextHasCodePointInRange(text, 0x0370, 0x03FF))
		return @"el";
	if (TGTextHasCodePointInRange(text, 0x0590, 0x05FF))
		return @"he";
	if (TGTextHasCodePointInRange(text, 0x0600, 0x06FF))
		return @"ar";
	if (TGTextHasCodePointInRange(text, 0x0900, 0x097F))
		return @"hi";
	if (TGTextHasCodePointInRange(text, 0x0E00, 0x0E7F))
		return @"th";
	if (TGTextHasCodePointInRange(text, 0x3040, 0x30FF))
		return @"ja";
	if (TGTextHasCodePointInRange(text, 0x4E00, 0x9FFF))
		return @"zh";
	if (TGTextHasCodePointInRange(text, 0xAC00, 0xD7AF))
		return @"ko";
	return nil;
}

NSString *TGAiComposeSourceLanguage(NSString *text, NSString *chatLanguageCode,
		NSString *appLanguageCode) {
	NSString *detected = TGDetectedLanguage(text);
	if (detected.length)
		return detected;
	NSString *chat = [chatLanguageCode isKindOfClass:NSString.class]
			? chatLanguageCode.lowercaseString : @"";
	if (chat.length)
		return chat;
	NSString *app = [appLanguageCode isKindOfClass:NSString.class]
			? appLanguageCode.lowercaseString : @"";
	return app.length ? app : @"en";
}

NSString *TGAiComposeTargetLanguage(NSString *sourceLanguage,
		NSString *appLanguageCode) {
	NSString *source = [sourceLanguage isKindOfClass:NSString.class]
			? sourceLanguage.lowercaseString : @"";
	NSString *app = [appLanguageCode isKindOfClass:NSString.class]
			? appLanguageCode.lowercaseString : @"";
	if (app.length && ![app isEqualToString:source])
		return app;
	if ([source isEqualToString:@"en"])
		return @"ru";
	return @"en";
}

/// Official names a target language with the pack's Translation.Language.<code>
/// keys, not the device locale: "Перевести на английский", not "на English".
/// Looked up by key because the English values collide ("English" is the
/// pack's own name). Official spells Polish "po", not "pl"; kept as it is.
NSString *TGAiComposeLanguageName(NSString *languageCode) {
	if (![languageCode isKindOfClass:NSString.class] || !languageCode.length)
		return @"";
	static NSDictionary *official;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		official = @{
			@"en": @"English", @"ar": @"Arabic", @"zh": @"Chinese", @"fr": @"French",
			@"de": @"German", @"it": @"Italian", @"ja": @"Japanese", @"ko": @"Korean",
			@"pt": @"Portuguese", @"ru": @"Russian", @"es": @"Spanish",
			@"uk": @"Ukrainian", @"be": @"Belarusian", @"ca": @"Catalan",
			@"hr": @"Croatian", @"cs": @"Czech", @"nl": @"Dutch", @"eo": @"Esperanto",
			@"fi": @"Finnish", @"he": @"Hebrew", @"hu": @"Hungarian",
			@"id": @"Indonesian", @"ms": @"Malay", @"ml": @"Malayalam",
			@"no": @"Norwegian", @"fa": @"Persian", @"po": @"Polish",
			@"ro": @"Romanian", @"sr": @"Serbian", @"sk": @"Slovak",
			@"sv": @"Swedish", @"ta": @"Tamil", @"tr": @"Turkish", @"uz": @"Uzbek",
		};
	});
	NSString *code = [languageCode isEqualToString:@"pl"] ? @"po" : languageCode;
	// TGLocalizedKey falls back to a lookup by the English value, which for
	// "English" answers the pack's own name. A marker no pack holds tells a
	// missing key apart from a real translation.
	if (official[code]){
		NSString *marker = @"\u2063TGNoLanguageKey";
		NSString *value = TGLocalizedKey(
				[@"Translation.Language." stringByAppendingString:code], marker);
		if (value.length && ![value isEqualToString:marker])
			return value;
	}
	NSString *name = [[NSLocale currentLocale] displayNameForKey:NSLocaleLanguageCode
			value:languageCode];
	if (!name.length)
		name = official[code];
	return name.length ? name : languageCode;
}

NSArray<NSString *> *TGAiComposeLanguageChoices(void) {
	static NSArray<NSString *> *choices;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		choices = @[@"en", @"ru", @"uk", @"es", @"de", @"fr", @"it", @"pt",
				@"tr", @"ar"];
	});
	return choices;
}

NSDictionary *TGAiComposeInputModel(NSString *text, int64_t chatId,
		NSString *chatLanguageCode, NSString *appLanguageCode) {
	NSString *body = [text isKindOfClass:NSString.class] ? text : @"";
	NSString *source = TGAiComposeSourceLanguage(body, chatLanguageCode,
			appLanguageCode);
	NSString *target = TGAiComposeTargetLanguage(source, appLanguageCode);
	return @{
		@"chatId" : @(chatId),
		@"text" : body,
		@"sourceLanguage" : source,
		@"targetLanguage" : target,
		@"modes" : TGAiComposeModeTitles(),
	};
}

BOOL TGChatDrawableSize(CGSize size) {
	return isfinite(size.width) && isfinite(size.height) &&
			size.width >= 1.0f && size.height >= 1.0f;
}

BOOL TGChatComposerShowsAIEntry(NSString *text, CGFloat width) {
	NSString *trimmed = [text isKindOfClass:NSString.class]
			? [text stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]]
			: @"";
	if (!trimmed.length)
		return NO;
	return TGChatComposerLineCount(text, width) >= TGMetricComposerAIMinLines;
}

NSInteger TGChatActionMenuReactionCount(NSDictionary *message) {
	NSArray *groups = message[@"reactionGroups"];
	if (![groups isKindOfClass:NSArray.class])
		return 0;
	NSInteger total = 0;
	for (NSDictionary *group in groups) {
		if (![group isKindOfClass:NSDictionary.class])
			continue;
		NSNumber *count = group[@"count"];
		if ([count isKindOfClass:NSNumber.class])
			total += count.integerValue;
	}
	return total;
}

BOOL TGChatActionMenuShowsReadSummary(NSDictionary *message,
		TGChatActionMenuContext context) {
	if (!context.mine || context.isSavedMessages)
		return NO;
	if (!context.isGroup && !context.isChannel)
		return NO;
	// TDLib knows when the viewers list exists (a small group, recent).
	if (context.hasProperties && !context.canGetViewers && !context.isChannel)
		return NO;
	return !TGMessageIsService(message);
}

NSString *TGChatActionMenuSeenText(NSInteger viewerCount) {
	if (viewerCount <= 0)
		return TGLocalized(@"No views");
	return TGLocalizedFormat(@"%@ Seen",
			[NSString stringWithFormat:@"%ld", (long)viewerCount]);
}

NSString *TGChatActionMenuReactionText(NSInteger reactionCount) {
	if (reactionCount <= 0)
		return @"";
	return TGLocalizedPlural(@"%d reaction", @"%d reactions", reactionCount);
}

CGFloat TGHoldLiftY(CGRect bubble, CGFloat above, CGFloat below, CGFloat top, CGFloat bottom) {
	CGFloat y = CGRectGetMinY(bubble);
	CGFloat h = CGRectGetHeight(bubble);
	if (y - above < top)
		y = top + above;
	if (y + h + below > bottom)
		y = bottom - below - h;
	if (y - above < top)
		y = top + above;
	return y;
}

void TGChatActionMenuApplyProperties(TGChatActionMenuContext *context,
		NSDictionary *properties) {
	if (!context || ![properties isKindOfClass:NSDictionary.class] ||
		![properties[@"@type"] isEqualToString:@"messageProperties"])
		return;
	context->hasProperties = YES;
	context->canReply = context->canReply && [properties[@"can_be_replied"] boolValue];
	context->canEdit = [properties[@"can_be_edited"] boolValue];
	context->canPin = [properties[@"can_be_pinned"] boolValue];
	context->canCopy = [properties[@"can_be_copied"] boolValue];
	context->canDeleteForSelf = [properties[@"can_be_deleted_only_for_self"] boolValue];
	context->canDeleteForAll = [properties[@"can_be_deleted_for_all_users"] boolValue];
	context->canViewAuthor = [properties[@"can_get_author"] boolValue];
	context->canEditFactCheck = [properties[@"can_set_fact_check"] boolValue];
	context->canViewStats = [properties[@"need_show_statistics"] boolValue];
	context->canReport = [properties[@"can_report_chat"] boolValue] ||
			[properties[@"can_report_supergroup_spam"] boolValue];
	context->canEditMedia = [properties[@"can_edit_media"] boolValue];
	context->canGetViewers = [properties[@"can_get_viewers"] boolValue];
	context->canReportReactions = [properties[@"can_report_reactions"] boolValue];
	context->canGetThread = [properties[@"can_get_message_thread"] boolValue];
	context->canGetReadDate = [properties[@"can_get_read_date"] boolValue];
	context->protectedByMe = [properties[@"has_protected_content_by_current_user"] boolValue];
	context->protectedByOther = [properties[@"has_protected_content_by_other_user"] boolValue];
}

BOOL TGDeleteLosesPaidPostStars(NSArray<NSDictionary *> *messages, BOOL revoke,
		NSTimeInterval now) {
	if (!revoke || ![messages isKindOfClass:NSArray.class])
		return NO;
	for (NSDictionary *m in messages) {
		if (![m isKindOfClass:NSDictionary.class] || ![m[@"paidStarPost"] boolValue])
			continue;
		if ([m[@"date"] doubleValue] > now - 24 * 60 * 60)
			return YES;
	}
	return NO;
}

NSArray<NSDictionary *> *TGMessageDeleteChoices(BOOL isSaved, BOOL isGroup,
		NSDictionary *properties) {
	if (isSaved)
		return @[ @{ @"title" : TGLocalized(@"Delete"), @"revoke" : @YES } ];
	BOOL known = [properties isKindOfClass:NSDictionary.class] &&
			[properties[@"@type"] isEqualToString:@"messageProperties"];
	BOOL forAll = !known || [properties[@"can_be_deleted_for_all_users"] boolValue];
	BOOL forSelf = !known || [properties[@"can_be_deleted_only_for_self"] boolValue];
	NSMutableArray *choices = [NSMutableArray array];
	if (forAll)
		[choices addObject:@{ @"title" : isGroup ? TGLocalized(@"Delete for All")
										: TGLocalized(@"Delete for Everyone"), @"revoke" : @YES }];
	if (forSelf)
		[choices addObject:@{ @"title" : TGLocalized(@"Delete for me"), @"revoke" : @NO }];
	return choices;
}

NSArray<NSDictionary *> *TGChatActionMenuRows(NSDictionary *message,
		TGChatActionMenuContext context) {
	if (![message isKindOfClass:NSDictionary.class])
		return @[];

	NSMutableArray *rows = [NSMutableArray array];
	NSString *text = TGMessageText(message);
	BOOL service = TGMessageIsService(message);
	BOOL failed = [message[@"failed"] boolValue];
	BOOL saveable = TGMessageIsSaveable(message);
	BOOL bodyText = TGMessageHasBodyText(message);
	BOOL sticker = TGMessageIsSticker(message);
	NSArray *pollOptions = message[@"pollOptions"];

	void (^add)(NSString *, NSString *, NSString *, BOOL) =
			^(NSString *title, NSString *action, NSString *icon, BOOL destructive){
		NSDictionary *row = TGRow(title, action, icon, destructive);
		if (row)
			[rows addObject:row];
	};

	// Official inserts the author of a monoforum post at the very top and the
	// sticker's favourite toggle before the verbs. An ordinary incoming chat
	// message has neither, so the author row is not a property of "not mine".
	if (context.canViewAuthor)
		add(TGLocalized(@"Author"), @"Author", @"select", NO);
	if (context.canAddToFavorites || sticker)
		add(TGLocalized(@"Add to Favorites"), @"Add to Favourites", @"pin", NO);

	// A failure is the only thing worth doing first: nothing else can run on
	// a message Telegram never took.
	if (failed)
		add(TGLocalized(@"Retry"), @"Retry", @"reply", NO);

	if (context.canReply && !failed && !service)
		add(TGLocalized(@"Reply"), @"Reply", @"reply", NO);
	// Official's thread row follows Reply: "View 3 Replies" when there are
	// some, "View Thread" when the message only starts one.
	if (context.canGetThread && !service && !failed){
		NSInteger replies = [message[@"replyCount"] integerValue];
		add(replies > 0 ? TGLocalizedPluralValue(@"View %@ Reply", @"View %@ Replies",
						[NSString stringWithFormat:@"%ld", (long)replies], replies)
				: TGLocalized(@"View Thread"), @"View Thread", @"reply", NO);
	}

	// Copy and Translate are text actions. A voice note, a sticker or a bare
	// photo carries a system description in `text`, not words the sender typed.
	// Quoting is done directly via text selection on the lifted bubble.
	if (bodyText && saveable && (!context.hasProperties || context.canCopy))
		add(TGLocalized(@"Copy"), @"Copy", @"copy", NO);
	if (bodyText && [text rangeOfString:@"#"].location != NSNotFound)
		add(TGLocalized(@"Search by Hashtag"), @"Search by Hashtag", @"data", NO);
	if (bodyText && context.canTranslate)
		add(TGLocalized(@"Translate"), @"Translate", @"edit", NO);

	// The discussion row sits where official puts View Replies: after the
	// text/media verbs, before Edit.
	if ([message[@"canComment"] boolValue]) {
		NSInteger count = [message[@"replyCount"] integerValue];
		add(count <= 0 ? TGLocalized(@"Leave a Comment") : TGLocalized(@"Replies"),
				@"Show 1 Reply", @"reply", NO);
	}

	BOOL documentWithCaption = [message[@"kind"] isEqualToString:@"messageDocument"];
	if (context.mine && context.canEdit && !failed && !sticker &&
			(bodyText || [message[@"photoId"] isKindOfClass:NSNumber.class] ||
			 documentWithCaption))
		add(TGLocalized(@"Edit"), @"Edit", @"edit", NO);
	// Official reaches a checklist from the message itself: "Add a Task" opens
	// the list. Only a checklist carries that row.
	if (TGMessageIsChecklist(message) && !failed)
		add(TGLocalized(@"Add a Task"), @"Checklist", @"select", NO);
	if ([message[@"hasSuggestedPost"] boolValue] && !failed)
		add(TGLocalized(@"Suggest Post"), @"Suggest Post", @"edit", NO);
	// Editing media belongs to the author, and only when Telegram would accept
	// the edit; somebody else's photo never offers it.
	if ((context.hasProperties ? context.canEditMedia : context.mine && context.canEdit) &&
			!failed && !sticker && [message[@"photoId"] isKindOfClass:NSNumber.class])
		add(TGLocalized(@"Replace Photo"), @"Replace Photo", @"react", NO);

	// Pin, poll and link rows follow Edit in official, before Forward.
	if (context.canPin && !service && !failed) {
		BOOL pinned = context.isPinned;
		add(pinned ? TGLocalized(@"Unpin") : TGLocalized(@"Pin"),
				pinned ? @"Unpin" : @"Pin", pinned ? @"unpin" : @"pin", NO);
	}
	if (context.mine && pollOptions.count && ![message[@"pollClosed"] boolValue])
		add(TGLocalized(@"Stop Poll"), @"Stop Poll", @"select", NO);
	if (TGPollCanRetract([message[@"poll"] isKindOfClass:NSDictionary.class]
			? message[@"poll"] : nil))
		add(TGLocalized(@"Retract Vote"), @"Retract Vote", @"select", NO);
	if (pollOptions.count){
		if ([message[@"pollClosed"] boolValue] ||
				[message[@"pollVoters"] boolValue]){
			NSDictionary *poll = [message[@"poll"] isKindOfClass:NSDictionary.class]
					? message[@"poll"] : nil;
			NSInteger votes = [poll[@"totalVoterCount"] integerValue];
			add(votes > 0
					? TGLocalizedFormat(@"View Votes (%@)", @(votes))
					: TGLocalized(@"Poll Results"),
					@"PollVoters", @"select", NO);
		}
		if ([message[@"pollStats"] boolValue])
			add(TGLocalized(@"Poll Stats"), @"Poll Statistics", @"data", NO);
		// TDLib's can_add_option decides, not authorship: anyone may add to a
		// poll with open answers.
		if (TGPollCanAddOption([message[@"poll"] isKindOfClass:NSDictionary.class]
				? message[@"poll"] : nil))
			add(TGLocalized(@"Add an Option"), @"Add Option", @"edit", NO);
		if (context.mine && [message[@"pollOpen"] boolValue] &&
				[message[@"pollDeletable"] boolValue])
			add(TGLocalized(@"Delete Option"), @"Delete Option", @"delete", YES);
	}

	// Official only links a channel post that has a public address; the
	// chat has already filtered that into isChannel/channelPost.
	if (context.isChannel && [message[@"channelPost"] boolValue] && !service &&
			![message[@"kind"] isEqualToString:@"messageAction"])
		add(TGLocalized(@"Copy Link"), @"Copy Link", @"copy", NO);

	if (saveable && !service)
		add(TGLocalized(@"Forward"), @"Forward", @"forward", NO);

	// Report and its two siblings share official's Report position.
	if (context.canReport && !context.mine && !service){
		add(context.isGroup ? TGLocalized(@"Report Spam") : TGLocalized(@"Report"),
				@"Report Spam", @"privacy", YES);
	}
	NSDictionary *reactionReport = message[@"reactionReport"];
	if (reactionReport && ![reactionReport isKindOfClass:NSNull.class] &&
			!context.mine && (!context.hasProperties || context.canReportReactions))
		add(TGLocalized(@"Report Reaction"), @"Report Reaction", @"privacy", YES);

	if (context.canViewStats && !service)
		add(TGLocalized(@"View Statistics"), @"View Stats", @"data", NO);
	// Official's fact check sits on broadcast channel posts and is named by
	// whether one is already there.
	if (context.isChannel && context.canEditFactCheck && !service &&
			![message[@"kind"] isEqualToString:@"messageAction"]){
		NSString *fact = [message[@"factCheck"] isKindOfClass:NSString.class]
				? message[@"factCheck"] : @"";
		add(fact.length ? TGLocalized(@"Edit Fact Check")
						: TGLocalized(@"Add Fact Check"),
				@"Fact Check", @"data", NO);
	}
	if (context.isChannel)
		add(TGLocalized(@"Forwarded Messages"), @"Public Forwards", @"forward", NO);
	if (context.mine && [message[@"kind"] isEqualToString:@"messageLiveLocation"] &&
			[message[@"liveEditable"] boolValue])
		add(TGLocalized(@"Stop Sharing Location"), @"Stop Live Location",
				@"delete", YES);

	if ([message[@"inlineRows"] count])
		add(TGLocalized(@"Clear Buttons"), @"Clear Buttons", @"delete", YES);
	if ([message[@"kind"] isEqualToString:@"messageGame"])
		add(TGLocalized(@"Game Scores"), @"Game Scores", @"star", NO);

	// Official offers Delete whenever the message can go from either side,
	// an incoming one in a private chat included; without TDLib's answer
	// only our own messages are offered.
	if (context.hasProperties ? (context.canDeleteForSelf || context.canDeleteForAll) : context.mine){
		add(TGLocalized(@"Delete"), @"Delete", @"delete", YES);
		// A timed message says under Delete when it goes by itself
		// (ChatDeleteMessageContextItem).
		double left = [message[@"deleteAt"] doubleValue] - [[NSDate date] timeIntervalSince1970];
		if (left > 0 && rows.count){
			NSMutableDictionary *row = [rows.lastObject mutableCopy];
			row[@"subtitle"] = TGAutoDeleteText(left);
			rows[rows.count - 1] = row;
		}
	}

	if (context.canSelect)
		add(TGLocalized(@"Select"), @"Select", @"select", NO);

#if TG_DEV
	// Developer rows stay together at the end. Message Tools is not one of
	// them: it is reached from the dev hub, never from a held message.
	if (context.hasMessageEffects)
		add(TGLocalized(@"Message Effects"), @"Message Effects", @"react", NO);
	if ([message[@"kind"] isEqualToString:@"messageAnimatedEmoji"])
		add(TGLocalized(@"Click Emoji"), @"Click Emoji", @"react", NO);
	if ([message[@"kind"] isEqualToString:@"messageLocation"] ||
			[message[@"kind"] isEqualToString:@"messageLiveLocation"])
		add(TGLocalized(@"Location"), @"Location", @"data", NO);
	if ([message[@"kind"] isEqualToString:@"messageVoiceNote"] ||
			[message[@"kind"] isEqualToString:@"messageVideoNote"])
		add(TGLocalized(@"Rate Transcription"), @"Rate Transcription",
				@"react", NO);
	if ([message[@"kind"] isEqualToString:@"messageVideo"])
		add(TGLocalized(@"Video Advertisements"), @"Video Advertisements",
				@"data", NO);
#endif

	return rows;
}

NSString *TGSlowModeWaitText(NSTimeInterval seconds) {
	NSInteger total = (NSInteger)ceil(MAX(0, seconds));
	return [NSString stringWithFormat:@"%ld:%02ld", (long)(total / 60), (long)(total % 60)];
}

NSString *TGAutoDeleteText(NSTimeInterval seconds) {
	NSInteger total = (NSInteger)MAX(0, seconds);
	if (total >= 86400){
		NSInteger days = (NSInteger)lround(total / 86400.0);
		return TGLocalizedPluralValue(@"auto-deletes in %@ day", @"auto-deletes in %@ days",
				[NSString stringWithFormat:@"%ld", (long)days], days);
	}
	NSString *clock = total >= 3600
			? [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)(total / 3600),
					(long)(total / 60 % 60), (long)(total % 60)]
			: [NSString stringWithFormat:@"%ld:%02ld", (long)(total / 60), (long)(total % 60)];
	return TGLocalizedFormat(@"auto-deletes in %@", clock);
}

NSString *TGFreeTranscriptionsText(NSInteger left) {
	if (left < 0)
		return nil;
	NSString *text = TGLocalizedPluralValue(@"You have **%@** free voice transcription left this week.",
			@"You have **%@** free voice transcriptions left this week.",
			[NSString stringWithFormat:@"%ld", (long)left], left);
	return [text stringByReplacingOccurrencesOfString:@"**" withString:@""];
}

NSString *TGCopyProtectionTip(TGChatActionMenuContext context, NSString *peerName) {
	if (context.protectedByMe)
		return TGLocalized(@"You disabled copying and forwarding in this chat.");
	if (context.protectedByOther)
		return [TGLocalizedFormat(@"**%@** disabled copying and forwarding in this chat.", peerName ?: @"")
				stringByReplacingOccurrencesOfString:@"**" withString:@""];
	return nil;
}

NSString *TGReadDateText(NSTimeInterval readDate) {
	if (readDate <= 0)
		return nil;
	return TGLocalizedFormat(@"read %@", TGAppDate(readDate, NSDateFormatterNoStyle, NSDateFormatterShortStyle));
}

NSString *TGTranscriptionCooldownText(NSInteger left, NSInteger weekly,
		NSTimeInterval resetDate, NSTimeInterval now) {
	if (left != 0 || resetDate <= now)
		return nil;
	NSString *used = TGLocalizedPluralValue(@"You have used all your **%@** free transcription this week.",
			@"You have used all your **%@** free transcriptions this week.",
			[NSString stringWithFormat:@"%ld", (long)weekly], weekly);
	NSString *wait = TGLocalizedFormat(@"Wait until **%@** to use it again or subscribe to [Telegram Premium]() now.",
			TGAppDate(resetDate, NSDateFormatterMediumStyle, NSDateFormatterNoStyle) ?: @"");
	NSString *text = [NSString stringWithFormat:@"%@ %@", used, wait];
	text = [text stringByReplacingOccurrencesOfString:@"**" withString:@""];
	return [text stringByReplacingOccurrencesOfString:@"[Telegram Premium]()" withString:@"Telegram Premium"];
}

TGHoldScrollMetrics TGHoldScrollLayout(CGRect bubble, CGFloat above,
		CGFloat cardGap, CGFloat cardH, CGFloat top, CGFloat bottom,
		CGFloat hostH, CGFloat bottomPad) {
	TGHoldScrollMetrics out = {0};
	CGFloat h = CGRectGetHeight(bubble);
	CGFloat below = cardGap + cardH;
	CGFloat totalH = above + h + below;
	CGFloat availH = bottom - top;

	if (totalH <= availH) {
		out.bubbleY = TGHoldLiftY(bubble, above, below, top, bottom);
		out.reactionBaseY = out.bubbleY - above;
		out.cardY = out.bubbleY + h + cardGap;
		out.contentH = hostH;
		out.initialOffsetY = 0.0f;
	} else {
		out.reactionBaseY = top;
		out.bubbleY = top + above;
		out.cardY = out.bubbleY + h + cardGap;
		out.contentH = MAX(hostH, out.cardY + cardH + bottomPad);
		CGFloat maxOffset = MAX(0.0f, out.contentH - hostH);
		out.initialOffsetY = maxOffset;
	}
	return out;
}

CGFloat TGHoldStickyReactionY(CGFloat baseY, CGFloat bubbleMaxY,
		CGFloat reactionH, CGFloat gap, CGFloat offsetY, CGFloat topInset) {
	CGFloat maxY = MAX(baseY, bubbleMaxY - reactionH - gap);
	return MAX(baseY, MIN(maxY, offsetY + topInset));
}

NSArray<NSDictionary *> *TGQuoteSliceEntities(NSArray *entities, NSRange range) {
	if (![entities isKindOfClass:NSArray.class] || !entities.count || range.length == 0)
		return @[];
	NSInteger qStart = (NSInteger)range.location;
	NSInteger qEnd = (NSInteger)NSMaxRange(range);
	NSMutableArray *sliced = [NSMutableArray array];
	for (NSDictionary *entity in entities) {
		if (![entity isKindOfClass:NSDictionary.class] || !entity[@"type"])
			continue;
		NSInteger start = [entity[@"offset"] integerValue];
		NSInteger len = [entity[@"length"] integerValue];
		if (len <= 0)
			continue;
		NSInteger oStart = MAX(start, qStart);
		NSInteger oEnd = MIN(start + len, qEnd);
		if (oEnd <= oStart)
			continue;
		[sliced addObject:@{
			@"@type"  : @"textEntity",
			@"offset" : @(oStart - qStart),
			@"length" : @(oEnd - oStart),
			@"type"   : entity[@"type"],
		}];
	}
	return sliced;
}
