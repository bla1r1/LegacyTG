#import "TGClient+StoriesSupport.h"
#import "TGClientInternal.h"

NSDictionary *TGStoryDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

NSArray *TGStoryArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : @[];
}

NSString *TGStoryErrorText(NSDictionary *result) {
	NSString *message = result[@"message"];
	return [message isKindOfClass:NSString.class]
			? message : @"Telegram refused that.";
}

/// TDLib answers every request with @"@type" : @"ok" on success. A few answer
/// an object; those callers check for "error" directly.
BOOL TGStorySucceeded(NSDictionary *result) {
	return ![result[@"@type"] isEqualToString:@"error"];
}

/// A photo's largest size, or a thumbnail's file. TDLib puts the usable file
/// in a different place for a photo, a chat photo and a video, and every
/// caller here just wants the one id to hand to downloadFile.
NSNumber *TGStoryPhotoFileId(NSDictionary *photo) {
	if (![photo isKindOfClass:NSDictionary.class])
		return nil;
	NSArray *sizes = photo[@"sizes"];
	if ([sizes isKindOfClass:NSArray.class] && sizes.count){
		NSDictionary *largest = nil;
		for (NSDictionary *size in sizes){
			if (![size isKindOfClass:NSDictionary.class])
				continue;
			if (!largest ||
				[size[@"width"] doubleValue] > [largest[@"width"] doubleValue])
				largest = size;
		}
		NSNumber *fileId = largest[@"photo"][@"id"];
		if ([fileId isKindOfClass:NSNumber.class])
			return fileId;
	}
	NSNumber *fileId = photo[@"file"][@"id"];
	return [fileId isKindOfClass:NSNumber.class] ? fileId : nil;
}

NSNumber *TGStoryChatPhotoFileId(NSDictionary *chat) {
	NSDictionary *photo = chat[@"photo"];
	NSNumber *fileId = photo[@"small"][@"id"];
	if (![fileId isKindOfClass:NSNumber.class])
		fileId = photo[@"big"][@"id"];
	return [fileId isKindOfClass:NSNumber.class] ? fileId : nil;
}

/// A video's poster frame is what a list can draw without a decoder.
NSNumber *TGStoryVideoThumbFileId(NSDictionary *video) {
	NSNumber *fileId = video[@"thumbnail"][@"file"][@"id"];
	if ([fileId isKindOfClass:NSNumber.class])
		return fileId;
	return TGStoryPhotoFileId(video);
}

/// One sender, as every screen in this file spells it.
NSDictionary *TGStoryFlattenSender(NSDictionary *sender) {
	if (![sender isKindOfClass:NSDictionary.class])
		return @{@"kind" : @"user", @"id" : @(0), @"name" : @""};
	if ([sender[@"@type"] isEqualToString:@"messageSenderChat"]){
		int64_t chatId = [sender[@"chat_id"] longLongValue];
		return @{@"kind" : @"chat", @"id" : @(chatId),
				 @"name" : [[TGClient shared] titleForChat:chatId] ?: @""};
	}
	int64_t userId = [sender[@"user_id"] longLongValue];
	return @{@"kind" : @"user", @"id" : @(userId),
			 @"name" : [[TGClient shared] nameForUserId:userId] ?: @""};
}

/// The privacy filter in the words a list row shows, and back again. TDLib
/// sends five types; this client offers the four a story can be posted with.
NSString *TGStoryPrivacyName(NSDictionary *privacy) {
	NSString *type = privacy[@"@type"];
	if ([type isEqualToString:@"storyPrivacySettingsEveryone"])
		return @"everyone";
	if ([type isEqualToString:@"storyPrivacySettingsContacts"])
		return @"contacts";
	if ([type isEqualToString:@"storyPrivacySettingsCloseFriends"])
		return @"closeFriends";
	if ([type isEqualToString:@"storyPrivacySettingsSelectedUsers"])
		return @"selected";
	return @"";
}

NSDictionary *TGStoryPrivacyObject(NSString *privacy, NSArray *userIds) {
	NSArray *ids = [userIds isKindOfClass:NSArray.class] ? userIds : @[];
	if ([privacy isEqualToString:@"contacts"])
		return @{@"@type" : @"storyPrivacySettingsContacts",
				 @"except_user_ids" : ids};
	if ([privacy isEqualToString:@"closeFriends"])
		return @{@"@type" : @"storyPrivacySettingsCloseFriends"};
	if ([privacy isEqualToString:@"selected"])
		return @{@"@type" : @"storyPrivacySettingsSelectedUsers",
				 @"user_ids" : ids};
	return @{@"@type" : @"storyPrivacySettingsEveryone",
			 @"except_user_ids" : ids};
}

/// One reaction as TDLib wants it. nil means "remove", which TDLib spells as
/// a null reaction_type rather than an empty emoji.
id TGStoryReactionObject(NSString *reaction) {
	if (![reaction isKindOfClass:NSString.class] || !reaction.length)
		return [NSNull null];
	if ([reaction hasPrefix:@"custom:"]){
		NSString *identifier = [reaction substringFromIndex:@"custom:".length];
		long long customId = identifier.longLongValue;
		if (customId > 0)
			return @{@"@type" : @"reactionTypeCustomEmoji",
					 @"custom_emoji_id" : @(customId)};
	}
	return @{@"@type" : @"reactionTypeEmoji", @"emoji" : reaction};
}

NSArray *TGStoryReactionEmojis(NSArray *reactions) {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *reaction in TGStoryArray(reactions)){
		NSDictionary *type = TGStoryDict(reaction[@"type"]);
		if ([type[@"@type"] isEqualToString:@"reactionTypeEmoji"] &&
			[type[@"emoji"] isKindOfClass:NSString.class])
			[out addObject:type[@"emoji"]];
		else if ([type[@"@type"] isEqualToString:@"reactionTypeCustomEmoji"] &&
				 type[@"custom_emoji_id"])
			[out addObject:[NSString stringWithFormat:@"custom:%lld",
					[type[@"custom_emoji_id"] longLongValue]]];
	}
	return out;
}

/// TDLib's statistical graph is either data with a JSON payload, a token to
/// poll, or a sentence saying why there is nothing. The list draws lines and
/// never follows the token: a graph that arrives after the page closed has
/// nowhere to go.
NSDictionary *TGStoryGraph(NSDictionary *graph) {
	if (![graph isKindOfClass:NSDictionary.class])
		return @{@"kind" : @"none", @"lines" : @[]};
	NSString *type = graph[@"@type"];
	if ([type isEqualToString:@"statisticalGraphData"]){
		NSString *raw = graph[@"json_data"];
		if (![raw isKindOfClass:NSString.class])
			raw = @"";
		id parsed = nil;
		NSData *data = [raw dataUsingEncoding:NSUTF8StringEncoding];
		if (data.length)
			parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		NSMutableArray *lines = [NSMutableArray array];
		if ([parsed isKindOfClass:NSDictionary.class]){
			NSArray *points = parsed[@"points"];
			if ([points isKindOfClass:NSArray.class] && points.count){
				double peak = 0;
				for (NSDictionary *point in points){
					double y = [point[@"y"] doubleValue];
					if (fabs(y) > peak)
						peak = fabs(y);
				}
				[lines addObject:[NSString stringWithFormat:@"%lu points",
						(unsigned long)points.count]];
				NSUInteger shown = MIN(points.count, (NSUInteger)60);
				for (NSUInteger i = 0; i < shown; i++){
					NSDictionary *point = points[i];
					double x = [point[@"x"] doubleValue];
					double y = [point[@"y"] doubleValue];
					NSUInteger bars = peak > 0
							? (NSUInteger)lround((fabs(y) / peak) * 20.0) : 0;
					NSMutableString *bar = [NSMutableString string];
					for (NSUInteger b = 0; b < bars; b++)
						[bar appendString:@"#"];
					[lines addObject:[NSString stringWithFormat:@"%lld %@ %g",
							(long long)x, bar, y]];
				}
			}
		}
		return @{@"kind" : @"data", @"lines" : lines, @"raw" : raw};
	}
	if ([type isEqualToString:@"statisticalGraphAsync"])
		return @{@"kind" : @"async",
				 @"token" : graph[@"token"] ?: @"",
				 @"lines" : @[@"Telegram is preparing this graph."]};
	if ([type isEqualToString:@"statisticalGraphError"])
		return @{@"kind" : @"error",
				 @"error" : graph[@"error"] ?: @"No statistics.",
				 @"lines" : @[graph[@"error"] ?: @"No statistics."]};
	return @{@"kind" : @"none", @"lines" : @[]};
}

/// One full story, flattened. Every screen in this file reads the same keys,
/// so a story opened from the strip, from an album or from a public search
/// draws the same way.
NSDictionary *TGStoryFlatten(NSDictionary *story) {
	if (![story isKindOfClass:NSDictionary.class])
		return @{};
	NSDictionary *content = TGStoryDict(story[@"content"]);
	NSString *kind = content[@"@type"];

	NSNumber *photoId = nil, *thumbPhotoId = nil, *videoId = nil;
	double duration = 0;
	NSString *contentKind = @"photo";
	if ([kind isEqualToString:@"storyContentPhoto"]){
		photoId = TGStoryPhotoFileId(content[@"photo"]);
		thumbPhotoId = photoId;
	} else if ([kind isEqualToString:@"storyContentVideo"]){
		contentKind = @"video";
		NSDictionary *video = TGStoryDict(content[@"alternative_video"]);
		if (!video.count)
			video = TGStoryDict(content[@"video"]);
		videoId = TGStoryDict(video[@"video"])[@"id"];
		thumbPhotoId = TGStoryVideoThumbFileId(video);
		photoId = thumbPhotoId;
		duration = [video[@"duration"] doubleValue];
	} else if ([kind isEqualToString:@"storyContentLive"]){
		contentKind = @"live";
	}

	NSDictionary *interactions = TGStoryDict(story[@"interaction_info"]);
	NSDictionary *repost = TGStoryDict(story[@"repost_info"]);
	NSDictionary *origin = TGStoryDict(repost[@"origin"]);
	NSString *chosen = TGStoryReactionEmojis(@[@{@"type" :
			TGStoryDict(story[@"chosen_reaction_type"])}]).firstObject ?: @"";
	NSArray *captionEntities = [TGStoryDict(story[@"caption"])[@"entities"] isKindOfClass:NSArray.class]
			? TGStoryDict(story[@"caption"])[@"entities"] : @[];
	NSMutableDictionary *out = [@{
		@"storyId"         : story[@"id"] ?: @(0),
		@"chatId"          : story[@"poster_chat_id"] ?: @(0),
		@"posterKind"      : TGStoryDict(story[@"poster_id"])[@"@type"] ?: @"",
		@"date"            : story[@"date"] ?: @(0),
		@"caption"         : TGStoryDict(story[@"caption"])[@"text"] ?: @"",
		@"captionEntities" : captionEntities,
		@"contentKind"     : contentKind,
		@"isVideo"        : @([contentKind isEqualToString:@"video"]),
		@"isLive"         : @([contentKind isEqualToString:@"live"]),
		@"groupCallId"    : content[@"group_call_id"] ?: @(0),
		@"isRtmp"         : content[@"is_rtmp_stream"] ?: @NO,
		@"duration"       : @(duration),
		@"viewers"        : interactions[@"view_count"] ?: @(0),
		@"forwards"       : interactions[@"forward_count"] ?: @(0),
		@"reactions"      : interactions[@"reaction_count"] ?: @(0),
		@"chosenReaction" : chosen,
		@"isPostedToChatPage" : story[@"is_posted_to_chat_page"] ?: @NO,
		@"isBeingPosted" : story[@"is_being_posted"] ?: @NO,
		@"isBeingEdited" : story[@"is_being_edited"] ?: @NO,
		@"isEdited"      : story[@"is_edited"] ?: @NO,
		@"canBeDeleted"  : story[@"can_be_deleted"] ?: @NO,
		@"canBeEdited"   : story[@"can_be_edited"] ?: @NO,
		@"canBeForwarded": story[@"can_be_forwarded"] ?: @NO,
		@"canBeReplied"  : story[@"can_be_replied"] ?: @NO,
		@"canBeAddedToAlbum" : story[@"can_be_added_to_album"] ?: @NO,
		@"canSetPrivacySettings" : story[@"can_set_privacy_settings"] ?: @NO,
		@"canToggleIsPostedToChatPage" : story[@"can_toggle_is_posted_to_chat_page"] ?: @NO,
		@"canGetStatistics" : story[@"can_get_statistics"] ?: @NO,
		@"canGetInteractions" : story[@"can_get_interactions"] ?: @NO,
		@"hasExpiredViewers" : story[@"has_expired_viewers"] ?: @NO,
		@"privacy"       : TGStoryPrivacyName(TGStoryDict(story[@"privacy_settings"])),
		@"albumIds"      : TGStoryArray(story[@"album_ids"]),
	} mutableCopy];
	if ([photoId isKindOfClass:NSNumber.class])
		out[@"photoId"] = photoId;
	if ([thumbPhotoId isKindOfClass:NSNumber.class])
		out[@"thumbPhotoId"] = thumbPhotoId;
	if ([videoId isKindOfClass:NSNumber.class])
		out[@"videoId"] = videoId;
	if ([repost isKindOfClass:NSDictionary.class]){
		if ([origin[@"@type"] isEqualToString:@"storyOriginPublicStory"])
			out[@"repostedFrom"] = @{@"chatId" : origin[@"chat_id"] ?: @(0),
									  @"storyId" : origin[@"story_id"] ?: @(0)};
		else if ([origin[@"poster_name"] isKindOfClass:NSString.class])
			out[@"repostedFrom"] = @{@"name" : origin[@"poster_name"]};
	}
	out[@"title"] = [[TGClient shared] titleForChat:[story[@"poster_chat_id"] longLongValue]] ?: @"";
	return out;
}

NSDictionary *TGStoryFlattenInfo(NSDictionary *info, NSDictionary *active) {
	if (![info isKindOfClass:NSDictionary.class])
		return @{};
	return @{
		@"storyId"   : info[@"story_id"] ?: @(0),
		@"date"      : info[@"date"] ?: @(0),
		@"isLive"    : info[@"is_live"] ?: @NO,
		@"closeFriends" : info[@"is_for_close_friends"] ?: @NO,
		@"chatId"    : active[@"chat_id"] ?: @(0),
	};
}

NSDictionary *TGStoryFlattenAlbum(NSDictionary *album) {
	if (![album isKindOfClass:NSDictionary.class])
		return @{};
	NSMutableDictionary *out = [@{
		@"albumId" : album[@"id"] ?: @(0),
		@"name"    : album[@"name"] ?: @"",
	} mutableCopy];
	NSNumber *photoId = TGStoryPhotoFileId(album[@"photo_icon"]);
	NSNumber *videoId = TGStoryVideoThumbFileId(album[@"video_icon"]);
	if (photoId)
		out[@"photoFileId"] = photoId;
	if (videoId)
		out[@"videoFileId"] = videoId;
	return out;
}

NSArray *TGStoryFlattenStoryList(NSDictionary *result) {
	NSArray *stories = result[@"stories"];
	if (![stories isKindOfClass:NSArray.class])
		return @[];
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *story in stories)
		if ([story isKindOfClass:NSDictionary.class] &&
			[story[@"@type"] isEqualToString:@"story"])
			[out addObject:TGStoryFlatten(story)];
	return out;
}
