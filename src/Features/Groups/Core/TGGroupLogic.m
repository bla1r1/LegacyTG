#import "TGGroupLogic.h"
#import "TGRows.h"
#import "TGBadge.h"
#import "TGLocalization.h"

void TGClearHistoryWindowForChoice(NSInteger choiceIndex, NSDate *now,
								   NSInteger *minDate, NSInteger *maxDate) {
	NSDate *when = now ?: [NSDate date];
	NSTimeInterval stamp = [when timeIntervalSince1970];
	if (choiceIndex == 2){
		// "Today" means today's window, not everything older than yesterday:
		// from local midnight to now.
		NSCalendar *calendar = [NSCalendar currentCalendar];
		NSDateComponents *parts = [calendar components:
				(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit)
				fromDate:when];
		NSDate *midnight = [calendar dateFromComponents:parts];
		if (minDate) *minDate = (NSInteger)[midnight timeIntervalSince1970];
		if (maxDate) *maxDate = (NSInteger)stamp;
		return;
	}
	NSInteger days = choiceIndex == 0 ? 7 : 30;
	if (minDate) *minDate = 0;
	if (maxDate) *maxDate = (NSInteger)(stamp - days * 86400);
}

NSDictionary *TGInviteLinkPreferred(NSArray *links) {
	if (![links isKindOfClass:[NSArray class]])
		return nil;
	for (NSDictionary *link in links)
		if ([link[@"primary"] boolValue] && ![link[@"revoked"] boolValue])
			return link;
	for (NSDictionary *link in links)
		if (![link[@"revoked"] boolValue])
			return link;
	return nil;
}

BOOL TGProfileTypeChangeNeedsDetailsReload(BOOL wasChannel, BOOL isChannel,
										   NSUInteger detailsCount) {
	return wasChannel != isChannel && detailsCount > 0;
}

NSString *TGMemberRowName(NSDictionary *member) {
	if (![member isKindOfClass:NSDictionary.class])
		return nil;
	NSString *name = member[@"name"];
	if (![name isKindOfClass:NSString.class])
		return nil;
	name = [name stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return name.length ? name : nil;
}

NSString *TGStripBoldMarkers(NSString *text) {
	if (!text.length)
		return @"";
	return [text stringByReplacingOccurrencesOfString:@"**" withString:@""];
}

NSDictionary *TGGroupMemberRowModel(NSDictionary *member,
									int64_t statusEmojiId) {
	if (![member isKindOfClass:NSDictionary.class])
		return nil;
	int64_t userId = [member[@"id"] longLongValue];
	NSString *name = TGMemberRowName(member) ?: @"";
	NSMutableDictionary *row = [TGPeerRow(@(userId), name, nil, nil) mutableCopy];
	row[TGRowAvatarUser] = @YES;
	row[TGRowAccessory] = TGRowAccessoryDisclosure;
	if (statusEmojiId > 0)
		row[TGRowStatusEmojiId] = @(statusEmojiId);
	NSString *status = member[@"status"];
	NSString *tag = [member[@"tag"] isKindOfClass:NSString.class]
			? [member[@"tag"] stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]] : nil;
	if ([status isEqualToString:@"owner"]){
		row[TGRowBadge] = tag.length ? tag : TGLocalized(@"Owner");
		row[TGRowBadgeVariant] = @(TGBadgeVariantAccent);
		row[TGRowBadgeInline] = @YES;
	} else if ([status isEqualToString:@"admin"]){
		row[TGRowBadge] = tag.length ? tag : TGLocalized(@"Admin");
		row[TGRowBadgeVariant] = @(TGBadgeVariantMuted);
		row[TGRowBadgeInline] = @YES;
	}
	return row;
}

NSDictionary *TGGroupInfoRowModel(NSString *title, NSString *detail,
								  BOOL opens, BOOL destructive,
								  BOOL disabled) {
	NSMutableDictionary *row = destructive
			? [TGRedRow(title, nil) mutableCopy]
			: [TGRow(TGKindDisclosure, title) mutableCopy];
	if (detail.length)
		row[TGRowDetail] = detail;
	// The value is the group's own name, description or a count; only the
	// label is ours to translate.
	row[TGRowRawDetail] = @YES;
	if (opens)
		row[TGRowOpens] = @YES;
	if (disabled)
		row[TGRowEnabled] = @NO;
	return row;
}
