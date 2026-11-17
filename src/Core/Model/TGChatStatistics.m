#import "TGChatStatistics.h"
#import "TGLocalization.h"
#import <math.h>

NSString *TGStatValueText(NSDictionary *value) {
	if (![value isKindOfClass:NSDictionary.class])
		return @"-";
	double now = [value[@"value"] doubleValue];
	double previous = [value[@"previous_value"] doubleValue];
	NSString *base = [NSString stringWithFormat:@"%ld", (long)llround(now)];
	double delta = now - previous;
	if (previous <= 0 || fabs(delta) < 0.5)
		return base;
	return [NSString stringWithFormat:@"%@ %@%ld (%.02f%%)", base, delta > 0 ? @"+" : @"-",
			(long)llround(fabs(delta)), fabs(delta / previous) * 100.0];
}

static NSString *TGStatCount(NSString *one, NSString *other, NSInteger count) {
	return TGLocalizedPluralValue(one, other, [NSString stringWithFormat:@"%ld", (long)count], count);
}

static NSString *TGStatUser(TGStatName name, id userId) {
	NSString *who = name ? name([userId longLongValue]) : nil;
	return who.length ? who : TGLocalized(@"Deleted Account");
}

NSArray *TGChatStatisticsRows(NSDictionary *result, TGStatName name,
		NSString *(^postText)(int64_t messageId)) {
	NSMutableArray *rows = [NSMutableArray array];
	NSString *kind = [result[@"@type"] isKindOfClass:NSString.class] ? result[@"@type"] : @"";
	[rows addObject:@{@"title" : @"Members", @"detail" : TGStatValueText(result[@"member_count"])}];
	if ([kind isEqualToString:@"chatStatisticsSupergroup"]) {
		[rows addObject:@{@"title" : @"Messages", @"detail" : TGStatValueText(result[@"message_count"])}];
		[rows addObject:@{@"title" : @"Viewers", @"detail" : TGStatValueText(result[@"viewer_count"])}];
		[rows addObject:@{@"title" : @"Senders", @"detail" : TGStatValueText(result[@"sender_count"])}];
		// GroupStatsController .topPoster / .topAdmin / .topInviter.
		for (NSDictionary *sender in result[@"top_senders"]) {
			NSInteger sent = [sender[@"sent_message_count"] integerValue];
			NSInteger chars = [sender[@"average_character_count"] integerValue];
			NSMutableArray *bits = [NSMutableArray array];
			if (sent > 0) {
				[bits addObject:TGStatCount(@"%@ message", @"%@ messages", sent)];
				if (chars > 0)
					[bits addObject:TGStatCount(@"%@ symbol per message", @"%@ symbols per message", chars)];
			}
			[rows addObject:@{@"section" : @"TOP MEMBERS", @"title" : TGStatUser(name, sender[@"user_id"]),
					@"detail" : [bits componentsJoinedByString:@", "]}];
		}
		for (NSDictionary *admin in result[@"top_administrators"]) {
			NSInteger deleted = [admin[@"deleted_message_count"] integerValue];
			NSInteger kicked = [admin[@"banned_user_count"] integerValue];
			NSInteger banned = [admin[@"restricted_user_count"] integerValue];
			NSMutableArray *bits = [NSMutableArray array];
			// Telegram's "kick" is TDLib's ban and its "ban" a restriction.
			if (deleted > 0)
				[bits addObject:TGStatCount(@"%@ deletion", @"%@ deletions", deleted)];
			if (kicked > 0)
				[bits addObject:TGStatCount(@"%@ kick", @"%@ kicks", kicked)];
			if (banned > 0)
				[bits addObject:TGStatCount(@"%@ ban", @"%@ bans", banned)];
			[rows addObject:@{@"section" : @"TOP ADMINS", @"title" : TGStatUser(name, admin[@"user_id"]),
					@"detail" : [bits componentsJoinedByString:@", "]}];
		}
		for (NSDictionary *inviter in result[@"top_inviters"]) {
			[rows addObject:@{@"section" : @"TOP INVITERS", @"title" : TGStatUser(name, inviter[@"user_id"]),
					@"detail" : TGStatCount(@"%@ invitation", @"%@ invitations",
							[inviter[@"added_member_count"] integerValue])}];
		}
	} else if ([kind isEqualToString:@"chatStatisticsChannel"]) {
		[rows addObject:@{@"title" : @"Views Per Post", @"detail" : TGStatValueText(result[@"mean_message_view_count"])}];
		[rows addObject:@{@"title" : @"Shares Per Post", @"detail" : TGStatValueText(result[@"mean_message_share_count"])}];
		[rows addObject:@{@"title" : @"Reactions Per Post", @"detail" : TGStatValueText(result[@"mean_message_reaction_count"])}];
		[rows addObject:@{@"title" : @"Views Per Story", @"detail" : TGStatValueText(result[@"mean_story_view_count"])}];
		[rows addObject:@{@"title" : @"Shares Per Story", @"detail" : TGStatValueText(result[@"mean_story_share_count"])}];
		[rows addObject:@{@"title" : @"Reactions Per Story", @"detail" : TGStatValueText(result[@"mean_story_reaction_count"])}];
		[rows addObject:@{@"title" : @"Enabled Notifications", @"detail" : [NSString stringWithFormat:@"%.0f%%",
				[result[@"enabled_notifications_percentage"] doubleValue]]}];
		// ChannelStatsController RECENT POSTS: each post or story with its views
		// and shares.
		for (NSDictionary *info in result[@"recent_interactions"]) {
			NSDictionary *object = [info[@"object_type"] isKindOfClass:NSDictionary.class] ? info[@"object_type"] : nil;
			BOOL story = [object[@"@type"] isEqualToString:@"chatStatisticsObjectTypeStory"];
			NSString *title = story ? TGLocalized(@"Story") : nil;
			if (!story && postText)
				title = postText([object[@"message_id"] longLongValue]);
			NSInteger views = [info[@"view_count"] integerValue];
			NSInteger shares = [info[@"forward_count"] integerValue];
			NSString *detail = views > 0 ? TGStatCount(@"%@ view", @"%@ views", views) : TGLocalized(@"No views");
			if (shares > 0)
				detail = [NSString stringWithFormat:@"%@, %@", detail, TGStatCount(@"%@ forward", @"%@ forwards", shares)];
			[rows addObject:@{@"section" : @"RECENT POSTS", @"title" : title.length ? title : TGLocalized(@"Message"),
					@"detail" : detail}];
		}
	}
	return rows;
}

NSArray *TGChatStatisticsPostIds(NSDictionary *result) {
	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *info in [result[@"recent_interactions"] isKindOfClass:NSArray.class] ? result[@"recent_interactions"] : @[]) {
		NSDictionary *object = [info isKindOfClass:NSDictionary.class] ? info[@"object_type"] : nil;
		if ([object[@"@type"] isEqualToString:@"chatStatisticsObjectTypeMessage"] && object[@"message_id"])
			[ids addObject:object[@"message_id"]];
	}
	return ids;
}
