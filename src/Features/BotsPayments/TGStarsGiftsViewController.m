//
// TGStarsGiftsViewController.m - what a user account can read about Premium,
// Stars and gifts without a payment provider.
//
// The store purchase, the card form, the TON wallet and the giveaway launch
// are not here: they need a stack this build does not carry, and pretending
// to charge a card would be worse than refusing. These rows only ask, and
// every answer is Telegram's.
//
#import "TGStarsGiftsViewController.h"
#import "TGAlertSheet.h"
#import "TGStyle.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGRows.h"

/// A transaction timestamp in the app's date format; the audit screen used to
/// print the raw Unix number.
static NSString *TGStarsTransactionDate(NSNumber *unix) {
	static NSDateFormatter *fmt = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		fmt = [[NSDateFormatter alloc] init];
		fmt.dateStyle = NSDateFormatterMediumStyle;
		fmt.timeStyle = NSDateFormatterShortStyle;
	});
	if (![unix isKindOfClass:[NSNumber class]] || unix.doubleValue <= 0)
		return @"-";
	NSString *language = TGAppLanguage();
	fmt.locale = language.length
			? [NSLocale localeWithLocaleIdentifier:language]
			: [NSLocale currentLocale];
	return [fmt stringFromDate:[NSDate dateWithTimeIntervalSince1970:unix.doubleValue]];
}

#import "TGStarsTransactionText.h"
#import "TGStarsStore.h"
#import "TGProfileStore.h"

/// The ledger as rows: localized type and date on the left, the signed Stars
/// amount in a value label on the right. An alert cannot lay that out.
@interface TGStarsTransactionsViewController : TGRowsViewController
@property (nonatomic, strong) NSArray *rows;
@end

@implementation TGStarsTransactionsViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Stars Transactions");
	[self rebuildSections];
}

- (void)rebuildSections {
	TGTheme *theme = [TGTheme shared];
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *model in TGStarsLedgerRowModels(self.rows)){
		NSMutableDictionary *row = [TGSubtitleRow(model[@"title"],
				model[@"subtitle"], nil) mutableCopy];
		row[TGRowAccessory] = model[@"amount"];
		row[TGRowAccessoryColour] = [model[@"isOutgoing"] boolValue]
				? [theme secondaryTextColour] : [theme accentColour];
		[rows addObject:row];
	}
	self.sections = @[TGSection(nil, nil, rows)];
	[self reloadRows];
}

@end

@interface TGStarsGiftsViewController ()
@property (nonatomic, copy) NSString *ownerKind;
@property (nonatomic, assign) int64_t ownerId;
@property (nonatomic, assign) int64_t giftId;
@property (nonatomic, strong) NSArray *answerLines;
@end

@implementation TGStarsGiftsViewController

- (instancetype)init {
	if ((self = [super init])){
		_ownerKind = @"user";
		_answerLines = @[@"None"];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Premium, Stars and Gifts";
	[self rebuildSections];
}

- (void)rebuildSections {
	NSMutableArray *premium = [NSMutableArray array];
	[premium addObject:TGBAction(@"Load Premium Features", nil, @"features")];
	[premium addObject:TGBAction(@"View A Premium Feature", nil, @"viewFeature")];
	[premium addObject:TGBAction(@"Load A Premium Limit", nil, @"limit")];
	[premium addObject:TGBAction(@"Premium Stickers", nil, @"premiumStickers")];
	[premium addObject:TGBAction(@"Examples", nil, @"premiumExamples")];
	[premium addObject:TGBAction(@"Premium Info Sticker", nil, @"premiumInfo")];
	[premium addObject:TGBAction(@"Check Gift Code", nil, @"checkCode")];
	[premium addObject:TGBAction(@"Apply Gift Code", nil, @"applyCode")];

	NSMutableArray *stars = [NSMutableArray array];
	[stars addObject:TGBAction(@"Owner",
			[NSString stringWithFormat:@"%@ %lld", self.ownerKind, self.ownerId], @"owner")];
	[stars addObject:TGBAction(@"Stars Transactions", nil, @"transactions")];
	[stars addObject:TGBAction(@"My Subscriptions", nil, @"subscriptions")];
	[stars addObject:TGBAction(@"Cancel Subscription", nil, @"cancelSubscription")];
	[stars addObject:TGBAction(@"Reuse A Subscription", nil, @"reuseSubscription")];

	NSMutableArray *boosts = [NSMutableArray array];
	[boosts addObject:TGBAction(@"Available Boost Slots", nil, @"boostSlots")];
	[boosts addObject:TGBAction(@"Boost Status For Owner", nil, @"boostStatus")];
	[boosts addObject:TGBAction(@"Boost Features For Channels", nil, @"boostFeatures")];
	[boosts addObject:TGBAction(@"Boost Level Features", nil, @"boostLevelFeatures")];
	[boosts addObject:TGBAction(@"Link", nil, @"boostLink")];
	[boosts addObject:TGBAction(@"Read A Boost Link", nil, @"boostLinkInfo")];
	[boosts addObject:TGBAction(@"Boosts On A Chat", nil, @"boostList")];
	[boosts addObject:TGBAction(@"Boost The Owner Chat", nil, @"boostSend")];

	NSMutableArray *revenue = [NSMutableArray array];
	[revenue addObject:TGBAction(@"Chat Revenue Statistics", nil, @"chatRevenue")];
	[revenue addObject:TGBAction(@"Transactions", nil, @"chatRevenueList")];
	[revenue addObject:TGBAction(@"Star Revenue Statistics", nil, @"starRevenue")];
	[revenue addObject:TGBAction(@"Gram Revenue Statistics", nil, @"gramRevenue")];
	[revenue addObject:TGBAction(@"Paid Message Revenue", nil, @"paidRevenue")];
	[revenue addObject:TGBAction(@"Direct Messages Topic Revenue", nil, @"topicRevenue")];

	NSMutableArray *paid = [NSMutableArray array];
	[paid addObject:TGBAction(@"Allow Unpaid Messages From A User", nil, @"allowUnpaid")];
	[paid addObject:TGBAction(@"Apply An Unpaid Token", nil, @"unpaidToken")];
	[paid addObject:TGBAction(@"Paid Reaction Senders", nil, @"reactionSenders")];
	[paid addObject:TGBAction(@"Chat Paid Message Price", nil, @"chatPaidPrice")];
	[paid addObject:TGBAction(@"Call Paid Message Price", nil, @"callPaidPrice")];
	[paid addObject:TGBAction(@"Topic Unpaid Messages", nil, @"topicUnpaid")];
	[paid addObject:TGBAction(@"Receipt", nil, @"receipt")];
	[paid addObject:TGBAction(@"Star Ads Account URL", nil, @"adAccount")];
	[paid addObject:TGBAction(@"Unrestrict Boost Count", nil, @"unrestrict")];

	NSMutableArray *discovery = [NSMutableArray array];
	[discovery addObject:TGBAction(@"Giveaway", nil, @"giveaway")];
	[discovery addObject:TGBAction(@"Collectible", nil, @"collectible")];
	[discovery addObject:TGBAction(@"Premium", nil, @"subscribe")];

	NSMutableArray *gifts = [NSMutableArray array];
	[gifts addObject:TGBAction(@"Gift ID", self.giftId
			? [NSString stringWithFormat:@"%lld", self.giftId] : @"Set", @"giftId")];
	[gifts addObject:TGBAction(@"Gifts", nil, @"available")];
	[gifts addObject:TGBAction(@"Can This Gift Be Sent?", nil, @"canSend")];
	[gifts addObject:TGBAction(@"Read A Received Gift", nil, @"received")];
	[gifts addObject:TGBAction(@"Read An Upgraded Gift", nil, @"upgraded")];
	[gifts addObject:TGBAction(@"Upgraded Gift Value", nil, @"value")];
	[gifts addObject:TGBAction(@"Upgraded Gift Variants", nil, @"variants")];
	[gifts addObject:TGBAction(@"Upgrade Preview", nil, @"upgradePreview")];
	[gifts addObject:TGBAction(@"Gift Collections", nil, @"collections")];
	[gifts addObject:TGBAction(@"Gifts For Crafting", nil, @"crafting")];
	[gifts addObject:TGBAction(@"Gifts For Resale", nil, @"resale")];
	[gifts addObject:TGBAction(@"Emoji Status", nil, @"emojiStatuses")];
	[gifts addObject:TGBAction(@"Themes", nil, @"themes")];
	[gifts addObject:TGBAction(@"Gift Auction State", nil, @"auctionState")];
	[gifts addObject:TGBAction(@"Acquired Auction Gifts", nil, @"auctionGifts")];
	[gifts addObject:TGBAction(@"Open Gift Auction", nil, @"auctionOpen")];
	[gifts addObject:TGBAction(@"Close Gift Auction", nil, @"auctionClose")];
	[gifts addObject:TGBAction(@"Promotional Animation", nil, @"promo")];

	NSMutableArray *answers = [NSMutableArray array];
	for (NSString *line in self.answerLines)
		[answers addObject:TGBInfo(line, nil)];

	self.sections = @[
		TGBSection(@"Premium", nil, premium),
		TGBSection(@"Stars", nil, stars),
		TGBSection(@"BOOSTS", nil, boosts),
		TGBSection(@"REVENUE", nil, revenue),
		TGBSection(@"Paid Messages", nil, paid),
		TGBSection(@"DISCOVERY", nil, discovery),
		TGBSection(@"GIFTS", nil, gifts),
		TGBSection(@"Replies", nil, answers),
	];
	[self rebuild];
}
- (void)finish:(BOOL)ok error:(NSString *)error title:(NSString *)title {
	self.answerLines = @[ok ? @"Done"
						   : (error.length ? error : @"An error occurred.")];
	[self rebuildSections];
	if (!ok)
		[self showMessage:self.answerLines.firstObject title:title];
}

- (void)showText:(NSString *)text title:(NSString *)title {
	self.answerLines = @[text ?: @""];
	[self rebuildSections];
	[self showMessage:text ?: @"" title:title];
}

- (void)askGift:(NSString *)title action:(void (^)(int64_t giftId))action {
	__weak typeof(self) weakSelf = self;
	[self askText:title message:@"Gift" placeholder:@"123"
			 text:(self.giftId ? [NSString stringWithFormat:@"%lld", self.giftId] : nil)
		   action:@"Next" completion:^(NSString *text){
		int64_t giftId = text.longLongValue;
		weakSelf.giftId = giftId;
		[weakSelf rebuildSections];
		action(giftId);
	}];
}

- (void)didChooseAction:(NSString *)action row:(NSDictionary *)row {
	__weak typeof(self) weakSelf = self;
	if ([action isEqualToString:@"features"]){
		[[TGStarsStore shared] premiumFeaturesFromSource:@""
										  completion:^(NSDictionary *features, NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"Premium"];
				return;
			}
			NSMutableArray *lines = [NSMutableArray array];
			for (NSString *feature in features[@"features"])
				[lines addObject:feature];
			for (NSDictionary *limit in features[@"limits"])
				[lines addObject:[NSString stringWithFormat:@"%@  %@ / %@",
						limit[@"type"], limit[@"defaultValue"], limit[@"premiumValue"]]];
			[weakSelf showText:(lines.count ? [lines componentsJoinedByString:@"\n"]
					: @"None")
					   title:@"Premium"];
		}];
	} else if ([action isEqualToString:@"viewFeature"]){
		[self askText:@"Premium Feature" message:nil
				 placeholder:@"disabledAds" text:nil action:@"Open"
		   completion:^(NSString *text){
			[[TGStarsStore shared] viewPremiumFeature:text
									   completion:^(BOOL ok, NSString *error){
				[weakSelf finish:ok error:error title:@"Premium Feature"];
			}];
		}];
	} else if ([action isEqualToString:@"limit"]){
		[self askText:@"Premium Limit" message:nil
				 placeholder:@"pinnedChatCount" text:nil action:@"Read"
		   completion:^(NSString *text){
			[[TGStarsStore shared] premiumLimitOfType:text
									   completion:^(NSDictionary *limit, NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Premium Limit"];
					return;
				}
				[weakSelf showText:[NSString stringWithFormat:@"%@\nFree: %@\nPremium: %@",
						limit[@"type"], limit[@"defaultValue"], limit[@"premiumValue"]]
							   title:@"Premium Limit"];
			}];
		}];
	} else if ([action isEqualToString:@"premiumStickers"]){
		[[TGStarsStore shared] premiumStickersWithLimit:50
										 completion:^(NSArray *stickers, NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"Premium Stickers"];
				return;
			}
			NSMutableArray *lines = [NSMutableArray array];
			for (NSDictionary *sticker in stickers)
				[lines addObject:[NSString stringWithFormat:@"%@  file %@",
						sticker[@"emoji"], sticker[@"fileId"]]];
			[weakSelf showText:(lines.count ? [lines componentsJoinedByString:@"\n"]
					: @"None")
					   title:@"Premium Stickers"];
		}];
	} else if ([action isEqualToString:@"premiumExamples"]){
		[[TGStarsStore shared] premiumStickerExamplesWithCompletion:^(NSArray *stickers,
																  NSString *error){
			[weakSelf finish:error == nil error:error title:@"Premium Stickers"];
			if (!error)
				[weakSelf showText:[NSString stringWithFormat:@"%lu example(s).",
						(unsigned long)stickers.count] title:@"Examples"];
		}];
	} else if ([action isEqualToString:@"premiumInfo"]){
		[self askText:@"Premium Months" message:nil placeholder:@"12" text:@"12"
			   action:@"Read" completion:^(NSString *text){
			[[TGStarsStore shared] premiumInfoStickerForMonths:text.intValue
												completion:^(NSDictionary *sticker,
															 NSString *error){
				[weakSelf finish:error == nil error:error title:@"Premium Stickers"];
				if (!error) [weakSelf showText:[NSString stringWithFormat:
						@"Sticker %@ in set %@", sticker[@"id"], sticker[@"setId"]]
									   title:@"Premium Stickers"];
			}];
		}];
	} else if ([action isEqualToString:@"checkCode"]){
		[self askText:@"Premium Gift Code" message:nil placeholder:@"ABCD-1234"
				 text:nil action:@"Check" completion:^(NSString *text){
			[[TGStarsStore shared] checkPremiumGiftCode:text
										 completion:^(NSDictionary *info, NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Gift Code"];
					return;
				}
				[weakSelf showText:[NSString stringWithFormat:
						@"%@ month(s), %@ day(s)\nFrom giveaway: %@\nUsed by: %@",
						info[@"monthCount"], info[@"dayCount"],
						[info[@"isFromGiveaway"] boolValue] ? @"yes" : @"no",
						info[@"userId"]] title:@"Gift Code"];
			}];
		}];
	} else if ([action isEqualToString:@"applyCode"]){
		[self askText:@"Apply Premium Gift Code" message:nil placeholder:@"ABCD-1234"
				 text:nil action:@"Apply" completion:^(NSString *text){
			[[TGStarsStore shared] applyPremiumGiftCode:text
										 completion:^(BOOL ok, NSString *error){
				[weakSelf finish:ok error:error title:@"Gift Code"];
			}];
		}];
	} else if ([action isEqualToString:@"owner"]){
		[TGAlertSheet showChoices:@[@"My Profile", @"A chat"]
							title:@"Owner" destructiveIndex:-1 inView:self.view
						 onChoice:^(NSInteger index){
			NSString *kind = index == 0 ? @"user" : @"chat";
			[weakSelf askText:@"Owner" message:nil placeholder:@"123" text:nil
					   action:@"Save" completion:^(NSString *text){
				weakSelf.ownerKind = kind;
				weakSelf.ownerId = text.longLongValue;
				[weakSelf rebuildSections];
			}];
		}];
	} else if ([action isEqualToString:@"transactions"]){
		[TGAlertSheet showChoices:@[@"Incoming", @"Outgoing", @"Both"]
							title:@"Stars Transactions" destructiveIndex:-1
						   inView:self.view onChoice:^(NSInteger index){
			NSString *direction = index == 0 ? @"incoming"
					: index == 1 ? @"outgoing" : @"";
			int64_t ownerId = weakSelf.ownerId;
			if (!ownerId && [weakSelf.ownerKind isEqualToString:@"user"])
				ownerId = [[TGProfileStore shared].me[@"id"] longLongValue];
			[[TGStarsStore shared] starTransactionsForOwner:weakSelf.ownerKind
												ownerId:ownerId
											  direction:direction
												 offset:@""
												  limit:20
											 completion:^(NSDictionary *page, NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Stars Transactions"];
					return;
				}
				NSMutableArray *rows = [NSMutableArray array];
				for (NSDictionary *transaction in page[@"transactions"]){
					if (![transaction isKindOfClass:NSDictionary.class])
						continue;
					NSMutableDictionary *withDate = [transaction mutableCopy];
					withDate[@"dateText"] =
							TGStarsTransactionDate(transaction[@"date"]);
					[rows addObject:TGStarsTransactionRow(withDate)];
				}
				if (!rows.count){
					[weakSelf showText:@"None" title:@"Stars Transactions"];
					return;
				}
				TGStarsTransactionsViewController *list =
						[[TGStarsTransactionsViewController alloc] initWithStyle:
								UITableViewStyleGrouped];
				list.rows = rows;
				list.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:list animated:YES];
			}];
		}];
	} else if ([action isEqualToString:@"subscriptions"]){
		[[TGStarsStore shared] starSubscriptionsOnlyExpiring:NO offset:@""
											  completion:^(NSDictionary *page,
														   NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"My Subscriptions"];
				return;
			}
			NSMutableArray *lines = [NSMutableArray array];
			for (NSDictionary *subscription in page[@"subscriptions"])
				[lines addObject:[NSString stringWithFormat:@"%@  chat %@  %@ stars  %@",
						subscription[@"id"], subscription[@"chatId"],
						subscription[@"starCount"],
						[subscription[@"isExpiring"] boolValue] ? @"expiring" : @"active"]];
			[weakSelf showText:(lines.count ? [lines componentsJoinedByString:@"\n"]
					: @"None") title:@"My Subscriptions"];
		}];
	} else if ([action isEqualToString:@"cancelSubscription"] ||
			   [action isEqualToString:@"reuseSubscription"]){
		BOOL reuse = [action isEqualToString:@"reuseSubscription"];
		[self askText:(reuse ? @"My Subscriptions" : @"Cancel Subscription")
				 message:nil placeholder:@"sub-1" text:nil
				 action:@"Send" completion:^(NSString *text){
			if (reuse){
				[[TGStarsStore shared] reuseStarSubscription:text
											  completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:@"My Subscriptions"];
				}];
			} else {
				[[TGStarsStore shared] setStarSubscription:text canceled:YES
											completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:@"My Subscriptions"];
				}];
			}
		}];
	} else if ([action isEqualToString:@"boostSlots"]){
		[[TGStarsStore shared] availableChatBoostSlotsWithCompletion:^(NSArray *slots, NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"Boost Slots"];
				return;
			}
			NSMutableArray *lines = [NSMutableArray array];
			for (NSDictionary *slot in slots)
				[lines addObject:[NSString stringWithFormat:@"Slot %@  chat %@  until %@",
						slot[@"slotId"], slot[@"currentlyBoostedChatId"],
						slot[@"cooldownUntilDate"]]];
			[weakSelf showText:(lines.count ? [lines componentsJoinedByString:@"\n"]
					: @"None") title:@"Boost Slots"];
		}];
	} else if ([action isEqualToString:@"boostStatus"]){
		[self askText:@"Boost Status" message:@"Chat ID" placeholder:@"123" text:nil
			   action:@"Read" completion:^(NSString *chat){
			[[TGStarsStore shared] chatBoostStatusForChat:chat.longLongValue
										   completion:^(NSDictionary *status, NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Boost Status"];
					return;
				}
				[weakSelf showText:[NSString stringWithFormat:
						@"Level %@\nBoosts: %@ (this level %@, next %@)\n%@",
						status[@"level"], status[@"boostCount"],
						status[@"currentLevelBoostCount"], status[@"nextLevelBoostCount"],
						status[@"boostUrl"]] title:@"Boost Status"];
			}];
		}];
	} else if ([action isEqualToString:@"boostFeatures"]){
		[[TGStarsStore shared] chatBoostFeaturesForChannel:YES
											completion:^(NSDictionary *features, NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"Boost Features"];
				return;
			}
			[weakSelf showText:[NSString stringWithFormat:
					@"%@ levels\nEmoji status from %@\nSpeech from %@\nNo ads from %@",
					features[@"levels"], features[@"minEmojiStatusBoostLevel"],
					features[@"minSpeechRecognitionBoostLevel"],
					features[@"minSponsoredMessageDisableBoostLevel"]]
						   title:@"Boost Features"];
		}];
	} else if ([action isEqualToString:@"boostLevelFeatures"]){
		[self askText:@"Boost Level" message:nil placeholder:@"1" text:@"1"
			   action:@"Read" completion:^(NSString *text){
			[[TGStarsStore shared] chatBoostLevelFeaturesForChannel:YES level:text.intValue
													 completion:^(NSDictionary *features,
																  NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Boost Level"];
					return;
				}
				[weakSelf showText:[NSString stringWithFormat:
						@"Level %@\nStory per day: %@\nSpeech: %@\nNo ads: %@",
						features[@"level"], features[@"storyPerDay"],
						[features[@"canRecognizeSpeech"] boolValue] ? @"yes" : @"no",
						[features[@"canDisableSponsoredMessages"] boolValue] ? @"yes" : @"no"]
							   title:@"Boost Level"];
			}];
		}];
	} else if ([action isEqualToString:@"boostLink"]){
		[self askText:@"Link" message:@"Chat ID" placeholder:@"123" text:nil
			   action:@"Read" completion:^(NSString *chat){
			[[TGStarsStore shared] chatBoostLinkForChat:chat.longLongValue
										 completion:^(NSString *link, NSString *error){
				[weakSelf finish:error == nil error:error title:@"Link"];
				if (link.length){
					[UIPasteboard generalPasteboard].string = link;
					[weakSelf showText:link title:@"Link"];
				}
			}];
		}];
	} else if ([action isEqualToString:@"boostLinkInfo"]){
		[self askText:@"Link" message:@"https://t.me/boost/..." placeholder:@"https://t.me/boost/x"
			 text:nil action:@"Read"
		   completion:^(NSString *text){
			[[TGStarsStore shared] chatBoostLinkInfo:text
									  completion:^(NSDictionary *info, NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Link"];
					return;
				}
				[weakSelf showText:[NSString stringWithFormat:@"Chat %@\nPublic: %@",
						info[@"chatId"], [info[@"isPublic"] boolValue] ? @"yes" : @"no"]
							   title:@"Link"];
			}];
		}];
	} else if ([action isEqualToString:@"boostList"]){
		[self askText:@"Boosts" message:@"Chat ID" placeholder:@"123" text:nil
			   action:@"Read" completion:^(NSString *chat){
			[[TGStarsStore shared] chatBoostsForChat:chat.longLongValue offset:@"" limit:20
									  completion:^(NSDictionary *page, NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Boosts"];
					return;
				}
				NSMutableArray *lines = [NSMutableArray array];
				for (NSDictionary *boost in page[@"boosts"])
					[lines addObject:[NSString stringWithFormat:@"%@  %@x  %@",
							boost[@"id"], boost[@"count"], boost[@"source"]]];
				[weakSelf showText:(lines.count ? [lines componentsJoinedByString:@"\n"]
						: @"None") title:@"Boosts"];
			}];
		}];
	} else if ([action isEqualToString:@"boostSend"]){
		[self askText:@"Boost A Chat" message:@"Chat ID" placeholder:@"123" text:nil
			   action:@"Next" completion:^(NSString *chat){
			[weakSelf askText:@"Boost A Chat" message:nil
						 placeholder:@"0" text:nil action:@"Boost"
				   completion:^(NSString *slots){
				NSMutableArray *ids = [NSMutableArray array];
				for (NSString *part in [slots componentsSeparatedByString:@","]){
					NSInteger value = part.intValue;
					if (value >= 0) [ids addObject:@(value)];
				}
				[[TGStarsStore shared] boostChat:chat.longLongValue slotIds:ids
								   completion:^(NSArray *remaining, NSString *error){
					[weakSelf finish:error == nil error:error title:@"Boost"];
					if (!error) [weakSelf showText:[NSString stringWithFormat:
							@"%lu slot(s) remain.", (unsigned long)remaining.count]
											 title:@"Boost"];
				}];
			}];
		}];
	} else if ([action isEqualToString:@"chatRevenue"]){
		[self askText:@"Revenue" message:@"Chat ID" placeholder:@"123" text:nil
			   action:@"Read" completion:^(NSString *chat){
			[[TGStarsStore shared] chatRevenueStatisticsForChat:chat.longLongValue dark:NO
												 completion:^(NSDictionary *statistics,
															  NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Revenue"];
					return;
				}
				[weakSelf showText:[NSString stringWithFormat:
						@"Total %@\nBalance %@\nAvailable %@\nWithdrawal: %@\nGraph: %@",
						statistics[@"totalAmount"], statistics[@"balanceAmount"],
						statistics[@"availableAmount"],
						[statistics[@"withdrawalEnabled"] boolValue] ? @"yes" : @"no",
						statistics[@"graph"]] title:@"Revenue"];
			}];
		}];
	} else if ([action isEqualToString:@"chatRevenueList"]){
		[self askText:@"Transactions" message:@"Chat ID" placeholder:@"123"
			 text:nil action:@"Read" completion:^(NSString *chat){
			[[TGStarsStore shared] chatRevenueTransactionsForChat:chat.longLongValue
														 offset:@"" limit:20
													 completion:^(NSDictionary *page,
																  NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Transactions"];
					return;
				}
				NSMutableArray *lines = [NSMutableArray array];
				for (NSDictionary *transaction in page[@"transactions"])
					[lines addObject:[NSString stringWithFormat:@"%@ %@",
							transaction[@"amount"], transaction[@"currency"]]];
				[weakSelf showText:(lines.count ? [lines componentsJoinedByString:@"\n"]
						: @"None") title:@"Transactions"];
			}];
		}];
	} else if ([action isEqualToString:@"starRevenue"]){
		int64_t ownerId = self.ownerId;
		if (!ownerId) ownerId = [[TGProfileStore shared].me[@"id"] longLongValue];
		[[TGStarsStore shared] starRevenueStatisticsForOwner:self.ownerKind ownerId:ownerId
													dark:NO
											  completion:^(NSDictionary *statistics,
														   NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"Revenue"];
				return;
			}
			[weakSelf showText:[NSString stringWithFormat:
					@"Total %@\nAvailable %@\nNext withdrawal in %@ s\nGraph: %@",
					statistics[@"total"], statistics[@"available"],
					statistics[@"nextWithdrawalIn"], statistics[@"graph"]]
						   title:@"Revenue"];
		}];
	} else if ([action isEqualToString:@"gramRevenue"]){
		[[TGStarsStore shared] gramRevenueStatisticsWithDark:NO
											  completion:^(NSDictionary *statistics,
														   NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"Revenue"];
				return;
			}
			[weakSelf showText:[NSString stringWithFormat:
					@"Total %@\nBalance %@\nAvailable %@\nGraph: %@",
					statistics[@"total"], statistics[@"balance"],
					statistics[@"available"], statistics[@"graph"]]
						   title:@"Revenue"];
		}];
	} else if ([action isEqualToString:@"paidRevenue"]){
		[self askText:@"Paid Message Revenue" message:@"User ID" placeholder:@"123"
			 text:nil action:@"Read" completion:^(NSString *text){
			[[TGStarsStore shared] paidMessageRevenueForUser:text.longLongValue
											  completion:^(int64_t stars, NSString *error){
				[weakSelf finish:error == nil error:error title:@"Revenue"];
				if (!error) [weakSelf showText:
						TGLocalizedFormat(@"%@ Stars", @(stars)) title:@"Revenue"];
			}];
		}];
	} else if ([action isEqualToString:@"topicRevenue"]){
		[self askText:@"Revenue" message:@"Chat ID" placeholder:@"123" text:nil
			   action:@"Next" completion:^(NSString *chat){
			[weakSelf askText:@"Revenue" message:@"Topic ID" placeholder:@"1"
				 text:nil action:@"Read" completion:^(NSString *topic){
				[[TGStarsStore shared] directMessagesChatTopicRevenueForChat:chat.longLongValue
																   topic:topic.longLongValue
															  completion:^(int64_t stars,
																		   NSString *error){
					[weakSelf finish:error == nil error:error title:@"Revenue"];
					if (!error) [weakSelf showText:
							TGLocalizedFormat(@"%@ Stars", @(stars))
											   title:@"Revenue"];
				}];
			}];
		}];
	} else if ([action isEqualToString:@"allowUnpaid"]){
		[self askText:@"Allow Unpaid Messages" message:@"User ID" placeholder:@"123"
				 text:nil action:@"Next" completion:^(NSString *user){
			[TGAlertSheet showChoices:@[@"Keep their payments", @"Refund their payments"]
								title:@"Allow Unpaid Messages" destructiveIndex:-1
							   inView:weakSelf.view onChoice:^(NSInteger index){
				[[TGStarsStore shared] allowUnpaidMessagesFromUser:user.longLongValue
													   refund:(index == 1)
												   completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:@"Unpaid Messages"];
				}];
			}];
		}];
	} else if ([action isEqualToString:@"unpaidToken"]){
		[self askText:@"Apply Unpaid Token" message:@"User ID" placeholder:@"123"
				 text:nil action:@"Next" completion:^(NSString *user){
			[weakSelf askText:@"Apply Unpaid Token" message:nil
					 placeholder:@"token" text:nil action:@"Apply"
				   completion:^(NSString *token){
				[[TGStarsStore shared] applyUnpaidMessagesToken:token
												   forUser:user.longLongValue
												completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:@"Unpaid Token"];
				}];
			}];
		}];
	} else if ([action isEqualToString:@"reactionSenders"]){
		[self askText:@"Paid Reaction Senders" message:@"Chat ID" placeholder:@"123"
				 text:nil action:@"Read" completion:^(NSString *chat){
			[[TGStarsStore shared] paidReactionSendersForChat:chat.longLongValue
												completion:^(NSArray *senders, NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Reactions"];
					return;
				}
				NSMutableArray *lines = [NSMutableArray array];
				for (NSDictionary *sender in senders)
					[lines addObject:[NSString stringWithFormat:@"%@  %@",
							sender[@"kind"], sender[@"id"]]];
				[weakSelf showText:(lines.count ? [lines componentsJoinedByString:@"\n"]
						: @"None") title:@"Reactions"];
			}];
		}];
	} else if ([action isEqualToString:@"chatPaidPrice"]){
		[self askText:@"Chat Paid Message Price" message:@"Chat ID" placeholder:@"123"
				 text:nil action:@"Next" completion:^(NSString *chat){
			[weakSelf askText:@"Chat Paid Message Price" message:@"Stars"
					 placeholder:@"0" text:nil action:@"Save"
				   completion:^(NSString *price){
				[[TGStarsStore shared] setChatPaidMessageStarCount:chat.longLongValue
														 count:price.intValue
													completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:@"Paid Messages"];
				}];
			}];
		}];
	} else if ([action isEqualToString:@"callPaidPrice"]){
		[self askText:@"Call Paid Message Price" message:@"Group Call"
			 placeholder:@"123" text:nil action:@"Next"
		   completion:^(NSString *call){
			[weakSelf askText:@"Call Paid Message Price" message:@"Stars"
					 placeholder:@"0" text:nil action:@"Save"
				   completion:^(NSString *price){
				[[TGStarsStore shared] setGroupCallPaidMessageStarCount:call.intValue
															 count:price.intValue
														completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:@"Paid Messages"];
				}];
			}];
		}];
	} else if ([action isEqualToString:@"topicUnpaid"]){
		[self askText:@"Topic Unpaid Messages" message:@"Chat ID" placeholder:@"123"
				 text:nil action:@"Next" completion:^(NSString *chat){
			[weakSelf askText:@"Topic Unpaid Messages" message:@"Topic ID"
					 placeholder:@"1" text:nil action:@"Next"
				   completion:^(NSString *topic){
				[TGAlertSheet showChoices:@[@"Allow unpaid messages",
											@"Disallow and refund"]
									title:@"Topic Unpaid Messages" destructiveIndex:-1
								   inView:weakSelf.view onChoice:^(NSInteger index){
					[[TGStarsStore shared] setDirectMessagesTopicUnpaid:chat.longLongValue
															 topic:topic.longLongValue
														   allowed:(index == 0)
															refund:(index == 1)
														completion:^(BOOL ok, NSString *error){
						[weakSelf finish:ok error:error title:@"Topic Unpaid Messages"];
					}];
				}];
			}];
		}];
	} else if ([action isEqualToString:@"receipt"]){
		[self askText:@"Receipt" message:@"Chat ID" placeholder:@"123"
				 text:nil action:@"Next" completion:^(NSString *chat){
			[weakSelf askText:@"Receipt" message:@"Message" placeholder:@"456"
					 text:nil action:@"Read" completion:^(NSString *message){
				[[TGStarsStore shared] paymentReceiptForChat:chat.longLongValue
												 message:message.longLongValue
											  completion:^(NSDictionary *receipt,
														   NSString *error){
					if (error){
						[weakSelf finish:NO error:error title:@"Receipt"];
						return;
					}
					[weakSelf showText:[NSString stringWithFormat:
							@"%@\n%@\n%@\n%@ Star(s)",
							receipt[@"title"], receipt[@"description"],
							receipt[@"kind"], receipt[@"starCount"]] title:@"Receipt"];
				}];
			}];
		}];
	} else if ([action isEqualToString:@"adAccount"]){
		int64_t ownerId = self.ownerId;
		if (!ownerId) ownerId = [[TGProfileStore shared].me[@"id"] longLongValue];
		[[TGStarsStore shared] starAdAccountURLForOwner:self.ownerKind ownerId:ownerId
										 completion:^(NSString *link, NSString *error){
			[weakSelf finish:error == nil error:error title:@"Telegram Ads"];
			if (link.length){
				[UIPasteboard generalPasteboard].string = link;
				[weakSelf showText:link title:@"Telegram Ads"];
			}
		}];
	} else if ([action isEqualToString:@"unrestrict"]){
		[self askText:@"Unrestrict Boost Count" message:@"Supergroup"
			 placeholder:@"123" text:nil action:@"Next"
		   completion:^(NSString *group){
			[weakSelf askText:@"Unrestrict Boost Count" message:nil
					 placeholder:@"1" text:nil action:@"Save"
				   completion:^(NSString *count){
				[[TGStarsStore shared] setSupergroupUnrestrictBoostCount:count.intValue
														 supergroupId:group.longLongValue
														  completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:@"Boost Settings"];
				}];
			}];
		}];
	} else if ([action isEqualToString:@"giveaway"]){
		[self askText:@"Giveaway" message:@"Chat ID" placeholder:@"123" text:nil
			   action:@"Next" completion:^(NSString *chat){
			[weakSelf askText:@"Giveaway" message:@"Message" placeholder:@"456"
				 text:nil action:@"Read" completion:^(NSString *message){
				[[TGStarsStore shared] giveawayInfoForChat:chat.longLongValue
											   message:message.longLongValue
											completion:^(NSDictionary *info, NSString *error){
					if (error){
						[weakSelf finish:NO error:error title:@"Giveaway"];
						return;
					}
					[weakSelf showText:[NSString stringWithFormat:
							@"%@\nWinner: %@\nWinners: %@\nWon: %@ stars\nCode: %@",
							info[@"kind"], [info[@"isWinner"] boolValue] ? @"yes" : @"no",
							info[@"winnerCount"], info[@"wonStarCount"],
							info[@"giftCode"]] title:@"Giveaway"];
				}];
			}];
		}];
	} else if ([action isEqualToString:@"collectible"]){
		[TGAlertSheet showChoices:@[@"Username", @"Phone Number"]
							title:@"Collectible" destructiveIndex:-1 inView:self.view
						 onChoice:^(NSInteger index){
			NSString *kind = index == 0 ? @"username" : @"phoneNumber";
			[weakSelf askText:@"Collectible" message:@"Value" placeholder:(index == 0 ? @"name" : @"+380...")
				 text:nil action:@"Read"
				   completion:^(NSString *value){
				[[TGStarsStore shared] collectibleItemInfoForKind:kind value:value
												   completion:^(NSDictionary *info,
																NSString *error){
					if (error){
						[weakSelf finish:NO error:error title:@"Collectible"];
						return;
					}
					[weakSelf showText:[NSString stringWithFormat:
							@"%@ %@\nBought %@\n%@",
							info[@"amount"], info[@"currency"],
							info[@"purchaseDate"], info[@"url"]]
								   title:@"Collectible"];
				}];
			}];
		}];
	} else if ([action isEqualToString:@"subscribe"]){
		[[TGStarsStore shared] clickPremiumSubscriptionButtonWithCompletion:
				^(BOOL ok, NSString *error){
			[weakSelf finish:ok error:error title:@"Premium"];
		}];
	} else if ([action isEqualToString:@"giftId"]){
		[self askGift:@"Gift ID" action:^(int64_t giftId){}];
	} else if ([action isEqualToString:@"available"]){
		[[TGStarsStore shared] availableGiftsWithCompletion:^(NSArray *gifts, NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"Gifts"];
				return;
			}
			NSMutableArray *lines = [NSMutableArray array];
			for (NSDictionary *gift in gifts)
				[lines addObject:[NSString stringWithFormat:@"%@  #%@  %@ stars",
						gift[@"title"], gift[@"id"], gift[@"starCount"]]];
			[weakSelf showText:(lines.count ? [lines componentsJoinedByString:@"\n"]
					: @"None") title:@"Gifts"];
		}];
	} else if ([action isEqualToString:@"canSend"]){
		[self askGift:@"Can Send Gift" action:^(int64_t giftId){
			[[TGStarsStore shared] canSendGift:giftId
								completion:^(NSDictionary *result, NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Gift"];
					return;
				}
				NSString *line = [NSString stringWithFormat:@"%@\n%@",
						result[@"type"], result[@"reason"]];
				[weakSelf showText:line title:@"Can Send Gift"];
			}];
		}];
	} else if ([action isEqualToString:@"received"]){
		[self askText:@"Received Gift" message:@"received_gift_id" placeholder:@"gift-1"
			 text:nil action:@"Read" completion:^(NSString *text){
			[[TGStarsStore shared] receivedGift:text
								 completion:^(NSDictionary *gift, NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Gift"];
					return;
				}
				[weakSelf showText:[NSString stringWithFormat:
						@"%@ %@\nSaved: %@\nPinned: %@\nCan upgrade: %@\nCan transfer: %@",
						gift[@"emoji"], gift[@"starCount"],
						[gift[@"isSaved"] boolValue] ? @"yes" : @"no",
						[gift[@"isPinned"] boolValue] ? @"yes" : @"no",
						[gift[@"canBeUpgraded"] boolValue] ? @"yes" : @"no",
						[gift[@"canBeTransferred"] boolValue] ? @"yes" : @"no"]
										   title:@"Received Gift"];
			}];
		}];
	} else if ([action isEqualToString:@"upgraded"] || [action isEqualToString:@"value"]){
		BOOL value = [action isEqualToString:@"value"];
		[self askText:(value ? @"Upgraded Gift Value" : @"Upgraded Gift")
				 message:@"Name" placeholder:@"gift-1" text:nil
				 action:@"Read" completion:^(NSString *text){
			if (value){
				[[TGStarsStore shared] upgradedGiftValueInfoNamed:text
												   completion:^(NSDictionary *info,
																NSString *error){
					if (error){
						[weakSelf finish:NO error:error title:@"Gift Value"];
						return;
					}
					[weakSelf showText:[NSString stringWithFormat:
							@"%@ %@\nAverage: %@\nMinimum: %@\n%@",
							info[@"value"], info[@"currency"],
							info[@"averageSalePrice"] ?: @(0),
							info[@"minimumPrice"],
							info[@"fragmentUrl"]] title:@"Gift Value"];
				}];
			} else {
				[[TGStarsStore shared] upgradedGiftNamed:text
										  completion:^(NSDictionary *gift, NSString *error){
					if (error){
						[weakSelf finish:NO error:error title:@"Gift"];
						return;
					}
					[weakSelf showText:[NSString stringWithFormat:
							@"%@\n#%@\n%@ %@\nValue: %@ %@",
							gift[@"title"], gift[@"number"], gift[@"model"],
							gift[@"symbol"], gift[@"valueAmount"],
							gift[@"valueCurrency"]] title:@"Upgraded Gift"];
				}];
			}
		}];
	} else if ([action isEqualToString:@"variants"] || [action isEqualToString:@"upgradePreview"]){
		BOOL preview = [action isEqualToString:@"upgradePreview"];
		[self askGift:(preview ? @"Upgrade Preview" : @"Gift Variants")
			   action:^(int64_t giftId){
			if (preview){
				[[TGStarsStore shared] giftUpgradePreviewForGift:giftId
												 completion:^(NSDictionary *data,
															  NSString *error){
					[weakSelf finish:error == nil error:error title:@"Upgrade Preview"];
					if (!error) [weakSelf showText:[NSString stringWithFormat:
							@"%@ models, %@ symbols, %@ backdrops, %@ prices",
							@([data[@"models"] count]), @([data[@"symbols"] count]),
							@([data[@"backdrops"] count]), @([data[@"prices"] count])]
										   title:@"Upgrade Preview"];
				}];
			} else {
				[[TGStarsStore shared] upgradedGiftVariantsForGift:giftId
												   completion:^(NSDictionary *data,
																NSString *error){
					[weakSelf finish:error == nil error:error title:@"Gift Variants"];
					if (!error) [weakSelf showText:[NSString stringWithFormat:
							@"%@ models, %@ symbols, %@ backdrops",
							@([data[@"models"] count]), @([data[@"symbols"] count]),
							@([data[@"backdrops"] count])] title:@"Gift Variants"];
				}];
			}
		}];
	} else if ([action isEqualToString:@"collections"]){
		int64_t ownerId = self.ownerId;
		if (!ownerId && [self.ownerKind isEqualToString:@"user"])
			ownerId = [[TGProfileStore shared].me[@"id"] longLongValue];
		[[TGStarsStore shared] giftCollectionsForOwner:self.ownerKind ownerId:ownerId
									   completion:^(NSArray *collections, NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"Gift Collections"];
				return;
			}
			NSMutableArray *lines = [NSMutableArray array];
			for (NSDictionary *collection in collections)
				[lines addObject:[NSString stringWithFormat:@"%@  %@ gifts",
						collection[@"name"], collection[@"giftCount"]]];
			[weakSelf showText:(lines.count ? [lines componentsJoinedByString:@"\n"]
					: @"None") title:@"Gift Collections"];
		}];
	} else if ([action isEqualToString:@"crafting"]){
		[self askGift:@"Gifts For Crafting" action:^(int64_t giftId){
			[[TGStarsStore shared] giftsForCraftingFromGift:giftId offset:@"" limit:20
											 completion:^(NSArray *gifts, NSString *error){
				[weakSelf finish:error == nil error:error title:@"Crafting"];
				if (!error) [weakSelf showText:[NSString stringWithFormat:
						@"%lu gift(s) can be crafted.", (unsigned long)gifts.count]
									   title:@"Crafting"];
			}];
		}];
	} else if ([action isEqualToString:@"resale"]){
		[self askGift:@"Gifts For Resale" action:^(int64_t giftId){
			[[TGStarsStore shared] searchGiftsForResaleFromGift:giftId
													 order:@"giftForResaleOrderPrice"
													offset:@""
													 limit:20
												completion:^(NSArray *gifts, NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Resale"];
					return;
				}
				NSMutableArray *lines = [NSMutableArray array];
				for (NSDictionary *gift in gifts)
					[lines addObject:[NSString stringWithFormat:@"%@  #%@",
							gift[@"title"] ?: gift[@"name"], gift[@"number"]]];
				[weakSelf showText:(lines.count ? [lines componentsJoinedByString:@"\n"]
						: @"None") title:@"Resale"];
			}];
		}];
	} else if ([action isEqualToString:@"emojiStatuses"]){
		[[TGStarsStore shared] upgradedGiftEmojiStatusesWithCompletion:^(NSArray *statuses,
																	 NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"Gift Statuses"];
				return;
			}
			NSMutableArray *lines = [NSMutableArray array];
			for (NSDictionary *status in statuses)
				[lines addObject:status[@"giftTitle"] ?: status[@"type"]];
			[weakSelf showText:(lines.count ? [lines componentsJoinedByString:@"\n"]
					: @"None") title:@"Gift Statuses"];
		}];
	} else if ([action isEqualToString:@"themes"]){
		[[TGStarsStore shared] giftChatThemesWithOffset:@"" limit:20
										 completion:^(NSArray *themes, NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"Gift Themes"];
				return;
			}
			NSMutableArray *lines = [NSMutableArray array];
			for (NSDictionary *theme in themes)
				[lines addObject:theme[@"giftTitle"] ?: theme[@"giftName"]];
			[weakSelf showText:(lines.count ? [lines componentsJoinedByString:@"\n"]
					: @"None") title:@"Gift Themes"];
		}];
	} else if ([action isEqualToString:@"auctionState"]){
		[self askText:@"Gift Auction" message:nil placeholder:@"auction-1"
				 text:nil action:@"Read" completion:^(NSString *auction){
			[[TGStarsStore shared] giftAuctionStateForAuction:auction
											   completion:^(NSDictionary *state,
															NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Gift Auction"];
					return;
				}
				[weakSelf showText:[NSString stringWithFormat:
						@"%@\nGift: %@\nStart %@  end %@\nMin bid %@\nRound %@ of %@",
						state[@"state"], state[@"giftTitle"], state[@"startDate"],
						state[@"endDate"], state[@"minBid"], state[@"currentRoundNumber"],
						state[@"totalRoundCount"]] title:@"Gift Auction"];
			}];
		}];
	} else if ([action isEqualToString:@"auctionGifts"]){
		[self askGift:@"Acquired Auction Gifts" action:^(int64_t giftId){
			[[TGStarsStore shared] giftAuctionAcquiredGiftsForGift:giftId
													completion:^(NSArray *gifts, NSString *error){
				if (error){
					[weakSelf finish:NO error:error title:@"Auction Gifts"];
					return;
				}
				NSMutableArray *lines = [NSMutableArray array];
				for (NSDictionary *gift in gifts)
					[lines addObject:[NSString stringWithFormat:
							@"#%@  %@ stars  round %@", gift[@"uniqueGiftNumber"],
							gift[@"starCount"], gift[@"roundNumber"]]];
				[weakSelf showText:(lines.count ? [lines componentsJoinedByString:@"\n"]
						: @"None") title:@"Auction Gifts"];
			}];
		}];
	} else if ([action isEqualToString:@"auctionOpen"] ||
			   [action isEqualToString:@"auctionClose"]){
		BOOL open = [action isEqualToString:@"auctionOpen"];
		[self askGift:(open ? @"Open Gift Auction" : @"Close Gift Auction")
			   action:^(int64_t giftId){
			if (open){
				[[TGStarsStore shared] openGiftAuctionForGift:giftId
											   completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:@"Gift Auction"];
				}];
			} else {
				[[TGStarsStore shared] closeGiftAuctionForGift:giftId
												completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:@"Gift Auction"];
				}];
			}
		}];
	} else if ([action isEqualToString:@"promo"]){
		[[TGStarsStore shared] upgradedGiftsPromotionalAnimationWithCompletion:
				^(NSDictionary *animation, NSString *error){
			[weakSelf finish:error == nil error:error title:@"Promotional Animation"];
			if (!error) [weakSelf showText:[NSString stringWithFormat:
					@"%@  file %@", animation[@"@type"], animation[@"file"][@"id"]]
								   title:@"Promotional Animation"];
		}];
	}
}

@end

// vim:ft=objc
