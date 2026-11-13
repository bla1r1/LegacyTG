#import "TGSettingsStore.h"
#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountReactions.h"
#import "TGClient+AccountSupport.h"







@implementation TGSettingsStore (Reactions)

#pragma mark - reactions

- (NSDictionary *)reactionNotificationSettings {
	return [TGClient shared].reactionNotificationSettingsValue;
}

/// No record yet means Telegram has not answered the post-login burst; its
/// default is to show them, so the switch starts on rather than off.
- (BOOL)reactionNotificationsEnabled {
	NSString *source = [TGClient shared].reactionNotificationSettingsValue[@"message_reaction_source"][@"@type"];
	if (!source.length)
		return YES;
	return ![source isEqualToString:@"reactionNotificationSourceNone"];
}

- (void)setReactionNotificationsEnabled:(BOOL)enabled
                             completion:(void (^)(BOOL))completion {
	// setReactionNotificationSettings replaces the whole record. Reading the
	// one Telegram last sent is the only way toggling reactions does not also
	// reset the story and poll sources or the chosen sound.
	NSDictionary *current = [TGClient shared].reactionNotificationSettingsValue ?: @{};
	NSDictionary *all = @{@"@type" : @"reactionNotificationSourceAll"};
	NSMutableDictionary *next = [@{
		@"@type"                    : @"reactionNotificationSettings",
		@"message_reaction_source"  : enabled
				? all : @{@"@type" : @"reactionNotificationSourceNone"},
		@"story_reaction_source"    : current[@"story_reaction_source"] ?: all,
		@"poll_vote_source"         : current[@"poll_vote_source"] ?: all,
		@"sound_id"                 : current[@"sound_id"] ?: @(0),
		@"show_preview"             : current[@"show_preview"] ?: @YES,
	} mutableCopy];

	[[TGClient shared] request:@{@"@type" : @"setReactionNotificationSettings",
					@"notification_settings" : next}
	   completion:^(NSDictionary *result){
		BOOL ok = ![result[@"@type"] isEqualToString:@"error"];
		if (!ok){
			NSLog(@"setReactionNotificationSettings: %@", result[@"message"]);
			if (completion) completion(NO);
			return;
		}
		[TGClient shared].reactionNotificationSettingsValue = next;
		// The settings page rebuilds from what it reads, and this write is
		// the one place the local copy moves without a server update.
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGNotificationSettingsChangedNotification object:[TGClient shared]];
		if (completion) completion(YES);
	}];
}


@end
