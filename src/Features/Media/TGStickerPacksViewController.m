//
// TGStickerPacksViewController.m - see the header.
//
#import "TGMessageLayout.h"
#import "TGLocalization.h"
#import "TGStickerPacksViewController.h"
#import "TGAlertSheet.h"
#import "TGStickerStore.h"
#import "TGStickerEditorViewController.h"
#import "TGStickerGalleryViewController.h"
#import "TGStyle.h"
#import "TGTheme.h"
#import "TGRows.h"

@implementation TGStickerPacksViewController {
	NSArray *_ownedSets;
	NSArray *_trendingSets;
	NSArray *_archivedSets;
	NSArray *_recentStickers;
	NSArray *_favoriteStickers;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Stickers");
	// Edit reorders and archives the installed packs, as the official list.
	self.navigationItem.rightBarButtonItem = self.editButtonItem;
	_ownedSets = @[];
	_trendingSets = @[];
	_archivedSets = @[];
	_recentStickers = @[];
	_favoriteStickers = @[];
	[self rebuildSections];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self reloadOwnedPacks];
	[self reloadTrending];
	[self reloadArchived];
	[self reloadStickerShelves];
}

#pragma mark - loading

- (void)reloadOwnedPacks {
	__weak typeof(self) weakSelf = self;
	[[TGStickerStore shared] ownedStickerSetsWithCompletion:^(NSArray *sets){
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		_ownedSets = sets ?: @[];
		[me rebuildSections];
	}];
}

/// Showing the shelf is what marks it seen. Telegram drops the ids this
/// request names from the next recommendation, so the write belongs at the
/// moment the rows are drawn rather than at app launch.
- (void)reloadTrending {
	__weak typeof(self) weakSelf = self;
	[[TGStickerStore shared] trendingStickerSetsWithCompletion:^(NSArray *sets){
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		_trendingSets = sets ?: @[];
		NSMutableArray *ids = [NSMutableArray array];
		for (NSDictionary *set in _trendingSets)
			if (set[@"id"])
				[ids addObject:set[@"id"]];
		[[TGStickerStore shared] viewTrendingStickerSets:ids];
		[me rebuildSections];
	}];
}

#pragma mark - rows

- (void)reloadArchived {
	__weak typeof(self) weakSelf = self;
	[[TGStickerStore shared] archivedStickerSetsWithCompletion:^(NSArray *sets){
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		_archivedSets = sets ?: @[];
		[me rebuildSections];
	}];
}

- (void)reloadStickerShelves {
	__weak typeof(self) weakSelf = self;
	[[TGStickerStore shared] recentStickersWithCompletion:^(NSArray *stickers){
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		_recentStickers = stickers ?: @[];
		[me rebuildSections];
	}];
	[[TGStickerStore shared] favoriteStickersWithCompletion:^(NSArray *stickers){
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		_favoriteStickers = stickers ?: @[];
		[me rebuildSections];
	}];
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSArray *titles = TGStickerPacksRowTitles(_ownedSets, _trendingSets,
			_archivedSets, _recentStickers, _favoriteStickers);

	NSMutableArray *topRows = [NSMutableArray arrayWithArray:@[
		TGOpenRow(titles[0][0], nil, ^{ [weakSelf openNewPack]; }),
		TGSubtitleRow(titles[0][1], nil, ^{ [weakSelf askForShortName]; }),
		TGRedRow(titles[0][2], ^{ [weakSelf confirmClearRecent]; }),
	]];

	NSMutableArray *ownedRows = [NSMutableArray array];
	if (!_ownedSets.count){
		[ownedRows addObject:TGRow(TGKindPlain, titles[1][0])];
	} else {
		for (NSUInteger index = 0; index < _ownedSets.count; index++){
			NSDictionary *set = _ownedSets[index];
			NSString *title = TGStripUndrawableScalars(titles[1][index]);
			[ownedRows addObject:TGButtonRow(title,
					TGStickerPackOwnedDetail(set), TGLocalized(@"Archive"),
					^{ [weakSelf archivePack:set]; },
					^{ [weakSelf openPack:set]; })];
		}
	}

	NSMutableArray *trendingRows = [NSMutableArray array];
	if (!_trendingSets.count){
		[trendingRows addObject:TGRow(TGKindPlain, titles[2][0])];
	} else {
		for (NSUInteger index = 0; index < _trendingSets.count; index++){
			NSDictionary *set = _trendingSets[index];
			NSString *title = TGStripUndrawableScalars(titles[2][index]);
			[trendingRows addObject:TGSubtitleRow(title,
					TGStickerPackTrendingDetail(set),
					^{ [weakSelf offerPack:set]; })];
		}
	}

	NSMutableArray *emojiRows = [NSMutableArray array];
	for (NSUInteger index = 0; index < 4; index++){
		NSString *title = titles[3][index];
		[emojiRows addObject:TGSubtitleOpenRow(title, nil, ^{
			[weakSelf openEmojiShelf:index title:title];
		})];
	}

	NSMutableArray *shelfRows = [NSMutableArray array];
	for (NSUInteger index = 0; index < 2; index++){
		NSArray *list = index == 0 ? _recentStickers : _favoriteStickers;
		NSString *title = titles[5][index];
		NSString *detail = TGStickerPacksShelfDetail(list);
		if (list.count){
			[shelfRows addObject:TGSubtitleOpenRow(title, detail, ^{
				[weakSelf showGallery:list title:title
						empty:TGLocalized(@"No Results")];
			})];
		} else {
			[shelfRows addObject:TGSubtitleRow(title, detail, nil)];
		}
	}

	NSMutableArray *archivedRows = [NSMutableArray array];
	if (!_archivedSets.count){
		[archivedRows addObject:TGRow(TGKindPlain, titles[6][0])];
	} else {
		for (NSUInteger index = 0; index < _archivedSets.count; index++){
			NSDictionary *set = _archivedSets[index];
			NSString *title = TGStripUndrawableScalars(titles[6][index]);
			[archivedRows addObject:TGButtonRow(title,
					TGStickerPackArchivedDetail(set), TGLocalized(@"Restore"),
					^{ [weakSelf restorePack:set]; },
					^{ [weakSelf openPack:set]; })];
		}
	}

	self.sections = @[
		TGSection(nil, nil, topRows),
		TGSection(TGLocalized(@"My Stickers"), nil, ownedRows),
		TGSection(TGLocalized(@"Trending"), nil, trendingRows),
		TGSection(TGLocalized(@"Custom Emoji"), nil, emojiRows),
		TGSection(TGLocalized(@"Stickers"), nil, @[
			TGSubtitleOpenRow(titles[4][0], nil,
					^{ [weakSelf loadGreetingStickers]; }),
		]),
		TGSection(TGLocalized(@"Favorites"), nil, shelfRows),
		TGSection(TGLocalized(@"Archived"), nil, archivedRows),
	];
	[self reloadRows];
}

#pragma mark - choosing

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == 1 && _ownedSets.count > 0;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == 1 && _ownedSets.count > 0;
}

- (void)tableView:(UITableView *)tableView
		moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
			  toIndexPath:(NSIndexPath *)destinationIndexPath {
	if (sourceIndexPath.section != 1 || destinationIndexPath.section != 1)
		return;
	NSMutableArray *sets = [_ownedSets mutableCopy];
	NSDictionary *set = sets[(NSUInteger)sourceIndexPath.row];
	[sets removeObjectAtIndex:(NSUInteger)sourceIndexPath.row];
	[sets insertObject:set atIndex:MIN((NSUInteger)destinationIndexPath.row,
			sets.count)];
	_ownedSets = sets;
	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *item in _ownedSets)
		if (item[@"id"])
			[ids addObject:item[@"id"]];
	[[TGStickerStore shared] reorderInstalledStickerSets:ids];
	[self rebuildSections];
}

- (void)tableView:(UITableView *)tableView
		commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
		 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete ||
			indexPath.section != 1 ||
			indexPath.row >= (NSInteger)_ownedSets.count)
		return;
	NSDictionary *set = _ownedSets[(NSUInteger)indexPath.row];
	[[TGStickerStore shared] setStickerSet:set[@"id"] installed:NO archived:YES];
	[self reloadOwnedPacks];
	[self reloadArchived];
}

- (void)openPack:(NSDictionary *)set {
	TGStickerEditorViewController *editor =
			[[TGStickerEditorViewController alloc] init];
	editor.setId = [set[@"id"] longLongValue];
	editor.setName = set[@"shortName"];
	editor.setTitle = set[@"title"];
	editor.stickerType = set[@"stickerType"];
	editor.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:editor animated:YES];
}

- (void)openEmojiShelf:(NSInteger)kind title:(NSString *)title {
	if (kind == 0)
		[self loadDefaultEmojiShelf:title kind:0];
	else if (kind == 1)
		[self loadDefaultEmojiShelf:title kind:1];
	else if (kind == 2)
		[self loadDefaultEmojiShelf:title kind:2];
	else
		[self askForCustomEmojiIds];
}

#pragma mark - actions

- (void)openNewPack {
	TGStickerEditorViewController *editor =
			[[TGStickerEditorViewController alloc] init];
	editor.creating = YES;
	editor.stickerType = @"regular";
	editor.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:editor animated:YES];
}

/// The name is searched, then read back by id: searchStickerSet is what
/// finds it, and getStickerSetName is what proves the row's short name is
/// the server's and not a local echo.
- (void)askForShortName {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Search Stickers"
					message:nil
				placeholder:@"animals" text:@"" action:@"Search"
					 inView:self.view onSubmit:^(NSString *text){
		TGStickerPacksViewController *me = weakSelf;
		[[TGStickerStore shared] searchStickerSetNamed:text ignoreCache:YES
				completion:^(NSDictionary *set){
			if (!set){
				[TGAlertSheet showMessage:@"An error occurred."
									  title:@"Search Stickers" inView:me.view];
				return;
			}
			int64_t setId = [set[@"id"] longLongValue];
			[[TGStickerStore shared] stickerSetNameForId:setId completion:^(NSString *name){
				TGStickerPacksViewController *panel = weakSelf;
				if (!panel)
					return;
				NSUInteger packCount = (NSUInteger)[set[@"count"] unsignedIntegerValue];
				NSString *packCountText = TGLocalizedPluralValue(@"%@ sticker", @"%@ stickers",
						[NSString stringWithFormat:@"%lu", (unsigned long)packCount],
						(NSInteger)packCount);
				NSString *message = [NSString stringWithFormat:
						@"%@\n%@\n%@%@",
						set[@"title"] ?: @"Stickers",
						name.length ? name : (set[@"name"] ?: text),
						packCountText,
						[set[@"installed"] boolValue] ? @"\nAlready installed." : @""];
				NSArray *choices = [set[@"installed"] boolValue]
						? @[@"Open", @"Cancel"] : @[@"Install", @"Cancel"];
				[TGAlertSheet showChoices:choices title:@"View Sticker Set"
						message:message destructiveIndex:-1 inView:panel.view
						onChoice:^(NSInteger index){
					if (index != 0)
						return;
					if ([set[@"installed"] boolValue]){
						TGStickerEditorViewController *editor =
								[[TGStickerEditorViewController alloc] init];
						editor.setId = setId;
						editor.setName = name.length ? name : set[@"name"];
						editor.setTitle = set[@"title"];
						editor.stickerType = set[@"stickerType"];
						editor.hidesBottomBarWhenPushed = YES;
						[panel.navigationController pushViewController:editor
															 animated:YES];
						return;
					}
					[[TGStickerStore shared] setStickerSet:set[@"id"] installed:YES archived:NO];
					[TGAlertSheet showMessage:@"Stickers Added"
										  title:@"Stickers Added" inView:panel.view];
				}];
			}];
		}];
	}];
}

- (void)confirmClearRecent {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"Clear Recent Stickers"
						title:@"Clear Recent Stickers" action:@"Clear" destructive:YES
					   inView:self.view onConfirm:^{
		TGStickerPacksViewController *me = weakSelf;
		[[TGStickerStore shared] clearRecentStickersAttached:NO];
		[TGAlertSheet showMessage:@"No Results"
							  title:@"Clear Recent Stickers" inView:me.view];
	}];
}

- (void)archivePack:(NSDictionary *)set {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:TGLocalized(@"Archive")
						title:set[@"title"] ?: TGLocalized(@"Archive")
					   action:TGLocalized(@"Archive")
				  destructive:NO
					   inView:self.view
					onConfirm:^{
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		[[TGStickerStore shared] setStickerSet:set[@"id"] installed:NO archived:YES];
		[me reloadOwnedPacks];
		[me reloadArchived];
	}];
}

- (void)restorePack:(NSDictionary *)set {
	[[TGStickerStore shared] setStickerSet:set[@"id"] installed:YES archived:NO];
	[self reloadOwnedPacks];
	[self reloadArchived];
	[TGAlertSheet showMessage:TGLocalized(@"Stickers Added")
						  title:set[@"title"] ?: TGLocalized(@"Archived Stickers")
						 inView:self.view];
}

- (void)offerPack:(NSDictionary *)set {
	NSUInteger offeredCount = (NSUInteger)[set[@"count"] unsignedIntegerValue];
	NSString *message = TGLocalizedPluralValue(@"%@ sticker", @"%@ stickers",
			[NSString stringWithFormat:@"%lu", (unsigned long)offeredCount],
			(NSInteger)offeredCount);
	if ([set[@"installed"] boolValue]){
		[TGAlertSheet showMessage:message title:set[@"title"] inView:self.view];
		return;
	}
	__weak typeof(self) weakSelf = self;
	int64_t setId = [set[@"id"] longLongValue];
	[TGAlertSheet showChoices:@[@"Install", @"Not Now"] title:set[@"title"]
					message:message destructiveIndex:-1 inView:self.view
					 onChoice:^(NSInteger index){
		if (index != 0)
			return;
		TGStickerPacksViewController *me = weakSelf;
		[[TGStickerStore shared] setStickerSet:@(setId) installed:YES archived:NO];
		[TGAlertSheet showMessage:@"Stickers Added"
							  title:@"Stickers Added" inView:me.view];
	}];
}

- (void)loadDefaultEmojiShelf:(NSString *)title kind:(NSInteger)kind {
	__weak typeof(self) weakSelf = self;
	void (^show)(NSArray *) = ^(NSArray *stickers){
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		[me showGallery:stickers title:title
				empty:@"No Results"];
	};
	if (kind == 0)
		[[TGStickerStore shared] defaultProfilePhotoCustomEmojiStickersWithCompletion:show];
	else if (kind == 1)
		[[TGStickerStore shared] defaultChatPhotoCustomEmojiStickersWithCompletion:show];
	else
		[[TGStickerStore shared] defaultBackgroundCustomEmojiStickersWithCompletion:show];
}

- (void)askForCustomEmojiIds {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Custom Emoji"
					message:nil
				placeholder:@"5368324170671202286" text:@"" action:@"Look Up"
					 inView:self.view onSubmit:^(NSString *text){
		TGStickerPacksViewController *me = weakSelf;
		NSMutableArray *ids = [NSMutableArray array];
		for (NSString *piece in [text componentsSeparatedByString:@","]){
			NSString *trimmed = [piece stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			long long value = [trimmed longLongValue];
			if (value > 0)
				[ids addObject:@(value)];
		}
		if (!ids.count){
			[TGAlertSheet showMessage:@"An error occurred."
								  title:@"Custom Emoji" inView:me.view];
			return;
		}
		[[TGStickerStore shared] customEmojiStickersForIds:ids completion:^(NSArray *stickers){
			TGStickerPacksViewController *panel = weakSelf;
			if (!panel)
				return;
			[panel showGallery:stickers title:@"Custom Emoji"
					empty:@"No Results"];
		}];
	}];
}

- (void)loadGreetingStickers {
	__weak typeof(self) weakSelf = self;
	[[TGStickerStore shared] greetingStickersWithCompletion:^(NSArray *stickers){
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		[me showGallery:stickers title:@"Stickers"
				empty:@"No Results"];
	}];
}

- (void)showGallery:(NSArray *)stickers title:(NSString *)title empty:(NSString *)empty {
	if (!stickers.count){
		[TGAlertSheet showMessage:empty title:title inView:self.view];
		return;
	}
	TGStickerGalleryViewController *gallery =
			[[TGStickerGalleryViewController alloc] init];
	gallery.stickers = stickers;
	gallery.title = title;
	gallery.emptyText = empty;
	gallery.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:gallery animated:YES];
}

@end
