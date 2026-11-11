#import "TGAccountStore.h"
#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountTwoStep.h"
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





@implementation TGAccountStore (TwoStep)

#pragma mark - two-step verification

/// The password written whole. A wrong old password is the error here, and
/// the screen above is what says that to a human. An empty new password is
/// how the password comes off, not a refusal to write one.
- (void)setPassword:(NSString *)oldPassword
				new:(NSString *)newPassword
			  hint:(NSString *)hint
	setEmailAddress:(BOOL)setEmailAddress
			  email:(NSString *)recoveryEmail
		 completion:(void (^)(BOOL))completion {
	[[TGClient shared] request:@{
		@"@type"                      : @"setPassword",
		@"old_password"               : oldPassword ?: @"",
		@"new_password"               : newPassword ?: @"",
		@"new_hint"                   : hint ?: @"",
		@"set_recovery_email_address" : @(setEmailAddress),
		@"new_recovery_email_address" : recoveryEmail ?: @"",
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

/// What a recovery address says - and whether the password that asked for it
/// was right, because a wrong one is answered with an empty class where the
/// email would have been.
- (void)recoveryEmailAddress:(NSString *)password
				  completion:(void (^)(NSString *))completion {
	[self recoveryEmailAddress:password completionWithError:^(NSString *email, NSString *error){
		if (completion)
			completion(email ?: @"");
	}];
}

- (void)recoveryEmailAddress:(NSString *)password
		  completionWithError:(void (^)(NSString *, NSString *))completion {
	[[TGClient shared] request:@{
		@"@type"    : @"getRecoveryEmailAddress",
		@"password" : password ?: @"",
	} completion:^(NSDictionary *result){
		if ([result[@"@type"] isEqualToString:@"recoveryEmailAddress"]){
			if (completion)
				completion(result[@"recovery_email_address"] ?: @"", nil);
			return;
		}
		NSString *error = result[@"message"];
		if (!error.length)
			error = @"An error occurred.";
		if (completion)
			completion(nil, error);
	}];
}

/// Point the recovery address somewhere else. TDLib confirms the new one by
/// letter afterwards, so the answer says the request landed, not that the
/// address is live.
- (void)setRecoveryEmailAddress:(NSString *)password
							 to:(NSString *)email
					 completion:(void (^)(BOOL))completion {
	[[TGClient shared] request:@{
		@"@type"                      : @"setRecoveryEmailAddress",
		@"password"                   : password ?: @"",
		@"new_recovery_email_address" : email ?: @"",
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}


@end
