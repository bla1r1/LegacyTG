#import "TGSettingsStore.h"
#import "TGClient+InlineMessages.h"
#import "TGClient+MessagesInternal.h"
#import "TGClientInternal.h"
#import "TGMessageStore.h"
#import "TGSendStore.h"

@implementation TGSettingsStore (InlineMessages)

#pragma mark - inline messages a bot owns

- (void)editInlineMessageText:(NSString *)inlineMessageId
						 text:(NSString *)text
				   completion:(void (^)(BOOL ok))completion {
	if (!inlineMessageId.length || !text.length){
		if (completion) completion(NO);
		return;
	}
	[[TGClient shared] request:@{
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
	[[TGClient shared] request:@{
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
	[[TGClient shared] request:@{
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
	[[TGClient shared] request:@{
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
	[[TGClient shared] request:@{
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
	[[TGMessageStore shared] reactTo:messageId inChat:chatId emoji:emoji];
}

- (void)deleteMessage:(int64_t)messageId inChat:(int64_t)chatId {
	[self deleteMessages:@[@(messageId)] inChat:chatId revoke:YES];
}

- (void)deleteMessages:(NSArray *)messageIds inChat:(int64_t)chatId {
	[[TGSendStore shared] deleteMessages:messageIds inChat:chatId revoke:YES];
}

- (void)deleteMessages:(NSArray *)messageIds inChat:(int64_t)chatId revoke:(BOOL)revoke {
	[[TGSendStore shared] deleteMessages:messageIds inChat:chatId revoke:revoke];
}

/// "typing...", as the other side shows it. TDLib expects this repeated while
/// typing goes on; it expires on its own a few seconds after the last one.
- (void)sendTypingToChat:(int64_t)chatId thread:(int64_t)threadId {
	[[TGMessageStore shared] sendTypingToChat:chatId thread:threadId];
}

/// Stops it at once rather than waiting for it to expire - sent when the
/// message goes or the field is emptied.
- (void)cancelTypingInChat:(int64_t)chatId thread:(int64_t)threadId {
	[[TGMessageStore shared] cancelTypingInChat:chatId thread:threadId];
}

- (void)removeReaction:(NSString *)emoji
			 fromMessage:(int64_t)messageId
				  inChat:(int64_t)chatId {
	[[TGMessageStore shared] removeReaction:emoji fromMessage:messageId inChat:chatId];
}

/// Marks a voice note, a video note or a one-time picture as opened. Without
/// it the sender never sees it played and a [TGClient shared]-destructing message never
/// starts its clock.
- (void)openContentOfMessage:(int64_t)messageId inChat:(int64_t)chatId {
	[[TGMessageStore shared] openContentOfMessage:messageId inChat:chatId];
}

- (void)pinMessage:(int64_t)messageId inChat:(int64_t)chatId notify:(BOOL)notify {
	[[TGMessageStore shared] pinMessage:messageId inChat:chatId notify:notify];
}

- (void)unpinMessage:(int64_t)messageId inChat:(int64_t)chatId {
	[[TGMessageStore shared] unpinMessage:messageId inChat:chatId];
}

/// Every pinned message down at once - in a forum topic, only that topic's.
- (void)unpinAllMessagesInChat:(int64_t)chatId thread:(int64_t)threadId {
	[[TGMessageStore shared] unpinAllMessagesInChat:chatId thread:threadId];
}

/// The last message sent on or before `date` (unix seconds), for jumping to
/// a day; nil when the chat has nothing that old.
- (void)messageAtDate:(NSTimeInterval)date inChat:(int64_t)chatId
		   completion:(void (^)(NSDictionary *message))completion {
	[[TGClient shared] request:@{@"@type" : @"getChatMessageByDate",
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
	[[TGMessageStore shared] repliedMessageTo:messageId inChat:chatId completion:completion];
}

/// Returns messages by their ids in a chat. Missing messages are returned as NSNull.
- (void)messagesInChat:(int64_t)chatId
			messageIds:(NSArray *)messageIds
			completion:(void (^)(NSArray *messages))completion {
	[[TGMessageStore shared] messagesInChat:chatId messageIds:messageIds completion:completion];
}

/// Returns properties of a message (e.g. can_be_replied, can_get_message_thread).
- (void)messagePropertiesForChat:(int64_t)chatId
					   messageId:(int64_t)messageId
					  completion:(void (^)(NSDictionary *properties))completion {
	[[TGMessageStore shared] messagePropertiesForChat:chatId messageId:messageId completion:completion];
}

/// A t.me link to one message, for Copy Link. Only public chats have one;
/// the completion gets nil for the rest.
- (void)linkToMessage:(int64_t)messageId
			   inChat:(int64_t)chatId
		   completion:(void (^)(NSString *link))completion {
	[[TGClient shared] request:@{@"@type"      : @"getMessageLink",
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
	[[TGSendStore shared] resendMessages:messageIds inChat:chatId];
}

/// Closes a poll you sent. Nobody can vote afterwards and the result stands.
- (void)stopPoll:(int64_t)messageId inChat:(int64_t)chatId {
	[[TGMessageStore shared] stopPoll:messageId inChat:chatId];
}

/// Who voted for one answer. `optionIndex` is the 0-based index the answer
/// sits at; the voters come back as senders, flattened into ids and names
/// the menu shows.
- (void)pollVotersOfOption:(NSInteger)optionIndex
				ofMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
				completion:(void (^)(NSArray *voters, BOOL end))completion {
	__weak TGClient *weakSelf = [TGClient shared];
	[[TGClient shared] request:@{
		@"@type"      : @"getPollVoters",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"option_id"  : @(optionIndex),
		@"offset"     : @(0),
		@"limit"      : @(50),
	} completion:^(NSDictionary *result){
		TGClient *me = [TGClient shared];
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
	__weak TGClient *weakSelf = [TGClient shared];
	[[TGClient shared] request:@{
		@"@type"      : @"getPollVoteStatistics",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		// The sheet has no theme of its own: the chat lists its colours and
		// the graph data is the same numbers either way.
		@"is_dark"    : @NO,
	} completion:^(NSDictionary *result){
		TGClient *me = [TGClient shared];
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
	[[TGMessageStore shared] addPollOption:text toMessage:messageId inChat:chatId completion:completion];
}

/// An option taken out again; `optionId` is the string id pollOption
/// carries, not an index.
- (void)deletePollOption:(NSString *)optionId
			   ofMessage:(int64_t)messageId
				  inChat:(int64_t)chatId
			  completion:(void (^)(BOOL ok))completion {
	[[TGMessageStore shared] deletePollOption:optionId ofMessage:messageId inChat:chatId completion:completion];
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
	[[TGClient shared] request:@{
		@"@type"        : @"getPollOptionProperties",
		@"chat_id"      : @(chatId),
		@"message_id"   : @(messageId),
		@"poll_option_id" : optionId,
	} completion:^(NSDictionary *result){
		if ([result[@"@type"] isEqualToString:@"error"]){
			NSString *message = [result[@"message"] isKindOfClass:NSString.class]
					? result[@"message"] : @"An error occurred.";
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
	[[TGClient shared] send:@{
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
	[[TGMessageStore shared] reportReactionBySender:sender ofMessage:messageId inChat:chatId completion:completion];
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
	__weak TGClient *weakSelf = [TGClient shared];
	[[TGClient shared] request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *chat){
		TGClient *me = [TGClient shared];
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
	[[TGMessageStore shared] blockSenderOfMessage:messageId deleteMessages:deleteMessages reportSpam:reportSpam];
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

	__weak TGClient *weakSelf = [TGClient shared];
	[[TGClient shared] request:@{
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
		TGClient *me = [TGClient shared];
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
	[[TGClient shared] request:@{
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
	[[TGClient shared] request:@{@"@type" : @"getInternalLinkType", @"link" : link}
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
			[[TGClient shared] request:@{@"@type" : @"getDeepLinkInfo", @"link" : link}
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
	[[TGClient shared] request:@{@"@type" : @"getMessage",
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
			[[TGClient shared] request:@{@"@type" : @"getMarkdownText", @"text" : formatted}
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
	[[TGMessageStore shared] markRead:messageIds inChat:chatId];
}

@end
