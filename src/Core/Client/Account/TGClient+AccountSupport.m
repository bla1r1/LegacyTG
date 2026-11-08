#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
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





NSDictionary *TGFlattenStory(NSDictionary *story) {
	NSDictionary *content = story[@"content"];
	NSString *kind = content[@"@type"];

	// A story is a photo or a video; a video's poster frame is its thumbnail,
	// which is the only frame this device is going to show in a list anyway.
	NSNumber *fileId = nil;
	if ([kind isEqualToString:@"storyContentPhoto"]){
		NSArray *sizes = content[@"photo"][@"sizes"];
		fileId = [sizes lastObject][@"photo"][@"id"] ?: [sizes firstObject][@"photo"][@"id"];
	} else if ([kind isEqualToString:@"storyContentVideo"]){
		fileId = content[@"video"][@"thumbnail"][@"file"][@"id"];
	}

	// A grid tile draws about 105 pt on edge, so beyond roughly 220 px of
	// width every extra byte only pads a 512 MB phone's download queue (B2:
	// the grid used to ask for the largest render of every story). The
	// smallest size that still covers the tile is the list download; the
	// full-size id stays beside it for the viewer.
	NSNumber *thumbId = nil;
	if ([kind isEqualToString:@"storyContentPhoto"]){
		NSDictionary *best = nil, *smallest = nil;
		for (NSDictionary *size in content[@"photo"][@"sizes"]){
			CGFloat w = [size[@"width"] doubleValue];
			if (w <= 0)
				continue;
			if (!smallest || w < [smallest[@"width"] doubleValue])
				smallest = size;
			if (w >= 220.0f && (!best || w < [best[@"width"] doubleValue]))
				best = size;
		}
		thumbId = (best ?: smallest ?: [content[@"photo"][@"sizes"] firstObject])[@"photo"][@"id"];
	}

	// The video itself, not just its poster frame - without this a video
	// story could only ever be shown as a still. The smaller alternative is
	// preferred where the server offers one; this is a 512MB phone.
	NSNumber *videoId = nil;
	NSNumber *videoDuration = nil;
	if ([kind isEqualToString:@"storyContentVideo"]){
		NSDictionary *video = [content[@"alternative_video"] isKindOfClass:NSDictionary.class]
				? content[@"alternative_video"] : content[@"video"];
		videoId = video[@"video"][@"id"];
		videoDuration = video[@"duration"];
	}

	NSArray *captionEntities = [story[@"caption"][@"entities"] isKindOfClass:NSArray.class]
			? story[@"caption"][@"entities"] : @[];
	NSMutableDictionary *out = [@{
		@"storyId"         : story[@"id"] ?: @(0),
		@"date"            : story[@"date"] ?: @(0),
		@"caption"         : story[@"caption"][@"text"] ?: @"",
		@"captionEntities" : captionEntities,
		@"isVideo"         : @([kind isEqualToString:@"storyContentVideo"]),
		@"viewers"         : story[@"interaction_info"][@"view_count"] ?: @(0),
	} mutableCopy];
	if (fileId)
		out[@"photoId"] = fileId;
	if (thumbId)
		out[@"thumbPhotoId"] = thumbId;
	if (videoId)
		out[@"videoId"] = videoId;
	if (videoDuration)
		out[@"duration"] = videoDuration;
	return out;
}
BOOL TGProfileBirthdayIsToday(NSInteger day, NSInteger month, NSDate *now) {
	if (day <= 0 || month <= 0 || month > 12 || !now)
		return NO;
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *parts = [calendar components:NSCalendarUnitDay | NSCalendarUnitMonth
										  fromDate:now];
	return parts.day == day && parts.month == month;
}
NSString *TGProfileBirthdayText(NSInteger day, NSInteger month, NSInteger year, NSDate *now) {
	if (day <= 0 || month <= 0 || month > 12)
		return nil;
	static NSArray *months = nil;
	if (!months)
		months = @[@"", @"January", @"February", @"March", @"April", @"May", @"June",
				@"July", @"August", @"September", @"October", @"November", @"December"];
	if (TGProfileBirthdayIsToday(day, month, now))
		return @"Birthday today";
	if (year > 0){
		NSCalendar *calendar = [NSCalendar currentCalendar];
		NSInteger nowYear = [calendar components:NSCalendarUnitYear fromDate:now].year;
		NSInteger age = nowYear - year;
		// A future or impossible year reads as a date without an age, not as
		// "(-2 years old)".
		if (age >= 0)
			return [NSString stringWithFormat:@"%@ %ld, %ld (%ld years old)",
					months[month], (long)day, (long)year, (long)age];
	}
	return [NSString stringWithFormat:@"%@ %ld", months[month], (long)day];
}
NSString *TGFirstUsername(NSDictionary *user) {
	NSArray *active = user[@"usernames"][@"active_usernames"];
	if ([active isKindOfClass:NSArray.class] && active.count)
		return active[0];
	NSString *legacy = user[@"username"];
	if ([legacy isKindOfClass:NSString.class] && legacy.length)
		return legacy;
	return nil;
}
