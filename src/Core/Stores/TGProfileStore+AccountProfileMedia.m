#import "TGProfileStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountProfileMedia.h"
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





@implementation TGProfileStore (AccountProfileMedia)

#pragma mark - profile photos, link, groups in common

/// A profile photo taken off the account by the id the chatPhoto carried.
- (void)deleteProfilePhoto:(int64_t)photoId
				completion:(void (^)(BOOL))completion {
	if (!photoId){
		if (completion) completion(NO);
		return;
	}
	[[TGClient shared] request:@{
		@"@type"            : @"deleteProfilePhoto",
		@"profile_photo_id" : @(photoId),
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

/// The account's whole photo history: what the avatar tap shows, and the
/// only place a photoId worth deleting answers from.
- (void)userProfilePhotos:(int64_t)userId
			   completion:(void (^)(NSArray *))completion {
	[[TGClient shared] request:@{
		@"@type"   : @"getUserProfilePhotos",
		@"user_id" : @(userId),
		@"offset"  : @(0),
		@"limit"   : @(50),
	} completion:^(NSDictionary *result){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *photo in result[@"photos"]){
			int64_t photoId = [photo[@"id"] longLongValue];
			NSNumber *fileId = photo[@"small"][@"id"];
			if (!photoId || !fileId)
				continue;
			[out addObject:@{@"photoId" : @(photoId),
							  @"fileId" : fileId,
							  @"date" : photo[@"date"] ?: @(0)}];
		}
		if (completion) completion(out);
	}];
}

/// The signed-in account's own t.me link - Telegram gives it only for the
/// current user, so there is no asking for someone else's.
- (void)myUserLink:(void (^)(NSString *))completion {
	[[TGClient shared] request:@{
		@"@type"                 : @"getUserLink",
		@"remove_messages_fee"   : @NO,
		@"return_permanent_link" : @YES,
		@"revoke_previous_links" : @NO,
	} completion:^(NSDictionary *result){
		if (completion) completion(result[@"url"] ?: @"");
	}];
}

/// The chats two accounts are in together, named off the answer itself, so
/// a tap opens it like any chat the list holds.
- (void)groupsInCommonWithUser:(int64_t)userId
					completion:(void (^)(NSArray *))completion {
	[[TGClient shared] request:@{
		@"@type"          : @"getGroupsInCommon",
		@"user_id"        : @(userId),
		@"offset_chat_id" : @(0),
		@"limit"          : @(50),
	} completion:^(NSDictionary *result){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *chat in result[@"chats"]){
			NSString *title = chat[@"title"] ?: @"";
			if (!title.length)
				continue;
			[out addObject:@{@"chatId" : chat[@"id"] ?: @0,
							  @"title" : title}];
		}
		if (completion) completion(out);
	}];
}


@end
