//
// TGStickerPacksViewController.m - see the header.
//
#import "TGMessageLayout.h"
#import "TGLocalization.h"
#import "TGStickerPacksViewController.h"
#import "TGAlertSheet.h"
#import "TGClient.h"
#import "TGStickerEditorViewController.h"
#import "TGStickerGalleryViewController.h"
#import "TGStyle.h"
#import "TGTheme.h"

@implementation TGStickerPacksViewController {
	NSArray *_ownedSets;
	NSArray *_trendingSets;
	NSArray *_archivedSets;
	NSArray *_recentStickers;
	NSArray *_favoriteStickers;
}

- (void)viewDidLoad {
	[super viewDidLoad];


	self.title = @"Stickers";
	self.tableView.rowHeight = TGMetricPersonRow;
	// Edit reorders and archives the installed packs, as the official list.
	self.navigationItem.rightBarButtonItem = self.editButtonItem;
	_ownedSets = @[];
	_trendingSets = @[];
	_archivedSets = @[];
	_recentStickers = @[];
	_favoriteStickers = @[];
	[self applyTheme];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	[self reloadOwnedPacks];
	[self reloadTrending];
	[self reloadArchived];
	[self reloadStickerShelves];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	self.tableView.backgroundColor = [theme listBackgroundColour];
	self.tableView.separatorColor = [theme separatorColour];
	[theme styleNavigationBar:self.navigationController.navigationBar];
}

#pragma mark - loading

- (void)reloadOwnedPacks {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] ownedStickerSetsWithCompletion:^(NSArray *sets){
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		_ownedSets = sets ?: @[];
		[me.tableView reloadData];
	}];
}

/// Showing the shelf is what marks it seen. Telegram drops the ids this
/// request names from the next recommendation, so the write belongs at the
/// moment the rows are drawn rather than at app launch.
- (void)reloadTrending {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] trendingStickerSetsWithCompletion:^(NSArray *sets){
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		_trendingSets = sets ?: @[];
		NSMutableArray *ids = [NSMutableArray array];
		for (NSDictionary *set in _trendingSets)
			if (set[@"id"])
				[ids addObject:set[@"id"]];
		[[TGClient shared] viewTrendingStickerSets:ids];
		[me.tableView reloadData];
	}];
}

#pragma mark - rows

- (void)reloadArchived {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] archivedStickerSetsWithCompletion:^(NSArray *sets){
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		_archivedSets = sets ?: @[];
		[me.tableView reloadData];
	}];
}

- (void)reloadStickerShelves {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] recentStickersWithCompletion:^(NSArray *stickers){
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		_recentStickers = stickers ?: @[];
		[me.tableView reloadData];
	}];
	[[TGClient shared] favoriteStickersWithCompletion:^(NSArray *stickers){
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		_favoriteStickers = stickers ?: @[];
		[me.tableView reloadData];
	}];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 7;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section){
		case 0: return 3;             // new, search, clear recents
		case 1: return MAX((NSInteger)_ownedSets.count, 1);
		case 2: return MAX((NSInteger)_trendingSets.count, 1);
		case 3: return 4;             // three default shelves, id lookup
		case 5: return 2;             // recently used, favourites
		case 6: return MAX((NSInteger)_archivedSets.count, 1);
		default: return 1;            // greeting stickers
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section){
		case 1: return @"My Stickers";
		case 2: return @"Trending";
		case 3: return @"Custom Emoji";
		case 5: return @"Favorites";
		case 6: return @"Archived";
		default: return section == 4 ? @"Stickers" : nil;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return nil;
}

- (UITableViewCell *)baseCell:(UITableView *)tableView {
	static NSString *cellId = @"row";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:cellId];
	TGTheme *theme = [TGTheme shared];
	cell.backgroundColor = [theme listBackgroundColour];
	cell.textLabel.textColor = [theme primaryTextColour];
	cell.detailTextLabel.textColor = [theme secondaryTextColour];
	cell.textLabel.font = TGFontRow();
	cell.detailTextLabel.font = TGFontCaption();
	cell.accessoryType = UITableViewCellAccessoryNone;
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [self baseCell:tableView];
	cell.accessoryView = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.detailTextLabel.text = nil;
	cell.selectionStyle = UITableViewCellSelectionStyleDefault;

	if (indexPath.section == 0){
		if (indexPath.row == 0){
			cell.textLabel.text = @"New Sticker Set";
			cell.detailTextLabel.text = nil;
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		} else if (indexPath.row == 1){
			cell.textLabel.text = @"Search Stickers";
			cell.detailTextLabel.text = nil;
		} else {
			cell.textLabel.text = @"Clear Recent Stickers";
			cell.detailTextLabel.text = nil;
			cell.textLabel.textColor = [TGTheme shared].destructiveColour;
		}
		return cell;
	}

	if (indexPath.section == 1){
		if (!_ownedSets.count){
			cell.textLabel.text = @"No Stickers Found";
			cell.detailTextLabel.text = nil;
			cell.accessoryType = UITableViewCellAccessoryNone;
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			return cell;
		}
		NSDictionary *set = _ownedSets[(NSUInteger)indexPath.row];
		cell.textLabel.text = [set[@"title"] length] ? TGStripUndrawableScalars(set[@"title"]) : @"Stickers";
		NSString *type = [self typeWord:set[@"stickerType"]];
		NSUInteger ownedCount = (NSUInteger)[set[@"count"] unsignedIntegerValue];
		NSString *ownedCountText = TGLocalizedPluralValue(@"%@ sticker", @"%@ stickers",
				[NSString stringWithFormat:@"%lu", (unsigned long)ownedCount],
				(NSInteger)ownedCount);
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  ·  %@  ·  %@",
				set[@"shortName"] ?: @"-", ownedCountText, type];
		UIButton *archive = [UIButton buttonWithType:UIButtonTypeCustom];
		archive.frame = CGRectMake(0, 0, TGMetricStoryBubble, TGMetricSearchScopeHeight);
		archive.titleLabel.font = TGFontCaption();
		[archive setTitle:@"Archive" forState:UIControlStateNormal];
		[archive setTitleColor:[[TGTheme shared] accentColour]
					  forState:UIControlStateNormal];
		archive.tag = indexPath.row;
		[archive addTarget:self action:@selector(archivePackTapped:)
		  forControlEvents:UIControlEventTouchUpInside];
		cell.accessoryView = archive;
		cell.accessoryType = UITableViewCellAccessoryNone;
		return cell;
	}

	if (indexPath.section == 2){
		if (!_trendingSets.count){
			cell.textLabel.text = @"No Results";
			cell.detailTextLabel.text = nil;
			cell.accessoryType = UITableViewCellAccessoryNone;
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			return cell;
		}
		NSDictionary *set = _trendingSets[(NSUInteger)indexPath.row];
		cell.textLabel.text = [set[@"title"] length] ? TGStripUndrawableScalars(set[@"title"]) : @"Trending Stickers";
		NSUInteger trendingCount = (NSUInteger)[set[@"count"] unsignedIntegerValue];
		NSString *trendingCountText = TGLocalizedPluralValue(@"%@ sticker", @"%@ stickers",
				[NSString stringWithFormat:@"%lu", (unsigned long)trendingCount],
				(NSInteger)trendingCount);
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@",
				trendingCountText,
				[set[@"installed"] boolValue] ? @"  ·  installed" : @""];
		return cell;
	}

	if (indexPath.section == 5){
		BOOL recent = indexPath.row == 0;
		NSArray *list = recent ? _recentStickers : _favoriteStickers;
		cell.textLabel.text = recent ? @"Recently Used" : @"Favorites";
		cell.detailTextLabel.text = list.count
				? TGLocalizedPluralValue(@"%@ sticker", @"%@ stickers", [NSString stringWithFormat:@"%lu", (unsigned long)list.count], (NSInteger)list.count)
				: @"No Results";
		cell.accessoryType = list.count ? UITableViewCellAccessoryDisclosureIndicator
										: UITableViewCellAccessoryNone;
		cell.selectionStyle = list.count ? UITableViewCellSelectionStyleDefault
										 : UITableViewCellSelectionStyleNone;
		return cell;
	}

	if (indexPath.section == 6){
		cell.selectionStyle = UITableViewCellSelectionStyleDefault;
		if (!_archivedSets.count){
			cell.textLabel.text = @"No Results";
			cell.detailTextLabel.text = nil;
			cell.accessoryType = UITableViewCellAccessoryNone;
			return cell;
		}
		NSDictionary *set = _archivedSets[(NSUInteger)indexPath.row];
		cell.textLabel.text = [set[@"title"] length] ? TGStripUndrawableScalars(set[@"title"]) : @"Archived Stickers";
		NSUInteger archivedCount = (NSUInteger)[set[@"count"] unsignedIntegerValue];
		NSString *archivedCountText = TGLocalizedPluralValue(@"%@ sticker", @"%@ stickers",
				[NSString stringWithFormat:@"%lu", (unsigned long)archivedCount],
				(NSInteger)archivedCount);
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  ·  %@",
				set[@"shortName"] ?: @"-", archivedCountText];
		UIButton *restore = [UIButton buttonWithType:UIButtonTypeCustom];
		restore.frame = CGRectMake(0, 0, TGMetricStoryBubble, TGMetricSearchScopeHeight);
		restore.titleLabel.font = TGFontCaption();
		[restore setTitle:@"Restore" forState:UIControlStateNormal];
		[restore setTitleColor:[[TGTheme shared] accentColour]
					  forState:UIControlStateNormal];
		restore.tag = indexPath.row;
		[restore addTarget:self action:@selector(restorePackTapped:)
		  forControlEvents:UIControlEventTouchUpInside];
		cell.accessoryView = restore;
		cell.accessoryType = UITableViewCellAccessoryNone;
		return cell;
	}

	if (indexPath.section == 3){
		NSArray *titles = @[@"Add Icons To Profile", @"Add Icons To Replies",
							@"Background Emoji", @"Search Emoji"];
		NSArray *notes = @[@"", @"", @"", @""];
		cell.textLabel.text = titles[(NSUInteger)indexPath.row];
		cell.detailTextLabel.text = notes[(NSUInteger)indexPath.row];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}

	cell.textLabel.text = @"Stickers";
	cell.detailTextLabel.text = nil;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}

- (NSString *)typeWord:(NSString *)type {
	if ([type isEqualToString:@"stickerTypeCustomEmoji"] ||
		[type isEqualToString:@"customEmoji"])
		return @"custom emoji";
	if ([type isEqualToString:@"stickerTypeMask"] || [type isEqualToString:@"mask"])
		return @"masks";
	return @"regular";
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
	[[TGClient shared] reorderInstalledStickerSets:ids];
}

- (void)tableView:(UITableView *)tableView
		commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
		 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete ||
			indexPath.section != 1 ||
			indexPath.row >= (NSInteger)_ownedSets.count)
		return;
	NSDictionary *set = _ownedSets[(NSUInteger)indexPath.row];
	[[TGClient shared] setStickerSet:set[@"id"] installed:NO archived:YES];
	[self reloadOwnedPacks];
	[self reloadArchived];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 6){
		// An archived pack opens like any other; Restore is the button beside it.
		if (indexPath.row >= (NSInteger)_archivedSets.count)
			return;
		NSDictionary *set = _archivedSets[(NSUInteger)indexPath.row];
		TGStickerEditorViewController *editor =
				[[TGStickerEditorViewController alloc] init];
		editor.setId = [set[@"id"] longLongValue];
		editor.setName = set[@"shortName"];
		editor.setTitle = set[@"title"];
		editor.stickerType = set[@"stickerType"];
		editor.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:editor animated:YES];
		return;
	}
	if (indexPath.section == 1 && !_ownedSets.count)
		return;
	if (indexPath.section == 2 && !_trendingSets.count)
		return;
	if (indexPath.section == 5){
		BOOL recent = indexPath.row == 0;
		NSArray *list = recent ? _recentStickers : _favoriteStickers;
		if (!list.count)
			return;
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.section == 0){
		if (indexPath.row == 0)
			[self openNewPack];
		else if (indexPath.row == 1)
			[self askForShortName];
		else
			[self confirmClearRecent];
		return;
	}

	if (indexPath.section == 1){
		if (!_ownedSets.count)
			return;
		NSDictionary *set = _ownedSets[(NSUInteger)indexPath.row];
		TGStickerEditorViewController *editor =
				[[TGStickerEditorViewController alloc] init];
		editor.setId = [set[@"id"] longLongValue];
		editor.setName = set[@"shortName"];
		editor.setTitle = set[@"title"];
		editor.stickerType = set[@"stickerType"];
		editor.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:editor animated:YES];
		return;
	}

	if (indexPath.section == 2){
		if (!_trendingSets.count)
			return;
		[self offerPack:_trendingSets[(NSUInteger)indexPath.row]];
		return;
	}

	if (indexPath.section == 5){
		BOOL recent = indexPath.row == 0;
		NSArray *list = recent ? _recentStickers : _favoriteStickers;
		if (!list.count)
			return;
		[self showGallery:list title:recent ? @"Recently Used" : @"Favorites"
				empty:@"No Results"];
		return;
	}

	if (indexPath.section == 6)
		return;

	if (indexPath.section == 3){
		if (indexPath.row == 0)
			[self loadDefaultEmojiShelf:@"Add Icons To Profile" kind:0];
		else if (indexPath.row == 1)
			[self loadDefaultEmojiShelf:@"Add Icons To Replies" kind:1];
		else if (indexPath.row == 2)
			[self loadDefaultEmojiShelf:@"Background Emoji" kind:2];
		else
			[self askForCustomEmojiIds];
		return;
	}

	[self loadGreetingStickers];
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
		[[TGClient shared] searchStickerSetNamed:text ignoreCache:YES
				completion:^(NSDictionary *set){
			if (!set){
				[TGAlertSheet showMessage:@"An error occurred."
									  title:@"Search Stickers" inView:me.view];
				return;
			}
			int64_t setId = [set[@"id"] longLongValue];
			[[TGClient shared] stickerSetNameForId:setId completion:^(NSString *name){
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
					[[TGClient shared] setStickerSet:set[@"id"] installed:YES archived:NO];
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
		[[TGClient shared] clearRecentStickersAttached:NO];
		[TGAlertSheet showMessage:@"No Results"
							  title:@"Clear Recent Stickers" inView:me.view];
	}];
}

- (void)archivePackTapped:(UIButton *)button {
	NSInteger row = button.tag;
	if (row < 0 || row >= (NSInteger)_ownedSets.count)
		return;
	NSDictionary *set = _ownedSets[(NSUInteger)row];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"Archive"
						title:set[@"title"] ?: @"Archive"
					   action:@"Archive"
				  destructive:NO
					   inView:self.view
					onConfirm:^{
		TGStickerPacksViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] setStickerSet:set[@"id"] installed:NO archived:YES];
		[me reloadOwnedPacks];
		[me reloadArchived];
	}];
}

- (void)restorePackTapped:(UIButton *)button {
	NSInteger row = button.tag;
	if (row < 0 || row >= (NSInteger)_archivedSets.count)
		return;
	NSDictionary *set = _archivedSets[(NSUInteger)row];
	[[TGClient shared] setStickerSet:set[@"id"] installed:YES archived:NO];
	[self reloadOwnedPacks];
	[self reloadArchived];
	[TGAlertSheet showMessage:@"Stickers Added"
						  title:set[@"title"] ?: @"Archived Stickers" inView:self.view];
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
		[[TGClient shared] setStickerSet:@(setId) installed:YES archived:NO];
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
		[[TGClient shared] defaultProfilePhotoCustomEmojiStickersWithCompletion:show];
	else if (kind == 1)
		[[TGClient shared] defaultChatPhotoCustomEmojiStickersWithCompletion:show];
	else
		[[TGClient shared] defaultBackgroundCustomEmojiStickersWithCompletion:show];
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
		[[TGClient shared] customEmojiStickersForIds:ids completion:^(NSArray *stickers){
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
	[[TGClient shared] greetingStickersWithCompletion:^(NSArray *stickers){
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
