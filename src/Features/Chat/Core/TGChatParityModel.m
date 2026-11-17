#import "TGChatParityModel.h"
#import "TGLocalization.h"
#import "TGUIFormat.h"
#import "TGMessageStore.h"

// Month.Gen*: the genitive the pack wants after a day ("5 ноября").
static NSString *TGChatMonthName(NSInteger month) {
	static NSArray *names = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		names = @[@"January", @"February", @"March", @"April", @"May", @"June",
				@"July", @"August", @"September", @"October", @"November", @"December"];
	});
	NSString *english = names[(NSUInteger)MAX(0, MIN(11, month))];
	return TGLocalizedKey([@"Month.Gen" stringByAppendingString:english], english);
}

NSArray<NSNumber *> *TGChangedMessageIds(NSArray *oldMessages, NSArray *newMessages) {
	NSMutableDictionary *oldById = [NSMutableDictionary dictionary];
	for (NSDictionary *message in oldMessages){
		if (![message isKindOfClass:NSDictionary.class])
			continue;
		NSNumber *messageId = message[@"id"];
		if ([messageId isKindOfClass:NSNumber.class])
			oldById[messageId] = message;
	}
	NSMutableArray *changed = [NSMutableArray array];
	for (NSDictionary *message in newMessages){
		if (![message isKindOfClass:NSDictionary.class])
			continue;
		NSNumber *messageId = message[@"id"];
		if (![messageId isKindOfClass:NSNumber.class])
			continue;
		NSDictionary *old = oldById[messageId];
		if (!old || ![old isEqualToDictionary:message])
			[changed addObject:messageId];
	}
	return changed;
}

NSString *TGChatDateSeparatorTitle(NSTimeInterval stamp, NSTimeInterval now) {
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:stamp];
	NSDate *today = [NSDate dateWithTimeIntervalSince1970:now];
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSUInteger units = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
	NSDateComponents *day = [calendar components:units fromDate:date];
	NSDateComponents *current = [calendar components:units fromDate:today];
	if (day.year == current.year && day.month == current.month &&
			day.day == current.day)
		return TGLocalized(@"Today");
	// ChatMessageDateHeader.swift: Date.ChatDateHeader(month, day). The
	// English "%1$@ %2$@" is shared by other keys, so look it up by key to
	// keep each language's own order.
	NSString *month = TGChatMonthName(day.month - 1);
	NSString *dayText = [NSString stringWithFormat:@"%ld", (long)day.day];
	if (day.year == current.year)
		return [NSString stringWithFormat:
				TGLocalizedKey(@"Date.ChatDateHeader", @"%1$@ %2$@"), month, dayText];
	return [NSString stringWithFormat:
			TGLocalizedKey(@"Date.ChatDateHeaderYear", @"%1$@ %2$@, %3$@"),
			month, dayText, [NSString stringWithFormat:@"%ld", (long)day.year]];
}

NSString *TGChatComposerPlaceholder(BOOL isChannel, BOOL silentPosting,
		BOOL canBeAnonymous) {
	if (isChannel)
		return silentPosting ? TGLocalized(@"Silent Broadcast")
							 : TGLocalized(@"Broadcast");
	if (canBeAnonymous)
		return TGLocalized(@"Send anonymously");
	return TGLocalized(@"Message");
}

NSArray<NSString *> *TGChatDeleteChoices(BOOL isPrivateChat, NSInteger count) {
	if (isPrivateChat)
		return @[TGLocalized(@"Delete for All"), TGLocalized(@"Delete for me")];
	NSString *number = [NSString stringWithFormat:@"%ld", (long)count];
	return @[TGLocalizedPluralValue(@"Delete %d Chat", @"Delete %@ Chats",
			number, count)];
}

BOOL TGChatRowIsSelectable(BOOL editing, BOOL canSwipe, BOOL validChatRow) {
	if (!validChatRow)
		return NO;
	return editing || canSwipe;
}

NSArray<NSNumber *> *TGSelectedChatIdsInOrder(NSArray *chats, NSSet *selected) {
	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *chat in chats){
		NSNumber *chatId = chat[@"id"];
		if ([chatId isKindOfClass:NSNumber.class] && [selected containsObject:chatId])
			[ids addObject:chatId];
	}
	return ids;
}

NSArray<NSDictionary *> *TGStoryRowsForList(NSArray *fresh, NSArray *old,
		NSString *list) {
	NSString *wanted = list.length ? list : @"main";
	NSMutableArray *merged = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];
	for (NSDictionary *row in fresh){
		if (![row isKindOfClass:NSDictionary.class])
			continue;
		NSString *rowList = row[@"list"];
		if (rowList.length && ![rowList isEqualToString:wanted])
			continue;
		NSNumber *chatId = row[@"chatId"];
		if (![chatId isKindOfClass:NSNumber.class])
			continue;
		[merged addObject:row];
		[seen addObject:chatId];
	}
	for (NSDictionary *row in old){
		if (![row isKindOfClass:NSDictionary.class])
			continue;
		NSString *rowList = row[@"list"];
		if (rowList.length && ![rowList isEqualToString:wanted])
			continue;
		NSNumber *chatId = row[@"chatId"];
		if (![chatId isKindOfClass:NSNumber.class] || [seen containsObject:chatId])
			continue;
		[merged addObject:row];
		[seen addObject:chatId];
	}
	return merged;
}

BOOL TGChatFolderAnswerStillWanted(NSInteger askedFolder, NSInteger currentFolder) {
	return askedFolder == currentFolder;
}

BOOL TGChatSearchHitOpensMessage(NSDictionary *hit) {
	if (![hit isKindOfClass:NSDictionary.class])
		return NO;
	return hit[@"chatId"] != nil && hit[@"id"] != nil;
}

BOOL TGChatDeleteDefersToCommit(BOOL revoke) {
	return !revoke;
}

BOOL TGChatStatusNotificationRefreshesPresence(NSString *noteName, BOOL isGroup,
		BOOL isSecret) {
	return [noteName isEqualToString:TGUserStatusChangedNotification] &&
			!isGroup && !isSecret;
}

NSString *TGChatChannelMuteTitle(BOOL muted) {
	// Conversation.Mute / Unmute, the short words official's channel bar
	// uses. By key: the English "Mute" is also the call screen's microphone.
	return muted ? TGLocalizedKey(@"Conversation.Unmute", @"Unmute")
				 : TGLocalizedKey(@"Conversation.Mute", @"Mute");
}

CGFloat TGBotKeyboardPanelHeight(NSInteger rows, BOOL resize, CGFloat standard,
		CGFloat gap, CGFloat *keyPitch) {
	CGFloat pitch = *keyPitch;
	if (rows <= 0)
		return 0;
	CGFloat natural = rows * pitch + gap;
	if (resize)
		return MIN(natural, standard);
	if (natural < standard)
		*keyPitch = floorf((standard - gap) / rows);
	return standard;
}

void TGChatNavigationButtonOffsets(BOOL down, NSInteger mentions, NSInteger reactions,
		NSInteger pollVotes, CGFloat pitch, CGFloat *mentionsY, CGFloat *reactionsY,
		CGFloat *pollVotesY) {
	CGFloat y = down ? pitch : 0;
	*mentionsY = mentions > 0 ? y : -1;
	if (mentions > 0)
		y += pitch;
	*reactionsY = reactions > 0 ? y : -1;
	if (reactions > 0)
		y += pitch;
	*pollVotesY = pollVotes > 0 ? y : -1;
}

NSString *TGPaidResendConfirmText(NSString *chatName, int64_t stars) {
	NSString *value = [NSString stringWithFormat:@"%lld", stars];
	NSString *price = TGLocalizedPluralValue(@"%@ Star", @"%@ Stars", value, (NSInteger)stars);
	NSString *count = TGLocalizedPluralValue(@"**%@** message", @"**%@** messages", @"1", 1);
	NSString *text = TGLocalizedFormat(@"**%1$@** charges **%2$@** per incoming message. Would you like to pay **%3$@** to send %4$@?",
			chatName ?: @"", price, price, count);
	return [text stringByReplacingOccurrencesOfString:@"**" withString:@""];
}

NSString *TGJoinRequestInfoText(NSString *chatTitle, NSString *day) {
	return TGLocalizedFormat(@"You received this message because you requested to join %1$@ on %2$@.",
			chatTitle ?: @"", day ?: @"");
}

/// "3 days ago", "5 hours ago", "12 minutes ago" (Chat.NonContactUser.Updated*).
static NSString *TGUpdatedAgo(NSTimeInterval seconds) {
	NSInteger value;
	if (seconds >= 86400){
		value = (NSInteger)(seconds / 86400);
		return TGLocalizedPluralValue(@"%@ day ago", @"%@ days ago",
				[NSString stringWithFormat:@"%ld", (long)value], value);
	}
	if (seconds >= 3600){
		value = (NSInteger)(seconds / 3600);
		return TGLocalizedPluralValue(@"%@ hour ago", @"%@ hours ago",
				[NSString stringWithFormat:@"%ld", (long)value], value);
	}
	value = MAX(1, (NSInteger)(seconds / 60));
	return TGLocalizedPluralValue(@"%@ minute ago", @"%@ minutes ago",
			[NSString stringWithFormat:@"%ld", (long)value], value);
}

NSArray *TGNewContactCardRows(NSDictionary *account, NSString *country,
		NSTimeInterval now) {
	if (![account isKindOfClass:NSDictionary.class])
		return @[];
	NSMutableArray *rows = [NSMutableArray array];
	if (country.length)
		[rows addObject:@[TGLocalized(@"Phone Number"), country]];
	NSInteger month = [account[@"registrationMonth"] integerValue];
	NSInteger year = [account[@"registrationYear"] integerValue];
	if (month >= 1 && month <= 12 && year > 0){
		static NSString *const months[] = {@"January", @"February", @"March", @"April", @"May",
				@"June", @"July", @"August", @"September", @"October", @"November", @"December"};
		[rows addObject:@[TGLocalized(@"Registration"),
				[NSString stringWithFormat:@"%@ %ld", TGLocalized(months[month - 1]), (long)year]]];
	}
	double name = [account[@"nameChanged"] doubleValue];
	if (name > 0 && now > name)
		[rows addObject:@[TGLocalizedFormat(@"User updated name %1$@", TGUpdatedAgo(now - name))]];
	double photo = [account[@"photoChanged"] doubleValue];
	if (photo > 0 && now > photo)
		[rows addObject:@[TGLocalizedFormat(@"User updated photo %1$@", TGUpdatedAgo(now - photo))]];
	return rows;
}

NSString *TGPaidMessagePlaceholder(int64_t stars) {
	if (stars <= 0)
		return nil;
	NSString *value = [NSString stringWithFormat:@"%lld", stars];
	return TGLocalizedFormat(@"Message for %@",
			TGLocalizedPluralValue(@"%@ Star", @"%@ Stars", value, (NSInteger)stars));
}

NSString *TGForwardHeaderLine(NSString *from, NSString *psaType) {
	NSString *line;
	if (!psaType.length)
		line = TGLocalizedFormat(@"Forwarded from: %@", from ?: @"");
	else if ([psaType isEqualToString:@"covid"])
		line = TGLocalizedFormat(@"Covid-19 Notification\nFrom: %@", from ?: @"");
	else
		line = TGLocalizedFormat(@"Public Service Announcement\nFrom: %@", from ?: @"");
	return [line stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
}

NSString *TGGiveawayInfoText(NSDictionary *info, NSString *chatTitle) {
	if (![info isKindOfClass:NSDictionary.class])
		return TGLocalized(@"An error occurred.");
	NSString *chat = chatTitle ?: @"";
	NSString *text;
	if ([info[@"isEnded"] boolValue] || [info[@"isWinner"] boolValue]){
		if ([info[@"isWinner"] boolValue])
			text = [TGLocalizedFormat(@"You won a prize in this giveaway. %@", info[@"giftCode"] ?: @"")
					stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		else
			text = TGLocalized(@"You didn't win a prize in this giveaway.");
		// Official's ended sheet says who picked whom, naming the other
		// channels when there were some (GiveawayInfoController .finished:
		// Chat.Giveaway.Info.Ended / EndedMany by additional channels).
		double selected = [info[@"selectionDate"] doubleValue];
		NSInteger winners = [info[@"winnerCount"] integerValue];
		if (selected > 0 && winners > 0) {
			NSString *count = [NSString stringWithFormat:@"%ld", (long)winners];
			NSString *who = [info[@"isGroup"] boolValue]
					? TGLocalizedPluralValue(@"**%@** random member", @"**%@** random members", count, winners)
					: TGLocalizedPluralValue(@"**%@** random subscriber", @"**%@** random subscribers", count, winners);
			NSString *date = TGAppDate(selected, NSDateFormatterMediumStyle, NSDateFormatterNoStyle) ?: @"";
			NSString *ending = [info[@"additionalChatCount"] integerValue] > 0
					? TGLocalizedFormat(@"On **%1$@**, Telegram automatically selected %2$@ of **%3$@** and other listed channels.", date, who, chat)
					: TGLocalizedFormat(@"On **%1$@**, Telegram automatically selected %2$@ of **%3$@**.", date, who, chat);
			text = [NSString stringWithFormat:@"%@\n\n%@", text, ending];
		}
		NSInteger used = [info[@"activationCount"] integerValue];
		if (used > 0)
			text = [NSString stringWithFormat:@"%@\n\n%@", text,
					TGLocalizedPluralValue(@"%@ winner already used their gift link.",
							@"%@ of the winners already used their gift links.",
							[NSString stringWithFormat:@"%ld", (long)used], used)];
	} else {
		NSString *status = info[@"status"];
		if ([status isEqualToString:@"giveawayParticipantStatusParticipating"])
			text = TGLocalizedFormat(@"You are participating in this giveaway, because you have joined the channel **%1$@**.", chat);
		else if ([status isEqualToString:@"giveawayParticipantStatusDisallowedCountry"])
			text = TGLocalized(@"You are not eligible to participate in this giveaway, because your country is not included in the terms of the giveaway.");
		else if ([status isEqualToString:@"giveawayParticipantStatusAlreadyWasMember"])
			text = TGLocalizedFormat(@"You are not eligible to participate in this giveaway, because you joined this channel on **%@**, which is before the contest started.",
					TGAppDate([info[@"statusDate"] doubleValue], NSDateFormatterMediumStyle, NSDateFormatterNoStyle) ?: @"");
		else if ([status isEqualToString:@"giveawayParticipantStatusAdministrator"])
			text = TGLocalizedFormat(@"You are not eligible to participate in this giveaway, because you are an admin of participating channel (**%@**).", chat);
		else
			text = TGLocalized(@"The giveaway is almost over.");
	}
	return [text stringByReplacingOccurrencesOfString:@"**" withString:@""];
}

NSString *TGBusinessBotStatus(NSDictionary *bot) {
	if (![bot[@"canReply"] boolValue])
		return TGLocalized(@"bot has access to this chat");
	return [bot[@"paused"] boolValue] ? TGLocalized(@"bot paused") : TGLocalized(@"bot manages this chat");
}

NSArray<NSNumber *> *TGSecretKeyCells(NSData *keyHash) {
	const uint8_t *bytes = keyHash.bytes;
	NSUInteger length = keyHash.length;
	NSMutableArray *cells = [NSMutableArray arrayWithCapacity:144];
	for (NSUInteger i = 0; i < 144; i++){
		NSUInteger byte = i / 4;
		uint8_t value = byte < length ? bytes[byte] : 0;
		[cells addObject:@((value >> (2 * (i % 4))) & 3)];
	}
	return cells;
}

NSString *TGSecretKeyHex(NSData *keyHash) {
	const uint8_t *bytes = keyHash.bytes;
	NSUInteger count = MIN(keyHash.length, (NSUInteger)32);
	NSMutableString *out = [NSMutableString string];
	for (NSUInteger i = 0; i < count; i++){
		[out appendFormat:@"%02X", bytes[i]];
		if (i + 1 < count)
			[out appendString:(i % 8 == 7) ? @"\n" : @" "];
	}
	return out;
}
