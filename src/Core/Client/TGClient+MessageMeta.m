//
 // TGClient+MessageMeta.m - facts around one message.
//
 // Link info, drafts, auto-delete, viewers, forwards, the reaction
 // lists, the calendar jump, translation - every read that hangs off
 // a message and answers with context rather than content.
//
#import "TGClientInternal.h"

@implementation TGClient (MessageMeta)
#pragma mark - facts a screen asks for

/// What a "message"-kind internal link points at: a t.me/name/12345 resolves
/// to the chat and the exact message inside it. The link type itself is
/// decided by Telegram, at internalLinkKind:; a link to a nonexistent or a
/// private-place message answers as an error, said as a zero chat id.
/// Every chat's draft, dropped at once - the ones typed here and the ones
/// typed on another device: TDLib owns all of them.
/// The lifetime new chats start with when nobody has picked one. Zero means
/// Telegram's "off" - messages live until deleted by hand.
#pragma mark - more of the same, kept apart for review

/// Members who opened the voice note, watched the round video or otherwise
/// read this own message in a group. messageViewer carries the user id and
/// when they did it; names resolve out of the client's user records.
/// When exactly the other side read this message - or why the answer is not
/// a timestamp: "unread", "tooOld", or their and our own privacy settings.
/// A nil date with a reason word is the honest sheet line.
/// Who a channel actually posted as, when the bubble says "Channel Admin".
/// The server answers a full user record.
/// The HTML this message is pasted with into a blog post. Only messages
/// carrying a web page preview answer it, which is what the server says to
/// anything else - passed on as an empty string.
/// Public channels and walls this post was forwarded to, as message dicts -
/// only public places answer, so a short list is the worst case.
/// The reactions that may be added to this message right now: the chat's
/// configured set filtered by per-message rules, from which the picker bar
/// is drawn instead of the app's hard defaults. "all" in the emoji list
/// means the chat allows everything and the defaults are the honest set.
/// Every reaction this message carries and who put it, for the reactor
/// sheet. `offset` iterates; an empty answer on the first call is a message
/// without reactors or a chat that does not hand these out.
- (void)addedReactionsOfMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
						  emoji:(NSString *)emoji
						 offset:(NSString *)offset
					 completion:(void (^)(NSArray *rows, NSString *next))completion {
	NSDictionary *type = emoji.length
			? @{@"@type" : @"reactionTypeEmoji", @"emoji" : emoji}
			: nil;
	[self addedReactionsOfMessage:messageId
						   inChat:chatId
					 reactionType:type
						   offset:offset
					   completion:completion];
}

/// The same list for either reaction spelling: a custom emoji has no character
/// to send, so the id travels as reactionTypeCustomEmoji instead.
- (void)addedReactionsOfMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
				   reactionType:(NSDictionary *)reactionType
						 offset:(NSString *)offset
					 completion:(void (^)(NSArray *rows, NSString *next))completion {
	if (!reactionType){
		if (completion) completion(nil, nil);
		return;
	}
	[self request:@{@"@type" : @"getMessageAddedReactions",
					@"chat_id" : @(chatId), @"message_id" : @(messageId),
					@"reaction_type" : reactionType,
					@"offset" : offset ?: @"",
					@"limit" : @(50)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"addedReactions"]){
			completion(nil, nil);
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		NSArray *reactions = result[@"reactions"];
		if ([reactions isKindOfClass:NSArray.class]){
			for (NSDictionary *r in reactions){
				if (![r isKindOfClass:NSDictionary.class])
					continue;
				// addedReaction carries is_outgoing itself; older fixtures
				// omit it and the sender still says who it was.
				NSNumber *date = r[@"date"];
				[rows addObject:@{
					@"sender" : r[@"sender_id"] ?: @{},
					@"date"   : date ?: @(0),
					@"mine"   : r[@"is_outgoing"] ?: @NO,
					@"type"   : r[@"type"] ?: @{},
				}];
			}
		}
		NSString *next = result[@"next_offset"];
		completion(rows, [next isKindOfClass:NSString.class] ? next : @"");
	}];
}

/// An administrator taking somebody's reaction off this message.
/// The same, chat-wide: everything this sender ever reacted with in this
/// chat, gone. That is the strongest undo an admin sheet has.
/// How many messages a chat (or one of its topics) carries. `thread` selects
/// a forum topic; zero is the whole chat.
- (void)messageCountInChat:(int64_t)chatId
					filter:(NSString *)filterType
				completion:(void (^)(NSInteger count))completion {
	[self request:@{@"@type" : @"getChatMessageCount",
					@"chat_id" : @(chatId),
					@"filter" : @{@"@type" : filterType ?: @"searchMessagesFilterEmpty"},
					@"return_local" : @NO}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if ([result[@"@type"] isEqualToString:@"count"])
			completion([result[@"count"] integerValue]);
		else
			completion(0);
	}];
}

/// Every call history entry on this account, gone from everywhere.
/// The calendar answer for one day: the message id to jump to and how many
/// messages the chat carries, from the same search the jump sheet used to
/// make two round trips for.
- (void)calendarJumpForChat:(int64_t)chatId
					 endDate:(NSInteger)end
				  completion:(void (^)(int64_t messageId, NSInteger total))completion {
	[self request:@{@"@type"   : @"getChatMessageCalendar",
					@"chat_id" : @(chatId),
					@"filter"  : @{@"@type" : @"searchMessagesFilterEmpty"},
					@"from_message_id" : @(0)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"messageCalendar"]){
			completion(0, 0);
			return;
		}
		completion([result[@"last_message_id"] longLongValue],
				   [result[@"total_count"] integerValue]);
	}];
}

/// Everything this account has sent as a file, named like search results:
/// message dicts the list page lays out as document rows.
/// The pubic posts everywhere a hashtag appears - server search, answered
/// newest first, paged by the string offset Telegram names.
- (void)publicMessagesByTag:(NSString *)tag
					 offset:(NSString *)offset
				completion:(void (^)(NSArray *messages, NSString *next))completion {
	NSString *clean = [tag stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!clean.length){
		if (completion) completion(nil, nil);
		return;
	}
	[self request:@{@"@type"     : @"searchPublicMessagesByTag",
					@"tag"     : clean,
					@"offset"  : offset ?: @"",
					@"limit"   : @(50)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"foundMessages"]){
			completion(nil, nil);
			return;
		}
		completion(result[@"messages"], result[@"next_offset"]);
	}];
}

/// Where this chat's live pins have been, newest first, for the "recent
/// locations" sheet: message dicts, each a location bubble the map opens.
/// This message's text, translated by Telegram into `languageCode`. The
/// answer is the same formattedText the composer already knows how to show.
#pragma mark - effects, import, prepared messages

@end
