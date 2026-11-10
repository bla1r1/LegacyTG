#import "TGProfileViewControllerInternal.h"
#import "TGMediaViewer.h"
#import "TGGiftViewController.h"
#import "TGAlertSheet.h"
#import "TGStoryViewerViewController.h"
#import "TGProfileTabs.h"
#import "TGProfileStore.h"
#import "TGProfileSupport.h"
#import "TGIcons.h"
#import "TGCapabilities.h"
#import "TGLocalization.h"
#import "TGProfileLogic.h"
#import "TGRows.h"
#import "TGGridRowCell.h"
#import "TGPictureRowCell.h"
#import "TGMusicPlayer.h"

/// The address a piece of text links to: a text link's own URL, or the first
/// URL typed in it. Nil when it has none.
NSURL *TGProfileFirstURL(NSString *text, NSArray *entities) {
	if (![entities isKindOfClass:NSArray.class])
		return nil;
	for (NSDictionary *entity in entities){
		NSDictionary *type = entity[@"type"];
		NSString *name = [type isKindOfClass:NSDictionary.class] ? type[@"@type"] : nil;
		NSString *url = nil;
		if ([name isEqualToString:@"textEntityTypeTextUrl"])
			url = type[@"url"];
		else if ([name isEqualToString:@"textEntityTypeUrl"]){
			NSInteger offset = [entity[@"offset"] integerValue], length = [entity[@"length"] integerValue];
			if (length > 0 && (NSUInteger)(offset + length) <= text.length)
				url = [text substringWithRange:NSMakeRange((NSUInteger)offset, (NSUInteger)length)];
		}
		if (!url.length)
			continue;
		NSURL *parsed = [NSURL URLWithString:url];
		return parsed.scheme.length ? parsed
				: [NSURL URLWithString:[@"http://" stringByAppendingString:url]];
	}
	return nil;
}

static BOOL TGKindIsStories(NSString *kind) {
	return [kind isEqualToString:@"stories"] || [kind isEqualToString:@"archive"];
}

static NSString *TGProfileFileSizeText(NSNumber *bytes) {
	long long value = [bytes longLongValue];
	if (value <= 0)
		return nil;
	if (value < 1024)
		return [NSString stringWithFormat:@"%lld B", value];
	if (value < 1024 * 1024)
		return [NSString stringWithFormat:@"%.0f KB", value / 1024.0];
	return [NSString stringWithFormat:@"%.1f MB", value / (1024.0 * 1024.0)];
}

static NSString *TGProfileDurationText(NSNumber *seconds) {
	NSInteger value = [seconds integerValue];
	if (value <= 0)
		return nil;
	return [NSString stringWithFormat:@"%ld:%02ld", (long)(value / 60),
			(long)(value % 60)];
}

static void TGProfileApplyAppLocale(NSDateFormatter *formatter) {
	NSString *language = TGAppLanguage();
	formatter.locale = language.length
			? [NSLocale localeWithLocaleIdentifier:language]
			: [NSLocale currentLocale];
}

static NSString *TGProfileShortDate(NSNumber *date) {
	if (![date isKindOfClass:NSNumber.class] || !date.doubleValue)
		return nil;
	static NSDateFormatter *formatter = nil;
	if (!formatter){
		formatter = [[NSDateFormatter alloc] init];
		formatter.dateStyle = NSDateFormatterMediumStyle;
		formatter.timeStyle = NSDateFormatterNoStyle;
	}
	TGProfileApplyAppLocale(formatter);
	return [formatter stringFromDate:
			[NSDate dateWithTimeIntervalSince1970:date.doubleValue]];
}

static NSString *TGProfileJoin(NSString *left, NSString *right) {
	if (left.length && right.length)
		return [NSString stringWithFormat:@"%@ · %@", left, right];
	return left.length ? left : right;
}

@implementation TGProfileViewController (Media)

- (void)loadMedia {
	[self fetchMediaForKind:@"stories"];
	[self fetchMediaForKind:@"gifts"];
	[self fetchAllMediaCounts];
}

- (void)fetchAllMediaCounts {
	if (!self.chatId)
		return;
	NSDictionary *filters = @{
		@"media" : @"searchMessagesFilterPhotoAndVideo",
		@"files" : @"searchMessagesFilterDocument",
		@"music" : @"searchMessagesFilterAudio",
		@"voice" : @"searchMessagesFilterVoiceAndVideoNote",
		@"links" : @"searchMessagesFilterUrl",
	};
	__weak typeof(self) weakSelf = self;
	[filters enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSString *filterType, BOOL *stop){
		[[TGProfileStore shared] messageCountInChat:weakSelf.chatId
									   filter:filterType
								   completion:^(NSInteger count){
			TGProfileViewController *me = weakSelf;
			if (!me || count <= 0)
				return;
			me.mediaCounts[kind] = @(count);
			[me reloadTableDebounced];
		}];
	}];
}

- (void)fetchMediaForKind:(NSString *)kind {
	if (!kind.length)
		return;
	if ([self.loadedMediaKinds containsObject:kind] ||
			[self.loadingMediaKinds containsObject:kind])
		return;
	if ([kind isEqualToString:@"groups"] && !self.userId)
		return;
	[self.loadingMediaKinds addObject:kind];

	NSDictionary *filters = @{@"media" : @"searchMessagesFilterPhotoAndVideo",
							  @"files" : @"searchMessagesFilterDocument",
							  @"music" : @"searchMessagesFilterAudio",
							  @"voice" : @"searchMessagesFilterVoiceAndVideoNote",
							  @"links" : @"searchMessagesFilterUrl"};
	NSString *filterForCount = filters[kind];
	__weak typeof(self) weakSelf = self;
	void (^done)(NSArray *) = ^(NSArray *rows){
		TGProfileViewController *me = weakSelf;
		if (!me)
			return;
		[me.loadingMediaKinds removeObject:kind];
		[me.loadedMediaKinds addObject:kind];
		NSArray *safe = rows ?: @[];
		if ([kind isEqualToString:@"media"])
			me.photos = safe;
		else if ([kind isEqualToString:@"files"])
			me.files = safe;
		else if ([kind isEqualToString:@"music"])
			me.music = safe;
		else if ([kind isEqualToString:@"voice"])
			me.voice = safe;
		else if ([kind isEqualToString:@"links"])
			me.links = safe;
		else if ([kind isEqualToString:@"groups"])
			me.groupsInCommon = safe;
		else if ([kind isEqualToString:@"stories"])
			me.stories = safe;
		else if ([kind isEqualToString:@"archive"])
			me.archivedStories = safe;
		else if ([kind isEqualToString:@"gifts"])
			me.gifts = safe;
		if (filterForCount)
			[[TGProfileStore shared] messageCountInChat:me.chatId filter:filterForCount
									   completion:^(NSInteger count){
				me.mediaCounts[kind] = @(count);
				[me reloadTableDebounced];
			}];
		else if (![kind isEqualToString:@"gifts"])
			me.mediaCounts[kind] = @(safe.count);
		[me reloadTableDebounced];
	};

	if ([kind isEqualToString:@"similar"]){
		done(self.similarChatIds ?: @[]);
		return;
	}

	if ([kind isEqualToString:@"stories"]){
		[[TGProfileStore shared] storiesForChat:self.chatId completion:done];
	} else if ([kind isEqualToString:@"archive"]){
		[[TGProfileStore shared] archivedStoriesForChat:self.chatId completion:done];
	} else if ([kind isEqualToString:@"gifts"]){
		NSDictionary *owner = [self giftOwnerSenderId];
		if (owner){
			__weak typeof(self) weakProfile = self;
			[[TGProfileStore shared] giftsForOwner:owner offset:@"" completion:^(NSArray *gifts, NSString *nextOffset, NSInteger totalCount){
				TGProfileViewController *me = weakProfile;
				if (!me) return;
				me.giftsNextOffset = nextOffset;
				if (totalCount > 0)
					me.mediaCounts[@"gifts"] = @(totalCount);
				done(gifts);
			}];
		} else {
			done(@[]);
		}
	} else if ([kind isEqualToString:@"groups"]){
		[[TGProfileStore shared] groupsInCommonWithUser:self.userId completion:done];
	} else {
		if (!filterForCount){
			[self.loadingMediaKinds removeObject:kind];
			return;
		}
		[[TGProfileStore shared] mediaInChat:self.chatId filter:filterForCount completion:done];
	}
}

- (NSInteger)mediaSectionIndex {
	for (NSUInteger index = 0; index < self.sections.count; index++){
		NSArray *rows = self.sections[index][@"rows"];
		for (NSDictionary *row in rows)
			if ([row[TGRowKind] isEqualToString:TGKindTabStrip])
				return (NSInteger)index;
	}
	return -1;
}

- (void)loadVisibleMediaTabIfNeeded {
	NSInteger index = [self mediaSectionIndex];
	if (index < 0)
		return;
	CGRect section = [self.tableView rectForSection:index];
	if (!CGRectIntersectsRect(section, self.tableView.bounds))
		return;
	NSString *kind = [self selectedMediaKind];
	if (kind)
		[self fetchMediaForKind:kind];
}

- (NSArray *)currentMediaTabs {
	NSDictionary *titles = @{@"stories" : @"Stories", @"gifts" : @"Gifts",
			@"media" : @"Media", @"files" : @"Files", @"music" : @"Music",
			@"voice" : @"Voice", @"links" : @"Links", @"groups" : @"Groups",
			@"archive" : @"Archive", @"similar" : @"Similar Channels"};
	BOOL own = self.isOwnProfile;
	BOOL ownPublic = own && ![self showsSavedMessages];
	NSMutableArray *out = [NSMutableArray array];
	for (NSString *kind in TGProfileTabKinds(!own && self.stories.count,
			self.gifts.count > 0, self.commonGroupCount > 0, ownPublic,
			self.mainMediaKind))
		[out addObject:@{@"title" : titles[kind], @"kind" : kind}];
	if (self.isChannel && self.similarChatIds.count)
		[out addObject:@{@"title" : titles[@"similar"], @"kind" : @"similar"}];
	return out;
}

- (void)mediaTabSelected:(NSString *)kind {
	if (!kind.length)
		return;
	self.storedMediaKind = kind;
	[self.thumbnailsRequested removeAllObjects];
	// A tab's pictures belong to that tab; keeping every pane's thumbnails is
	// what the 16 MB ceiling exists to stop.
	[self.mediaImages removeAllObjects];
	[self fetchMediaForKind:kind];
	self.mediaSearchActive = NO;
	self.mediaSearchQuery = nil;
	self.mediaSearchBar.text = @"";
	self.mediaSearchBar.showsCancelButton = NO;
	[self.mediaSearchBar resignFirstResponder];
	[self updateNavigationItem];
	[self rebuildSections];
}

/// Holding a tab asks Telegram to make it the profile's main tab.
- (void)setMainTabKind:(NSString *)kind {
	if (!kind.length)
		return;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:nil
					   action:TGLocalized(@"Set as Main Tab")
				  destructive:NO
					   inView:self.view
					onConfirm:^{
		[[TGProfileStore shared] setSupergroupMainProfileTab:kind inChat:weakSelf.chatId
				completion:^(BOOL ok, NSString *error){
			TGProfileViewController *me = weakSelf;
			if (!ok){
				[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
									title:TGLocalized(@"Set as Main Tab") inView:me.view];
				return;
			}
			me.mainMediaKind = kind;
			[me rebuildSections];
		}];
	}];
}

- (BOOL)selectedTabIsGrid {
	NSString *kind = [self selectedMediaKind];
	return [kind isEqualToString:@"media"] || TGKindIsStories(kind) ||
		   [kind isEqualToString:@"gifts"];
}

- (NSDictionary *)giftOwnerSenderId {
	if (self.userId)
		return @{@"@type" : @"messageSenderUser", @"user_id" : @(self.userId)};
	if (self.chatId)
		return @{@"@type" : @"messageSenderChat", @"chat_id" : @(self.chatId)};
	return nil;
}

- (NSString *)selectedMediaKind {
	NSString *kind = self.storedMediaKind;
	if ([kind isEqualToString:@"posts"])
		kind = @"stories";
	else if ([kind isEqualToString:@"gifs"])
		kind = @"media";
	NSArray *tabs = [self currentMediaTabs];
	for (NSDictionary *tab in tabs)
		if ([tab[@"kind"] isEqualToString:kind])
			return kind;
	return tabs.firstObject[@"kind"];
}

- (BOOL)showsSavedMessages {
	return self.chatId && self.chatId == [[TGProfileStore shared] savedMessagesChatId] &&
			self.onSearchTapped != nil;
}

- (NSArray *)selectedMediaRows {
	NSString *kind = [self selectedMediaKind];
	NSArray *rows = @[];
	if ([kind isEqualToString:@"media"])   rows = self.photos ?: @[];
	else if ([kind isEqualToString:@"files"])   rows = self.files ?: @[];
	else if ([kind isEqualToString:@"music"])   rows = self.music ?: @[];
	else if ([kind isEqualToString:@"voice"])   rows = self.voice ?: @[];
	else if ([kind isEqualToString:@"links"])   rows = self.links ?: @[];
	else if ([kind isEqualToString:@"groups"])  rows = self.groupsInCommon ?: @[];
	else if ([kind isEqualToString:@"archive"]) rows = self.archivedStories ?: @[];
	else if ([kind isEqualToString:@"stories"]) rows = self.stories ?: @[];
	else if ([kind isEqualToString:@"gifts"])   rows = self.gifts ?: @[];
	else if ([kind isEqualToString:@"similar"]) rows = self.similarChatIds ?: @[];
	return TGProfileMediaRowsMatchingQuery(rows, self.mediaSearchQuery, kind);
}

- (UISearchBar *)ensureMediaSearchBar {
	if (self.mediaSearchBar)
		return self.mediaSearchBar;
	UISearchBar *bar = [[UISearchBar alloc] initWithFrame:
			CGRectMake(0, 0, self.view.bounds.size.width,
					TGMetricSearchBarHeight)];
	bar.delegate = self;
	bar.placeholder = TGLocalized(@"Search");
	bar.autocorrectionType = UITextAutocorrectionTypeNo;
	bar.autocapitalizationType = UITextAutocapitalizationTypeNone;
	[[TGTheme shared] styleSearchBar:bar];
	self.mediaSearchBar = bar;
	return bar;
}

- (void)mediaSearchTapped {
	self.mediaSearchActive = YES;
	self.mediaSearchQuery = nil;
	UISearchBar *bar = [self ensureMediaSearchBar];
	bar.text = @"";
	bar.showsCancelButton = YES;
	[self updateNavigationItem];
	[self rebuildSections];
	[self.tableView layoutIfNeeded];
	NSInteger index = [self mediaSectionIndex];
	if (index >= 0){
		CGRect header = [self.tableView rectForSection:index];
		[self.tableView setContentOffset:CGPointMake(0, header.origin.y)
								animated:NO];
	}
	[bar performSelector:@selector(becomeFirstResponder) withObject:nil
			 afterDelay:0];
}

- (void)endMediaSearch {
	self.mediaSearchActive = NO;
	self.mediaSearchQuery = nil;
	self.mediaSearchBar.text = @"";
	self.mediaSearchBar.showsCancelButton = NO;
	[self.mediaSearchBar resignFirstResponder];
	[self updateNavigationItem];
	[self rebuildSections];
}

#pragma mark - search bar

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	self.mediaSearchQuery = [searchText stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	[self rebuildSections];
	if (self.mediaSearchActive && !searchBar.isFirstResponder)
		[searchBar performSelector:@selector(becomeFirstResponder)
					   withObject:nil afterDelay:0];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[self endMediaSearch];
}

#pragma mark - media content

- (void)downloadMediaImage:(NSNumber *)fileId {
	if (![fileId isKindOfClass:NSNumber.class] || fileId.integerValue <= 0)
		return;
	if (self.mediaImages[fileId])
		return;
	if ([self.thumbnailsRequested containsObject:fileId])
		return;
	[self.thumbnailsRequested addObject:fileId];
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] downloadFile:fileId.integerValue
						   priority:TGDownloadPriorityOnScreen
						 completion:^(NSString *path){
		if (!path.length)
			return;
		UIImage *image = [TGIcons decodedImageAtPath:path
				fittingSize:CGSizeMake(TGMetricProfilePhotoSide,
						TGMetricProfilePhotoSide)
						 fill:YES
						scale:[UIScreen mainScreen].scale];
		if (!image)
			return;
		dispatch_async(dispatch_get_main_queue(), ^{
			TGProfileViewController *me = weakSelf;
			if (!me)
				return;
			me.mediaImages[fileId] = image;
			[me reloadTableDebounced];
		});
	}];
}

- (UIImage *)imageForItem:(NSDictionary *)item storyKind:(BOOL)storyKind {
	NSNumber *fileId = storyKind
			? (item[@"thumbPhotoId"] ?: item[@"photoId"])
			: (item[@"photoId"] ?: item[@"thumbPhotoId"] ?: item[@"albumCoverId"]);
	if (![fileId isKindOfClass:NSNumber.class] || fileId.integerValue <= 0)
		return nil;
	UIImage *cached = self.mediaImages[fileId];
	if (cached)
		return cached;
	[self downloadMediaImage:fileId];
	return nil;
}

- (NSDictionary *)storyTileForItem:(NSDictionary *)item index:(NSInteger)index {
	NSMutableDictionary *tile = [NSMutableDictionary dictionary];
	UIImage *image = [self imageForItem:item storyKind:YES];
	if (image)
		tile[TGGridItemImage] = image;
	if (self.isOwnProfile){
		__weak typeof(self) weakSelf = self;
		tile[TGGridItemHold] = ^{ [weakSelf handleStoryHoldAtIndex:index]; };
	}
	return tile;
}

- (NSDictionary *)photoTileForItem:(NSDictionary *)item {
	NSMutableDictionary *tile = [NSMutableDictionary dictionary];
	UIImage *image = [self imageForItem:item storyKind:NO];
	if (image)
		tile[TGGridItemImage] = image;
	return tile;
}

- (NSDictionary *)giftTileForItem:(NSDictionary *)tile {
	NSMutableDictionary *item = [NSMutableDictionary dictionary];
	BOOL collectible = [tile[@"isCollectible"] boolValue];
	NSString *emoji = tile[@"emoji"];
	if ([emoji isKindOfClass:NSString.class] && emoji.length)
		item[TGGridItemEmoji] = emoji;
	NSNumber *thumbId = collectible ? tile[@"modelThumbFileId"]
			: tile[@"thumbFileId"];
	UIImage *image = [thumbId isKindOfClass:NSNumber.class]
			? self.mediaImages[thumbId] : nil;
	if (image)
		item[TGGridItemImage] = image;
	else if ([thumbId isKindOfClass:NSNumber.class])
		[self downloadMediaImage:thumbId];
	if (collectible)
		item[TGGridItemCaption] = [NSString stringWithFormat:@"#%ld",
				(long)[tile[@"number"] integerValue]];
	else {
		NSInteger stars = [tile[@"starCount"] integerValue];
		item[TGGridItemCaption] = TGLocalizedPluralValue(
				@"%@ Star", @"%@ Stars",
				[NSString stringWithFormat:@"%ld", (long)stars], stars);
	}
	return item;
}

/// The rows under the selected tab. Grids chunk their list into three tiles a
/// line; the list panes use the shared picture row, and groups are people.
- (NSArray *)mediaContentRows {
	NSString *kind = [self selectedMediaKind];
	NSArray *items = [self selectedMediaRows];
	if (!kind)
		return @[];

	if ([self selectedTabIsGrid]){
		__weak typeof(self) weakSelf = self;
		BOOL giftKind = [kind isEqualToString:@"gifts"];
		BOOL storyKind = TGKindIsStories(kind);
		NSArray *rows = TGProfileGridRowModels(items, 3,
				^NSDictionary *(NSInteger index){
			TGProfileViewController *me = weakSelf;
			if (giftKind)
				return [me giftTileForItem:items[(NSUInteger)index]];
			if (storyKind)
				return [me storyTileForItem:items[(NSUInteger)index]
						index:index];
			return [me photoTileForItem:items[(NSUInteger)index]];
		}, ^(NSInteger index){
			[weakSelf openMediaGridItemAtIndex:index kind:kind];
		});
		if (rows.count)
			return rows;
		// An answered empty pane says so rather than looking frozen.
		if (TGKindIsStories(kind) &&
				[self.loadedMediaKinds containsObject:kind]){
			BOOL archive = [kind isEqualToString:@"archive"];
			NSMutableArray *empty = [NSMutableArray array];
			NSMutableDictionary *line = [TGRow(TGKindPlain,
					archive ? TGLocalized(@"No Archived Stories")
							: TGLocalized(@"No posted stories")) mutableCopy];
			line[TGRowCentred] = @YES;
			[empty addObject:line];
			if (!archive && self.isOwnProfile)
				[empty addObject:TGActionRow(TGLocalized(@"Add Story"),
						^{ [weakSelf addStoryTapped]; })];
			return empty;
		}
		return @[];
	}

	NSMutableArray *rows = [NSMutableArray array];
	__weak typeof(self) weakSelf = self;
	for (NSUInteger index = 0; index < items.count; index++){
		NSDictionary *m = items[index];
		NSMutableDictionary *row = nil;
		if ([kind isEqualToString:@"files"]){
			NSString *name = [m[@"docName"] length] ? m[@"docName"]
					: TGLocalized(@"File");
			NSString *detail = TGProfileJoin(TGProfileFileSizeText(m[@"docSize"]),
					TGProfileShortDate(m[@"date"]));
			row = TGPictureRow(name, detail, ^{ [weakSelf openMediaRow:(NSInteger)index]; });
			row[TGRowRawTitle] = @YES;
			row[TGRowRawDetail] = @YES;
			row[TGRowPictureImage] = [TGIcons document];
		} else if ([kind isEqualToString:@"voice"]){
			BOOL videoNote = [m[@"kind"] isEqualToString:@"messageVideoNote"];
			NSString *detail = TGProfileJoin(TGProfileDurationText(m[@"duration"]),
					TGProfileShortDate(m[@"date"]));
			row = TGPictureRow(videoNote ? TGLocalized(@"Video message")
					: TGLocalized(@"Voice message"), detail,
					^{ [weakSelf openMediaRow:(NSInteger)index]; });
			row[TGRowRawTitle] = @YES;
			row[TGRowRawDetail] = @YES;
			if (videoNote){
				row[TGRowPictureGlyph] = @"video";
				row[TGRowPictureGlyphColour] = [[TGTheme shared] accentColour];
			} else {
				row[TGRowPictureImage] = [TGIcons microphone];
			}
			if (self.playingVoiceId == [m[@"id"] longLongValue])
				row[TGRowTitleColour] = [[TGTheme shared] accentColour];
		} else if ([kind isEqualToString:@"music"]){
			NSString *title = [m[@"audioTitle"] length] ? m[@"audioTitle"]
					: ([m[@"docName"] length] ? m[@"docName"]
							: TGLocalized(@"Audio"));
			NSString *artist = [m[@"audioPerformer"] length]
					? m[@"audioPerformer"] : TGLocalized(@"Unknown artist");
			row = TGPictureRow(title, artist, ^{ [weakSelf openMediaRow:(NSInteger)index]; });
			row[TGRowRawTitle] = @YES;
			row[TGRowRawDetail] = @YES;
			row[TGRowHeight] = @(TGMetricTrackRow);
			NSNumber *coverId = [m[@"albumCoverId"] isKindOfClass:NSNumber.class]
					? m[@"albumCoverId"] : nil;
			UIImage *cover = coverId ? self.mediaImages[coverId] : nil;
			if (cover)
				row[TGRowPictureImage] = cover;
			else if (coverId)
				[self downloadMediaImage:coverId];
			else {
				row[TGRowPictureGlyph] = @"music";
				row[TGRowPictureGlyphColour] = [[TGTheme shared] secondaryTextColour];
			}
			NSString *duration = TGProfileDurationText(m[@"duration"]);
			if (duration.length)
				row[TGRowAccessory] = duration;
			TGMusicPlayer *player = [TGMusicPlayer shared];
			if (player.currentMessageId == [m[@"id"] longLongValue])
				row[TGRowTitleColour] = [[TGTheme shared] accentColour];
		} else if ([kind isEqualToString:@"links"]){
			NSString *domain = [self linkDomainForMessage:m];
			NSString *date = TGProfileShortDate(m[@"date"]);
			BOOL bare = !domain.length || [m[@"text"] hasPrefix:domain] ||
					[m[@"text"] hasPrefix:@"http"];
			NSString *title = bare ? (domain.length ? domain
					: TGLocalized(@"Link")) : m[@"text"];
			NSString *detail = bare || !date.length
					? (bare ? date : domain)
					: TGProfileJoin(domain, date);
			row = TGPictureRow(title, detail, ^{ [weakSelf openMediaRow:(NSInteger)index]; });
			row[TGRowRawTitle] = @YES;
			row[TGRowRawDetail] = @YES;
			row[TGRowPictureGlyph] = @"forward";
			row[TGRowPictureGlyphColour] = [[TGTheme shared] secondaryTextColour];
		} else if ([kind isEqualToString:@"groups"]){
			int64_t chatId = [m[@"chatId"] longLongValue];
			row = TGPeerRow(@(chatId), m[@"title"] ?: TGLocalized(@"Group"), nil,
					^{ [weakSelf openMediaRow:(NSInteger)index]; });
			row[TGRowAccessory] = TGRowAccessoryDisclosure;
		} else if ([kind isEqualToString:@"similar"]){
			int64_t chatId = [m[@"id"] longLongValue];
			NSInteger members = [m[@"members"] integerValue];
			NSString *detail = members > 0
					? TGLocalizedPlural(@"%d subscriber", @"%d subscribers",
							members)
					: TGLocalized(@"Channel");
			row = TGPeerRow(@(chatId), m[@"title"] ?: TGLocalized(@"Channel"),
					detail, ^{ [weakSelf openMediaRow:(NSInteger)index]; });
			row[TGRowAccessory] = TGRowAccessoryDisclosure;
		}
		if (row)
			[rows addObject:row];
	}
	if (!rows.count && TGKindIsStories(kind) &&
			[self.loadedMediaKinds containsObject:kind]){
		NSMutableDictionary *line = [TGRow(TGKindPlain,
				[kind isEqualToString:@"archive"] ? TGLocalized(@"No Archived Stories")
						: TGLocalized(@"No posted stories")) mutableCopy];
		line[TGRowCentred] = @YES;
		[rows addObject:line];
	}
	return rows;
}

- (void)openMediaGridItemAtIndex:(NSInteger)index kind:(NSString *)kind {
	NSArray *rows = [self selectedMediaRows];
	if (index < 0 || index >= (NSInteger)rows.count)
		return;
	if (TGKindIsStories(kind)){
		[self openStoryAtIndex:index];
		return;
	}
	if ([kind isEqualToString:@"gifts"]){
		TGGiftViewController *vc = [[TGGiftViewController alloc]
				initWithGift:rows[(NSUInteger)index]];
		vc.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:vc animated:YES];
		return;
	}
	[TGMediaViewer presentItems:rows startAt:index inChat:self.chatId];
}

- (NSString *)linkDomainForMessage:(NSDictionary *)message {
	return TGProfileFirstURL(message[@"text"], message[@"entities"]).host.lowercaseString;
}

- (void)handleStoryHoldAtIndex:(NSInteger)index {
	NSArray *rows = [self selectedMediaRows];
	if (index < 0 || index >= (NSInteger)rows.count)
		return;
	NSDictionary *story = rows[(NSUInteger)index];
	BOOL posted = [story[@"isPostedToChatPage"] boolValue];
	NSMutableArray *choices = [NSMutableArray array];
	if ([story[@"canToggleIsPostedToChatPage"] boolValue])
		[choices addObject:(posted ? TGLocalized(@"Remove from Profile")
				: TGLocalized(@"Add to Profile"))];
	if ([story[@"canBeDeleted"] boolValue])
		[choices addObject:TGLocalized(@"Delete Story")];
	if (!choices.count)
		return;
	NSInteger deleteIndex = [choices indexOfObject:TGLocalized(@"Delete Story")];
	NSInteger destructiveIndex = (deleteIndex != NSNotFound) ? (NSInteger)deleteIndex
			: (posted ? 0 : -1);
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices
						title:nil destructiveIndex:destructiveIndex inView:self.view
					 onChoice:^(NSInteger choice){
		if (choice < 0 || choice >= (NSInteger)choices.count)
			return;
		NSString *picked = choices[(NSUInteger)choice];
		if ([picked isEqualToString:TGLocalized(@"Delete Story")]){
			[[TGProfileStore shared] deleteStory:[story[@"storyId"] intValue]
								  fromChat:weakSelf.chatId
								completion:^(BOOL ok, NSString *error){
				TGProfileViewController *me = weakSelf;
				if (!me) return;
				if (!ok){
					[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
										title:TGLocalized(@"Delete Story") inView:me.view];
					return;
				}
				[me reloadOwnStories];
			}];
		} else {
			[[TGProfileStore shared] toggleStory:(int32_t)[story[@"storyId"] intValue]
								  fromChat:weakSelf.chatId
						  postedToChatPage:!posted
								completion:^(BOOL ok, NSString *error){
				TGProfileViewController *me = weakSelf;
				if (!me) return;
				if (!ok){
					[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
										title:TGLocalized(@"Stories") inView:me.view];
					return;
				}
				[me reloadOwnStories];
			}];
		}
	}];
}

- (void)reloadOwnStories {
	if (!self.isOwnProfile)
		return;
	for (NSString *kind in @[@"stories", @"archive"]){
		[self.loadedMediaKinds removeObject:kind];
		[self fetchMediaForKind:kind];
	}
}

- (void)openStoryAtIndex:(NSInteger)index {
	NSArray *rows = [self selectedMediaRows];
	if (index < 0 || index >= (NSInteger)rows.count)
		return;
	TGStoryViewerViewController *viewer = [[TGStoryViewerViewController alloc]
			initWithChatId:self.chatId
					 title:self.title ?: TGLocalized(@"Stories")
				   stories:rows
				startIndex:index
				 canManage:self.chatId == [[TGProfileStore shared] savedMessagesChatId]];
	UINavigationController *nav = [[UINavigationController alloc]
			initWithRootViewController:viewer];
	nav.navigationBar.barStyle = UIBarStyleBlack;
	nav.navigationBar.translucent = YES;
	[self presentViewController:nav animated:YES completion:nil];
}

- (void)loadMoreMediaForCurrentTab {
	if (self.isLoadingMoreMedia) return;
	NSString *kind = [self selectedMediaKind];
	if ([kind isEqualToString:@"gifts"]) {
		if (!self.giftsNextOffset.length)
			return;
		NSDictionary *owner = [self giftOwnerSenderId];
		if (!owner)
			return;
		self.isLoadingMoreMedia = YES;
		__weak typeof(self) weakProfile = self;
		[[TGProfileStore shared] giftsForOwner:owner offset:self.giftsNextOffset completion:^(NSArray *more, NSString *nextOffset, NSInteger totalCount){
			dispatch_async(dispatch_get_main_queue(), ^{
				TGProfileViewController *me = weakProfile;
				if (!me) return;
				me.isLoadingMoreMedia = NO;
				me.giftsNextOffset = nextOffset;
				if (totalCount > 0)
					me.mediaCounts[@"gifts"] = @(totalCount);
				if (more.count) {
					NSMutableArray *combined = [NSMutableArray arrayWithArray:me.gifts ?: @[]];
					[combined addObjectsFromArray:more];
					me.gifts = combined;
					[me reloadTableDebounced];
				}
			});
		}];
		return;
	}

	NSString *filter = nil;
	NSArray *currentList = nil;
	if ([kind isEqualToString:@"media"]) {
		filter = @"searchMessagesFilterPhotoAndVideo";
		currentList = self.photos;
	} else if ([kind isEqualToString:@"files"]) {
		filter = @"searchMessagesFilterDocument";
		currentList = self.files;
	} else if ([kind isEqualToString:@"music"]) {
		filter = @"searchMessagesFilterAudio";
		currentList = self.music;
	} else if ([kind isEqualToString:@"voice"]) {
		filter = @"searchMessagesFilterVoiceAndVideoNote";
		currentList = self.voice;
	} else if ([kind isEqualToString:@"links"]) {
		filter = @"searchMessagesFilterUrl";
		currentList = self.links;
	}
	if (!filter || !currentList.count) return;
	int64_t lastId = [currentList.lastObject[@"id"] longLongValue];
	if (!lastId) return;
	self.isLoadingMoreMedia = YES;
	__weak typeof(self) weakProfile = self;
	[[TGProfileStore shared] mediaInChat:self.chatId filter:filter fromMessageId:lastId limit:60 completion:^(NSArray *more){
		dispatch_async(dispatch_get_main_queue(), ^{
			TGProfileViewController *me = weakProfile;
			if (!me) return;
			me.isLoadingMoreMedia = NO;
			if (!more.count) return;
			if ([kind isEqualToString:@"media"])
				me.photos = TGMediaPageAppending(me.photos, more);
			else if ([kind isEqualToString:@"files"])
				me.files = TGMediaPageAppending(me.files, more);
			else if ([kind isEqualToString:@"music"])
				me.music = TGMediaPageAppending(me.music, more);
			else if ([kind isEqualToString:@"voice"])
				me.voice = TGMediaPageAppending(me.voice, more);
			else if ([kind isEqualToString:@"links"])
				me.links = TGMediaPageAppending(me.links, more);
			[me reloadTableDebounced];
		});
	}];
}

@end
