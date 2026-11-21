#import "TGAppActivity.h"
#import "TGCustomEmojiStore.h"
#import "TGLocalization.h"
#import "TGNameWithStatus.h"
#import "TGChatListViewControllerInternal.h"
#import "TGPerf.h"
#import "TGStatusText.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGPeerStore.h"
#import "TGDateFormat.h"
#import "TGOptions.h"
#import "TGStoryViewerViewController.h"
#import "TGStoryComposerViewController.h"
#import "TGProfileViewController.h"
#import "TGPasscode.h"
#import "TGPasscodeViewController.h"
#import "TGChatListRowGeometry.h"
#import "TGUIFormat.h"
#import "TGRowCell.h"
#import "TGRows.h"


// Height of the folder pill strip above the chat list (official-style tabs).




@implementation TGChatListViewController (TGChatListTable)

#pragma mark - table data
/// Pictures are loaded by TGPeerStore as rows ask for them; there is no
/// separate window pass to keep in step with the table any more.
- (void)fetchMissingAvatars {
}

/// Today shows the time, this week the weekday, older the date - as clients do.
static NSString *TGChatDate(NSTimeInterval unix) {
	return TGUIFormatChatDate(unix, TGOptionNow());
}

/// Saved Messages has a row of its own above the list, so leaving it among the
/// chats as well would show it twice.
- (NSArray *)visibleChats {
	if (self.searchResults)
		return self.searchResults;

	NSMutableArray *chats = [NSMutableArray array];

	BOOL hideSaved = [[self headerRows] containsObject:@"saved"];
	int64_t saved = hideSaved ? [[TGChatListStore shared] savedMessagesChatId] : 0;
	for (NSDictionary *c in self.chats){
		int64_t chatId = [c[@"id"] longLongValue];
		if (chatId == saved || chatId == self.chatPendingDeletion)
			continue;
		[chats addObject:c];
	}
	return chats;
}

/// Fills the strip whether it is the header's expanded row or a table cell.
- (void)configureStoriesCell:(TGStoryStripRowCell *)strip {
	NSMutableArray *display = [NSMutableArray array];
	NSDictionary *own = nil;
	for (NSDictionary *row in self.storyRows){
		if ([row[@"isOwn"] boolValue]){
			own = row;
			continue;
		}
		NSMutableDictionary *copy = [row mutableCopy];
		int64_t peerId = [row[@"chatId"] longLongValue];
		UIImage *picture = peerId
				? [[TGPeerStore shared] cachedAvatarForPeer:peerId
													   side:TGMetricStoryAvatar]
				: nil;
		if (picture)
			copy[@"avatarImage"] = picture;
		[display addObject:copy];
	}
	int64_t myId = [[TGChatListStore shared].me[@"id"] longLongValue];
	NSMutableDictionary *mine = [own mutableCopy] ?: [NSMutableDictionary dictionary];
	mine[@"title"] = TGLocalized(@"My Story");
	mine[@"isOwn"] = @YES;
	mine[@"userId"] = @(myId);
	if (!mine[@"chatId"])
		mine[@"chatId"] = @([[TGChatListStore shared] savedMessagesChatId] ?: myId);
	UIImage *ownPicture = myId
			? [[TGPeerStore shared] cachedAvatarForPeer:myId
												   side:TGMetricStoryAvatar]
			: nil;
	if (ownPicture)
		mine[@"avatarImage"] = ownPicture;

	NSMutableDictionary *stripRow = TGStoryStripRow(display, mine);
	__weak typeof(self) weakSelf = self;
	stripRow[TGRowStoryAdd] = ^{ [weakSelf openStoryComposer]; };
	stripRow[TGRowStoryMore] = ^{ [weakSelf openStoriesMenu]; };
	stripRow[TGRowStoryMyTap] = ^{
		TGChatListViewController *me = weakSelf;
		if (!me) return;
		if ([own[@"stories"] count])
			[me showStoryRow:own];
		else
			[me openStoryComposer];
	};
	stripRow[TGRowStoryMyHold] = ^{ [weakSelf openStoriesMenu]; };
	stripRow[TGRowStoryTap] = ^(NSDictionary *row){ [weakSelf showStoryRow:row]; };
	stripRow[TGRowStoryHold] = ^(NSDictionary *row){ [weakSelf runStoryRowMenu:row]; };
	[strip configureWithRow:stripRow];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *header = self.searchResults ? nil : [self headerRows];
	if (indexPath.row < (NSInteger)header.count && [header[indexPath.row] isEqualToString:@"notice"])
		return [TGRowCell heightForRow:[self noticeRow] inTableView:tableView];
	return kRowHeight;
}

/// The notice as a shared row: title, the official sentence under it, and a
/// close glyph when official lets it be dismissed.
- (NSDictionary *)noticeRow {
	NSDictionary *notice = TGChatListNotice([TGChatListStore shared].suggestedActions);
	if (!notice)
		return TGSubtitleRow(@"", @"", nil);
	NSDictionary *action = notice[@"action"];
	NSMutableDictionary *row = [([notice[@"closable"] boolValue]
			? TGButtonRow(notice[@"title"], notice[@"text"], nil, ^{
				[[TGChatListStore shared] hideSuggestedAction:action];
			}, nil)
			: TGSubtitleRow(notice[@"title"], notice[@"text"], nil)) mutableCopy];
	if ([notice[@"closable"] boolValue])
		row[TGRowAccessoryImage] = [TGIcons glyphNamed:@"close"
				colour:[[TGTheme shared] secondaryTextColour] side:TGMetricMenuGlyph];
	// Official wraps the sentence in grey; it is not a link.
	row[TGRowDetailLines] = @3;
	row[TGRowDetailColour] = [[TGTheme shared] secondaryTextColour];
	// The shared cell sizes one line of detail; this one wraps, so the row
	// is measured here: a bold title line over the subhead-sized sentence,
	// as the subtitle cell draws them.
	CGFloat width = self.tableView.bounds.size.width - TGDoubled(TGMetricPadLarge)
			- ([notice[@"closable"] boolValue] ? TGMetricMenuGlyph + TGMetricPadLarge : TGMetricZero);
	CGFloat detail = [notice[@"text"] sizeWithFont:TGFontSubhead()
			constrainedToSize:CGSizeMake(width, CGFLOAT_MAX)
			lineBreakMode:NSLineBreakByWordWrapping].height;
	row[TGRowHeight] = @(ceilf(TGFontBodyStrong().lineHeight + detail) + TGDoubled(TGMetricPadMedium));
	return row;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (self.searchResults)
		return self.searchResults.count;
	return [self visibleChats].count + [self headerRows].count;
}

- (void)reloadVisibleRows {
	// Off screen (a chat pushed over the list) every status update rebuilt the
	// rows nobody sees: ~2% of the main thread in a chat scroll on the iPod
	// touch 4. The list catches up once in viewWillAppear.
	if (!self.isViewLoaded || !self.view.window || TGAppInBackground()) {
		self.visibleRowsStale = YES;
		return;
	}
	NSArray *visible = [self.tableView indexPathsForVisibleRows];
	if (visible.count)
		[self.tableView reloadRowsAtIndexPaths:visible
							  withRowAnimation:UITableViewRowAnimationNone];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *header = [self headerRows];
	if (indexPath.row < (NSInteger)header.count && [header[indexPath.row] isEqualToString:@"notice"])
		return [TGRowCell cellForTableView:tableView row:[self noticeRow] rowIndex:0 totalRows:1];
	if (indexPath.row < (NSInteger)header.count){
		BOOL isArchive = [header[indexPath.row] isEqualToString:@"archive"];
		NSUInteger archived = [TGChatListStore shared].archivedChats.count;
		NSMutableDictionary *row = isArchive
				? TGArchiveChatRow(TGLocalized(@"Archived Chats"),
						TGChatListArchiveSubtitle(archived))
				: TGSavedMessagesChatRow(TGLocalized(@"Saved Messages"),
						TGLocalized(@"Your own notes and forwards"));
		return [TGChatRowCell cellForTableView:tableView row:row];
	}

	NSDictionary *c = [self visibleChats][indexPath.row - header.count];
	double cellStart = TGPerfNow();
	NSMutableDictionary *row = TGChatRow(c, TGChatDate([c[@"date"] doubleValue]));

	int64_t cid = [c[@"id"] longLongValue];
	BOOL saved = [c[@"isSaved"] boolValue];
	// TDLib names the chat "Saved Messages" in English; the pack has it.
	if (saved)
		row[TGRowTitle] = TGLocalized(@"Saved Messages");
	UIImage *cached = saved ? nil : [[TGPeerStore shared] cachedAvatarForPeer:cid side:kAvatar];
	UIImage *photo = saved ? [TGIcons savedMessagesAvatarOfSide:kAvatar] : cached;
	if (!photo){
		NSString *title = c[@"title"] ?: @"";
		NSString *initials = [TGIcons initialsForTitle:title];
		photo = [TGIcons avatarWithInitials:initials
									   size:kAvatar
								   colourId:cid];
	}
	row[TGRowChatAvatarImage] = photo;
	// A cached avatar answers loadAvatarForPeer at once, and the reload it
	// asked for drew this cell again: reloadData about 12 times a second for
	// as long as the list was on screen.
	if (TGChatListNeedsAvatarLoad(saved, cid, cached != nil)){
		__weak typeof(self) weakSelf = self;
		[[TGPeerStore shared] loadAvatarForPeer:cid side:kAvatar
									completion:^(UIImage *image){
			if (image)
				[weakSelf reloadTableDebounced];
		}];
	}

	row[TGRowChatLayout] = [TGChatRowCell accessoriesValueForRow:row
														   width:tableView.bounds.size.width];
	UITableViewCell *cell = [TGChatRowCell cellForTableView:tableView row:row];
	TGPerfReport("list cell", [c[@"title"] UTF8String] ?: "", cellStart, 33.0);
	return cell;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!self.editingChats)
		return;
	[self refreshEditToolbar];
	[self refreshListTitleView];
}

/// Edit also reorders the pinned chats: only a pinned row gets the move
/// handle, and the result is written as Telegram's whole pinned list.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!self.editingChats)
		return NO;
	NSInteger index = indexPath.row - (NSInteger)[self headerRows].count;
	NSArray *chats = [self visibleChats];
	return index >= 0 && index < (NSInteger)chats.count &&
			[chats[(NSUInteger)index][@"isPinned"] boolValue];
}

- (void)tableView:(UITableView *)tableView
		moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
			  toIndexPath:(NSIndexPath *)destinationIndexPath {
	NSInteger header = [self headerRows].count;
	NSArray *chats = [self visibleChats];
	NSInteger from = sourceIndexPath.row - header;
	NSInteger to = destinationIndexPath.row - header;
	if (from < 0 || from >= (NSInteger)chats.count || to < 0)
		return;
	NSMutableArray *pinned = [NSMutableArray array];
	for (NSDictionary *chat in chats)
		if ([chat[@"isPinned"] boolValue])
			[pinned addObject:chat];
	if (to >= (NSInteger)chats.count)
		to = (NSInteger)chats.count - 1;
	NSInteger pinnedTo = 0;
	for (NSInteger i = 0; i <= to && i < (NSInteger)chats.count; i++)
		if ([chats[(NSUInteger)i][@"isPinned"] boolValue])
			pinnedTo++;
	NSInteger pinnedFrom = [pinned indexOfObjectIdenticalTo:chats[(NSUInteger)from]];
	if (pinnedFrom == NSNotFound)
		return;
	if (pinnedTo > pinnedFrom)
		pinnedTo--;
	if (pinnedTo < 0)
		pinnedTo = 0;
	if (pinnedTo >= (NSInteger)pinned.count)
		pinnedTo = (NSInteger)pinned.count - 1;
	if (pinnedFrom == pinnedTo)
		return;
	NSDictionary *moved = pinned[(NSUInteger)pinnedFrom];
	[pinned removeObjectAtIndex:(NSUInteger)pinnedFrom];
	[pinned insertObject:moved atIndex:(NSUInteger)pinnedTo];
	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *chat in pinned)
		[ids addObject:chat[@"id"]];
	[[TGChatListStore shared] setPinnedChatIds:ids];
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{ [weakSelf reload]; });
}


@end
