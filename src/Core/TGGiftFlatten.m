//
// TGGiftFlatten.m - flatten TDLib receivedGift records down to row and viewer fields.
//
#import "TGGiftFlatten.h"

/// Resolves still picture file id from a sticker: prefers an explicit still
/// picture thumbnail (webp, jpeg, png), falling back to the sticker's own
/// file id only when the sticker is a still WebP image.
static NSNumber *TGExtractPictureFileId(NSDictionary *sticker) {
	if (![sticker isKindOfClass:[NSDictionary class]])
		return nil;

	NSDictionary *thumbnail = [sticker[@"thumbnail"] isKindOfClass:[NSDictionary class]]
			? sticker[@"thumbnail"] : nil;
	if (thumbnail) {
		id formatObj = thumbnail[@"format"];
		NSString *thumbFormat = [formatObj isKindOfClass:[NSDictionary class]]
				? formatObj[@"@type"]
				: ([formatObj isKindOfClass:[NSString class]] ? formatObj : @"");
		BOOL thumbIsPicture = [thumbFormat isEqualToString:@"thumbnailFormatWebp"] ||
							  [thumbFormat isEqualToString:@"thumbnailFormatJpeg"] ||
							  [thumbFormat isEqualToString:@"thumbnailFormatPng"];
		if (thumbIsPicture) {
			id fileObj = thumbnail[@"file"];
			id fileId = [fileObj isKindOfClass:[NSDictionary class]] ? fileObj[@"id"] : fileObj;
			if ([fileId respondsToSelector:@selector(intValue)] && [fileId intValue] > 0)
				return @([fileId intValue]);
		}
	}

	id formatObj = sticker[@"format"];
	NSString *stickerFormat = [formatObj isKindOfClass:[NSDictionary class]]
			? formatObj[@"@type"]
			: ([formatObj isKindOfClass:[NSString class]] ? formatObj : @"");
	if ([stickerFormat isEqualToString:@"stickerFormatWebp"]) {
		id stickerFile = sticker[@"sticker"];
		id fileId = [stickerFile isKindOfClass:[NSDictionary class]] ? stickerFile[@"id"] : stickerFile;
		if ([fileId respondsToSelector:@selector(intValue)] && [fileId intValue] > 0)
			return @([fileId intValue]);
	}

	return nil;
}

static NSNumber *TGExtractStickerFileId(NSDictionary *sticker) {
	if (![sticker isKindOfClass:[NSDictionary class]])
		return nil;
	id stickerFile = sticker[@"sticker"];
	id fileId = [stickerFile isKindOfClass:[NSDictionary class]] ? stickerFile[@"id"] : stickerFile;
	if ([fileId respondsToSelector:@selector(intValue)] && [fileId intValue] > 0)
		return @([fileId intValue]);
	return nil;
}

NSDictionary *TGFlattenReceivedGift(NSDictionary *receivedGift) {
	if (![receivedGift isKindOfClass:[NSDictionary class]])
		return nil;

	NSString *receivedGiftId = @"";
	id rawRId = receivedGift[@"received_gift_id"];
	if ([rawRId isKindOfClass:[NSString class]]) {
		receivedGiftId = rawRId;
	} else if ([rawRId respondsToSelector:@selector(stringValue)]) {
		receivedGiftId = [rawRId stringValue];
	}

	int64_t senderUserId = 0;
	int64_t senderChatId = 0;
	id senderId = receivedGift[@"sender_id"];
	if ([senderId isKindOfClass:[NSDictionary class]]) {
		id uid = senderId[@"user_id"];
		if ([uid respondsToSelector:@selector(longLongValue)])
			senderUserId = [uid longLongValue];
		id cid = senderId[@"chat_id"];
		if ([cid respondsToSelector:@selector(longLongValue)])
			senderChatId = [cid longLongValue];
	}
	if (senderUserId == 0 && [receivedGift[@"sender_user_id"] respondsToSelector:@selector(longLongValue)])
		senderUserId = [receivedGift[@"sender_user_id"] longLongValue];
	if (senderChatId == 0 && [receivedGift[@"sender_chat_id"] respondsToSelector:@selector(longLongValue)])
		senderChatId = [receivedGift[@"sender_chat_id"] longLongValue];

	int32_t date = 0;
	id rawDate = receivedGift[@"date"];
	if ([rawDate respondsToSelector:@selector(intValue)])
		date = [rawDate intValue];

	NSString *note = @"";
	id rawText = receivedGift[@"text"];
	if ([rawText isKindOfClass:[NSDictionary class]]) {
		id inner = rawText[@"text"];
		if ([inner isKindOfClass:[NSString class]])
			note = inner;
	} else if ([rawText isKindOfClass:[NSString class]]) {
		note = rawText;
	}
	if (note.length == 0) {
		id rawMsg = receivedGift[@"message"];
		if ([rawMsg isKindOfClass:[NSDictionary class]] && [rawMsg[@"text"] isKindOfClass:[NSString class]])
			note = rawMsg[@"text"];
		else if ([rawMsg isKindOfClass:[NSString class]])
			note = rawMsg;
	}

	BOOL isPrivate = [receivedGift[@"is_private"] respondsToSelector:@selector(boolValue)]
			? [receivedGift[@"is_private"] boolValue] : NO;
	BOOL isSaved = [receivedGift[@"is_saved"] respondsToSelector:@selector(boolValue)]
			? [receivedGift[@"is_saved"] boolValue] : NO;
	BOOL isPinned = [receivedGift[@"is_pinned"] respondsToSelector:@selector(boolValue)]
			? [receivedGift[@"is_pinned"] boolValue] : NO;
	BOOL canBeUpgraded = [receivedGift[@"can_be_upgraded"] respondsToSelector:@selector(boolValue)]
			? [receivedGift[@"can_be_upgraded"] boolValue] : NO;
	BOOL canBeTransferred = [receivedGift[@"can_be_transferred"] respondsToSelector:@selector(boolValue)]
			? [receivedGift[@"can_be_transferred"] boolValue] : NO;
	BOOL wasRefunded = [receivedGift[@"was_refunded"] respondsToSelector:@selector(boolValue)]
			? [receivedGift[@"was_refunded"] boolValue] : NO;

	int64_t sellStarCount = 0;
	id rawSell = receivedGift[@"sell_star_count"];
	if ([rawSell respondsToSelector:@selector(longLongValue)])
		sellStarCount = [rawSell longLongValue];

	BOOL isCollectible = NO;
	NSDictionary *giftObj = nil;
	id rawGift = receivedGift[@"gift"];
	if ([rawGift isKindOfClass:[NSDictionary class]]) {
		NSString *type = rawGift[@"@type"];
		if ([type isEqualToString:@"sentGiftUpgraded"]) {
			isCollectible = YES;
			id inner = rawGift[@"gift"];
			giftObj = [inner isKindOfClass:[NSDictionary class]] ? inner : rawGift;
		} else if ([type isEqualToString:@"sentGiftRegular"]) {
			isCollectible = NO;
			id inner = rawGift[@"gift"];
			giftObj = [inner isKindOfClass:[NSDictionary class]] ? inner : rawGift;
		} else if ([type isEqualToString:@"upgradedGift"]) {
			isCollectible = YES;
			giftObj = rawGift;
		} else if ([type isEqualToString:@"gift"]) {
			isCollectible = NO;
			giftObj = rawGift;
		} else {
			id inner = rawGift[@"gift"];
			if ([inner isKindOfClass:[NSDictionary class]]) {
				NSString *innerType = inner[@"@type"];
				if ([innerType isEqualToString:@"upgradedGift"] || inner[@"model"] != nil)
					isCollectible = YES;
				giftObj = inner;
			} else {
				if (rawGift[@"model"] != nil || rawGift[@"backdrop"] != nil)
					isCollectible = YES;
				giftObj = rawGift;
			}
		}
	}

	NSMutableDictionary *out = [NSMutableDictionary dictionaryWithDictionary:@{
		@"receivedGiftId"  : receivedGiftId,
		@"senderUserId"    : @(senderUserId),
		@"senderChatId"    : @(senderChatId),
		@"date"            : @(date),
		@"note"            : note,
		@"isPrivate"       : @(isPrivate),
		@"isSaved"         : @(isSaved),
		@"isPinned"        : @(isPinned),
		@"canBeUpgraded"   : @(canBeUpgraded),
		@"canBeTransferred": @(canBeTransferred),
		@"wasRefunded"     : @(wasRefunded),
		@"sellStarCount"   : @(sellStarCount),
		@"isCollectible"   : @(isCollectible),
	}];

	if (note.length > 0)
		out[@"message"] = note;

	if (isCollectible) {
		NSString *title = [giftObj[@"title"] isKindOfClass:[NSString class]] ? giftObj[@"title"] : @"";
		out[@"title"] = title;

		int32_t number = 0;
		id rawNum = giftObj[@"number"] ?: receivedGift[@"unique_gift_number"];
		if ([rawNum respondsToSelector:@selector(intValue)])
			number = [rawNum intValue];
		out[@"number"] = @(number);

		NSDictionary *model = [giftObj[@"model"] isKindOfClass:[NSDictionary class]] ? giftObj[@"model"] : nil;
		NSString *modelName = [model[@"name"] isKindOfClass:[NSString class]] ? model[@"name"] : @"";
		out[@"modelName"] = modelName;

		NSDictionary *modelSticker = [model[@"sticker"] isKindOfClass:[NSDictionary class]] ? model[@"sticker"] : nil;
		NSNumber *modelThumbFileId = TGExtractPictureFileId(modelSticker);
		if (modelThumbFileId)
			out[@"modelThumbFileId"] = modelThumbFileId;

		NSDictionary *symbol = [giftObj[@"symbol"] isKindOfClass:[NSDictionary class]] ? giftObj[@"symbol"] : nil;
		NSString *symbolName = [symbol[@"name"] isKindOfClass:[NSString class]] ? symbol[@"name"] : @"";
		out[@"symbolName"] = symbolName;

		NSDictionary *backdrop = [giftObj[@"backdrop"] isKindOfClass:[NSDictionary class]] ? giftObj[@"backdrop"] : nil;
		NSString *backdropName = [backdrop[@"name"] isKindOfClass:[NSString class]] ? backdrop[@"name"] : @"";
		out[@"backdropName"] = backdropName;

		NSDictionary *colors = [backdrop[@"colors"] isKindOfClass:[NSDictionary class]]
				? backdrop[@"colors"]
				: ([giftObj[@"backdrop_colors"] isKindOfClass:[NSDictionary class]] ? giftObj[@"backdrop_colors"] : nil);
		if (colors) {
			id c = colors[@"center_color"];
			if ([c respondsToSelector:@selector(intValue)])
				out[@"backdropCenterColor"] = @([c intValue]);
			id e = colors[@"edge_color"];
			if ([e respondsToSelector:@selector(intValue)])
				out[@"backdropEdgeColor"] = @([e intValue]);
			id t = colors[@"text_color"];
			if ([t respondsToSelector:@selector(intValue)])
				out[@"backdropTextColor"] = @([t intValue]);
		}
	} else {
		int64_t giftId = 0;
		id rawGId = giftObj[@"id"];
		if ([rawGId respondsToSelector:@selector(longLongValue)])
			giftId = [rawGId longLongValue];
		out[@"giftId"] = @(giftId);

		int64_t starCount = 0;
		id rawStars = giftObj[@"star_count"];
		if ([rawStars respondsToSelector:@selector(longLongValue)])
			starCount = [rawStars longLongValue];
		out[@"starCount"] = @(starCount);

		NSDictionary *sticker = [giftObj[@"sticker"] isKindOfClass:[NSDictionary class]] ? giftObj[@"sticker"] : nil;
		NSString *emoji = [sticker[@"emoji"] isKindOfClass:[NSString class]] ? sticker[@"emoji"] : @"";
		out[@"emoji"] = emoji;

		NSNumber *thumbFileId = TGExtractPictureFileId(sticker);
		if (thumbFileId)
			out[@"thumbFileId"] = thumbFileId;

		NSNumber *stickerFileId = TGExtractStickerFileId(sticker);
		if (stickerFileId)
			out[@"stickerFileId"] = stickerFileId;
	}

	return out;
}
