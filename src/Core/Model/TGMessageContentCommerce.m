//
// TGMessageContentCommerce.m - read-side of the commerce message contents.
//
// TDLib could not deliver a valid number where the screens expect one, so
// every scalar below falls back to its zero value and every nested object
// falls back to an empty dictionary. An NSNull anywhere here would reach a
// label and draw "(null)" over a gift.
//
#import "TGMessageContentCommerce.h"
#import "TGBase64.h"

static NSDictionary *TGCDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *TGCArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : @[];
}

static NSNumber *TGCNumber(id value) {
	if ([value isKindOfClass:NSNumber.class])
		return value;
	if ([value isKindOfClass:NSString.class])
		return @([value longLongValue]);
	return @0;
}

static NSNumber *TGCBool(id value) {
	if ([value isKindOfClass:NSNumber.class])
		return @([value boolValue]);
	if ([value isKindOfClass:NSString.class])
		return @([value boolValue]);
	return @NO;
}

static NSString *TGCString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSString *TGCText(id value) {
	return TGCString(TGCDict(value)[@"text"]);
}

static NSArray *TGCNumberArray(id value) {
	NSArray *raw = TGCArray(value);
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:raw.count];
	for (id item in raw)
		[out addObject:TGCNumber(item)];
	return out;
}

static NSArray *TGCStringArray(id value) {
	NSArray *raw = TGCArray(value);
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:raw.count];
	for (id item in raw)
		[out addObject:TGCString(item)];
	return out;
}

/// A `file` is nested under the key its owner gives it; nil there means the
/// file is unknown, and callers treat 0 as "nothing to download".
static NSNumber *TGCFileId(id file) {
	NSDictionary *dict = TGCDict(file);
	return dict ? TGCNumber(dict[@"id"]) : @0;
}

static NSNumber *TGCThumbFileId(NSDictionary *owner) {
	return TGCFileId(TGCDict(owner[@"thumbnail"])[@"file"]);
}

static NSNumber *TGCStickerFileId(NSDictionary *sticker) {
	return TGCFileId(TGCDict(sticker[@"sticker"]));
}

/// photoSize spells its file `photo`, not `file`.
static NSDictionary *TGCLargestPhotoSize(id photo) {
	NSArray *sizes = TGCArray(TGCDict(photo)[@"sizes"]);
	NSDictionary *best = nil;
	long long bestArea = -1;
	for (id raw in sizes) {
		NSDictionary *size = TGCDict(raw);
		if (!size)
			continue;
		long long width = [TGCNumber(size[@"width"]) longLongValue];
		long long height = [TGCNumber(size[@"height"]) longLongValue];
		long long area = width * height;
		if (!best || area > bestArea) {
			best = size;
			bestArea = area;
		}
	}
	return best;
}

static NSNumber *TGCPhotoFileId(id photo) {
	NSDictionary *size = TGCLargestPhotoSize(photo);
	return size ? TGCFileId(size[@"photo"]) : @0;
}

/// bytes arrive as base64 in the JSON layer, and only the ticket size exists
/// here; an absent thumbnail simply leaves the key out.
static NSData *TGCMinithumbnail(NSDictionary *owner) {
	NSString *data = TGCString(TGCDict(owner[@"minithumbnail"])[@"data"]);
	return data.length ? TGBase64Decode(data) : nil;
}

/// The flattened message has always treated sender ids as user ids; a chat
/// sender has no user behind it and reads as 0, like `senderId` there.
static NSNumber *TGCSenderId(id sender) {
	NSDictionary *dict = TGCDict(sender);
	if ([TGCString(dict[@"@type"]) isEqualToString:@"messageSenderUser"])
		return TGCNumber(dict[@"user_id"]);
	return @0;
}

/// Premium and star giveaways share one object but not one count; whichever
/// half is missing stays 0 so the bubble can pick its own wording.
static void TGCReadPrize(id prize, NSNumber **months, NSNumber **stars) {
	NSDictionary *dict = TGCDict(prize);
	NSString *type = TGCString(dict[@"@type"]);
	*months = @0;
	*stars = @0;
	if ([type isEqualToString:@"giveawayPrizePremium"])
		*months = TGCNumber(dict[@"month_count"]);
	else if ([type isEqualToString:@"giveawayPrizeStars"])
		*stars = TGCNumber(dict[@"star_count"]);
}

static NSDictionary *TGCPaidMediaItem(id raw) {
	NSDictionary *media = TGCDict(raw) ?: @{};
	NSString *type = TGCString(media[@"@type"]);
	NSMutableDictionary *item = [@{
		@"kind"        : @"unsupported",
		@"width"       : @0,
		@"height"      : @0,
		@"duration"    : @0,
		@"photoFileId" : @0,
		@"thumbFileId" : @0,
		@"videoFileId" : @0,
	} mutableCopy];

	if ([type isEqualToString:@"paidMediaPreview"]) {
		item[@"kind"] = @"preview";
		item[@"width"] = TGCNumber(media[@"width"]);
		item[@"height"] = TGCNumber(media[@"height"]);
		item[@"duration"] = TGCNumber(media[@"duration"]);
		NSData *mini = TGCMinithumbnail(media);
		if (mini)
			item[@"minithumbnail"] = mini;

	} else if ([type isEqualToString:@"paidMediaPhoto"]) {
		item[@"kind"] = @"photo";
		NSDictionary *photo = TGCDict(media[@"photo"]);
		NSDictionary *size = TGCLargestPhotoSize(photo);
		if (size) {
			item[@"width"] = TGCNumber(size[@"width"]);
			item[@"height"] = TGCNumber(size[@"height"]);
			item[@"photoFileId"] = TGCFileId(size[@"photo"]);
		}
		NSData *mini = TGCMinithumbnail(photo);
		if (mini)
			item[@"minithumbnail"] = mini;
		// A live photo carries a short video behind the still image.
		NSDictionary *video = TGCDict(media[@"video"]);
		if (video) {
			item[@"duration"] = TGCNumber(video[@"duration"]);
			item[@"thumbFileId"] = TGCThumbFileId(video);
			item[@"videoFileId"] = TGCFileId(video[@"video"]);
		}

	} else if ([type isEqualToString:@"paidMediaVideo"]) {
		item[@"kind"] = @"video";
		NSDictionary *video = TGCDict(media[@"video"]) ?: @{};
		item[@"width"] = TGCNumber(video[@"width"]);
		item[@"height"] = TGCNumber(video[@"height"]);
		item[@"duration"] = TGCNumber(video[@"duration"]);
		item[@"thumbFileId"] = TGCThumbFileId(video);
		item[@"videoFileId"] = TGCFileId(video[@"video"]);
		NSData *mini = TGCMinithumbnail(video);
		if (mini)
			item[@"minithumbnail"] = mini;
	}
	return item;
}

NSDictionary *TGFlattenCommerceContent(NSDictionary *content) {
	NSString *type = TGCString(content[@"@type"]);

	if ([type isEqualToString:@"messagePaidMedia"]) {
		NSMutableArray *items = [NSMutableArray array];
		for (id media in TGCArray(content[@"media"]))
			[items addObject:TGCPaidMediaItem(media)];
		return @{@"paidMedia" : @{
			@"starCount"    : TGCNumber(content[@"star_count"]),
			@"caption"      : TGCText(content[@"caption"]),
			@"captionAbove" : TGCBool(content[@"show_caption_above_media"]),
			@"items"        : items,
		}};
	}

	if ([type isEqualToString:@"messageInvoice"]) {
		NSDictionary *product = TGCDict(content[@"product_info"]) ?: @{};
		return @{@"invoice" : @{
			@"title"            : TGCString(product[@"title"]),
			@"description"      : TGCText(product[@"description"]),
			@"photoFileId"      : TGCPhotoFileId(product[@"photo"]),
			@"currency"         : TGCString(content[@"currency"]),
			@"totalAmount"      : TGCNumber(content[@"total_amount"]),
			@"startParameter"   : TGCString(content[@"start_parameter"]),
			@"isTest"           : TGCBool(content[@"is_test"]),
			@"needShipping"     : TGCBool(content[@"need_shipping_address"]),
			@"receiptMessageId" : TGCNumber(content[@"receipt_message_id"]),
			@"hasPaidMedia"     : @(TGCDict(content[@"paid_media"]) != nil),
		}};
	}

	if ([type isEqualToString:@"messageGiveaway"]) {
		NSDictionary *params = TGCDict(content[@"parameters"]) ?: @{};
		NSNumber *months = @0, *stars = @0;
		TGCReadPrize(content[@"prize"], &months, &stars);
		return @{@"giveaway" : @{
			@"winnerCount"          : TGCNumber(content[@"winner_count"]),
			@"winnersSelectionDate" : TGCNumber(params[@"winners_selection_date"]),
			@"onlyNewMembers"       : TGCBool(params[@"only_new_members"]),
			@"hasPublicWinners"     : TGCBool(params[@"has_public_winners"]),
			@"countryCodes"         : TGCStringArray(params[@"country_codes"]),
			@"prizeDescription"     : TGCString(params[@"prize_description"]),
			@"additionalChatIds"    : TGCNumberArray(params[@"additional_chat_ids"]),
			@"boostedChatId"        : TGCNumber(params[@"boosted_chat_id"]),
			@"premiumMonths"        : months,
			@"starCount"            : stars,
			@"stickerFileId"        : TGCStickerFileId(content[@"sticker"]),
		}};
	}

	if ([type isEqualToString:@"messageGiveawayWinners"]) {
		NSNumber *months = @0, *stars = @0;
		TGCReadPrize(content[@"prize"], &months, &stars);
		return @{@"giveawayWinners" : @{
			@"boostedChatId"              : TGCNumber(content[@"boosted_chat_id"]),
			@"giveawayMessageId"          : TGCNumber(content[@"giveaway_message_id"]),
			@"actualWinnersSelectionDate" : TGCNumber(content[@"actual_winners_selection_date"]),
			@"winnerCount"                : TGCNumber(content[@"winner_count"]),
			@"unclaimedPrizeCount"        : TGCNumber(content[@"unclaimed_prize_count"]),
			@"winnerUserIds"              : TGCNumberArray(content[@"winner_user_ids"]),
			@"onlyNewMembers"             : TGCBool(content[@"only_new_members"]),
			@"wasRefunded"                : TGCBool(content[@"was_refunded"]),
			@"premiumMonths"              : months,
			@"starCount"                  : stars,
			@"prizeDescription"           : TGCString(content[@"prize_description"]),
		}};
	}

	if ([type isEqualToString:@"messageGift"]) {
		NSDictionary *gift = TGCDict(content[@"gift"]) ?: @{};
		NSDictionary *sticker = TGCDict(gift[@"sticker"]) ?: @{};
		return @{@"gift" : @{
			@"giftId"            : TGCNumber(gift[@"id"]),
			@"stickerFileId"     : TGCStickerFileId(sticker),
			@"stickerThumbFileId": TGCThumbFileId(sticker),
			@"starCount"         : TGCNumber(gift[@"star_count"]),
			@"text"              : TGCText(content[@"text"]),
			@"senderUserId"      : TGCSenderId(content[@"sender_id"]),
			@"receiverUserId"    : TGCSenderId(content[@"receiver_id"]),
			@"isPrivate"         : TGCBool(content[@"is_private"]),
			@"isSaved"           : TGCBool(content[@"is_saved"]),
			@"canBeUpgraded"     : TGCBool(content[@"can_be_upgraded"]),
			@"wasConverted"      : TGCBool(content[@"was_converted"]),
			@"wasUpgraded"       : TGCBool(content[@"was_upgraded"]),
			@"sellStarCount"     : TGCNumber(content[@"sell_star_count"]),
		}};
	}

	if ([type isEqualToString:@"messageUpgradedGift"]) {
		NSDictionary *gift = TGCDict(content[@"gift"]) ?: @{};
		NSDictionary *model = TGCDict(gift[@"model"]) ?: @{};
		NSDictionary *symbol = TGCDict(gift[@"symbol"]) ?: @{};
		NSDictionary *backdrop = TGCDict(gift[@"backdrop"]) ?: @{};
		NSDictionary *colors = TGCDict(backdrop[@"colors"]) ?: @{};
		return @{@"upgradedGift" : @{
			@"title"               : TGCString(gift[@"title"]),
			@"number"              : TGCNumber(gift[@"number"]),
			@"modelName"           : TGCString(model[@"name"]),
			@"modelStickerFileId"  : TGCStickerFileId(model[@"sticker"]),
			@"symbolName"          : TGCString(symbol[@"name"]),
			@"backdropName"        : TGCString(backdrop[@"name"]),
			@"backdropCenterColor" : TGCNumber(colors[@"center_color"]),
			@"backdropEdgeColor"   : TGCNumber(colors[@"edge_color"]),
			@"senderUserId"        : TGCSenderId(content[@"sender_id"]),
			@"receiverUserId"      : TGCSenderId(content[@"receiver_id"]),
			@"isSaved"             : TGCBool(content[@"is_saved"]),
			@"canBeTransferred"    : TGCBool(content[@"can_be_transferred"]),
			@"wasTransferred"      : TGCBool(content[@"was_transferred"]),
		}};
	}

	return nil;
}
