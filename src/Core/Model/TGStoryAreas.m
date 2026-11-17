#import "TGStoryAreas.h"
#import <math.h>

static double TGAreaPercent(NSDictionary *position, NSString *key) {
	id value = position[key];
	return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] / 100.0 : 0;
}

NSArray *TGStoryAreasFromTD(NSArray *areas) {
	if (![areas isKindOfClass:NSArray.class])
		return @[];
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *area in areas) {
		if (![area isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *position = [area[@"position"] isKindOfClass:NSDictionary.class] ? area[@"position"] : nil;
		NSDictionary *type = [area[@"type"] isKindOfClass:NSDictionary.class] ? area[@"type"] : nil;
		if (!position || !type)
			continue;
		NSMutableDictionary *row = [@{
			@"x"        : @(TGAreaPercent(position, @"x_percentage")),
			@"y"        : @(TGAreaPercent(position, @"y_percentage")),
			@"w"        : @(TGAreaPercent(position, @"width_percentage")),
			@"h"        : @(TGAreaPercent(position, @"height_percentage")),
			@"rotation" : position[@"rotation_angle"] ?: @0,
		} mutableCopy];
		NSString *kind = type[@"@type"];
		// A location opens official's location story search and a reaction
		// widget is tapped through its own view; neither is built here, so
		// only links and channel messages answer a tap.
		if ([kind isEqualToString:@"storyAreaTypeLink"] && [type[@"url"] isKindOfClass:NSString.class]) {
			row[@"kind"] = @"link";
			row[@"url"] = type[@"url"];
		} else if ([kind isEqualToString:@"storyAreaTypeMessage"]) {
			row[@"kind"] = @"message";
			row[@"chatId"] = type[@"chat_id"] ?: @0;
			row[@"messageId"] = type[@"message_id"] ?: @0;
		} else {
			continue;
		}
		[out addObject:row];
	}
	return out;
}

NSDictionary *TGStoryAreaAt(NSArray *areas, CGPoint point, CGRect picture) {
	if (picture.size.width <= 0 || picture.size.height <= 0)
		return nil;
	// Official's hit test (StoryItemSetContainerComponent tapGesture): the
	// point turned back by the area's rotation about its centre, inside the
	// area grown by a tenth.
	for (NSDictionary *area in [areas reverseObjectEnumerator]) {
		double cx = picture.origin.x + [area[@"x"] doubleValue] * picture.size.width;
		double cy = picture.origin.y + [area[@"y"] doubleValue] * picture.size.height;
		double tx = point.x - cx, ty = point.y - cy;
		double rad = -[area[@"rotation"] doubleValue] * M_PI / 180.0;
		double rx = tx * cos(rad) - ty * sin(rad);
		double ry = tx * sin(rad) + ty * cos(rad);
		if (fabs(rx) <= [area[@"w"] doubleValue] * picture.size.width / 2.0 * 1.1 &&
				fabs(ry) <= [area[@"h"] doubleValue] * picture.size.height / 2.0 * 1.1)
			return area;
	}
	return nil;
}

NSArray *TGStoriesPinnedFirst(NSArray *stories, NSArray *pinnedIds) {
	if (![stories isKindOfClass:NSArray.class])
		return @[];
	if (![pinnedIds isKindOfClass:NSArray.class] || !pinnedIds.count)
		return stories;
	NSMutableArray *pinned = [NSMutableArray array];
	NSMutableArray *rest = [NSMutableArray array];
	NSMutableDictionary *byId = [NSMutableDictionary dictionary];
	for (NSDictionary *story in stories) {
		if (![story isKindOfClass:NSDictionary.class])
			continue;
		NSNumber *storyId = story[@"storyId"];
		if ([pinnedIds containsObject:storyId ?: @0])
			byId[storyId] = story;
		else
			[rest addObject:story];
	}
	for (NSNumber *storyId in pinnedIds) {
		NSDictionary *story = byId[storyId];
		if (!story)
			continue;
		NSMutableDictionary *marked = [story mutableCopy];
		marked[@"isPinned"] = @YES;
		[pinned addObject:marked];
	}
	return [pinned arrayByAddingObjectsFromArray:rest];
}
