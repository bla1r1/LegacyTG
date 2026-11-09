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


// Height of the folder pill strip above the chat list (official-style tabs).
static const CGFloat kFolderTabRow = TGMetricFolderTabRow;
/// The mute and pin marks on a row are drawn at this side and then fitted into
/// the smaller box the cell gives them, which is what keeps their strokes even.
static const CGFloat kRowGlyph     = 28.0f;
/// The title view's box: the name, then the connection line under it. 200 pt
/// is the chat header's width on the same 320 pt bar, so neither nav button
/// loses its target to a long folder name.
static const CGFloat kListTitleWidth  = 150.0f;
static const CGFloat kListTitleHeight = TGMetricRow;
static const CGFloat kListChevronWidth = 12.0f;
static const CGFloat kListChevronGap   = TGMetricPadTiny;
static const CGFloat kListStorySide    = 24.0f;
static const CGFloat kListStoryGap     = TGMetricPadSmall;
/// The chat-list bar controls: the Edit pill, the circled add and the blue
/// compose button. Named here because only this header stacks them.
static const CGFloat kBarEditWidth    = 66.0f;
static const CGFloat kBarEditHeight   = TGMetricSegmentedHeight;
static const CGFloat kBarRightWidth   = 92.0f;
static const CGFloat kBarControlSide  = TGMetricButtonMediumH;
static const CGFloat kBarComposeSide  = 46.0f;
static const CGFloat kBarComposeX     = 46.0f;
static const CGFloat kBarControlTop   = 5.0f;
/// The archive pill's tag, outside the folder indexes (100 + slot).
static const NSInteger kFolderArchiveTag = 1000;
/// A folder pill's side padding, its widest form and the gap to the next pill.
static const CGFloat kFolderPillPad = 26.0f;
static const CGFloat kFolderPillMax = 150.0f;
static const CGFloat kFolderPillGap = 6.0f;

/// A 3.5" screen shows six rows of 76 pt; this is two screens.
static const NSUInteger kAvatarWindowRows = 14;

/// One pill's two states. The strip rebuilds on every switch, so the old and
/// new chosen pills are repainted here after the new header is on screen.
static void TGPaintFolderPill(UIButton *pill, BOOL active) {
	TGTheme *theme = [TGTheme shared];
	if (active){
		[pill setBackgroundColor:[theme accentColour]];
		[pill setTitleColor:[theme onAccentColour] forState:UIControlStateNormal];
		pill.layer.borderWidth = TGMetricBorderNone;
	} else {
		[pill setBackgroundColor:[theme cardBackgroundColour]];
		[pill setTitleColor:[theme primaryTextColour] forState:UIControlStateNormal];
		pill.layer.borderWidth = TGMetricHairline;
		pill.layer.borderColor = [theme separatorColour].CGColor;
	}
}


static NSString *TGChatSnapshotPath(void) {
	NSString *dir = [NSSearchPathForDirectoriesInDomains(
			NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	// The snapshot is one account's list. Slot 0 keeps the pre-accounts name
	// so an update does not discard the last list it saved; later slots get
	// their own file so switching never shows another account's rows.
	NSInteger slot = [TGClient activeAccountSlot];
	NSString *name = slot > 0
			? [NSString stringWithFormat:@"chat-list-snapshot-%ld.plist", (long)slot]
			: @"chat-list-snapshot.plist";
	return [dir stringByAppendingPathComponent:name];
}

/// Only primitive fields go to the plist. chatsById also holds TDLib records
/// (permissions, action bar, background) that are not plist values and are
/// not read by a list row.
static NSDictionary *TGChatSnapshotRow(NSDictionary *chat) {
	static NSArray *keys = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		keys = @[@"id", @"title", @"date", @"text", @"previewText", @"lastAuthor",
				@"unread", @"unreadMentions", @"markedUnread", @"isMuted",
				@"isPinned", @"isOnline", @"isSaved", @"lastId", @"lastOutgoing",
				@"readOutbox", @"readInbox", @"isGroup", @"isForum",
				@"isSecret", @"order", @"archiveOrder", @"supergroupId", @"draft",
				@"emojiStatusId"];
	});
	NSMutableDictionary *row = [NSMutableDictionary dictionaryWithCapacity:keys.count];
	for (NSString *key in keys){
		id value = chat[key];
		if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class])
			row[key] = value;
	}
	return row[@"id"] ? row : nil;
}



@implementation TGChatListViewController (TGChatListTable)

#pragma mark - table data
/// Pictures are loaded by TGPeerStore as rows ask for them; there is no
/// separate window pass to keep in step with the table any more.
- (void)fetchMissingAvatars {
}

/// Today shows the time, this week the weekday, older the date - as clients do.
static NSString *TGChatDate(NSTimeInterval unix) {
	char buf[TGDateFormatBufferSize];
	// The server's clock, not this device's: a 4S off by a year grades every
	// date as "today" until the option arrives.
	size_t len = TGChatDateFormat((time_t)unix, (time_t)TGOptionNow(), buf, sizeof(buf));
	if (!len)
		return @"";
	return [[NSString alloc] initWithBytes:buf length:len
								  encoding:NSASCIIStringEncoding];
}

/// Saved Messages has a row of its own above the list, so leaving it among the
/// chats as well would show it twice.
- (NSArray *)visibleChats {
	if (self.searchResults)
		return self.searchResults;

	NSMutableArray *chats = [NSMutableArray array];

	BOOL hideSaved = [[self headerRows] containsObject:@"saved"];
	int64_t saved = hideSaved ? [[TGClient shared] savedMessagesChatId] : 0;
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
	int64_t myId = [[TGClient shared].me[@"id"] longLongValue];
	NSMutableDictionary *mine = [own mutableCopy] ?: [NSMutableDictionary dictionary];
	mine[@"title"] = TGLocalized(@"My Story");
	mine[@"isOwn"] = @YES;
	mine[@"userId"] = @(myId);
	if (!mine[@"chatId"])
		mine[@"chatId"] = @([[TGClient shared] savedMessagesChatId] ?: myId);
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
	return kRowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (self.searchResults)
		return self.searchResults.count;
	return [self visibleChats].count + [self headerRows].count;
}

- (void)reloadVisibleRows {
	NSArray *visible = [self.tableView indexPathsForVisibleRows];
	if (visible.count)
		[self.tableView reloadRowsAtIndexPaths:visible
							  withRowAnimation:UITableViewRowAnimationNone];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *header = [self headerRows];
	if (indexPath.row < (NSInteger)header.count){
		BOOL isArchive = [header[indexPath.row] isEqualToString:@"archive"];
		NSUInteger archived = [TGClient shared].archivedChats.count;
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
	UIImage *photo = saved ? [TGIcons savedMessagesAvatarOfSide:kAvatar]
			: [[TGPeerStore shared] cachedAvatarForPeer:cid side:kAvatar];
	if (!photo){
		NSString *title = c[@"title"] ?: @"";
		NSString *initials = [TGIcons initialsForTitle:title];
		photo = [TGIcons avatarWithInitials:initials
									   size:kAvatar
								   colourId:cid];
	}
	row[TGRowChatAvatarImage] = photo;
	if (!saved && cid != 0){
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
	[[TGClient shared] setPinnedChatIds:ids];
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{ [weakSelf reload]; });
}


@end
