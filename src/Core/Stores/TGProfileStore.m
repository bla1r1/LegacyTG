//
// TGProfileStore.m - explicit Profile boundary.
//
#import "TGProfileStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGGiftFlatten.h"
#import "TGClient+StoriesSupport.h"
#import "TGProfileSupport.h"
#import "TGMediaStore.h"
#import "TGSendStore.h"
#import "TGMessageStore.h"
#import "TGChatListStore.h"

@implementation TGProfileStore

+ (instancetype)shared {
static TGProfileStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ store = [[TGProfileStore alloc] init]; });
	return store;
}

- (NSDictionary *)me {
return [TGClient shared].me;
}
- (NSArray *)communities {
return [TGClient shared].communities;
}
- (TGConnectionState)connectionState {
return [TGClient shared].connectionState;
}





- (void)archivedStoriesForChat:(int64_t)chatId completion:(void (^)(NSArray *))completion {
[[TGClient shared] request:@{@"@type" : @"getChatArchivedStories",
					@"chat_id" : @(chatId),
					@"from_story_id" : @(0),
					@"limit" : @(60)}
	   completion:^(NSDictionary *result){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *story in TGStoryArray(result[@"stories"]))
			if ([story isKindOfClass:NSDictionary.class])
				[out addObject:TGFlattenStory(story)];
		if (completion)
			completion(out);
	}];
}





- (void)bioLengthMaxWithCompletion:(void (^)(NSInteger maxLength))completion {
	[[TGClient shared] request:@{@"@type" : @"getOption", @"name" : @"bio_length_max"}
	   completion:^(NSDictionary *option){
		if (completion)
			completion([option[@"@type"] isEqualToString:@"optionValueInteger"]
					? [option[@"value"] integerValue] : 0);
	}];
}

- (NSDictionary *)cachedCommunityFullInfo:(int64_t)communityId {
NSDictionary *info = [TGClient shared].communityFullInfoById[@(communityId)];
	return [info isKindOfClass:NSDictionary.class] ? info : nil;
}

- (void)canSendMessageToUser:(int64_t)userId completion:(void (^)(NSString *result))completion {
if (!userId){
		if (completion) completion(@"userDeleted");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"canSendMessageToUser", @"user_id" : @(userId)}
	   completion:^(NSDictionary *result){
		NSString *kind = result[@"@type"] ?: @"";
		NSString *word = @"userDeleted";
		if ([kind isEqualToString:@"canSendMessageToUserResultOk"]) word = @"ok";
		else if ([kind isEqualToString:@"canSendMessageToUserResultUserHasPaidMessages"])
			word = @"paidMessages";
		else if ([kind isEqualToString:@"canSendMessageToUserResultUserIsDeleted"])
			word = @"userDeleted";
		else if ([kind isEqualToString:@"canSendMessageToUserResultUserRestrictsNewChats"])
			word = @"userRestrictsNewChats";
		if (completion) completion(word);
	}];
}

- (BOOL)chatIsSavedMessages:(int64_t)chatId {
return [[TGChatListStore shared] chatIsSavedMessages:chatId];
}

- (void)chatMember:(int64_t)userId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *member))completion {
if (!userId){
		if (completion) completion(nil);
		return;
	}
	[[TGClient shared] request:@{
		@"@type"     : @"getChatMember",
		@"chat_id"   : @(chatId),
		@"member_id" : TGMemberSender(userId),
	} completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"@type"] isEqualToString:@"error"] ? nil : result);
	}];
}

- (void)chatProfile:(int64_t)chatId completion:(void (^)(NSDictionary *info))completion {
[[TGMessageStore shared] chatProfile:chatId completion:completion];
}

- (void)chatRecordForChat:(int64_t)chatId completion:(void (^)(NSDictionary *chat))completion {
[[TGMessageStore shared] chatRecordForChat:chatId completion:completion];
}

- (void)chatWithViewAsTopics:(int64_t)chatId completion:(void (^)(BOOL viewAsTopics))completion {
[[TGClient shared] request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *chat){
		if (completion)
			completion([chat[@"view_as_topics"] boolValue]);
	}];
}

- (void)clearHistoryInChat:(int64_t)chatId {
[[TGMessageStore shared] clearHistoryInChat:chatId];
}





- (void)communityFullInfo:(int64_t)communityId completion:(void (^)(NSDictionary *info, NSString *error))completion {
if (!communityId){
		if (completion)
			completion(nil, @"No community was chosen.");
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] request:@{
		@"@type"        : @"getCommunityFullInfo",
		@"community_id" : @(communityId),
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(nil, TGFeatureErrorText(result));
			return;
		}
		NSMutableArray *chats = [NSMutableArray array];
		for (NSDictionary *chat in TGFeatureArray(result[@"chats"])){
			int64_t chatId = [chat[@"chat_id"] longLongValue];
			if (!chatId)
				continue;
			[chats addObject:[@{
				@"chatId"        : @(chatId),
				@"title"         : TGFeatureChatTitle(chatId) ?: [NSString stringWithFormat:
										@"Chat %lld", (long long)chatId],
				@"canViewHistory": chat[@"can_view_history"] ?: @NO,
				@"hidden"        : chat[@"is_hidden"] ?: @NO,
			} mutableCopy]];
		}
		NSDictionary *info = @{
			@"photoFileId"         : TGFeaturePhotoFileId(result[@"photo"]) ?: @(0),
			@"chats"               : chats,
			@"administratorCount"  : result[@"administrator_count"] ?: @(0),
			@"bannedCount"         : result[@"banned_count"] ?: @(0),
			@"addChatRequestCount" : result[@"add_chat_request_count"] ?: @(0),
		};
		[TGClient shared].communityFullInfoById[@(communityId)] = info;
		if (completion)
			completion(info, nil);
	}];
}

- (void)createSecretChatWithUser:(int64_t)userId completion:(void (^)(int64_t chatId))completion {
if (!userId){
		if (completion) completion(0);
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"createNewSecretChat", @"user_id" : @(userId)}
	   completion:^(NSDictionary *result){
		int64_t chatId = [result[@"id"] longLongValue];
		NSNumber *secretChatId = result[@"type"][@"secret_chat_id"];
		
		
		
		
		if (secretChatId && chatId){
			[[TGClient shared] request:@{@"@type" : @"createSecretChat",
							@"secret_chat_id" : secretChatId}
			   completion:^(NSDictionary *resolved){
				int64_t resolvedId = [resolved[@"id"] longLongValue];
				if (completion)
					completion(resolvedId ? resolvedId : chatId);
			}];
			return;
		}
		if (completion)
			completion(chatId);
	}];
}

- (void)customEmojiStickersForIds:(NSArray *)ids completion:(void (^)(NSArray *stickers))completion {
if (!ids.count){
		if (completion) completion(@[]);
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getCustomEmojiStickers",
					@"custom_emoji_ids" : ids}
	   completion:^(NSDictionary *result){
		if (completion) completion(TGCustomEmojiStickerList(result[@"stickers"]));
	}];
}





- (void)deleteChat:(int64_t)chatId {
[[TGChatListStore shared] deleteChat:chatId];
}

- (void)deleteChatForEveryone:(int64_t)chatId completion:(void (^)(NSString *error))completion {
[[TGChatListStore shared] deleteChatForEveryone:chatId completion:completion];
}



- (void)deleteStory:(int32_t)storyId fromChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion {
[[TGClient shared] request:@{@"@type" : @"deleteStory",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId)}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}



- (void)downloadFile:(NSInteger)fileId completion:(void (^)(NSString *path))completion {
[[TGMediaStore shared] downloadFile:fileId completion:completion];
}

- (void)downloadFile:(NSInteger)fileId priority:(NSInteger)priority completion:(void (^)(NSString *path))completion {
[[TGMediaStore shared] downloadFile:fileId priority:priority completion:completion];
}



- (void)giftsForOwner:(NSDictionary *)ownerId offset:(NSString *)offset completion:(void (^)(NSArray *gifts, NSString *nextOffset, NSInteger totalCount))completion {
NSMutableDictionary *query = [NSMutableDictionary dictionaryWithDictionary:@{
		@"@type" : @"getReceivedGifts",
		@"limit" : @(50),
		@"offset": offset ?: @"",
	}];
	if (ownerId)
		query[@"owner_id"] = ownerId;

	[[TGClient shared] request:query completion:^(NSDictionary *result){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *entry in result[@"gifts"]){
			if (![entry isKindOfClass:NSDictionary.class])
				continue;
			NSDictionary *flat = TGFlattenReceivedGift(entry);
			if (flat)
				[out addObject:flat];
		}
		NSString *nextOffset = [result[@"next_offset"] isKindOfClass:NSString.class]
				? result[@"next_offset"] : @"";
		NSInteger totalCount = [result[@"total_count"] respondsToSelector:@selector(integerValue)]
				? [result[@"total_count"] integerValue] : (NSInteger)out.count;
		if (completion)
			completion(out, nextOffset, totalCount);
	}];
}



- (void)historyForChat:(int64_t)chatId limit:(NSInteger)limit completion:(void (^)(NSArray *messages))completion {
[[TGMessageStore shared] historyForChat:chatId thread:0 limit:limit completion:completion];
}

- (BOOL)isChatMuted:(int64_t)chatId {
return [[TGMessageStore shared] isChatMuted:chatId];
}



- (void)logOut {
	[[TGClient shared] send:@{@"@type" : @"logOut"}];
}

- (void)mediaInChat:(int64_t)chatId filter:(NSString *)filter completion:(void (^)(NSArray *messages))completion {
	[self mediaInChat:chatId filter:filter fromMessageId:0 limit:60 completion:completion];
}

- (void)mediaInChat:(int64_t)chatId filter:(NSString *)filter fromMessageId:(int64_t)fromMessageId limit:(NSInteger)limit completion:(void (^)(NSArray *messages))completion {
	NSInteger batchLimit = limit > 0 ? MIN(limit, 100) : 60;
	[[TGClient shared] request:@{
		@"@type"           : @"searchChatMessages",
		@"chat_id"         : @(chatId),
		@"query"           : @"",
		@"from_message_id" : @(fromMessageId),
		@"offset"          : @(0),
		@"limit"           : @(batchLimit),
		@"filter"          : @{@"@type" : filter ?: @"searchMessagesFilterPhotoAndVideo"},
	} completion:^(NSDictionary *result){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *m in result[@"messages"]){
			NSDictionary *flat = TGFlattenMessage(m);
			if (flat) [out addObject:flat];
		}
		if (completion) completion(out);
	}];
}

- (void)memberCountForChat:(int64_t)chatId completion:(void (^)(NSInteger count))completion {
[[TGClient shared] request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *chat){
		NSDictionary *type = chat[@"type"];
		NSString *t = type[@"@type"];
		if ([t isEqualToString:@"chatTypeBasicGroup"]){
			[[TGClient shared] request:@{@"@type" : @"getBasicGroupFullInfo",
							@"basic_group_id" : type[@"basic_group_id"]}
			   completion:^(NSDictionary *full){
				if (completion) completion([full[@"members"] count]);
			}];
		} else if ([t isEqualToString:@"chatTypeSupergroup"]){
			[[TGClient shared] request:@{@"@type" : @"getSupergroupFullInfo",
							@"supergroup_id" : type[@"supergroup_id"]}
			   completion:^(NSDictionary *full){
				if (completion) completion([full[@"member_count"] integerValue]);
			}];
		} else if (completion){
			completion(0);
		}
	}];
}

- (void)membersOfChat:(int64_t)chatId completion:(void (^)(NSArray *members))completion {
__weak typeof(self) weakSelf = self;
	[[TGClient shared] request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *chat){
		NSDictionary *type = chat[@"type"];
		NSString *kind = type[@"@type"];

		void (^collect)(NSArray *) = ^(NSArray *members){
			TGClient *me = weakSelf;
			NSMutableArray *out = [NSMutableArray array];
			for (NSDictionary *member in members){
				NSDictionary *row = TGMemberRowForMember(member,
						[me nameForUserId:[member[@"member_id"][@"user_id"] longLongValue]]);
				if (row)
					[out addObject:row];
			}
			if (completion) completion(out);
		};

		if ([kind isEqualToString:@"chatTypeBasicGroup"]){
			[[TGClient shared] request:@{
				@"@type"          : @"getBasicGroupFullInfo",
				@"basic_group_id" : type[@"basic_group_id"],
			} completion:^(NSDictionary *full){ collect(full[@"members"]); }];
			return;
		}
		if ([kind isEqualToString:@"chatTypeSupergroup"]){
			[[TGClient shared] request:@{
				@"@type"        : @"getSupergroupMembers",
				@"supergroup_id": type[@"supergroup_id"],
				@"filter"       : @{@"@type" : @"supergroupMembersFilterRecent"},
				@"offset"       : @(0),
				@"limit"        : @(50),
			} completion:^(NSDictionary *result){ collect(result[@"members"]); }];
			return;
		}
		if (completion) completion(@[]);
	}];
}

- (void)messageCountInChat:(int64_t)chatId filter:(NSString *)filterType completion:(void (^)(NSInteger count))completion {
[[TGMessageStore shared] messageCountInChat:chatId filter:filterType completion:completion];
}



- (void)myBirthdayWithCompletion:(void (^)(NSInteger day, NSInteger month,
                                           NSInteger year))completion {
[[TGClient shared] request:@{@"@type"   : @"getUserFullInfo",
					@"user_id" : [TGClient shared].me[@"id"] ?: @0}
	   completion:^(NSDictionary *full){
		NSDictionary *birth = full[@"birthdate"];
		if (completion)
			completion([birth[@"day"] integerValue], [birth[@"month"] integerValue],
					   [birth[@"year"] integerValue]);
	}];
}





- (void)openSimilarChat:(int64_t)openedChatId fromChat:(int64_t)chatId {
[[TGClient shared] send:@{@"@type" : @"openChatSimilarChat",
				 @"chat_id" : @(chatId),
				 @"opened_chat_id" : @(openedChatId)}];
}

- (NSNumber *)photoFileIdForUserId:(int64_t)userId {
return [TGClient shared].userPhotosById[@(userId)];
}

- (void)privacyRule:(NSString *)setting completion:(void (^)(NSString *value))completion {
	[[TGClient shared] request:@{
		@"@type"   : @"getUserPrivacySettingRules",
		@"setting" : @{@"@type" : [@"userPrivacySetting" stringByAppendingString:setting]},
	} completion:^(NSDictionary *rules){
		
		
		
		NSString *first = [rules[@"rules"] lastObject][@"@type"];
		NSString *value = @"nobody";
		if ([first isEqualToString:@"userPrivacySettingRuleAllowAll"])
			value = @"everybody";
		else if ([first isEqualToString:@"userPrivacySettingRuleAllowContacts"])
			value = @"contacts";

		NSInteger allowCount = 0;
		NSInteger restrictCount = 0;
		for (NSDictionary *r in rules[@"rules"]) {
			if (![r isKindOfClass:NSDictionary.class])
				continue;
			NSString *type = r[@"@type"];
			if (!type.length)
				continue;
			
			if ([type isEqualToString:@"userPrivacySettingRuleAllowAll"] ||
					[type isEqualToString:@"userPrivacySettingRuleAllowContacts"] ||
					[type isEqualToString:@"userPrivacySettingRuleRestrictAll"] ||
					[type isEqualToString:@"userPrivacySettingRuleRestrictContacts"])
				continue;
			BOOL allow = [type hasPrefix:@"userPrivacySettingRuleAllow"];
			NSInteger amount = 1;
			if ([type rangeOfString:@"Premium"].location != NSNotFound ||
					[type rangeOfString:@"Bots"].location != NSNotFound ||
					[type rangeOfString:@"CloseFriends"].location != NSNotFound){
				amount = 1;
			} else if ([type rangeOfString:@"Chat"].location != NSNotFound){
				amount = (NSInteger)[r[@"chat_ids"] count];
			} else if ([type hasSuffix:@"Users"]){
				amount = (NSInteger)[r[@"user_ids"] count];
			}
			if (allow)
				allowCount += amount;
			else
				restrictCount += amount;
		}
		if (allowCount > 0 && [value isEqualToString:@"nobody"]) {
			value = [NSString stringWithFormat:@"nobody (+%ld)", (long)allowCount];
		} else if (restrictCount > 0) {
			value = [NSString stringWithFormat:@"%@ (-%ld)", value, (long)restrictCount];
		} else if (allowCount > 0 && [value isEqualToString:@"contacts"]) {
			value = [NSString stringWithFormat:@"contacts (+%ld)", (long)allowCount];
		}

		if (completion) completion(value);
	}];
}

- (void)privateChatWithUser:(int64_t)userId completion:(void (^)(int64_t chatId))completion {
[[TGMessageStore shared] privateChatWithUser:userId completion:completion];
}







- (void)removeContactWithUserId:(int64_t)userId completion:(void (^)(BOOL ok))completion {
[[TGClient shared] request:@{@"@type" : @"removeContacts", @"user_ids" : @[@(userId)]}
	   completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"@type"] isEqualToString:@"ok"]);
	}];
}



- (void)reportChat:(int64_t)chatId optionId:(NSString *)optionId text:(NSString *)text completion:(void (^)(NSString *title, NSArray *options, BOOL done))completion {
[[TGMessageStore shared] reportChat:chatId optionId:optionId text:text completion:completion];
}

- (void)request:(NSDictionary *)request completion:(void (^)(NSDictionary *result))completion {
[[TGClient shared] request:request completion:completion];
}

- (int64_t)savedMessagesChatId {
return [[TGChatListStore shared] savedMessagesChatId];
}

- (void)sendText:(NSString *)text toChat:(int64_t)chatId {
[[TGSendStore shared] sendText:text toChat:chatId thread:0];
}





- (void)setBio:(NSString *)bio completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] request:@{@"@type" : @"setBio", @"bio" : bio ?: @""}
	   completion:^(NSDictionary *result){
		BOOL failed = [result[@"@type"] isEqualToString:@"error"];
		if (completion)
			completion(!failed, failed ? (result[@"message"] ?: @"An error occurred.") : nil);
	}];
}

- (void)setBirthdayDay:(NSInteger)day month:(NSInteger)month year:(NSInteger)year completion:(void (^)(BOOL ok, NSString *error))completion {
if (day <= 0){
		[[TGClient shared] request:@{@"@type" : @"setBirthdate", @"birthdate" : [NSNull null]}
		   completion:^(NSDictionary *result){
			BOOL failed = [result[@"@type"] isEqualToString:@"error"];
			if (completion)
				completion(!failed, failed ? (result[@"message"] ?: @"An error occurred.") : nil);
		}];
		return;
	}
	NSMutableDictionary *birthdate = [@{
		@"@type" : @"birthdate",
		@"day"   : @(day),
		@"month" : @(month),
	} mutableCopy];
	if (year > 0)
		birthdate[@"year"] = @(year);
	[[TGClient shared] request:@{@"@type" : @"setBirthdate", @"birthdate" : birthdate}
	   completion:^(NSDictionary *result){
		BOOL failed = [result[@"@type"] isEqualToString:@"error"];
		if (completion)
			completion(!failed, failed ? (result[@"message"] ?: @"An error occurred.") : nil);
	}];
}

- (void)setChat:(int64_t)chatId autoDeleteSeconds:(NSInteger)seconds {
	[[TGClient shared] send:@{
		@"@type"   : @"setChatMessageAutoDeleteTime",
		@"chat_id" : @(chatId),
		@"message_auto_delete_time" : @(seconds),
	}];
}

- (void)setChat:(int64_t)chatId muted:(BOOL)muted {
[[TGMessageStore shared] setChat:chatId muted:muted];
}



- (void)setChatViewAsTopics:(int64_t)chatId viewAsTopics:(BOOL)viewAsTopics completion:(void (^)(BOOL ok))completion {
[[TGClient shared] request:@{
		@"@type"         : @"toggleChatViewAsTopics",
		@"chat_id"       : @(chatId),
		@"view_as_topics" : @(viewAsTopics),
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}





- (void)setName:(NSString *)firstName last:(NSString *)lastName completion:(void (^)(BOOL ok, NSString *error))completion {
	[[TGClient shared] request:@{
		@"@type"      : @"setName",
		@"first_name" : firstName ?: @"",
		@"last_name"  : lastName ?: @"",
	} completion:^(NSDictionary *result){
		BOOL failed = [result[@"@type"] isEqualToString:@"error"];
		if (completion)
			completion(!failed, failed ? (result[@"message"] ?: @"An error occurred.") : nil);
	}];
}

- (void)setPersonalChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
[[TGClient shared] request:@{@"@type" : @"setPersonalChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}



- (void)setPrivacyRule:(NSString *)setting to:(NSString *)value {
	
	
	[self setPrivacyRule:setting to:value completion:nil];
}



- (void)setPrivacyRule:(NSString *)setting to:(NSString *)value
			completion:(void (^)(BOOL, NSString *))completion {
	NSString *rule = @"userPrivacySettingRuleRestrictAll";
	if ([value isEqualToString:@"everybody"])
		rule = @"userPrivacySettingRuleAllowAll";
	else if ([value isEqualToString:@"contacts"])
		rule = @"userPrivacySettingRuleAllowContacts";

	void (^write)(NSArray *) = ^(NSArray *exceptions){
		NSMutableArray *rules = [exceptions mutableCopy] ?: [NSMutableArray array];
		[rules addObject:@{@"@type" : rule}];
		[[TGClient shared] request:@{
			@"@type"   : @"setUserPrivacySettingRules",
			@"setting" : @{@"@type" : [@"userPrivacySetting" stringByAppendingString:setting]},
			@"rules"   : @{@"@type" : @"userPrivacySettingRules",
						   @"rules" : rules},
		} completion:^(NSDictionary *result){
			BOOL ok = ![result[@"@type"] isEqualToString:@"error"];
			NSString *error = ok ? nil : (result[@"message"] ?: @"An error occurred.");
			if (completion)
				completion(ok, error);
		}];
	};

	[[TGClient shared] request:@{
		@"@type"   : @"getUserPrivacySettingRules",
		@"setting" : @{@"@type" : [@"userPrivacySetting" stringByAppendingString:setting]},
	} completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"userPrivacySettingRules"]){
			if (completion)
				completion(NO, result[@"message"] ?: @"An error occurred.");
			return;
		}
		static NSSet *catchAll = nil;
		static dispatch_once_t once;
		dispatch_once(&once, ^{
			catchAll = [NSSet setWithObjects:@"userPrivacySettingRuleAllowAll",
					@"userPrivacySettingRuleAllowContacts",
					@"userPrivacySettingRuleRestrictAll", nil];
		});
		NSMutableArray *exceptions = [NSMutableArray array];
		for (NSDictionary *entry in result[@"rules"]){
			if ([entry isKindOfClass:NSDictionary.class] &&
					![catchAll containsObject:entry[@"@type"]])
				[exceptions addObject:entry];
		}
		write(exceptions);
	}];
}

- (void)setProfilePhotoAtPath:(NSString *)path completion:(void (^)(BOOL ok))completion {
[[TGClient shared] request:@{
		@"@type" : @"setProfilePhoto",
		@"photo" : @{@"@type" : @"inputChatPhotoStatic",
					 @"photo" : @{@"@type" : @"inputFileLocal", @"path" : path ?: @""}},
		
		@"is_public" : @NO,
	} completion:^(NSDictionary *result){
		BOOL ok = ![result[@"@type"] isEqualToString:@"error"];
		if (!ok)
			NSLog(@"setProfilePhoto: %@", result[@"message"]);
		if (completion) completion(ok);
	}];
}



- (void)setSupergroupMainProfileTab:(NSString *)tab inChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion {
__weak typeof(self) weakSelf = self;
	[[TGClient shared] supergroupIdForChat:chatId completion:^(int64_t supergroupId){
		if (!supergroupId){
			if (completion) completion(NO, @"This chat is not a supergroup or a channel.");
			return;
		}
		[[TGClient shared] request:@{@"@type" : @"setSupergroupMainProfileTab",
							@"supergroup_id" : @(supergroupId),
							@"main_profile_tab" : TGProfileTabObject(tab)}
			   completion:^(NSDictionary *result){
			BOOL failed = [result[@"@type"] isEqualToString:@"error"];
			if (completion)
				completion(!failed, failed ? (result[@"message"] ?: @"An error occurred.") : nil);
		}];
	}];
}

- (void)setUser:(int64_t)userId blocked:(BOOL)blocked completion:(void (^)(BOOL ok))completion {
[[TGMessageStore shared] setUser:userId blocked:blocked completion:completion];
}





- (void)similarChatsForChat:(int64_t)chatId completion:(void (^)(NSArray *chats, NSInteger total))completion {
__weak typeof(self) weakSelf = self;
	[[TGClient shared] request:@{@"@type" : @"getChatSimilarChatCount", @"chat_id" : @(chatId),
					@"return_local" : @NO}
	   completion:^(NSDictionary *countAnswer){
		TGClient *me = weakSelf;
		NSInteger total = [countAnswer[@"count"] integerValue];
		[me request:@{@"@type" : @"getChatSimilarChats", @"chat_id" : @(chatId)}
		 completion:^(NSDictionary *result){
			NSArray *rows = TGChatRowsForIds(me, result[@"chat_ids"]);
			if (completion)
				completion(rows, total > 0 ? total : (NSInteger)rows.count);
		}];
	}];
}

- (void)storiesForChat:(int64_t)chatId completion:(void (^)(NSArray *stories))completion {
__weak typeof(self) weakSelf = self;

	void (^flattenAll)(NSArray *) = ^(NSArray *stories){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *story in stories)
			if ([story isKindOfClass:NSDictionary.class])
				[out addObject:TGFlattenStory(story)];
		if (completion) completion(out);
	};

	[[TGClient shared] request:@{
		@"@type"         : @"getChatPostedToChatPageStories",
		@"chat_id"       : @(chatId),
		@"from_story_id" : @(0),
		@"limit"         : @(20),
	} completion:^(NSDictionary *posted){
		NSArray *stories = posted[@"stories"];
		if ([stories count]){
			flattenAll(stories);
			return;
		}

		
		
		[[TGClient shared] request:@{@"@type" : @"getChatActiveStories", @"chat_id" : @(chatId)}
			   completion:^(NSDictionary *active){
			NSArray *infos = active[@"stories"];
			if (![infos count]){
				if (completion) completion(@[]);
				return;
			}

			NSMutableArray *collected = [NSMutableArray array];
			__block NSUInteger outstanding = infos.count;
			for (NSDictionary *info in infos){
				[[TGClient shared] request:@{
					@"@type"                : @"getStory",
					@"story_sender_chat_id" : @(chatId),
					@"story_id"             : info[@"story_id"] ?: @(0),
					@"only_local"           : @NO,
				} completion:^(NSDictionary *story){
					if ([story[@"@type"] isEqualToString:@"story"])
						[collected addObject:TGFlattenStory(story)];
					if (--outstanding == 0 && completion)
						completion(collected);
				}];
			}
		}];
	}];
}





- (void)suitablePersonalChatsWithCompletion:(void (^)(NSArray *chats))completion {
[[TGClient shared] request:@{@"@type" : @"getSuitablePersonalChats"}
	   completion:^(NSDictionary *result){
		if (completion)
			completion(TGChatRowsForIds(self, result[@"chat_ids"]));
	}];
}

- (void)supergroupSettingsForChat:(int64_t)chatId completion:(void (^)(NSDictionary *settings))completion {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] supergroupIdForChat:chatId completion:^(int64_t supergroupId){
		if (!supergroupId){
			if (completion) completion(nil);
			return;
		}
		TGClient *me = weakSelf;
		[me request:@{@"@type" : @"getSupergroup", @"supergroup_id" : @(supergroupId)}
		 completion:^(NSDictionary *group){
			if ([group[@"@type"] isEqualToString:@"error"]){
				if (completion) completion(nil);
				return;
			}
			// The mode switches are on the record; hidden members and the
			// main profile tab are only in full info. One screen draws both,
			// so one method reads both rather than making the screen pair them.
			[me request:@{@"@type" : @"getSupergroupFullInfo",
						  @"supergroup_id" : @(supergroupId)}
			 completion:^(NSDictionary *full){
				BOOL fullOK = ![full[@"@type"] isEqualToString:@"error"];
				NSDictionary *usernames = [group[@"usernames"] isKindOfClass:NSDictionary.class]
						? group[@"usernames"] : @{};
				NSArray *active = [usernames[@"active_usernames"] isKindOfClass:NSArray.class]
						? usernames[@"active_usernames"] : @[];
				NSArray *disabled = [usernames[@"disabled_usernames"] isKindOfClass:NSArray.class]
						? usernames[@"disabled_usernames"] : @[];
				if (completion)
					completion(@{
						@"supergroupId"   : @(supergroupId),
						@"active"         : active,
						@"disabled"       : disabled,
						@"editable"       : usernames[@"editable_username"] ?: @"",
						@"canSetUsername" : fullOK ? (full[@"can_set_username"] ?: @NO) : @NO,
						@"canHideMembers" : fullOK ? (full[@"can_hide_members"] ?: @NO) : @NO,
						@"guardBotUserId" : fullOK ? (full[@"guard_bot_user_id"] ?: @0) : @0,
						@"isChannel"      : group[@"is_channel"] ?: @NO,
						@"isForum"        : group[@"is_forum"] ?: @NO,
						@"hasForumTabs"   : group[@"has_forum_tabs"] ?: @NO,
						@"joinByRequest"  : group[@"join_by_request"] ?: @NO,
						@"isBroadcast"    : group[@"is_broadcast_group"] ?: @NO,
						@"hiddenMembers"  : fullOK ? (full[@"has_hidden_members"] ?: @NO) : @NO,
						@"automaticTranslation" : group[@"has_automatic_translation"] ?: @NO,
						@"mainTab"        : TGProfileTabName(fullOK ? full[@"main_profile_tab"] : nil),
					});
			}];
		}];
	}];
}





- (NSString *)titleForChat:(int64_t)chatId {
return [[TGChatListStore shared] titleForChat:chatId];
}

- (void)toggleStory:(int32_t)storyId fromChat:(int64_t)chatId postedToChatPage:(BOOL)posted completion:(void (^)(BOOL ok, NSString *error))completion {
[[TGClient shared] request:@{@"@type" : @"toggleStoryIsPostedToChatPage",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId),
					@"is_posted_to_chat_page" : @(posted)}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)userInfo:(int64_t)userId completion:(void (^)(NSDictionary *user))completion {
	if ([TGClient shared].rawUsersById[@(userId)]){
		if (completion) completion([TGClient shared].rawUsersById[@(userId)]);
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
	   completion:^(NSDictionary *u){
		if ([u[@"@type"] isEqualToString:@"user"]){
			if (![TGClient shared].rawUsersById) [TGClient shared].rawUsersById = [[TGObjectLruCache alloc] initWithCapacity:TGRawUserCacheCap];
			[TGClient shared].rawUsersById[@(userId)] = u;
		}
		if (completion) completion([u[@"@type"] isEqualToString:@"user"] ? u : nil);
	}];
}

- (BOOL)userIsBot:(int64_t)userId {
NSDictionary *raw = [TGClient shared].rawUsersById[@(userId)];
	NSDictionary *type = raw[@"type"];
	return [type[@"@type"] isEqualToString:@"userTypeBot"];
}

- (void)userProfile:(int64_t)userId completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] request:@{@"@type" : @"getUserFullInfo", @"user_id" : @(userId)}
	   completion:^(NSDictionary *full){
		NSDictionary *birth = full[@"birthdate"];
		NSString *birthday = TGProfileBirthdayText([birth[@"day"] integerValue],
				[birth[@"month"] integerValue], [birth[@"year"] integerValue], [NSDate date]);
		NSString *tab = full[@"main_profile_tab"][@"@type"];
		tab = [tab stringByReplacingOccurrencesOfString:@"profileTab" withString:@""];
		// The bio travels as formatted text; the entities let the row keep its
		// links and mentions instead of clipping them to one grey line.
		NSDictionary *bio = full[@"bio"];
		NSDictionary *note = full[@"note"];
		if (completion) completion(@{
			@"bio"          : bio[@"text"] ?: @"",
			@"bioEntities"  : [bio[@"entities"] isKindOfClass:NSArray.class]
					? bio[@"entities"] : @[],
			@"commonGroups" : full[@"group_in_common_count"] ?: @0,
			@"birthday"     : birthday ?: @"",
			// The profile draws "Birthday today" in the online colour with a
			// gift glyph; the flag travels beside the text so the row does not
			// compare strings.
			@"birthdayToday": @(TGProfileBirthdayIsToday([birth[@"day"] integerValue],
					[birth[@"month"] integerValue], [NSDate date])),
			// The note is this account's own copy; empty means none is kept.
			@"note"         : note[@"text"] ?: @"",
			@"noteEntities" : [note[@"entities"] isKindOfClass:NSArray.class]
					? note[@"entities"] : @[],
			// A contact's private picture: an id is present only when one is
			// set, which is what the profile's remove row keys off.
			@"personalPhoto": full[@"personal_photo"][@"small"][@"id"] ?: @0,
			@"mainProfileTab": tab.length ? tab.lowercaseString : @"posts",
			@"shareTheme"   : full[@"share_theme"][@"@type"] ?: @"",
			// A user who has calls turned off should not be offered one.
			@"canCall"      : full[@"can_be_called"] ?: @NO,
			@"canVideoCall" : full[@"supports_video_calls"] ?: @NO,
			// Whether this account has them blocked, read from the same
			// full-info answer the card already waited for, so opening a
			// profile is one round trip instead of two.
			@"isBlocked"    : @([full[@"block_list"] isKindOfClass:NSDictionary.class]),
			// The strip under the action buttons: the owner's saved music.
			@"firstProfileAudio" : TGProfileAudioRow(full[@"first_profile_audio"]) ?: (id)[NSNull null],
			// The channel this person set as their personal channel, if any.
			@"personalChatId" : [full[@"personal_chat_id"] isKindOfClass:NSNumber.class]
					? full[@"personal_chat_id"] : @0,
			@"businessLocation" : full[@"business_info"][@"location"][@"address"] ?: @"",
			@"botDescription"   : full[@"bot_info"][@"short_description"] ?: (full[@"bot_info"][@"description"] ?: @""),
		});
	}];
}



@end
