#import "TGVideoAvatar.h"

BOOL TGVideoAvatarAnnounced(NSDictionary *photo) {
	return [photo isKindOfClass:NSDictionary.class] && [photo[@"has_animation"] boolValue];
}

NSDictionary *TGVideoAvatarFrom(NSDictionary *photo) {
	if (![photo isKindOfClass:NSDictionary.class])
		return nil;
	NSDictionary *small = [photo[@"small_animation"] isKindOfClass:NSDictionary.class]
			? photo[@"small_animation"] : nil;
	NSDictionary *large = [photo[@"animation"] isKindOfClass:NSDictionary.class]
			? photo[@"animation"] : nil;
	NSDictionary *clip = small ?: large;
	id fileId = clip[@"file"][@"id"];
	if (![fileId isKindOfClass:NSNumber.class] || ![fileId longLongValue])
		return nil;
	double frame = [(large ?: small)[@"main_frame_timestamp"] doubleValue];
	return @{@"fileId" : fileId, @"frame" : @(MAX(frame, 0.0))};
}

static NSArray *TGFillColours(NSDictionary *fill) {
	NSString *kind = [fill isKindOfClass:NSDictionary.class] ? fill[@"@type"] : nil;
	if ([kind isEqualToString:@"backgroundFillSolid"])
		return fill[@"color"] ? @[fill[@"color"]] : @[];
	if ([kind isEqualToString:@"backgroundFillGradient"])
		return (fill[@"top_color"] && fill[@"bottom_color"])
				? @[fill[@"top_color"], fill[@"bottom_color"]] : @[];
	if ([kind isEqualToString:@"backgroundFillFreeformGradient"])
		return [fill[@"colors"] isKindOfClass:NSArray.class] ? fill[@"colors"] : @[];
	return @[];
}

NSDictionary *TGStickerAvatarFrom(NSDictionary *photo) {
	NSDictionary *sticker = [photo isKindOfClass:NSDictionary.class] &&
			[photo[@"sticker"] isKindOfClass:NSDictionary.class] ? photo[@"sticker"] : nil;
	NSDictionary *type = [sticker[@"type"] isKindOfClass:NSDictionary.class] ? sticker[@"type"] : nil;
	if (![type[@"@type"] isEqualToString:@"chatPhotoStickerTypeRegularOrMask"])
		return nil;
	long long setId = [type[@"sticker_set_id"] longLongValue];
	long long stickerId = [type[@"sticker_id"] longLongValue];
	if (!setId || !stickerId)
		return nil;
	return @{@"setId" : @(setId), @"stickerId" : @(stickerId),
			 @"colours" : TGFillColours(sticker[@"background_fill"])};
}

NSDictionary *TGStickerAvatarPick(NSArray *stickers, int64_t stickerId) {
	if (![stickers isKindOfClass:NSArray.class])
		return nil;
	for (NSDictionary *sticker in stickers) {
		if (![sticker isKindOfClass:NSDictionary.class] || [sticker[@"id"] longLongValue] != stickerId)
			continue;
		id fileId = sticker[@"sticker"][@"id"];
		if (![fileId isKindOfClass:NSNumber.class])
			return nil;
		NSString *format = sticker[@"format"][@"@type"];
		NSString *kind = [format isEqualToString:@"stickerFormatTgs"] ? @"tgs"
				: [format isEqualToString:@"stickerFormatWebm"] ? @"webm" : @"webp";
		return @{@"fileId" : fileId, @"format" : kind};
	}
	return nil;
}
