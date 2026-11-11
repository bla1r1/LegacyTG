//
// TGClient+EmojiStatus.m - the emoji status lists and the two setters.
//
// getDefaultEmojiStatuses and its chat twin answer custom_emoji_ids, while
// getRecentEmojiStatuses answers whole emojiStatus objects. Both become an
// NSNumber id here, because every screen draws the same sticker grid and the
// only thing a tap needs back is the id.
//
#import "TGClient+EmojiStatus.h"
#import "TGClientInternal.h"

int64_t TGEmojiStatusCustomEmojiId(NSDictionary *status) {
	if (![status isKindOfClass:NSDictionary.class])
		return 0;
	NSDictionary *type = status[@"type"];
	if (![type isKindOfClass:NSDictionary.class])
		return 0;
	NSString *kind = type[@"@type"];
	if ([kind isEqualToString:@"emojiStatusTypeCustomEmoji"])
		return [type[@"custom_emoji_id"] longLongValue];
	if ([kind isEqualToString:@"emojiStatusTypeUpgradedGift"])
		return [type[@"model_custom_emoji_id"] longLongValue];
	return 0;
}

@implementation TGClient (EmojiStatus)

- (int64_t)emojiStatusIdForUser:(int64_t)userId {
	if (userId <= 0)
		return 0;
	NSDictionary *user = self.rawUsersById[@(userId)];
	if (![user isKindOfClass:NSDictionary.class])
		return 0;
	if (user[@"emojiStatusId"])
		return [user[@"emojiStatusId"] longLongValue];
	return TGEmojiStatusCustomEmojiId(user[@"emoji_status"]);
}

- (int64_t)emojiStatusIdForChat:(int64_t)chatId {
	if (chatId == 0)
		return 0;
	NSDictionary *chat = self.chatsById[@(chatId)];
	if ([chat isKindOfClass:NSDictionary.class]) {
		if ([chat[@"isSaved"] boolValue])
			return 0;
		if (chat[@"emojiStatusId"])
			return [chat[@"emojiStatusId"] longLongValue];
		return TGEmojiStatusCustomEmojiId(chat[@"emoji_status"]);
	}
	for (NSDictionary *c in self.chats) {
		if ([c[@"id"] longLongValue] == chatId) {
			if ([c[@"isSaved"] boolValue])
				return 0;
			return [c[@"emojiStatusId"] longLongValue];
		}
	}
	return 0;
}

@end
