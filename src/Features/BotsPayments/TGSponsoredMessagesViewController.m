//
// TGSponsoredMessagesViewController.m - one page for every advertisement
// TDLib hands a user client: channel posts, search results, video overlays
// and the owner switches that turn them off.
//
// The requests are real and the server's answer is the row's text. A channel
// account with no ads is told so rather than shown an empty table, and a
// report that Telegram wants a reason for opens its own option list.
//
#import "TGSponsoredMessagesViewController.h"
#import "TGAlertSheet.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGStarsStore.h"

@interface TGSponsoredMessagesViewController ()
@property (nonatomic, assign) BOOL myAdsEnabled;
@property (nonatomic, assign) BOOL channelAdsEnabled;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) NSArray *answerLines;
@end

@implementation TGSponsoredMessagesViewController

- (instancetype)init {
	if ((self = [super init])){
		_myAdsEnabled = YES;
		_channelAdsEnabled = YES;
		_answerLines = @[@"None"];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Telegram Ads";
	[self rebuildSections];
}

- (void)rebuildSections {
	NSMutableArray *answers = [NSMutableArray array];
	for (NSString *line in self.answerLines)
		[answers addObject:TGBInfo(line, nil)];

	NSMutableArray *chatRows = [NSMutableArray array];
	[chatRows addObject:TGBAction(@"Chat ID", self.chatId
			? [NSString stringWithFormat:@"%lld", self.chatId] : @"Set", @"chatId")];
	[chatRows addObject:TGBAction(@"Show", nil, @"load")];

	NSMutableArray *switchRows = [NSMutableArray array];
	[switchRows addObject:TGBAction(@"Telegram Ads",
			self.myAdsEnabled ? @"On" : @"Off",
			@"toggleMine")];
	[switchRows addObject:TGBAction(@"Channel",
			self.channelAdsEnabled ? @"On" : @"Off",
			@"toggleChannel")];
	[switchRows addObject:TGBAction(@"Supergroup", nil, @"supergroupId")];

	NSMutableArray *searchRows = [NSMutableArray array];
	[searchRows addObject:TGBAction(@"Search Query",
			self.searchQuery.length ? self.searchQuery : @"Set", @"query")];
	[searchRows addObject:TGBAction(@"Search", nil, @"search")];

	NSMutableArray *videoRows = [NSMutableArray array];
	[videoRows addObject:TGBAction(@"Video", self.messageId
			? [NSString stringWithFormat:@"%lld", self.messageId] : @"Set",
			@"videoMessageId")];
	[videoRows addObject:TGBAction(@"Show", nil, @"loadVideo")];

	NSMutableArray *speechRows = [NSMutableArray array];
	[speechRows addObject:TGBAction(@"Voice Message", nil, @"transcribe")];
	[speechRows addObject:TGBAction(@"Rate Transcription", nil, @"speechGood")];
	[speechRows addObject:TGBAction(@"Rate Transcription", nil, @"speechBad")];

	self.sections = @[
		TGBSection(@"ADS IN CHANNELS", nil, chatRows),
		TGBSection(@"Settings", nil, switchRows),
		TGBSection(@"Search", nil, searchRows),
		TGBSection(@"Video", nil, videoRows),
		TGBSection(@"Voice", nil, speechRows),
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

- (void)showAds:(NSArray *)ads title:(NSString *)title {
	if (!ads.count){
		[self showMessage:@"None"
					title:title];
		return;
	}
	NSMutableArray *titles = [NSMutableArray array];
	for (NSDictionary *ad in ads){
		NSString *line = ad[@"title"] ?: ad[@"text"] ?: ad[@"sponsorInfo"] ?: @"";
		if (!line.length)
			line = @"Ad";
		[titles addObject:line];
	}
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles title:title destructiveIndex:-1 inView:self.view
					 onChoice:^(NSInteger index){
		[weakSelf actOnAd:ads[(NSUInteger)index] title:title];
	}];
}

- (void)actOnAd:(NSDictionary *)ad title:(NSString *)title {
	__weak typeof(self) weakSelf = self;
	NSString *kind = ad[@"kind"];
	BOOL chatAd = [kind isEqualToString:@"chat"];
	BOOL videoAd = [kind isEqualToString:@"video"];
	NSString *report = @"Report Ad";
	[TGAlertSheet showChoices:@[@"Open", @"View", report]
						title:title destructiveIndex:-1 inView:self.view
					 onChoice:^(NSInteger index){
		if (index == 0){
			if (chatAd){
				[[TGStarsStore shared] clickSponsoredMessage:[ad[@"messageId"] longLongValue]
												  inChat:weakSelf.chatId
											   mediaClick:NO
											 fromFullscreen:NO
											   completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:title];
				}];
			} else if (videoAd){
				[[TGStarsStore shared] clickVideoAdvertisement:[ad[@"uniqueId"] longLongValue]
											   completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:title];
				}];
			} else {
				[[TGStarsStore shared] openSponsoredChat:[ad[@"uniqueId"] longLongValue]
										  completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:title];
				}];
			}
		} else if (index == 1){
			if (chatAd){
				[self showMessage:@"A channel advertisement has no separate view call; "
								  @"opening it is the click." title:title];
			} else if (videoAd){
				[[TGStarsStore shared] viewVideoAdvertisement:[ad[@"uniqueId"] longLongValue]
											  completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:title];
				}];
			} else {
				[[TGStarsStore shared] viewSponsoredChat:[ad[@"uniqueId"] longLongValue]
										  completion:^(BOOL ok, NSString *error){
					[weakSelf finish:ok error:error title:title];
				}];
			}
		} else {
			[self reportAd:ad title:title];
		}
	}];
}

- (void)reportAd:(NSDictionary *)ad title:(NSString *)title {
	__weak typeof(self) weakSelf = self;
	void (^done)(NSDictionary *, NSString *) = ^(NSDictionary *result, NSString *error){
		if (error){
			[weakSelf finish:NO error:error title:title];
			return;
		}
		NSArray *options = result[@"options"];
		if ([options isKindOfClass:NSArray.class] && options.count){
			NSMutableArray *titles = [NSMutableArray array];
			for (NSDictionary *option in options)
				[titles addObject:option[@"text"] ?: @"Reason"];
			[TGAlertSheet showChoices:titles title:title destructiveIndex:-1
							   inView:weakSelf.view onChoice:^(NSInteger index){
				NSDictionary *option = options[(NSUInteger)index];
				[weakSelf sendReport:ad option:option[@"id"] title:title];
			}];
			return;
		}
		[weakSelf finish:YES error:nil title:title];
		[weakSelf showMessage:[NSString stringWithFormat:@"Telegram answered: %@",
				result[@"type"] ?: @"received"] title:title];
	};
	if ([ad[@"kind"] isEqualToString:@"chat"]){
		[[TGStarsStore shared] reportSponsoredMessage:[ad[@"messageId"] longLongValue]
										   inChat:weakSelf.chatId option:@""
									   completion:done];
	} else if ([ad[@"kind"] isEqualToString:@"video"]){
		[[TGStarsStore shared] reportVideoAdvertisement:[ad[@"uniqueId"] longLongValue]
											option:@""
										completion:done];
	} else {
		[[TGStarsStore shared] reportSponsoredChat:[ad[@"uniqueId"] longLongValue]
										option:@""
									completion:done];
	}
}

- (void)sendReport:(NSDictionary *)ad option:(NSString *)optionId title:(NSString *)title {
	__weak typeof(self) weakSelf = self;
	void (^done)(NSDictionary *, NSString *) = ^(NSDictionary *result, NSString *error){
		[weakSelf finish:error == nil error:error title:title];
	};
	if ([ad[@"kind"] isEqualToString:@"chat"]){
		[[TGStarsStore shared] reportSponsoredMessage:[ad[@"messageId"] longLongValue]
										   inChat:weakSelf.chatId option:optionId
									   completion:done];
	} else if ([ad[@"kind"] isEqualToString:@"video"]){
		[[TGStarsStore shared] reportVideoAdvertisement:[ad[@"uniqueId"] longLongValue]
											option:optionId completion:done];
	} else {
		[[TGStarsStore shared] reportSponsoredChat:[ad[@"uniqueId"] longLongValue]
										option:optionId completion:done];
	}
}

- (void)didChooseAction:(NSString *)action row:(NSDictionary *)row {
	__weak typeof(self) weakSelf = self;
	if ([action isEqualToString:@"chatId"]){
		[self askText:@"Chat ID" message:nil
		  placeholder:@"-100..." text:(self.chatId
				  ? [NSString stringWithFormat:@"%lld", self.chatId] : nil)
			   action:@"Save" completion:^(NSString *text){
			weakSelf.chatId = text.longLongValue;
			[weakSelf rebuildSections];
		}];
	} else if ([action isEqualToString:@"load"]){
		[[TGStarsStore shared] sponsoredMessagesForChat:self.chatId
										 completion:^(NSArray *messages, NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"Telegram Ads"];
				return;
			}
			weakSelf.answerLines = messages.count
					? @[[NSString stringWithFormat:@"%lu advertisement(s) for this chat.",
						 (unsigned long)messages.count]]
					: @[@"None"];
			[weakSelf rebuildSections];
			[weakSelf showAds:messages title:@"Telegram Ads"];
		}];
	} else if ([action isEqualToString:@"toggleMine"]){
		weakSelf.myAdsEnabled = !weakSelf.myAdsEnabled;
		[[TGStarsStore shared] setSponsoredMessagesEnabled:weakSelf.myAdsEnabled
											completion:^(BOOL ok, NSString *error){
			[weakSelf finish:ok error:error title:@"Telegram Ads"];
		}];
	} else if ([action isEqualToString:@"toggleChannel"]){
		[weakSelf askText:@"Channel" message:@"Supergroup"
			  placeholder:@"123" text:nil action:@"Next" completion:^(NSString *text){
			int64_t supergroupId = text.longLongValue;
			weakSelf.channelAdsEnabled = !weakSelf.channelAdsEnabled;
			[[TGStarsStore shared] setChannelSponsoredMessagesEnabled:weakSelf.channelAdsEnabled
													 supergroupId:supergroupId
													  completion:^(BOOL ok, NSString *error){
				[weakSelf finish:ok error:error title:@"Channel"];
			}];
		}];
	} else if ([action isEqualToString:@"supergroupId"]){
		[self askText:@"Supergroup" message:nil
		  placeholder:@"123" text:nil action:@"Save" completion:^(NSString *text){
			[weakSelf finish:YES error:nil title:@"Supergroup"];
		}];
	} else if ([action isEqualToString:@"query"]){
		[self askText:@"Search" message:nil placeholder:@"news" text:self.searchQuery
			   action:@"Save" completion:^(NSString *text){
			weakSelf.searchQuery = text;
			[weakSelf rebuildSections];
		}];
	} else if ([action isEqualToString:@"search"]){
		[[TGStarsStore shared] searchSponsoredChats:self.searchQuery
									 completion:^(NSArray *chats, NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"Search"];
				return;
			}
			weakSelf.answerLines = @[[NSString stringWithFormat:@"%lu sponsored chat(s).",
					(unsigned long)chats.count]];
			[weakSelf rebuildSections];
			[weakSelf showAds:chats title:@"Search"];
		}];
	} else if ([action isEqualToString:@"videoMessageId"]){
		[self askText:@"Video" message:nil placeholder:@"123"
				 text:(self.messageId
				  ? [NSString stringWithFormat:@"%lld", self.messageId] : nil)
			   action:@"Save" completion:^(NSString *text){
			weakSelf.messageId = text.longLongValue;
			[weakSelf rebuildSections];
		}];
	} else if ([action isEqualToString:@"loadVideo"]){
		[[TGStarsStore shared] videoAdvertisementsForChat:self.chatId
											  message:self.messageId
										   completion:^(NSArray *ads, NSString *error){
			if (error){
				[weakSelf finish:NO error:error title:@"Video"];
				return;
			}
			weakSelf.answerLines = @[[NSString stringWithFormat:@"%lu video advertisement(s).",
					(unsigned long)ads.count]];
			[weakSelf rebuildSections];
			[weakSelf showAds:ads title:@"Video"];
		}];
	} else if ([action isEqualToString:@"transcribe"]){
		[[TGStarsStore shared] recognizeSpeechInChat:self.chatId message:self.messageId
									  completion:^(BOOL ok, NSString *error){
			[weakSelf finish:ok error:error title:@"Voice Message"];
		}];
	} else if ([action isEqualToString:@"speechGood"] || [action isEqualToString:@"speechBad"]){
		BOOL good = [action isEqualToString:@"speechGood"];
		[[TGStarsStore shared] rateSpeechInChat:self.chatId message:self.messageId
									 isGood:good completion:^(BOOL ok, NSString *error){
			[weakSelf finish:ok error:error title:@"Rate Transcription"];
		}];
	}
}

@end

// vim:ft=objc
