#import "TGChatParityModel.h"
#import "TGLocalization.h"
#import "TGClientNotifications.h"

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
