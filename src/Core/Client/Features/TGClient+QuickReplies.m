#import "TGClient+QuickReplies.h"
#import "TGClientInternal.h"
#import "TGClient+FeatureSupport.h"

@implementation TGClient (QuickReplies)

#pragma mark - quick replies

- (NSArray *)quickReplyShortcuts {
	NSMutableArray *out = [NSMutableArray array];
	for (NSNumber *ident in self.quickReplyShortcutOrder){
		NSDictionary *row = self.quickReplyShortcutsById[ident];
		if (row)
			[out addObject:row];
	}
	return out;
}

- (void)loadQuickReplyShortcutsWithCompletion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"loadQuickReplyShortcuts"}
	   completion:^(NSDictionary *result){
		TGClient *strong = weakSelf;
		if (!strong){
			if (completion)
				completion(@[]);
			return;
		}
		// The answer is Ok; the shortcuts themselves arrive as updates. A
		// caller that gets here first still sees whatever the cache holds.
		if (!TGFeatureOK(result) && !strong.quickReplyShortcutOrder.count){
			if (completion)
				completion(@[]);
			return;
		}
		if (completion)
			completion(strong.quickReplyShortcuts);
	}];
}

- (void)loadQuickReplyMessagesForShortcut:(NSInteger)shortcutId
                               completion:(void (^)(NSArray *))completion {
	if (!shortcutId){
		if (completion)
			completion(@[]);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type"       : @"loadQuickReplyShortcutMessages",
		@"shortcut_id" : @(shortcutId),
	} completion:^(NSDictionary *result){
		TGClient *strong = weakSelf;
		NSArray *messages = strong.quickReplyMessagesByShortcut[@(shortcutId)];
		if (!TGFeatureOK(result) && !messages){
			if (completion)
				completion(@[]);
			return;
		}
		if (completion)
			completion(messages ?: @[]);
	}];
}

- (void)checkQuickReplyShortcutName:(NSString *)name
                         completion:(void (^)(BOOL, NSString *))completion {
	NSString *clean = [name stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!clean.length){
		if (completion)
			completion(NO, @"A shortcut needs a name.");
		return;
	}
	[self request:@{
		@"@type" : @"checkQuickReplyShortcutName",
		@"name"  : clean,
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)setQuickReplyShortcutName:(NSInteger)shortcutId
                             name:(NSString *)name
                       completion:(void (^)(BOOL, NSString *))completion {
	NSString *clean = [name stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!clean.length){
		if (completion)
			completion(NO, @"A shortcut needs a name.");
		return;
	}
	[self request:@{
		@"@type"       : @"setQuickReplyShortcutName",
		@"shortcut_id" : @(shortcutId),
		@"name"        : clean,
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (ok && shortcutId){
			NSMutableDictionary *row = self.quickReplyShortcutsById[@(shortcutId)];
			if (row)
				row[@"name"] = clean;
		}
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)deleteQuickReplyShortcut:(NSInteger)shortcutId
                      completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type"       : @"deleteQuickReplyShortcut",
		@"shortcut_id" : @(shortcutId),
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (ok && shortcutId){
			[self.quickReplyShortcutsById removeObjectForKey:@(shortcutId)];
			[self.quickReplyShortcutOrder removeObject:@(shortcutId)];
			[self.quickReplyMessagesByShortcut removeObjectForKey:@(shortcutId)];
		}
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)reorderQuickReplyShortcuts:(NSArray *)shortcutIds
                        completion:(void (^)(BOOL, NSString *))completion {
	NSArray *ids = shortcutIds ?: @[];
	[self request:@{
		@"@type"        : @"reorderQuickReplyShortcuts",
		@"shortcut_ids" : ids,
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (ok){
			[self.quickReplyShortcutOrder removeAllObjects];
			for (NSNumber *ident in ids)
				[self.quickReplyShortcutOrder addObject:ident];
		}
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)addQuickReplyShortcutMessage:(NSString *)shortcutName
                                text:(NSString *)text
                          completion:(void (^)(NSDictionary *, NSString *))completion {
	NSString *clean = [shortcutName stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!clean.length || !text.length){
		if (completion)
			completion(nil, @"A shortcut needs a name and a message.");
		return;
	}
	[self request:@{
		@"@type"                : @"addQuickReplyShortcutMessage",
		@"shortcut_name"        : clean,
		@"reply_to_message_id"  : @(0),
		@"input_message_content": @{
			@"@type" : @"inputMessageText",
			@"text"  : TGFormattedText(text),
		},
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(nil, TGFeatureErrorText(result));
			return;
		}
		NSDictionary *flat = TGFeatureMessagesFromResult(result).firstObject;
		if (completion)
			completion(flat, nil);
	}];
}

- (void)addQuickReplyShortcutMessageAlbum:(NSString *)shortcutName
                                    texts:(NSArray *)texts
                               completion:(void (^)(NSArray *, NSString *))completion {
	NSString *clean = [shortcutName stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSMutableArray *contents = [NSMutableArray array];
	for (NSString *text in texts){
		if (![text isKindOfClass:NSString.class] || !text.length)
			continue;
		[contents addObject:@{@"@type" : @"inputMessageText",
							  @"text"  : TGFormattedText(text)}];
	}
	if (!clean.length || contents.count < 2){
		if (completion)
			completion(@[], @"An album needs a name and at least two messages.");
		return;
	}
	[self request:@{
		@"@type"                 : @"addQuickReplyShortcutMessageAlbum",
		@"shortcut_name"         : clean,
		@"reply_to_message_id"   : @(0),
		@"input_message_contents": contents,
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(@[], TGFeatureErrorText(result));
			return;
		}
		if (completion)
			completion(TGFeatureMessagesFromResult(result), nil);
	}];
}

- (void)editQuickReplyMessage:(int64_t)messageId
                   shortcutId:(NSInteger)shortcutId
                         text:(NSString *)text
                   completion:(void (^)(BOOL, NSString *))completion {
	if (!messageId || !text.length){
		if (completion)
			completion(NO, @"A message needs text.");
		return;
	}
	[self request:@{
		@"@type"                : @"editQuickReplyMessage",
		@"shortcut_id"          : @(shortcutId),
		@"message_id"           : @(messageId),
		@"input_message_content": @{
			@"@type" : @"inputMessageText",
			@"text"  : TGFormattedText(text),
		},
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)deleteQuickReplyShortcutMessages:(NSArray *)messageIds
                              shortcutId:(NSInteger)shortcutId
                              completion:(void (^)(BOOL, NSString *))completion {
	NSArray *ids = messageIds ?: @[];
	if (!ids.count){
		if (completion)
			completion(NO, @"No messages were chosen.");
		return;
	}
	[self request:@{
		@"@type"       : @"deleteQuickReplyShortcutMessages",
		@"shortcut_id" : @(shortcutId),
		@"message_ids" : ids,
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (ok){
			NSMutableArray *cached = self.quickReplyMessagesByShortcut[@(shortcutId)];
			if (cached){
				for (NSNumber *ident in ids){
					for (NSUInteger i = 0; i < cached.count; i++){
						if ([cached[i][@"id"] isEqualToNumber:ident]){
							[cached removeObjectAtIndex:i];
							break;
						}
					}
				}
			}
		}
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)readdQuickReplyShortcutMessages:(NSArray *)messageIds
                           shortcutName:(NSString *)shortcutName
                             completion:(void (^)(NSArray *, NSString *))completion {
	NSString *clean = [shortcutName stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSArray *ids = messageIds ?: @[];
	if (!clean.length || !ids.count){
		if (completion)
			completion(@[], @"No removed messages to put back.");
		return;
	}
	[self request:@{
		@"@type"         : @"readdQuickReplyShortcutMessages",
		@"shortcut_name" : clean,
		@"message_ids"   : ids,
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(@[], TGFeatureErrorText(result));
			return;
		}
		if (completion)
			completion(TGFeatureMessagesFromResult(result), nil);
	}];
}

- (void)sendQuickReplyShortcutMessages:(NSInteger)shortcutId
                                toChat:(int64_t)chatId
                             sendingId:(int32_t)sendingId
                            completion:(void (^)(NSArray *, NSString *))completion {
	[self request:@{
		@"@type"       : @"sendQuickReplyShortcutMessages",
		@"chat_id"     : @(chatId),
		@"shortcut_id" : @(shortcutId),
		@"sending_id"  : @(sendingId),
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(@[], TGFeatureErrorText(result));
			return;
		}
		if (completion)
			completion(TGFeatureMessagesFromResult(result), nil);
	}];
}


- (void)applyQuickReplyShortcutUpdate:(NSDictionary *)update {
	NSDictionary *shortcut = TGFeatureDict(update[@"shortcut"]);
	NSNumber *ident = shortcut[@"id"];
	if (![ident isKindOfClass:NSNumber.class])
		return;
	if (!self.quickReplyShortcutsById)
		self.quickReplyShortcutsById = [NSMutableDictionary dictionary];
	if (!self.quickReplyShortcutOrder)
		self.quickReplyShortcutOrder = [NSMutableArray array];
	NSDictionary *first = TGFeatureDict(shortcut[@"first_message"]);
	NSString *preview = first.count ? (TGFlattenMessage(first)[@"text"] ?: @"") : @"";
	self.quickReplyShortcutsById[ident] = [@{
		@"id"          : ident,
		@"name"        : shortcut[@"name"] ?: @"",
		@"messageCount": shortcut[@"message_count"] ?: @(0),
		@"preview"     : preview,
	} mutableCopy];
	if (![self.quickReplyShortcutOrder containsObject:ident])
		[self.quickReplyShortcutOrder addObject:ident];
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGQuickRepliesChangedNotification object:nil];
}

- (void)applyQuickReplyShortcutDeleted:(NSDictionary *)update {
	NSNumber *ident = update[@"shortcut_id"];
	if (![ident isKindOfClass:NSNumber.class])
		return;
	[self.quickReplyShortcutsById removeObjectForKey:ident];
	[self.quickReplyShortcutOrder removeObject:ident];
	[self.quickReplyMessagesByShortcut removeObjectForKey:ident];
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGQuickRepliesChangedNotification object:nil];
}

- (void)applyQuickReplyShortcutsUpdate:(NSDictionary *)update {
	NSArray *ids = TGFeatureArray(update[@"shortcut_ids"]);
	if (!self.quickReplyShortcutOrder)
		self.quickReplyShortcutOrder = [NSMutableArray array];
	[self.quickReplyShortcutOrder removeAllObjects];
	for (NSNumber *ident in ids){
		if ([ident isKindOfClass:NSNumber.class])
			[self.quickReplyShortcutOrder addObject:ident];
	}
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGQuickRepliesChangedNotification object:nil];
}

- (void)applyQuickReplyShortcutMessagesUpdate:(NSDictionary *)update {
	NSNumber *ident = update[@"shortcut_id"];
	if (![ident isKindOfClass:NSNumber.class])
		return;
	if (!self.quickReplyMessagesByShortcut)
		self.quickReplyMessagesByShortcut = [NSMutableDictionary dictionary];
	NSMutableArray *messages = [NSMutableArray array];
	for (NSDictionary *message in TGFeatureArray(update[@"messages"])){
		if (![message isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *flat = TGFlattenMessage(message);
		[messages addObject:@{
			@"id"      : flat[@"id"] ?: @(0),
			@"text"    : flat[@"text"] ?: @"",
			@"kind"    : flat[@"kind"] ?: @"",
			@"photoId" : flat[@"photoId"] ?: [NSNull null],
		}];
	}
	self.quickReplyMessagesByShortcut[ident] = messages;
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGQuickRepliesChangedNotification object:nil];
}


@end
