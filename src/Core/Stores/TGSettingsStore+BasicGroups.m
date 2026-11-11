//
// TGSettingsStore+BasicGroups.m - the one resolver the Tier 3 page needs.
//
// A basic group's record and the chat that carries its name, in one call.
//
#import "TGSettingsStore.h"
#import "TGClientInternal.h"
#import "TGClient+Groups.h"

@implementation TGSettingsStore (BasicGroups)

/// The basic group's record, which is what a basic-group id resolves to before
/// any chat exists in the local database. `getBasicGroupFullInfo` is the other
/// half the profile reads; this one carries the member count and the status
/// word the debug resolver shows beside the name.
- (void)basicGroupInfo:(int64_t)basicGroupId
			completion:(void (^)(NSDictionary *info))completion {
	if (!basicGroupId){
		if (completion) completion(nil);
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getBasicGroup",
								 @"basic_group_id" : @(basicGroupId)}
					completion:^(NSDictionary *group){
		if ([group[@"@type"] isEqualToString:@"error"]){
			if (completion) completion(nil);
			return;
		}
		// getBasicGroup carries no name; the chat record does. Resolving it
		// here means the resolver row can show the group as a name with a
		// member count rather than as an id with a result.
		[[TGClient shared] request:@{@"@type" : @"createBasicGroupChat",
									 @"basic_group_id" : @(basicGroupId),
									 @"force" : @NO}
						completion:^(NSDictionary *chat){
			[[TGClient shared] mergeChat:chat];
			if (completion)
				completion(@{
					@"id"         : group[@"id"] ?: @(basicGroupId),
					@"title"      : chat[@"title"] ?: @"Group",
					@"members"    : group[@"member_count"] ?: @(0),
					@"status"     : TGMemberStatusName(group[@"status"]),
					@"active"     : group[@"is_active"] ?: @NO,
					@"upgradedTo" : group[@"upgraded_to_supergroup_id"] ?: @(0),
				});
		}];
	}];
}

@end
