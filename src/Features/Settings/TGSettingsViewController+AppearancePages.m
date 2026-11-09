//
// TGSettingsViewController+AppearancePages.m
// Settings pages for theme styling, chat appearance, and skeuomorphic wallpapers.
//
#import "TGSettingsViewControllerInternal.h"
#import "TGAlertSheet.h"
#import "TGBackgroundsViewController.h"
#import "TGBackgroundEditorViewController.h"
#import "TGProfileAppearanceViewController.h"
#import "TGStickerPacksViewController.h"
#import "TGChatThemeStore.h"
#import "TGStyle.h"

static NSString *TGDefaultBackgroundDetail(NSDictionary *state) {
	if (![state isKindOfClass:NSDictionary.class])
		return @"Chat Wallpaper";
	NSDictionary *background = state[@"background"];
	NSString *name = [background isKindOfClass:NSDictionary.class]
			? background[@"name"] : nil;
	if ([name isKindOfClass:NSString.class] && name.length)
		return name;
	return @"Chat Wallpaper";
}

@implementation TGSettingsViewController (AppearancePages)

- (NSArray *)appearanceSections {
	__weak typeof(self) weakSelf = self;
	TGTheme *theme = [TGTheme shared];

	// ThemeSettingsController's order: preview, carousel, Chat Themes, Chat
	// Wallpaper, Your Color. The cards are baked once per theme and state.
	// Appearance's carousel is the server's emoji themes, as official draws
	// it; the base themes are chosen on the Chat Themes page under the preview.
	NSMutableDictionary *cards = TGThemeCardsRow(
			TGSettingsThemesWithClassic([[TGChatThemeStore shared] themes]),
			[theme currentThemeId], NO, ^(NSString *themeId){
		if (![[TGTheme shared] selectThemeId:themeId])
			[TGAlertSheet showMessage:@"Invalid theme file"
								title:@"Themes" inView:weakSelf.view];
		[weakSelf repaint];
	});

	NSArray *colourRows = @[
		TGChatPreviewRow(),
		cards,
		TGOpenRow(@"Chat Themes", nil, ^{
			[weakSelf openPage:TGSettingsPageChatThemes];
		}),
		TGOpenRow(@"Chat Wallpaper", nil, ^{
			TGBackgroundsViewController *backgrounds =
					[[TGBackgroundsViewController alloc] init];
			backgrounds.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:backgrounds animated:YES];
		}),
		TGOpenRow(@"Your Color", nil, ^{
			TGProfileAppearanceViewController *colours =
					[[TGProfileAppearanceViewController alloc] init];
			colours.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:colours animated:YES];
		}),
	];

	// Night Mode and Auto-Night sit together, then the message settings. The
	// "Animations" row opens the existing Power Saving switches: it is the
	// official entry point, so it is not a row without a setting behind it.
	NSMutableArray *messageRows = [NSMutableArray array];
	[messageRows addObject:TGSwitchRow(@"Night Mode", [theme isNightModeEnabled],
			^(BOOL on){
		[[TGTheme shared] setNightModeEnabled:on];
		[weakSelf repaint];
	})];
	[messageRows addObject:TGOpenRow(@"Auto-Night Theme",
			TGSettingsAutoNightModeLabel(NSUserDefaults.standardUserDefaults),
			^{ [weakSelf openPage:TGSettingsPageAutoNight]; })];
	// No icon: official Appearance draws none in this section, and one tile
	// among plain rows pushed its title out of the column.
	[messageRows addObject:TGOpenRow(@"Text Size",
			[NSString stringWithFormat:@"%.0fpt", theme.messageFontSize],
			^{ [weakSelf chooseTextSize]; })];
	[messageRows addObject:TGOpenRow(@"Animations", nil, ^{
		[weakSelf openPage:TGSettingsPagePowerSaving];
	})];
	[messageRows addObject:TGIconTapOpenRow(@"Stickers and Emoji", nil, @"star",
			TGIconTileViolet(), ^{
		TGStickerPacksViewController *packs =
				[[TGStickerPacksViewController alloc] init];
		packs.hidesBottomBarWhenPushed = YES;
		[weakSelf.navigationController pushViewController:packs animated:YES];
	})];

	NSString *colourHeader = [theme isNightModeEnabled]
			? @"COLOR THEME — AUTO-NIGHT MODE" : @"COLOR THEME";
	return @[
		TGSection(colourHeader, nil, colourRows),
		TGSection(nil, nil, messageRows),
	];
}

- (NSArray *)chatThemesSections {
	__weak typeof(self) weakSelf = self;
	NSString *currentThemeId = [[TGTheme shared] currentThemeId];
	void (^select)(NSString *) = [^(NSString *themeId){
		if (![[TGTheme shared] selectThemeId:themeId])
			[TGAlertSheet showMessage:@"Invalid theme file"
								title:@"Themes" inView:weakSelf.view];
		[weakSelf repaint];
	} copy];

	NSArray *model = TGSettingsChatThemesModel(
			TGSettingsThemesWithClassic([[TGChatThemeStore shared] themes]),
			[TGTheme availableThemes], currentThemeId);
	NSDictionary *emojiSection = model[0];
	NSDictionary *customSection = model[1];

	NSMutableDictionary *grid = TGThemeGridRow(emojiSection[@"themes"],
			currentThemeId, select);
	NSMutableDictionary *baseThemes = TGThemeCardsRow(customSection[@"themes"],
			currentThemeId, YES, select);

	// ThemeSettingsController order: the emoji grid first, then the preview,
	// with the base themes and their names under it. Accent circles and the
	// Edit/Create rows are not shown because this client has no accent editor
	// or theme editor to put behind them.
	return @[
		TGSection(emojiSection[@"header"], nil, @[grid]),
		TGSection(customSection[@"header"], nil, @[
			TGChatPreviewRow(),
			baseThemes,
		]),
	];
}

- (NSArray *)autoNightSections {
	__weak typeof(self) weakSelf = self;
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	NSInteger mode = TGSettingsAutoNightMode(defaults);
	NSInteger from = TGSettingsAutoNightMinute(defaults,
			TGSettingsAutoNightFromKey, TGSettingsAutoNightDefaultFrom);
	NSInteger to = TGSettingsAutoNightMinute(defaults,
			TGSettingsAutoNightToKey, TGSettingsAutoNightDefaultTo);

	NSArray *modeRows = @[
		TGCheckRow(@"Disabled", nil, mode != TGSettingsAutoNightModeScheduled, ^{
			TGSettingsSetAutoNightMode(NSUserDefaults.standardUserDefaults,
					TGSettingsAutoNightModeDisabled);
			[[TGTheme shared] refreshAutoNightMode];
			[weakSelf rebuild];
		}),
		TGCheckRow(@"Scheduled", nil, mode == TGSettingsAutoNightModeScheduled, ^{
			TGSettingsSetAutoNightMode(NSUserDefaults.standardUserDefaults,
					TGSettingsAutoNightModeScheduled);
			[[TGTheme shared] refreshAutoNightMode];
			[weakSelf rebuild];
		}),
	];

	NSMutableArray *sections = [NSMutableArray array];
	[sections addObject:TGSection(nil, nil, modeRows)];
	if (mode == TGSettingsAutoNightModeScheduled){
		[sections addObject:TGSection(nil, nil, @[
			TGTapRow(@"From", TGSettingsAutoNightTimeText(from), ^{
				[weakSelf chooseAutoNightTimeFrom:YES];
			}),
			TGTapRow(@"To", TGSettingsAutoNightTimeText(to), ^{
				[weakSelf chooseAutoNightTimeFrom:NO];
			}),
		])];
	}
	return sections;
}

- (void)chooseAutoNightTimeFrom:(BOOL)from {
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	NSInteger minute = TGSettingsAutoNightMinute(defaults,
			from ? TGSettingsAutoNightFromKey : TGSettingsAutoNightToKey,
			from ? TGSettingsAutoNightDefaultFrom : TGSettingsAutoNightDefaultTo);
	UIDatePicker *picker = [[UIDatePicker alloc] init];
	picker.datePickerMode = UIDatePickerModeTime;
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *parts = [calendar components:(NSYearCalendarUnit |
			NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:[NSDate date]];
	parts.hour = minute / 60;
	parts.minute = minute % 60;
	parts.second = 0;
	NSDate *date = [calendar dateFromComponents:parts];
	picker.date = date ?: [NSDate date];

	UIViewController *page = [[UIViewController alloc] init];
	page.title = from ? TGLocalized(@"From") : TGLocalized(@"To");
	page.view.backgroundColor = [[TGTheme shared] groupedBackgroundColour];
	CGFloat width = self.view.bounds.size.width;
	picker.frame = CGRectMake(0, TGMetricPadLarge, width, TGMetricPickerHeight);
	[page.view addSubview:picker];
	page.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:TGLocalized(@"Done")
					style:UIBarButtonItemStyleDone
				   target:self action:@selector(saveAutoNightTime)];
	self.autoNightPicker = picker;
	self.autoNightPickingFrom = from;
	page.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:page animated:YES];
}

- (void)saveAutoNightTime {
	NSDate *date = self.autoNightPicker.date ?: [NSDate date];
	NSInteger minute = TGSettingsMinuteOfDay(date);
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	[defaults setInteger:minute forKey:(self.autoNightPickingFrom
			? TGSettingsAutoNightFromKey : TGSettingsAutoNightToKey)];
	[defaults synchronize];
	[[TGTheme shared] refreshAutoNightMode];
	self.autoNightPicker = nil;
	[self.navigationController popViewControllerAnimated:YES];
	[self rebuild];
}

/// The default background is one record, so the sheet can name its id, which
/// side of the theme it belongs to, and its type. A background not received
/// yet says so rather than drawing a made-up one.
- (void)showDefaultBackground {
	NSDictionary *state = [TGClient shared].defaultBackground;
	if (![state isKindOfClass:NSDictionary.class]){
		[TGAlertSheet showMessage:@"Empty"
							title:@"Chat Wallpaper" inView:self.view];
		return;
	}
	[TGAlertSheet showMessage:TGDefaultBackgroundDetail(state)
						title:@"Chat Wallpaper" inView:self.view];
}

@end
