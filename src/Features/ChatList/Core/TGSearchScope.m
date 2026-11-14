#import "TGSearchScope.h"

NSArray *TGSearchScopeTitles(void) {
	return @[@"All", @"Chats", @"Messages", @"Media", @"Links",
			 @"Files", @"Music", @"Voice"];
}

NSString *TGPublicPostText(NSDictionary *message) {
	NSDictionary *content = [message[@"content"] isKindOfClass:NSDictionary.class]
			? message[@"content"] : nil;
	NSDictionary *text = [content[@"text"] isKindOfClass:NSDictionary.class]
			? content[@"text"] : nil;
	if (![text[@"text"] isKindOfClass:NSString.class])
		text = [content[@"caption"] isKindOfClass:NSDictionary.class]
				? content[@"caption"] : nil;
	if ([text[@"text"] isKindOfClass:NSString.class])
		return [text[@"text"] stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *kind = [content[@"@type"] isKindOfClass:NSString.class]
			? content[@"@type"] : nil;
	if ([kind hasPrefix:@"message"])
		return [kind substringFromIndex:7];
	return @"";
}

static BOOL TGSearchKindIsMedia(NSString *kind) {
	return [kind isEqualToString:@"messagePhoto"] ||
		   [kind isEqualToString:@"messageVideo"] ||
		   [kind isEqualToString:@"messageAnimation"] ||
		   [kind isEqualToString:@"messageVideoNote"];
}

static BOOL TGSearchKindIsFile(NSString *kind) {
	return [kind isEqualToString:@"messageDocument"];
}

static BOOL TGSearchKindIsMusic(NSString *kind) {
	return [kind isEqualToString:@"messageAudio"];
}

static BOOL TGSearchKindIsVoice(NSString *kind) {
	return [kind isEqualToString:@"messageVoiceNote"];
}

static BOOL TGSearchMessageHasLink(NSDictionary *message) {
	NSString *text = [message[@"text"] isKindOfClass:NSString.class]
			? message[@"text"] : @"";
	if (!text.length)
		return NO;
	NSString *lower = text.lowercaseString;
	return [lower rangeOfString:@"http://"].location != NSNotFound ||
		   [lower rangeOfString:@"https://"].location != NSNotFound ||
		   [lower rangeOfString:@"www."].location != NSNotFound ||
		   [lower rangeOfString:@"t.me/"].location != NSNotFound ||
		   [lower rangeOfString:@"tg://"].location != NSNotFound;
}

BOOL TGSearchMessageMatchesScope(NSDictionary *message, TGSearchScope scope) {
	NSString *kind = [message[@"kind"] isKindOfClass:NSString.class]
			? message[@"kind"] : @"";
	switch (scope){
		case TGSearchScopeMedia: return TGSearchKindIsMedia(kind);
		case TGSearchScopeLinks: return TGSearchMessageHasLink(message);
		case TGSearchScopeFiles: return TGSearchKindIsFile(kind);
		case TGSearchScopeMusic: return TGSearchKindIsMusic(kind);
		case TGSearchScopeVoice: return TGSearchKindIsVoice(kind);
		default: return YES;
	}
}

NSArray *TGSearchScopedMessages(NSArray *messages, TGSearchScope scope) {
	if (scope == TGSearchScopeAll || scope == TGSearchScopeMessages)
		return messages;
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *message in messages)
		if (TGSearchMessageMatchesScope(message, scope))
			[out addObject:message];
	return out;
}

BOOL TGSearchScopeShowsChats(TGSearchScope scope) {
	return scope == TGSearchScopeAll || scope == TGSearchScopeChats;
}

BOOL TGSearchScopeShowsMessages(TGSearchScope scope) {
	return scope == TGSearchScopeAll || scope >= TGSearchScopeMessages;
}

BOOL TGSearchScopeShowsPublic(TGSearchScope scope) {
	return scope == TGSearchScopeAll;
}
