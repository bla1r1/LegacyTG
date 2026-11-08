#import "TGClient+AuditSupport.h"
#import "TGClientInternal.h"

NSString *TGAuditError(NSDictionary *result) {
	NSString *message = result[@"message"];
	return [message isKindOfClass:NSString.class] ? message : @"Telegram refused that.";
}

BOOL TGAuditFailed(NSDictionary *result) {
	return [result[@"@type"] isEqualToString:@"error"];
}

/// The synchronous half of td_api has to go through execute. A build without
/// the symbol falls back to the outbox so a request is still recorded and the
/// host tests can read its shape.
void TGAuditExecute(TGClient *client, NSDictionary *request,
						void (^completion)(NSDictionary *)) {
	if (client.td_exec){
		NSDictionary *answer = [client executeSynchronously:request];
		if (completion) completion(answer);
		return;
	}
	[client request:request completion:completion];
}

/// "premiumFeatureDisabledAds" -> "disabledAds", the word a row shows.
NSString *TGAuditShortType(id value) {
	if (![value isKindOfClass:NSString.class])
		return @"unknown";
	NSString *name = value;
	NSArray *prefixes = nil;
	if (!prefixes)
		prefixes = @[@"premiumFeature", @"premiumLimitType", @"premiumSource",
					 @"checkChatUsernameResult", @"canSendGiftResult",
					 @"reportSponsoredResult", @"starTransactionType",
					 @"transactionDirection", @"giftForResaleOrder",
					 @"logStream", @"chatTheme", @"emojiStatusType",
					 @"businessRecipient", @"messageSender"];
	for (NSString *prefix in prefixes){
		if ([name hasPrefix:prefix]){
			name = [name substringFromIndex:prefix.length];
			break;
		}
	}
	if ([name hasSuffix:@"Result"] && name.length > @"Result".length)
		name = [name substringToIndex:name.length - @"Result".length];
	if (!name.length)
		return @"unknown";
	return [[[name substringToIndex:1] lowercaseString]
			stringByAppendingString:[name substringFromIndex:1]];
}

/// "disabledAds" -> "premiumFeatureDisabledAds", and an already-prefixed
/// name is left alone so a caller can pass either spelling.
NSString *TGAuditPrefixedType(NSString *prefix, NSString *value) {
	if ([value hasPrefix:prefix])
		return value;
	if (!value.length)
		return prefix;
	NSString *first = [[value substringToIndex:1] uppercaseString];
	return [prefix stringByAppendingString:
			[first stringByAppendingString:[value substringFromIndex:1]]];
}

NSString *TGAuditString(NSDictionary *dictionary, NSString *key) {
	id value = dictionary[key];
	return [value isKindOfClass:NSString.class] ? value : @"";
}

NSNumber *TGAuditNumber(NSDictionary *dictionary, NSString *key) {
	id value = dictionary[key];
	return [value isKindOfClass:NSNumber.class] ? value : @0;
}

/// A user record reduced to the three facts a row draws.
NSDictionary *TGAuditUser(NSDictionary *user) {
	if (![user isKindOfClass:NSDictionary.class])
		return @{@"id" : @0, @"name" : @"", @"username" : @""};
	NSString *first = TGAuditString(user, @"first_name");
	NSString *last = TGAuditString(user, @"last_name");
	NSString *name = [[NSString stringWithFormat:@"%@ %@", first, last]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (!name.length)
		name = TGAuditString(user, @"username");
	return @{
		@"id"       : TGAuditNumber(user, @"id"),
		@"name"     : name,
		@"username" : TGAuditString(user, @"username"),
	};
}

/// messageSenderUser/messageSenderChat as the object the requests want.
NSDictionary *TGAuditSender(NSString *kind, int64_t identifier) {
	if ([kind isEqualToString:@"chat"])
		return @{@"@type" : @"messageSenderChat", @"chat_id" : @(identifier)};
	return @{@"@type" : @"messageSenderUser", @"user_id" : @(identifier)};
}

NSDictionary *TGAuditSticker(NSDictionary *sticker) {
	if (![sticker isKindOfClass:NSDictionary.class])
		return @{};
	return @{
		@"id"     : TGAuditNumber(sticker, @"id"),
		@"setId"  : TGAuditNumber(sticker, @"set_id"),
		@"emoji"  : TGAuditString(sticker, @"emoji"),
		@"fileId" : TGAuditNumber(sticker[@"sticker"], @"id"),
	};
}

/// JsonValue for a plain string. A full tree is accepted when the caller
/// already built one, which is what the JSON screen does.
NSDictionary *TGAuditJsonValue(id value) {
	if ([value isKindOfClass:NSDictionary.class] &&
			[value[@"@type"] hasPrefix:@"jsonValue"])
		return value;
	NSString *text = [value isKindOfClass:NSString.class] ? value : @"";
	return @{@"@type" : @"jsonValueString", @"value" : text};
}

/// The report result shape: the word Telegram wants the client to draw plus
/// the option list when it is asking for one.
NSDictionary *TGAuditReportResult(NSDictionary *result) {
	NSString *type = TGAuditShortType(result[@"@type"]);
	NSMutableDictionary *out = [@{@"type" : type} mutableCopy];
	if ([result[@"title"] isKindOfClass:NSString.class])
		out[@"title"] = result[@"title"];
	NSMutableArray *options = [NSMutableArray array];
	for (NSDictionary *option in result[@"options"]){
		if (![option isKindOfClass:NSDictionary.class])
			continue;
		[options addObject:@{
			@"id"   : TGAuditString(option, @"id"),
			@"text" : TGAuditString(option, @"text"),
		}];
	}
	if (options.count)
		out[@"options"] = options;
	return out;
}

/// The nested themeParameters a Web App call requires. This client has no
/// in-app browser, so the colours are only the record Telegram stores with
/// the request; black is TDLib's zero.
NSDictionary *TGAuditWebAppTheme(void) {
	return @{@"@type" : @"themeParameters",
			 @"background_color" : @((int32_t)0xff000000),
			 @"secondary_background_color" : @((int32_t)0xff1c1c1c),
			 @"header_background_color" : @((int32_t)0xff000000),
			 @"bottom_bar_background_color" : @((int32_t)0xff000000),
			 @"section_background_color" : @((int32_t)0xffffffff),
			 @"section_separator_color" : @((int32_t)0xffe1e4e9),
			 @"text_color" : @((int32_t)0xff222222),
			 @"accent_text_color" : @((int32_t)0xff3d95d4),
			 @"section_header_text_color" : @((int32_t)0xff696a6f),
			 @"subtitle_text_color" : @((int32_t)0xff8d8e90),
			 @"destructive_text_color" : @((int32_t)0xffe53935),
			 @"hint_color" : @((int32_t)0xff95999a),
			 @"link_color" : @((int32_t)0xff4cb3f5),
			 @"button_color" : @((int32_t)0xff3d95d4),
			 @"button_text_color" : @((int32_t)0xffffffff)};
}

NSDictionary *TGAuditWebAppParameters(NSString *mode) {
	NSString *openMode = @"webAppOpenModeCompact";
	if ([mode isEqualToString:@"fullSize"])
		openMode = @"webAppOpenModeFullSize";
	else if ([mode isEqualToString:@"fullScreen"])
		openMode = @"webAppOpenModeFullScreen";
	return @{@"@type" : @"webAppOpenParameters",
			 @"theme" : TGAuditWebAppTheme(),
			 @"application_name" : @"LegacyTG",
			 @"mode" : @{@"@type" : openMode}};
}

NSDictionary *TGAuditButtonSource(int64_t chatId, int64_t messageId) {
	return @{@"@type" : @"keyboardButtonSourceMessage",
			 @"chat_id" : @(chatId),
			 @"message_id" : @(messageId)};
}
