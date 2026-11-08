#import "TGClient+StoriesStealth.h"
#import "TGClient+StoriesSupport.h"
#import "TGClientInternal.h"

@implementation TGClient (StoriesStealth)

#pragma mark - stealth

- (void)activateStoryStealthModeWithCompletion:
		(void (^)(BOOL, NSString *))completion {
	[self request:@{@"@type" : @"activateStoryStealthMode"}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

@end
