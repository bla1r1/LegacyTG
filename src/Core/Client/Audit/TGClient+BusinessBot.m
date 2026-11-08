#import "TGClient+BusinessBot.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGClient (BusinessBot)

#pragma mark - business bot

- (void)businessConnectedBotWithCompletion:(void (^)(NSDictionary *, NSString *))completion {
	[self request:@{@"@type" : @"getBusinessConnectedBot"}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSDictionary *bot = result[@"bot"];
		if (completion)
			completion(@{@"botUserId" : TGAuditNumber(bot, @"bot_user_id"),
						 @"connectionDate" : TGAuditNumber(result, @"connection_date"),
						 @"deviceModel" : TGAuditString(result, @"device_model"),
						 @"location" : TGAuditString(result, @"location")}, nil);
	}];
}

- (void)setBusinessConnectedBot:(int64_t)botUserId
					 recipients:(NSDictionary *)recipients
					 completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId){
		if (completion) completion(NO, @"A bot id is needed.");
		return;
	}
	NSDictionary *rights = @{
		@"@type" : @"businessBotRights",
		@"can_reply" : @YES, @"can_read_messages" : @YES,
		@"can_delete_sent_messages" : @NO, @"can_delete_all_messages" : @NO,
		@"can_edit_name" : @NO, @"can_edit_bio" : @NO,
		@"can_edit_profile_photo" : @NO, @"can_edit_username" : @NO,
		@"can_view_gifts_and_stars" : @NO, @"can_sell_gifts" : @NO,
		@"can_change_gift_settings" : @NO, @"can_transfer_and_upgrade_gifts" : @NO,
		@"can_transfer_stars" : @NO, @"can_manage_stories" : @NO,
	};
	NSDictionary *selection = @{
		@"@type" : @"businessRecipients",
		@"chat_ids" : @[],
		@"excluded_chat_ids" : @[],
		@"select_existing_chats" : @([recipients[@"existing"] boolValue]),
		@"select_new_chats" : @([recipients[@"new"] boolValue]),
		@"select_contacts" : @([recipients[@"contacts"] boolValue]),
		@"select_non_contacts" : @([recipients[@"nonContacts"] boolValue]),
		@"exclude_selected" : @([recipients[@"excludeSelected"] boolValue]),
	};
	[self request:@{@"@type" : @"setBusinessConnectedBot",
					@"bot" : @{@"@type" : @"businessConnectedBot",
							   @"bot_user_id" : @(botUserId),
							   @"recipients" : selection,
							   @"rights" : rights}}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)deleteBusinessConnectedBot:(int64_t)botUserId
						completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId){
		if (completion) completion(NO, @"A bot id is needed.");
		return;
	}
	[self request:@{@"@type" : @"deleteBusinessConnectedBot",
					@"bot_user_id" : @(botUserId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)confirmBusinessConnectedBot:(int64_t)botUserId
						 completion:(void (^)(BOOL, NSString *))completion {
	if (!botUserId){
		if (completion) completion(NO, @"A bot id is needed.");
		return;
	}
	[self request:@{@"@type" : @"confirmBusinessConnectedBot",
					@"bot_user_id" : @(botUserId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)removeBusinessConnectedBotFromChat:(int64_t)chatId
								completion:(void (^)(BOOL, NSString *))completion {
	if (!chatId){
		if (completion) completion(NO, @"A chat id is needed.");
		return;
	}
	[self request:@{@"@type" : @"removeBusinessConnectedBotFromChat",
					@"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)pauseBusinessConnectedBotInChat:(int64_t)chatId
								 paused:(BOOL)paused
							 completion:(void (^)(BOOL, NSString *))completion {
	if (!chatId){
		if (completion) completion(NO, @"A chat id is needed.");
		return;
	}
	[self request:@{@"@type" : @"toggleBusinessConnectedBotChatIsPaused",
					@"chat_id" : @(chatId), @"is_paused" : @(paused)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

@end
