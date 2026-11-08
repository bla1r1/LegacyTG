#import "TGClient+Base.h"

@interface TGClient (OAuth)

- (void)oauthLinkInfo:(NSString *)url
			   origin:(NSString *)origin
		   completion:(void (^)(NSDictionary *info,
								NSString *error))completion;

- (void)checkOauthMatchCode:(NSString *)code
						forURL:(NSString *)url
					  completion:(void (^)(BOOL ok, NSString *error))completion;

/// Accepts an OAuth request and answers the URL that finishes it. The URL is
/// opened in the browser; this client hosts no in-app browser.
- (void)acceptOauthRequest:(NSString *)url
				 matchCode:(NSString *)code
			allowWriteAccess:(BOOL)allowWriteAccess
		 allowPhoneNumberAccess:(BOOL)allowPhoneNumberAccess
				completion:(void (^)(NSString *link, NSString *error))completion;

- (void)declineOauthRequest:(NSString *)url
				 completion:(void (^)(BOOL ok, NSString *error))completion;

@end
