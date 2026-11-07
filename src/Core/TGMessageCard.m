//
// TGMessageCard.m - read flattened message dictionaries into bubble cards.
//
#import "TGMessageCard.h"

FOUNDATION_EXPORT NSString *TGMessageCardPrice(NSString *currency, int64_t amount);

@implementation TGMessageCard

- (instancetype)init {
	self = [super init];
	if (self) {
		_kicker = @"";
		_title = @"";
		_lines = @[];
	}
	return self;
}

- (void)setKicker:(NSString *)kicker {
	_kicker = kicker ? [kicker copy] : @"";
}

- (void)setTitle:(NSString *)title {
	_title = title ? [title copy] : @"";
}

- (void)setLines:(NSArray *)lines {
	_lines = lines ? [lines copy] : @[];
}

@end

static NSString *TGMCString(id value) {
	if ([value isKindOfClass:[NSString class]])
		return value;
	return @"";
}

static int64_t TGMCInt64(id value) {
	if ([value respondsToSelector:@selector(longLongValue)])
		return [value longLongValue];
	return 0;
}

static BOOL TGMCBool(id value) {
	if ([value respondsToSelector:@selector(boolValue)])
		return [value boolValue];
	return NO;
}

static BOOL TGMCIsZeroDecimalCurrency(NSString *currency) {
	if (![currency isKindOfClass:[NSString class]])
		return NO;
	static NSSet *set = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		set = [[NSSet alloc] initWithObjects:
			@"JPY", @"KRW", @"VND", @"CLP", @"ISK", @"UGX",
			@"PYG", @"XAF", @"XOF", @"KMF", @"GNF", @"RWF",
			@"DJF", @"BIF", @"VUV", @"XPF", nil];
	});
	return [set containsObject:currency];
}

NSString *TGMessageCardPrice(NSString *currency, int64_t amount) {
	NSString *curr = [currency isKindOfClass:[NSString class]] ? currency : @"";
	if ([curr isEqualToString:@"XTR"]) {
		if (amount == 1)
			return @"1 Star";
		return [NSString stringWithFormat:@"%lld Stars", (long long)amount];
	}
	if (TGMCIsZeroDecimalCurrency(curr)) {
		return [NSString stringWithFormat:@"%lld %@", (long long)amount, curr];
	}
	int64_t major = amount / 100;
	int64_t minor = llabs(amount % 100);
	if ([curr isEqualToString:@"USD"]) {
		return [NSString stringWithFormat:@"$%lld.%02lld", (long long)major, (long long)minor];
	}
	if (curr.length == 0) {
		return [NSString stringWithFormat:@"%lld.%02lld", (long long)major, (long long)minor];
	}
	return [NSString stringWithFormat:@"%lld.%02lld %@", (long long)major, (long long)minor, curr];
}

static NSString *TGMCPrizeLine(int64_t starCount, int64_t premiumMonths, int64_t winnerCount) {
	if (starCount > 0) {
		return (starCount == 1) ? @"1 Star" : [NSString stringWithFormat:@"%lld Stars", (long long)starCount];
	}
	if (premiumMonths > 0) {
		NSString *subs = (winnerCount == 1) ? @"1 Telegram Premium subscription"
											: [NSString stringWithFormat:@"%lld Telegram Premium subscriptions", (long long)winnerCount];
		NSString *months = (premiumMonths == 1) ? @"1 month"
												: [NSString stringWithFormat:@"%lld months", (long long)premiumMonths];
		return [NSString stringWithFormat:@"%@ for %@", subs, months];
	}
	return nil;
}

static NSString *TGMCFormatGiveawayDate(int64_t timestamp) {
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)timestamp];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
	formatter.dateFormat = @"MMM d, yyyy";
	formatter.timeZone = [NSTimeZone defaultTimeZone];
	return [formatter stringFromDate:date];
}

static NSString *TGMCDurationString(int64_t duration) {
	int64_t h = duration / 3600;
	int64_t m = (duration % 3600) / 60;
	int64_t s = duration % 60;
	if (h > 0) {
		return [NSString stringWithFormat:@"Duration %lld:%02lld:%02lld", (long long)h, (long long)m, (long long)s];
	}
	return [NSString stringWithFormat:@"Duration %lld:%02lld", (long long)m, (long long)s];
}

static NSString *TGMCUserName(id rawUser) {
	if (![rawUser isKindOfClass:[NSDictionary class]])
		return @"Deleted Account";
	NSDictionary *user = (NSDictionary *)rawUser;
	NSString *first = TGMCString(user[@"firstName"]);
	NSString *last = TGMCString(user[@"lastName"]);
	NSString *full;
	if (first.length && last.length)
		full = [NSString stringWithFormat:@"%@ %@", first, last];
	else if (first.length)
		full = first;
	else
		full = last;
	NSString *trimmed = [full stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return trimmed.length ? trimmed : @"Deleted Account";
}

static NSArray *TGMCCapLines(NSArray *lines) {
	if (lines.count > 4)
		return [lines subarrayWithRange:NSMakeRange(0, 4)];
	return lines ?: @[];
}

TGMessageCard *TGMessageCardForRow(NSDictionary *row) {
	if (![row isKindOfClass:[NSDictionary class]])
		return nil;

	int64_t rowId = TGMCInt64(row[@"id"]);

	// 1. invoice
	id rawInvoice = row[@"invoice"];
	if ([rawInvoice isKindOfClass:[NSDictionary class]] && [rawInvoice count] > 0) {
		NSDictionary *invoice = (NSDictionary *)rawInvoice;
		TGMessageCard *card = [[TGMessageCard alloc] init];
		card.kicker = TGMCBool(invoice[@"isTest"]) ? @"Test Invoice" : @"Invoice";
		NSString *title = TGMCString(invoice[@"title"]);
		card.title = title.length ? title : @"Invoice";
		NSString *desc = TGMCString(invoice[@"description"]);
		card.lines = desc.length ? @[desc] : @[];
		card.imageFileId = TGMCInt64(invoice[@"photoFileId"]);
		card.imageAspect = 1.0f;
		card.action = TGMessageCardActionPay;
		card.actionTargetId = rowId;

		int64_t receiptMessageId = TGMCInt64(invoice[@"receiptMessageId"]);
		if (receiptMessageId != 0) {
			card.buttonTitle = @"Receipt";
		} else {
			NSString *price = TGMessageCardPrice(TGMCString(invoice[@"currency"]), TGMCInt64(invoice[@"totalAmount"]));
			card.buttonTitle = [NSString stringWithFormat:@"Pay %@", price];
		}
		return card;
	}

	// 2. giveaway
	id rawGiveaway = row[@"giveaway"];
	if ([rawGiveaway isKindOfClass:[NSDictionary class]] && [rawGiveaway count] > 0) {
		NSDictionary *giveaway = (NSDictionary *)rawGiveaway;
		TGMessageCard *card = [[TGMessageCard alloc] init];
		card.kicker = @"Giveaway";
		card.title = @"Giveaway Prizes";

		NSMutableArray *lines = [NSMutableArray array];
		int64_t winnerCount = TGMCInt64(giveaway[@"winnerCount"]);
		NSString *prize = TGMCPrizeLine(TGMCInt64(giveaway[@"starCount"]), TGMCInt64(giveaway[@"premiumMonths"]), winnerCount);
		if (prize.length)
			[lines addObject:prize];

		NSString *desc = TGMCString(giveaway[@"prizeDescription"]);
		if (desc.length)
			[lines addObject:desc];

		int64_t selDate = TGMCInt64(giveaway[@"winnersSelectionDate"]);
		if (selDate > 0) {
			[lines addObject:[NSString stringWithFormat:@"Winners selected on %@", TGMCFormatGiveawayDate(selDate)]];
		}

		if (TGMCBool(giveaway[@"onlyNewMembers"]))
			[lines addObject:@"Only new subscribers"];

		card.lines = TGMCCapLines(lines);
		card.imageFileId = TGMCInt64(giveaway[@"stickerFileId"]);
		card.imageAspect = 1.0f;
		card.buttonTitle = @"Learn More";
		card.action = TGMessageCardActionOpenGiveaway;
		card.actionTargetId = rowId;
		return card;
	}

	// 3. giveawayWinners
	id rawWinners = row[@"giveawayWinners"];
	if ([rawWinners isKindOfClass:[NSDictionary class]] && [rawWinners count] > 0) {
		NSDictionary *winners = (NSDictionary *)rawWinners;
		TGMessageCard *card = [[TGMessageCard alloc] init];
		card.kicker = @"Giveaway Results";
		card.title = @"Winners Selected!";

		NSMutableArray *lines = [NSMutableArray array];
		int64_t winnerCount = TGMCInt64(winners[@"winnerCount"]);
		[lines addObject:(winnerCount == 1) ? @"1 winner" : [NSString stringWithFormat:@"%lld winners", (long long)winnerCount]];

		NSString *prize = TGMCPrizeLine(TGMCInt64(winners[@"starCount"]), TGMCInt64(winners[@"premiumMonths"]), winnerCount);
		if (prize.length)
			[lines addObject:prize];

		int64_t unclaimed = TGMCInt64(winners[@"unclaimedPrizeCount"]);
		if (unclaimed > 0) {
			[lines addObject:(unclaimed == 1) ? @"1 unclaimed prize" : [NSString stringWithFormat:@"%lld unclaimed prizes", (long long)unclaimed]];
		}

		if (TGMCBool(winners[@"wasRefunded"]))
			[lines addObject:@"The giveaway was refunded"];

		card.lines = TGMCCapLines(lines);
		card.imageFileId = 0;
		card.imageAspect = 0.0f;
		card.buttonTitle = @"Learn More";
		card.action = TGMessageCardActionOpenGiveaway;
		card.actionTargetId = TGMCInt64(winners[@"giveawayMessageId"]);
		return card;
	}

	// 4. gift
	id rawGift = row[@"gift"];
	if ([rawGift isKindOfClass:[NSDictionary class]] && [rawGift count] > 0) {
		NSDictionary *gift = (NSDictionary *)rawGift;
		TGMessageCard *card = [[TGMessageCard alloc] init];
		card.kicker = @"Gift";
		int64_t starCount = TGMCInt64(gift[@"starCount"]);
		if (starCount > 0)
			card.title = (starCount == 1) ? @"1 Star" : [NSString stringWithFormat:@"%lld Stars", (long long)starCount];
		else
			card.title = @"Gift";

		NSMutableArray *lines = [NSMutableArray array];
		NSString *text = TGMCString(gift[@"text"]);
		if (text.length)
			[lines addObject:text];

		if (TGMCBool(gift[@"wasConverted"])) {
			int64_t sellStars = TGMCInt64(gift[@"sellStarCount"]);
			NSString *starStr = (sellStars == 1) ? @"1 Star" : [NSString stringWithFormat:@"%lld Stars", (long long)sellStars];
			[lines addObject:[NSString stringWithFormat:@"Converted to %@", starStr]];
		} else if (TGMCBool(gift[@"wasUpgraded"])) {
			[lines addObject:@"Upgraded to a collectible"];
		} else if (TGMCBool(gift[@"isSaved"])) {
			[lines addObject:@"Shown on the profile"];
		}

		card.lines = TGMCCapLines(lines);
		int64_t thumbId = TGMCInt64(gift[@"stickerThumbFileId"]);
		card.imageFileId = (thumbId > 0) ? thumbId : TGMCInt64(gift[@"stickerFileId"]);
		card.imageAspect = 1.0f;
		card.buttonTitle = @"View";
		card.action = TGMessageCardActionViewGift;
		card.actionTargetId = TGMCInt64(gift[@"giftId"]);
		return card;
	}

	// 5. upgradedGift
	id rawUpgraded = row[@"upgradedGift"];
	if ([rawUpgraded isKindOfClass:[NSDictionary class]] && [rawUpgraded count] > 0) {
		NSDictionary *upgraded = (NSDictionary *)rawUpgraded;
		TGMessageCard *card = [[TGMessageCard alloc] init];
		card.kicker = @"Collectible";

		NSString *title = TGMCString(upgraded[@"title"]);
		int64_t number = TGMCInt64(upgraded[@"number"]);
		if (title.length == 0)
			card.title = @"Collectible";
		else if (number == 0)
			card.title = title;
		else
			card.title = [NSString stringWithFormat:@"%@ #%lld", title, (long long)number];

		NSMutableArray *lines = [NSMutableArray array];
		NSString *model = TGMCString(upgraded[@"modelName"]);
		if (model.length)
			[lines addObject:[NSString stringWithFormat:@"Model: %@", model]];
		NSString *symbol = TGMCString(upgraded[@"symbolName"]);
		if (symbol.length)
			[lines addObject:[NSString stringWithFormat:@"Symbol: %@", symbol]];
		NSString *backdrop = TGMCString(upgraded[@"backdropName"]);
		if (backdrop.length)
			[lines addObject:[NSString stringWithFormat:@"Backdrop: %@", backdrop]];

		card.lines = TGMCCapLines(lines);
		card.imageFileId = TGMCInt64(upgraded[@"modelStickerFileId"]);
		card.imageAspect = 1.0f;
		card.buttonTitle = @"View";
		card.action = TGMessageCardActionViewGift;
		card.actionTargetId = rowId;
		return card;
	}

	// 6. game
	id rawGame = row[@"game"];
	if ([rawGame isKindOfClass:[NSDictionary class]] && [rawGame count] > 0) {
		NSDictionary *game = (NSDictionary *)rawGame;
		TGMessageCard *card = [[TGMessageCard alloc] init];
		card.kicker = @"Game";
		NSString *title = TGMCString(game[@"title"]);
		card.title = title.length ? title : @"Game";
		NSString *desc = TGMCString(game[@"description"]);
		card.lines = desc.length ? @[desc] : @[];
		card.imageFileId = TGMCInt64(game[@"photoFileId"]);
		card.imageAspect = 16.0f / 9.0f;
		card.buttonTitle = @"Play";
		card.action = TGMessageCardActionPlayGame;
		card.actionTargetId = TGMCInt64(game[@"gameId"]);
		return card;
	}

	// 7. sharedUsers
	id rawUsers = row[@"sharedUsers"];
	if ([rawUsers isKindOfClass:[NSArray class]] && [rawUsers count] > 0) {
		NSArray *users = (NSArray *)rawUsers;
		TGMessageCard *card = [[TGMessageCard alloc] init];
		if (users.count == 1) {
			card.kicker = @"Shared contact";
			NSDictionary *user = [users[0] isKindOfClass:[NSDictionary class]] ? users[0] : @{};
			card.title = TGMCUserName(user);
			NSString *username = TGMCString(user[@"username"]);
			if (username.length) {
				NSString *handle = [username hasPrefix:@"@"] ? username : [NSString stringWithFormat:@"@%@", username];
				card.lines = @[handle];
			} else {
				card.lines = @[];
			}
			card.imageFileId = TGMCInt64(user[@"photoFileId"]);
			card.imageAspect = 1.0f;
			card.imageIsRound = YES;
			card.buttonTitle = @"Open";
			card.action = TGMessageCardActionOpenUser;
			card.actionTargetId = TGMCInt64(user[@"userId"]);
		} else {
			card.kicker = @"Shared contacts";
			card.title = [NSString stringWithFormat:@"%lu contacts", (unsigned long)users.count];
			NSMutableArray *lines = [NSMutableArray array];
			NSUInteger count = MIN((NSUInteger)4, users.count);
			for (NSUInteger i = 0; i < count; i++) {
				[lines addObject:TGMCUserName(users[i])];
			}
			card.lines = lines;
			card.imageFileId = 0;
			card.imageAspect = 0.0f;
			card.imageIsRound = NO;
			card.buttonTitle = @"Open";
			card.action = TGMessageCardActionOpenUser;
			NSDictionary *first = [users[0] isKindOfClass:[NSDictionary class]] ? users[0] : @{};
			card.actionTargetId = TGMCInt64(first[@"userId"]);
		}
		return card;
	}

	// 8. sharedChat
	id rawChat = row[@"sharedChat"];
	if ([rawChat isKindOfClass:[NSDictionary class]] && [rawChat count] > 0) {
		NSDictionary *chat = (NSDictionary *)rawChat;
		TGMessageCard *card = [[TGMessageCard alloc] init];
		card.kicker = @"Shared chat";
		NSString *title = TGMCString(chat[@"title"]);
		card.title = title.length ? title : @"Chat";
		NSString *username = TGMCString(chat[@"username"]);
		if (username.length) {
			NSString *handle = [username hasPrefix:@"@"] ? username : [NSString stringWithFormat:@"@%@", username];
			card.lines = @[handle];
		} else {
			card.lines = @[];
		}
		card.imageFileId = TGMCInt64(chat[@"photoFileId"]);
		card.imageAspect = 1.0f;
		card.imageIsRound = YES;
		card.buttonTitle = @"Open";
		card.action = TGMessageCardActionOpenChat;
		card.actionTargetId = TGMCInt64(chat[@"chatId"]);
		return card;
	}

	// 9. groupCall
	id rawCall = row[@"groupCall"];
	if ([rawCall isKindOfClass:[NSDictionary class]] && [rawCall count] > 0) {
		NSDictionary *call = (NSDictionary *)rawCall;
		TGMessageCard *card = [[TGMessageCard alloc] init];
		card.kicker = TGMCBool(call[@"isVideo"]) ? @"Video chat" : @"Voice chat";
		BOOL isActive = TGMCBool(call[@"isActive"]);
		if (isActive)
			card.title = @"Ongoing";
		else if (TGMCBool(call[@"wasMissed"]))
			card.title = @"Missed";
		else
			card.title = @"Ended";

		int64_t duration = TGMCInt64(call[@"duration"]);
		if (duration > 0)
			card.lines = @[TGMCDurationString(duration)];
		else
			card.lines = @[];

		if (isActive) {
			card.buttonTitle = @"Join";
			card.action = TGMessageCardActionJoinCall;
			card.actionTargetId = TGMCInt64(call[@"groupCallId"]);
		} else {
			card.buttonTitle = nil;
			card.action = TGMessageCardActionNone;
			card.actionTargetId = 0;
		}
		return card;
	}

	// 10. story
	id rawStory = row[@"story"];
	if ([rawStory isKindOfClass:[NSDictionary class]] && [rawStory count] > 0) {
		NSDictionary *story = (NSDictionary *)rawStory;
		TGMessageCard *card = [[TGMessageCard alloc] init];
		card.kicker = @"Story";
		card.title = TGMCBool(story[@"viaMention"]) ? @"Mentioned you in a story" : @"Story";
		card.lines = @[];
		card.imageFileId = 0;
		card.imageAspect = 0.0f;
		card.buttonTitle = @"Open";
		card.action = TGMessageCardActionOpenStory;
		card.actionTargetId = TGMCInt64(story[@"storyId"]);
		card.actionChatId = TGMCInt64(story[@"posterChatId"]);
		return card;
	}

	return nil;
}
