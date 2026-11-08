#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountAutosave.h"
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





@implementation TGClient (AccountAutosave)

#pragma mark - autosave

static NSString *TGAutosaveScopeType(NSString *scope) {
	if ([scope isEqualToString:@"groups"])
		return @"autosaveSettingsScopeGroupChats";
	if ([scope isEqualToString:@"channels"])
		return @"autosaveSettingsScopeChannelChats";
	return @"autosaveSettingsScopePrivateChats";
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

- (void)autosaveSettingsWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getAutosaveSettings"}
	   completion:^(NSDictionary *result){
		if (![result isKindOfClass:NSDictionary.class] ||
			[result[@"@type"] isEqualToString:@"error"]){
			if (completion) completion(nil);
			return;
		}
		NSMutableArray *exceptions = [NSMutableArray array];
		for (NSDictionary *exception in result[@"exceptions"]){
			if (![exception isKindOfClass:NSDictionary.class])
				continue;
			NSMutableDictionary *row = [@{
				@"chatId" : exception[@"chat_id"] ?: @(0),
			} mutableCopy];
			[row addEntriesFromDictionary:TGFlattenAutosaveScope(exception[@"settings"])];
			[exceptions addObject:row];
		}
		NSDictionary *settings = @{
			@"private"    : TGFlattenAutosaveScope(result[@"private_chat_settings"]),
			@"groups"     : TGFlattenAutosaveScope(result[@"group_settings"]),
			@"channels"   : TGFlattenAutosaveScope(result[@"channel_settings"]),
			@"exceptions" : exceptions,
		};
		if (completion) completion(settings);
	}];
}

- (void)setAutosaveSettingsForScope:(NSString *)scope
							 photos:(BOOL)photos
							 videos:(BOOL)videos
					   maxVideoSize:(long long)maxVideoSize
						 completion:(void (^)(BOOL))completion {
	NSDictionary *settings = @{
		@"@type"              : @"scopeAutosaveSettings",
		@"autosave_photos"    : @(photos),
		@"autosave_videos"    : @(videos),
		@"max_video_file_size": @(maxVideoSize),
	};
	[self request:@{
		@"@type"    : @"setAutosaveSettings",
		@"scope"    : @{@"@type" : TGAutosaveScopeType(scope)},
		@"settings" : settings,
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)clearAutosaveSettingsExceptionsWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"clearAutosaveSettingsExceptions"}
	   completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}


@end
