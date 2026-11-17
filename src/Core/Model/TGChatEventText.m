#import "TGChatEventText.h"
#import "TGLocalization.h"
#import "TGMessageFlatten.h"

static NSString *TGEString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

/// "30 seconds", "5 minutes", "1 hour", "7 days": slow mode and the
/// auto-delete timer in the line.
static NSString *TGEDuration(NSInteger seconds) {
	if (seconds % 86400 == 0)
		return TGLocalizedPlural(@"%d day", @"%d days", seconds / 86400);
	if (seconds % 3600 == 0)
		return TGLocalizedPlural(@"%d hour", @"%d hours", seconds / 3600);
	if (seconds % 60 == 0)
		return TGLocalizedPlural(@"%d minute", @"%d minutes", seconds / 60);
	return TGLocalizedPlural(@"%d second", @"%d seconds", seconds);
}

static NSString *TGEMessageText(NSDictionary *message) {
	NSDictionary *content = [message isKindOfClass:NSDictionary.class] ? message[@"content"] : nil;
	id text = content[@"text"] ?: content[@"caption"];
	return [text isKindOfClass:NSDictionary.class] ? TGEString(text[@"text"]) : @"";
}

static BOOL TGEIsCaption(NSDictionary *message) {
	NSDictionary *content = [message isKindOfClass:NSDictionary.class] ? message[@"content"] : nil;
	return [content isKindOfClass:NSDictionary.class] && !content[@"text"] && content[@"caption"];
}

static NSString *TGETopic(NSDictionary *info) {
	return [info isKindOfClass:NSDictionary.class] ? TGEString(info[@"name"]) : @"";
}

/// TDLib splits media six ways; official's admin log has one Send Media line.
static BOOL TGEPermission(NSDictionary *p, NSString *key) {
	if (![p isKindOfClass:NSDictionary.class])
		return NO;
	if (![key isEqualToString:@"media"])
		return [p[key] boolValue];
	for (NSString *k in @[@"can_send_audios", @"can_send_documents", @"can_send_photos",
			@"can_send_videos", @"can_send_video_notes", @"can_send_voice_notes"])
		if ([p[k] boolValue])
			return YES;
	return NO;
}

/// The permissions official lists, in its order, under their admin-log names.
static NSString *TGEPermissionChanges(NSDictionary *oldP, NSDictionary *newP) {
	static NSString *const keys[] = {@"can_send_basic_messages", @"media",
		@"can_send_other_messages", @"can_add_link_previews", @"can_send_polls",
		@"can_react_to_messages", @"can_change_info", @"can_invite_users",
		@"can_pin_messages", @"can_create_topics"};
	static NSString *const names[] = {@"Send Messages", @"Send Media", @"Send Stickers & GIFs",
		@"Embed Links", @"Send Polls", @"Send Reactions", @"Change Info", @"Add Members",
		@"Pin Messages", @"Manage Topics"};
	NSMutableArray *lines = [NSMutableArray array];
	for (int i = 0; i < 10; i++){
		BOOL before = TGEPermission(oldP, keys[i]), after = TGEPermission(newP, keys[i]);
		if (before != after)
			[lines addObject:[NSString stringWithFormat:@"%@%@", after ? @"+" : @"-", TGLocalized(names[i])]];
	}
	return [lines componentsJoinedByString:@"\n"];
}

static BOOL TGEIsAdmin(NSDictionary *status) {
	NSString *kind = [status isKindOfClass:NSDictionary.class] ? status[@"@type"] : nil;
	return [kind isEqualToString:@"chatMemberStatusAdministrator"] ||
			[kind isEqualToString:@"chatMemberStatusCreator"];
}

static BOOL TGEIsBanned(NSDictionary *status) {
	return [status isKindOfClass:NSDictionary.class] &&
			[status[@"@type"] isEqualToString:@"chatMemberStatusBanned"];
}

/// Switches and the voice chat events: one official sentence for each side.
static NSString *TGEToggleLine(NSString *kind, NSDictionary *action, NSString *who,
		NSString *(^person)(id)) {
	static NSDictionary *toggles;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		toggles = @{
			@"chatEventInvitesToggled" : @[@"can_invite_users", @"%@ enabled group invites", @"%@ disabled group invites"],
			@"chatEventSignMessagesToggled" : @[@"sign_messages", @"%@ enabled signatures", @"%@ disabled signatures"],
			@"chatEventShowMessageSenderToggled" : @[@"show_message_sender", @"%@ enabled admin profiles", @"%@ disabled admin profiles"],
			@"chatEventHasProtectedContentToggled" : @[@"has_protected_content", @"%@ restricted message forwarding", @"%@ allowed message forwarding"],
			@"chatEventIsAllHistoryAvailableToggled" : @[@"is_all_history_available",
				@"%@ made the group history visible for new members", @"%@ made the group history hidden from new members"],
			@"chatEventIsForumToggled" : @[@"is_forum", @"%1$@ enabled topics", @"%1$@ disabled topics"],
			@"chatEventHasAggressiveAntiSpamEnabledToggled" : @[@"has_aggressive_anti_spam_enabled",
				@"%1$@ enabled anti-spam", @"%1$@ disabled anti-spam"],
			@"chatEventAutomaticTranslationToggled" : @[@"has_automatic_translation",
				@"%@ enabled autotranslation of messages", @"%@ disabled autotranslation of messages"],
			@"chatEventVideoChatMuteNewParticipantsToggled" : @[@"mute_new_participants",
				@"%1$@ muted new members", @"%1$@ allowed new members to speak"],
		};
	});
	NSArray *toggle = toggles[kind];
	if (toggle)
		return TGLocalizedFormat([action[toggle[0]] boolValue] ? toggle[1] : toggle[2], who);

	if ([kind isEqualToString:@"chatEventMemberInvited"])
		return [NSString stringWithFormat:@"%@ %@", who,
				TGLocalizedFormat(@"invited %1$@", person(action[@"user_id"]))];
	if ([kind isEqualToString:@"chatEventMemberJoinedByRequest"]){
		NSString *approver = person(action[@"approver_user_id"]);
		NSString *link = TGEString([action[@"invite_link"] isKindOfClass:NSDictionary.class]
				? action[@"invite_link"][@"invite_link"] : nil);
		return link.length
				? TGLocalizedFormat(@"%1$@ joined via invite link %2$@, approved by %3$@", who, link, approver)
				: TGLocalizedFormat(@"%1$@ joined via public request, approved by %2$@", who, approver);
	}
	NSDictionary *participant = action[@"participant_id"];
	id participantId = [participant isKindOfClass:NSDictionary.class]
			? (participant[@"user_id"] ?: participant[@"chat_id"]) : nil;
	if ([kind isEqualToString:@"chatEventVideoChatParticipantIsMutedToggled"])
		return [action[@"is_muted"] boolValue]
				? TGLocalizedFormat(@"%1$@ muted %2$@", who, person(participantId))
				: TGLocalizedFormat(@"%1$@ unmuted %2$@", who, person(participantId));
	if ([kind isEqualToString:@"chatEventVideoChatParticipantVolumeLevelChanged"]){
		// TDLib's volume is 1..20000, 10000 being 100%.
		NSString *level = [NSString stringWithFormat:@"%ld%%", (long)([action[@"volume_level"] integerValue] / 100)];
		return TGLocalizedFormat(@"%1$@ changed %2$@ volume to %3$@", who, person(participantId), level);
	}
	return nil;
}

NSDictionary *TGChatEventLine(NSDictionary *action, NSString *actor, BOOL isChannel,
		NSString *(^name)(int64_t userId)) {
	NSString *kind = [action isKindOfClass:NSDictionary.class] ? TGEString(action[@"@type"]) : @"";
	NSString *who = actor ?: @"";
	NSString *title = nil, *detail = @"";
	NSDictionary *swatch = nil;
	NSString *(^person)(id) = ^NSString *(id userId){
		return name ? (name([userId longLongValue]) ?: @"") : @"";
	};

	if ([kind isEqualToString:@"chatEventTitleChanged"]){
		title = isChannel ? TGLocalizedFormat(@"Channel renamed to \"%@\" ", TGEString(action[@"new_title"]))
				: TGLocalizedFormat(@"%@ changed group name to \"%@\" ", who, TGEString(action[@"new_title"]));
		title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	} else if ([kind isEqualToString:@"chatEventDescriptionChanged"]){
		title = isChannel ? TGLocalizedFormat(@"%@ edited channel description", who)
				: TGLocalizedFormat(@"%@ edited group description", who);
		NSString *was = TGEString(action[@"old_description"]);
		detail = TGEString(action[@"new_description"]);
		if (was.length)
			detail = [NSString stringWithFormat:@"%@\n%@: %@", detail, TGLocalized(@"Previous description"), was];
	} else if ([kind isEqualToString:@"chatEventUsernameChanged"]){
		NSString *now = TGEString(action[@"new_username"]), *was = TGEString(action[@"old_username"]);
		title = now.length
				? (isChannel ? TGLocalizedFormat(@"%@ changed channel link:", who) : TGLocalizedFormat(@"%@ changed group link:", who))
				: (isChannel ? TGLocalizedFormat(@"%@ removed channel link", who) : TGLocalizedFormat(@"%@ removed group link", who));
		detail = now.length ? [@"t.me/" stringByAppendingString:now] : @"";
		if (was.length)
			detail = [NSString stringWithFormat:@"%@%@%@: t.me/%@", detail, detail.length ? @"\n" : @"",
					TGLocalized(@"Previous link"), was];
	} else if ([kind isEqualToString:@"chatEventActiveUsernamesChanged"]){
		title = isChannel ? TGLocalizedFormat(@"%@ changed channel links:", who)
				: TGLocalizedFormat(@"%@ changed group links:", who);
		NSArray *now = [action[@"new_usernames"] isKindOfClass:NSArray.class] ? action[@"new_usernames"] : @[];
		NSArray *was = [action[@"old_usernames"] isKindOfClass:NSArray.class] ? action[@"old_usernames"] : @[];
		detail = [NSString stringWithFormat:@"%@\n%@: %@", [now componentsJoinedByString:@", "],
				TGLocalized(@"Previous links"), [was componentsJoinedByString:@", "]];
	} else if ([kind isEqualToString:@"chatEventPhotoChanged"]){
		BOOL removed = ![action[@"new_photo"] isKindOfClass:NSDictionary.class];
		title = isChannel ? (removed ? TGLocalized(@"Channel photo removed") : TGLocalized(@"Channel photo updated"))
				: (removed ? TGLocalizedFormat(@"%@ removed group photo", who) : TGLocalizedFormat(@"%@ changed group photo", who));
	} else if ([kind isEqualToString:@"chatEventPermissionsChanged"]){
		title = [NSString stringWithFormat:@"%@ %@", who, TGLocalized(@"changed default permissions")];
		detail = TGEPermissionChanges(action[@"old_permissions"], action[@"new_permissions"]);
	} else if ([kind isEqualToString:@"chatEventSlowModeDelayChanged"]){
		NSInteger now = [action[@"new_slow_mode_delay"] integerValue];
		title = now > 0 ? TGLocalizedFormat(@"%1$@ set slowmode to %2$@", who, TGEDuration(now))
				: TGLocalizedFormat(@"%@ disabled slowmode", who);
	} else if ([kind isEqualToString:@"chatEventMessageAutoDeleteTimeChanged"]){
		NSInteger now = [action[@"new_message_auto_delete_time"] integerValue];
		title = now > 0 ? TGLocalizedFormat(@"%1$@ set auto-remove timer to %2$@", who, TGEDuration(now))
				: TGLocalizedFormat(@"%1$@ disabled auto-remove timer", who);
	} else if ([kind isEqualToString:@"chatEventMessageEdited"]){
		BOOL caption = TGEIsCaption(action[@"new_message"]);
		title = caption ? TGLocalizedFormat(@"%@ edited caption:", who) : TGLocalizedFormat(@"%@ edited message:", who);
		NSString *was = TGEMessageText(action[@"old_message"]);
		detail = TGEMessageText(action[@"new_message"]);
		if (was.length)
			detail = [NSString stringWithFormat:@"%@\n%@: %@", detail,
					caption ? TGLocalized(@"Original caption") : TGLocalized(@"Original message"), was];
	} else if ([kind isEqualToString:@"chatEventMessageDeleted"]){
		title = TGLocalizedFormat(@"%@ deleted message:", who);
		detail = TGEMessageText(action[@"message"]);
	} else if ([kind isEqualToString:@"chatEventMessagePinned"]){
		title = TGLocalizedFormat(@"%@ pinned message:", who);
		detail = TGEMessageText(action[@"message"]);
	} else if ([kind isEqualToString:@"chatEventMessageUnpinned"]){
		title = TGLocalizedFormat(@"%@ unpinned message:", who);
		detail = TGEMessageText(action[@"message"]);
	} else if ([kind isEqualToString:@"chatEventPollStopped"]){
		title = TGLocalizedFormat(@"%@ stopped poll", who);
	} else if ([kind isEqualToString:@"chatEventMemberPromoted"]){
		NSString *target = person(action[@"user_id"]);
		BOOL was = TGEIsAdmin(action[@"old_status"]), now = TGEIsAdmin(action[@"new_status"]);
		NSString *what = (!was && now) ? TGLocalizedFormat(@"promoted %1$@", target)
				: (was && !now) ? TGLocalizedFormat(@"demoted %1$@", target)
				: TGLocalizedFormat(@"changed privileges for %1$@", target);
		title = [NSString stringWithFormat:@"%@ %@", who, what];
	} else if ([kind isEqualToString:@"chatEventMemberRestricted"]){
		NSDictionary *member = action[@"member_id"];
		NSString *target = person(member[@"user_id"] ?: member[@"chat_id"]);
		BOOL was = TGEIsBanned(action[@"old_status"]), now = TGEIsBanned(action[@"new_status"]);
		NSString *what = now ? TGLocalizedFormat(@"banned %1$@", target)
				: was ? TGLocalizedFormat(@"unbanned %1$@", target)
				: TGLocalizedFormat(@"changed restrictions for %1$@", target);
		title = [NSString stringWithFormat:@"%@ %@", who, what];
	} else if ([kind isEqualToString:@"chatEventMemberSubscriptionExtended"]){
		title = TGLocalizedFormat(@"%@ extended their subscription", who);
	} else if ([kind isEqualToString:@"chatEventMemberTagChanged"]){
		NSString *target = person(action[@"user_id"]);
		title = [NSString stringWithFormat:@"%@ %@", who,
				TGLocalizedFormat(@"changed member tag for %1$@:\n%2$@", target, TGEString(action[@"new_tag"]))];
	} else if ([kind isEqualToString:@"chatEventMemberJoinedByInviteLink"]){
		NSString *link = TGEString(action[@"invite_link"][@"invite_link"]);
		title = [action[@"via_chat_folder_invite_link"] boolValue]
				? TGLocalizedFormat(@"%1$@ joined via invite link %2$@ (community)", who, link)
				: TGLocalizedFormat(@"%1$@ joined via invite link %2$@", who, link);
	} else if ([kind isEqualToString:@"chatEventInviteLinkEdited"]){
		title = TGLocalizedFormat(@"%1$@ edited invite link %2$@", who,
				TGEString(action[@"new_invite_link"][@"invite_link"]));
	} else if ([kind isEqualToString:@"chatEventInviteLinkRevoked"]){
		title = TGLocalizedFormat(@"%1$@ revoked invite link %2$@", who, TGEString(action[@"invite_link"][@"invite_link"]));
	} else if ([kind isEqualToString:@"chatEventInviteLinkDeleted"]){
		title = TGLocalizedFormat(@"%1$@ deleted invite link %2$@", who, TGEString(action[@"invite_link"][@"invite_link"]));
	} else if ([kind isEqualToString:@"chatEventLinkedChatChanged"]){
		int64_t now = [action[@"new_linked_chat_id"] longLongValue], was = [action[@"old_linked_chat_id"] longLongValue];
		NSString *other = person(@(now ?: was));
		title = isChannel
				? (now ? TGLocalizedFormat(@"%1$@ made %2$@ the discussion group for this channel.", who, other)
					   : TGLocalizedFormat(@"%1$@ removed the discussion group %2$@", who, other))
				: (now ? TGLocalizedFormat(@"%1$@ linked this group to %2$@", who, other)
					   : TGLocalizedFormat(@"%1$@ unlinked this group from %2$@", who, other));
	} else if ([kind isEqualToString:@"chatEventLocationChanged"]){
		NSDictionary *place = action[@"new_location"];
		title = [NSString stringWithFormat:@"%@ %@", who, TGLocalizedFormat(@"changed group location to \"%@\"",
				[place isKindOfClass:NSDictionary.class] ? TGEString(place[@"address"]) : @"")];
	} else if ([kind isEqualToString:@"chatEventAvailableReactionsChanged"]){
		NSDictionary *now = action[@"new_available_reactions"];
		NSArray *some = [now isKindOfClass:NSDictionary.class] && [now[@"reactions"] isKindOfClass:NSArray.class]
				? now[@"reactions"] : nil;
		if ([now[@"@type"] isEqualToString:@"chatAvailableReactionsAll"])
			title = TGLocalizedFormat(@"%1$@ enabled all reactions", who);
		else if (!some.count)
			title = TGLocalizedFormat(@"%1$@ disabled reactions", who);
		else {
			NSMutableArray *emoji = [NSMutableArray array];
			for (NSDictionary *r in some)
				if ([r isKindOfClass:NSDictionary.class] && TGEString(r[@"emoji"]).length)
					[emoji addObject:r[@"emoji"]];
			title = TGLocalizedFormat(@"%1$@ updated the list of allowed reactions to: %2$@", who,
					[emoji componentsJoinedByString:@" "]);
		}
	} else if ([kind isEqualToString:@"chatEventBackgroundChanged"]){
		title = [action[@"new_background"] isKindOfClass:NSDictionary.class]
				? TGLocalizedFormat(@"%1$@ set a new wallpaper", who)
				: TGLocalizedFormat(@"%1$@ removed wallpaper", who);
	} else if ([kind isEqualToString:@"chatEventStickerSetChanged"]){
		title = [action[@"new_sticker_set_id"] longLongValue]
				? TGLocalizedFormat(@"%@ changed group sticker set", who)
				: TGLocalizedFormat(@"%@ removed group sticker set", who);
	} else if ([kind isEqualToString:@"chatEventCustomEmojiStickerSetChanged"]){
		title = [action[@"new_sticker_set_id"] longLongValue]
				? TGLocalizedFormat(@"%@ changed group emoji pack", who)
				: TGLocalizedFormat(@"%@ removed group emoji pack", who);
	} else if ([kind isEqualToString:@"chatEventEmojiStatusChanged"]){
		title = [action[@"new_emoji_status"] isKindOfClass:NSDictionary.class]
				? TGLocalizedFormat(@"%1$@ changed the channel status to %2$@", who, TGEString(action[@"emoji"]))
				: TGLocalizedFormat(@"%1$@ removed the channel status", who);
	} else if ([kind isEqualToString:@"chatEventForumTopicCreated"]){
		title = TGLocalizedFormat(@"%1$@ created topic %2$@", who, TGETopic(action[@"topic_info"]));
	} else if ([kind isEqualToString:@"chatEventForumTopicDeleted"]){
		title = TGLocalizedFormat(@"%1$@ deleted topic %2$@", who, TGETopic(action[@"topic_info"]));
	} else if ([kind isEqualToString:@"chatEventForumTopicEdited"]){
		title = TGLocalizedFormat(@"%1$@ renamed topic %2$@ to %3$@", who,
				TGETopic(action[@"old_topic_info"]), TGETopic(action[@"new_topic_info"]));
	} else if ([kind isEqualToString:@"chatEventForumTopicPinned"]){
		NSDictionary *now = action[@"new_topic_info"];
		title = [now isKindOfClass:NSDictionary.class]
				? TGLocalizedFormat(@"%1$@ pinned topic %2$@", who, TGETopic(now))
				: TGLocalizedFormat(@"%1$@ unpinned topic %2$@", who, TGETopic(action[@"old_topic_info"]));
	} else if ([kind isEqualToString:@"chatEventForumTopicToggleIsClosed"]){
		NSDictionary *topic = action[@"topic_info"];
		title = [topic[@"is_closed"] boolValue] ? TGLocalizedFormat(@"%1$@ closed topic %2$@", who, TGETopic(topic))
				: TGLocalizedFormat(@"%1$@ reopened topic %2$@", who, TGETopic(topic));
	} else if ([kind isEqualToString:@"chatEventForumTopicToggleIsHidden"]){
		NSDictionary *topic = action[@"topic_info"];
		title = [topic[@"is_hidden"] boolValue] ? TGLocalizedFormat(@"%1$@ hid topic %2$@", who, TGETopic(topic))
				: TGLocalizedFormat(@"%1$@ unhid topic %2$@", who, TGETopic(topic));
	} else if ([kind isEqualToString:@"chatEventVideoChatCreated"]){
		title = TGLocalizedFormat(@"%1$@ started voice chat", who);
	} else if ([kind isEqualToString:@"chatEventVideoChatEnded"]){
		title = TGLocalizedFormat(@"%1$@ ended voice chat", who);
	} else if ([kind isEqualToString:@"chatEventMemberJoined"]){
		title = isChannel ? TGLocalizedFormat(@"%@ joined the channel", who)
				: TGLocalizedFormat(@"%@ joined the group", who);
	} else if ([kind isEqualToString:@"chatEventMemberLeft"]){
		title = isChannel ? TGLocalizedFormat(@"%@ left the channel", who)
				: TGLocalizedFormat(@"%@ left the group", who);
	}
	// Official writes the new colour as a swatch and the new icon as its
	// emoji, never the old ones (ChatRecentActionsHistoryTransition
	// changeNameColor / changeProfileColor). The swatch is a dot here that
	// the list colours; the icon is the custom emoji's own emoji, as the
	// status line above does.
	if ([kind isEqualToString:@"chatEventAccentColorChanged"] ||
			[kind isEqualToString:@"chatEventProfileAccentColorChanged"]){
		BOOL profile = [kind isEqualToString:@"chatEventProfileAccentColorChanged"];
		NSInteger colourId = [action[profile ? @"new_profile_accent_color_id" : @"new_accent_color_id"]
				integerValue];
		BOOL hasIcon = [action[profile ? @"new_profile_background_custom_emoji_id"
				: @"new_background_custom_emoji_id"] longLongValue] != 0;
		NSString *icon = TGEString(action[@"iconEmoji"]);
		NSString *dot = @"\u25CF";
		if (profile && colourId < 0)
			title = TGLocalizedFormat(@"%1$@ changed the removed profile color and icon", who);
		else if (hasIcon)
			title = profile
					? TGLocalizedFormat(@"%1$@ changed the channel profile color and icon to %2$@ %3$@", who, dot, icon)
					: TGLocalizedFormat(@"%1$@ changed the channel name color and icon to %2$@ %3$@", who, dot, icon);
		else
			title = profile
					? TGLocalizedFormat(@"%1$@ changed the channel profile color to %2$@", who, dot)
					: TGLocalizedFormat(@"%1$@ changed the channel name color to %2$@", who, dot);
		title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSRange at = [title rangeOfString:dot options:NSBackwardsSearch];
		if (at.location != NSNotFound && !(profile && colourId < 0))
			swatch = @{@"location" : @(at.location), @"colorId" : @(colourId),
					   @"profile" : @(profile)};
	}
	if (!title)
		title = TGEToggleLine(kind, action, who, person);
	if (!title){
		// Anything newer than this list still says what happened, in plain
		// words.
		NSString *rest = [kind hasPrefix:@"chatEvent"] ? [kind substringFromIndex:9] : kind;
		title = [NSString stringWithFormat:@"%@ %@", who, [TGPhraseFromTypeName(rest) lowercaseString]];
	}
	if (swatch)
		return @{@"title" : title, @"detail" : detail ?: @"", @"swatch" : swatch};
	return @{@"title" : title, @"detail" : detail ?: @""};
}
