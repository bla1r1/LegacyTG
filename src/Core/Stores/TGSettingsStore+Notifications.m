#import "TGSettingsStore.h"
#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountSettings.h"
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





@implementation TGSettingsStore (Notifications)

#pragma mark - account settings

- (void)notificationsMutedForScope:(NSString *)scope
                        completion:(void (^)(BOOL))completion {
	[[TGClient shared] request:@{
		@"@type" : @"getScopeNotificationSettings",
		@"scope" : @{@"@type" : TGScopeType(scope)},
	} completion:^(NSDictionary *settings){
		// There is no flag: a very large mute_for is how muting is expressed.
		if (completion) completion([settings[@"mute_for"] integerValue] > 0);
	}];
}

/// setScopeNotificationSettings replaces the whole record, so writing one field
/// means reading the rest back first - otherwise muting a scope silently reset
/// its preview setting, and turning previews off unmuted it.
- (void)updateScope:(NSString *)scope
			 change:(NSDictionary *(^)(NSDictionary *current))change
{
	[[TGClient shared] request:@{
		@"@type" : @"getScopeNotificationSettings",
		@"scope" : @{@"@type" : TGScopeType(scope)},
	} completion:^(NSDictionary *current){
		NSMutableDictionary *next = [@{
			@"@type"                : @"scopeNotificationSettings",
			@"mute_for"             : current[@"mute_for"] ?: @(0),
			@"sound_id"             : current[@"sound_id"] ?: @(0),
			@"show_preview"         : current[@"show_preview"] ?: @YES,
			@"use_default_mute_stories" :
					current[@"use_default_mute_stories"] ?: @YES,
			@"mute_stories"         : current[@"mute_stories"] ?: @NO,
			@"story_sound_id"       : current[@"story_sound_id"] ?: @(0),
			@"show_story_poster"    : current[@"show_story_poster"] ?: @YES,
			@"disable_pinned_message_notifications" :
					current[@"disable_pinned_message_notifications"] ?: @NO,
			@"disable_mention_notifications" :
					current[@"disable_mention_notifications"] ?: @NO,
		} mutableCopy];
		[next addEntriesFromDictionary:change(current)];
		[[TGClient shared] send:@{
			@"@type" : @"setScopeNotificationSettings",
			@"scope" : @{@"@type" : TGScopeType(scope)},
			@"notification_settings" : next,
		}];
	}];
}

- (void)setScope:(NSString *)scope muted:(BOOL)muted {
	[self updateScope:scope change:^NSDictionary *(NSDictionary *current){
		return @{@"mute_for" : @(muted ? 365 * 24 * 3600 : 0)};
	}];
}

- (void)notificationPreviewForScope:(NSString *)scope
						 completion:(void (^)(BOOL))completion {
	[[TGClient shared] request:@{
		@"@type" : @"getScopeNotificationSettings",
		@"scope" : @{@"@type" : TGScopeType(scope)},
	} completion:^(NSDictionary *settings){
		if (completion) completion([settings[@"show_preview"] boolValue]);
	}];
}

- (void)setScope:(NSString *)scope showPreview:(BOOL)show {
	[self updateScope:scope change:^NSDictionary *(NSDictionary *current){
		return @{@"show_preview" : @(show)};
	}];
}

- (void)resetAllNotificationSettings {
	[[TGClient shared] send:@{@"@type" : @"resetAllNotificationSettings"}];
}


@end
