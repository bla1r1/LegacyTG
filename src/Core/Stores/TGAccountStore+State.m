//
// TGAccountStore+State.m - the account values the account pages read.
//
// Sign-in state, the account's stars, the freeze and verification records
// Telegram sent, a user's subscription and the account's own username. These
// are reads of the client's account cache plus the one setter; putting them
// behind the store keeps a page from importing the client.
//
#import "TGAccountStore.h"
#import "TGClientInternal.h"
#import "TGClient+AccountMisc.h"
#import "TGClient+Revenue.h"

@implementation TGAccountStore (State)

- (TGAuthState)authState {
	return [TGClient shared].authState;
}

- (int64_t)ownedStarCount {
	return [TGClient shared].ownedStarCount;
}

- (NSDictionary *)freezeState {
	NSDictionary *state = [TGClient shared].freezeState;
	return [state isKindOfClass:NSDictionary.class] ? state : @{};
}

- (NSDictionary *)ageVerificationParameters {
	NSDictionary *parameters = [TGClient shared].ageVerificationParameters;
	return [parameters isKindOfClass:NSDictionary.class] ? parameters : @{};
}

- (NSDictionary *)recaptchaVerificationRequest {
	NSDictionary *request = [TGClient shared].recaptchaVerificationRequest;
	return [request isKindOfClass:NSDictionary.class] ? request : @{};
}

- (NSDictionary *)subscriptionForUserId:(int64_t)userId {
	id row = [TGClient shared].userSubscriptionsById[@(userId)];
	return [row isKindOfClass:NSDictionary.class] ? row : nil;
}

#pragma mark - the account's own username

- (void)setUsername:(NSString *)username completion:(void (^)(BOOL))completion {
	[[TGClient shared] request:@{@"@type" : @"setUsername", @"username" : username ?: @""}
					completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

@end
