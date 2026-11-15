//
// TGUpdateHandlersSupport.h - pure helpers shared by the update families.
//
#import <Foundation/Foundation.h>

static inline NSString *TGUPlainTitle(id value){
	while ([value isKindOfClass:NSDictionary.class])
		value = value[@"text"];
	return [value isKindOfClass:NSString.class] ? value : nil;
}

static inline NSString *TGUFolderTitle(NSDictionary *f){
	NSString *answer = TGUPlainTitle(f[@"title"]) ?: TGUPlainTitle(f[@"name"]);
	return answer.length ? answer : @"";
}

static inline NSString *TGUFirstActiveUsername(NSDictionary *user){
	id usernames = user[@"usernames"];
	if (![usernames isKindOfClass:NSDictionary.class])
		return nil;
	id names = usernames[@"active_usernames"];
	return [names isKindOfClass:NSArray.class] ? [names firstObject] : nil;
}

/// The ring round a chat-list avatar from active_story_state: 0 none, 1 seen
/// (grey), 2 unseen or live (accent), as official ChatListItem draws it.
static inline NSInteger TGUStoryRing(id state){
	if (![state isKindOfClass:NSDictionary.class])
		return 0;
	NSString *type = state[@"@type"];
	if ([type isEqualToString:@"activeStoryStateRead"])
		return 1;
	if ([type isEqualToString:@"activeStoryStateUnread"] || [type isEqualToString:@"activeStoryStateLive"])
		return 2;
	return 0;
}

static inline NSArray *TGUEffectIdList(id value){
	if (![value isKindOfClass:NSArray.class])
		return @[];
	NSMutableArray *ids = [NSMutableArray array];
	for (id raw in value){
		if (![raw isKindOfClass:NSNumber.class] && ![raw isKindOfClass:NSString.class])
			continue;
		[ids addObject:@([raw longLongValue])];
	}
	return ids;
}
