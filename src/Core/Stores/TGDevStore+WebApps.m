//
// TGDevStore+WebApps.m - the Dev store's WebApps requests.
//
// Bodies copied from src/Core/Client/Audit/TGClient+WebApps.m; the store owns them.
//

#import "TGDevStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGDevStore (WebApps)

#pragma mark - browser settings and Web App links

- (void)setWebBrowserSettingsOpenExternal:(BOOL)openExternal
						displayCloseButton:(BOOL)displayCloseButton
							   completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"changeWebBrowserSettings",
					@"open_external_browser" : @(openExternal),
					@"display_close_button" : @(displayCloseButton)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)addWebBrowserException:(NSString *)url
				  openExternal:(BOOL)openExternal
					completion:(void (^)(BOOL, NSString *))completion {
	url = [url stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!url.length){
		if (completion) completion(NO, @"A URL is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"addWebBrowserSettingsException",
					@"open_external_browser" : @(openExternal),
					@"url" : url}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)removeWebBrowserException:(NSString *)url
					   completion:(void (^)(BOOL, NSString *))completion {
	url = [url stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!url.length){
		if (completion) completion(NO, @"A URL is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"removeWebBrowserSettingsException", @"url" : url}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)removeAllWebBrowserExceptionsWithCompletion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"removeAllWebBrowserSettingsExceptions"}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)grossingWebAppBotsOffset:(NSString *)offset
						   limit:(int32_t)limit
					  completion:(void (^)(NSArray *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getGrossingWebAppBots",
					@"offset" : (offset ?: @""),
					@"limit" : @(MAX((int32_t)1, MIN(limit, (int32_t)100)))}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSNumber *identifier in result[@"user_ids"]){
			if (![identifier isKindOfClass:NSNumber.class])
				continue;
			int64_t userId = identifier.longLongValue;
			[rows addObject:@{@"id" : @(userId),
							  @"name" : [[TGClient shared] nameForUserId:userId] ?: @"Bot"}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)searchWebAppForBot:(int64_t)botUserId
				 shortName:(NSString *)shortName
				completion:(void (^)(NSDictionary *, NSString *))completion {
	shortName = [shortName stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!botUserId || !shortName.length){
		if (completion) completion(nil, @"A bot id and a short name are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"searchWebApp",
					@"bot_user_id" : @(botUserId),
					@"web_app_short_name" : shortName}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSDictionary *app = result[@"web_app"];
		if (completion)
			completion(@{@"shortName" : TGAuditString(app, @"short_name"),
						 @"title" : TGAuditString(app, @"title"),
						 @"description" : TGAuditString(app, @"description"),
						 @"requestWriteAccess" : @([result[@"request_write_access"] boolValue]),
						 @"skipConfirmation" : @([result[@"skip_confirmation"] boolValue])}, nil);
	}];
}

- (void)webAppPlaceholderForBot:(int64_t)botUserId
					 completion:(void (^)(NSString *, NSString *))completion {
	if (!botUserId){
		if (completion) completion(nil, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getWebAppPlaceholder", @"bot_user_id" : @(botUserId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditString(result, @"@type"), nil);
	}];
}

- (void)webAppURLForBot:(int64_t)botUserId
					url:(NSString *)url
				   mode:(NSString *)mode
			 completion:(void (^)(NSString *, NSString *))completion {
	if (!botUserId){
		if (completion) completion(nil, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getWebAppUrl",
					@"bot_user_id" : @(botUserId),
					@"url" : (url ?: @""),
					@"parameters" : TGAuditWebAppParameters(mode)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditString(result, @"url"), nil);
	}];
}

- (void)mainWebAppForBot:(int64_t)botUserId
				  chatId:(int64_t)chatId
		  startParameter:(NSString *)startParameter
					mode:(NSString *)mode
			  completion:(void (^)(NSString *, NSString *))completion {
	if (!botUserId){
		if (completion) completion(nil, @"A bot id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getMainWebApp",
					@"chat_id" : @(chatId),
					@"bot_user_id" : @(botUserId),
					@"start_parameter" : (startParameter ?: @""),
					@"parameters" : TGAuditWebAppParameters(mode)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditString(result[@"url"], @"url"), nil);
	}];
}

- (void)webAppLinkURLForBot:(int64_t)botUserId
					 chatId:(int64_t)chatId
				  shortName:(NSString *)shortName
			 startParameter:(NSString *)startParameter
				 allowWrite:(BOOL)allowWrite
					   mode:(NSString *)mode
				 completion:(void (^)(NSString *, NSString *))completion {
	shortName = [shortName stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!botUserId || !shortName.length){
		if (completion) completion(nil, @"A bot id and a short name are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getWebAppLinkUrl",
					@"chat_id" : @(chatId),
					@"bot_user_id" : @(botUserId),
					@"web_app_short_name" : shortName,
					@"start_parameter" : (startParameter ?: @""),
					@"allow_write_access" : @(allowWrite),
					@"parameters" : TGAuditWebAppParameters(mode)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditString(result, @"url"), nil);
	}];
}

- (void)shareChatWithBot:(int64_t)botUserId
			 sourceChat:(int64_t)sourceChatId
		  sourceMessage:(int64_t)sourceMessageId
			   buttonId:(int32_t)buttonId
			  sharedChat:(int64_t)sharedChatId
				checkOnly:(BOOL)checkOnly
			   completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId || !sharedChatId){
		if (completion) completion(NO, @"A bot id and a shared chat id are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"shareChatWithBot",
					@"source" : TGAuditButtonSource(sourceChatId, sourceMessageId),
					@"button_id" : @(buttonId),
					@"shared_chat_id" : @(sharedChatId),
					@"only_check" : @(checkOnly)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)shareUsersWithBot:(int64_t)botUserId
			  sourceChat:(int64_t)sourceChatId
		   sourceMessage:(int64_t)sourceMessageId
				buttonId:(int32_t)buttonId
				 userIds:(NSArray *)userIds
			   checkOnly:(BOOL)checkOnly
			  completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId || !userIds.count){
		if (completion) completion(NO, @"A bot id and user ids are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"shareUsersWithBot",
					@"source" : TGAuditButtonSource(sourceChatId, sourceMessageId),
					@"button_id" : @(buttonId),
					@"shared_user_ids" : userIds,
					@"only_check" : @(checkOnly)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

@end
