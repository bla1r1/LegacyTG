#import "TGChatActionMenuModel.h"
#import "TGLocalization.h"
#import "TGPollPresentation.h"
#import "TGStyle.h"
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

	// Copy, Quote, Translate and Speak are text actions. A voice note, a
	// sticker or a bare photo carries a system description in `text`, not
	// words the sender typed, and official does not offer any of them there.
	if (bodyText && saveable)
		add(TGLocalized(@"Copy"), @"Copy", @"copy", NO);
	if (bodyText)
		add(TGLocalized(@"Quote"), @"Find Quote", @"data", NO);
	if (bodyText && [text rangeOfString:@"#"].location != NSNotFound)
		add(TGLocalized(@"Search by Hashtag"), @"Search by Hashtag", @"data", NO);
	if (bodyText && context.canTranslate)
		add(TGLocalized(@"Translate"), @"Translate", @"edit", NO);
	if (bodyText && context.canSpeak)
		add(TGLocalized(@"Speak"), @"Speak", @"microphone", NO);

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
	if (context.mine && context.canEdit && !failed && !sticker &&
			[message[@"photoId"] isKindOfClass:NSNumber.class])
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
		if (context.mine && [message[@"pollOpen"] boolValue])
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
			!context.mine)
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

	if (context.mine)
		add(TGLocalized(@"Delete"), @"Delete", @"delete", YES);

	if (context.canSelect)
		add(TGLocalized(@"Select"), @"Select", @"select", NO);

#if TG_DEV
	// Developer rows stay together at the end. Message Tools is not one of
	// them: it is reached from the dev hub, never from a held message.
	add(TGLocalized(@"Shared Media"), @"Shared Media Map", @"data", NO);
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
