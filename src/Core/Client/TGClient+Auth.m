#import "TGClientInternal.h"
#import <objc/runtime.h>

@interface TGClient (AuthPrivate)
- (void)setPushReceiverId:(int64_t)receiverId;
@end

@implementation TGClient (Auth)

- (void)setPushReceiverId:(int64_t)receiverId {
	objc_setAssociatedObject(self, @selector(pushReceiverId), @(receiverId),
							 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - authorization steps

- (void)flushPendingPhoneNumber {
	if (!self.pendingPhoneNumber.length)
		return;
	NSString *number = self.pendingPhoneNumber;
	self.pendingPhoneNumber = nil;
	[self send:@{
		@"@type"        : @"setAuthenticationPhoneNumber",
		@"phone_number" : number,
	}];
}

static NSString *TGAuthError(NSDictionary *result) {
	if ([result[@"@type"] isEqualToString:@"ok"])
		return nil;
	NSString *message = result[@"message"];
	return message.length ? message : @"An error occurred.";
}

/// passwordState has no "recovery_email_address_pattern": it carries a flag
/// for whether there is an address, and a pattern only while a code sent to
/// a new one is outstanding. Reading the absent key meant the Two-Step screen
/// never once showed an address.
/// A phone number Telegram has never seen lands in authorizationStateWait-
/// Registration, and the only way out of it is this. Without it a new account
/// could enter a code and then sit on the code screen forever.
/// The terms a new account has to be shown before it is made. Empty when
/// Telegram sent none with the registration state.
/// Every country Telegram knows, for the picker on the phone step. Entries
/// carry "code" (ISO), "name", "prefix" (the calling code with its +) and
/// "flag". Hidden countries are left out, as their own client leaves them.
/// The country this phone is in, as Telegram guesses it from the network -
/// which is what their phone step preselects. An ISO code, or nil.
#pragma mark - push

/// Hands the APNs token to Telegram, which is what makes a notification
/// arrive while the app is closed. Without it the app had no notifications
/// at all, however the certificate was set up.
///
/// `sandbox` has to match the certificate the build was signed against: a
/// production token registered as sandbox is silently never delivered to.
/// A notification that arrived while the app was running: TDLib decrypts it
/// and turns it into the ordinary updates, so the chat list moves without
/// waiting for the next poll.
///
/// APNs wraps Telegram's blob under "p", which is the one piece TDLib wants;
/// the alert above it is display data Telegram's own clients ignore.
/// What account a push belongs to, told by TDLib itself: works even while
/// the certificate is still on its way, because the blob sent over the wire
/// is all the answer needs. `ok` is NO for a payload TDLib cannot read.
/// Accepts the terms the update named, which is what lifts the restriction
/// the server put on the account until it happens.
- (void)acceptTermsOfService:(NSString *)termsId
				  completion:(void (^)(BOOL ok))completion {
	if (!termsId.length){
		if (completion) completion(NO);
		return;
	}
	[self request:@{@"@type" : @"acceptTermsOfService",
					@"terms_of_service_id" : termsId}
	   completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

#pragma mark - login email address

/// The request has no boolean: "ok" is the yes and an error is the no, with
/// its own words for why. Both are handed on rather than flattened into a
/// bare flag, because "you must set one" and "Telegram refused to answer"
/// are different things for the screen to say.
#pragma mark - web tokens and QR login

- (void)searchUserByToken:(NSString *)token
			   completion:(void (^)(NSDictionary *user, NSString *error))completion {
	[self request:@{@"@type" : @"searchUserByToken", @"token" : token ?: @""}
	   completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"user"]){
			completion(nil, TGAuthError(result));
			return;
		}
		NSString *first = result[@"first_name"] ?: @"";
		NSString *last = result[@"last_name"] ?: @"";
		NSString *name = [@[first, last] componentsJoinedByString:@" "];
		// A user found by token very often has no username at all - that is
		// why the link carried a token - and TDLib spells that as null, which
		// must not be subscripted.
		NSDictionary *usernames = [result[@"usernames"] isKindOfClass:NSDictionary.class]
				? result[@"usernames"] : nil;
		NSArray *actives = [usernames[@"active_usernames"] isKindOfClass:NSArray.class]
				? usernames[@"active_usernames"] : nil;
		NSString *username = [actives firstObject];
		completion(@{
			@"id" : result[@"id"] ?: @(0),
			@"name" : [name stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceCharacterSet]],
			@"username" : username ?: @"",
			@"phone" : result[@"phone_number"] ?: @"",
		}, nil);
	}];
}

#pragma mark - phone numbers

#pragma mark - password recovery inside the account

#pragma mark - temporary password and saved credentials

#pragma mark - recovery email and email verification

#pragma mark - ownership and application verification

/// The result list is small and each member means something different to the
/// screen: allowed, password wanted, or a wait. Retry times are handed back
/// in seconds so the sheet can say how long rather than "later".
/// The update can arrive more than once while the request is outstanding;
/// the last one is the one the token has to answer, so it is simply replaced.
- (void)noteApplicationVerificationWithId:(int64_t)verificationId
									nonce:(NSString *)nonce {
	objc_setAssociatedObject(self, @selector(pendingApplicationVerificationId),
			@(verificationId), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(self, @selector(pendingApplicationVerificationNonce),
			nonce ?: @"", OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
