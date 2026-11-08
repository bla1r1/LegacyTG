#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGLocalization.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountRest.h"
#import "TGClient+AccountSupport.h"


/// Defined with the autosave reads below; the update branch above it only
/// needs the same flattening so both paths produce one row shape.
static NSDictionary *TGFlattenAutosaveScope(NSDictionary *settings);

/// TDLib names the three scopes; the app names them shortly.
static NSString *TGScopeType(NSString *scope) {
	if ([scope isEqualToString:@"groups"])   return @"notificationSettingsScopeGroupChats";
	if ([scope isEqualToString:@"channels"]) return @"notificationSettingsScopeChannelChats";
	return @"notificationSettingsScopePrivateChats";
}

/// Kept as a compatibility call into the pure gift flattening utility.
static NSDictionary *TGFlattenGift(NSDictionary *entry) {
	return TGFlattenReceivedGift(entry);
}


static NSArray *TGPacksFrom(NSDictionary *target) {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *pack in target[@"language_packs"]){
		if (![pack[@"id"] length])
			continue;
		[out addObject:@{@"id"   : pack[@"id"],
						 @"name" : pack[@"native_name"] ?: pack[@"name"] ?: pack[@"id"]}];
	}
	return out;
}





/// The row title for a blocked user or chat answer; a deleted account has
/// no name at all and says so, as official does.
NSString *TGBlockedSenderName(NSDictionary *answer) {
	if ([answer[@"@type"] isEqualToString:@"chat"])
		return [answer[@"title"] length] ? answer[@"title"] : TGLocalized(@"Deleted Account");
	NSString *name = [[NSString stringWithFormat:@"%@ %@",
			answer[@"first_name"] ?: @"", answer[@"last_name"] ?: @""]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (!name.length && [answer[@"usernames"][@"active_usernames"] count])
		name = answer[@"usernames"][@"active_usernames"][0];
	return name.length ? name : TGLocalized(@"Deleted Account");
}

@implementation TGClient (AccountRest)

#pragma mark - the last of the account

/// Every other device signs off in one request. This one is never its own
/// victim - terminateAllOtherSessions answers for the rest only.
/// A new recovery address is not in force until the code Telegram emails to
/// it is entered. Until then the old address - or none - still stands, which
/// is why the flow has to offer this rather than stopping at "we wrote".
- (void)checkRecoveryEmailCode:(NSString *)code
					completion:(void (^)(BOOL ok))completion {
	if (!code.length){
		if (completion) completion(NO);
		return;
	}
	[self request:@{@"@type" : @"checkRecoveryEmailAddressCode", @"code" : code}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		// Still carrying a pattern means the code did not take.
		BOOL stillWaiting = [result[@"recovery_email_address_code_info"]
				[@"email_address_pattern"] length] > 0;
		completion([result[@"@type"] isEqualToString:@"passwordState"] && !stillWaiting);
	}];
}

- (void)resendRecoveryEmailCode {
	[self send:@{@"@type" : @"resendRecoveryEmailAddressCode"}];
}

- (void)terminateAllOtherSessions:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"terminateAllOtherSessions"}
	   completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

/// The end of the road, asked with the reason Telegram's own form collects
/// and the password two-step verification demands.
- (void)deleteAccountWithReason:(NSString *)reason
					   password:(NSString *)password
					 completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type"    : @"deleteAccount",
		@"reason"   : reason ?: @"",
		@"password" : password ?: @"",
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

/// Their Recent Calls page is a search across every chat for call messages -
/// there is no separate call log in TDLib.
- (void)recentCallsWithCompletion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type"         : @"searchCallMessages",
		@"offset"        : @"",
		@"limit"         : @(50),
		@"only_missed"   : @NO,
	} completion:^(NSDictionary *result){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *m in result[@"messages"]){
			NSDictionary *content = m[@"content"];
			if (![content[@"@type"] isEqualToString:@"messageCall"])
				continue;
			int64_t chatId = [m[@"chat_id"] longLongValue];
			NSString *reason = content[@"discard_reason"][@"@type"];
			[out addObject:@{
				@"userId"   : @(chatId),
				@"chatId"   : @(chatId),
				@"messageId": m[@"id"] ?: @0,
				@"name"     : [weakSelf nameForUserId:chatId] ?: @"Unknown",
				@"outgoing" : @([m[@"is_outgoing"] boolValue]),
				@"missed"   : @([reason isEqualToString:@"callDiscardReasonMissed"] ||
								[reason isEqualToString:@"callDiscardReasonDeclined"]),
				@"date"     : m[@"date"] ?: @(0),
				@"duration" : content[@"duration"] ?: @(0),
			}];
		}
		if (completion) completion(out);
	}];
}

- (void)privacyRule:(NSString *)setting completion:(void (^)(NSString *))completion {
	[self request:@{
		@"@type"   : @"getUserPrivacySettingRules",
		@"setting" : @{@"@type" : [@"userPrivacySetting" stringByAppendingString:setting]},
	} completion:^(NSDictionary *rules){
		// The rules are a list, most specific first. The catch-all is last:
		// reading the first rule showed "Nobody" for any account with a
		// Premium/bot/user exception ahead of the real setting.
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
			// The catch-all is the setting itself, not an exception.
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

- (void)setPrivacyRule:(NSString *)setting to:(NSString *)value {
	// The same read-then-write as the Settings screen: a bare catch-all
	// would replace the list and drop every exception.
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
		[self request:@{
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

	// Read the existing exceptions first: setUserPrivacySettingRules replaces
	// the whole list, so writing the catch-all alone deleted every allow /
	// restrict user exception the account had.
	[self request:@{
		@"@type"   : @"getUserPrivacySettingRules",
		@"setting" : @{@"@type" : [@"userPrivacySetting" stringByAppendingString:setting]},
	} completion:^(NSDictionary *result){
		// Without the current list there is nothing safe to write.
		if (![result[@"@type"] isEqualToString:@"userPrivacySettingRules"]){
			if (completion)
				completion(NO, result[@"message"] ?: @"An error occurred.");
			return;
		}
		// Every exception kind stays (users, chat members, contacts, close
		// friends, bots, Premium); only the catch-all is replaced.
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

- (void)blockedUsersWithCompletion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type"       : @"getBlockedMessageSenders",
		@"block_list"  : @{@"@type" : @"blockListMain"},
		@"offset"      : @(0),
		@"limit"       : @(100),
	} completion:^(NSDictionary *result){
		TGClient *me = weakSelf;
		NSMutableArray *out = [NSMutableArray array];
		NSMutableArray *missing = [NSMutableArray array];
		for (NSDictionary *sender in result[@"senders"]){
			// A blocked MessageSender is either a user or a chat/channel;
			// keeping only user_id dropped every blocked channel.
			NSNumber *userId = sender[@"user_id"];
			NSNumber *chatId = sender[@"chat_id"];
			NSNumber *senderId = userId ?: chatId;
			if (!senderId)
				continue;
			NSString *name = userId ? [me nameForUserId:userId.longLongValue]
					: me.chatsById[chatId][@"title"];
			NSMutableDictionary *row = [@{@"id" : senderId,
					@"name" : name ?: @""} mutableCopy];
			[out addObject:row];
			if (!name.length)
				[missing addObject:row];
		}
		// Users this session has not seen came back as blank rows; ask for
		// each before answering, so the list never shows an empty line.
		__block NSInteger pending = (NSInteger)missing.count;
		void (^finish)(void) = ^{
			if (--pending <= 0 && completion)
				completion(out);
		};
		if (!missing.count){
			pending = 1;
			finish();
			return;
		}
		for (NSMutableDictionary *row in missing){
			int64_t senderId = [row[@"id"] longLongValue];
			NSDictionary *ask = senderId < 0
					? @{@"@type" : @"getChat", @"chat_id" : @(senderId)}
					: @{@"@type" : @"getUser", @"user_id" : @(senderId)};
			[me request:ask completion:^(NSDictionary *answer){
				row[@"name"] = TGBlockedSenderName(answer);
				if ([answer[@"@type"] isEqualToString:@"user"])
					[weakSelf cacheProfilePhoto:answer];
				finish();
			}];
		}
	}];
}

- (void)accountTtlWithCompletion:(void (^)(NSInteger))completion {
	[self request:@{@"@type" : @"getAccountTtl"} completion:^(NSDictionary *ttl){
		if (completion) completion([ttl[@"days"] integerValue]);
	}];
}

- (void)setAccountTtlDays:(NSInteger)days {
	[self send:@{
		@"@type" : @"setAccountTtl",
		@"ttl"   : @{@"@type" : @"accountTtl", @"days" : @(days)},
	}];
}

- (void)languagesWithCompletion:(void (^)(NSArray *, NSString *))completion {
	__weak typeof(self) weakSelf = self;

	void (^answer)(NSArray *) = ^(NSArray *packs){
		[weakSelf request:@{@"@type" : @"getOption",
							@"name"  : @"language_pack_id"}
			   completion:^(NSDictionary *option){
			NSString *current = option[@"value"] ?: @"en";
			NSArray *list = packs;
			// With no list at all, say what is in use rather than nothing:
			// an empty screen looks broken and tells you less than one row.
			if (!list.count)
				list = @[@{@"id" : current, @"name" : current}];
			if (completion) completion(list, current);
		}];
	};

	// The full list comes from Telegram's servers, and they answer 404 to an
	// api_id with no language packs of its own - which is this app's case. The
	// local query still knows about the packs already on the device.
	[self request:@{@"@type" : @"getLocalizationTargetInfo",
					@"only_local" : @NO}
	   completion:^(NSDictionary *target){
		NSArray *packs = TGPacksFrom(target);
		if (packs.count){
			answer(packs);
			return;
		}
		[weakSelf request:@{@"@type" : @"getLocalizationTargetInfo",
							@"only_local" : @YES}
			   completion:^(NSDictionary *local){
			answer(TGPacksFrom(local));
		}];
	}];
}

- (void)setLanguage:(NSString *)packId {
	// The strings themselves are the official client's; this app is written in
	// English throughout. Setting it still matters: TDLib uses it for the text
	// it generates, and other clients on the account follow it.
	[self send:@{
		@"@type" : @"setOption",
		@"name"  : @"language_pack_id",
		@"value" : @{@"@type" : @"optionValueString", @"value" : packId ?: @"en"},
	}];
}

- (void)userInfo:(int64_t)userId completion:(void (^)(NSDictionary *))completion {
	if (self.rawUsersById[@(userId)]){
		if (completion) completion(self.rawUsersById[@(userId)]);
		return;
	}
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
	   completion:^(NSDictionary *u){
		if ([u[@"@type"] isEqualToString:@"user"]){
			if (!self.rawUsersById) self.rawUsersById = [[TGObjectLruCache alloc] initWithCapacity:TGRawUserCacheCap];
			self.rawUsersById[@(userId)] = u;
		}
		if (completion) completion([u[@"@type"] isEqualToString:@"user"] ? u : nil);
	}];
}

- (void)mediaInChat:(int64_t)chatId filter:(NSString *)filter
         completion:(void (^)(NSArray *))completion {
	[self mediaInChat:chatId filter:filter fromMessageId:0 limit:60 completion:completion];
}

- (void)mediaInChat:(int64_t)chatId filter:(NSString *)filter
      fromMessageId:(int64_t)fromMessageId limit:(NSInteger)limit
         completion:(void (^)(NSArray *))completion {
	NSInteger batchLimit = limit > 0 ? MIN(limit, 100) : 60;
	[self request:@{
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

- (NSString *)nameForUserId:(int64_t)userId {
	return self.usersById[@(userId)];
}

- (void)ensureUserName:(int64_t)userId completion:(void (^)(void))completion {
	if (userId == 0 || self.usersById[@(userId)]){
		if (completion) completion();
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
	   completion:^(NSDictionary *u){
		TGClient *me = weakSelf;
		if (me && [u[@"@type"] isEqualToString:@"user"]){
			NSString *name = [[NSString stringWithFormat:@"%@ %@",
					u[@"first_name"] ?: @"", u[@"last_name"] ?: @""]
					stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if (!name.length)
				name = u[@"usernames"][@"active_usernames"][0] ?: @"";
			if (name.length)
				me.usersById[@(userId)] = name;
			[me cacheProfilePhoto:u];
		}
		if (completion) completion();
	}];
}


@end
