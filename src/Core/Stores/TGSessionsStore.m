//
// TGSessionsStore.m - the session list and the calls that act on one.
//
// The request bodies were the client's; they live here now so the Devices
// pages ask the store. The client is still the transport, and the state the
// answer describes stays on it.
//
#import "TGSessionsStore.h"
#import "TGClientInternal.h"

@implementation TGSessionsStore

+ (instancetype)shared {
	static TGSessionsStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		store = [[TGSessionsStore alloc] init];
	});
	return store;
}

#pragma mark - the list

- (void)sessionsWithCompletion:(void (^)(NSArray *))completion {
	[self sessionsWithInactiveTtlCompletion:^(NSArray *sessions, NSInteger ttlDays){
		if (completion) completion(sessions);
	}];
}

- (void)sessionsWithInactiveTtlCompletion:(void (^)(NSArray *, NSInteger))completion {
	[[TGClient shared] request:@{@"@type" : @"getActiveSessions"}
					completion:^(NSDictionary *result){
		if ([result[@"@type"] isEqualToString:@"error"]){
			if (completion) completion(@[], 0);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *session in result[@"sessions"]){
			[out addObject:@{
				@"id"         : session[@"id"] ?: @0,
				@"name"       : session[@"application_name"] ?: @"",
				@"platform"   : [NSString stringWithFormat:@"%@ %@",
						session[@"platform"] ?: @"", session[@"system_version"] ?: @""],
				@"ip"         : session[@"ip_address"] ?: session[@"ip"] ?: @"",
				@"isCurrent"  : session[@"is_current"] ?: @NO,
				@"isUnconfirmed" : session[@"is_unconfirmed"] ?: @NO,
				@"canAcceptSecretChats" : session[@"can_accept_secret_chats"] ?: @YES,
				@"canAcceptCalls" : session[@"can_accept_calls"] ?: @YES,
				@"lastActive" : session[@"last_active_date"] ?: @0,
			}];
		}
		if (completion)
			completion(out, [result[@"inactive_session_ttl_days"] integerValue]);
	}];
}

#pragma mark - acting on one

- (void)terminateSession:(long long)sessionId {
	[[TGClient shared] send:@{@"@type" : @"terminateSession",
							  @"session_id" : @(sessionId)}];
}

- (void)terminateAllOtherSessions:(void (^)(BOOL))completion {
	[[TGClient shared] request:@{@"@type" : @"terminateAllOtherSessions"}
					completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)confirmSession:(long long)sessionId {
	[[TGClient shared] send:@{@"@type" : @"confirmSession",
							  @"session_id" : @(sessionId)}];
}

- (void)toggleSession:(long long)sessionId
	   canAcceptCalls:(BOOL)canAccept
		   completion:(void (^)(BOOL, NSString *))completion {
	if (!sessionId){
		if (completion) completion(NO, @"No session was named.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"toggleSessionCanAcceptCalls",
								 @"session_id" : @(sessionId),
								 @"can_accept_calls" : @(canAccept)}
					completion:^(NSDictionary *result){
		BOOL failed = [result[@"@type"] isEqualToString:@"error"];
		NSString *message = [result[@"message"] isKindOfClass:NSString.class]
				? result[@"message"] : @"An error occurred.";
		if (completion) completion(!failed, failed ? message : nil);
	}];
}

- (void)toggleSession:(int64_t)sessionId canAcceptSecretChats:(BOOL)can {
	[[TGClient shared] send:@{@"@type" : @"toggleSessionCanAcceptSecretChats",
							  @"session_id" : @(sessionId),
							  @"can_accept_secret_chats" : @(can)}];
}

#pragma mark - the idle timeout

- (void)setInactiveSessionTtlDays:(NSInteger)days
					   completion:(void (^)(BOOL, NSString *))completion {
	// TDLib's own range; naming it here means the picker cannot send a value
	// the server will only reject.
	if (days < 1 || days > 366){
		if (completion) completion(NO, @"The idle timeout is 1 to 366 days.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"setInactiveSessionTtl",
								 @"inactive_session_ttl_days" : @((int32_t)days)}
					completion:^(NSDictionary *result){
		BOOL failed = [result[@"@type"] isEqualToString:@"error"];
		NSString *message = [result[@"message"] isKindOfClass:NSString.class]
				? result[@"message"] : @"An error occurred.";
		if (completion) completion(!failed, failed ? message : nil);
	}];
}

@end
