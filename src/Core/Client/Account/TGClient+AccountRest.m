#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGLocalization.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountRest.h"
#import "TGClient+AccountSupport.h"


/// The row title for a blocked user or chat answer; a deleted account has
/// no name at all and says so, as official does.
BOOL TGBlockedSenderIsDeleted(NSDictionary *answer) {
	if (![answer isKindOfClass:NSDictionary.class])
		return NO;
	if ([answer[@"@type"] isEqualToString:@"user"])
		return [answer[@"type"][@"@type"] isEqualToString:@"userTypeDeleted"];
	return NO;
}

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
/// The end of the road, asked with the reason Telegram's own form collects
/// and the password two-step verification demands.
/// Their Recent Calls page is a search across every chat for call messages -
/// there is no separate call log in TDLib.
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
