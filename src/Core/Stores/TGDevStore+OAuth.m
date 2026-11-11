//
// TGDevStore+OAuth.m - the Dev store's OAuth requests.
//
// Bodies copied from src/Core/Client/Audit/TGClient+OAuth.m; the store owns them.
//

#import "TGDevStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGDevStore (OAuth)

#pragma mark - OAuth

- (void)oauthLinkInfo:(NSString *)url
			   origin:(NSString *)origin
		   completion:(void (^)(NSDictionary *, NSString *))completion {
	url = [url stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!url.length){
		if (completion) completion(nil, @"A link is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getOauthLinkInfo",
					@"url" : url, @"in_app_origin" : (origin ?: @"")}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *matches = [NSMutableArray array];
		for (NSDictionary *match in result[@"match_codes"]){
			[matches addObject:TGAuditString(match, @"code")];
		}
		NSArray *codes = result[@"match_codes"];
		if (!matches.count && [codes isKindOfClass:NSArray.class]){
			for (id code in codes){
				if ([code isKindOfClass:NSString.class])
					[matches addObject:code];
			}
		}
		if (completion)
			completion(@{@"botUserId" : TGAuditNumber(result, @"bot_user_id"),
						 @"botName" : TGAuditString(result, @"bot_name"),
						 @"botUsername" : TGAuditString(result, @"bot_username"),
						 @"url" : TGAuditString(result, @"url"),
						 @"matches" : matches}, nil);
	}];
}

- (void)checkOauthMatchCode:(NSString *)code
					 forURL:(NSString *)url
				  completion:(void (^)(BOOL, NSString *))completion {
	if (!code.length || !url.length){
		if (completion) completion(NO, @"A link and a match code are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"checkOauthRequestMatchCode",
					@"url" : url, @"match_code" : code}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)acceptOauthRequest:(NSString *)url
				 matchCode:(NSString *)code
			allowWriteAccess:(BOOL)allowWriteAccess
		 allowPhoneNumberAccess:(BOOL)allowPhoneNumberAccess
				completion:(void (^)(NSString *, NSString *))completion {
	if (!url.length || !code.length){
		if (completion) completion(nil, @"A link and a match code are needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"acceptOauthRequest",
					@"url" : url,
					@"match_code" : code,
					@"allow_write_access" : @(allowWriteAccess),
					@"allow_phone_number_access" : @(allowPhoneNumberAccess),
					@"ton_connect_connect_data" : [NSNull null]}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditString(result, @"url"), nil);
	}];
}

- (void)declineOauthRequest:(NSString *)url
				 completion:(void (^)(BOOL, NSString *))completion {
	if (!url.length){
		if (completion) completion(NO, @"A link is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"declineOauthRequest", @"url" : url}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

@end
