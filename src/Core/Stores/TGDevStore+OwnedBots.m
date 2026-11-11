//
// TGDevStore+OwnedBots.m - the Dev store's OwnedBots requests.
//
// Bodies copied from src/Core/Client/Audit/TGClient+OwnedBots.m; the store owns them.
//

#import "TGDevStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGDevStore (OwnedBots)

#pragma mark - owned bots

- (BOOL)userIsBot:(int64_t)userId {
	NSDictionary *raw = [TGClient shared].rawUsersById[@(userId)];
	NSDictionary *type = raw[@"type"];
	return [type[@"@type"] isEqualToString:@"userTypeBot"];
}

- (void)ownedBotsWithCompletion:(void (^)(NSArray *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getOwnedBots"} completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		// Users carries ids, not records: TDLib keeps the user objects in its
		// own cache and the client already has their names from updateUser.
		NSMutableArray *rows = [NSMutableArray array];
		for (NSNumber *identifier in result[@"user_ids"]){
			if (![identifier isKindOfClass:NSNumber.class])
				continue;
			int64_t userId = identifier.longLongValue;
			[rows addObject:@{
				@"id" : @(userId),
				@"name" : [[TGClient shared] nameForUserId:userId] ?: @"Bot",
				@"username" : @"",
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)checkBotUsername:(NSString *)username
			  isSecondary:(BOOL)isSecondary
			   completion:(void (^)(NSString *, NSString *))completion {
	username = [username stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!username.length){
		if (completion) completion(nil, @"A username is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"checkBotUsername",
					@"username" : username,
					@"is_secondary" : @(isSecondary)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSString *word = TGAuditShortType(result[@"@type"]);
		if (completion) completion(word, nil);
	}];
}

- (void)botNameForBot:(int64_t)botUserId
			 language:(NSString *)language
		   completion:(void (^)(NSString *, NSString *))completion {
	if (!botUserId){
		if (completion) completion(nil, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getBotName", @"bot_user_id" : @(botUserId),
					@"language_code" : (language ?: @"")}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditString(result, @"text"), nil);
	}];
}

- (void)setBotName:(NSString *)name
			forBot:(int64_t)botUserId
		  language:(NSString *)language
		completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId){
		if (completion) completion(NO, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"setBotName", @"bot_user_id" : @(botUserId),
					@"language_code" : (language ?: @""), @"name" : (name ?: @"")}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)botDescriptionForBot:(int64_t)botUserId
					language:(NSString *)language
				  completion:(void (^)(NSString *, NSString *))completion {
	if (!botUserId){
		if (completion) completion(nil, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getBotInfoDescription", @"bot_user_id" : @(botUserId),
					@"language_code" : (language ?: @"")}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditString(result, @"text"), nil);
	}];
}

- (void)setBotDescription:(NSString *)text
				   forBot:(int64_t)botUserId
				 language:(NSString *)language
			   completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId){
		if (completion) completion(NO, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"setBotInfoDescription",
					@"bot_user_id" : @(botUserId),
					@"language_code" : (language ?: @""),
					@"description" : (text ?: @"")}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)botShortDescriptionForBot:(int64_t)botUserId
						 language:(NSString *)language
					   completion:(void (^)(NSString *, NSString *))completion {
	if (!botUserId){
		if (completion) completion(nil, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getBotInfoShortDescription",
					@"bot_user_id" : @(botUserId),
					@"language_code" : (language ?: @"")}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditString(result, @"text"), nil);
	}];
}

- (void)setBotShortDescription:(NSString *)text
						forBot:(int64_t)botUserId
					  language:(NSString *)language
					completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId){
		if (completion) completion(NO, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"setBotInfoShortDescription",
					@"bot_user_id" : @(botUserId),
					@"language_code" : (language ?: @""),
					@"short_description" : (text ?: @"")}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)removeBotProfilePhoto:(int64_t)botUserId
				   completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId){
		if (completion) completion(NO, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"setBotProfilePhoto",
					@"bot_user_id" : @(botUserId),
					@"photo" : [NSNull null]}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)addBotSecondaryUsername:(NSString *)username
						 forBot:(int64_t)botUserId
					 completion:(void (^)(BOOL, NSString *))completion {
	username = [username stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!botUserId || !username.length){
		if (completion) completion(NO, @"A bot id and a username are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"addBotSecondaryUsername",
					@"bot_user_id" : @(botUserId), @"username" : username}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)deleteBotSecondaryUsernameForBot:(int64_t)botUserId
							  completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId){
		if (completion) completion(NO, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"deleteBotSecondaryUsername",
					@"bot_user_id" : @(botUserId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)setBotUsername:(NSString *)username
				active:(BOOL)active
				forBot:(int64_t)botUserId
			completion:(void (^)(BOOL, NSString *))completion {
	username = [username stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!botUserId || !username.length){
		if (completion) completion(NO, @"A bot id and a username are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"toggleBotUsernameIsActive",
					@"bot_user_id" : @(botUserId),
					@"username" : username,
					@"is_active" : @(active)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)reorderBotActiveUsernames:(NSArray *)usernames
						   forBot:(int64_t)botUserId
					   completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId || !usernames.count){
		if (completion) completion(NO, @"A bot id and its usernames are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"reorderBotActiveUsernames",
					@"bot_user_id" : @(botUserId),
					@"usernames" : usernames}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)botMediaPreviewsForBot:(int64_t)botUserId
					completion:(void (^)(NSArray *, NSString *))completion {
	if (!botUserId){
		if (completion) completion(nil, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getBotMediaPreviews", @"bot_user_id" : @(botUserId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *preview in result[@"previews"]){
			if (![preview isKindOfClass:NSDictionary.class])
				continue;
			NSDictionary *content = preview[@"content"];
			[rows addObject:@{
				@"date"        : TGAuditNumber(preview, @"date"),
				@"contentType" : TGAuditShortType(content[@"@type"]),
				@"fileId"      : TGAuditNumber(content[@"photo"] ?: content[@"video"], @"id"),
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)botMediaPreviewInfoForBot:(int64_t)botUserId
						 language:(NSString *)language
					   completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!botUserId){
		if (completion) completion(nil, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getBotMediaPreviewInfo",
					@"bot_user_id" : @(botUserId),
					@"language_code" : (language ?: @"")}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *previews = [NSMutableArray array];
		for (NSDictionary *preview in result[@"previews"]){
			if (![preview isKindOfClass:NSDictionary.class])
				continue;
			[previews addObject:@{@"date" : TGAuditNumber(preview, @"date"),
								  @"contentType" : TGAuditShortType(preview[@"content"][@"@type"])}];
		}
		NSArray *languages = result[@"language_codes"];
		if (completion)
			completion(@{@"previews" : previews,
						 @"languages" : ([languages isKindOfClass:NSArray.class]
								 ? languages : @[])}, nil);
	}];
}

- (NSDictionary *)botPreviewContentForFile:(int32_t)fileId video:(BOOL)video {
	NSDictionary *input = @{@"@type" : @"inputFileId", @"id" : @(fileId)};
	if (video){
		return @{@"@type" : @"inputStoryContentVideo",
				 @"video" : input,
				 @"added_sticker_file_ids" : @[],
				 @"duration" : @0.0,
				 @"cover_frame_timestamp" : @0.0,
				 @"is_animation" : @NO};
	}
	return @{@"@type" : @"inputStoryContentPhoto",
			 @"photo" : input,
			 @"added_sticker_file_ids" : @[]};
}

- (void)addBotMediaPreviewForBot:(int64_t)botUserId
						language:(NSString *)language
						  fileId:(int32_t)fileId
						   video:(BOOL)video
					  completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!botUserId || fileId <= 0){
		if (completion) completion(nil, @"A bot id and a file id are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"addBotMediaPreview",
					@"bot_user_id" : @(botUserId),
					@"language_code" : (language ?: @""),
					@"content" : [self botPreviewContentForFile:fileId video:video]}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"date" : TGAuditNumber(result, @"date"),
						 @"contentType" : TGAuditShortType(result[@"content"][@"@type"])}, nil);
	}];
}

- (void)editBotMediaPreviewForBot:(int64_t)botUserId
						 language:(NSString *)language
						   fileId:(int32_t)fileId
					   newFileId:(int32_t)newFileId
							video:(BOOL)video
					   completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!botUserId || fileId <= 0 || newFileId <= 0){
		if (completion) completion(nil, @"A bot id and both file ids are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"editBotMediaPreview",
					@"bot_user_id" : @(botUserId),
					@"language_code" : (language ?: @""),
					@"file_id" : @(fileId),
					@"content" : [self botPreviewContentForFile:newFileId video:video]}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"date" : TGAuditNumber(result, @"date"),
						 @"contentType" : TGAuditShortType(result[@"content"][@"@type"])}, nil);
	}];
}

- (void)deleteBotMediaPreviewsForBot:(int64_t)botUserId
							language:(NSString *)language
							 fileIds:(NSArray *)fileIds
						  completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId || !fileIds.count){
		if (completion) completion(NO, @"A bot id and file ids are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"deleteBotMediaPreviews",
					@"bot_user_id" : @(botUserId),
					@"language_code" : (language ?: @""),
					@"file_ids" : fileIds}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)reorderBotMediaPreviewsForBot:(int64_t)botUserId
							 language:(NSString *)language
							  fileIds:(NSArray *)fileIds
						   completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId || !fileIds.count){
		if (completion) completion(NO, @"A bot id and file ids are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"reorderBotMediaPreviews",
					@"bot_user_id" : @(botUserId),
					@"language_code" : (language ?: @""),
					@"file_ids" : fileIds}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)similarBotCountForBot:(int64_t)botUserId
						local:(BOOL)localOnly
				   completion:(void (^)(int32_t, NSString *))completion {
	if (!botUserId){
		if (completion) completion(0, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getBotSimilarBotCount",
					@"bot_user_id" : @(botUserId),
					@"return_local" : @(localOnly)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(0, TGAuditError(result));
			return;
		}
		if (completion) completion([TGAuditNumber(result, @"count") intValue], nil);
	}];
}

- (void)similarBotsForBot:(int64_t)botUserId
			   completion:(void (^)(NSArray *, NSString *))completion {
	if (!botUserId){
		if (completion) completion(nil, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getBotSimilarBots", @"bot_user_id" : @(botUserId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *user in result[@"users"]){
			if ([user isKindOfClass:NSDictionary.class])
				[rows addObject:TGAuditUser(user)];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)openSimilarBot:(int64_t)openedBotId
			   fromBot:(int64_t)botUserId
			completion:(void (^)(BOOL, NSString *))completion {
	if (!openedBotId || !botUserId){
		if (completion) completion(NO, @"Both bot ids are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"openBotSimilarBot",
					@"bot_user_id" : @(botUserId),
					@"opened_bot_user_id" : @(openedBotId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)setBotCanManageEmojiStatus:(BOOL)allowed
							forBot:(int64_t)botUserId
						completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId){
		if (completion) completion(NO, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"toggleBotCanManageEmojiStatus",
					@"bot_user_id" : @(botUserId),
					@"can_manage_emoji_status" : @(allowed)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)setBotVerification:(int64_t)botUserId
			 verifiedKind:(NSString *)kind
				 verifiedId:(int64_t)verifiedId
				description:(NSString *)description
				 completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId || !verifiedId){
		if (completion) completion(NO, @"A bot id and a verified account id are needed.");
		return;
	}
	NSDictionary *formatted = @{@"@type" : @"formattedText",
								@"text" : (description ?: @""),
								@"entities" : @[]};
	[[TGClient shared] request:@{@"@type" : @"setMessageSenderBotVerification",
					@"bot_user_id" : @(botUserId),
					@"verified_id" : TGAuditSender(kind, verifiedId),
					@"custom_description" : formatted}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)removeBotVerification:(int64_t)botUserId
				 verifiedKind:(NSString *)kind
					 verifiedId:(int64_t)verifiedId
				   completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId || !verifiedId){
		if (completion) completion(NO, @"A bot id and a verified account id are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"removeMessageSenderBotVerification",
					@"bot_user_id" : @(botUserId),
					@"verified_id" : TGAuditSender(kind, verifiedId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)createBotNamed:(NSString *)name
			  username:(NSString *)username
			  manager:(int64_t)managerBotId
			completion:(void (^)(NSDictionary *, NSString *))completion {
	name = [name stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	username = [username stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!managerBotId || !name.length || !username.length){
		if (completion) completion(nil, @"A manager bot, a name and a username are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"createBot",
					@"manager_bot_user_id" : @(managerBotId),
					@"name" : name,
					@"username" : username,
					@"via_link" : @NO}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditUser(result), nil);
	}];
}

- (void)recentInlineBotsWithCompletion:(void (^)(NSArray *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getRecentInlineBots"} completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *user in result[@"users"]){
			if ([user isKindOfClass:NSDictionary.class])
				[rows addObject:TGAuditUser(user)];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)startBot:(int64_t)botUserId
		  inChat:(int64_t)chatId
	   parameter:(NSString *)parameter
	  completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!botUserId || !chatId){
		if (completion) completion(nil, @"A bot id and a chat id are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"sendBotStartMessage",
					@"bot_user_id" : @(botUserId),
					@"chat_id" : @(chatId),
					@"parameter" : (parameter ?: @"")}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"id" : TGAuditNumber(result, @"id"),
						 @"date" : TGAuditNumber(result, @"date"),
						 @"contentType" : TGAuditShortType(result[@"content"][@"@type"])}, nil);
	}];
}

- (void)attachmentMenuBot:(int64_t)botUserId
			   completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!botUserId){
		if (completion) completion(nil, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getAttachmentMenuBot", @"bot_user_id" : @(botUserId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"name" : TGAuditString(result, @"name"),
						 @"isAdded" : @([result[@"is_added"] boolValue]),
						 @"requestWriteAccess" : @([result[@"request_write_access"] boolValue]),
						 @"supportsSelfChat" : @([result[@"supports_self_chat"] boolValue]),
						 @"supportsUserChats" : @([result[@"supports_user_chats"] boolValue]),
						 @"supportsBotChats" : @([result[@"supports_bot_chats"] boolValue]),
						 @"supportsGroupChats" : @([result[@"supports_group_chats"] boolValue]),
						 @"supportsChannelChats" : @([result[@"supports_channel_chats"] boolValue])}, nil);
	}];
}

- (void)setBotOnAttachmentMenu:(int64_t)botUserId
					   added:(BOOL)added
			 allowWriteAccess:(BOOL)allowWriteAccess
					completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId){
		if (completion) completion(NO, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"toggleBotIsAddedToAttachmentMenu",
					@"bot_user_id" : @(botUserId),
					@"is_added" : @(added),
					@"allow_write_access" : @(allowWriteAccess)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)canBotSendMessages:(int64_t)botUserId
				completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId){
		if (completion) completion(NO, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"canBotSendMessages", @"bot_user_id" : @(botUserId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)allowBotToSendMessages:(int64_t)botUserId
					completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId){
		if (completion) completion(NO, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"allowBotToSendMessages", @"bot_user_id" : @(botUserId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)addInlineResultToQuickReply:(NSString *)shortcutName
						 replyToId:(int64_t)replyToMessageId
						   queryId:(int64_t)queryId
						  resultId:(NSString *)resultId
						 hideViaBot:(BOOL)hideViaBot
						completion:(void (^)(NSDictionary *, NSString *))completion {
	shortcutName = [shortcutName stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	resultId = [resultId stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!shortcutName.length || !queryId || !resultId.length){
		if (completion) completion(nil, @"A shortcut, a query id and a result id are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"addQuickReplyShortcutInlineQueryResultMessage",
					@"shortcut_name" : shortcutName,
					@"reply_to_message_id" : @(replyToMessageId),
					@"query_id" : @(queryId),
					@"result_id" : resultId,
					@"hide_via_bot" : @(hideViaBot)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"id" : TGAuditNumber(result, @"id"),
						 @"contentType" : TGAuditShortType(result[@"content"][@"@type"])}, nil);
	}];
}

@end
