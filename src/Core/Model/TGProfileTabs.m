//
// TGProfileTabs.m
//
#import "TGProfileTabs.h"

NSArray *TGProfileTabKinds(BOOL hasStories, BOOL hasGifts, BOOL hasCommonGroups,
		BOOL ownPublicProfile, NSString *mainKind) {
	NSMutableArray *out = [NSMutableArray array];
	if (hasStories || ownPublicProfile)
		[out addObject:@"stories"];
	if (hasGifts)
		[out addObject:@"gifts"];
	if (!ownPublicProfile)
		[out addObjectsFromArray:@[@"media", @"files", @"music", @"voice", @"links"]];
	if (hasCommonGroups)
		[out addObject:@"groups"];
	if (ownPublicProfile)
		[out addObject:@"archive"];

	// td_api's profileTabPosts is the stories posted to the page.
	NSString *chosen = [mainKind isEqualToString:@"posts"] ? @"stories" : mainKind;
	if (chosen.length && [out containsObject:chosen]){
		[out removeObject:chosen];
		[out insertObject:chosen atIndex:0];
	}
	return out;
}

NSArray *TGProfileMediaTabs(NSArray *kinds, BOOL similarChannels) {
	NSDictionary *titles = @{@"stories" : @"Stories", @"gifts" : @"Gifts",
			@"media" : @"Media", @"files" : @"Files", @"music" : @"Music",
			@"voice" : @"Voice", @"links" : @"Links", @"groups" : @"Groups",
			@"archive" : @"Archive", @"similar" : @"Similar Channels"};
	NSMutableArray *out = [NSMutableArray array];
	for (NSString *kind in kinds)
		[out addObject:@{@"title" : titles[kind], @"kind" : kind}];
	if (similarChannels)
		[out addObject:@{@"title" : titles[@"similar"], @"kind" : @"similar"}];
	return out;
}

NSString *TGProfileSelectedTabKind(NSString *stored, NSArray *tabs) {
	NSString *kind = stored;
	if ([kind isEqualToString:@"posts"])
		kind = @"stories";
	else if ([kind isEqualToString:@"gifs"])
		kind = @"media";
	for (NSDictionary *tab in tabs)
		if ([tab[@"kind"] isEqualToString:kind])
			return kind;
	return [tabs.firstObject objectForKey:@"kind"];
}

BOOL TGProfileTabIsStories(NSString *kind) {
	return [kind isEqualToString:@"stories"] || [kind isEqualToString:@"archive"];
}

BOOL TGProfileTabIsGrid(NSString *kind) {
	return [kind isEqualToString:@"media"] || TGProfileTabIsStories(kind) ||
			[kind isEqualToString:@"gifts"];
}
