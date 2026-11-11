//
// TGStoryStore+Stealth.m - copied from TGClient+StoriesStealth.m.
//
#import "TGStoryStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+StoriesSupport.h"

#import "TGClient+StoriesStealth.h"
#import "TGClient+StoriesSupport.h"
#import "TGClientInternal.h"

@implementation TGStoryStore (StoriesStealth)

#pragma mark - stealth

- (void)activateStoryStealthModeWithCompletion:
		(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"activateStoryStealthMode"}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

@end

// vim:ft=objc
