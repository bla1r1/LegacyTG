#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountLocalNotifications.h"
#import "TGClient+AccountSupport.h"


/// Defined with the autosave reads below; the update branch above it only
/// needs the same flattening so both paths produce one row shape.
static NSDictionary *TGFlattenAutosaveScope(NSDictionary *settings);






static NSDictionary *TGFlattenAutosaveScope(NSDictionary *settings) {
	if (![settings isKindOfClass:NSDictionary.class])
		return @{};
	return @{
		@"photos"       : settings[@"autosave_photos"] ?: @NO,
		@"videos"       : settings[@"autosave_videos"] ?: @NO,
		@"maxVideoSize" : settings[@"max_video_file_size"] ?: @(0),
	};
}

@implementation TGClient (AccountLocalNotifications)

#pragma mark - local notifications

/// The group types TDLib names. A raw "@type" is not what a row header
/// should read, and the four labels are all the schema has.
- (void)applyHavePendingNotificationsUpdate:(NSDictionary *)update {
	self.haveDelayedNotifications =
			[update[@"have_delayed_notifications"] boolValue];
	self.haveUnreceivedNotifications =
			[update[@"have_unreceived_notifications"] boolValue];
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGActiveNotificationsChangedNotification
						  object:self
						userInfo:@{@"pending" : @(self.havePendingNotifications)}];
}

- (void)applyAutosaveSettingsUpdate:(NSDictionary *)update {
	NSString *scopeType = update[@"scope"][@"@type"] ?: @"";
	NSString *scope = nil;
	if ([scopeType isEqualToString:@"autosaveSettingsScopeGroupChats"])
		scope = @"groups";
	else if ([scopeType isEqualToString:@"autosaveSettingsScopeChannelChats"])
		scope = @"channels";
	else if ([scopeType isEqualToString:@"autosaveSettingsScopePrivateChats"])
		scope = @"private";

	if (scope.length && [update[@"settings"] isKindOfClass:NSDictionary.class]){
		NSMutableDictionary *scopes = [self.autosaveSettingsByScope mutableCopy]
				?: [NSMutableDictionary dictionary];
		scopes[scope] = TGFlattenAutosaveScope(update[@"settings"]);
		self.autosaveSettingsByScope = scopes;
	}
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGAutosaveSettingsChangedNotification object:self];
}


@end
