//
// TGMessageStore.m - explicit message boundary.
//
// Each method is written out: no runtime forwarding. A method that has
// not grown store state yet delegates to the client transport; the ones
// that own request shaping are moved here method by method.
//
#import "TGMessageStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGUpdateRouter.h"
#import "TGDownloadStore.h"

NSString *const TGMessageStoreChangedNotification = @"TGMessageStoreChangedNotification";

@implementation TGMessageStore

- (void)messageStoreChanged:(NSNotification *)note {
	NSArray *chatIds = note.userInfo[@"chatIds"];
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGMessageStoreChangedNotification
						  object:self userInfo:@{@"chatIds" : chatIds ?: @[]}];
}


+ (instancetype)shared {
	static TGMessageStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ store = [[TGMessageStore alloc] init]; });
	return store;
}

+ (NSDictionary *)scheduledAtDate:(NSTimeInterval)date {
	return [TGClient scheduledAtDate:date];
}

+ (NSDictionary *)scheduledAtDate:(NSTimeInterval)date repeatPeriod:(NSInteger)seconds {
	return [TGClient scheduledAtDate:date repeatPeriod:seconds];
}

+ (NSDictionary *)scheduledWhenOnline {
	return [TGClient scheduledWhenOnline];
}

- (void)addChat:(int64_t)chatId toList:(NSDictionary *)list completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] addChat:chatId toList:list completion:completion];
}

- (void)addChecklistTasks:(NSArray *)tasks toMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] addChecklistTasks:tasks toMessage:messageId inChat:chatId completion:completion];
}

- (void)addPollOption:(NSString *)text toMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
{
	if (!text.length){
		if (completion) completion(NO);
		return;
	}
	[[TGClient shared] request:@{
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
}

- (void)addQuickReplyShortcutMessage:(NSString *)shortcutName text:(NSString *)text completion:(void (^)(NSDictionary *message, NSString *error))completion {
	[[TGClient shared] addQuickReplyShortcutMessage:shortcutName text:text completion:completion];
}

- (void)addQuickReplyShortcutMessageAlbum:(NSString *)shortcutName texts:(NSArray *)texts completion:(void (^)(NSArray *messages, NSString *error))completion {
	[[TGClient shared] addQuickReplyShortcutMessageAlbum:shortcutName texts:texts completion:completion];
}

- (void)addedReactionsOfMessage:(int64_t)messageId inChat:(int64_t)chatId reactionType:(NSDictionary *)reactionType offset:(NSString *)offset completion:(void (^)(NSArray *rows, NSString *next))completion {
	[[TGClient shared] addedReactionsOfMessage:messageId inChat:chatId reactionType:reactionType offset:offset completion:completion];
}

- (void)approveSuggestedPost:(int64_t)messageId inChat:(int64_t)chatId sendDate:(NSInteger)sendDate completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] approveSuggestedPost:messageId inChat:chatId sendDate:sendDate completion:completion];
}

- (void)authorOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *user))completion {
{
	[[TGClient shared] request:@{@"@type" : @"getMessageAuthor",
					@"chat_id" : @(chatId), @"message_id" : @(messageId)}
	   completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"@type"] isEqualToString:@"user"] ? result : nil);
	}];
}
}

- (void)availableReactionsForMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSArray *emojis))completion {
{
	[[TGClient shared] request:@{@"@type" : @"getMessageAvailableReactions",
					@"chat_id" : @(chatId), @"message_id" : @(messageId),
					@"row_size" : @(8)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"availableReactions"] ||
				[result[@"unavailability_reason"] isKindOfClass:NSDictionary.class]){
			completion(nil);
			return;
		}
		NSArray *top = result[@"top_reactions"];
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *r in top){


			NSString *emoji = r[@"type"][@"emoji"] ?: r[@"emoji"];
			if (emoji.length)
				[out addObject:emoji];
		}


		completion(out.count ? out : nil);
	}];
}
}

- (void)blockSenderOfMessage:(int64_t)messageId deleteMessages:(BOOL)deleteMessages reportSpam:(BOOL)reportSpam {
{
	[[TGClient shared] send:@{
		@"@type"              : @"blockMessageSenderFromReplies",
		@"message_id"         : @(messageId),
		@"delete_message"     : @(deleteMessages),
		@"delete_all_messages": @(deleteMessages),
		@"report_spam"        : @(reportSpam),
	}];
}
}

- (void)blockUserWithUserId:(int64_t)userId {
	[[TGClient shared] blockUserWithUserId:userId];
}

- (void)calendarJumpForChat:(int64_t)chatId endDate:(NSInteger)end completion:(void (^)(int64_t messageId, NSInteger total))completion {
	[[TGClient shared] calendarJumpForChat:chatId endDate:end completion:completion];
}

- (void)canSendInChat:(int64_t)chatId completion:(void (^)(BOOL canSend, BOOL isChannel))completion {
	[[TGClient shared] canSendInChat:chatId completion:completion];
}

- (void)cancelDownloadOfFile:(NSInteger)fileId onlyIfPending:(BOOL)onlyIfPending {
	[[TGDownloadStore shared] cancelDownloadOfFile:fileId onlyIfPending:onlyIfPending];
}



- (void)cancelTypingInChat:(int64_t)chatId thread:(int64_t)threadId {
	[[TGClient shared] send:@{
		@"@type"             : @"sendChatAction",
		@"chat_id"           : @(chatId),
		@"message_thread_id" : @(threadId),
		@"action"            : @{@"@type" : @"chatActionCancel"},
	}];
}

- (BOOL)chatIsSavedMessages:(int64_t)chatId {
	return [[TGClient shared] chatIsSavedMessages:chatId];
}

- (void)chatKindForChat:(int64_t)chatId completion:(void (^)(NSDictionary *kind))completion {
	[[TGClient shared] chatKindForChat:chatId completion:completion];
}

- (void)chatListsForChat:(int64_t)chatId completion:(void (^)(NSArray *lists))completion {
	[[TGClient shared] chatListsForChat:chatId completion:completion];
}

- (void)chatProfile:(int64_t)chatId completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] chatProfile:chatId completion:completion];
}

- (void)chatRecordForChat:(int64_t)chatId completion:(void (^)(NSDictionary *chat))completion {
	[[TGClient shared] chatRecordForChat:chatId completion:completion];
}

- (void)chatStatisticsForChat:(int64_t)chatId completion:(void (^)(NSArray *rows, NSString *kind))completion {
	[[TGClient shared] chatStatisticsForChat:chatId completion:completion];
}

- (void)chatWithUsername:(NSString *)username completion:(void (^)(int64_t chatId, NSString *title))completion {
	[[TGClient shared] chatWithUsername:username completion:completion];
}

- (void)checkQuickReplyShortcutName:(NSString *)name completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] checkQuickReplyShortcutName:name completion:completion];
}

- (void)checklistForMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *checklist, NSString *error))completion {
	[[TGClient shared] checklistForMessage:messageId inChat:chatId completion:completion];
}

- (void)clearHistoryInChat:(int64_t)chatId {
	[self clearHistoryInChat:chatId revoke:NO];
}

- (void)clearHistoryInChat:(int64_t)chatId revoke:(BOOL)revoke {
	[[TGClient shared] clearHistoryInChat:chatId revoke:revoke];
}

- (void)clearReplyMarkupOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
{

	[[TGClient shared] request:@{
		@"@type"        : @"editMessageReplyMarkup",
		@"chat_id"      : @(chatId),
		@"message_id"   : @(messageId),
		@"reply_markup" : @{@"@type" : @"replyMarkupInlineKeyboard",
							@"rows" : @[]},
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}
}

- (void)clearSavedTopicMessagesBefore:(int64_t)topicId minDate:(NSInteger)minDate maxDate:(NSInteger)maxDate {
	[[TGClient shared] clearSavedTopicMessagesBefore:topicId minDate:minDate maxDate:maxDate];
}

- (void)clickAnimatedEmojiMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSString *emoji))completion {
{
	[[TGClient shared] request:@{
		@"@type"      : @"clickAnimatedEmojiMessage",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result){
		if (!completion)
			return;



		NSDictionary *sticker = [result[@"sticker"] isKindOfClass:NSDictionary.class]
				? result[@"sticker"] : result;
		NSString *emoji = sticker[@"emoji"];
		completion([emoji isKindOfClass:NSString.class] ? emoji : nil);
	}];
}
}

- (void)closeChat:(int64_t)chatId {
	[[TGClient shared] closeChat:chatId];
}

- (void)closeSecretChat:(NSInteger)secretChatId {
	[[TGClient shared] closeSecretChat:secretChatId];
}

- (void)commentThreadForChat:(int64_t)chatId messageId:(int64_t)messageId completion:(void (^)(int64_t discussionChatId, int64_t threadId,
									   NSString *error))completion {
	[[TGClient shared] commentThreadForChat:chatId messageId:messageId completion:completion];
}

- (void)communityFullInfo:(int64_t)communityId completion:(void (^)(NSDictionary *info, NSString *error))completion {
	[[TGClient shared] communityFullInfo:communityId completion:completion];
}

- (void)composeTextWithAi:(NSString *)text translateTo:(NSString *)languageCode style:(NSString *)styleName addEmojis:(BOOL)addEmojis completion:(void (^)(NSString *text, NSString *error))completion {
	[[TGClient shared] composeTextWithAi:text translateTo:languageCode style:styleName addEmojis:addEmojis completion:completion];
}

- (void)confirmLoginButton:(NSDictionary *)button inChat:(int64_t)chatId messageId:(int64_t)messageId completion:(void (^)(NSString *url, NSString *error))completion {
	[[TGClient shared] confirmLoginButton:button inChat:chatId messageId:messageId completion:completion];
}

- (void)currentWeatherAtLatitude:(double)latitude longitude:(double)longitude completion:(void (^)(NSDictionary *weather,
										   NSString *error))completion {
	[[TGClient shared] currentWeatherAtLatitude:latitude longitude:longitude completion:completion];
}

- (void)declineSuggestedPost:(int64_t)messageId inChat:(int64_t)chatId comment:(NSString *)comment completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] declineSuggestedPost:messageId inChat:chatId comment:comment completion:completion];
}

- (void)defaultChatPhotoEmojiStickersWithCompletion:(void (^)(NSArray *stickers))completion {
	[[TGClient shared] defaultChatPhotoEmojiStickersWithCompletion:completion];
}

- (void)deleteAllReactionsOfSender:(NSDictionary *)sender inChat:(int64_t)chatId {
{
	if (!sender)
		return;
	[[TGClient shared] send:@{
		@"@type"   : @"deleteAllRecentMessageReactionsFromSender",
		@"chat_id" : @(chatId),
		@"sender_id" : sender,
	}];
}
}

- (void)deleteChatBackground:(int64_t)chatId restorePrevious:(BOOL)restore {
	[[TGClient shared] deleteChatBackground:chatId restorePrevious:restore];
}

- (void)deleteDirectMessagesChatTopicHistory:(int64_t)topicId inChat:(int64_t)chatId completion:(void (^)(BOOL ok,
                                                       NSString *error))completion {
	[[TGClient shared] deleteDirectMessagesChatTopicHistory:topicId inChat:chatId completion:completion];
}

- (void)deleteDirectMessagesChatTopicMessages:(int64_t)topicId inChat:(int64_t)chatId minDate:(NSInteger)minDate maxDate:(NSInteger)maxDate completion:(void (^)(BOOL ok,
                                                       NSString *error))completion {
	[[TGClient shared] deleteDirectMessagesChatTopicMessages:topicId inChat:chatId minDate:minDate maxDate:maxDate completion:completion];
}

- (void)deleteEphemeralMessage:(NSInteger)ephemeralMessageId receiver:(int64_t)receiverUserId inChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] deleteEphemeralMessage:ephemeralMessageId receiver:receiverUserId inChat:chatId completion:completion];
}

- (void)deleteMessageEphemeralContent:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok,
                                               NSString *error))completion {
	[[TGClient shared] deleteMessageEphemeralContent:messageId inChat:chatId completion:completion];
}



- (void)deletePollOption:(NSString *)optionId ofMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
{
	if (!optionId.length){
		if (completion) completion(NO);
		return;
	}
	[[TGClient shared] request:@{
		@"@type"      : @"deletePollOption",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"option_id"  : optionId,
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}
}

- (void)deleteQuickReplyShortcut:(NSInteger)shortcutId completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] deleteQuickReplyShortcut:shortcutId completion:completion];
}

- (void)deleteQuickReplyShortcutMessages:(NSArray *)messageIds shortcutId:(NSInteger)shortcutId completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] deleteQuickReplyShortcutMessages:messageIds shortcutId:shortcutId completion:completion];
}

- (void)deleteReactionsOfSender:(NSDictionary *)sender ofMessage:(int64_t)messageId inChat:(int64_t)chatId {
{
	if (!sender)
		return;
	[[TGClient shared] send:@{
		@"@type"     : @"deleteMessageReactionsFromSender",
		@"chat_id"   : @(chatId),
		@"message_id": @(messageId),
		@"sender_id" : sender,
	}];
}
}

- (void)deleteSavedTopicHistory:(int64_t)topicId {
	[[TGClient shared] deleteSavedTopicHistory:topicId];
}

- (void)directMessagesChatTopic:(int64_t)topicId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *topic,
                                          NSString *error))completion {
	[[TGClient shared] directMessagesChatTopic:topicId inChat:chatId completion:completion];
}

- (void)directMessagesChatTopicHistory:(int64_t)topicId inChat:(int64_t)chatId fromMessageId:(int64_t)fromMessageId offset:(NSInteger)offset limit:(NSInteger)limit completion:(void (^)(NSArray *messages,
                                                 NSString *error))completion {
	[[TGClient shared] directMessagesChatTopicHistory:topicId inChat:chatId fromMessageId:fromMessageId offset:offset limit:limit completion:completion];
}

- (void)directMessagesChatTopicMessageByDate:(int64_t)topicId inChat:(int64_t)chatId date:(NSInteger)date completion:(void (^)(NSDictionary *message,
                                                       NSString *error))completion {
	[[TGClient shared] directMessagesChatTopicMessageByDate:topicId inChat:chatId date:date completion:completion];
}

- (NSArray *)directMessagesChatTopicsForChat:(int64_t)chatId {
	return [[TGClient shared] directMessagesChatTopicsForChat:chatId];
}

- (void)dismissReplyMarkupInChat:(int64_t)chatId {
	[[TGClient shared] dismissReplyMarkupInChat:chatId];
}

- (void)downloadFile:(NSInteger)fileId completion:(void (^)(NSString *path))completion {
	[[TGDownloadStore shared] downloadFile:fileId completion:completion];
}

- (void)downloadFile:(NSInteger)fileId priority:(NSInteger)priority completion:(void (^)(NSString *path))completion {
	[[TGDownloadStore shared] downloadFile:fileId priority:priority completion:completion];
}

- (NSString *)draftForChat:(int64_t)chatId {
	return [[TGClient shared] draftForChat:chatId];
}

- (void)editCaption:(NSString *)caption ofMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] request:@{
		@"@type"      : @"editMessageCaption",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"caption"    : TGFormattedText(caption),
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)editEphemeralMessage:(NSInteger)ephemeralMessageId text:(NSString *)text receiver:(int64_t)receiverUserId inChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] editEphemeralMessage:ephemeralMessageId text:text receiver:receiverUserId inChat:chatId completion:completion];
}

- (void)editEphemeralMessageCaption:(NSInteger)ephemeralMessageId caption:(NSString *)caption receiver:(int64_t)receiverUserId inChat:(int64_t)chatId completion:(void (^)(BOOL ok,
                                              NSString *error))completion {
	[[TGClient shared] editEphemeralMessageCaption:ephemeralMessageId caption:caption receiver:receiverUserId inChat:chatId completion:completion];
}

- (void)editLiveLocationOfMessage:(int64_t)messageId inChat:(int64_t)chatId latitude:(double)latitude longitude:(double)longitude livePeriod:(NSInteger)seconds completion:(void (^)(BOOL ok))completion {
{
	if (!messageId){
		if (completion) completion(NO);
		return;
	}
	[[TGClient shared] request:@{
		@"@type"      : @"editMessageLiveLocation",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"location"   : @{
			@"@type"       : @"liveLocation",
			@"location"    : @{@"@type"     : @"location",
							   @"latitude"  : @(latitude),
							   @"longitude" : @(longitude)},
			@"live_period" : @(seconds),
			@"heading"     : @(0),
			@"proximity_alert_radius" : @(0),
		},
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}
}

- (void)editMessageChecklist:(int64_t)messageId inChat:(int64_t)chatId title:(NSString *)title tasks:(NSArray *)tasks othersCanAdd:(BOOL)othersCanAdd othersCanMark:(BOOL)othersCanMark completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] editMessageChecklist:messageId inChat:chatId title:title tasks:tasks othersCanAdd:othersCanAdd othersCanMark:othersCanMark completion:completion];
}

- (void)editPhotoAtPath:(NSString *)path caption:(NSString *)caption ofMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
{
	if (!path.length){
		if (completion) completion(NO);
		return;
	}
	[[TGClient shared] request:@{
		@"@type"      : @"editMessageMedia",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),


		@"reply_markup" : @{@"@type" : @"replyMarkupInlineKeyboard",
							@"rows" : @[]},
		@"input_message_content": @{
			@"@type"   : @"inputMessagePhoto",
			@"photo"   : @{@"@type" : @"inputFileLocal", @"path" : path},
			@"caption" : TGFormattedText(caption),
		},
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}
}

- (void)editQuickReplyMessage:(int64_t)messageId shortcutId:(NSInteger)shortcutId text:(NSString *)text completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] editQuickReplyMessage:messageId shortcutId:shortcutId text:text completion:completion];
}

- (void)embeddingCodeOfMessage:(int64_t)messageId inChat:(int64_t)chatId album:(BOOL)album completion:(void (^)(NSString *code))completion {
{
	[[TGClient shared] request:@{@"@type" : @"getMessageEmbeddingCode",
					@"chat_id" : @(chatId), @"message_id" : @(messageId),
					@"for_album" : @(album)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"text"]){
			completion(@"");
			return;
		}
		completion(result[@"text"]);
	}];
}
}

- (int64_t)emojiStatusIdForChat:(int64_t)chatId {
	return [[TGClient shared] emojiStatusIdForChat:chatId];
}

- (int64_t)emojiStatusIdForUser:(int64_t)userId {
	return [[TGClient shared] emojiStatusIdForUser:userId];
}

- (void)ensureUserName:(int64_t)userId completion:(void (^)(void))completion {
	[[TGClient shared] ensureUserName:userId completion:completion];
}

- (void)externalLinkForURL:(NSString *)url allowWriteAccess:(BOOL)allowWriteAccess completion:(void (^)(NSString *link))completion {
	[[TGClient shared] externalLinkForURL:url allowWriteAccess:allowWriteAccess completion:completion];
}

- (void)externalLinkInfoForURL:(NSString *)url completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] externalLinkInfoForURL:url completion:completion];
}

- (void)fixTextWithAi:(NSString *)text completion:(void (^)(NSString *text, NSString *diff, NSString *error))completion {
	[[TGClient shared] fixTextWithAi:text completion:completion];
}

- (void)forwardMessages:(NSArray *)messageIds fromChat:(int64_t)fromChatId toChat:(int64_t)toChatId {
	[[TGClient shared] send:@{
		@"@type"        : @"forwardMessages",
		@"chat_id"      : @(toChatId),
		@"from_chat_id" : @(fromChatId),
		@"message_ids"  : messageIds ?: @[],
	}];
}

- (void)gameHighScoresForChat:(int64_t)chatId message:(int64_t)messageId user:(int64_t)userId completion:(void (^)(NSArray *scores,
										NSString *error))completion {
	[[TGClient shared] gameHighScoresForChat:chatId message:messageId user:userId completion:completion];
}

- (void)getFullRichMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSString *text, NSDictionary *message, NSString *error))completion {
	[[TGClient shared] getFullRichMessage:messageId inChat:chatId completion:completion];
}

- (void)giveawayInfoForChat:(int64_t)chatId message:(int64_t)messageId completion:(void (^)(NSDictionary *info, NSString *error))completion {
	[[TGClient shared] giveawayInfoForChat:chatId message:messageId completion:completion];
}

- (void)groupFullInfoForChat:(int64_t)chatId completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] groupFullInfoForChat:chatId completion:completion];
}







- (void)inlineGameHighScores:(NSString *)inlineMessageId user:(int64_t)userId completion:(void (^)(NSArray *scores,
										NSString *error))completion {
	[[TGClient shared] inlineGameHighScores:inlineMessageId user:userId completion:completion];
}

- (void)instantViewForURL:(NSString *)url onlyLocal:(BOOL)onlyLocal completion:(void (^)(NSDictionary *view))completion {
	[[TGClient shared] instantViewForURL:url onlyLocal:onlyLocal completion:completion];
}

- (void)internalLinkForType:(NSDictionary *)type http:(BOOL)http completion:(void (^)(NSString *link))completion {
	[[TGClient shared] internalLinkForType:type http:http completion:completion];
}

- (void)internalLinkKind:(NSString *)link completion:(void (^)(NSString *kind, NSString *value))completion {
	[[TGClient shared] internalLinkKind:link completion:completion];
}

- (BOOL)isChatMuted:(int64_t)chatId {
	return [[TGClient shared] isChatMuted:chatId];
}

- (void)isUserBlocked:(int64_t)userId completion:(void (^)(BOOL blocked))completion {
	[[TGClient shared] isUserBlocked:userId completion:completion];
}

- (void)joinChat:(int64_t)chatId completion:(void (^)(BOOL ok, BOOL requestSent))completion {
	[[TGClient shared] joinChat:chatId completion:completion];
}

- (void)joinChatByInviteLink:(NSString *)inviteLink completion:(void (^)(int64_t chatId, NSString *title))completion {
	[[TGClient shared] joinChatByInviteLink:inviteLink completion:completion];
}

- (void)joinRequestsForChat:(int64_t)chatId completion:(void (^)(NSArray *requests))completion {
	[[TGClient shared] joinRequestsForChat:chatId completion:completion];
}

- (void)labelSavedTag:(NSDictionary *)tag label:(NSString *)label {
	[[TGClient shared] labelSavedTag:tag label:label];
}

- (int64_t)lastReadInboxForChat:(int64_t)chatId {
	return [[TGClient shared] lastReadInboxForChat:chatId];
}

- (void)linkPreviewForText:(NSString *)text completion:(void (^)(NSDictionary *preview))completion {
	[[TGClient shared] linkPreviewForText:text completion:completion];
}

- (void)linkToMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSString *link))completion {
	[[TGClient shared] linkToMessage:messageId inChat:chatId completion:completion];
}

- (void)loadDirectMessagesChatTopicsInChat:(int64_t)chatId limit:(NSInteger)limit completion:(void (^)(BOOL ok,
                                                     NSString *error))completion {
	[[TGClient shared] loadDirectMessagesChatTopicsInChat:chatId limit:limit completion:completion];
}

- (void)loadQuickReplyMessagesForShortcut:(NSInteger)shortcutId completion:(void (^)(NSArray *messages))completion {
	[[TGClient shared] loadQuickReplyMessagesForShortcut:shortcutId completion:completion];
}

- (void)loadQuickReplyShortcutsWithCompletion:(void (^)(NSArray *shortcuts))completion {
	[[TGClient shared] loadQuickReplyShortcutsWithCompletion:completion];
}

- (void)loadSavedMessagesTopics {
	[[TGClient shared] loadSavedMessagesTopics];
}

- (void)localMessageWithId:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *message))completion {
	[[TGClient shared] localMessageWithId:messageId inChat:chatId completion:completion];
}

- (void)loginURLForButton:(NSDictionary *)button inChat:(int64_t)chatId messageId:(int64_t)messageId completion:(void (^)(NSString *url, NSString *confirmDomain,
									NSString *error))completion {
	[[TGClient shared] loginURLForButton:button inChat:chatId messageId:messageId completion:completion];
}

- (void)mapThumbnailForLatitude:(double)latitude longitude:(double)longitude width:(NSInteger)width height:(NSInteger)height inChat:(int64_t)chatId completion:(void (^)(NSString *path))completion {
	NSInteger wanted = MAX(16, MIN(1024, width));
	NSInteger tall   = MAX(16, MIN(1024, height));
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
		NSNumber *fileId = result[@"id"];
		if (![fileId isKindOfClass:NSNumber.class]){
			if (completion) completion(nil);
			return;
		}
		NSString *local = result[@"local"][@"path"];
		if ([result[@"local"][@"is_downloading_completed"] boolValue] && local.length){
			if (completion) completion(local);
			return;
		}
		[[TGDownloadStore shared] downloadFile:fileId.integerValue completion:completion];
	}];
}

- (void)markChecklistTask:(int64_t)taskId done:(BOOL)done inMessage:(int64_t)messageId chat:(int64_t)chatId {
{
	NSArray *one = @[@(taskId)];
	[[TGClient shared] send:@{
		@"@type"                      : @"markChecklistTasksAsDone",
		@"chat_id"                    : @(chatId),
		@"message_id"                 : @(messageId),
		@"marked_as_done_task_ids"    : done ? one : @[],
		@"marked_as_not_done_task_ids": done ? @[] : one,
	}];
}
}

- (void)markChecklistTasksAsDone:(NSArray *)doneTaskIds notDoneTaskIds:(NSArray *)notDoneTaskIds onMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] markChecklistTasksAsDone:doneTaskIds notDoneTaskIds:notDoneTaskIds onMessage:messageId inChat:chatId completion:completion];
}

- (void)markRead:(NSArray *)messageIds inChat:(int64_t)chatId {
	if (!messageIds.count)
		return;
	[[TGClient shared] send:@{
		@"@type"       : @"viewMessages",
		@"chat_id"     : @(chatId),
		@"message_ids" : messageIds,
		@"force_read"  : @YES,
	}];
}

- (NSDictionary *)markdownForEditing:(NSDictionary *)formattedText {
	return [[TGClient shared] markdownForEditing:formattedText];
}

- (NSDictionary *)markdownParsed:(NSDictionary *)formattedText {
	return [[TGClient shared] markdownParsed:formattedText];
}

- (void)messageAtDate:(NSTimeInterval)date inChat:(int64_t)chatId completion:(void (^)(NSDictionary *message))completion {
	[[TGClient shared] messageAtDate:date inChat:chatId completion:completion];
}

- (void)messageCountInChat:(int64_t)chatId filter:(NSString *)filterType completion:(void (^)(NSInteger count))completion {
	[[TGClient shared] messageCountInChat:chatId filter:filterType completion:completion];
}

- (void)messageCountInChat:(int64_t)chatId thread:(int64_t)threadId completion:(void (^)(NSInteger count))completion {
{
	NSMutableDictionary *ask = [@{@"@type" : @"getChatMessageCount",
								  @"chat_id" : @(chatId),
								  @"filter" : @{@"@type" : @"searchMessagesFilterEmpty"},
								  @"return_local" : @NO} mutableCopy];

	if (threadId)
		ask[@"topic_id"] = @{@"@type" : @"messageTopicThread", @"message_thread_id" : @(threadId)};
	[[TGClient shared] request:ask
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if ([result[@"@type"] isEqualToString:@"count"])
			completion([result[@"count"] integerValue]);
		else
			completion(0);
	}];
}
}

- (void)messageEffectWithId:(int64_t)effectId completion:(void (^)(NSDictionary *effect))completion {
{
	[[TGClient shared] request:@{@"@type" : @"getMessageEffect", @"effect_id" : @(effectId)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"messageEffect"]){
			completion(nil);
			return;
		}
		completion(@{
			@"emoji"   : result[@"emoji"] ?: @"",
			@"premium" : result[@"is_premium"] ?: @NO,
			@"kind"    : result[@"type"][@"@type"] ?: @"",
		});
	}];
}
}

- (void)messageLinkInfo:(NSString *)link completion:(void (^)(int64_t chatId, int64_t messageId))completion {
{
	if (!link.length){
		if (completion) completion(0, 0);
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getMessageLinkInfo", @"url" : link}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"messageLinkInfo"]){
			completion(0, 0);
			return;
		}
		completion([result[@"chat_id"] longLongValue],
				   [result[@"message"][@"id"] longLongValue]);
	}];
}
}

- (void)messagePropertiesForChat:(int64_t)chatId messageId:(int64_t)messageId completion:(void (^)(NSDictionary *properties))completion {
{
	[[TGClient shared] request:@{
		@"@type"      : @"getMessageProperties",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result){
		if (completion)
			completion([result isKindOfClass:NSDictionary.class] ? result : nil);
	}];
}
}

- (void)messagesInChat:(int64_t)chatId messageIds:(NSArray *)messageIds completion:(void (^)(NSArray *messages))completion {
{
	if (!messageIds.count){
		if (completion) completion(@[]);
		return;
	}
	[[TGClient shared] request:@{
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
}

- (UIColor *)nameColourForUser:(int64_t)userId {
	return [[TGClient shared] nameColourForUser:userId];
}

- (NSString *)nameForUserId:(int64_t)userId {
	return [[TGClient shared] nameForUserId:userId];
}



- (void)openChat:(int64_t)chatId {
	[[TGClient shared] openChat:chatId];
}

- (void)openContentOfMessage:(int64_t)messageId inChat:(int64_t)chatId {
	if (!messageId)
		return;
	[[TGClient shared] send:@{
		@"@type"      : @"openMessageContent",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
	}];
}

- (void)ownerAfterLeavingChat:(int64_t)chatId completion:(void (^)(NSDictionary *user))completion {
	[[TGClient shared] ownerAfterLeavingChat:chatId completion:completion];
}

- (void)parseMarkdownText:(NSString *)text completion:(void (^)(NSDictionary *formatted))completion {
	[[TGClient shared] parseMarkdownText:text completion:completion];
}

- (void)pinMessage:(int64_t)messageId inChat:(int64_t)chatId notify:(BOOL)notify {
	[[TGClient shared] send:@{
		@"@type"                : @"pinChatMessage",
		@"chat_id"              : @(chatId),
		@"message_id"           : @(messageId),
		@"disable_notification" : @(!notify),
		@"only_for_self"        : @NO,
	}];
}

- (void)pinnedMessageForChat:(int64_t)chatId completion:(void (^)(NSDictionary *message))completion {
	[[TGClient shared] pinnedMessageForChat:chatId completion:completion];
}

- (void)pollVoteStatisticsOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *graph))completion {
	[[TGClient shared] pollVoteStatisticsOfMessage:messageId inChat:chatId completion:completion];
}

- (void)pollVotersOfOption:(NSInteger)optionIndex ofMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSArray *voters, BOOL end))completion {
	[[TGClient shared] pollVotersOfOption:optionIndex ofMessage:messageId inChat:chatId completion:completion];
}

- (void)positionOfMessage:(int64_t)messageId inChat:(int64_t)chatId thread:(int64_t)threadId completion:(void (^)(NSInteger position))completion {
	[[TGClient shared] positionOfMessage:messageId inChat:chatId thread:threadId completion:completion];
}

- (void)pressCallbackButton:(NSDictionary *)button inChat:(int64_t)chatId messageId:(int64_t)messageId completion:(void (^)(NSString *text, BOOL alert, NSString *url,
									  NSString *error))completion {
	[[TGClient shared] pressCallbackButton:button inChat:chatId messageId:messageId completion:completion];
}

- (void)privateChatWithUser:(int64_t)userId completion:(void (^)(int64_t chatId))completion {
	[[TGClient shared] privateChatWithUser:userId completion:completion];
}

- (void)processAllJoinRequests:(int64_t)chatId link:(NSString *)link approve:(BOOL)approve completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] processAllJoinRequests:chatId link:link approve:approve completion:completion];
}

- (void)processJoinRequest:(int64_t)userId inChat:(int64_t)chatId approve:(BOOL)approve {
	[[TGClient shared] processJoinRequest:userId inChat:chatId approve:approve];
}

- (void)publicForwardsOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSArray *messages))completion {
{
	[[TGClient shared] request:@{@"@type" : @"getMessagePublicForwards",
					@"chat_id" : @(chatId), @"message_id" : @(messageId),
					@"offset" : @"", @"limit" : @(50)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"publicForwards"]){
			completion(nil);
			return;
		}
		completion(result[@"messages"]);
	}];
}
}

- (void)publicMessagesByTag:(NSString *)tag offset:(NSString *)offset completion:(void (^)(NSArray *messages, NSString *next))completion {
	[[TGClient shared] publicMessagesByTag:tag offset:offset completion:completion];
}

- (void)rateSpeechInChat:(int64_t)chatId message:(int64_t)messageId isGood:(BOOL)isGood completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] rateSpeechInChat:chatId message:messageId isGood:isGood completion:completion];
}

- (void)reactTo:(int64_t)messageId inChat:(int64_t)chatId emoji:(NSString *)emoji {
	[[TGClient shared] send:@{
		@"@type"      : @"addMessageReaction",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"reaction_type" : @{@"@type" : @"reactionTypeEmoji", @"emoji" : emoji},
		@"is_big"     : @NO,
		@"update_recent_reactions" : @YES,
	}];
}

- (void)readAllChatPollVotes:(int64_t)chatId {
	[[TGClient shared] readAllChatPollVotes:chatId];
}

- (void)readAllDirectMessagesChatTopicReactions:(int64_t)topicId inChat:(int64_t)chatId completion:(void (^)(BOOL ok,
                                                          NSString *error))completion {
	[[TGClient shared] readAllDirectMessagesChatTopicReactions:topicId inChat:chatId completion:completion];
}

- (void)readAllMentionsAndReactionsInChat:(int64_t)chatId {
	[[TGClient shared] readAllMentionsAndReactionsInChat:chatId];
}

- (void)readDateOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSTimeInterval date, NSString *reason))completion {
{
	[[TGClient shared] request:@{@"@type" : @"getMessageReadDate",
					@"chat_id" : @(chatId), @"message_id" : @(messageId)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		NSString *kind = result[@"@type"] ?: @"";
		if ([kind isEqualToString:@"messageReadDateRead"]){
			completion([result[@"read_date"] doubleValue], nil);
		} else if ([kind isEqualToString:@"messageReadDateUnread"]){
			completion(0, @"Not read yet");
		} else if ([kind isEqualToString:@"messageReadDateTooOld"]){
			completion(0, @"Read too long ago for Telegram to say when");
		} else if ([kind isEqualToString:@"messageReadDateUserPrivacyRestricted"]){
			completion(0, @"They hide their read receipts");
		} else if ([kind isEqualToString:@"messageReadDateMyPrivacyRestricted"]){
			completion(0, @"This account hides its own read receipts");
		} else {
			completion(0, @"Not available");
		}
	}];
}
}

- (void)readdQuickReplyShortcutMessages:(NSArray *)messageIds shortcutName:(NSString *)shortcutName completion:(void (^)(NSArray *messages, NSString *error))completion {
	[[TGClient shared] readdQuickReplyShortcutMessages:messageIds shortcutName:shortcutName completion:completion];
}

- (void)recentLocationsInChat:(int64_t)chatId completion:(void (^)(NSArray *messages))completion {
{
	[[TGClient shared] request:@{@"@type" : @"searchChatRecentLocationMessages",
					@"chat_id" : @(chatId),
					@"limit" : @(20)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"messages"]){
			completion(nil);
			return;
		}
		completion(result[@"messages"]);
	}];
}
}

- (void)recognizeSpeechInChat:(int64_t)chatId message:(int64_t)messageId completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] recognizeSpeechInChat:chatId message:messageId completion:completion];
}

- (void)recommendedChatsWithCompletion:(void (^)(NSArray *chats))completion {
	[[TGClient shared] recommendedChatsWithCompletion:completion];
}

- (void)removeActionBarInChat:(int64_t)chatId {
	[[TGClient shared] removeActionBarInChat:chatId];
}

- (void)removeReaction:(NSString *)emoji fromMessage:(int64_t)messageId inChat:(int64_t)chatId {
	if (!emoji.length)
		return;
	[[TGClient shared] send:@{
		@"@type"         : @"removeMessageReaction",
		@"chat_id"       : @(chatId),
		@"message_id"    : @(messageId),
		@"reaction_type" : @{@"@type" : @"reactionTypeEmoji", @"emoji" : emoji},
	}];
}

- (void)reorderQuickReplyShortcuts:(NSArray *)shortcutIds completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] reorderQuickReplyShortcuts:shortcutIds completion:completion];
}

- (void)repliedMessageTo:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *message))completion {
{
	[[TGClient shared] request:@{@"@type"      : @"getRepliedMessage",
					@"chat_id"    : @(chatId),
					@"message_id" : @(messageId)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		NSDictionary *parsed = [result[@"id"] longLongValue]
				? TGFlattenMessage(result) : nil;
		if (parsed){



			NSMutableDictionary *withChat = [parsed mutableCopy];
			withChat[@"chatId"] = result[@"chat_id"];
			parsed = withChat;
		}
		completion(parsed);
	}];
}
}

- (void)replyKeyboardForChat:(int64_t)chatId completion:(void (^)(NSDictionary *keyboard))completion {
	[[TGClient shared] replyKeyboardForChat:chatId completion:completion];
}

- (void)reportChat:(int64_t)chatId optionId:(NSString *)optionId text:(NSString *)text completion:(void (^)(NSString *title, NSArray *options, BOOL done))completion {
	[[TGClient shared] reportChat:chatId optionId:optionId text:text completion:completion];
}

- (void)reportChatPhotoInChat:(int64_t)chatId reason:(NSString *)reason detail:(NSString *)detail completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] reportChatPhotoInChat:chatId reason:reason detail:detail completion:completion];
}

- (void)reportReactionBySender:(NSDictionary *)sender ofMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
{
	if (![sender isKindOfClass:NSDictionary.class]){
		if (completion) completion(NO);
		return;
	}
	[[TGClient shared] request:@{
		@"@type"      : @"reportMessageReactions",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"sender_id"  : sender,
	} completion:^void (NSDictionary *result){
		if (completion)
			completion([result[@"@type"] isEqualToString:@"ok"]);
	}];
}
}

- (void)reportSpamMessages:(NSArray *)messageIds inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] reportSpamMessages:messageIds inChat:chatId completion:completion];
}

- (void)reportViewOfMessage:(int64_t)messageId inChat:(int64_t)chatId timeInViewMs:(NSInteger)timeInViewMs activeTimeInViewMs:(NSInteger)activeTimeInViewMs heightRatio:(NSInteger)heightPerMille seenRangeRatio:(NSInteger)seenPerMille completion:(void (^)(BOOL ok))completion {
{
	[[TGClient shared] request:@{
		@"@type"                           : @"sendMessageViewMetrics",
		@"chat_id"                         : @(chatId),
		@"message_id"                      : @(messageId),
		@"time_in_view_ms"                 : @(MAX((NSInteger)0, timeInViewMs)),
		@"active_time_in_view_ms"          : @(MAX((NSInteger)0, activeTimeInViewMs)),
		@"height_to_viewport_ratio_per_mille" : @(MAX((NSInteger)0, MIN(heightPerMille, (NSInteger)1000))),
		@"seen_range_ratio_per_mille"      : @(MAX((NSInteger)0, MIN(seenPerMille, (NSInteger)1000))),
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}
}

- (void)request:(NSDictionary *)request completion:(void (^)(NSDictionary *result))completion {
	[[TGClient shared] request:request completion:completion];
}

- (int64_t)savedMessagesChatId {
	return [[TGClient shared] savedMessagesChatId];
}

- (void)savedTopicMessageAtDate:(int64_t)topicId date:(NSInteger)date completion:(void (^)(NSDictionary *message))completion {
	[[TGClient shared] savedTopicMessageAtDate:topicId date:date completion:completion];
}

- (void)savedTopicsTags:(int64_t)topicId completion:(void (^)(NSArray *tags))completion {
	[[TGClient shared] savedTopicsTags:topicId completion:completion];
}

- (void)scheduledMessagesInChat:(int64_t)chatId completion:(void (^)(NSArray *messages))completion {
	[[TGClient shared] scheduledMessagesInChat:chatId completion:completion];
}

- (void)searchInChat:(int64_t)chatId query:(NSString *)query completion:(void (^)(NSArray *messages))completion {
	[[TGClient shared] searchInChat:chatId query:query completion:completion];
}

- (void)searchQuote:(NSString *)quote inText:(NSString *)text position:(NSInteger)position completion:(void (^)(NSInteger position, BOOL found))completion {
	[[TGClient shared] searchQuote:quote inText:text position:position completion:completion];
}

- (void)searchSavedMessagesInTopic:(int64_t)topicId query:(NSString *)query tag:(NSDictionary *)tag from:(int64_t)fromMessageId completion:(void (^)(NSArray *found, int64_t next))completion {
	[[TGClient shared] searchSavedMessagesInTopic:topicId query:query tag:tag from:fromMessageId completion:completion];
}

- (void)searchUserByToken:(NSString *)token completion:(void (^)(NSDictionary *user, NSString *error))completion {
	[[TGClient shared] searchUserByToken:token completion:completion];
}

- (void)secretChatIdForChat:(int64_t)chatId completion:(void (^)(NSInteger secretChatId))completion {
	[[TGClient shared] secretChatIdForChat:chatId completion:completion];
}

- (void)secretChatState:(NSInteger)secretChatId completion:(void (^)(NSString *state, BOOL outgoing))completion {
	[[TGClient shared] secretChatState:secretChatId completion:completion];
}



























- (void)sendTypingToChat:(int64_t)chatId thread:(int64_t)threadId {
	[[TGClient shared] send:@{
		@"@type"             : @"sendChatAction",
		@"chat_id"           : @(chatId),
		@"message_thread_id" : @(threadId),
		@"action"            : @{@"@type" : @"chatActionTyping"},
	}];
}







- (void)setAvailableReactionsForChat:(int64_t)chatId mode:(NSString *)mode completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setAvailableReactionsForChat:chatId mode:mode completion:completion];
}

- (void)setChat:(int64_t)chatId muted:(BOOL)muted {
	[[TGClient shared] setChat:chatId muted:muted];
}

- (void)setChatAccentColour:(int64_t)chatId colourId:(NSInteger)colourId {
	[[TGClient shared] setChatAccentColour:chatId colourId:colourId];
}

- (void)setChatBackground:(int64_t)chatId imagePath:(NSString *)imagePath colour:(NSInteger)colour onlyForSelf:(BOOL)onlyForSelf completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setChatBackground:chatId imagePath:imagePath colour:colour onlyForSelf:onlyForSelf completion:completion];
}

- (void)setChatProfileAccentColour:(int64_t)chatId colourId:(NSInteger)colourId {
	[[TGClient shared] setChatProfileAccentColour:chatId colourId:colourId];
}

- (void)setChatTheme:(int64_t)chatId name:(NSString *)name completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setChatTheme:chatId name:name completion:completion];
}

- (void)setClientNote:(NSString *)note forChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setClientNote:note forChat:chatId completion:completion];
}

- (void)setDefaultReactionEmoji:(NSString *)emoji completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setDefaultReactionEmoji:emoji completion:completion];
}

- (void)setDirectMessagesChatTopic:(int64_t)topicId inChat:(int64_t)chatId markedAsUnread:(BOOL)markedAsUnread completion:(void (^)(BOOL ok,
                                             NSString *error))completion {
	[[TGClient shared] setDirectMessagesChatTopic:topicId inChat:chatId markedAsUnread:markedAsUnread completion:completion];
}

- (void)setDiscussionGroup:(int64_t)discussionChatId forChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setDiscussionGroup:discussionChatId forChat:chatId completion:completion];
}

- (void)setDraft:(NSString *)text inChat:(int64_t)chatId thread:(int64_t)threadId replyTo:(int64_t)replyToId {
	[[TGClient shared] setDraft:text inChat:chatId thread:threadId replyTo:replyToId];
}

- (void)setEmojiPhotoForChat:(int64_t)chatId customEmojiId:(int64_t)customEmojiId colour:(NSInteger)colour completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setEmojiPhotoForChat:chatId customEmojiId:customEmojiId colour:colour completion:completion];
}

- (void)setGameScoreForChat:(int64_t)chatId message:(int64_t)messageId user:(int64_t)userId score:(int32_t)score force:(BOOL)force editMessage:(BOOL)editMessage completion:(void (^)(NSDictionary *message,
									  NSString *error))completion {
	[[TGClient shared] setGameScoreForChat:chatId message:messageId user:userId score:score force:force editMessage:editMessage completion:completion];
}

- (void)setInlineGameScore:(NSString *)inlineMessageId user:(int64_t)userId score:(int32_t)score force:(BOOL)force editMessage:(BOOL)editMessage completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] setInlineGameScore:inlineMessageId user:userId score:score force:force editMessage:editMessage completion:completion];
}

- (void)setLocationAddress:(NSString *)address forChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setLocationAddress:address forChat:chatId completion:completion];
}

- (void)setMessageFactCheck:(int64_t)messageId inChat:(int64_t)chatId text:(NSString *)text completion:(void (^)(BOOL ok, NSString *error))completion {
{
	NSString *clean = [text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	[[TGClient shared] request:@{
		@"@type"      : @"setMessageFactCheck",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"text"       : clean.length ? TGFormattedText(clean) : [NSNull null],
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}
}

- (void)setPinnedSavedTopics:(NSArray *)topicIds {
	[[TGClient shared] setPinnedSavedTopics:topicIds];
}

- (void)setQuickReplyShortcutName:(NSInteger)shortcutId name:(NSString *)name completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] setQuickReplyShortcutName:shortcutId name:name completion:completion];
}



- (void)setSlowModeDelayForChat:(int64_t)chatId seconds:(NSInteger)seconds completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setSlowModeDelayForChat:chatId seconds:seconds completion:completion];
}

- (void)setSticker:(NSInteger)fileId favourite:(BOOL)favourite {
	[[TGClient shared] setSticker:fileId favourite:favourite];
}

- (void)setStickerSet:(id)setId installed:(BOOL)installed archived:(BOOL)archived {
	[[TGClient shared] setStickerSet:setId installed:installed archived:archived];
}

- (void)setUser:(int64_t)userId blocked:(BOOL)blocked completion:(void (^)(BOOL ok))completion {
	NSDictionary *sender = userId < 0
			? @{@"@type" : @"messageSenderChat", @"chat_id" : @(userId)}
			: @{@"@type" : @"messageSenderUser", @"user_id" : @(userId)};
	[[TGClient shared] request:@{
		@"@type"      : @"setMessageSenderBlockList",
		@"sender_id"  : sender,
		@"block_list" : blocked ? @{@"@type" : @"blockListMain"} : [NSNull null],
	} completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"@type"] isEqualToString:@"ok"]);
	}];
}

- (void)setUser:(int64_t)userId blocked:(BOOL)blocked {
	[[TGClient shared] setUser:userId blocked:blocked];
}

- (void)sharePhoneNumberWithUser:(int64_t)userId {
	[[TGClient shared] sharePhoneNumberWithUser:userId];
}

- (void)sparsePositionsInChat:(int64_t)chatId fromMessageId:(int64_t)fromMessageId thread:(int64_t)threadId limit:(NSInteger)limit completion:(void (^)(NSArray *messageIds))completion {
	[[TGClient shared] sparsePositionsInChat:chatId fromMessageId:fromMessageId thread:threadId limit:limit completion:completion];
}

- (void)stakeDiceStateWithCompletion:(void (^)(NSDictionary *state,
                                              NSString *error))completion {
	[[TGClient shared] stakeDiceStateWithCompletion:completion];
}

- (void)statisticsOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *statistics))completion {
{
	[[TGClient shared] request:@{
		@"@type"      : @"getMessageStatistics",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),


		@"is_dark"    : @NO,
	} completion:^(NSDictionary *result){
		if (!completion)
			return;
		completion([result[@"@type"] isEqualToString:@"messageStatistics"]
				? result : nil);
	}];
}
}

- (void)statusForUser:(int64_t)userId completion:(void (^)(NSString *status))completion {
	[[TGClient shared] statusForUser:userId completion:completion];
}

- (void)stickerSetByShortName:(NSString *)shortName completion:(void (^)(NSDictionary *set))completion {
	[[TGClient shared] stickerSetByShortName:shortName completion:completion];
}

- (void)stopPoll:(int64_t)messageId inChat:(int64_t)chatId {
	[[TGClient shared] send:@{
		@"@type"      : @"stopPoll",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
	}];
}

- (void)suggestedPostForMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *post, NSString *error))completion {
	[[TGClient shared] suggestedPostForMessage:messageId inChat:chatId completion:completion];
}

- (void)suitableDiscussionChatsWithCompletion:(void (^)(NSArray *chats))completion {
	[[TGClient shared] suitableDiscussionChatsWithCompletion:completion];
}

- (void)summarizeMessage:(int64_t)messageId inChat:(int64_t)chatId translateTo:(NSString *)languageCode tone:(NSString *)tone completion:(void (^)(NSString *text, NSString *error))completion {
	[[TGClient shared] summarizeMessage:messageId inChat:chatId translateTo:languageCode tone:tone completion:completion];
}

- (void)textEntitiesInText:(NSString *)text completion:(void (^)(NSArray *entities))completion {
	[[TGClient shared] textEntitiesInText:text completion:completion];
}

- (NSString *)titleForChat:(int64_t)chatId {
	return [[TGClient shared] titleForChat:chatId];
}

- (void)toggleDefaultSilentForChat:(int64_t)chatId on:(BOOL)on {
	[[TGClient shared] toggleDefaultSilentForChat:chatId on:on];
}

- (void)toggleProtectedContentForChat:(int64_t)chatId on:(BOOL)on completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] toggleProtectedContentForChat:chatId on:on completion:completion];
}

- (void)toggleSavedTopicPinned:(int64_t)topicId pinned:(BOOL)pinned {
	[[TGClient shared] toggleSavedTopicPinned:topicId pinned:pinned];
}

- (void)toggleTranslatableForChat:(int64_t)chatId on:(BOOL)on {
	[[TGClient shared] toggleTranslatableForChat:chatId on:on];
}

- (void)topChatsWithCompletion:(void (^)(NSArray *chats))completion {
	[[TGClient shared] topChatsWithCompletion:completion];
}

- (void)translateMessage:(int64_t)messageId inChat:(int64_t)chatId toCode:(NSString *)languageCode completion:(void (^)(NSString *text))completion {
{
	if (!languageCode.length)
		languageCode = [[NSLocale currentLocale] objectForKey:
				NSLocaleLanguageCode] ?: @"en";
	[[TGClient shared] request:@{@"@type"   : @"translateMessageText",
					@"chat_id" : @(chatId),
					@"message_id" : @(messageId),
					@"to_language_code" : languageCode,
					@"tone" : @""}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"formattedText"]){
			completion(@"");
			return;
		}
		completion(result[@"text"]);
	}];
}
}

- (void)translateMessageRichMessage:(int64_t)messageId inChat:(int64_t)chatId toCode:(NSString *)languageCode tone:(NSString *)tone completion:(void (^)(NSString *text, NSString *error))completion {
	[[TGClient shared] translateMessageRichMessage:messageId inChat:chatId toCode:languageCode tone:tone completion:completion];
}

- (void)translateText:(NSString *)text toLanguageCode:(NSString *)languageCode tone:(NSString *)tone completion:(void (^)(NSString *text))completion {
{
	if (!text.length){
		if (completion) completion(nil);
		return;
	}
	NSString *code = languageCode.length ? languageCode
			: ([[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode] ?: @"en");
	[[TGClient shared] request:@{
		@"@type" : @"translateText",
		@"text" : @{@"@type" : @"formattedText",
					@"text" : text,
					@"entities" : @[]},
		@"to_language_code" : code,
		@"tone" : tone ?: @"",
	} completion:^(NSDictionary *result){
		if (!completion)
			return;
		NSString *translated = [result[@"@type"] isEqualToString:@"formattedText"]
				? result[@"text"] : nil;
		completion([translated isKindOfClass:NSString.class] ? translated : nil);
	}];
}
}

- (void)unpinAllDirectMessagesChatTopicMessages:(int64_t)topicId inChat:(int64_t)chatId completion:(void (^)(BOOL ok,
                                                          NSString *error))completion {
	[[TGClient shared] unpinAllDirectMessagesChatTopicMessages:topicId inChat:chatId completion:completion];
}

- (void)unpinAllMessagesInChat:(int64_t)chatId thread:(int64_t)threadId {
	if (threadId)
		[[TGClient shared] send:@{@"@type" : @"unpinAllForumTopicMessages",
						 @"chat_id" : @(chatId), @"forum_topic_id" : @(threadId)}];
	else
		[[TGClient shared] send:@{@"@type" : @"unpinAllChatMessages", @"chat_id" : @(chatId)}];
}

- (void)unpinMessage:(int64_t)messageId inChat:(int64_t)chatId {
	[[TGClient shared] send:@{
		@"@type"      : @"unpinChatMessage",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
	}];
}

- (void)userForPhone:(NSString *)phone completion:(void (^)(NSDictionary *user))completion {
	[[TGClient shared] userForPhone:phone completion:completion];
}

- (void)userInfo:(int64_t)userId completion:(void (^)(NSDictionary *user))completion {
	[[TGClient shared] userInfo:userId completion:completion];
}

- (void)viewersOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSArray *viewers))completion {
{
	[[TGClient shared] request:@{@"@type" : @"getMessageViewers",
					@"chat_id" : @(chatId), @"message_id" : @(messageId)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"messageViewers"]){
			completion(nil);
			return;
		}
		completion(result[@"viewers"]);
	}];
}
}

- (void)votePoll:(int64_t)messageId inChat:(int64_t)chatId options:(NSArray *)optionIds {
	[[TGClient shared] send:@{
		@"@type"      : @"setPollAnswer",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"option_ids" : optionIds ?: @[],
	}];
}

- (void)webBrowserTypeForURL:(NSString *)url completion:(void (^)(NSString *kind))completion {
	[[TGClient shared] webBrowserTypeForURL:url completion:completion];
}

#pragma mark - properties

- (TGConnectionState)connectionState {
	return [TGClient shared].connectionState;
}

- (NSArray *)chats {
	return [TGClient shared].chats;
}

- (NSArray *)folders {
	return [TGClient shared].folders;
}

- (NSArray *)communities {
	return [TGClient shared].communities;
}

- (NSArray *)savedTopics {
	return [TGClient shared].savedTopics;
}

- (NSArray *)quickReplyShortcuts {
	NSMutableArray *out = [NSMutableArray array];
	for (NSNumber *ident in [TGClient shared].quickReplyShortcutOrder){
		NSDictionary *row = [TGClient shared].quickReplyShortcutsById[ident];
		if (row)
			[out addObject:row];
	}
	return out;
}

- (NSDictionary *)me {
	return [TGClient shared].me;
}

- (NSArray *)availableMessageEffectIds {
	return [TGClient shared].availableMessageEffectIds;
}

- (NSArray *)availableStickerEffectIds {
	return [TGClient shared].availableStickerEffectIds;
}

- (NSString *)defaultReactionEmoji {
	return [TGClient shared].defaultReactionEmoji;
}

- (void)setOnMessage:(void (^)(int64_t chatId, NSDictionary *message, int64_t deletedId))block {
	[TGClient shared].onMessage = block;
}

- (void (^)(int64_t, NSDictionary *, int64_t))onMessage {
	return [TGClient shared].onMessage;
}

- (void)setOnChatAction:(void (^)(int64_t chatId, NSString *action))block {
	[TGClient shared].onChatAction = block;
}

- (void (^)(int64_t, NSString *))onChatAction {
	return [TGClient shared].onChatAction;
}

- (void)setOnSecretChat:(void (^)(NSInteger secretChatId, NSString *state))block {
	[TGClient shared].onSecretChat = block;
}

- (void (^)(NSInteger, NSString *))onSecretChat {
	return [TGClient shared].onSecretChat;
}

- (void)setOnFileProgress:(void (^)(NSInteger fileId, float progress))block {
	[TGClient shared].onFileProgress = block;
}

- (void (^)(NSInteger, float))onFileProgress {
	return [TGClient shared].onFileProgress;
}


@end
