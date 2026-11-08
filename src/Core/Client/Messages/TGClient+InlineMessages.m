#import "TGClient+InlineMessages.h"
#import "TGClient+MessagesInternal.h"
#import "TGClientInternal.h"

@implementation TGClient (InlineMessages)

#pragma mark - inline messages a bot owns

- (void)editInlineMessageText:(NSString *)inlineMessageId
						 text:(NSString *)text
				   completion:(void (^)(BOOL ok))completion {
	if (!inlineMessageId.length || !text.length){
		if (completion) completion(NO);
		return;
	}
	[self request:@{
		@"@type"                  : @"editInlineMessageText",
		@"inline_message_id"      : inlineMessageId,
		@"reply_markup"           : [NSNull null],
		@"input_message_content"  : @{@"@type" : @"inputMessageText",
									  @"text" : TGFormattedText(text)},
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)editInlineMessageCaption:(NSString *)inlineMessageId
						 caption:(NSString *)caption
					  completion:(void (^)(BOOL ok))completion {
	if (!inlineMessageId.length){
		if (completion) completion(NO);
		return;
	}
	[self request:@{
		@"@type"        : @"editInlineMessageCaption",
		@"inline_message_id" : inlineMessageId,
		@"reply_markup" : [NSNull null],
		@"caption"      : TGFormattedText(caption ?: @""),
		@"show_caption_above_media" : @NO,
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)clearInlineMessageReplyMarkup:(NSString *)inlineMessageId
						   completion:(void (^)(BOOL ok))completion {
	if (!inlineMessageId.length){
		if (completion) completion(NO);
		return;
	}
	[self request:@{
		@"@type"             : @"editInlineMessageReplyMarkup",
		@"inline_message_id" : inlineMessageId,
		@"reply_markup"      : @{@"@type" : @"replyMarkupInlineKeyboard",
								 @"rows" : @[]},
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)editInlineMessagePhoto:(NSString *)inlineMessageId
					   photoId:(int64_t)photoId
					   caption:(NSString *)caption
					completion:(void (^)(BOOL ok))completion {
	if (!inlineMessageId.length || photoId <= 0){
		if (completion) completion(NO);
		return;
	}
	// The media edits take an inputPhoto, not a local file: TDLib wants the
	// photo the bot already has. An empty reference is what a caller that
	// only knows the id can send; the server says whether it is enough.
	[self request:@{
		@"@type"             : @"editInlineMessageMedia",
		@"inline_message_id" : inlineMessageId,
		@"reply_markup"      : [NSNull null],
		@"input_message_content" : @{
			@"@type"   : @"inputMessagePhoto",
			@"photo"   : @{@"@type" : @"inputPhoto",
						   @"id" : @(photoId),
						   @"access_hash" : @(0),
						   @"file_reference" : @""},
			@"caption" : TGFormattedText(caption ?: @""),
			@"show_caption_above_media" : @NO,
			@"self_destruct_type" : [NSNull null],
			@"has_spoiler" : @NO,
		},
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)editInlineMessageLiveLocation:(NSString *)inlineMessageId
							 latitude:(double)latitude
							longitude:(double)longitude
						   completion:(void (^)(BOOL ok))completion {
	if (!inlineMessageId.length){
		if (completion) completion(NO);
		return;
	}
	[self request:@{
		@"@type"             : @"editInlineMessageLiveLocation",
		@"inline_message_id" : inlineMessageId,
		@"reply_markup"      : [NSNull null],
		@"location"          : @{
			@"@type"   : @"liveLocation",
			@"location" : @{@"@type" : @"location",
							@"latitude" : @(latitude),
							@"longitude" : @(longitude),
							@"horizontal_accuracy" : @(0)},
			// 0x7FFFFFFF keeps the period the message already has.
			@"live_period" : @(0x7FFFFFFF),
			@"heading" : @(0),
			@"proximity_alert_radius" : @(0),
		},
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)reactTo:(int64_t)messageId inChat:(int64_t)chatId emoji:(NSString *)emoji {
	[self send:@{
		@"@type"      : @"addMessageReaction",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"reaction_type" : @{@"@type" : @"reactionTypeEmoji", @"emoji" : emoji},
		@"is_big"     : @NO,
		@"update_recent_reactions" : @YES,
	}];
}

- (void)deleteMessage:(int64_t)messageId inChat:(int64_t)chatId {
	[self deleteMessages:@[@(messageId)] inChat:chatId revoke:YES];
}

- (void)deleteMessages:(NSArray *)messageIds inChat:(int64_t)chatId {
	[self deleteMessages:messageIds inChat:chatId revoke:YES];
}

- (void)deleteMessages:(NSArray *)messageIds inChat:(int64_t)chatId revoke:(BOOL)revoke {
	if (!messageIds.count)
		return;
	[self send:@{
		@"@type"        : @"deleteMessages",
		@"chat_id"      : @(chatId),
		@"message_ids"  : messageIds,
		@"revoke"       : @(revoke),
	}];
}

/// "typing...", as the other side shows it. TDLib expects this repeated while
/// typing goes on; it expires on its own a few seconds after the last one.
- (void)sendTypingToChat:(int64_t)chatId thread:(int64_t)threadId {
	[self send:@{
		@"@type"             : @"sendChatAction",
		@"chat_id"           : @(chatId),
		@"message_thread_id" : @(threadId),
		@"action"            : @{@"@type" : @"chatActionTyping"},
	}];
}

/// Stops it at once rather than waiting for it to expire - sent when the
/// message goes or the field is emptied.
- (void)cancelTypingInChat:(int64_t)chatId thread:(int64_t)threadId {
	[self send:@{
		@"@type"             : @"sendChatAction",
		@"chat_id"           : @(chatId),
		@"message_thread_id" : @(threadId),
		@"action"            : @{@"@type" : @"chatActionCancel"},
	}];
}

- (void)removeReaction:(NSString *)emoji
			 fromMessage:(int64_t)messageId
				  inChat:(int64_t)chatId {
	if (!emoji.length)
		return;
	[self send:@{
		@"@type"         : @"removeMessageReaction",
		@"chat_id"       : @(chatId),
		@"message_id"    : @(messageId),
		@"reaction_type" : @{@"@type" : @"reactionTypeEmoji", @"emoji" : emoji},
	}];
}

/// Marks a voice note, a video note or a one-time picture as opened. Without
/// it the sender never sees it played and a self-destructing message never
/// starts its clock.
- (void)openContentOfMessage:(int64_t)messageId inChat:(int64_t)chatId {
	if (!messageId)
		return;
	[self send:@{
		@"@type"      : @"openMessageContent",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
	}];
}

- (void)pinMessage:(int64_t)messageId inChat:(int64_t)chatId notify:(BOOL)notify {
	[self send:@{
		@"@type"                : @"pinChatMessage",
		@"chat_id"              : @(chatId),
		@"message_id"           : @(messageId),
		@"disable_notification" : @(!notify),
		@"only_for_self"        : @NO,
	}];
}

- (void)unpinMessage:(int64_t)messageId inChat:(int64_t)chatId {
	[self send:@{
		@"@type"      : @"unpinChatMessage",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
	}];
}

/// Every pinned message down at once - in a forum topic, only that topic's.
- (void)unpinAllMessagesInChat:(int64_t)chatId thread:(int64_t)threadId {
	if (threadId)
		[self send:@{@"@type" : @"unpinAllForumTopicMessages",
					 @"chat_id" : @(chatId), @"forum_topic_id" : @(threadId)}];
	else
		[self send:@{@"@type" : @"unpinAllChatMessages", @"chat_id" : @(chatId)}];
}

/// The last message sent on or before `date` (unix seconds), for jumping to
/// a day; nil when the chat has nothing that old.
- (void)messageAtDate:(NSTimeInterval)date inChat:(int64_t)chatId
		   completion:(void (^)(NSDictionary *message))completion {
	[self request:@{@"@type" : @"getChatMessageByDate",
					@"chat_id" : @(chatId),
					@"date" : @((int32_t)date)}
	   completion:^(NSDictionary *m){
		if (completion)
			completion([m[@"@type"] isEqualToString:@"message"] ? TGFlattenMessage(m) : nil);
	}];
}

/// The message a reply points at. The history may not hold it - a reply to
/// something far above, or to a message in another chat - so this asks the
/// server rather than searching what is loaded.
- (void)repliedMessageTo:(int64_t)messageId
				  inChat:(int64_t)chatId
			  completion:(void (^)(NSDictionary *message))completion {
	[self request:@{@"@type"      : @"getRepliedMessage",
					@"chat_id"    : @(chatId),
					@"message_id" : @(messageId)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		NSDictionary *parsed = [result[@"id"] longLongValue]
				? TGFlattenMessage(result) : nil;
		if (parsed){
			// The chat the answer lives in, which a reply across chats is
			// what reads it: the flattened message carries the id of a
			// message only, and the chat view would ask itself for it.
			NSMutableDictionary *withChat = [parsed mutableCopy];
			withChat[@"chatId"] = result[@"chat_id"];
			parsed = withChat;
		}
		completion(parsed);
	}];
}

/// Returns messages by their ids in a chat. Missing messages are returned as NSNull.
- (void)messagesInChat:(int64_t)chatId
			messageIds:(NSArray *)messageIds
			completion:(void (^)(NSArray *messages))completion {
	if (!messageIds.count){
		if (completion) completion(@[]);
		return;
	}
	[self request:@{
		@"@type"       : @"getMessages",
		@"chat_id"     : @(chatId),
		@"message_ids" : messageIds,
	} completion:^(NSDictionary *result){
		if (!completion) return;
		NSArray *raw = result[@"messages"];
		if (![raw isKindOfClass:NSArray.class]){
			completion(@[]);
			return;
		}
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:raw.count];
		for (id item in raw){
			if ([item isKindOfClass:NSDictionary.class] && [item[@"id"] longLongValue] != 0)
				[out addObject:TGFlattenMessage(item)];
			else
				[out addObject:[NSNull null]];
		}
		completion(out);
	}];
}

/// Returns properties of a message (e.g. can_be_replied, can_get_message_thread).
- (void)messagePropertiesForChat:(int64_t)chatId
					   messageId:(int64_t)messageId
					  completion:(void (^)(NSDictionary *properties))completion {
	[self request:@{
		@"@type"      : @"getMessageProperties",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result){
		if (completion)
			completion([result isKindOfClass:NSDictionary.class] ? result : nil);
	}];
}

/// A t.me link to one message, for Copy Link. Only public chats have one;
/// the completion gets nil for the rest.
- (void)linkToMessage:(int64_t)messageId
			   inChat:(int64_t)chatId
		   completion:(void (^)(NSString *link))completion {
	[self request:@{@"@type"      : @"getMessageLink",
					@"chat_id"    : @(chatId),
					@"message_id" : @(messageId),
					@"for_album"  : @NO}
	   completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"link"] isKindOfClass:NSString.class] ? result[@"link"] : nil);
	}];
}

/// Sends failed messages again. TDLib keeps them in the history with their
/// own ids until they go or are deleted.
- (void)resendMessages:(NSArray *)messageIds inChat:(int64_t)chatId {
	if (!messageIds.count)
		return;
	[self send:@{
		@"@type"       : @"resendMessages",
		@"chat_id"     : @(chatId),
		@"message_ids" : messageIds,
	}];
}

/// Closes a poll you sent. Nobody can vote afterwards and the result stands.
- (void)stopPoll:(int64_t)messageId inChat:(int64_t)chatId {
	[self send:@{
		@"@type"      : @"stopPoll",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
	}];
}

/// Who voted for one answer. `optionIndex` is the 0-based index the answer
/// sits at; the voters come back as senders, flattened into ids and names
/// the menu shows.
- (void)pollVotersOfOption:(NSInteger)optionIndex
				ofMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
				completion:(void (^)(NSArray *voters, BOOL end))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type"      : @"getPollVoters",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"option_id"  : @(optionIndex),
		@"offset"     : @(0),
		@"limit"      : @(50),
	} completion:^(NSDictionary *result){
		TGClient *me = weakSelf;
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *voter in result[@"voters"]){
			NSDictionary *sender = voter[@"voter_id"];
			int64_t userId = [sender[@"user_id"] longLongValue];
			if (!userId)
				continue;
			[out addObject:@{
				@"id"   : @(userId),
				@"name" : [me nameForUserId:userId] ?: @"",
				@"date" : voter[@"date"] ?: @(0),
			}];
		}
		if (completion)
			completion(out, [out count] >= [result[@"total_count"] integerValue]);
	}];
}

- (void)pollVoteStatisticsOfMessage:(int64_t)messageId
							 inChat:(int64_t)chatId
						 completion:(void (^)(NSDictionary *graph))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type"      : @"getPollVoteStatistics",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		// The sheet has no theme of its own: the chat lists its colours and
		// the graph data is the same numbers either way.
		@"is_dark"    : @NO,
	} completion:^(NSDictionary *result){
		TGClient *me = weakSelf;
		NSDictionary *graph = nil;
		NSString *json = result[@"vote_graph"][@"json_data"];
		if ([json isKindOfClass:NSString.class] && json.length) {
			graph = @{@"json" : json,
					  @"zoom" : result[@"vote_graph"][@"zoom_token"] ?: @""};
		}
		if (completion) completion(graph);
	}];
}

/// An option added after the poll went out, for polls that allow it. The
/// option is a line of text in the same shaped envelope an input poll
/// carries.
- (void)addPollOption:(NSString *)text
			toMessage:(int64_t)messageId
				 inChat:(int64_t)chatId
			completion:(void (^)(BOOL ok))completion {
	if (!text.length){
		if (completion) completion(NO);
		return;
	}
	[self request:@{
		@"@type"      : @"addPollOption",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"option"     : @{@"@type" : @"inputPollOption",
						  @"text"  : @{@"@type" : @"formattedText",
									   @"text"  : text}},
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

/// An option taken out again; `optionId` is the string id pollOption
/// carries, not an index.
- (void)deletePollOption:(NSString *)optionId
			   ofMessage:(int64_t)messageId
				  inChat:(int64_t)chatId
			  completion:(void (^)(BOOL ok))completion {
	if (!optionId.length){
		if (completion) completion(NO);
		return;
	}
	[self request:@{
		@"@type"      : @"deletePollOption",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"option_id"  : optionId,
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

/// What one answer still allows. TDLib answers with a record of four flags;
/// the card names each one instead of showing the raw object, because a
/// client that only prints JSON has not told the user anything.
- (void)pollOptionProperties:(NSString *)optionId
				   ofMessage:(int64_t)messageId
					  inChat:(int64_t)chatId
				  completion:(void (^)(NSDictionary *, NSString *))completion {
	optionId = [optionId isKindOfClass:NSString.class] ? optionId : @"";
	if (!optionId.length){
		if (completion) completion(nil, @"This answer has no id to look up.");
		return;
	}
	[self request:@{
		@"@type"        : @"getPollOptionProperties",
		@"chat_id"      : @(chatId),
		@"message_id"   : @(messageId),
		@"poll_option_id" : optionId,
	} completion:^(NSDictionary *result){
		if ([result[@"@type"] isEqualToString:@"error"]){
			NSString *message = [result[@"message"] isKindOfClass:NSString.class]
					? result[@"message"] : @"Telegram refused that lookup.";
			if (completion) completion(nil, message);
			return;
		}
		if (completion)
			completion(@{
				@"canBeDeleted"             : result[@"can_be_deleted"] ?: @NO,
				@"canBeReplied"             : result[@"can_be_replied"] ?: @NO,
				@"canBeRepliedInAnotherChat": result[@"can_be_replied_in_another_chat"] ?: @NO,
				@"canGetLink"               : result[@"can_get_link"] ?: @NO,
			}, nil);
	}];
}

/// Every poll in the chat read up on: the votes are no longer new once the
/// chat has been seen, which is what a badge on the answer options is.
- (void)readAllChatPollVotes:(int64_t)chatId {
	[self send:@{
		@"@type"   : @"readAllChatPollVotes",
		@"chat_id" : @(chatId),
	}];
}

/// Reports a reaction as harassment: TDLib names the sender, not the
/// message alone - the fire brigade wants to know who lit the fire.
/// `sender` is the MessageSender the flattening carried up untouched.
- (void)reportReactionBySender:(NSDictionary *)sender
					 ofMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
					 completion:(void (^)(BOOL ok))completion {
	if (![sender isKindOfClass:NSDictionary.class]){
		if (completion) completion(NO);
		return;
	}
	[self request:@{
		@"@type"      : @"reportMessageReactions",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"sender_id"  : sender,
	} completion:^void (NSDictionary *result){
		if (completion)
			completion([result[@"@type"] isEqualToString:@"ok"]);
	}];
}

/// Reports messages in a supergroup as spam. It takes the supergroup's own
/// id, not the chat id - a chat id for a supergroup is the negative of it
/// with a prefix, so this reads the chat first rather than doing arithmetic
/// on it.
- (void)reportSpamMessages:(NSArray *)messageIds
				    inChat:(int64_t)chatId
				completion:(void (^)(BOOL ok))completion {
	if (!messageIds.count){
		if (completion) completion(NO);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *chat){
		TGClient *me = weakSelf;
		NSNumber *supergroupId = chat[@"type"][@"supergroup_id"];
		if (!me || !supergroupId){
			// A basic group or a private chat has no supergroup to report to;
			// reportChat is the route for those.
			if (completion) completion(NO);
			return;
		}
		[me request:@{@"@type"        : @"reportSupergroupSpam",
					  @"supergroup_id": supergroupId,
					  @"message_ids"  : messageIds}
		 completion:^(NSDictionary *result){
			if (completion)
				completion([result[@"@type"] isEqualToString:@"ok"]);
		}];
	}];
}

/// Blocks whoever sent a message from replying again, and optionally takes
/// what they wrote with them. Only for messages in the chats a reply reaches
/// this account through.
- (void)blockSenderOfMessage:(int64_t)messageId
			  deleteMessages:(BOOL)deleteMessages
				  reportSpam:(BOOL)reportSpam {
	[self send:@{
		@"@type"              : @"blockMessageSenderFromReplies",
		@"message_id"         : @(messageId),
		@"delete_message"     : @(deleteMessages),
		@"delete_all_messages": @(deleteMessages),
		@"report_spam"        : @(reportSpam),
	}];
}

/// Telegram's own static map of a place, as a PNG. The completion gets a
/// local path, or nil when there is no answer - which on this device is
/// ordinary: the thumbnail is a download like any other, and a chat opened
/// on a slow connection or with none will not have it.
///
/// `scale` is left at 1 deliberately. A retina plate is four times the bytes
/// for a card 220 points wide on a screen that has 320 of them.
- (void)mapThumbnailForLatitude:(double)latitude
					  longitude:(double)longitude
						  width:(NSInteger)width
						 height:(NSInteger)height
						 inChat:(int64_t)chatId
					 completion:(void (^)(NSString *path))completion {
	// Their own bounds; a request outside them is refused rather than clamped.
	NSInteger wanted = MAX(16, MIN(1024, width));
	NSInteger tall   = MAX(16, MIN(1024, height));

	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type"    : @"getMapThumbnailFile",
		@"location" : @{@"@type"     : @"location",
						@"latitude"  : @(latitude),
						@"longitude" : @(longitude)},
		@"zoom"     : @(16),
		@"width"    : @(wanted),
		@"height"   : @(tall),
		@"scale"    : @(1),
		@"chat_id"  : @(chatId),
	} completion:^(NSDictionary *result){
		TGClient *me = weakSelf;
		NSNumber *fileId = result[@"id"];
		if (!me || ![fileId isKindOfClass:NSNumber.class]){
			if (completion) completion(nil);
			return;
		}
		// The answer is a file record, not the picture: it still has to come
		// down, and a thumbnail already in the cache answers at once.
		NSString *local = result[@"local"][@"path"];
		if ([result[@"local"][@"is_downloading_completed"] boolValue] && local.length){
			if (completion) completion(local);
			return;
		}
		[me downloadFile:fileId.integerValue completion:completion];
	}];
}

/// What Telegram makes of a link: the site, a title, a description and the
/// picture, which is the card their clients draw under a message. Answers nil
/// when the link has no preview, which is most links.
///
/// Entries: "url", "site", "title", "description", "photoId", "instantView".
- (void)linkPreviewForText:(NSString *)text
				completion:(void (^)(NSDictionary *preview))completion {
	if (!text.length){
		if (completion) completion(nil);
		return;
	}
	[self request:@{
		@"@type" : @"getLinkPreview",
		@"text"  : TGFormattedText(text),
		@"link_preview_options" : @{@"@type" : @"linkPreviewOptions",
									@"is_disabled" : @NO},
	} completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"linkPreview"]){
			completion(nil);
			return;
		}
		// The biggest size the preview carries, which is the one a card draws.
		NSArray *sizes = result[@"type"][@"photo"][@"sizes"];
		NSDictionary *largest = [sizes isKindOfClass:NSArray.class]
				? [sizes lastObject] : nil;
		NSNumber *photoId = largest[@"photo"][@"id"];
		completion(@{
			@"url"         : result[@"url"] ?: @"",
			@"site"        : result[@"site_name"] ?: @"",
			@"title"       : result[@"title"] ?: @"",
			@"description" : result[@"description"][@"text"] ?: @"",
			@"photoId"     : photoId ?: [NSNull null],
			@"instantView" : @([result[@"instant_view_version"] integerValue] > 0),
		});
	}];
}

/// What a t.me or tg:// link points at, decided by Telegram rather than by
/// pattern-matching the path here - which is how a link to a sticker set
/// ended up opening a chat named after it.
///
/// Answers the kind as one word ("publicChat", "message", "stickerSet",
/// "inviteLink", "unknown") and the piece of it worth acting on.
- (void)internalLinkKind:(NSString *)link
			  completion:(void (^)(NSString *kind, NSString *value))completion {
	if (!link.length){
		if (completion) completion(@"unknown", nil);
		return;
	}
	[self request:@{@"@type" : @"getInternalLinkType", @"link" : link}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		NSString *type = result[@"@type"] ?: @"";
		if ([type isEqualToString:@"internalLinkTypePublicChat"])
			completion(@"publicChat", result[@"chat_username"]);
		else if ([type isEqualToString:@"internalLinkTypeMessage"])
			completion(@"message", result[@"url"]);
		else if ([type isEqualToString:@"internalLinkTypeStickerSet"])
			completion(@"stickerSet", result[@"sticker_set_name"]);
		else if ([type isEqualToString:@"internalLinkTypeChatInvite"])
			completion(@"inviteLink", result[@"invite_link"]);
		else if ([type isEqualToString:@"internalLinkTypeUserPhoneNumber"])
			completion(@"phoneNumber", result[@"phone_number"]);
		else if ([type isEqualToString:@"internalLinkTypeUserToken"])
			completion(@"userToken", result[@"token"]);
		else {
			// Telegram keeps a server-side table of links it has no schema
			// for: what a private invite or a reserved page means, told in
			// prose. That prose is the link's meaning - without it the tap
			// fell through to a path-matcher that mostly guessed wrong.
			[self request:@{@"@type" : @"getDeepLinkInfo", @"link" : link}
			   completion:^(NSDictionary *info){
				if (!completion)
					return;
				// A refusal answers as an error, whose "message" is a bare
				// string - subscripting that is the crash a naive chain
				// here would take.
				NSDictionary *said = [info[@"message"] isKindOfClass:NSDictionary.class]
						? info[@"message"] : nil;
				NSString *note = said[@"text"] ?: @"";
				// "update_app" means TDLib answered because its copy is
				// stale, not because this is what the link means: the tap
				// falls back rather than reciting a version check.
				BOOL staleCopy = [info[@"update_app"] boolValue];
				if ([info[@"@type"] isEqualToString:@"deepLinkInfo"] && note.length &&
						!staleCopy)
					completion(@"deepLink", note);
				else
					completion(@"unknown", nil);
			}];
		}
	}];
}

/// What the sender typed, handed back as markdown: *bold*, `_italic_`,
/// `code` come back out of the entities their client stored - so Edit edits
/// the origin rather than the render. A message with no entities is not
/// worth the round trip: the plain text goes back as it is.
- (void)markdownOfMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
				completion:(void (^)(NSString *markdown))completion {
	[self request:@{@"@type" : @"getMessage",
					@"chat_id"    : @(chatId),
					@"message_id" : @(messageId)}
		completion:^(NSDictionary *result){
			if (!completion)
				return;
			NSString *plain = result[@"content"][@"text"][@"text"] ?: @"";
			NSDictionary *formatted = result[@"content"][@"text"];
			if (![formatted[@"@type"] isEqualToString:@"formattedText"] ||
					![formatted[@"entities"] isKindOfClass:NSArray.class] ||
					!((NSArray *)formatted[@"entities"]).count){
				completion(plain);
				return;
			}
			[self request:@{@"@type" : @"getMarkdownText", @"text" : formatted}
				completion:^(NSDictionary *answer){
				NSString *text = answer[@"text"];
				if ([answer[@"@type"] isEqualToString:@"formattedText"] &&
						text.length)
					completion(text);
				else
					completion(plain);
			}];
		}];
}

- (void)markRead:(NSArray *)messageIds inChat:(int64_t)chatId {
	if (!messageIds.count)
		return;
	[self send:@{
		@"@type"       : @"viewMessages",
		@"chat_id"     : @(chatId),
		@"message_ids" : messageIds,
		@"force_read"  : @YES,
	}];
}

@end
