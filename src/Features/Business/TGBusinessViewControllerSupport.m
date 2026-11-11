#import "TGBusinessViewController.h"
#import "TGBusinessMessagesViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGBusinessBaseViewController.h"
#import "TGBusinessStore.h"
#import "TGProfileStore.h"

//
// TGBusinessViewController.m - Telegram Business settings, the profile
// fields, the automated messages, the location/hours/intro and links to
// chat.
//
// The account-level settings are real subscriber features. The profile
// checksum through setBusinessAccount* carries a business connection id and
// is declared bot-only; when a user account tries it, Telegram answers with
// its refusal and the alert shows that sentence. The row stays visible
// because hiding it would leave a Business subscriber with a page that
// silently does less than the official client.
//


static NSString *const TGBusinessConnectionDefaultsKey = @"TGBusinessConnectionId";



/// The names Telegram's Business page uses for the feature type names the
/// server returns. A feature this wave has no screen for is still listed:
/// saying Telegram included it is more honest than dropping it silently.
static NSString *TGBusinessFeatureTitle(NSString *type) {
	if ([type isEqualToString:@"businessFeatureLocation"]) return @"Location";
	if ([type isEqualToString:@"businessFeatureOpeningHours"]) return @"Opening Hours";
	if ([type isEqualToString:@"businessFeatureQuickReplies"]) return @"Quick Replies";
	if ([type isEqualToString:@"businessFeatureGreetingMessage"]) return @"Greeting Messages";
	if ([type isEqualToString:@"businessFeatureAwayMessage"]) return @"Away Messages";
	if ([type isEqualToString:@"businessFeatureAccountLinks"]) return @"Links to Chat";
	if ([type isEqualToString:@"businessFeatureStartPage"]) return @"Intro";
	if ([type isEqualToString:@"businessFeatureBots"]) return @"Chatbots";
	if ([type isEqualToString:@"businessFeatureEmojiStatus"]) return @"Emoji Status";
	if ([type isEqualToString:@"businessFeatureChatFolderTags"]) return @"Chat Folder Tags";
	if ([type isEqualToString:@"businessFeatureUpgradedStories"]) return @"Upgraded Stories";
	return type ?: @"Feature";
}

/// businessRecipients, as the switches on the greeting and away pages hold
/// it. The defaults are Telegram's "all 1-to-1 chats".
static NSDictionary *TGBusinessRecipients(BOOL existing, BOOL newChats,
										  BOOL contacts, BOOL nonContacts,
										  BOOL excludeSelected) {
	return @{
		@"existing" : @(existing),
		@"new" : @(newChats),
		@"contacts" : @(contacts),
		@"nonContacts" : @(nonContacts),
		@"excludeSelected" : @(excludeSelected),
	};
}

#pragma mark - the shared list screen


NSString *TGBusinessStoredConnectionId(void) {
	NSString *value = [[NSUserDefaults standardUserDefaults]
			stringForKey:TGAccountDefaultsKey(TGBusinessConnectionDefaultsKey)];
	return [value isKindOfClass:NSString.class] ? value : @"";
}
void TGBusinessStoreConnectionId(NSString *connectionId) {
	[[NSUserDefaults standardUserDefaults] setObject:(connectionId ?: @"")
											  forKey:TGAccountDefaultsKey(TGBusinessConnectionDefaultsKey)];
}
