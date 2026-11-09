#import "TGGroupCallParticipantCell.h"
#import "TGRows.h"
#import "TGLocalization.h"

NSString *TGGroupCallParticipantDetail(NSDictionary *participant) {
	NSMutableArray *parts = [NSMutableArray array];
	if ([participant[@"isMutedForAllUsers"] boolValue])
		[parts addObject:TGLocalized(@"Muted")];
	else if ([participant[@"isMutedForCurrentUser"] boolValue])
		[parts addObject:TGLocalized(@"Muted for you")];
	else if ([participant[@"isSpeaking"] boolValue])
		[parts addObject:TGLocalized(@"Speaking")];
	if ([participant[@"isHandRaised"] boolValue])
		[parts addObject:TGLocalized(@"Hand raised")];
	if ([participant[@"hasVideo"] boolValue]){
		[parts addObject:[participant[@"videoPaused"] boolValue]
				? TGLocalized(@"Video paused") : TGLocalized(@"Video")];
	}
	NSDictionary *screen = participant[@"screenInfo"];
	if ([screen[@"hasVideo"] boolValue])
		[parts addObject:[screen[@"isPaused"] boolValue]
				? TGLocalized(@"Screen paused")
				: TGLocalized(@"Sharing screen")];
	NSInteger volume = [participant[@"volumeLevel"] integerValue];
	if (volume > 0 && volume != 10000)
		[parts addObject:[NSString stringWithFormat:@"%ld%%",
				(long)(volume / 100)]];
	if ([participant[@"isCurrentUser"] boolValue])
		[parts insertObject:TGLocalized(@"You") atIndex:0];
	if (!parts.count)
		[parts addObject:TGLocalized(@"In the call")];
	return [parts componentsJoinedByString:@" · "];
}

NSMutableDictionary *TGGroupCallParticipantRow(NSDictionary *participant,
		UIColor *accentColour, UIImage *mutedIcon) {
	if (![participant isKindOfClass:NSDictionary.class])
		return nil;

	NSString *name = participant[@"name"];
	if (!name.length)
		name = [participant[@"kind"] isEqualToString:@"chat"]
				? TGLocalized(@"Channel") : TGLocalized(@"Participant");
	int64_t userId = [participant[@"userId"] longLongValue];
	int64_t chatId = [participant[@"chatId"] longLongValue];
	int64_t peerId = userId ?: chatId;

	NSMutableDictionary *row = TGPeerRow(@(peerId), name,
			TGGroupCallParticipantDetail(participant), nil);
	row[TGRowAvatarUser] = @(userId != 0);

	BOOL speaking = [participant[@"isSpeaking"] boolValue] &&
			![participant[@"isMutedForAllUsers"] boolValue];
	row[TGRowOnline] = @(speaking);
	if ([participant[@"isCurrentUser"] boolValue] && accentColour)
		row[TGRowTitleColour] = accentColour;

	BOOL muted = [participant[@"isMutedForAllUsers"] boolValue] ||
			[participant[@"isMutedForCurrentUser"] boolValue];
	if (muted && mutedIcon)
		row[TGRowTrailingImage] = mutedIcon;
	return row;
}

// vim:ft=objc
