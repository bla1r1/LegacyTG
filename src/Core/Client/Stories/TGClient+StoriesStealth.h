#import "TGClient+Base.h"

@interface TGClient (StoriesStealth)

/// Hides this account's views for the past and next stealth window. Premium
/// only; the server's refusal is the answer the menu shows.
- (void)activateStoryStealthModeWithCompletion:
		(void (^)(BOOL ok, NSString *error))completion;

@end
