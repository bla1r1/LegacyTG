#import "TGCustomEmojiStore.h"
#import "TGLocalization.h"
#import "TGNameWithStatus.h"
#import "TGChatListViewControllerInternal.h"
#import "TGPerf.h"
#import "TGStatusText.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGMemberAvatarStore.h"
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



static dispatch_semaphore_t TGAvtDecodeGate(NSInteger cap) {
	static dispatch_semaphore_t gate = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		gate = dispatch_semaphore_create((long)cap);
	});
	return gate;
}

@implementation TGChatListViewController (TGChatListTable)

#pragma mark - table data
- (void)fetchMissingAvatars {
	// Wait until live chats from TDLib arrive: snapshot rows must not query
	// file IDs from a prior session.
	if (![TGClient shared].chats.count && self.cachedChats.count)
		return;

	__weak typeof(self) weakSelf = self;
	CGFloat screenScale = [UIScreen mainScreen].scale;
	dispatch_semaphore_t gate = TGAvtDecodeGate(2);
	// What is on screen and a screenful ahead, not the whole list: 176 downloads
	// and decodes at launch on the A4 paid for rows nobody had looked at yet.
	// The next stop of the scroll asks for what it reached.
	NSArray *chats = self.chats ?: @[];
	NSInteger first = [[self.tableView indexPathsForVisibleRows] firstObject]
			? [[[self.tableView indexPathsForVisibleRows] firstObject] row] : 0;
	NSRange window = TGAvatarWindow(first, kAvatarWindowRows, chats.count);
	NSMutableArray *rows = [NSMutableArray arrayWithArray:[chats subarrayWithRange:window]];
	[rows addObjectsFromArray:self.storyRows ?: @[]];
	NSNumber *ownPhoto = [TGClient shared].me[@"profile_photo"][@"small"][@"id"]
			?: [[TGClient shared] photoFileIdForUserId:
					[[TGClient shared].me[@"id"] longLongValue]];
	if (ownPhoto)
		[rows addObject:@{@"photoFileId" : ownPhoto}];
	for (NSDictionary *c in rows){
		NSNumber *fileId = c[@"photoFileId"];
		if (!fileId || fileId.longLongValue < 0 || self.avatars[fileId] || [self.avatarsRequested containsObject:fileId])
			continue;
		// The mark follows the request from start to finish: set here, and
		// lifted on a nil callback, so a watchdog timeout or a lost download
		// reads as "ask me again on the next pass" instead of leaving the
		// avatar a placeholder forever (B2).
		[self.avatarsRequested addObject:fileId];

		[[TGClient shared] downloadFile:[fileId integerValue]
							   priority:TGDownloadPriorityAvatar
							 completion:^(NSString *path){
			if (!path){
				TGChatListViewController *me = weakSelf;
				[me.avatarsRequested removeObject:fileId];
				return;
			}
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
				// The gate is taken inside the block, not before: an entry
				// slot costs the wait, and the semaphore release happens in
				// the same block that took it.
				dispatch_semaphore_wait(gate, DISPATCH_TIME_FOREVER);
				@autoreleasepool {
					UIImage *img = [TGIcons decodedImageAtPath:path
												   fittingSize:CGSizeMake(kAvatar, kAvatar)
														  fill:YES
														 scale:screenScale];
					if (img){
						UIImage *rounded = [TGIcons roundedImage:img
														    size:CGSizeMake(kAvatar, kAvatar)
														  radius:TGHalf(kAvatar)
														 corners:UIRectCornerAllCorners];
						dispatch_async(dispatch_get_main_queue(), ^{
							TGChatListViewController *me = weakSelf;
							if (!me) { dispatch_semaphore_signal(gate); return; }
							me.avatars[fileId] = rounded ?: img;
							[me.avatarsRequested removeObject:fileId];
							[me refreshListTitleView];
							[me reloadTableDebounced];
							dispatch_semaphore_signal(gate);
						});
						return;
					}
					dispatch_async(dispatch_get_main_queue(), ^{
						[weakSelf.avatarsRequested removeObject:fileId];
					});
					dispatch_semaphore_signal(gate);
				}
			});
		}];
	}
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
- (void)configureStoriesCell:(TGStoriesCell *)strip {
	NSMutableArray *display = [NSMutableArray array];
	NSDictionary *own = nil;
	for (NSDictionary *row in self.storyRows){
		if ([row[@"isOwn"] boolValue]){
			own = row;
			continue;
		}
		NSMutableDictionary *copy = [row mutableCopy];
		NSNumber *fileId = row[@"photoFileId"];
		if (fileId && self.avatars[fileId])
			copy[@"avatarImage"] = self.avatars[fileId];
		[display addObject:copy];
	}
	int64_t myId = [[TGClient shared].me[@"id"] longLongValue];
	NSMutableDictionary *mine = [own mutableCopy] ?: [NSMutableDictionary dictionary];
	mine[@"title"] = @"My Story";
	mine[@"isOwn"] = @YES;
	mine[@"userId"] = @(myId);
	if (!mine[@"chatId"])
		mine[@"chatId"] = @([[TGClient shared] savedMessagesChatId] ?: myId);
	NSNumber *ownPhoto = [TGClient shared].me[@"profile_photo"][@"small"][@"id"]
			?: [[TGClient shared] photoFileIdForUserId:myId]
			?: mine[@"photoFileId"];
	if (ownPhoto)
		mine[@"photoFileId"] = ownPhoto;
	if (ownPhoto && self.avatars[ownPhoto])
		mine[@"avatarImage"] = self.avatars[ownPhoto];
	strip.stories = display;
	strip.ownStory = mine;
	__weak typeof(self) weakSelf = self;
	strip.onAddStory = ^{ [weakSelf openStoryComposer]; };
	strip.onMore = ^{ [weakSelf openStoriesMenu]; };
	strip.onMyStoryTapped = ^{
		TGChatListViewController *me = weakSelf;
		if (!me) return;
		if ([own[@"stories"] count])
			[me showStoryRow:own];
		else
			[me openStoryComposer];
	};
	strip.onMyStoryHeld = ^{ [weakSelf openStoriesMenu]; };
	strip.onStoryTapped = ^(NSDictionary *row){ [weakSelf showStoryRow:row]; };
	strip.onStoryHeld = ^(NSDictionary *row){ [weakSelf runStoryRowMenu:row]; };
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
	static NSString *reuse = @"TGChatCell";
	TGChatCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGChatCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];

	TGTheme *theme = [TGTheme shared];
	UIColor *bg = [theme listBackgroundColour];
	cell.backgroundColor = bg;
	cell.contentView.backgroundColor = bg;
	cell.titleLabel.backgroundColor = bg;
	cell.titleLabel.opaque = YES;
	cell.titleLabel.textColor = [theme primaryTextColour];
	cell.previewLabel.backgroundColor = bg;
	cell.previewLabel.opaque = YES;
	cell.previewLabel.textColor = [theme secondaryTextColour];
	cell.dateLabel.backgroundColor = bg;
	cell.dateLabel.opaque = YES;
	cell.dateLabel.textColor = [theme listDateColour];
	cell.onlineDot.hidden = YES;
	cell.tick.hidden = YES;
	cell.muteIcon.hidden = YES;
	cell.pin.hidden = YES;
	cell.onlineDot.layer.borderColor = bg.CGColor;
	cell.separator.backgroundColor = [theme separatorColour];


	NSArray *header = [self headerRows];
	if (indexPath.row < (NSInteger)header.count){

		BOOL isArchive = [header[indexPath.row] isEqualToString:@"archive"];
		cell.titleLabel.text = isArchive ? TGLocalized(@"Archived Chats") : TGLocalized(@"Saved Messages");
		NSUInteger archived = [TGClient shared].archivedChats.count;
		cell.previewLabel.text = isArchive
				? TGChatListArchiveSubtitle(archived)
				: @"Your own notes and forwards";
		cell.dateLabel.text = @"";
		cell.badge.hidden = YES;
		// A cell reused from a chat with unseen mentions kept its "@" on the
		// archive row; the early return never cleared it.
		cell.mentionBadge.hidden = YES;
		cell.pin.hidden = YES;
		cell.avatar.image = isArchive
				? [TGIcons archiveAvatarOfSide:kAvatar]
				: [TGIcons savedMessagesAvatarOfSide:kAvatar];
		cell.avatar.backgroundColor = [UIColor clearColor];
		[cell setNeedsLayout];
		return cell;
	}

	NSDictionary *c = [self visibleChats][indexPath.row - header.count];
	double cellStart = TGPerfNow();
	int64_t statusId = [c[@"isSaved"] boolValue] ? 0 : [c[@"emojiStatusId"] longLongValue];
	cell.titleLabel.attributedText = TGNameWithStatus(c[@"title"] ?: @"", statusId, cell.titleLabel.font, [theme primaryTextColour]);
	cell.statusIcon.image = nil;
	cell.statusIcon.hidden = YES;
	cell.dateLabel.text = TGChatDate([c[@"date"] doubleValue]);

	// Someone typing takes the preview over for as long as it lasts, in their
	// blurple rather than the grey the preview uses.
	NSString *action = c[@"action"];
	NSString *draft = c[@"draft"];
	if ([action length]){
		cell.previewLabel.text = action;
		cell.previewLabel.textColor = [theme typingColour];
	} else if ([draft length]){
		[cell setDraftPreview:draft];
	} else if (c[@"previewText"]){
		[cell setPreview:c[@"previewText"] author:c[@"lastAuthor"] customEmoji:c[@"previewCustomEmoji"]];
	} else if (c[@"text"]){
		[cell setPreview:c[@"text"] author:nil customEmoji:c[@"previewCustomEmoji"]];
	} else {
		cell.previewLabel.text = @"";
	}

	cell.onlineDot.hidden = ![c[@"isOnline"] boolValue];

	// Your own last message shows whether it has been read, beside the date.
	// Saved Messages has no one to read it.
	if ([c[@"lastOutgoing"] boolValue] && ![c[@"isSaved"] boolValue] && ![action length]){
		BOOL read = [c[@"lastId"] longLongValue] <= [c[@"readOutbox"] longLongValue];
		cell.tick.image = [TGIcons ticksColour:[theme ticksColour] read:read];
		cell.tick.hidden = NO;
	}

	[cell setNeedsLayout];

	BOOL muted = [c[@"isMuted"] boolValue];
	cell.muteIcon.hidden = !muted;
	if (muted)
		cell.muteIcon.image = [TGIcons glyphNamed:@"mute" colour:[theme listDateColour]
											 side:kRowGlyph];

	NSInteger unread = [c[@"unread"] integerValue];
	NSInteger mentions = [c[@"unreadMentions"] integerValue];
	cell.mentionBadge.hidden = (mentions <= 0);

	BOOL marked = [c[@"markedUnread"] boolValue];
	BOOL anyBadge = unread > 0 || marked;
	cell.badge.hidden = !anyBadge;
	// The unread count occupies the badge slot; the pin only shows when that
	// slot is free.
	cell.pin.hidden = anyBadge || ![c[@"isPinned"] boolValue];
	if (!cell.pin.hidden)
		cell.pin.image = [TGIcons glyphNamed:@"pin" colour:[theme listDateColour]
									  side:kRowGlyph];
	cell.badge.text = unread > 0 ? (unread > 9999 ? @"9999+" : [NSString stringWithFormat:@"%ld", (long)unread]) : @"";
	// A muted chat still counts, it just stops shouting about it.
	cell.badge.backgroundColor = [c[@"isMuted"] boolValue]
			? [theme mutedBadgeColour] : [theme badgeColour];

	NSNumber *fileId = c[@"photoFileId"];
	UIImage *photo = fileId ? self.avatars[fileId] : nil;
	int64_t cid = [c[@"id"] longLongValue];
	if ([c[@"isSaved"] boolValue])
		photo = [TGIcons savedMessagesAvatarOfSide:kAvatar];
	if (!photo){
		NSString *title = c[@"title"] ?: @"";
		NSString *initials = [TGIcons initialsForTitle:title];
		photo = [TGIcons avatarWithInitials:initials
									   size:kAvatar
								   colourId:[c[@"id"] longLongValue]];
	}
	cell.avatar.image = photo;
	cell.avatar.opaque = NO;
	cell.avatar.backgroundColor = [UIColor clearColor];

	[cell setNeedsLayout];
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
