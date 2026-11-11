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
