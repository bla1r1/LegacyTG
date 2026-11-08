#import "TGServiceMessageText.h"
#import "TGClientInternal.h"
#import "TGLocalization.h"
#include <vector>
#include <algorithm>

#ifndef typeof
#define typeof __typeof__
#endif

/// Preview text for a chat's last message, for the types it knows by name.
/// Returns nil for everything else, so callers can tell "known, said this"
/// from "unknown, you are on your own". TDLib nests the content by type.
/// A service action's sentence with the names this client already holds, or
/// nil when the message is not a service action. The chat list shows it as
/// is: the actor is inside the sentence, so no "Name:" goes in front.
NSString *TGServicePreview(NSDictionary *message) {
	return TGServiceMessageText(message,
			^NSString *(int64_t userId){ return [[TGClient shared] nameForUserId:userId]; },
			^NSString *(int64_t chatId){
				NSString *title = [TGClient shared].chatsById[@(chatId)][@"title"];
				return [title isKindOfClass:NSString.class] && title.length ? title : nil;
			});
}

/// Custom emoji entities for the chat list's preview line. When the preview
/// begins with the message's text/caption, entities that fit within the preview
/// are returned; entities that extend beyond its end (if cut) are dropped.
NSArray *TGPreviewCustomEmoji(NSString *previewText, NSString *messageText, NSArray *entities) {
	if (![previewText isKindOfClass:NSString.class] || ![messageText isKindOfClass:NSString.class] ||
		![entities isKindOfClass:NSArray.class] || previewText.length == 0 || messageText.length == 0 ||
		entities.count == 0) {
		return @[];
	}

	NSUInteger checkLen = MIN(previewText.length, messageText.length);
	if (![[previewText substringToIndex:checkLen] isEqualToString:[messageText substringToIndex:checkLen]]) {
		return @[];
	}

	NSMutableArray *result = [NSMutableArray array];
	for (id item in entities) {
		NSInteger offset = 0;
		NSInteger length = 0;
		int64_t emojiId = 0;

		if ([item isKindOfClass:NSDictionary.class]) {
			NSDictionary *dict = (NSDictionary *)item;
			id typeObj = dict[@"type"];
			if ([typeObj isKindOfClass:NSDictionary.class]) {
				NSString *typeStr = typeObj[@"@type"];
				if ([typeStr isKindOfClass:NSString.class] && [typeStr isEqualToString:@"textEntityTypeCustomEmoji"]) {
					id rawId = typeObj[@"custom_emoji_id"];
					if ([rawId isKindOfClass:NSNumber.class] || [rawId isKindOfClass:NSString.class]) {
						emojiId = [rawId longLongValue];
					}
				}
			}
			if (emojiId == 0) {
				id rawId = dict[@"customEmojiId"] ?: dict[@"custom_emoji_id"];
				if ([rawId isKindOfClass:NSNumber.class] || [rawId isKindOfClass:NSString.class]) {
					emojiId = [rawId longLongValue];
				}
			}
			id offsetObj = dict[@"offset"];
			id lengthObj = dict[@"length"];
			if (([offsetObj isKindOfClass:NSNumber.class] || [offsetObj isKindOfClass:NSString.class]) &&
				([lengthObj isKindOfClass:NSNumber.class] || [lengthObj isKindOfClass:NSString.class])) {
				offset = [offsetObj integerValue];
				length = [lengthObj integerValue];
			}
		} else if ([item isKindOfClass:NSArray.class]) {
			NSArray *arr = (NSArray *)item;
			if (arr.count >= 3) {
				id offsetObj = arr[0];
				id lengthObj = arr[1];
				id idObj = arr[2];
				if (([offsetObj isKindOfClass:NSNumber.class] || [offsetObj isKindOfClass:NSString.class]) &&
					([lengthObj isKindOfClass:NSNumber.class] || [lengthObj isKindOfClass:NSString.class]) &&
					([idObj isKindOfClass:NSNumber.class] || [idObj isKindOfClass:NSString.class])) {
					offset = [offsetObj integerValue];
					length = [lengthObj integerValue];
					emojiId = [idObj longLongValue];
				}
			}
		}

		if (emojiId <= 0 || offset < 0 || length <= 0) {
			continue;
		}

		if ((NSUInteger)(offset + length) > previewText.length ||
			(NSUInteger)(offset + length) > messageText.length) {
			continue;
		}

		[result addObject:@{
			@"offset"        : @(offset),
			@"length"        : @(length),
			@"customEmojiId" : @(emojiId),
		}];
	}

	[result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
		NSInteger offA = [a[@"offset"] integerValue];
		NSInteger offB = [b[@"offset"] integerValue];
		if (offA < offB) return NSOrderedAscending;
		if (offA > offB) return NSOrderedDescending;
		return NSOrderedSame;
	}];

	return result;
}

NSString *TGKnownMessagePreview(NSDictionary *message) {
	NSDictionary *content = message[@"content"];
	NSString *ctype = content[@"@type"];

	NSString *service = TGServicePreview(message);
	if (service)
		return service;

	// The caption is what the sender wrote, so it beats the media's own label.
	if ([ctype isEqualToString:@"messagePhoto"] ||
		[ctype isEqualToString:@"messageVideo"] ||
		[ctype isEqualToString:@"messageAnimation"] ||
		[ctype isEqualToString:@"messageAudio"] ||
		[ctype isEqualToString:@"messageDocument"] ||
		[ctype isEqualToString:@"messageVoiceNote"] ||
		[ctype isEqualToString:@"messagePaidMedia"]){
		NSString *caption = content[@"caption"][@"text"];
		if (caption.length)
			return caption;
	}

	if ([ctype isEqualToString:@"messageText"])
		return content[@"text"][@"text"] ?: @"";
	if ([ctype isEqualToString:@"messagePhoto"])
		return @"Photo";
	if ([ctype isEqualToString:@"messageVideo"])
		return @"Video";
	if ([ctype isEqualToString:@"messageVoiceNote"])
		return @"Voice message";
	if ([ctype isEqualToString:@"messageVideoNote"])
		return @"Video message";
	if ([ctype isEqualToString:@"messageSticker"]){
		NSString *emoji = content[@"sticker"][@"emoji"];
		return emoji.length ? [emoji stringByAppendingString:@" Sticker"] : @"Sticker";
	}
	if ([ctype isEqualToString:@"messageDocument"]){
		NSString *name = content[@"document"][@"file_name"];
		return name.length ? name : @"File";
	}
	if ([ctype isEqualToString:@"messageAudio"]){
		NSString *performer = content[@"audio"][@"performer"];
		NSString *title = content[@"audio"][@"title"];
		if (performer.length && title.length)
			return [NSString stringWithFormat:@"%@ – %@", performer, title];
		if (performer.length || title.length)
			return performer.length ? performer : title;
		return @"Music";
	}
	if ([ctype isEqualToString:@"messageAnimation"])
		return @"GIF";
	if ([ctype isEqualToString:@"messageAnimatedEmoji"])
		return content[@"emoji"] ?: @"Emoji";
	if ([ctype isEqualToString:@"messageContact"]){
		NSString *first = content[@"contact"][@"first_name"];
		NSString *last = content[@"contact"][@"last_name"];
		NSString *name = [@[first ?: @"", last ?: @""] componentsJoinedByString:@" "];
		name = [name stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceCharacterSet]];
		return name.length ? name : @"Contact";
	}
	if ([ctype isEqualToString:@"messageVenue"]){
		NSString *title = content[@"venue"][@"title"];
		return title.length ? title : @"Venue";
	}
	if ([ctype isEqualToString:@"messageLocation"]){
		BOOL live = [content[@"live_period"] longLongValue] > 0 ||
					[content[@"location"][@"live_period"] longLongValue] > 0;
		return live ? @"Live Location" : @"Location";
	}
	if ([ctype isEqualToString:@"messageLiveLocation"])
		return @"Live Location";
	if ([ctype isEqualToString:@"messagePoll"]){
		NSString *question = content[@"poll"][@"question"][@"text"];
		if (!question.length)
			return @"Poll";
		BOOL quiz = [content[@"poll"][@"type"][@"@type"]
					 isEqualToString:@"pollTypeQuiz"];
		return quiz ? [@"📊 Quiz: " stringByAppendingString:question]
					: [@"📊 " stringByAppendingString:question];
	}
	if ([ctype isEqualToString:@"messageChecklist"]){
		NSString *title = content[@"list"][@"title"][@"text"];
		return title.length ? [@"☑️ " stringByAppendingString:title]
				: TGLocalized(@"Checklist");
	}
	if ([ctype isEqualToString:@"messageDice"]){
		NSString *emoji = content[@"emoji"];
		return emoji.length ? emoji : @"Dice";
	}
	if ([ctype isEqualToString:@"messageGame"]){
		NSString *title = content[@"game"][@"title"];
		return title.length ? [@"🎮 " stringByAppendingString:title]
				: [@"🎮 " stringByAppendingString:TGLocalized(@"Game")];
	}
	if ([ctype isEqualToString:@"messageInvoice"]){
		NSString *title = content[@"product_info"][@"title"];
		return title.length ? title : @"Invoice";
	}
	if ([ctype isEqualToString:@"messagePaidMedia"])
		return @"Paid media";
	if ([ctype isEqualToString:@"messageGiveaway"])
		return @"Giveaway";
	if ([ctype isEqualToString:@"messageGiveawayWinners"])
		return @"Giveaway results";
	if ([ctype isEqualToString:@"messageGift"])
		return [@"🎁 " stringByAppendingString:TGLocalized(@"Gift")];
	if ([ctype isEqualToString:@"messageUpgradedGift"]){
		NSString *title = content[@"gift"][@"title"];
		return title.length ? [@"🎁 " stringByAppendingString:title]
				: [@"🎁 " stringByAppendingString:TGLocalized(@"Gift")];
	}
	if ([ctype isEqualToString:@"messageStory"])
		return @"Story";
	if ([ctype isEqualToString:@"messageCall"]){
		NSString *reason = content[@"discard_reason"][@"@type"];
		BOOL video = [content[@"is_video"] boolValue];
		if ([reason isEqualToString:@"callDiscardReasonMissed"] ||
			[reason isEqualToString:@"callDiscardReasonDeclined"])
			return video ? @"Missed video call" : @"Missed call";
		// A message with no is_outgoing is not a real one, but callers that
		// only know the type still get a sensible word.
		if (!message[@"is_outgoing"])
			return video ? @"Video call" : @"Call";
		BOOL outgoing = [message[@"is_outgoing"] boolValue];
		if (video)
			return outgoing ? @"Outgoing video call" : @"Incoming video call";
		return outgoing ? @"Outgoing call" : @"Incoming call";
	}
	if ([ctype isEqualToString:@"messageRichMessage"]){
		NSString *t = TGRichMessageText(content);
		return t.length ? t : @"Rich message";
	}
	return nil;
}

/// Preview text for a chat's last message. The unknown tail reads as its own
/// type name turned back into a sentence, the same way the chat renders it.
NSString *TGMessagePreview(NSDictionary *message) {
	NSString *known = TGKnownMessagePreview(message);
	if (known) return known;
	NSString *ctype = message[@"content"][@"@type"];
	return ctype.length ? TGPhraseFromTypeName(ctype) : @"";
}

/// Chats are ordered by the "order" of their position in a list. It is an
/// int64 sent as a string, so it must not be compared as a string.
int64_t TGOrderInList(NSArray *positions, NSString *listType) {
	for (NSDictionary *p in positions){
		NSDictionary *list = p[@"list"];
		if ([list[@"@type"] isEqualToString:listType])
			return (int64_t)[p[@"order"] longLongValue];
	}
	return 0;
}

BOOL TGPinnedInMain(NSArray *positions) {
	for (NSDictionary *p in positions)
		if ([p[@"list"][@"@type"] isEqualToString:@"chatListMain"])
			return [p[@"is_pinned"] boolValue];
	return NO;
}

int64_t TGMainListOrder(NSArray *positions) {
	return TGOrderInList(positions, @"chatListMain");
}

int64_t TGArchiveOrder(NSArray *positions) {
	return TGOrderInList(positions, @"chatListArchive");
}
