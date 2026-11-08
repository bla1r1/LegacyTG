#import "TGClient+SuggestedPosts.h"
#import "TGClientInternal.h"
#import "TGClient+FeatureSupport.h"

@implementation TGClient (SuggestedPosts)

#pragma mark - suggested posts and actions

- (void)suggestedPostForMessage:(int64_t)messageId
                         inChat:(int64_t)chatId
                     completion:(void (^)(NSDictionary *, NSString *))completion {
	[self request:@{
		@"@type"      : @"getMessage",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *message){
		if (!TGFeatureOK(message)){
			if (completion)
				completion(nil, TGFeatureErrorText(message));
			return;
		}
		NSDictionary *info = TGFeatureDict(message[@"suggested_post_info"]);
		if (![info isKindOfClass:NSDictionary.class] || !info.count ||
			[info isKindOfClass:NSNull.class]){
			if (completion)
				completion(nil, @"That message is not a suggested post.");
			return;
		}
		NSDictionary *post = @{
			@"price"        : TGFeatureSuggestedPrice(TGFeatureDict(info[@"price"])),
			@"sendDate"     : info[@"send_date"] ?: @(0),
			@"state"        : TGFeatureSuggestedState(TGFeatureString(info[@"state"][@"@type"])),
			@"canBeApproved": info[@"can_be_approved"] ?: @NO,
			@"canBeDeclined": info[@"can_be_declined"] ?: @NO,
		};
		if (completion)
			completion(post, nil);
	}];
}

- (void)approveSuggestedPost:(int64_t)messageId
                      inChat:(int64_t)chatId
                    sendDate:(NSInteger)sendDate
                  completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type"      : @"approveSuggestedPost",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"send_date"  : @(sendDate),
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)declineSuggestedPost:(int64_t)messageId
                      inChat:(int64_t)chatId
                     comment:(NSString *)comment
                  completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type"      : @"declineSuggestedPost",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"comment"    : comment ?: @"",
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (NSArray *)suggestedActions {
	return self.suggestedActionsValue ?: @[];
}

- (void)hideSuggestedAction:(NSDictionary *)action
                 completion:(void (^)(BOOL, NSString *))completion {
	NSDictionary *object = TGFeatureDict(action[@"action"]);
	if (!object.count){
		if (completion)
			completion(NO, @"No suggested action was chosen.");
		return;
	}
	[self request:@{
		@"@type"  : @"hideSuggestedAction",
		@"action" : object,
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (ok){
			NSString *key = TGFeatureActionKey(object);
			NSMutableArray *kept = [NSMutableArray array];
			for (NSDictionary *row in self.suggestedActionsValue){
				if (![TGFeatureActionKey(TGFeatureDict(row[@"action"])) isEqualToString:key])
					[kept addObject:row];
			}
			self.suggestedActionsValue = kept;
		}
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}


- (void)applySuggestedActionsUpdate:(NSDictionary *)update {
	NSMutableArray *rows = [NSMutableArray array];
	NSMutableSet *removed = [NSMutableSet set];
	for (NSDictionary *action in TGFeatureArray(update[@"removed_actions"])){
		if ([action isKindOfClass:NSDictionary.class])
			[removed addObject:TGFeatureActionKey(action)];
	}
	for (NSDictionary *row in self.suggestedActionsValue){
		NSDictionary *action = TGFeatureDict(row[@"action"]);
		if (![removed containsObject:TGFeatureActionKey(action)])
			[rows addObject:row];
	}
	NSMutableSet *seen = [NSMutableSet set];
	for (NSDictionary *row in rows)
		[seen addObject:TGFeatureActionKey(TGFeatureDict(row[@"action"]))];
	for (NSDictionary *action in TGFeatureArray(update[@"added_actions"])){
		if (![action isKindOfClass:NSDictionary.class])
			continue;
		NSString *key = TGFeatureActionKey(action);
		if ([seen containsObject:key])
			continue;
		[seen addObject:key];
		[rows addObject:@{
			@"title" : TGFeatureActionTitle(action),
			@"action": action,
		}];
	}
	self.suggestedActionsValue = rows;
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGSuggestedActionsChangedNotification object:nil];
}


@end
