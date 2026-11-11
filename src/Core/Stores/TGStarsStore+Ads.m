//
// TGStarsStore+Ads.m - the Stars store's Ads requests.
//
// Bodies copied from src/Core/Client/Audit/TGClient+Ads.m; the store owns them.
//

#import "TGStarsStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGStarsStore (Ads)

#pragma mark - sponsored messages

- (void)sponsoredMessagesForChat:(int64_t)chatId
					  completion:(void (^)(NSArray *, NSString *))completion {
	if (!chatId){
		if (completion) completion(nil, @"A chat id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getChatSponsoredMessages", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *message in result[@"messages"]){
			if (![message isKindOfClass:NSDictionary.class])
				continue;
			NSDictionary *sponsor = message[@"sponsor"];
			[rows addObject:@{
				@"kind"           : @"chat",
				@"messageId"      : TGAuditNumber(message, @"message_id"),
				@"isRecommended"  : @([message[@"is_recommended"] boolValue]),
				@"canBeReported"  : @([message[@"can_be_reported"] boolValue]),
				@"title"          : TGAuditString(message, @"title"),
				@"buttonText"     : TGAuditString(message, @"button_text"),
				@"additionalInfo" : TGAuditString(message, @"additional_info"),
				@"sponsor"        : TGAuditString(sponsor, @"info"),
				@"contentType"    : TGAuditShortType(message[@"content"][@"@type"]),
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)clickSponsoredMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
					mediaClick:(BOOL)mediaClick
			  fromFullscreen:(BOOL)fromFullscreen
				   completion:(void (^)(BOOL, NSString *))completion {
	if (!chatId || !messageId){
		if (completion) completion(NO, @"An error occurred.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"clickChatSponsoredMessage",
					@"chat_id" : @(chatId),
					@"message_id" : @(messageId),
					@"is_media_click" : @(mediaClick),
					@"from_fullscreen" : @(fromFullscreen)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)reportSponsoredMessage:(int64_t)messageId
						inChat:(int64_t)chatId
						option:(NSString *)optionId
					completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!chatId || !messageId){
		if (completion) completion(nil, @"An error occurred.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"reportChatSponsoredMessage",
					@"chat_id" : @(chatId),
					@"message_id" : @(messageId),
					@"option_id" : (optionId ?: @"")}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditReportResult(result), nil);
	}];
}

- (void)setSponsoredMessagesEnabled:(BOOL)enabled
						 completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"toggleHasSponsoredMessagesEnabled",
					@"has_sponsored_messages_enabled" : @(enabled)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)setChannelSponsoredMessagesEnabled:(BOOL)enabled
							  supergroupId:(int64_t)supergroupId
							   completion:(void (^)(BOOL, NSString *))completion {
	if (!supergroupId){
		if (completion) completion(NO, @"A supergroup id is needed here, not a chat id.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"toggleSupergroupCanHaveSponsoredMessages",
					@"supergroup_id" : @(supergroupId),
					@"can_have_sponsored_messages" : @(enabled)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)searchSponsoredChats:(NSString *)query
				  completion:(void (^)(NSArray *, NSString *))completion {
	query = [query stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!query.length){
		if (completion) completion(nil, @"Type what to search for.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getSearchSponsoredChats", @"query" : query}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *chat in result[@"chats"]){
			if (![chat isKindOfClass:NSDictionary.class])
				continue;
			[rows addObject:@{
				@"kind"           : @"search",
				@"uniqueId"       : TGAuditNumber(chat, @"unique_id"),
				@"chatId"         : TGAuditNumber(chat, @"chat_id"),
				@"sponsorInfo"    : TGAuditString(chat, @"sponsor_info"),
				@"additionalInfo" : TGAuditString(chat, @"additional_info"),
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)openSponsoredChat:(int64_t)uniqueId
			   completion:(void (^)(BOOL, NSString *))completion {
	if (!uniqueId){
		if (completion) completion(NO, @"A sponsored chat id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"openSponsoredChat",
					@"sponsored_chat_unique_id" : @(uniqueId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)viewSponsoredChat:(int64_t)uniqueId
			   completion:(void (^)(BOOL, NSString *))completion {
	if (!uniqueId){
		if (completion) completion(NO, @"A sponsored chat id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"viewSponsoredChat",
					@"sponsored_chat_unique_id" : @(uniqueId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)reportSponsoredChat:(int64_t)uniqueId
					 option:(NSString *)optionId
				 completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!uniqueId){
		if (completion) completion(nil, @"A sponsored chat id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"reportSponsoredChat",
					@"sponsored_chat_unique_id" : @(uniqueId),
					@"option_id" : (optionId ?: @"")}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditReportResult(result), nil);
	}];
}

- (void)videoAdvertisementsForChat:(int64_t)chatId
						 message:(int64_t)messageId
					  completion:(void (^)(NSArray *, NSString *))completion {
	if (!chatId || !messageId){
		if (completion) completion(nil, @"An error occurred.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getVideoMessageAdvertisements",
					@"chat_id" : @(chatId),
					@"message_id" : @(messageId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *ad in result[@"advertisements"]){
			if (![ad isKindOfClass:NSDictionary.class])
				continue;
			[rows addObject:@{
				@"kind"               : @"video",
				@"uniqueId"           : TGAuditNumber(ad, @"unique_id"),
				@"text"               : TGAuditString(ad, @"text"),
				@"title"              : TGAuditString(ad, @"title"),
				@"additionalInfo"     : TGAuditString(ad, @"additional_info"),
				@"minDisplayDuration" : TGAuditNumber(ad, @"min_display_duration"),
				@"maxDisplayDuration" : TGAuditNumber(ad, @"max_display_duration"),
				@"canBeReported"      : @([ad[@"can_be_reported"] boolValue]),
				@"sponsor"            : TGAuditString(ad[@"sponsor"], @"info"),
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)clickVideoAdvertisement:(int64_t)uniqueId
					 completion:(void (^)(BOOL, NSString *))completion {
	if (!uniqueId){
		if (completion) completion(NO, @"An advertisement id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"clickVideoMessageAdvertisement",
					@"advertisement_unique_id" : @(uniqueId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)viewVideoAdvertisement:(int64_t)uniqueId
					completion:(void (^)(BOOL, NSString *))completion {
	if (!uniqueId){
		if (completion) completion(NO, @"An advertisement id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"viewVideoMessageAdvertisement",
					@"advertisement_unique_id" : @(uniqueId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)reportVideoAdvertisement:(int64_t)uniqueId
						  option:(NSString *)optionId
					  completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!uniqueId){
		if (completion) completion(nil, @"An advertisement id is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"reportVideoMessageAdvertisement",
					@"advertisement_unique_id" : @(uniqueId),
					@"option_id" : (optionId ?: @"")}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditReportResult(result), nil);
	}];
}

@end
