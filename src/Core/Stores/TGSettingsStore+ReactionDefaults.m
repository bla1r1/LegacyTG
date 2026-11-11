//
// TGSettingsStore+ReactionDefaults.m - the privacy page's two reaction rows.
//
// The recent-reactions switch lives in the Reactions category; the default
// emoji and the clear request are separate TDLib methods the same page owns.
//
#import "TGSettingsStore.h"
#import "TGClientInternal.h"

@implementation TGSettingsStore (ReactionDefaults)

- (void)clearRecentReactionsWithCompletion:(void (^)(BOOL))completion {
	[[TGClient shared] request:@{@"@type" : @"clearRecentReactions"}
					completion:^(NSDictionary *result){
		BOOL ok = ![result[@"@type"] isEqualToString:@"error"];
		if (completion) completion(ok);
	}];
}

- (void)setDefaultReactionEmoji:(NSString *)emoji
					 completion:(void (^)(BOOL))completion {
	if (!emoji.length){
		if (completion) completion(NO);
		return;
	}
	[[TGClient shared] request:@{
		@"@type"         : @"setDefaultReactionType",
		@"reaction_type" : @{@"@type" : @"reactionTypeEmoji", @"emoji" : emoji},
	} completion:^(NSDictionary *result){
		BOOL ok = ![result[@"@type"] isEqualToString:@"error"];
		// The update says the same thing later; setting it here keeps the
		// picker that asked from flicking back to the old default first.
		if (ok)
			[TGClient shared].reactionDefaultEmoji = emoji;
		else
			NSLog(@"setDefaultReactionType %@: %@", emoji, result[@"message"]);
		if (completion) completion(ok);
	}];
}

@end
