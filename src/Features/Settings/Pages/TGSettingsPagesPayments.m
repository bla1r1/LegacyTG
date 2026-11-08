#import "TGSettingsViewControllerInternal.h"
#import "RootViewController.h"
#import "TGAlertSheet.h"
#import "TGForwardPicker.h"
#import "TGListViewController.h"
#import "TGStyle.h"
#import "TGDevGalleryViewController.h"
#import "TGGhostMode.h"
#import "AppDelegate.h"
#import "TGChatViewController.h"
#import "TGDevShowcase.h"
#import "TGStickerPacksViewController.h"
#import "TGStorySettingsViewController.h"
#import "TGStoriesMenuViewController.h"
#import "TGSettingsViewController+Tier2.h"
#import "TGEmojiStatusViewController.h"
#import "TGSponsoredMessagesViewController.h"
#import "TGDevEnvironmentViewController.h"
#import "TGDevBotConsoleViewController.h"
#import "TGStarsGiftsViewController.h"
#import "TGDevTestHarnessViewController.h"
#import "TGAffiliateProgramsViewController.h"
#import "TGSupportInfoViewController.h"
#import "TGCallViewController.h"


/// A custom method's answer is a string the app has no schema for. When it is
/// JSON, pretty-print it so the viewer reads like a response rather than one
/// long line; otherwise show it as the lines TDLib sent.
static NSArray *TGCustomResultRows(NSString *result) {
	NSMutableArray *rows = [NSMutableArray array];
	NSString *text = result.length ? result : @"None";
	NSData *raw = [text dataUsingEncoding:NSUTF8StringEncoding];
	id parsed = raw.length
			? [NSJSONSerialization JSONObjectWithData:raw options:0 error:nil] : nil;
	if (parsed){
		NSData *pretty = [NSJSONSerialization dataWithJSONObject:parsed
				options:NSJSONWritingPrettyPrinted error:nil];
		if (pretty.length)
			text = [[NSString alloc] initWithData:pretty encoding:NSUTF8StringEncoding]
					?: text;
	}
	for (NSString *line in [text componentsSeparatedByString:@"\n"]){
		NSMutableDictionary *row = [@{@"title" : line ?: @""} mutableCopy];
		[rows addObject:row];
	}
	return rows;
}


@implementation TGSettingsViewController (TGSettingsPagesPayments)

#pragma mark - orders and payment data

/// Every non-empty line of an orderInfo, so the sheet reads like the form it
/// came from instead of a raw object.
static NSString *TGOrderLines(NSDictionary *order) {
	if (![order isKindOfClass:NSDictionary.class])
		return @"";
	NSMutableArray *lines = [NSMutableArray array];
	NSArray *keys = @[@"name", @"phone_number", @"email_address"];
	NSArray *titles = @[@"Name", @"Phone", @"Email"];
	for (NSUInteger i = 0; i < keys.count; i++){
		NSString *value = order[keys[i]];
		if ([value isKindOfClass:NSString.class] && value.length)
			[lines addObject:[NSString stringWithFormat:@"%@: %@", titles[i], value]];
	}
	NSDictionary *address = order[@"shipping_address"];
	if ([address isKindOfClass:NSDictionary.class]){
		NSArray *parts = @[@"street_line1", @"street_line2", @"city", @"state",
						   @"postal_code", @"country_code"];
		NSMutableArray *where = [NSMutableArray array];
		for (NSString *key in parts){
			NSString *value = address[key];
			if ([value isKindOfClass:NSString.class] && value.length)
				[where addObject:value];
		}
		if (where.count)
			[lines addObject:[NSString stringWithFormat:@"Address: %@",
					[where componentsJoinedByString:@", "]]];
	}
	return [lines componentsJoinedByString:@"\n"];
}

- (NSArray *)paymentSections {
	__weak typeof(self) weakSelf = self;
	NSString *orderDetail;
	if (!self.savedOrderLoaded)
		orderDetail = @"Loading...";
	else if (self.savedOrder)
		orderDetail = self.savedOrder[@"name"] ?: @"Payment Info";
	else
		orderDetail = @"None";

	NSMutableArray *orderRows = [NSMutableArray array];
	[orderRows addObject:TGTapRow(@"Payment Info", orderDetail, ^{
		NSString *body = weakSelf.savedOrder
				? TGOrderLines(weakSelf.savedOrder)
				: (weakSelf.savedOrderError ?: @"None");
		[TGAlertSheet showMessage:body.length ? body : @"Empty"
							title:@"Payment Info"
						   inView:weakSelf.view];
	})];
	if (self.savedOrder){
		[orderRows addObject:TGRedRow(@"Clear Payment and Shipping Info", ^{
			[TGAlertSheet showConfirm:nil
								title:@"Clear Payment and Shipping Info"
							   action:@"Delete"
						  destructive:YES
							   inView:weakSelf.view
							onConfirm:^{
				[[TGClient shared] deleteSavedOrderInfoWithCompletion:^(BOOL ok,
																		NSString *error){
					if (!ok){
						[TGAlertSheet showMessage:(error ?: @"An error occurred.")
											title:@"Clear Payment and Shipping Info"
										   inView:weakSelf.view];
						return;
					}
					weakSelf.savedOrder = nil;
					weakSelf.savedOrderError = nil;
					weakSelf.savedOrderLoaded = YES;
					[weakSelf rebuild];
				}];
			}];
		})];
	}

	return @[
		TGSection(@"Payment Info", nil, orderRows),
	];
}

#if TG_DEV
- (void)showBankCardLookup {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Look Up"
					message:nil
				placeholder:@"4111 1111 1111 1111"
					 text:nil action:@"Look Up" inView:self.view
				 onSubmit:^(NSString *number){
		[[TGClient shared] bankCardInfoForNumber:number
									  completion:^(NSDictionary *info, NSString *error){
			if (!info){
				[TGAlertSheet showMessage:(error ?: @"An error occurred.")
									title:@"Payment Method"
								   inView:weakSelf.view];
				return;
			}
			NSString *title = info[@"title"] ?: @"Payment Method";
			NSArray *actions = [info[@"actions"] isKindOfClass:NSArray.class]
					? info[@"actions"] : @[];
			NSMutableArray *titles = [NSMutableArray array];
			for (NSDictionary *action in actions){
				NSString *text = action[@"text"];
				if ([text isKindOfClass:NSString.class] && text.length)
					[titles addObject:text];
			}
			if (!titles.count){
				[TGAlertSheet showMessage:title title:@"Payment Method" inView:weakSelf.view];
				return;
			}
			[TGAlertSheet showChoices:titles
								title:title
							  message:nil
					   destructiveIndex:-1
							   inView:weakSelf.view
							 onChoice:^(NSInteger index){
				NSString *url = actions[(NSUInteger)index][@"url"];
				if ([url isKindOfClass:NSString.class] && url.length)
					[weakSelf openURL:url];
			}];
		}];
	}];
}

- (void)addOfferFlow {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Offer"
					message:nil
				placeholder:@"-100..."
					 text:nil action:@"Next" inView:self.view
				 onSubmit:^(NSString *chat){
		int64_t chatId = chat.longLongValue;
		[TGAlertSheet showInput:@"Offer"
						message:nil
					placeholder:@"123"
						 text:nil action:@"Next" inView:weakSelf.view
					 onSubmit:^(NSString *message){
			int64_t messageId = message.longLongValue;
			[TGAlertSheet showInput:@"Offer"
							message:@"Stars"
						placeholder:@"100"
							 text:nil action:@"Send" inView:weakSelf.view
						 onSubmit:^(NSString *stars){
				[[TGClient shared] addOfferToMessage:messageId
											  inChat:chatId
										   starCount:stars.longLongValue
											sendDate:0
										  completion:^(NSDictionary *sent,
													   NSString *error){
					if (error){
						[TGAlertSheet showMessage:error
											title:@"Offer"
										   inView:weakSelf.view];
						return;
					}
					NSString *body = sent[@"id"]
							? [NSString stringWithFormat:@"Offer sent. Message id %@.",
									sent[@"id"]]
							: @"Done";
					[TGAlertSheet showMessage:body
										title:@"Offer"
									   inView:weakSelf.view];
				}];
			}];
		}];
	}];
}

- (void)validateOrderFlow {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Validate an Order"
					message:nil
				placeholder:@"invoice-name"
					 text:nil action:@"Next" inView:self.view
				 onSubmit:^(NSString *invoice){
		NSMutableDictionary *values = [NSMutableDictionary dictionary];
		values[@"invoice"] = invoice;
		[TGAlertSheet showChoices:@[@"Check", @"Save"]
							title:@"Validate an Order"
						  message:nil
				 destructiveIndex:-1
						   inView:weakSelf.view
						 onChoice:^(NSInteger index){
			BOOL save = index == 1;
			NSArray *keys = @[@"name", @"phone_number", @"email_address",
							  @"street_line1", @"city", @"postal_code",
							  @"country_code"];
			NSArray *prompts = @[@"Name", @"Phone Number", @"Email",
								 @"Street", @"City", @"Postal code",
								 @"Country Code"];
			[weakSelf askOrderFieldAtIndex:0 keys:keys prompts:prompts
									values:values allowSave:save];
		}];
	}];
}

/// The order form is seven fields and no more: state and the second street
/// line are the two an invoice rarely asks for, and orderInfo sends them as
/// empty strings rather than leaving a required key out.
- (void)askOrderFieldAtIndex:(NSUInteger)index
						keys:(NSArray *)keys
					 prompts:(NSArray *)prompts
					  values:(NSMutableDictionary *)values
				   allowSave:(BOOL)allowSave {
	if (index >= keys.count){
		[self runOrderValidation:values allowSave:allowSave];
		return;
	}
	__weak typeof(self) weakSelf = self;
	NSString *key = keys[index];
	[TGAlertSheet showInput:@"Validate an Order"
					message:nil
				placeholder:prompts[index]
					 text:nil
				   action:(index + 1 == keys.count ? @"Done" : @"Next")
				   inView:self.view
				 onSubmit:^(NSString *text){
		values[key] = text;
		[weakSelf askOrderFieldAtIndex:index + 1 keys:keys prompts:prompts
								values:values allowSave:allowSave];
	}];
}

- (void)runOrderValidation:(NSMutableDictionary *)values allowSave:(BOOL)allowSave {
	NSString *invoice = values[@"invoice"];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] validateOrderInfoForInvoice:invoice order:values
										 allowSave:allowSave
										completion:^(NSDictionary *validated,
													 NSString *error){
		if (error){
			[TGAlertSheet showMessage:error title:@"Validate an Order"
							   inView:weakSelf.view];
			return;
		}
		NSMutableArray *lines = [NSMutableArray array];
		NSString *orderId = validated[@"order_info_id"];
		if ([orderId isKindOfClass:NSString.class] && orderId.length)
			[lines addObject:[NSString stringWithFormat:@"Order info id: %@", orderId]];
		NSArray *options = [validated[@"shipping_options"] isKindOfClass:NSArray.class]
				? validated[@"shipping_options"] : @[];
		if (options.count){
			[lines addObject:@"Shipping Info"];
			for (NSDictionary *option in options){
				NSMutableArray *prices = [NSMutableArray array];
				NSArray *parts = [option[@"price_parts"] isKindOfClass:NSArray.class]
						? option[@"price_parts"] : @[];
				for (NSDictionary *part in parts){
					NSString *label = part[@"label"];
					NSNumber *amount = part[@"amount"];
					if ([label isKindOfClass:NSString.class] && label.length)
						[prices addObject:[NSString stringWithFormat:@"%@ %@",
								label, amount ?: @0]];
				}
				[lines addObject:[NSString stringWithFormat:@"· %@%@",
						option[@"title"] ?: @"Option",
						prices.count ? [NSString stringWithFormat:@" - %@",
								[prices componentsJoinedByString:@", "]] : @""]];
			}
		} else {
			[lines addObject:@"Done"];
		}
		[TGAlertSheet showMessage:([lines componentsJoinedByString:@"\n"])
							title:@"Validate an Order"
						   inView:weakSelf.view];
	}];
}

/// Record that a diagnostic went for this call, so the row says so on the
/// next open. The default is the only place it belongs: TDLib keeps no flag
/// for "this user already sent the log".
- (void)noteCallDiagnostic:(NSString *)kind forCall:(NSDictionary *)call {
	NSString *key = [NSString stringWithFormat:@"%lld:%lld",
			(long long)[call[@"chatId"] longLongValue],
			(long long)[call[@"messageId"] longLongValue]];
	if ([key isEqualToString:@"0:0"])
		return;
	if (!self.callDiagnostics)
		self.callDiagnostics = [NSMutableDictionary dictionary];
	NSMutableArray *kinds = [self.callDiagnostics[key] mutableCopy]
			?: [NSMutableArray array];
	if (![kinds containsObject:kind])
		[kinds addObject:kind];
	self.callDiagnostics[key] = kinds;
	[NSUserDefaults.standardUserDefaults setObject:self.callDiagnostics
											forKey:@"TGCallDiagnosticsSent"];
	[self rebuild];
}

/// Dev mode's settings tab: what the build is, and every console that has no
/// place in a person's settings.
- (NSArray *)debugSections {
	__weak typeof(self) weakSelf = self;
	NSDictionary *info = [NSBundle mainBundle].infoDictionary;

	// Whether the bundled emoji font actually registered - the one thing that
	// cannot be told apart from "no emoji in this message" by looking.
	UIFont *emoji = TGFontEmojiMeta();

	NSMutableArray *facts = [NSMutableArray array];
	[facts addObject:TGTapRow(@"Application", [NSString stringWithFormat:@"%@ (%@)",
			info[@"CFBundleShortVersionString"] ?: @"?",
			info[@"CFBundleVersion"] ?: @"?"], nil)];
	[facts addObject:TGTapRow(@"TDLib", self.tdlibVersion ?: @"...", nil)];
	[facts addObject:TGTapRow(@"System", [UIDevice currentDevice].systemVersion, nil)];
	[facts addObject:TGTapRow(@"Device", [TGDevice modelName] ?: @"?", nil)];
	[facts addObject:TGTapRow(@"Machine", [TGDevice machine] ?: @"?", nil)];
	[facts addObject:TGTapRow(@"Tier", [TGDevice tierName] ?: @"?", nil)];
	[facts addObject:TGTapRow(@"Chip", [TGDevice chip] ?: @"unknown", nil)];
	[facts addObject:TGTapRow(@"Memory", [NSString stringWithFormat:@"%lu MB",
			(unsigned long)[TGCapabilities memoryMB]], nil)];
	[facts addObject:TGTapRow(@"Architecture",
			[TGCapabilities is64Bit] ? @"arm64" : @"armv7", nil)];
	[facts addObject:TGTapRow(@"Emoji",
			emoji ? emoji.fontName : @"NOT REGISTERED", nil)];
	[facts addObject:TGTapRow(@"Color Theme", [[TGTheme shared] currentThemeId], nil)];

	return @[
		TGSection(@"Test Account", nil, @[
			TGSwitchRow(@"Ghost Mode", TGGhostModeOn(), ^(BOOL on){
				[[NSUserDefaults standardUserDefaults] setBool:on forKey:@"TGGhostMode"];
				[[NSUserDefaults standardUserDefaults] synchronize];
				TGGhostModeSetOn(on);
			}),
		]),

		TGSection(@"Consoles", nil, @[
			TGOpenRow(@"Languages", nil, ^{
				[weakSelf openPage:TGSettingsPageLanguageDev];
			}),
			TGOpenRow(@"Invoice Tools", nil, ^{
				[weakSelf openPage:TGSettingsPagePaymentDev];
			}),
			TGOpenRow(@"Stories Menu", nil, ^{
				TGStoriesMenuViewController *stories = [[TGStoriesMenuViewController alloc]
						initWithChatId:[[TGClient shared] savedMessagesChatId] title:@"Your Story"];
				stories.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:stories animated:YES];
			}),
			[weakSelf tier2ToolsRow],
			[weakSelf tier2ProxyCarrierRow],
		]),

		TGSection(@"Components", nil, @[
			// The component gallery is a development surface, not a setting.
			// It sat in Appearance next to the theme picker, where a user had
			// no reason to open it.
			TGOpenRow(@"UI Component Gallery", nil, ^{
				TGDevGalleryViewController *gallery = [[TGDevGalleryViewController alloc] init];
				gallery.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:gallery animated:YES];
			}),
		]),

		TGSection(@"Build", nil, facts),

		TGSection(@"Capabilities", nil, @[
			TGOpenRow(@"Device Capabilities", nil, ^{
				TGDeviceViewController *device = [[TGDeviceViewController alloc] init];
				device.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:device animated:YES];
			}),
		]),

		// The calls the old tier list called "never" but a user account can
		// still send. Each screen names its request and shows Telegram's
		// answer; the ones that stay impossible are documented in
		// docs/status/bots-payments.md.
		TGSection(@"Tier 3 Audit", nil, @[
			TGOpenRow(@"Support", nil, ^{
				TGSupportInfoViewController *support =
						[[TGSupportInfoViewController alloc] init];
				support.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:support animated:YES];
			}),
			TGOpenRow(@"Telegram Ads", nil, ^{
				TGSponsoredMessagesViewController *ads =
						[[TGSponsoredMessagesViewController alloc] init];
				ads.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:ads animated:YES];
			}),
			TGOpenRow(@"TDLib Environment", nil, ^{
				TGDevEnvironmentViewController *environment =
						[[TGDevEnvironmentViewController alloc] init];
				environment.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:environment animated:YES];
			}),
			TGOpenRow(@"Bot Console", nil, ^{
				TGDevBotConsoleViewController *bots = [[TGDevBotConsoleViewController alloc] init];
				bots.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:bots animated:YES];
			}),
			TGOpenRow(@"TDLib Test Harness", nil, ^{
				TGDevTestHarnessViewController *harness =
						[[TGDevTestHarnessViewController alloc] init];
				harness.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:harness animated:YES];
			}),
			TGOpenRow(@"Affiliate Programs", nil, ^{
				TGAffiliateProgramsViewController *affiliate =
						[[TGAffiliateProgramsViewController alloc] init];
				affiliate.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:affiliate animated:YES];
			}),
			TGOpenRow(@"Premium, Stars and Gifts", nil, ^{
				TGStarsGiftsViewController *stars = [[TGStarsGiftsViewController alloc] init];
				stars.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:stars animated:YES];
			}),
		]),

		// The calls TDLib reserves for bot accounts. A user account still
		// sends them; the server's refusal is the honest answer, and the row
		// exists so the request and its result have a real surface.
		TGSection(@"Bot Tools", nil, @[
			TGTapRow(@"Prepared Keyboard Button", nil, ^{
				[TGAlertSheet showInput:@"Prepared Keyboard Button"
								message:@"Bot user id" placeholder:@"123"
									 text:nil action:@"Next" inView:weakSelf.view
							   onSubmit:^(NSString *bot){
					int64_t botId = bot.longLongValue;
					[TGAlertSheet showInput:@"Prepared Keyboard Button"
									message:@"Prepared button id"
								placeholder:@"prepared"
									 text:nil action:@"Show" inView:weakSelf.view
							   onSubmit:^(NSString *prepared){
						[[TGClient shared] preparedKeyboardButtonFromBot:botId
													   preparedButtonId:prepared
															completion:^(NSDictionary *button,
																		 NSString *error){
							if (!button){
								[TGAlertSheet showMessage:(error ?: @"An error occurred.")
													title:@"Prepared Keyboard Button"
												   inView:weakSelf.view];
								return;
							}
							NSString *body = [NSString stringWithFormat:
									@"Text: %@\nType: %@\nStyle: %@\nIcon: %@",
									button[@"text"] ?: @"",
									button[@"type"] ?: @"",
									button[@"style"] ?: @"",
									button[@"customEmojiId"] ?: @0];
							[TGAlertSheet showMessage:body
												title:@"Prepared Keyboard Button"
											   inView:weakSelf.view];
						}];
					}];
				}];
			}),
			TGTapRow(@"Save Prepared Keyboard Button", nil, ^{
				[TGAlertSheet showInput:@"Save Prepared Keyboard Button"
								message:@"User id the button is prepared for"
							placeholder:@"123"
									 text:nil action:@"Next" inView:weakSelf.view
							   onSubmit:^(NSString *user){
					int64_t userId = user.longLongValue;
					[TGAlertSheet showInput:@"Save Prepared Keyboard Button"
									message:@"Text"
								placeholder:@"Send me the file"
									 text:nil action:@"Save" inView:weakSelf.view
							   onSubmit:^(NSString *text){
						[[TGClient shared] savePreparedKeyboardButtonText:text
																  forUser:userId
															   completion:^(NSString *preparedId,
																			NSString *error){
							if (!preparedId.length){
								[TGAlertSheet showMessage:(error ?: @"An error occurred.")
													title:@"Save Prepared Keyboard Button"
												   inView:weakSelf.view];
								return;
							}
							[TGAlertSheet showChoices:@[@"Show"]
												title:@"Prepared Button Saved"
											  message:[NSString stringWithFormat:
													  @"Prepared id: %@", preparedId]
									   destructiveIndex:-1
											   inView:weakSelf.view
											 onChoice:^(NSInteger index){
								[[TGClient shared] preparedKeyboardButtonFromBot:userId
															   preparedButtonId:preparedId
																		completion:^(NSDictionary *button,
																					 NSString *fetchError){
									if (!button){
										[TGAlertSheet showMessage:(fetchError
												?: @"An error occurred.")
															title:@"Prepared Keyboard Button"
														   inView:weakSelf.view];
										return;
									}
									[TGAlertSheet showMessage:[NSString stringWithFormat:
											@"Text: %@\nType: %@",
											button[@"text"] ?: @"",
											button[@"type"] ?: @""]
														title:@"Prepared Keyboard Button"
													   inView:weakSelf.view];
								}];
							}];
						}];
					}];
				}];
			}),
			TGTapRow(@"Callback Query Message", nil, ^{
				[TGAlertSheet showInput:@"Callback Query Message"
								message:@"Chat id" placeholder:@"-100..."
									 text:nil action:@"Next" inView:weakSelf.view
							   onSubmit:^(NSString *chat){
					int64_t chatId = [chat longLongValue];
					[TGAlertSheet showInput:@"Callback Query Message"
									message:@"Message" placeholder:@"123"
										 text:nil action:@"Next" inView:weakSelf.view
								   onSubmit:^(NSString *message){
						int64_t messageId = [message longLongValue];
						[TGAlertSheet showInput:@"Callback Query Message"
										message:@"Callback query id"
									placeholder:@"0"
										 text:nil action:@"Show"
									   inView:weakSelf.view
								   onSubmit:^(NSString *query){
							[[TGClient shared] callbackQueryMessage:messageId
															 inChat:chatId
													callbackQueryId:[query longLongValue]
														 completion:^(NSDictionary *found){
								[TGAlertSheet showMessage:(found[@"text"] ?: @"An error occurred.")
													title:@"Callback Query Message"
												   inView:weakSelf.view];
							}];
						}];
					}];
				}];
			}),
			TGTapRow(@"Personal Chat History", nil, ^{
				[TGAlertSheet showInput:@"Personal Chat History"
								message:@"User id" placeholder:@"123"
									 text:nil action:@"Show" inView:weakSelf.view
							   onSubmit:^(NSString *user){
					[[TGClient shared] personalChatHistoryForUser:[user longLongValue]
														   limit:20
													  completion:^(NSArray *messages){
						NSMutableString *body = [NSMutableString string];
						for (NSDictionary *message in messages)
							[body appendFormat:@"%@\n",
									message[@"text"] ?: @"None"];
						if (!body.length)
							body = [@"An error occurred."
									mutableCopy];
						[TGAlertSheet showMessage:body
											title:@"Personal Chat History"
										   inView:weakSelf.view];
					}];
				}];
			}),
			TGTapRow(@"Set Reactions", nil, ^{
				[TGAlertSheet showInput:@"Set Reactions"
								message:@"Chat id" placeholder:@"-100..."
									 text:nil action:@"Next" inView:weakSelf.view
							   onSubmit:^(NSString *chat){
					int64_t chatId = [chat longLongValue];
					[TGAlertSheet showInput:@"Set Reactions"
									message:@"Message" placeholder:@"123"
										 text:nil action:@"Next" inView:weakSelf.view
								   onSubmit:^(NSString *message){
						int64_t messageId = [message longLongValue];
						[TGAlertSheet showInput:@"Set Reactions"
										message:@"Emoji"
									placeholder:@"👍"
										 text:nil action:@"Set"
									   inView:weakSelf.view
								   onSubmit:^(NSString *emoji){
							[[TGClient shared] setReactions:(emoji.length ? @[emoji] : @[])
												  onMessage:messageId
													 inChat:chatId
												 completion:^(BOOL ok){
								[TGAlertSheet showMessage:(ok ? @"Done"
															: @"An error occurred.")
													title:@"Set Reactions"
												   inView:weakSelf.view];
							}];
						}];
					}];
				}];
			}),
			TGTapRow(@"Send Text Draft", nil, ^{
				[TGAlertSheet showInput:@"Send Text Draft"
								message:@"Chat id" placeholder:@"-100..."
									 text:nil action:@"Next" inView:weakSelf.view
							   onSubmit:^(NSString *chat){
					int64_t chatId = [chat longLongValue];
					[TGAlertSheet showInput:@"Send Text Draft"
									message:@"Message" placeholder:@"Thinking..."
										 text:nil action:@"Send" inView:weakSelf.view
								   onSubmit:^(NSString *text){
						int64_t draftId = (int64_t)([[NSDate date]
								timeIntervalSince1970] * 1000);
						[[TGClient shared] sendTextDraft:text
												 toChat:chatId
												  topic:0
												draftId:draftId
												 canStop:YES
													keep:NO
											 completion:^(BOOL ok){
							NSString *body = ok
									? [NSString stringWithFormat:
											@"Draft sent. Its id is %lld.",
											(long long)draftId]
									: @"An error occurred.";
							[TGAlertSheet showMessage:body
												title:@"Send Text Draft"
											   inView:weakSelf.view];
						}];
					}];
				}];
			}),
			TGTapRow(@"Stop Text Draft", nil, ^{
				[TGAlertSheet showInput:@"Stop Text Draft"
								message:@"Chat id" placeholder:@"-100..."
									 text:nil action:@"Next" inView:weakSelf.view
							   onSubmit:^(NSString *chat){
					int64_t chatId = [chat longLongValue];
					[TGAlertSheet showInput:@"Stop Text Draft"
									message:@"Draft id" placeholder:@"0"
										 text:nil action:@"Stop" inView:weakSelf.view
								   onSubmit:^(NSString *draft){
						[[TGClient shared] stopTextDraft:[draft longLongValue]
												  inChat:chatId
												   topic:0
											  completion:^(BOOL ok){
							[TGAlertSheet showMessage:(ok ? @"Done"
														: @"An error occurred.")
												title:@"Stop Text Draft"
											   inView:weakSelf.view];
						}];
					}];
				}];
			}),
			TGTapRow(@"Prepared Inline Message", nil, ^{
				[TGAlertSheet showInput:@"Prepared Inline Message"
								message:@"Bot user id" placeholder:@"123"
									 text:nil action:@"Next" inView:weakSelf.view
							   onSubmit:^(NSString *bot){
					int64_t botId = [bot longLongValue];
					[TGAlertSheet showInput:@"Prepared Inline Message"
									message:@"Prepared message id"
								placeholder:@"prepared"
									 text:nil action:@"Show"
								   inView:weakSelf.view
							   onSubmit:^(NSString *prepared){
						[[TGClient shared] preparedInlineMessageFromBot:botId
													  preparedMessageId:prepared
														   completion:^(NSDictionary *found){
							NSString *body = found
									? [NSString stringWithFormat:@"Id: %@\nResult: %@",
											found[@"id"] ?: @"",
											found[@"result"] ?: @{}]
									: @"An error occurred.";
							[TGAlertSheet showMessage:body
												title:@"Prepared Inline Message"
											   inView:weakSelf.view];
						}];
					}];
				}];
			}),
			TGTapRow(@"Save Inline Message", nil, ^{
				[TGAlertSheet showInput:@"Save Inline Message"
								message:@"User id to prepare it for" placeholder:@"123"
									 text:nil action:@"Next" inView:weakSelf.view
							   onSubmit:^(NSString *user){
					int64_t userId = [user longLongValue];
					[TGAlertSheet showInput:@"Save Inline Message"
									message:@"Message"
								placeholder:@"Hello"
									 text:nil action:@"Save"
								   inView:weakSelf.view
							   onSubmit:^(NSString *text){
						[[TGClient shared] savePreparedInlineMessageForUser:userId
																	 text:text
																	title:text
															   completion:^(NSString *preparedId){
							[TGAlertSheet showMessage:(preparedId.length
									? [NSString stringWithFormat:@"Saved as %@", preparedId]
									: @"An error occurred.")
												title:@"Save Inline Message"
											   inView:weakSelf.view];
						}];
					}];
				}];
			}),
			TGTapRow(@"Edit Inline Message", nil, ^{
				[TGAlertSheet showInput:@"Edit Inline Message"
								message:@"Inline message id"
							placeholder:@"AAH..."
									 text:nil action:@"Next"
								   inView:weakSelf.view
							   onSubmit:^(NSString *inlineId){
					[TGAlertSheet showChoices:@[@"Text", @"Caption",
												@"Remove", @"Photo",
												@"Live Location"]
										title:@"Edit Inline Message"
							  destructiveIndex:-1
									   inView:weakSelf.view
									 onChoice:^(NSInteger index){
						if (index == 0){
							[TGAlertSheet showInput:@"Edit Inline Message"
											message:@"Text" placeholder:@"Hello"
												 text:nil action:@"Save"
											   inView:weakSelf.view
										   onSubmit:^(NSString *text){
								[[TGClient shared] editInlineMessageText:inlineId
																	text:text
															  completion:^(BOOL ok){
									[TGAlertSheet showMessage:(ok ? @"Done"
																: @"An error occurred.")
														title:@"Edit Inline Message"
													   inView:weakSelf.view];
								}];
							}];
						} else if (index == 1){
							[TGAlertSheet showInput:@"Edit Inline Message"
											message:@"Caption" placeholder:@"Caption"
												 text:nil action:@"Save"
											   inView:weakSelf.view
										   onSubmit:^(NSString *caption){
								[[TGClient shared] editInlineMessageCaption:inlineId
																   caption:caption
																completion:^(BOOL ok){
									[TGAlertSheet showMessage:(ok ? @"Done"
																: @"An error occurred.")
														title:@"Edit Inline Message"
													   inView:weakSelf.view];
								}];
							}];
						} else if (index == 2){
							[[TGClient shared] clearInlineMessageReplyMarkup:inlineId
																 completion:^(BOOL ok){
								[TGAlertSheet showMessage:(ok ? @"Done"
															: @"An error occurred.")
													title:@"Edit Inline Message"
												   inView:weakSelf.view];
							}];
						} else if (index == 3){
							[TGAlertSheet showInput:@"Edit Inline Message"
											message:@"Photo" placeholder:@"123"
												 text:nil action:@"Next"
											   inView:weakSelf.view
										   onSubmit:^(NSString *photo){
								int64_t photoId = [photo longLongValue];
								[TGAlertSheet showInput:@"Edit Inline Message"
												message:@"Caption" placeholder:@"Photo"
													 text:nil action:@"Save"
												   inView:weakSelf.view
											   onSubmit:^(NSString *caption){
									[[TGClient shared] editInlineMessagePhoto:inlineId
																	photoId:photoId
																	caption:caption
																 completion:^(BOOL ok){
										[TGAlertSheet showMessage:(ok ? @"Done"
																	: @"An error occurred.")
															title:@"Edit Inline Message"
														   inView:weakSelf.view];
									}];
								}];
							}];
						} else {
							[TGAlertSheet showInput:@"Edit Inline Message"
											message:@"Location" placeholder:@"0.0"
												 text:nil action:@"Next"
											   inView:weakSelf.view
										   onSubmit:^(NSString *lat){
								double latitude = [lat doubleValue];
								[TGAlertSheet showInput:@"Edit Inline Message"
												message:@"Location" placeholder:@"0.0"
													 text:nil action:@"Save"
												   inView:weakSelf.view
											   onSubmit:^(NSString *lon){
									[[TGClient shared] editInlineMessageLiveLocation:inlineId
																			latitude:latitude
																		   longitude:[lon doubleValue]
																		  completion:^(BOOL ok){
										[TGAlertSheet showMessage:(ok ? @"Done"
																	: @"An error occurred.")
															title:@"Edit Inline Message"
														   inView:weakSelf.view];
									}];
								}];
							}];
						}
					}];
				}];
			}),
		]),

		TGSection(@"Chat Resolvers", nil, @[
			TGTapRow(@"Open Basic Group by ID", nil, ^{
				[TGAlertSheet showInput:@"Basic Group ID" message:nil
							placeholder:@"Group" text:nil action:@"Read"
								 inView:weakSelf.view onSubmit:^(NSString *text){
					int64_t basicGroupId = text.longLongValue;
					// The record first, so the resolver shows what Telegram
					// holds for the id - name, members and status - not only
					// an attempt to open a chat from it.
					[[TGClient shared] basicGroupInfo:basicGroupId
							completion:^(NSDictionary *info){
						if (!info){
							[TGAlertSheet showMessage:@"An error occurred."
												title:@"Basic Group"
											   inView:weakSelf.view];
							return;
						}
						NSString *status = [info[@"status"] capitalizedString];
						NSString *upgraded = [info[@"upgradedTo"] longLongValue]
								? @"\nIt has been upgraded to a supergroup."
								: @"";
						NSString *message = [NSString stringWithFormat:
								@"%@\n%ld members · %@%@%@",
								info[@"title"],
								(long)[info[@"members"] integerValue],
								status,
								[info[@"active"] boolValue] ? @"" : @" · inactive",
								upgraded];
						[TGAlertSheet showChoices:@[@"Open Chat"]
											title:@"Basic Group"
										  message:message
								 destructiveIndex:-1
										   inView:weakSelf.view
										 onChoice:^(NSInteger index){
							[[TGClient shared] chatForBasicGroup:basicGroupId
													completion:^(int64_t chatId){
								[weakSelf openResolvedChat:chatId
													 title:info[@"title"]];
							}];
						}];
					}];
				}];
			}),
			TGTapRow(@"Open Supergroup by ID", nil, ^{
				[TGAlertSheet showInput:@"Supergroup" message:nil
							placeholder:nil text:nil action:@"Open"
								 inView:weakSelf.view onSubmit:^(NSString *text){
					[[TGClient shared] chatForSupergroup:text.longLongValue
											completion:^(int64_t chatId){
						[weakSelf openResolvedChat:chatId title:@"Supergroup"];
					}];
				}];
			}),
			TGTapRow(@"Open Secret Chat by ID", nil, ^{
				[TGAlertSheet showInput:@"Secret Chat" message:nil
							placeholder:nil text:nil action:@"Open"
								 inView:weakSelf.view onSubmit:^(NSString *text){
					[[TGClient shared] chatForSecretChat:(int32_t)text.intValue
											completion:^(int64_t chatId){
						[weakSelf openResolvedChat:chatId title:@"Secret Chat"];
					}];
				}];
			}),
		]),

		TGSection(@"Diagnostics", nil, @[
			TGTapRow(@"Send Custom Request", nil, ^{
				[TGAlertSheet showInput:@"Send Custom Request"
								message:@"TDLib method"
							placeholder:@"getOption"
								   text:nil action:@"Next" inView:weakSelf.view
							   onSubmit:^(NSString *method){
					[TGAlertSheet showInput:@"Send Custom Request"
									message:nil
								placeholder:@"{}"
									   text:@"{}" action:@"Send"
								   inView:weakSelf.view
								   onSubmit:^(NSString *parameters){
						[[TGClient shared] sendCustomRequestMethod:method
													   parameters:parameters
													   completion:^(NSString *result,
																	NSString *error){
							if (error){
								[TGAlertSheet showMessage:error
													title:@"Custom Request"
												   inView:weakSelf.view];
								return;
							}
							TGListViewController *viewer = [[TGListViewController alloc] init];
							viewer.listTitle = method;
							viewer.rows = TGCustomResultRows(result);
							viewer.listFooter = nil;
							viewer.offersCopy = YES;
							viewer.hidesBottomBarWhenPushed = YES;
							[weakSelf.navigationController pushViewController:viewer
																 animated:YES];
						}];
					}];
				}];
			}),
			TGTapRow(@"Encryption Key",
					[[TGClient shared] databaseEncryptionKeyIsKnown]
							? ([[TGClient shared] databaseEncryptionKeyIsSet]
								? @"Set" : @"None")
							: @"None",
					^{
				if (![[TGClient shared] databaseEncryptionKeyIsKnown]){
					[TGAlertSheet showMessage:@"An error occurred."
										title:@"Encryption Key"
									   inView:weakSelf.view];
					return;
				}
				[TGAlertSheet showConfirm:nil
									title:@"Encryption Key"
								   action:@"Continue"
							  destructive:YES
								   inView:weakSelf.view
								onConfirm:^{
					[TGAlertSheet showSecureInput:@"Encryption Key"
										  message:@"Encryption Key"
									  placeholder:nil
										   action:@"Set"
										   inView:weakSelf.view
									   onSubmit:^(NSString *key){
						NSData *bytes = [key dataUsingEncoding:NSUTF8StringEncoding];
						[[TGClient shared] setDatabaseEncryptionKey:bytes
								completion:^(BOOL ok, NSString *error){
							if (!ok){
								[TGAlertSheet showMessage:(error ?: @"An error occurred.")
													title:@"Encryption Key"
												   inView:weakSelf.view];
								return;
							}
							[TGAlertSheet showMessage:@"Done"
												title:@"Encryption Key"
											   inView:weakSelf.view];
							[weakSelf rebuild];
						}];
					}];
				}];
			}),
		]),

		TGSection(@"Logging", nil, @[
			TGTapRow(@"TDLib Log Verbosity: Errors", nil, ^{
				[[TGClient shared] send:@{@"@type" : @"setLogVerbosityLevel",
										  @"new_verbosity_level" : @(1)}];
				[weakSelf toast:@"Done"];
			}),
			TGTapRow(@"TDLib Log Verbosity: Verbose", nil, ^{
				[[TGClient shared] send:@{@"@type" : @"setLogVerbosityLevel",
										  @"new_verbosity_level" : @(5)}];
				[weakSelf toast:@"Done"];
			}),
		]),

		TGSection(@"Data and Storage", nil, @[
			TGTapRow(@"Clear Temporary Files", nil, ^{
				[weakSelf clearTemporaryFiles];
			}),
			TGOpenRow(@"Storage Usage", nil, ^{
				TGStorageViewController *storage = [[TGStorageViewController alloc] init];
				storage.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:storage animated:YES];
			}),
		]),

		TGSection(nil, nil, @[
			TGRedRow(@"Reset Local Preferences", ^{
				[TGAlertSheet showConfirm:nil
									title:@"Reset Local Preferences"
								   action:@"Reset"
							  destructive:YES
								   inView:weakSelf.view
								onConfirm:^{
					NSString *domain = [NSBundle mainBundle].bundleIdentifier;
					[NSUserDefaults.standardUserDefaults
							removePersistentDomainForName:domain];
					[NSUserDefaults.standardUserDefaults synchronize];
					[weakSelf repaint];
					[weakSelf toast:@"Done"];
				}];
			}),
		]),
	];
}

/// Provider lookups and order checks with nothing behind them to buy.
- (NSArray *)paymentDevSections {
	__weak typeof(self) weakSelf = self;
	return @[
		TGSection(@"Payment Method", nil, @[
			TGActionRow(@"Look Up", ^{ [weakSelf showBankCardLookup]; }),
		]),

		TGSection(@"Offer", nil, @[
			TGActionRow(@"Offer", ^{ [weakSelf addOfferFlow]; }),
		]),

		TGSection(@"Payment Info", nil, @[
			TGActionRow(@"Validate an Order", ^{ [weakSelf validateOrderFlow]; }),
		]),
	];
}
#endif

- (void)openResolvedChat:(int64_t)chatId title:(NSString *)title {
	if (!chatId){
		[TGAlertSheet showMessage:@"An error occurred."
							title:title inView:self.view];
		return;
	}
	TGChatViewController *chat = [[TGChatViewController alloc] init];
	chat.chatId = chatId;
	chat.chatTitle = title;
	chat.isGroup = YES;
	chat.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:chat animated:YES];
}

- (void)toast:(NSString *)text {
	[TGAlertSheet showMessage:text title:nil inView:self.view];
}


@end
