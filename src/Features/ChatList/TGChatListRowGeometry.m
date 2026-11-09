#import "TGChatListRowGeometry.h"
#import "TGLocalization.h"

NSString *TGChatListArchiveSubtitle(NSUInteger count) {
	return TGLocalizedPlural(@"%d chat", @"%d chats", (NSInteger)count);
}

void TGChatListRowAccessories(CGFloat rightEdge,
                              CGFloat top,
                              BOOL hasBadge,
                              CGFloat badgeWidth,
                              CGFloat badgeHeight,
                              BOOL hasPin,
                              CGFloat pinSide,
                              CGFloat gap,
                              CGRect *badgeFrame,
                              CGRect *pinFrame,
                              CGFloat *previewRight) {
	CGFloat x = rightEdge;

	if (hasBadge){
		if (badgeFrame)
			*badgeFrame = CGRectMake(x - badgeWidth, top, badgeWidth, badgeHeight);
		x -= badgeWidth + gap;
	} else if (badgeFrame){
		*badgeFrame = CGRectZero;
	}

	if (hasPin){
		if (pinFrame)
			*pinFrame = CGRectMake(x - pinSide,
					top + (badgeHeight - pinSide) * 0.5f, pinSide, pinSide);
		x -= pinSide + gap;
	} else if (pinFrame){
		*pinFrame = CGRectZero;
	}

	if (previewRight)
		*previewRight = x;
}

NSRange TGAvatarWindow(NSInteger firstVisible, NSUInteger rows, NSUInteger total) {
	NSUInteger start = firstVisible > 1 ? (NSUInteger)(firstVisible - 1) : 0;
	if (start >= total)
		return NSMakeRange(total, 0);
	return NSMakeRange(start, MIN(rows, total - start));
}

/// Custom emoji ranges as the row reads them, { offset, length, customEmojiId }
/// or [offset, length, id], reduced to numbers so the list stays a plist.
NSArray *TGSnapshotCustomEmoji(id value) {
	if (![value isKindOfClass:NSArray.class])
		return nil;
	NSMutableArray *out = [NSMutableArray array];
	for (id item in value){
		NSNumber *offset = nil, *length = nil, *emojiId = nil;
		if ([item isKindOfClass:NSDictionary.class]){
			offset = item[@"offset"]; length = item[@"length"]; emojiId = item[@"customEmojiId"];
		} else if ([item isKindOfClass:NSArray.class] && [item count] >= 3){
			offset = item[0]; length = item[1]; emojiId = item[2];
		}
		if (![offset isKindOfClass:NSNumber.class] || ![length isKindOfClass:NSNumber.class])
			continue;
		if ([emojiId isKindOfClass:NSString.class])
			emojiId = @([(NSString *)emojiId longLongValue]);
		if (![emojiId isKindOfClass:NSNumber.class] || emojiId.longLongValue == 0)
			continue;
		[out addObject:@{@"offset" : offset, @"length" : length, @"customEmojiId" : emojiId}];
	}
	return out;
}
