//
// TGClient+Notifications.m - saved sounds and TDLib's local notification list.
//
// APNs is still the delivery path, but TDLib also keeps the groups it would
// draw. updateActiveNotifications is the only request-free way to see them,
// so the client holds that answer and lets the screen remove entries with
// removeNotification / removeNotificationGroup - the two calls that keep the
// list honest after the screen says "remove".
//
#import "TGClientInternal.h"

/// A notification is a type object; a row only needs a sentence. New messages
/// arrive whole, push messages arrive flattened by the server, and calls and
/// secret chats carry no text at all.
static NSDictionary *TGNotificationRow(NSDictionary *notification) {
	if (![notification isKindOfClass:NSDictionary.class])
		return nil;
	NSDictionary *type = [notification[@"type"] isKindOfClass:NSDictionary.class]
			? notification[@"type"] : nil;
	NSString *kind = type[@"@type"] ?: @"";
	NSString *text = @"";
	if ([kind isEqualToString:@"notificationTypeNewMessage"]){
		NSDictionary *message = type[@"message"];
		text = TGMessagePreview(message) ?: @"Message";
	} else if ([kind isEqualToString:@"notificationTypeNewPushMessage"]){
		NSString *sender = type[@"sender_name"] ?: @"";
		NSString *content = type[@"content"][@"@type"] ?: @"";
		NSString *phrase = content.length ? TGPhraseFromTypeName(content) : @"Message";
		text = sender.length ? [NSString stringWithFormat:@"%@: %@", sender, phrase]
							 : phrase;
	} else if ([kind isEqualToString:@"notificationTypeNewCall"]){
		text = @"Incoming call";
	} else if ([kind isEqualToString:@"notificationTypeNewSecretChat"]){
		text = @"New secret chat";
	}
	return @{
		@"id"       : notification[@"id"] ?: @(0),
		@"date"     : notification[@"date"] ?: @(0),
		@"isSilent" : notification[@"is_silent"] ?: @NO,
		@"kind"     : kind,
		@"text"     : text,
	};
}

static NSDictionary *TGNotificationGroupRow(TGClient *client,
											NSDictionary *group) {
	if (![group isKindOfClass:NSDictionary.class])
		return nil;
	int64_t chatId = [group[@"chat_id"] longLongValue];
	NSString *title = client.chatsById[@(chatId)][@"title"] ?: @"";
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *notification in group[@"notifications"]){
		NSDictionary *row = TGNotificationRow(notification);
		if (row)
			[rows addObject:row];
	}
	NSDictionary *groupType = [group[@"type"] isKindOfClass:NSDictionary.class]
			? group[@"type"] : nil;
	return @{
		@"id"         : group[@"id"] ?: @(0),
		@"type"       : groupType[@"@type"] ?: @"",
		@"chatId"     : @(chatId),
		@"chatTitle"  : title,
		@"totalCount" : group[@"total_count"] ?: @(rows.count),
		@"notifications" : rows,
	};
}

static NSMutableArray *TGNotificationGroupsFromAnswer(TGClient *client,
													   NSArray *groups) {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *group in groups){
		NSDictionary *row = TGNotificationGroupRow(client, group);
		if (row)
			[out addObject:row];
	}
	return out;
}

/// The same notification list in one group, with `notification` replacing the
/// row of the same id or joining at the end.
static NSMutableArray *TGNotificationsReplacing(NSArray *current,
												NSDictionary *notification) {
	NSDictionary *row = TGNotificationRow(notification);
	if (!row)
		return [current mutableCopy];
	NSMutableArray *next = [NSMutableArray array];
	BOOL replaced = NO;
	for (NSDictionary *existing in current){
		if ([existing[@"id"] isEqual:row[@"id"]]){
			[next addObject:row];
			replaced = YES;
		} else {
			[next addObject:existing];
		}
	}
	if (!replaced)
		[next addObject:row];
	return next;
}

@implementation TGClient (Notifications)

#pragma mark - saved sounds

#pragma mark - active notifications

/// TDLib is still fetching or delaying notifications; the screen keeps its
/// spinner up until both flags are off.
- (BOOL)havePendingNotifications {
	return self.haveDelayedNotifications || self.haveUnreceivedNotifications;
}

#pragma mark - update handling, called from TGClient.m

/// An update the receive loop used to mark ignored. Kept in one method so
/// the three shapes share the same list instead of three copies of it.
- (void)applyActiveNotificationUpdate:(NSDictionary *)update {
	NSString *type = update[@"@type"];
	if ([type isEqualToString:@"updateActiveNotifications"]){
		self.activeNotificationGroupsValue =
				TGNotificationGroupsFromAnswer(self, update[@"groups"]);
	} else if ([type isEqualToString:@"updateNotificationGroup"]){
		int32_t groupId = [update[@"id"] intValue];
		NSString *groupType = [update[@"type"] isKindOfClass:NSDictionary.class]
				? update[@"type"][@"@type"] : nil;
		NSMutableArray *groups = [NSMutableArray array];
		BOOL found = NO;
		for (NSDictionary *group in self.activeNotificationGroupsValue ?: @[]){
			if ([group[@"id"] intValue] != groupId){
				[groups addObject:group];
				continue;
			}
			found = YES;
			NSMutableArray *rows = [group[@"notifications"] mutableCopy];
			NSSet *removed = [NSSet setWithArray:update[@"removed_notification_ids"] ?: @[]];
			if (removed.count){
				NSMutableArray *left = [NSMutableArray array];
				for (NSDictionary *row in rows)
					if (![removed containsObject:row[@"id"]])
						[left addObject:row];
				rows = left;
			}
			for (NSDictionary *added in update[@"added_notifications"] ?: @[])
				rows = TGNotificationsReplacing(rows, added);
			NSMutableDictionary *next = [group mutableCopy];
			next[@"type"] = groupType ?: group[@"type"];
			next[@"chatId"] = update[@"chat_id"] ?: group[@"chatId"];
			next[@"totalCount"] = update[@"total_count"] ?: @(rows.count);
			next[@"notifications"] = rows;
			int64_t chatId = [next[@"chatId"] longLongValue];
			NSString *title = self.chatsById[@(chatId)][@"title"];
			if (title.length)
				next[@"chatTitle"] = title;
			[groups addObject:next];
		}
		if (!found){
			NSMutableDictionary *next = [@{
				@"id"         : @(groupId),
				@"type"       : groupType ?: @"",
				@"chatId"     : update[@"chat_id"] ?: @(0),
				@"totalCount" : update[@"total_count"] ?: @(0),
			} mutableCopy];
			NSMutableArray *rows = [NSMutableArray array];
			for (NSDictionary *added in update[@"added_notifications"] ?: @[]){
				NSDictionary *row = TGNotificationRow(added);
				if (row)
					[rows addObject:row];
			}
			next[@"notifications"] = rows;
			int64_t chatId = [next[@"chatId"] longLongValue];
			next[@"chatTitle"] = self.chatsById[@(chatId)][@"title"] ?: @"";
			[groups addObject:next];
		}
		self.activeNotificationGroupsValue = groups;
	} else if ([type isEqualToString:@"updateNotification"]){
		int32_t groupId = [update[@"notification_group_id"] intValue];
		NSMutableArray *groups = [NSMutableArray array];
		BOOL found = NO;
		for (NSDictionary *group in self.activeNotificationGroupsValue ?: @[]){
			if ([group[@"id"] intValue] != groupId){
				[groups addObject:group];
				continue;
			}
			found = YES;
			NSMutableDictionary *next = [group mutableCopy];
			next[@"notifications"] =
					TGNotificationsReplacing(group[@"notifications"],
											 update[@"notification"]);
			NSInteger total = MAX([next[@"totalCount"] integerValue],
								  (NSInteger)[next[@"notifications"] count]);
			next[@"totalCount"] = @(total);
			[groups addObject:next];
		}
		if (!found){
			NSMutableDictionary *next = [@{
				@"id"         : @(groupId),
				@"type"       : @"",
				@"chatId"     : @(0),
				@"chatTitle"  : @"",
				@"totalCount" : @(1),
			} mutableCopy];
			next[@"notifications"] =
					TGNotificationsReplacing(@[], update[@"notification"]);
			[groups addObject:next];
		}
		self.activeNotificationGroupsValue = groups;
	} else {
		return;
	}
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGActiveNotificationsChangedNotification
						  object:self];
}

@end

// vim:ft=objc
