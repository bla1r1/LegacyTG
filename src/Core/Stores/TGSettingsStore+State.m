//
// TGSettingsStore+State.m - the account values a settings row reads.
//
// These are reads of the client's account cache, not requests. They live on
// the store so a settings page imports one header and still sees the same
// value the chat list and the profile see.
//
#import "TGSettingsStore.h"
#import "TGClientInternal.h"

@implementation TGSettingsStore (State)

- (NSDictionary *)archiveSettings {
	NSDictionary *settings = [TGClient shared].archiveSettings;
	return [settings isKindOfClass:NSDictionary.class] ? settings : @{};
}

- (NSDictionary *)defaultBackground {
	NSDictionary *background = [TGClient shared].defaultBackground;
	return [background isKindOfClass:NSDictionary.class] ? background : nil;
}

#pragma mark - logging

/// The Tier 3 console's two logging rows. The level is TDLib's own: 1 is
/// errors only, 5 is everything.
- (void)setLogVerbosityLevel:(NSInteger)level {
	[[TGClient shared] send:@{@"@type" : @"setLogVerbosityLevel",
							  @"new_verbosity_level" : @(level)}];
}

@end
