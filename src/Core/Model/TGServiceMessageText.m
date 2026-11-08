#import "TGServiceMessageText.h"
#import "TGLocalization.h"

static NSString *TGServiceString(NSDictionary *dict, NSString *key) {
	id value = dict[key];
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSString *TGServiceFormattedText(NSDictionary *formatted) {
	if (![formatted isKindOfClass:[NSDictionary class]])
		return @"";
	return TGServiceString(formatted, @"text") ?: @"";
}

static NSString *TGServiceCount(int64_t count, NSString *singular, NSString *plural) {
	NSString *value = [NSString stringWithFormat:@"%lld", (long long)count];
	return TGLocalizedPluralValue([@"%@ " stringByAppendingString:singular],
			[@"%@ " stringByAppendingString:plural], value, (NSInteger)count);
}

static NSString *TGServiceStars(int64_t stars) {
	int64_t count = stars < 0 ? -stars : stars;
	return TGServiceCount(count, @"Star", @"Stars");
}

static NSString *TGServiceMoney(NSString *currency, int64_t amount) {
	int64_t cents = amount < 0 ? -amount : amount;
	int64_t whole = cents / 100;
	int64_t fraction = cents % 100;
	NSString *code = currency.length ? [currency uppercaseString] : @"";
	if ([code isEqualToString:@"USD"])
		return [NSString stringWithFormat:@"$%lld.%02lld",
				(long long)whole, (long long)fraction];
	if ([code isEqualToString:@"EUR"])
		return [NSString stringWithFormat:@"\u20ac%lld.%02lld",
				(long long)whole, (long long)fraction];
	if (code.length == 0)
		return [NSString stringWithFormat:@"%lld.%02lld",
				(long long)whole, (long long)fraction];
	return [NSString stringWithFormat:@"%lld.%02lld %@",
			(long long)whole, (long long)fraction, code];
}

static NSString *TGServiceDuration(int64_t seconds) {
	int64_t value = seconds < 0 ? -seconds : seconds;
	if (value < 60)
		return TGServiceCount(value, @"second", @"seconds");
	if (value < 3600)
		return TGServiceCount(value / 60, @"minute", @"minutes");
	if (value < 86400)
		return TGServiceCount(value / 3600, @"hour", @"hours");
	if (value < 7 * 86400)
		return TGServiceCount(value / 86400, @"day", @"days");
	if (value < 30 * 86400)
		return TGServiceCount(value / (7 * 86400), @"week", @"weeks");
	if (value < 365 * 86400)
		return TGServiceCount(value / (30 * 86400), @"month", @"months");
	return TGServiceCount(value / (365 * 86400), @"year", @"years");
}

static NSString *TGServicePremiumPeriod(int64_t months, int64_t days) {
	if (months > 0 && days > 0)
		return TGLocalizedFormat(@"%@ and %@",
				TGServiceCount(months, @"month", @"months"),
				TGServiceCount(days, @"day", @"days"));
	if (months > 0)
		return TGServiceCount(months, @"month", @"months");
	if (days > 0)
		return TGServiceCount(days, @"day", @"days");
	return nil;
}

static NSString *TGServiceTon(int64_t grams) {
	int64_t value = grams < 0 ? -grams : grams;
	int64_t whole = value / 1000000000LL;
	int64_t fraction = value % 1000000000LL;
	if (fraction == 0)
		return [NSString stringWithFormat:@"%lld TON", (long long)whole];
	NSMutableString *digits = [NSMutableString stringWithFormat:@"%09lld",
			(long long)fraction];
	while ([digits hasSuffix:@"0"])
		[digits deleteCharactersInRange:NSMakeRange(digits.length - 1, 1)];
	return [NSString stringWithFormat:@"%lld.%@ TON", (long long)whole, digits];
}

static NSString *TGServiceGramCents(int64_t cents) {
	int64_t value = cents < 0 ? -cents : cents;
	int64_t whole = value / 100;
	int64_t fraction = value % 100;
	if (fraction == 0)
		return [NSString stringWithFormat:@"%lld TON", (long long)whole];
	NSMutableString *digits = [NSMutableString stringWithFormat:@"%02lld",
			(long long)fraction];
	while ([digits hasSuffix:@"0"])
		[digits deleteCharactersInRange:NSMakeRange(digits.length - 1, 1)];
	return [NSString stringWithFormat:@"%lld.%@ TON", (long long)whole, digits];
}

static NSString *TGServicePrice(NSDictionary *price) {
	if (![price isKindOfClass:[NSDictionary class]])
		return nil;
	NSString *type = TGServiceString(price, @"@type");
	if ([type isEqualToString:@"suggestedPostPriceStar"] ||
			[type isEqualToString:@"giftResalePriceStar"])
		return TGServiceStars([price[@"star_count"] longLongValue]);
	if ([type isEqualToString:@"suggestedPostPriceGram"] ||
			[type isEqualToString:@"giftResalePriceGram"])
		return TGServiceGramCents([price[@"gram_cent_count"] longLongValue]);
	return nil;
}

static NSString *TGServiceStarAmount(NSDictionary *amount) {
	if (![amount isKindOfClass:[NSDictionary class]])
		return nil;
	return TGServiceStars([amount[@"star_count"] longLongValue]);
}

static NSString *TGServiceSenderName(NSDictionary *sender,
		TGServiceUserName userName, TGServiceChatTitle chatTitle) {
	if (![sender isKindOfClass:[NSDictionary class]])
		return nil;
	NSString *type = TGServiceString(sender, @"@type");
	if ([type isEqualToString:@"messageSenderUser"]) {
		int64_t userId = [sender[@"user_id"] longLongValue];
		NSString *name = userName ? userName(userId) : nil;
		return name.length ? name : nil;
	}
	if ([type isEqualToString:@"messageSenderChat"]) {
		int64_t chatId = [sender[@"chat_id"] longLongValue];
		NSString *name = chatTitle ? chatTitle(chatId) : nil;
		return name.length ? name : nil;
	}
	return nil;
}

static NSString *TGServiceActor(NSDictionary *message,
		TGServiceUserName userName, TGServiceChatTitle chatTitle) {
	if ([message[@"is_outgoing"] boolValue])
		return @"You";
	NSString *name = TGServiceSenderName(message[@"sender_id"], userName, chatTitle);
	return name ?: TGLocalized(@"Someone");
}

static NSString *TGServicePossessive(NSString *actor) {
	if ([actor isEqualToString:@"You"])
		return @"Your";
	return [NSString stringWithFormat:@"%@'s", actor];
}

static NSString *TGServiceGroupWord(NSDictionary *message) {
	return [message[@"is_channel_post"] boolValue] ? @"channel" : @"group";
}

static NSString *TGServiceJoinUsers(NSArray *userIds, TGServiceUserName userName) {
	if (![userIds isKindOfClass:[NSArray class]] || userIds.count == 0)
		return nil;
	NSMutableArray *names = [NSMutableArray arrayWithCapacity:userIds.count];
	for (id value in userIds) {
		int64_t userId = [value longLongValue];
		NSString *name = userName ? userName(userId) : nil;
		[names addObject:name.length ? name : TGLocalized(@"Someone")];
	}
	if (names.count == 1)
		return names[0];
	if (names.count == 2)
		return TGLocalizedFormat(@"%@ and %@", names[0], names[1]);
	NSArray *head = [names subarrayWithRange:NSMakeRange(0, names.count - 1)];
	return TGLocalizedFormat(@"%@ and %@",
			[head componentsJoinedByString:@", "], names.lastObject);
}

static NSString *TGServiceGiftGiver(NSDictionary *content, NSString *actor,
		TGServiceUserName userName) {
	int64_t userId = [content[@"gifter_user_id"] longLongValue];
	if (userId == 0)
		return actor;
	NSString *name = userName ? userName(userId) : nil;
	return name.length ? name : TGLocalized(@"Someone");
}

static NSString *TGServiceGiftReceiver(NSDictionary *content, NSDictionary *message,
		TGServiceUserName userName) {
	int64_t userId = [content[@"receiver_user_id"] longLongValue];
	if (userId != 0) {
		NSString *name = userName ? userName(userId) : nil;
		return name.length ? name : TGLocalized(@"Someone");
	}
	return [message[@"is_outgoing"] boolValue] ? @"someone" : @"you";
}

NSString *TGServiceMessageText(NSDictionary *message,
		TGServiceUserName userName, TGServiceChatTitle chatTitle) {
	if (![message isKindOfClass:[NSDictionary class]])
		return nil;
	NSDictionary *content = message[@"content"];
	if (![content isKindOfClass:[NSDictionary class]])
		return nil;
	NSString *type = TGServiceString(content, @"@type");
	if (type.length == 0)
		return nil;

	NSString *actor = TGServiceActor(message, userName, chatTitle);
	NSString *group = TGServiceGroupWord(message);
	NSString *title = TGServiceString(content, @"title");
	NSString *name = TGServiceString(content, @"name");
	NSString *text = TGServiceString(content, @"text");

	if ([type isEqualToString:@"messageBasicGroupChatCreate"] ||
			[type isEqualToString:@"messageSupergroupChatCreate"]) {
		if ([group isEqualToString:@"group"]) {
			return title.length
					? TGLocalizedFormat(@"%@ created the group \"%@\"", actor, title)
					: TGLocalizedFormat(@"%@ created a group", actor);
		}
		return title.length
				? [NSString stringWithFormat:@"%@ created the channel \"%@\"", actor, title]
				: [NSString stringWithFormat:@"%@ created a channel", actor];
	}
	if ([type isEqualToString:@"messageChatChangeTitle"]) {
		if ([group isEqualToString:@"group"]) {
			return title.length
					? TGLocalizedFormat(@"%@ changed the group name to \"%@\"", actor, title)
					: [NSString stringWithFormat:@"%@ changed the %@ name", actor, group];
		}
		return title.length
				? [NSString stringWithFormat:@"%@ changed the %@ name to \"%@\"",
						actor, group, title]
				: [NSString stringWithFormat:@"%@ changed the %@ name", actor, group];
	}
	if ([type isEqualToString:@"messageChatChangePhoto"]) {
		return [group isEqualToString:@"group"]
				? TGLocalizedFormat(@"%@ changed the group photo", actor)
				: [NSString stringWithFormat:@"%@ changed the %@ photo", actor, group];
	}
	if ([type isEqualToString:@"messageChatDeletePhoto"])
		return [NSString stringWithFormat:@"%@ removed the %@ photo", actor, group];
	if ([type isEqualToString:@"messageChatAddMembers"]) {
		NSString *names = TGServiceJoinUsers(content[@"member_user_ids"], userName);
		return names
				? [NSString stringWithFormat:@"%@ added %@", actor, names]
				: [NSString stringWithFormat:@"%@ added members", actor];
	}
	if ([type isEqualToString:@"messageChatJoinByLink"]) {
		return [group isEqualToString:@"group"]
				? TGLocalizedFormat(@"%@ joined the group via invite link", actor)
				: [NSString stringWithFormat:@"%@ joined the %@ via invite link", actor, group];
	}
	if ([type isEqualToString:@"messageChatJoinByRequest"]) {
		return [group isEqualToString:@"group"]
				? TGLocalizedFormat(@"%@ was accepted to the group", actor)
				: [NSString stringWithFormat:@"%@ was accepted to the %@", actor, group];
	}
	if ([type isEqualToString:@"messageChatJoinFromCommunity"])
		return [NSString stringWithFormat:@"%@ joined the %@ from a community", actor, group];
	if ([type isEqualToString:@"messageChatDeleteMember"]) {
		int64_t userId = [content[@"user_id"] longLongValue];
		NSDictionary *sender = message[@"sender_id"];
		// TDLib uses the same content type when a member leaves by choice;
		// only an outsider removing somebody reads as "removed".
		BOOL left = ![message[@"is_outgoing"] boolValue] &&
				[sender isKindOfClass:[NSDictionary class]] &&
				[TGServiceString(sender, @"@type") isEqualToString:@"messageSenderUser"] &&
				[sender[@"user_id"] longLongValue] == userId && userId != 0;
		if (left) {
			return [group isEqualToString:@"group"]
					? TGLocalizedFormat(@"%@ left the group", actor)
					: TGLocalizedFormat(@"%@ left the channel", actor);
		}
		NSString *who = userName ? userName(userId) : nil;
		return who.length
				? TGLocalizedFormat(@"%@ removed %@", actor, who)
				: [NSString stringWithFormat:@"%@ removed a member", actor];
	}
	if ([type isEqualToString:@"messageChatUpgradeTo"])
		return TGLocalized(@"This group was upgraded to a supergroup");
	if ([type isEqualToString:@"messageChatUpgradeFrom"]) {
		NSString *created = [message[@"is_channel_post"] boolValue] ? @"channel" : @"supergroup";
		return title.length
				? [NSString stringWithFormat:@"%@ created the %@ \"%@\"", actor, created, title]
				: [NSString stringWithFormat:@"%@ created a %@", actor, created];
	}
	if ([type isEqualToString:@"messagePinMessage"]) {
		// The zero-width marker tells TGPinnedLine that this is a pinned line
		// even when the sentence is translated and no longer ends in "a message".
		NSString *english = @"%@ pinned a message";
		NSString *line = TGLocalizedFormat(english, actor);
		if ([TGLocalized(english) isEqualToString:english])
			return line;
		return [line stringByAppendingString:@"\u200B"];
	}
	if ([type isEqualToString:@"messageScreenshotTaken"])
		return [NSString stringWithFormat:@"%@ took a screenshot", actor];
	if ([type isEqualToString:@"messageChatSetBackground"])
		return [NSString stringWithFormat:@"%@ set a new chat background", actor];
	if ([type isEqualToString:@"messageChatSetTheme"]) {
		NSDictionary *theme = content[@"theme"];
		BOOL hasTheme = [theme isKindOfClass:[NSDictionary class]] &&
				TGServiceString(theme, @"@type").length > 0;
		return hasTheme
				? [NSString stringWithFormat:@"%@ changed the chat theme", actor]
				: [NSString stringWithFormat:@"%@ reset the chat theme", actor];
	}
	if ([type isEqualToString:@"messageChatSetMessageAutoDeleteTime"]) {
		int64_t seconds = [content[@"message_auto_delete_time"] longLongValue];
		return seconds > 0
				? TGLocalizedFormat(@"%1$@ set messages to auto-delete in %2$@",
						actor, TGServiceDuration(seconds))
				: [NSString stringWithFormat:@"%@ turned off auto-delete", actor];
	}
	if ([type isEqualToString:@"messageChatBoost"]) {
		int64_t count = [content[@"boost_count"] longLongValue];
		return count > 1
				? [NSString stringWithFormat:@"%@ boosted the %@ %lld times",
						actor, group, (long long)count]
				: [NSString stringWithFormat:@"%@ boosted the %@", actor, group];
	}
	if ([type isEqualToString:@"messageForumTopicCreated"]) {
		return name.length
				? [NSString stringWithFormat:@"%@ created the topic \"%@\"", actor, name]
				: [NSString stringWithFormat:@"%@ created a topic", actor];
	}
	if ([type isEqualToString:@"messageForumTopicEdited"]) {
		if (name.length)
			return [NSString stringWithFormat:@"%@ renamed the topic to \"%@\"", actor, name];
		if ([content[@"edit_icon_custom_emoji_id"] boolValue])
			return TGLocalizedFormat(@"%1$@ changed the topic icon", actor);
		return [NSString stringWithFormat:@"%@ edited the topic", actor];
	}
	if ([type isEqualToString:@"messageForumTopicIsClosedToggled"]) {
		return [content[@"is_closed"] boolValue]
				? TGLocalizedFormat(@"%1$@ closed the topic", actor)
				: TGLocalizedFormat(@"%1$@ reopened the topic", actor);
	}
	if ([type isEqualToString:@"messageForumTopicIsHiddenToggled"]) {
		return [content[@"is_hidden"] boolValue]
				? [NSString stringWithFormat:@"%@ hid the topic", actor]
				: [NSString stringWithFormat:@"%@ showed the topic", actor];
	}
	if ([type isEqualToString:@"messageSuggestProfilePhoto"])
		return [NSString stringWithFormat:@"%@ suggested a new profile photo", actor];
	if ([type isEqualToString:@"messageSuggestBirthdate"])
		return [NSString stringWithFormat:@"%@ suggested a birthdate", actor];
	if ([type isEqualToString:@"messageCustomServiceAction"])
		return text ?: @"";
	if ([type isEqualToString:@"messageGameScore"]) {
		int64_t score = [content[@"score"] longLongValue];
		return [NSString stringWithFormat:@"%@ scored %lld in a game",
				actor, (long long)score];
	}
	if ([type isEqualToString:@"messagePaymentSuccessful"]) {
		NSString *amount = TGServiceMoney(TGServiceString(content, @"currency"),
				[content[@"total_amount"] longLongValue]);
		NSString *invoice = TGServiceString(content, @"invoice_name");
		return invoice.length
				? [NSString stringWithFormat:@"%@ paid %@ for \"%@\"", actor, amount, invoice]
				: [NSString stringWithFormat:@"%@ paid %@", actor, amount];
	}
	if ([type isEqualToString:@"messagePaymentSuccessfulBot"]) {
		NSString *amount = TGServiceMoney(TGServiceString(content, @"currency"),
				[content[@"total_amount"] longLongValue]);
		return [NSString stringWithFormat:@"%@ paid %@", actor, amount];
	}
	if ([type isEqualToString:@"messagePaymentRefunded"]) {
		NSString *amount = TGServiceMoney(TGServiceString(content, @"currency"),
				[content[@"total_amount"] longLongValue]);
		return [NSString stringWithFormat:@"%@ received a refund of %@", actor, amount];
	}
	if ([type isEqualToString:@"messageGiftedPremium"]) {
		NSString *gifter = TGServiceGiftGiver(content, actor, userName);
		NSString *receiver = TGServiceGiftReceiver(content, message, userName);
		NSString *period = TGServicePremiumPeriod(
				[content[@"month_count"] longLongValue],
				[content[@"day_count"] longLongValue]);
		return period.length
				? [NSString stringWithFormat:@"%@ gifted %@ %@ of Telegram Premium",
						gifter, receiver, period]
				: [NSString stringWithFormat:@"%@ gifted %@ Telegram Premium",
						gifter, receiver];
	}
	if ([type isEqualToString:@"messagePremiumGiftCode"]) {
		NSString *period = TGServicePremiumPeriod(
				[content[@"month_count"] longLongValue],
				[content[@"day_count"] longLongValue]);
		return period.length
				? [NSString stringWithFormat:@"%@ received a gift code for %@ of Telegram Premium",
						actor, period]
				: [NSString stringWithFormat:@"%@ received a Telegram Premium gift code", actor];
	}
	if ([type isEqualToString:@"messageGiftedStars"]) {
		NSString *gifter = TGServiceGiftGiver(content, actor, userName);
		NSString *receiver = TGServiceGiftReceiver(content, message, userName);
		return [NSString stringWithFormat:@"%@ gifted %@ %@", gifter, receiver,
				TGServiceStars([content[@"star_count"] longLongValue])];
	}
	if ([type isEqualToString:@"messageGiftedGrams"]) {
		NSString *gifter = TGServiceGiftGiver(content, actor, userName);
		NSString *receiver = TGServiceGiftReceiver(content, message, userName);
		return [NSString stringWithFormat:@"%@ gifted %@ %@", gifter, receiver,
				TGServiceTon([content[@"gram_amount"] longLongValue])];
	}
	if ([type isEqualToString:@"messageGiveawayPrizeStars"]) {
		int64_t stars = [content[@"star_count"] longLongValue];
		return stars > 0
				? [NSString stringWithFormat:@"%@ received %@ from a giveaway",
						actor, TGServiceStars(stars)]
				: [NSString stringWithFormat:@"%@ received Telegram Stars from a giveaway", actor];
	}
	if ([type isEqualToString:@"messageGiveawayCreated"]) {
		int64_t stars = [content[@"star_count"] longLongValue];
		return stars > 0
				? [NSString stringWithFormat:@"%@ started a giveaway of %@",
						actor, TGServiceStars(stars)]
				: TGLocalizedFormat(@"%@ started a giveaway", actor);
	}
	if ([type isEqualToString:@"messageGiveawayCompleted"]) {
		int64_t winners = [content[@"winner_count"] longLongValue];
		return [NSString stringWithFormat:@"%@ giveaway has ended: %@",
				TGServicePossessive(actor),
				TGServiceCount(winners, @"winner", @"winners")];
	}
	if ([type isEqualToString:@"messageContactRegistered"])
		return TGLocalizedFormat(@"%@ joined Telegram", actor);
	if ([type isEqualToString:@"messageBotWriteAccessAllowed"]) {
		NSDictionary *reason = content[@"reason"];
		NSString *reasonType = [reason isKindOfClass:[NSDictionary class]]
				? TGServiceString(reason, @"@type") : nil;
		if ([reasonType isEqualToString:@"botWriteAccessAllowReasonConnectedWebsite"]) {
			NSString *domain = TGServiceString(reason, @"domain_name");
			if (domain.length)
				return TGLocalizedFormat(
						@"You allowed this bot to message you when you logged in on %@.",
						domain);
		}
		if ([reasonType isEqualToString:@"botWriteAccessAllowReasonAddedToAttachmentMenu"])
			return TGLocalized(@"You allowed this bot to message you when you added it to your attachment menu.");
		return [NSString stringWithFormat:@"%@ allowed the bot to send messages", actor];
	}
	if ([type isEqualToString:@"messageWebAppDataSent"])
		return [NSString stringWithFormat:@"%@ sent data to the bot", actor];
	if ([type isEqualToString:@"messageWebAppDataReceived"])
		return [NSString stringWithFormat:@"%@ received data from the bot", actor];
	if ([type isEqualToString:@"messagePassportDataSent"])
		return [NSString stringWithFormat:@"%@ sent passport data", actor];
	if ([type isEqualToString:@"messagePassportDataReceived"])
		return [NSString stringWithFormat:@"%@ received passport data", actor];
	if ([type isEqualToString:@"messageProximityAlertTriggered"]) {
		NSString *traveler = TGServiceSenderName(content[@"traveler_id"],
				userName, chatTitle) ?: TGLocalized(@"Someone");
		NSString *watcher = TGServiceSenderName(content[@"watcher_id"],
				userName, chatTitle) ?: TGLocalized(@"Someone");
		int64_t distance = [content[@"distance"] longLongValue];
		return [NSString stringWithFormat:@"%@ is within %lld m of %@",
				traveler, (long long)distance, watcher];
	}
	if ([type isEqualToString:@"messageVideoChatScheduled"])
		return [NSString stringWithFormat:@"%@ scheduled a video chat", actor];
	if ([type isEqualToString:@"messageVideoChatStarted"])
		return [NSString stringWithFormat:@"%@ started a video chat", actor];
	if ([type isEqualToString:@"messageVideoChatEnded"]) {
		int64_t duration = [content[@"duration"] longLongValue];
		return TGLocalizedFormat(@"Video chat ended (%@)",
				TGServiceDuration(duration));
	}
	if ([type isEqualToString:@"messageInviteVideoChatParticipants"]) {
		NSString *names = TGServiceJoinUsers(content[@"user_ids"], userName);
		return names
				? [NSString stringWithFormat:@"%@ invited %@ to the video chat",
						actor, names]
				: [NSString stringWithFormat:@"%@ invited participants to the video chat", actor];
	}
	if ([type isEqualToString:@"messageExpiredPhoto"])
		return @"Photo has expired";
	if ([type isEqualToString:@"messageExpiredVideo"])
		return @"Video has expired";
	if ([type isEqualToString:@"messageExpiredVideoNote"])
		return @"Expired video message";
	if ([type isEqualToString:@"messageExpiredVoiceNote"])
		return @"Expired voice message";
	if ([type isEqualToString:@"messageChatOwnerChanged"]) {
		int64_t userId = [content[@"new_owner_user_id"] longLongValue];
		NSString *owner = userName ? userName(userId) : nil;
		return owner.length
				? [NSString stringWithFormat:@"%@ transferred the %@ to %@",
						actor, group, owner]
				: [NSString stringWithFormat:@"%@ transferred ownership of the %@",
						actor, group];
	}
	if ([type isEqualToString:@"messageChatOwnerLeft"]) {
		int64_t userId = [content[@"new_owner_user_id"] longLongValue];
		NSString *owner = userName ? userName(userId) : nil;
		return owner.length
				? [NSString stringWithFormat:@"%@ left the %@. %@ is the new owner",
						actor, group, owner]
				: [NSString stringWithFormat:@"%@ left the %@", actor, group];
	}
	if ([type isEqualToString:@"messageChatAddedToCommunity"])
		return [NSString stringWithFormat:@"%@ added the %@ to a community",
				actor, group];
	if ([type isEqualToString:@"messageChatRemovedFromCommunity"])
		return [NSString stringWithFormat:@"%@ removed the %@ from the community",
				actor, group];
	if ([type isEqualToString:@"messageChatHasProtectedContentToggled"]) {
		return [content[@"new_has_protected_content"] boolValue]
				? [NSString stringWithFormat:@"%@ enabled content protection", actor]
				: [NSString stringWithFormat:@"%@ disabled content protection", actor];
	}
	if ([type isEqualToString:@"messageChatHasProtectedContentDisableRequested"]) {
		return [content[@"is_expired"] boolValue]
				? [NSString stringWithFormat:
						@"%@ request to disable content protection has expired",
						TGServicePossessive(actor)]
				: [NSString stringWithFormat:@"%@ requested to disable content protection",
						actor];
	}
	if ([type isEqualToString:@"messageDirectMessagePriceChanged"]) {
		int64_t stars = [content[@"paid_message_star_count"] longLongValue];
		if (![content[@"is_enabled"] boolValue])
			return [NSString stringWithFormat:@"%@ disabled paid direct messages", actor];
		if (stars > 0)
			return [NSString stringWithFormat:
					@"%@ enabled paid direct messages at %@ per message",
					actor, TGServiceStars(stars)];
		return [NSString stringWithFormat:@"%@ enabled direct messages for free", actor];
	}
	if ([type isEqualToString:@"messagePaidMessagePriceChanged"]) {
		int64_t stars = [content[@"paid_message_star_count"] longLongValue];
		return stars > 0
				? TGLocalizedFormat(
						@"%1$@ changed price to %2$@ per message",
						actor, TGServiceStars(stars))
				: [NSString stringWithFormat:@"%@ made messages free", actor];
	}
	if ([type isEqualToString:@"messagePaidMessagesRefunded"]) {
		int64_t count = [content[@"message_count"] longLongValue];
		NSString *stars = TGServiceStars([content[@"star_count"] longLongValue]);
		return count > 0
				? [NSString stringWithFormat:@"%@ refunded %@ for %@",
						actor, stars, TGServiceCount(count, @"message", @"messages")]
				: [NSString stringWithFormat:@"%@ refunded %@", actor, stars];
	}
	if ([type isEqualToString:@"messageUnpaidMessagesAllowedByLink"])
		return [NSString stringWithFormat:@"%@ allowed unpaid messages via link", actor];
	if ([type isEqualToString:@"messageSuggestedPostApprovalFailed"])
		return [NSString stringWithFormat:@"%@ suggested post could not be approved",
				TGServicePossessive(actor)];
	if ([type isEqualToString:@"messageSuggestedPostApproved"])
		return [NSString stringWithFormat:@"%@ suggested post was approved",
				TGServicePossessive(actor)];
	if ([type isEqualToString:@"messageSuggestedPostDeclined"])
		return [NSString stringWithFormat:@"%@ suggested post was declined",
				TGServicePossessive(actor)];
	if ([type isEqualToString:@"messageSuggestedPostPaid"]) {
		NSString *stars = TGServiceStarAmount(content[@"star_amount"]);
		return stars
				? [NSString stringWithFormat:@"%@ received %@ for the suggested post",
						actor, stars]
				: [NSString stringWithFormat:@"%@ received payment for the suggested post",
						actor];
	}
	if ([type isEqualToString:@"messageSuggestedPostRefunded"])
		return [NSString stringWithFormat:
				@"%@ payment for the suggested post was refunded",
				TGServicePossessive(actor)];
	if ([type isEqualToString:@"messageChecklistTasksAdded"]) {
		NSArray *tasks = content[@"tasks"];
		int64_t count = [tasks isKindOfClass:[NSArray class]] ? (int64_t)tasks.count : 0;
		return [NSString stringWithFormat:@"%@ added %@ to a checklist", actor,
				TGServiceCount(count, @"task", @"tasks")];
	}
	if ([type isEqualToString:@"messageChecklistTasksDone"]) {
		NSArray *done = content[@"marked_as_done_task_ids"];
		NSArray *notDone = content[@"marked_as_not_done_task_ids"];
		int64_t doneCount = [done isKindOfClass:[NSArray class]] ? (int64_t)done.count : 0;
		int64_t notDoneCount = [notDone isKindOfClass:[NSArray class]]
				? (int64_t)notDone.count : 0;
		if (doneCount > 0 && notDoneCount > 0)
			return [NSString stringWithFormat:@"%@ marked %@ as done and %@ as not done",
					actor, TGServiceCount(doneCount, @"task", @"tasks"),
					TGServiceCount(notDoneCount, @"task", @"tasks")];
		if (doneCount > 0)
			return [NSString stringWithFormat:@"%@ marked %@ as done", actor,
					TGServiceCount(doneCount, @"task", @"tasks")];
		if (notDoneCount > 0)
			return [NSString stringWithFormat:@"%@ marked %@ as not done", actor,
					TGServiceCount(notDoneCount, @"task", @"tasks")];
		return [NSString stringWithFormat:@"%@ updated a checklist", actor];
	}
	if ([type isEqualToString:@"messagePollOptionAdded"]) {
		NSString *option = TGServiceFormattedText(content[@"text"]);
		return option.length
				? [NSString stringWithFormat:@"%@ added the poll option \"%@\"",
						actor, option]
				: [NSString stringWithFormat:@"%@ added a poll option", actor];
	}
	if ([type isEqualToString:@"messagePollOptionDeleted"]) {
		NSString *option = TGServiceFormattedText(content[@"text"]);
		return option.length
				? [NSString stringWithFormat:@"%@ deleted the poll option \"%@\"",
						actor, option]
				: [NSString stringWithFormat:@"%@ deleted a poll option", actor];
	}
	if ([type isEqualToString:@"messageManagedBotCreated"]) {
		int64_t managerId = [content[@"manager_bot_user_id"] longLongValue];
		NSString *manager = managerId && userName ? userName(managerId) : nil;
		return manager.length
				? [NSString stringWithFormat:@"%@ created a bot managed by %@",
						actor, manager]
				: [NSString stringWithFormat:@"%@ created a bot", actor];
	}
	if ([type isEqualToString:@"messageTonConnectRequest"]) {
		NSString *dapp = TGServiceString(content, @"dapp_name");
		return dapp.length
				? [NSString stringWithFormat:@"%@ received a request from %@ via TON Connect",
						actor, dapp]
				: [NSString stringWithFormat:@"%@ received a TON Connect request", actor];
	}
	if ([type isEqualToString:@"messageTonWalletTransfer"])
		return [NSString stringWithFormat:@"%@ transferred %@", actor,
				TGServiceTon([content[@"amount"] longLongValue])];
	if ([type isEqualToString:@"messageRefundedUpgradedGift"])
		return [NSString stringWithFormat:@"%@ gift was refunded",
				TGServicePossessive(actor)];
	if ([type isEqualToString:@"messageUpgradedGiftPurchaseOffer"]) {
		NSString *price = TGServicePrice(content[@"price"]);
		return price.length
				? [NSString stringWithFormat:@"%@ offered %@ for a gift", actor, price]
				: [NSString stringWithFormat:@"%@ made an offer to buy a gift", actor];
	}
	if ([type isEqualToString:@"messageUpgradedGiftPurchaseOfferRejected"]) {
		return [content[@"was_expired"] boolValue]
				? [NSString stringWithFormat:@"%@ offer to buy a gift has expired",
						TGServicePossessive(actor)]
				: [NSString stringWithFormat:@"%@ offer to buy a gift was rejected",
						TGServicePossessive(actor)];
	}
	if ([type isEqualToString:@"messageUnsupported"])
		return @"This message is not supported by your version of Telegram. Please update to the latest version.";

	return nil;
}
