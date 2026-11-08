#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountLocalNotifications.h"
#import "TGClient+AccountSupport.h"


/// Defined with the autosave reads below; the update branch above it only
/// needs the same flattening so both paths produce one row shape.
static NSDictionary *TGFlattenAutosaveScope(NSDictionary *settings);

/// TDLib names the three scopes; the app names them shortly.
static NSString *TGScopeType(NSString *scope) {
	if ([scope isEqualToString:@"groups"])   return @"notificationSettingsScopeGroupChats";
	if ([scope isEqualToString:@"channels"]) return @"notificationSettingsScopeChannelChats";
	return @"notificationSettingsScopePrivateChats";
}

/// Kept as a compatibility call into the pure gift flattening utility.
static NSDictionary *TGFlattenGift(NSDictionary *entry) {
	return TGFlattenReceivedGift(entry);
}


static NSArray *TGPacksFrom(NSDictionary *target) {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *pack in target[@"language_packs"]){
		if (![pack[@"id"] length])
			continue;
		[out addObject:@{@"id"   : pack[@"id"],
						 @"name" : pack[@"native_name"] ?: pack[@"name"] ?: pack[@"id"]}];
	}
	return out;
}





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
