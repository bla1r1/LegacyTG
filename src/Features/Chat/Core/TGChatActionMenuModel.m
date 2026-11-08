#import "TGChatActionMenuModel.h"
#import "TGLocalization.h"
#import "TGPollPresentation.h"

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
	NSInteger reactionCount = TGChatActionMenuReactionCount(message);
	NSArray *reactionGroups = message[@"reactionGroups"];
	NSArray *pollOptions = message[@"pollOptions"];

	void (^add)(NSString *, NSString *, NSString *, BOOL) =
			^(NSString *title, NSString *action, NSString *icon, BOOL destructive){
		NSDictionary *row = TGRow(title, action, icon, destructive);
		if (row)
			[rows addObject:row];
	};

	// Official inserts the author of a monoforum post at the very top and the
	// sticker's favourite toggle before the verbs; ours keeps the same two
	// positions for the rows it has.
	if (!context.mine)
		add(TGLocalized(@"Author"), @"Author", @"select", NO);
	if (context.canAddToFavorites || TGMessageIsSticker(message))
		add(TGLocalized(@"Add to Favorites"), @"Add to Favourites", @"pin", NO);
	if ([reactionGroups isKindOfClass:NSArray.class] && reactionGroups.count)
		add(TGLocalized(@"Reactions"), @"Reactions", @"react", NO);

	// A failure is the only thing worth doing first: nothing else can run on
	// a message Telegram never took.
	if (failed)
		add(TGLocalized(@"Retry"), @"Retry", @"reply", NO);

	if (context.canReply && !failed && !service)
		add(TGLocalized(@"Reply"), @"Reply", @"reply", NO);

	if (text.length && saveable)
		add(TGLocalized(@"Copy"), @"Copy", @"copy", NO);
	if (text.length)
		add(TGLocalized(@"Quote"), @"Find Quote", @"data", NO);
	if ([text rangeOfString:@"#"].location != NSNotFound)
		add(TGLocalized(@"Search by Hashtag"), @"Search by Hashtag", @"data", NO);
	if (text.length && context.canTranslate)
		add(TGLocalized(@"Translate"), @"Translate", @"edit", NO);
	if (text.length && context.canSpeak)
		add(TGLocalized(@"Speak"), @"Speak", @"microphone", NO);
	if ([message[@"kind"] isEqualToString:@"messageVoiceNote"] ||
			[message[@"kind"] isEqualToString:@"messageVideoNote"])
		add(TGLocalized(@"Transcribe"), @"Transcribe", @"data", NO);

	// The discussion row sits where official puts View Replies: after the
	// text/media verbs, before Edit.
	if ([message[@"canComment"] boolValue]) {
		NSInteger count = [message[@"replyCount"] integerValue];
		add(count <= 0 ? TGLocalized(@"Leave a Comment") : TGLocalized(@"Replies"),
				@"Show 1 Reply", @"reply", NO);
	}

	if (context.mine && context.canEdit && !failed &&
			(text.length || [message[@"photoId"] isKindOfClass:NSNumber.class]))
		add(TGLocalized(@"Edit"), @"Edit", @"edit", NO);
	if (context.mine && [message[@"photoId"] isKindOfClass:NSNumber.class])
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
	// Developer rows stay together at the end so release never grows one.
	add(TGLocalized(@"Message Tools"), @"Message Tools", @"data", NO);
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
