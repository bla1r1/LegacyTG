#import "TGSettingsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGUIFormat.h"
#import "TGDateFormat.h"
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
	NSString *text = result.length ? result : @"Empty";
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


/// Undenied? iOS 8+ answers with the settings the user granted, iOS 6/7 with
/// the enabled remote types. No permission at all is the warning state.
static BOOL TGNotificationsWarning(void) {
	UIApplication *app = [UIApplication sharedApplication];
	if ([app respondsToSelector:@selector(currentUserNotificationSettings)]){
		UIUserNotificationSettings *settings = [app currentUserNotificationSettings];
		UIUserNotificationType wanted = UIUserNotificationTypeAlert |
				UIUserNotificationTypeSound | UIUserNotificationTypeBadge;
		return (settings.types & wanted) == 0;
	}
	if ([app respondsToSelector:@selector(enabledRemoteNotificationTypes)]){
		UIRemoteNotificationType wanted = UIRemoteNotificationTypeAlert |
				UIRemoteNotificationTypeSound | UIRemoteNotificationTypeBadge;
		return ([app enabledRemoteNotificationTypes] & wanted) == 0;
	}
	return NO;
}


@implementation TGSettingsViewController (TGSettingsPagesCore)

#pragma mark - pages

- (NSArray *)buildSections {
	switch (self.page){
		case TGSettingsPageAppearance:    return [self appearanceSections];
		case TGSettingsPageData:          return [self dataSections];
		case TGSettingsPageNotifications: return [self notificationSections];
		case TGSettingsPageNotificationSounds: return [self soundSections];
		case TGSettingsPageActiveNotifications:
			return [self activeNotificationSections];
		case TGSettingsPagePrivacy:       return [self privacySections];
		case TGSettingsPagePasscode:      return [self passcodeSections];
		case TGSettingsPageLanguage:      return [self languageSections];
		case TGSettingsPageBlocked:       return [self blockedSections];
		case TGSettingsPagePowerSaving:   return [self powerSavingSections];
		case TGSettingsPageRecentCalls:   return [self recentCallSections];
		case TGSettingsPageFolders:       return [self folderSections];
		case TGSettingsPageProxy:         return [self proxySections];
		case TGSettingsPageDownloads:     return [self downloadSections];
		case TGSettingsPageAutosave:      return [self autosaveSections];
		case TGSettingsPageWallpaper:     return @[];   // the URL opens the gallery itself
		case TGSettingsPageChatThemes:    return [self chatThemesSections];
		case TGSettingsPageAutoNight:     return [self autoNightSections];
		case TGSettingsPagePaymentData:   return [self paymentSections];
#if TG_DEV
		case TGSettingsPageDebug:         return [self debugSections];
		case TGSettingsPageLanguageDev:   return [self languageDevSections];
		case TGSettingsPagePaymentDev:    return [self paymentDevSections];
#endif
		default:                          return [self rootSections];
	}
}

- (NSArray *)rootSections {
	__weak typeof(self) weakSelf = self;
	NSDictionary *me = [TGClient shared].me;

	// The values Telegram shows on the right of these rows. They stay nil
	// until the client answers, so a slow network leaves the row exactly as
	// it was instead of a dash that never fills in.
	NSString *username = [me[@"username"] length]
			? [NSString stringWithFormat:@"@%@", me[@"username"]] : nil;
	NSString *foldersDetail = nil;
	NSString *cacheDetail = nil;
	NSString *languageDetail = self.rootLanguageName.length
			? self.rootLanguageName : self.currentLanguage;
	NSString *proxyDetail = self.rootProxyDetail.length
			? self.rootProxyDetail : nil;

	NSMutableArray *sections = [NSMutableArray array];
	[sections addObject:TGSection(nil, nil, @[
		TGRow(TGKindProfile, @""),
	])];
	NSMutableArray *accountRows = [NSMutableArray array];
	// Logged out or still connecting there is no account to show or edit;
	// the one useful row is the way back in.
	if ([TGClient shared].authState != TGAuthStateReady){
		[accountRows addObject:TGIconRow(@"Log in to Telegram", @"privacy", TGIconTileAzure(), ^{
			[[AppDelegate sharedDelegate] showLoginUI];
		})];
		[sections addObject:TGSection(nil, nil, accountRows)];
	} else {
		// One row opens the account sheet, as before the parity pass: the
		// inline list of accounts read worse on the device.
		[accountRows addObject:TGIconRow(@"Switch Account", @"select", TGIconTileAzure(), ^{
			[weakSelf showAccountChoices];
		})];
		[accountRows addObject:TGIconOpenRow(@"My Profile", @"contacts", TGIconTileSky(), ^{
			[weakSelf openMyProfile];
		})];
		if (!username.length)
			[accountRows addObject:TGIconOpenRow(@"Set Username", @"contacts", TGIconTileAzure(), ^{
				[weakSelf openUsername];
			})];
		[accountRows addObject:TGIconOpenRow(TGLocalized(@"Emoji Status"), @"star", TGIconTileGold(), ^{
			TGEmojiStatusViewController *status =
					[[TGEmojiStatusViewController alloc] init];
			status.target = TGEmojiStatusTargetSelf;
			status.userId = [[TGClient shared].me[@"id"] longLongValue];
			status.subjectTitle = TGLocalized(@"Emoji Status");
			status.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:status animated:YES];
		})];
		[sections addObject:TGSection(nil, nil, accountRows)];
	}

	if (proxyDetail.length)
		[sections addObject:TGSection(nil, nil, @[
			TGIconTapOpenRow(TGLocalized(@"Proxy"), proxyDetail, @"data", TGIconTileGrey(), ^{
				[weakSelf openPage:TGSettingsPageProxy];
			}),
		])];

	[sections addObject:TGSection(nil, nil, @[
		TGIconOpenRow(TGLocalized(@"Saved Messages"), @"folder", TGIconTileSky(), ^{
			[weakSelf openSavedMessages];
		}),
		TGIconOpenRow(TGLocalized(@"Recent Calls"), @"call", TGIconTileGreen(), ^{
			[weakSelf openPage:TGSettingsPageRecentCalls];
		}),
		TGIconTapOpenRow(TGLocalized(@"Devices"),
				self.rootDeviceName.length
						? TGSettingsDevicesValue(self.rootSessionCount) : nil,
				@"devices", TGIconTileAmber(), ^{
			TGSessionsViewController *sessions = [[TGSessionsViewController alloc] init];
			sessions.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:sessions animated:YES];
		}),
		TGIconTapOpenRow(TGLocalized(@"Chat Folders"), foldersDetail, @"folder", TGIconTileCyan(), ^{
			[weakSelf openPage:TGSettingsPageFolders];
		}),
	])];
	[sections addObject:TGSection(nil, nil, @[
		({ NSMutableDictionary *row = [TGIconOpenRow(TGLocalized(@"Notifications and Sounds"), @"notifications", TGIconTileRed(), ^{
			[weakSelf openPage:TGSettingsPageNotifications];
		}) mutableCopy];
		   if (TGNotificationsWarning()) row[TGRowBadge] = @YES;
		   row; }),
		TGIconOpenRow(TGLocalized(@"Privacy and Security"), @"privacy", TGIconTileGrey(), ^{
			[weakSelf openPage:TGSettingsPagePrivacy];
		}),
		TGIconTapOpenRow(TGLocalized(@"Data and Storage"), cacheDetail, @"data", TGIconTileGreen(), ^{
			[weakSelf openPage:TGSettingsPageData];
		}),
		TGIconOpenRow(TGLocalized(@"Appearance"), @"chat", TGIconTileSky(), ^{
			[weakSelf openPage:TGSettingsPageAppearance];
		}),
		TGIconTapOpenRow(TGLocalized(@"Power Saving"),
				(![TGCapabilities animatedStickersWanted] ||
				 ![TGCapabilities wallpaperWanted] ||
				 ![TGCapabilities gifAutoplayWanted]) ? @"On" : @"Off",
				@"battery", TGIconTileAmber(), ^{
			[weakSelf openPage:TGSettingsPagePowerSaving];
		}),
		TGIconTapOpenRow(TGLocalized(@"Language"), languageDetail, @"language", TGIconTileViolet(), ^{
			[weakSelf openPage:TGSettingsPageLanguage];
		}),
	])];
	[sections addObject:TGSection(nil, nil, @[
		TGIconRow(TGLocalized(@"Telegram Premium"), @"star", TGIconTilePurple(), ^{
			[weakSelf showPremiumState];
		}),
		TGIconTapOpenRow(TGLocalized(@"Telegram Stars"), [NSString stringWithFormat:@"%lld",
				(long long)[TGClient shared].ownedStarCount], @"star", TGIconTileGold(), ^{
			TGStarsGiftsViewController *stars = [[TGStarsGiftsViewController alloc] init];
			stars.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:stars animated:YES];
		}),
		[weakSelf tier2BusinessRow],
	])];
	[sections addObject:TGSection(nil, nil, @[
		TGIconOpenRow(TGLocalized(@"Ask a Question"), @"chat", TGIconTileAmber(), ^{
			[weakSelf openSupport];
		}),
		TGIconRow(TGLocalized(@"Telegram FAQ"), @"faq", TGIconTileCyan(), ^{
			[weakSelf openFAQ];
		}),
		TGIconRow(TGLocalized(@"Telegram Features"), @"star", TGIconTileGold(), ^{
			[weakSelf openTelegramTips];
		}),
	])];
	[sections addObject:TGSection(nil, nil, @[
		TGIconTapOpenRow(TGLocalized(@"Device"), [TGDevice tierName], @"devices", TGIconTileSlate(), ^{
			TGDeviceViewController *device = [[TGDeviceViewController alloc] init];
			device.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:device animated:YES];
		}),
		TGRedRow(TGLocalized(@"Log out"), ^{
			[TGAlertSheet showConfirm:@"Are you sure you want to log out from this device?"
								title:@"Log out?"
							   action:TGLocalized(@"Log out")
						  destructive:YES
							   inView:weakSelf.view
							onConfirm:^{ [[TGClient shared] logOut]; }];
		}),
	])];
	return sections;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	self.languageSearchText = searchText;
	[self rebuild];
}

- (NSArray *)languageSections {
	__weak typeof(self) weakSelf = self;
	NSString *appLanguage = TGAppLanguage();
	NSString *query = [self.languageSearchText stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;
	NSMutableArray *rows = [NSMutableArray array];
	if (!query.length)
		[rows addObject:TGCheckRow(@"System", nil, TGAppLanguageIsSystem(), ^{
			TGSetAppLanguage(nil);
			TGSetTelegramLanguageLookup(nil);
			[[TGClient shared] loadAppLanguagePack:TGAppLanguage() completion:^(BOOL ok){
				[TGAlertSheet showMessage:@"Restart"
									title:@"Interface Language" inView:weakSelf.view];
			}];
		})];
	for (NSDictionary *language in self.languages){
		NSString *packId = language[@"id"];
		if (!packId.length)
			continue;
		NSString *name = language[@"name"];
		if (query.length &&
			[name.lowercaseString rangeOfString:query].location == NSNotFound &&
			[packId.lowercaseString rangeOfString:query].location == NSNotFound)
			continue;
		// Official shows the language's native name and a checkmark. The
		// pack id on the right read as "en" under "Русский".
		[rows addObject:TGCheckRow(name, nil,
				[packId isEqualToString:appLanguage], ^{
			TGSetAppLanguage(packId);
			TGSetTelegramLanguageLookup(nil);
			// One choice sets both the UI pack and TDLib's language, as the
			// official list does.
			[[TGClient shared] setLanguage:packId];
			weakSelf.currentLanguage = packId;
			[[TGClient shared] loadAppLanguagePack:packId completion:^(BOOL ok){
				[TGAlertSheet showMessage:@"Restart"
									title:@"Interface Language" inView:weakSelf.view];
			}];
			[weakSelf rebuild];
		})];
	}
	if (!rows.count && !query.length)
		for (NSUInteger i = 0; i < 8; i++)
			[rows addObject:TGRow(TGKindPlain, @"Loading...")];

	return @[TGSection(@"Interface Language", nil, rows)];
}

#if TG_DEV
/// Reading and writing packs string by string is a console, not a language picker.
- (NSArray *)languageDevSections {
	__weak typeof(self) weakSelf = self;
	NSString *code = self.countryCode ?: @"US";
	NSString *countryName = self.countryInfo[@"name"] ?: code;
	NSString *flag = self.countryFlag.length ? self.countryFlag
			: (self.countryInfo[@"flag"] ?: @"");
	NSString *countryDetail = flag.length
			? [NSString stringWithFormat:@"%@  %@", flag, countryName]
			: countryName;
	NSString *preferred = self.preferredCountryLanguage ?: @"Unknown";
	NSMutableDictionary *preferredRow =
			TGRow(TGKindPlain, @"Preferred Country Language");
	preferredRow[TGRowDetail] = preferred;
	NSArray *countryRows = @[
		TGTapRow(@"Country", countryDetail, ^{ [weakSelf askCountryCode]; }),
		preferredRow,
	];

	NSString *packName = self.languageInfo[@"name"] ?: self.currentLanguage ?: @"en";
	NSString *packDetail = self.languageInfo
			? [NSString stringWithFormat:@"%@ of %@ strings",
					self.languageInfo[@"translated"] ?: @(0),
					self.languageInfo[@"total"] ?: @(0)]
			: @"Read the current pack";
	NSString *stringsDetail = weakSelf.languagePackStrings
			? [NSString stringWithFormat:@"%lu strings read",
					(unsigned long)weakSelf.languagePackStrings.count]
			: @"Read the pack's strings back";
	NSArray *packRows = @[
		TGTapRow(@"Pack Info", packDetail, ^{ [weakSelf showLanguagePackInfo]; }),
		TGTapRow(@"Strings", stringsDetail, ^{
			[weakSelf showLanguagePackStrings];
		}),
		TGTapRow(@"Read a String", @"One key from the local database", ^{
			[weakSelf readLanguagePackString];
		}),
	];

	NSArray *editRows = @[
		TGTapRow(@"New Custom Pack", @"A local pack, id starts with X", ^{
			[weakSelf createCustomLanguagePack];
		}),
		TGTapRow(@"Edit Pack Name", packName, ^{ [weakSelf editLanguagePackName]; }),
		TGTapRow(@"Set a String", @"Add or change one key", ^{
			[weakSelf setLanguagePackString];
		}),
		TGTapRow(@"Delete a String", @"Fall back to the base pack", ^{
			[weakSelf deleteLanguagePackString];
		}),
		TGTapRow(@"Install Pack from Telegram", @"Add a server pack by id", ^{
			[weakSelf installServerLanguagePack];
		}),
		TGTapRow(@"Synchronize Pack", @"Fetch the latest strings", ^{
			[weakSelf synchronizeCurrentLanguagePack];
		}),
		TGRedRow(@"Delete Pack", ^{ [weakSelf deleteCurrentLanguagePack]; }),
	];

	return @[
		TGSection(@"Country",
			@"Telegram answers the country's name, flag and preferred language; "
			@"the code is the two-letter ISO one.", countryRows),
		TGSection(@"Current Pack",
			@"Pack info, the strings it carries and a read-back of one key.", packRows),
		TGSection(@"Custom Packs",
			@"A local pack starts with X and overrides the base one string at a "
			@"time. Install adds a pack Telegram already serves.", editRows),
	];
}

/// The country rows are read once per open; changing the code re-reads all
/// three answers rather than leaving a flag from the previous country.
- (void)askCountryCode {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Country Code"
					message:@"Two-letter ISO 3166-1 code, for example DE."
				placeholder:@"DE"
					   text:self.countryCode ?: @""
					 action:@"Read"
					 inView:self.view
				 onSubmit:^(NSString *text){
		NSString *code = text.uppercaseString;
		weakSelf.countryCode = code;
		[[TGClient shared] countryInfoForCode:code completion:^(NSDictionary *country){
			weakSelf.countryInfo = country;
			[weakSelf rebuild];
		}];
		[[TGClient shared] preferredCountryLanguageForCode:code
												completion:^(NSString *language){
			weakSelf.preferredCountryLanguage = language;
			[weakSelf rebuild];
		}];
		[[TGClient shared] countryFlagEmojiForCode:code completion:^(NSString *emoji){
			weakSelf.countryFlag = emoji;
			[weakSelf rebuild];
		}];
	}];
}

- (void)showLanguagePackInfo {
	NSString *packId = self.currentLanguage ?: @"en";
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] languagePackInfo:packId completion:^(NSDictionary *info){
		weakSelf.languageInfo = info;
		[weakSelf rebuild];
		if (!info){
			[TGAlertSheet showMessage:@"Telegram returned no record for this pack."
							   title:@"Language Pack"
							   inView:weakSelf.view];
			return;
		}
		NSMutableString *body = [NSMutableString string];
		NSString *displayName = info[@"nativeName"] ?: info[@"name"] ?: info[@"id"];
		[body appendFormat:@"%@ (%@)\n", displayName ?: @"Unknown", info[@"id"]];
		if ([info[@"name"] length] && ![info[@"name"] isEqualToString:info[@"nativeName"]])
			[body appendFormat:@"English name: %@\n", info[@"name"]];
		[body appendFormat:@"Base: %@\nStrings: %@ of %@ translated, %@ local\n",
				info[@"base"] ?: @"none", info[@"translated"] ?: @(0),
				info[@"total"] ?: @(0), info[@"local"] ?: @(0)];
		[body appendFormat:@"Official: %@ · Installed: %@ · RTL: %@",
				[info[@"official"] boolValue] ? @"yes" : @"no",
				[info[@"installed"] boolValue] ? @"yes" : @"no",
				[info[@"rtl"] boolValue] ? @"yes" : @"no"];
		[TGAlertSheet showMessage:body title:@"Language Pack" inView:weakSelf.view];
	}];
}

- (void)showLanguagePackStrings {
	NSString *packId = self.currentLanguage ?: @"en";
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] languagePackStrings:packId keys:@[] completion:^(NSArray *strings){
		if (!weakSelf)
			return;
		weakSelf.languagePackStrings = strings;
		[weakSelf rebuild];
		if (!strings.count){
			[TGAlertSheet showMessage:@"This pack has no strings on the device yet."
							   title:@"Strings"
							   inView:weakSelf.view];
			return;
		}
		NSMutableString *body = [NSMutableString string];
		NSUInteger shown = MIN(strings.count, (NSUInteger)20);
		for (NSUInteger i = 0; i < shown; i++){
			NSDictionary *string = strings[i];
			[body appendFormat:@"%@ = %@\n", string[@"key"], string[@"value"]];
		}
		if (strings.count > shown)
			[body appendFormat:@"…and %lu more.", (unsigned long)(strings.count - shown)];
		[TGAlertSheet showMessage:body
						   title:[NSString stringWithFormat:@"%@ Strings", packId]
						   inView:weakSelf.view];
	}];
}

- (void)readLanguagePackString {
	NSString *packId = self.currentLanguage ?: @"en";
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Read a String"
					message:@"The key as the pack stores it, for example Continue."
				placeholder:@"Continue"
					   text:@""
					 action:@"Read"
					 inView:self.view
				 onSubmit:^(NSString *key){
		[[TGClient shared] languagePackString:key pack:packId
								   completion:^(NSString *value, NSString *kind){
			if (!weakSelf)
				return;
			NSString *body = value == nil
					? @"That key is not in this pack."
					: [NSString stringWithFormat:@"%@ = %@ (%@)", key, value, kind ?: @"value"];
			[TGAlertSheet showMessage:body title:@"Language String" inView:weakSelf.view];
		}];
	}];
}

- (void)createCustomLanguagePack {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"New Custom Pack"
					message:@"An id for the local pack. X is added when missing."
				placeholder:@"Xmytest"
					   text:@"X"
					 action:@"Next"
					 inView:self.view
				 onSubmit:^(NSString *packId){
		[TGAlertSheet showInput:@"Pack Name"
						message:@"What the language list calls this pack."
					placeholder:@"My Test Pack"
						   text:@""
						 action:@"Create"
						 inView:weakSelf.view
					 onSubmit:^(NSString *name){
			[[TGClient shared] setCustomLanguagePack:packId name:name
										  nativeName:name strings:@[]
										  completion:^(BOOL ok){
				if (!weakSelf)
					return;
				if (ok){
					NSString *customId = [packId hasPrefix:@"X"] ? packId
							: [@"X" stringByAppendingString:packId];
					weakSelf.currentLanguage = customId;
					[[TGClient shared] setLanguage:customId];
					[[TGClient shared] languagePackInfo:customId
											completion:^(NSDictionary *info){
						weakSelf.languageInfo = info;
						[weakSelf rebuild];
					}];
				}
				[weakSelf toast:ok ? @"Custom pack created" : @"An error occurred."];
				[weakSelf refreshLanguagePage];
			}];
		}];
	}];
}

- (void)editLanguagePackName {
	NSString *packId = self.currentLanguage ?: @"en";
	__weak typeof(self) weakSelf = self;
	void (^ask)(NSDictionary *) = ^(NSDictionary *info){
		if (!weakSelf)
			return;
		if (!info){
			[TGAlertSheet showMessage:@"Read Pack Info first."
							   title:@"Edit Pack"
							   inView:weakSelf.view];
			return;
		}
		[TGAlertSheet showInput:@"Edit Pack Name"
						message:@"Only a custom local pack can be changed."
					placeholder:@"Name"
						   text:info[@"name"] ?: @""
						 action:@"Save"
						 inView:weakSelf.view
					 onSubmit:^(NSString *name){
			NSMutableDictionary *changed = [info mutableCopy];
			changed[@"name"] = name;
			changed[@"nativeName"] = name;
			[[TGClient shared] editCustomLanguagePackInfo:changed completion:^(BOOL ok){
				if (!weakSelf)
					return;
				[weakSelf toast:ok ? @"Pack renamed" : @"An error occurred."];
				[weakSelf refreshLanguagePage];
			}];
		}];
	};
	if (self.languageInfo)
		ask(self.languageInfo);
	else
		[[TGClient shared] languagePackInfo:packId completion:^(NSDictionary *info){
			ask(info);
		}];
}

- (void)setLanguagePackString {
	NSString *packId = self.currentLanguage ?: @"Xcustom";
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Set a String"
					message:@"The key to add or change in this local pack."
				placeholder:@"Continue"
					   text:@""
					 action:@"Next"
					 inView:self.view
				 onSubmit:^(NSString *key){
		[TGAlertSheet showInput:@"String Value"
						message:[NSString stringWithFormat:@"Value for %@.", key]
					placeholder:@"Continue"
						   text:@""
						 action:@"Save"
						 inView:weakSelf.view
					 onSubmit:^(NSString *value){
			[[TGClient shared] setCustomLanguagePackString:key value:value
													 pack:packId
											   completion:^(BOOL ok){
				if (!weakSelf)
					return;
				[weakSelf toast:ok ? @"String saved" : @"An error occurred."];
				[weakSelf refreshLanguagePage];
			}];
		}];
	}];
}

- (void)deleteLanguagePackString {
	NSString *packId = self.currentLanguage ?: @"Xcustom";
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Delete a String"
					message:@"The key falls back to the base pack."
				placeholder:@"Continue"
					   text:@""
					 action:@"Delete"
					 inView:self.view
				 onSubmit:^(NSString *key){
		[[TGClient shared] setCustomLanguagePackString:key value:nil
												 pack:packId
										   completion:^(BOOL ok){
			if (!weakSelf)
				return;
			[weakSelf toast:ok ? @"String deleted" : @"An error occurred."];
			[weakSelf refreshLanguagePage];
		}];
	}];
}

- (void)installServerLanguagePack {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Install Language Pack"
					message:@"The id Telegram serves, for example de."
				placeholder:@"de"
					   text:@""
					 action:@"Install"
					 inView:self.view
				 onSubmit:^(NSString *packId){
		[[TGClient shared] addCustomServerLanguagePack:packId completion:^(BOOL ok){
			if (!weakSelf)
				return;
			[weakSelf toast:ok ? @"Pack installed" : @"An error occurred."];
			[weakSelf refreshLanguagePage];
		}];
	}];
}

- (void)synchronizeCurrentLanguagePack {
	NSString *packId = self.currentLanguage ?: @"en";
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] synchronizeLanguagePack:packId completion:^(BOOL ok){
		if (!weakSelf)
			return;
		[weakSelf toast:ok ? @"Strings synchronized" : @"An error occurred."];
		[weakSelf refreshLanguagePage];
	}];
}

- (void)deleteCurrentLanguagePack {
	NSString *packId = self.currentLanguage ?: @"en";
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:[NSString stringWithFormat:@"%@ is removed from this device. The pack Telegram serves is untouched.", packId]
						title:@"Delete Pack"
					   action:@"Delete"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGClient shared] deleteLanguagePack:packId completion:^(BOOL ok){
			if (!weakSelf)
				return;
			[weakSelf toast:ok ? @"Pack deleted" : @"An error occurred."];
			weakSelf.languageInfo = nil;
			[weakSelf refreshLanguagePage];
		}];
	}];
}

#endif

- (void)refreshLanguagePage {
	[self rebuild];
	[self loadForPage];
}

static NSString *TGCallRecordWhen(NSNumber *stamp) {
	NSTimeInterval seconds = stamp.doubleValue;
	if (seconds <= 0)
		return @"unknown time";
	static NSDateFormatter *formatter = nil;
	if (!formatter){
		formatter = [[NSDateFormatter alloc] init];
		formatter.dateStyle = NSDateFormatterMediumStyle;
		formatter.timeStyle = NSDateFormatterShortStyle;
	}
	return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:seconds]];
}

/// The record this client writes for sendCallLog. TDLib's own log is not a
/// file this app can read - setLogStream is a stream the client would have to
/// own - so the log it sends is the call's facts and the device it ran on.
static NSString *TGCallLogText(NSDictionary *call) {
	NSDictionary *info = [NSBundle mainBundle].infoDictionary;
	return [NSString stringWithFormat:
			@"LegacyTG call log\n"
			@"Client: LegacyTG %@ (%@)\n"
			@"System: iOS %@\n"
			@"Device: %@\n"
			@"Call: %@\n"
			@"Direction: %@\n"
			@"Time: %@\n"
			@"Duration: %ld s\n"
			@"Missed: %@\n"
			@"Chat: %lld\n"
			@"Message: %lld\n",
			info[@"CFBundleShortVersionString"] ?: @"?",
			info[@"CFBundleVersion"] ?: @"?",
			[UIDevice currentDevice].systemVersion ?: @"?",
			[TGDevice modelName] ?: @"?",
			call[@"name"] ?: @"?",
			[call[@"outgoing"] boolValue] ? @"outgoing" : @"incoming",
			TGCallRecordWhen(call[@"date"]),
			(long)[call[@"duration"] integerValue],
			[call[@"missed"] boolValue] ? @"yes" : @"no",
			(long long)[call[@"chatId"] longLongValue],
			(long long)[call[@"messageId"] longLongValue]];
}

/// The debug record: the same facts as JSON, because that is what TDLib
/// forwards and what Telegram's call team reads.
static NSString *TGCallDebugText(NSDictionary *call) {
	NSDictionary *record = @{
		@"client"    : @"LegacyTG",
		@"system"    : [NSString stringWithFormat:@"iOS %@",
						[UIDevice currentDevice].systemVersion ?: @"?"],
		@"device"    : [TGDevice modelName] ?: @"?",
		@"peer"      : call[@"name"] ?: @"?",
		@"outgoing"  : [call[@"outgoing"] boolValue] ? @"yes" : @"no",
		@"missed"    : [call[@"missed"] boolValue] ? @"yes" : @"no",
		@"date"      : call[@"date"] ?: @0,
		@"duration"  : call[@"duration"] ?: @0,
		@"chat_id"   : call[@"chatId"] ?: @0,
		@"message_id": call[@"messageId"] ?: @0,
	};
	NSData *json = [NSJSONSerialization dataWithJSONObject:record options:0 error:NULL];
	if (!json)
		return nil;
	return [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
}

/// Telegram changed a pack. The page re-reads its record so the translated
/// count moves, and a string list it had already read is read again: the
/// update carries only what changed, not a complete pack to draw.
- (void)languagePackStringsChanged:(NSString *)packId {
	if (self.page != TGSettingsPageLanguage)
		return;
	if (!packId.length || ![packId isEqualToString:self.currentLanguage ?: @""])
		return;
	[self loadForPage];
	if (!self.languagePackStrings.count)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] languagePackStrings:packId keys:@[]
								completion:^(NSArray *strings){
		weakSelf.languagePackStrings = strings;
		[weakSelf rebuild];
	}];
}

- (NSArray *)recentCallSections {
	__weak typeof(self) weakSelf = self;
	// The bar's filter belongs to this page, and its English-only titles were
	// what overflowed once the pack supplied "Пропущ.". Size each segment to
	// its own title instead of splitting the bar in two.
	UISegmentedControl *filter =
			(UISegmentedControl *)self.navigationItem.titleView;
	if ([filter isKindOfClass:UISegmentedControl.class] &&
		filter.numberOfSegments == 2){
		NSString *all = TGLocalized(@"All");
		NSString *missed = TGLocalized(@"Missed");
		UIFont *font = TGFontCaption();
		[filter setTitle:all forSegmentAtIndex:0];
		[filter setTitle:missed forSegmentAtIndex:1];
		[filter setTitleTextAttributes:@{NSFontAttributeName : font}
							  forState:UIControlStateNormal];
		// The pack's "Пропущ." is nine characters; the control's equal split
		// cut it. Each segment gets its own measured width and the same
		// narrowed padding, so the whole word is on screen.
		filter.apportionsSegmentWidthsByContent = NO;
		[filter setWidth:TGSettingsSegmentWidth(all, font, TGMetricPadSmall)
		 forSegmentAtIndex:0];
		[filter setWidth:TGSettingsSegmentWidth(missed, font, TGMetricPadSmall)
		 forSegmentAtIndex:1];
		[filter sizeToFit];
	}

	NSArray *displayCalls = self.calls;
	if (self.recentCallsFilter == 1) {
		NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *c, NSDictionary *bindings) {
			return [c[@"missed"] boolValue];
		}];
		displayCalls = [self.calls filteredArrayUsingPredicate:pred];
	}

	// Telegram's switch for its fourth tab sits with the list it shows, so
	// the tab can be turned off from inside it.
	NSDictionary *tabSection = TGSection(nil, nil, @[
			TGSwitchRow(@"Show Calls Tab", [RootViewController showsCallsTab], ^(BOOL on){
				[RootViewController setShowsCallsTab:on];
			})]);

	if (!displayCalls.count)
		return @[tabSection, TGSection(nil, nil, @[TGRow(TGKindPlain, self.recentCallsFilter == 1 ? @"You have no missed calls" : @"Empty")])];

	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *call in displayCalls){
		BOOL missed = [call[@"missed"] boolValue];
		BOOL outgoing = [call[@"outgoing"] boolValue];
		NSInteger duration = [call[@"duration"] integerValue];
		// Pack words and the chat list's date shapes (time today, weekday
		// this week, date beyond), not English and the locale's 06/11/26.
		NSString *typeLabel = TGLocalized(missed ? @"Missed Call"
				: (outgoing ? @"Outgoing Call" : @"Incoming Call"));
		char buf[TGDateFormatBufferSize];
		size_t len = TGChatDateFormat((time_t)[call[@"date"] doubleValue],
				(time_t)[[NSDate date] timeIntervalSince1970], buf, sizeof(buf));
		NSString *when = len ? TGLocalized([[NSString alloc] initWithBytes:buf
				length:len encoding:NSASCIIStringEncoding]) : @"";
		NSString *detail = (!missed && duration > 0)
				? [NSString stringWithFormat:@"%@, %@ (%@)", typeLabel, when,
						TGUIFormatCallDuration(duration)]
				: [NSString stringWithFormat:@"%@, %@", typeLabel, when];
		NSString *key = [NSString stringWithFormat:@"%lld:%lld",
				(long long)[call[@"chatId"] longLongValue],
				(long long)[call[@"messageId"] longLongValue]];
		NSArray *already = weakSelf.callDiagnostics[key];
		if (already.count){
			NSMutableArray *done = [NSMutableArray array];
			if ([already containsObject:@"log"])
				[done addObject:@"log sent"];
			if ([already containsObject:@"debug"])
				[done addObject:@"debug sent"];
			if (done.count)
				detail = [NSString stringWithFormat:@"%@ · %@", detail,
						[done componentsJoinedByString:@", "]];
		}

		NSMutableDictionary *row = [TGSubtitleOpenRow(call[@"name"], detail, ^{
			int64_t userId = [call[@"userId"] longLongValue];
			if (userId) {
				[TGCallViewController presentForUserId:userId name:call[@"name"] outgoing:YES];
			}
		}) mutableCopy];
		if (missed)
			row[TGRowKind] = TGKindDestructive;
		[rows addObject:row];
	}
	return @[tabSection, TGSection(nil, nil, rows)];
}

#if TG_DEV
/// A finished call leaves a message, and that message is an InputCall. The
/// action sheet offers the two diagnostics TDLib accepts for one, and shows
/// Telegram's own sentence when it refuses - a user account usually is.
- (void)runRecentCallActionFor:(NSDictionary *)call {
	NSString *name = call[@"name"] ?: @"Call";
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Send Call Log", @"Send Debug Information"]
						title:name
					  message:[NSString stringWithFormat:@"%@ · %@",
							  [call[@"missed"] boolValue] ? @"Missed" : ([call[@"outgoing"] boolValue] ? @"Outgoing" : @"Incoming"),
							  TGCallRecordWhen(call[@"date"])]
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		int64_t chatId = [call[@"chatId"] longLongValue];
		int64_t messageId = [call[@"messageId"] longLongValue];
		if (!chatId || !messageId){
			[TGAlertSheet showMessage:@"This call record has no message to report."
								title:name inView:weakSelf.view];
			return;
		}
		if (index == 0){
			NSString *log = TGCallLogText(call);
			[[TGClient shared] sendCallLog:log forMessage:messageId inChat:chatId
								completion:^(BOOL ok, NSString *error){
				if (ok)
					[weakSelf noteCallDiagnostic:@"log" forCall:call];
				[TGAlertSheet showMessage:(ok ? @"Telegram accepted the call log."
						: (error ?: @"An error occurred."))
									title:@"Send Call Log" inView:weakSelf.view];
			}];
			return;
		}
		NSString *debug = TGCallDebugText(call);
		if (!debug.length){
			[TGAlertSheet showMessage:@"The debug record could not be encoded."
								title:name inView:weakSelf.view];
			return;
		}
		[[TGClient shared] sendCallDebugInformation:debug
										forMessage:messageId
											inChat:chatId
										completion:^(BOOL ok, NSString *error){
			if (ok)
				[weakSelf noteCallDiagnostic:@"debug" forCall:call];
			[TGAlertSheet showMessage:(ok ? @"Telegram accepted the debug information."
					: (error ?: @"An error occurred."))
								title:@"Send Debug Information" inView:weakSelf.view];
		}];
	}];
}
#endif


@end
