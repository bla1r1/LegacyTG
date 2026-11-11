//
// TGGroupStore+Tools.m - copied from TGClient+SavedMessages.m for the group store.
//
#import "TGGroupStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+Messages.h"


static NSString *TGGGroupErrorText(NSDictionary *result) {
	if ([result[@"@type"] isEqualToString:@"ok"])
		return nil;
	NSString *message = result[@"message"];
	return message.length ? message : @"An error occurred.";
}

@implementation TGGroupStore (Tools)

- (void)welcomeMessagesOfChat:(int64_t)chatId
				   completion:(void (^)(NSArray *welcomes))completion {
	__block id token = [[NSNotificationCenter defaultCenter]
			addObserverForName:TGFullInfoChangedNotification
						object:nil queue:nil
			usingBlock:^(NSNotification *note){
		if (![note.userInfo[@"kind"] isEqualToString:@"chat"] ||
				[note.userInfo[@"id"] longLongValue] != chatId)
			return;
		[[NSNotificationCenter defaultCenter] removeObserver:token];
		token = nil;
		NSMutableArray *out = [NSMutableArray array];
		NSArray *rows = [TGClient shared].chatsById[@(chatId)][@"welcomeMessages"];
		for (NSDictionary *w in rows){
			// A welcome text rides the nested shape the composer reads.
			id content = w[@"content"] ?: @{};
			NSString *text = content[@"messageText"][@"text"][@"text"];
			NSString *word = [text isKindOfClass:NSString.class] ? text : @"";
			[out addObject:@{@"id" : w[@"id"], @"text" : word}];
		}
		if (completion) completion(out);
	}];
	// The load answers an ok; the rows themselves ride updateChatWelcome-
	// Messages, which is what the announcement above heard.
	[[TGClient shared] request:@{@"@type" : @"loadChatWelcomeMessages", @"chat_id" : @(chatId)}
		 completion:nil];
}

- (void)deleteChatMessagesByDate:(int64_t)chatId
						 minDate:(NSInteger)minDate
						 maxDate:(NSInteger)maxDate
						  revoke:(BOOL)revoke {
	[[TGClient shared] send:@{
		@"@type"     : @"deleteChatMessagesByDate",
		@"chat_id"   : @(chatId),
		@"min_date"  : @(minDate),
		@"max_date"  : @(maxDate),
		@"revoke"    : @(revoke),
	}];
}

- (void)deleteChatMessagesBySender:(NSDictionary *)sender
							inChat:(int64_t)chatId
							revoke:(BOOL)revoke {
	if (!sender)
		return;
	[[TGClient shared] send:@{
		@"@type"     : @"deleteChatMessagesBySender",
		@"chat_id"   : @(chatId),
		@"sender_id" : sender,
		@"revoke"    : @(revoke),
	}];
}

- (void)addWelcomeMessageToChat:(int64_t)chatId
						   text:(NSString *)text
					 completion:(void (^)(BOOL ok))completion {
	if (!text.length){
		if (completion) completion(NO);
		return;
	}
	[[TGClient shared] request:@{
			@"@type"   : @"addChatWelcomeMessage",
			@"chat_id" : @(chatId),
			@"input_message_content" : @{@"@type"  : @"inputMessageText",
										 @"text"   : TGFormattedText(text)},
		} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)setWelcomeMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
					 text:(NSString *)text
			   completion:(void (^)(BOOL ok))completion {
	if (!text.length){
		if (completion) completion(NO);
		return;
	}
	[[TGClient shared] request:@{
			@"@type"              : @"editChatWelcomeMessage",
			@"chat_id"            : @(chatId),
			@"welcome_message_id" : @(messageId),
			@"input_message_content" : @{@"@type"  : @"inputMessageText",
										 @"text"   : TGFormattedText(text)},
		} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)deleteWelcomeMessage:(int64_t)messageId inChat:(int64_t)chatId {
	[[TGClient shared] request:@{@"@type"              : @"deleteChatWelcomeMessage",
					@"chat_id"            : @(chatId),
					@"welcome_message_id" : @(messageId)}
		 completion:nil];
}

- (void)clearAllWelcomeMessagesInChat:(int64_t)chatId {
	[[TGClient shared] request:@{@"@type"   : @"deleteAllChatWelcomeMessages",
					@"chat_id" : @(chatId)}
		 completion:nil];
}

- (void)availableMessageSendersInChat:(int64_t)chatId
						   completion:(void (^)(NSArray *senders))completion {
	[[TGClient shared] request:@{@"@type" : @"getChatAvailableMessageSenders", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"chatMessageSenders"]){
			completion(nil);
			return;
		}
		completion(result[@"message_senders"]);
	}];
}

- (void)setMessageSender:(NSDictionary *)sender
				  inChat:(int64_t)chatId
			  completion:(void (^)(BOOL ok))completion {
	if (!sender){
		if (completion) completion(NO);
		return;
	}
	[[TGClient shared] request:@{@"@type"   : @"setChatMessageSender",
					@"chat_id" : @(chatId),
					@"message_sender_id" : sender}
	   completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)messageFileTypeForHead:(NSString *)head
					completion:(void (^)(NSDictionary *fileType))completion {
	if (!head.length){
		if (completion) completion(nil);
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getMessageFileType", @"message_file_head" : head}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		NSString *type = result[@"@type"];
		if ([type isEqualToString:@"messageFileTypePrivate"])
			completion(@{@"kind" : @"private",
						 @"title" : result[@"name"] ?: @""});
		else if ([type isEqualToString:@"messageFileTypeGroup"])
			completion(@{@"kind" : @"group",
						 @"title" : result[@"title"] ?: @""});
		else
			completion(@{@"kind" : @"unknown", @"title" : @""});
	}];
}

- (void)importConfirmationTextForChat:(int64_t)chatId
						   completion:(void (^)(NSString *text))completion {
	[[TGClient shared] request:@{@"@type" : @"getMessageImportConfirmationText",
					@"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		completion([result[@"@type"] isEqualToString:@"text"]
				? (result[@"text"] ?: @"") : @"");
	}];
}

- (void)importMessagesFromFile:(NSString *)path
				 attachedFiles:(NSArray *)attachedPaths
					  intoChat:(int64_t)chatId
					completion:(void (^)(BOOL ok))completion {
	if (!path.length){
		if (completion) completion(NO);
		return;
	}
	NSMutableArray *attached = [NSMutableArray array];
	for (NSString *file in attachedPaths)
		if ([file isKindOfClass:NSString.class] && file.length)
			[attached addObject:@{@"@type" : @"inputFileLocal",
								  @"path" : file}];
	[[TGClient shared] request:@{
		@"@type"          : @"importMessages",
		@"chat_id"        : @(chatId),
		@"message_file"   : @{@"@type" : @"inputFileLocal", @"path" : path},
		@"attached_files" : attached,
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)hasPasswordWithCompletion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getPasswordState"} completion:^(NSDictionary *state){
		if (!completion)
			return;
		NSString *pattern = state[@"recovery_email_address_code_info"]
				[@"email_address_pattern"];
		NSString *email = pattern.length ? pattern
				: ([state[@"has_recovery_email_address"] boolValue] ? @"set" : @"");
		completion([state[@"has_password"] boolValue], email);
	}];
}

- (void)canTransferOwnershipWithCompletion:
		(void (^)(NSString *result, NSInteger retryAfter,
				  NSString *error))completion {
	[[TGClient shared] request:@{@"@type" : @"canTransferOwnership"}
	   completion:^(NSDictionary *answer){
		if (!completion)
			return;
		NSString *type = answer[@"@type"] ?: @"";
		if ([type isEqualToString:@"canTransferOwnershipResultOk"]){
			completion(@"ok", 0, nil);
		} else if ([type isEqualToString:@"canTransferOwnershipResultPasswordNeeded"]){
			completion(@"passwordNeeded", 0, nil);
		} else if ([type isEqualToString:@"canTransferOwnershipResultPasswordTooFresh"]){
			completion(@"passwordTooFresh",
					   (NSInteger)[answer[@"retry_after"] integerValue], nil);
		} else if ([type isEqualToString:@"canTransferOwnershipResultSessionTooFresh"]){
			completion(@"sessionTooFresh",
					   (NSInteger)[answer[@"retry_after"] integerValue], nil);
		} else {
			completion(nil, 0, TGGGroupErrorText(answer));
		}
	}];
}


@end

// vim:ft=objc
