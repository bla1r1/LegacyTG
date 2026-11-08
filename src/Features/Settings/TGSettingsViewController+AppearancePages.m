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

	NSString *current = [theme currentThemeId];
	NSMutableArray *themes = [NSMutableArray array];
	for (NSDictionary *entry in [TGTheme availableThemes]){
		NSString *themeId = entry[@"id"];
		BOOL fromFile = entry[@"path"] != nil;
		[themes addObject:TGCheckRow(entry[@"name"],
				fromFile ? [(NSString *)entry[@"path"] pathExtension] : nil,
				[current isEqualToString:themeId], ^{
			if (![[TGTheme shared] selectThemeId:themeId]){
				[TGAlertSheet showMessage:@"Invalid theme file"
									title:@"Themes" inView:weakSelf.view];
			}
			[weakSelf repaint];
		})];
	}

	NSMutableArray *colourRows = [NSMutableArray array];
	[colourRows addObject:TGRow(TGKindPreview, @"")];
	[colourRows addObjectsFromArray:themes];
	[colourRows addObject:TGTapRow(@"Chat Themes",
			[TGClient shared].emojiChatThemes.count
					? [NSString stringWithFormat:@"%lu",
							(unsigned long)[TGClient shared].emojiChatThemes.count]
					: @"None",
			^{ [weakSelf showEmojiChatThemes]; })];
	[colourRows addObject:TGIconTapOpenRow(@"Chat Wallpaper",
			[theme wallpaperTitleForType:theme.wallpaperType],
			@"data", TGIconTileGreen(), ^{
		TGBackgroundsViewController *backgrounds =
				[[TGBackgroundsViewController alloc] init];
		backgrounds.hidesBottomBarWhenPushed = YES;
		[weakSelf.navigationController pushViewController:backgrounds animated:YES];
	})];
	[colourRows addObject:TGIconTapOpenRow(@"Your Color", @"Name and Profile Colors",
			@"star", TGIconTilePurple(), ^{
		TGProfileAppearanceViewController *colours =
				[[TGProfileAppearanceViewController alloc] init];
		colours.hidesBottomBarWhenPushed = YES;
		[weakSelf.navigationController pushViewController:colours animated:YES];
	})];

	return @[
		TGSection(@"COLOR THEME", nil, colourRows),

		TGSection(nil, nil, @[
			TGIconTapRow(@"Text Size",
					[NSString stringWithFormat:@"%.0fpt", theme.messageFontSize],
					@"chat", TGIconTileSky(),
					^{ [weakSelf chooseTextSize]; }),
			TGIconTapOpenRow(@"Power Saving", nil, @"battery", TGIconTileAmber(), ^{
				[weakSelf openPage:TGSettingsPagePowerSaving];
			}),
			TGIconTapOpenRow(@"Stickers and Emoji", nil, @"star", TGIconTileViolet(), ^{
				TGStickerPacksViewController *packs =
						[[TGStickerPacksViewController alloc] init];
				packs.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:packs animated:YES];
			}),
		]),
	];
}

- (NSArray *)wallpaperSections {
	__weak typeof(self) weakSelf = self;
	TGTheme *theme = [TGTheme shared];
	TGWallpaperType current = [theme wallpaperType];

	id (^textureRow)(NSString *, TGWallpaperType) = ^id(NSString *title, TGWallpaperType type) {
		BOOL checked = (current == type);
		return TGCheckRow(title, nil, checked, ^{
			[[TGTheme shared] setWallpaperType:type];
			[weakSelf rebuild];
		});
	};

	NSArray *textures = @[
		textureRow(@"Paper Grain", TGWallpaperTypePaperGrain),
		textureRow(@"Pinstripes", TGWallpaperTypePinstripes),
		textureRow(@"Classic Linen", TGWallpaperTypeLinen),
		textureRow(@"Parchment", TGWallpaperTypeParchment),
		textureRow(@"Game Center Felt", TGWallpaperTypeFelt),
	];

	NSMutableArray *customRows = [NSMutableArray array];
	[customRows addObject:TGOpenRow(@"Set a Color", @"Colors & Gradients", ^{
		TGBackgroundEditorViewController *editor = [[TGBackgroundEditorViewController alloc] init];
		editor.hidesBottomBarWhenPushed = YES;
		[weakSelf.navigationController pushViewController:editor animated:YES];
	})];
	[customRows addObject:TGOpenRow(@"Choose Wallpaper from Photos", (current == TGWallpaperTypeCustom ? @"Active" : nil), ^{
		[weakSelf presentWallpaperPicker];
	})];
	if (current != TGWallpaperTypeNone) {
		[customRows addObject:TGActionRow(@"Remove Wallpaper", ^{
			[[TGTheme shared] setWallpaperType:TGWallpaperTypeNone];
			[weakSelf rebuild];
		})];
	}

	return @[
		TGSection(nil, nil, @[TGRow(TGKindPreview, @"")]),
		TGSection(@"Wallpaper", nil, textures),
		TGSection(@"Background", nil, customRows)
	];
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

/// Each emoji chat theme carries a light and a dark settings record. The list
/// is the names the server sent; the sheet behind one shows the accent and
/// background it would apply, without pretending this client can select it.
- (void)showEmojiChatThemes {
	NSArray *themes = [TGClient shared].emojiChatThemes;
	if (!themes.count){
		[TGAlertSheet showMessage:@"Empty"
							title:@"Chat Themes" inView:self.view];
		return;
	}
	NSMutableArray *titles = [NSMutableArray array];
	for (NSDictionary *theme in themes){
		NSString *name = [theme isKindOfClass:NSDictionary.class] ? theme[@"name"] : nil;
		[titles addObject:([name isKindOfClass:NSString.class] && name.length)
				? name : @"—"];
	}
	[TGAlertSheet showChoices:titles
						title:@"Chat Themes"
					  message:nil
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		if (index < 0 || (NSUInteger)index >= themes.count)
			return;
		id chosen = themes[(NSUInteger)index];
		if (![chosen isKindOfClass:NSDictionary.class])
			return;
		[TGAlertSheet showMessage:nil
							title:titles[(NSUInteger)index]
						   inView:self.view];
	}];
}

@end
