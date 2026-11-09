#import "TGCustomEmojiStore.h"
#import "TGLocalization.h"
#import "TGNameWithStatus.h"
#import "TGChatListViewControllerInternal.h"
#import "TGPerf.h"
#import "TGStatusText.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
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


/// The add-story control: the official story ring with a plus, from TGIconPaths.
static UIImage *TGAddStoryIcon(CGFloat side, UIColor *colour) {
	return [TGIcons glyphNamed:@"addStory" colour:colour side:side];
}

/// The lock in the title view: passcode users could lock the app from the
/// list before the bar item was removed.
UIImage *TGChatListLockIcon(CGFloat side, UIColor *colour) {
	return [TGIcons glyphNamed:@"lock" colour:colour side:side];
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



@implementation TGChatListViewController (TGChatListHeader)

#pragma mark - header and editing
- (NSDictionary *)collapsedStoryRow {
	for (NSDictionary *row in self.storyRows){
		if ([row[@"isOwn"] boolValue])
			continue;
		if ([row[@"stories"] count])
			return row;
	}
	return nil;
}

- (void)openCollapsedStory {
	if (![self collapsedStoryRow])
		return;
	self.storiesExpanded = YES;
	self.storiesFadePending = YES;
	[self rebuildTableHeader];
	[self.tableView reloadData];
}

/// Telegram's chat list bar: a pill-shaped Edit on the left, and on the right
/// the dashed add-story circle beside the blue compose button. Both are
/// custom views because the stock bar items cannot carry those shapes.
- (void)buildHeaderButtons {
	if (self.showsArchive || self.folderId != 0)
		return;

	UIBarButtonItem *edit = [[UIBarButtonItem alloc]
			initWithTitle:(self.editingChats ? TGLocalized(@"Done") : TGLocalized(@"Edit"))
					style:(self.editingChats ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain)
				   target:self
				   action:@selector(toggleChatListEditing)];
	self.navigationItem.leftBarButtonItems = @[edit];
	self.navigationItem.leftBarButtonItem = edit;

	if (self.editingChats) {
		self.navigationItem.rightBarButtonItems = nil;
		self.navigationItem.rightBarButtonItem = nil;
	} else {
		UIBarButtonItem *compose = [[UIBarButtonItem alloc]
				initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
									 target:self
									 action:@selector(composeTapped)];
		UIButton *storyButton = [UIButton buttonWithType:UIButtonTypeCustom];
		CGFloat side = TGMetricButtonMediumH;
		storyButton.frame = CGRectMake(0, 0, side, side);
		// Bar items take the bar-button role; the accent is the bar itself in
		// Classic, so the circle vanished into it.
		[storyButton setImage:TGAddStoryIcon(side, [[TGTheme shared] barButtonColour])
					 forState:UIControlStateNormal];
		[storyButton addTarget:self action:@selector(openStoryComposer)
			 forControlEvents:UIControlEventTouchUpInside];
		UIBarButtonItem *story = [[UIBarButtonItem alloc]
				initWithCustomView:storyButton];
		// The first right item sits at the edge; compose is the outermost.
		self.navigationItem.rightBarButtonItems = @[compose, story];
	}
}

- (void)lockAppTapped {
	[TGPasscode setLocked:YES];
	[TGPasscodeViewController presentUnlockIfLocked];
}

/// Telegram's Edit is multi-select, not a settings mode: check the chats,
/// then delete, archive or mute them together. The table's own editing mode
/// draws the checks; the toolbar carries the three verbs.
- (void)toggleChatListEditing {
	self.editingChats = !self.editingChats;
	self.tableView.allowsMultipleSelectionDuringEditing = YES;
	[self.tableView setEditing:self.editingChats animated:YES];
	[self buildHeaderButtons];
	// Done restores the list name (or the folder's); the count only belongs
	// while the edits are open, so the title is refreshed on both edges.
	[self refreshListTitleView];

	if (!self.editingChats){
		[self hideEditBarAnimated];
		return;
	}
	if (!self.editBar){
		CGFloat h = TGMetricRow;
		UIView *host = self.tabBarController.view ?: self.view;
		CGFloat bottom = host.bounds.size.height;
		if (self.tabBarController && !self.tabBarController.tabBar.hidden)
			bottom = CGRectGetMinY(self.tabBarController.tabBar.frame);
		self.editBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0,
				bottom - h, host.bounds.size.width, h)];
		self.editBar.autoresizingMask = UIViewAutoresizingFlexibleWidth |
				UIViewAutoresizingFlexibleTopMargin;
		[host addSubview:self.editBar];
		// Start below the tab bar, then slide up: the bar arriving in place
		// on one frame is the part that looked unfinished.
		self.editBar.transform = CGAffineTransformMakeTranslation(0, h);
	}
	// A bar that was already on screen is at identity, so this only moves
	// one that is arriving or reversing a hide that was still running.
	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		self.editBar.transform = CGAffineTransformIdentity;
	}];
	[self refreshEditToolbar];
}

/// Slide the toolbar under the tab bar. Edit can be turned back on while the
/// slide is running, in which case the bar must stay where the new press put
/// it rather than disappear with the old slide.
- (void)hideEditBarAnimated {
	UIToolbar *bar = self.editBar;
	if (!bar)
		return;
	CGFloat h = bar.bounds.size.height;
	__weak typeof(self) weakSelf = self;
	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		bar.transform = CGAffineTransformMakeTranslation(0, h);
	} completion:^(BOOL finished){
		TGChatListViewController *me = weakSelf;
		if (!me || me.editingChats || me.editBar != bar)
			return;
		[bar removeFromSuperview];
		me.editBar = nil;
	}];
}

/// The toolbar follows the selection: a selection reads Read, no selection
/// reads Read All. It never flips to Unread.
- (void)refreshEditToolbar {
	NSArray *selected = [self selectedChatIndexes];
	// Official's bar carries the three list-wide verbs; selecting a row is a
	// tap, not a mode, so All/None, Mute and Pin do not belong here. Read is
	// Read All or Read, never Unread: the toolbar has no mark-as-unread verb.
	NSString *readTitle = selected.count ? TGLocalized(@"Read")
			: TGLocalized(@"Read All");
	UIBarButtonItem *read = [[UIBarButtonItem alloc]
			initWithTitle:readTitle
					style:UIBarButtonItemStyleBordered target:self
				   action:@selector(readSelectedChats)];
	UIBarButtonItem *archive = [[UIBarButtonItem alloc]
			initWithTitle:TGLocalized(@"Archive")
					style:UIBarButtonItemStyleBordered
				   target:self action:@selector(archiveSelectedChats)];
	UIBarButtonItem *delete = [[UIBarButtonItem alloc]
			initWithTitle:TGLocalized(@"Delete")
					style:UIBarButtonItemStyleBordered
				   target:self action:@selector(deleteSelectedChats)];
	if (self.editBar)
		[self.editBar setItems:@[read, archive, delete] animated:NO];
}

- (void)readSelectedChats {
	NSArray *selected = [self selectedChatIndexes];
	if (!selected.count)
		selected = [self visibleChats];
	if (!selected.count)
		return;
	for (NSDictionary *chat in selected){
		int64_t chatId = [chat[@"id"] longLongValue];
		NSNumber *lastId = chat[@"lastId"];
		if ([lastId longLongValue])
			[[TGClient shared] markRead:@[lastId] inChat:chatId];
		else
			[[TGClient shared] setChat:chatId markedUnread:NO];
	}
	[self finishChatEditingAction];
}

- (NSArray *)selectedChatIndexes {
	NSMutableArray *ids = [NSMutableArray array];
	NSInteger header = [self headerRows].count;
	for (NSIndexPath *path in self.tableView.indexPathsForSelectedRows){
		if (path.row < header)
			continue;
		NSInteger index = path.row - header;
		NSArray *chats = [self visibleChats];
		if (index >= 0 && index < (NSInteger)chats.count)
			[ids addObject:chats[(NSUInteger)index]];
	}
	return ids;
}

- (void)finishChatEditingAction {
	self.editingChats = NO;
	[self.tableView setEditing:NO animated:YES];
	[self buildHeaderButtons];
	[self hideEditBarAnimated];
	[self reload];
}

- (void)deleteSelectedChats {
	NSArray *selected = [self selectedChatIndexes];
	if (!selected.count)
		return;
	__weak typeof(self) weakSelf = self;
	NSString *countText = [NSString stringWithFormat:@"%ld", (long)selected.count];
	NSString *confirm = TGLocalizedPluralValue(@"Delete %d Chat",
			@"Delete %@ Chats", countText, selected.count);
	[TGAlertSheet showConfirm:confirm
						title:@"Delete" action:@"Delete" destructive:YES
					   inView:self.view onConfirm:^{
		for (NSDictionary *chat in selected)
			[[TGClient shared] deleteChat:[chat[@"id"] longLongValue]];
		[weakSelf finishChatEditingAction];
	}];
}

- (void)archiveSelectedChats {
	for (NSDictionary *chat in [self selectedChatIndexes])
		[[TGClient shared] setChat:[chat[@"id"] longLongValue] archived:YES];
	[self finishChatEditingAction];
}
/// them: "All chats" first, then every folder, the active one filled with
/// the accent colour. Tapping one switches the list in place - no sheet,
/// no navigation.
- (void)buildFolderTabsInto:(UIView *)header atY:(CGFloat)y width:(CGFloat)width folders:(NSArray *)folders {
	UIScrollView *strip = [[UIScrollView alloc] initWithFrame:CGRectMake(0, y, width, kFolderTabRow)];
	strip.showsHorizontalScrollIndicator = NO;
	strip.alwaysBounceHorizontal = YES;
	strip.backgroundColor = [UIColor clearColor];
	[header addSubview:strip];

	UIFont *font = TGFontCaptionStrong();
	CGFloat x = 8;
	for (NSInteger i = 0; i <= (NSInteger)folders.count; i++){
		NSString *title = nil;
		if (i > 0)
			title = [folders[i - 1] isKindOfClass:NSDictionary.class]
					? folders[i - 1][@"title"] : nil;
		NSString *label = (i == 0) ? @"All" : nil;
		if (!label)
			label = [title isKindOfClass:NSString.class] && title.length
					? title : @"Folders";
		BOOL active = (i == 0 && self.folderId == 0) ||
				(i > 0 && [folders[i - 1] isKindOfClass:NSDictionary.class] &&
				 [folders[i - 1][@"id"] integerValue] == self.folderId);
		// The strip is rebuilt during a switch. Paint the pill that was
		// active with its old colour first, then fade it and the new active
		// pill to their new colours, so the highlight slides rather than
		// jumping from one pill to another in a single frame.
		BOOL shownActive = active;
		if (self.folderHighlightPending){
			shownActive = (i == 0 && self.folderHighlightPreviousId == 0) ||
					(i > 0 && [folders[i - 1] isKindOfClass:NSDictionary.class] &&
					 [folders[i - 1][@"id"] integerValue] ==
							self.folderHighlightPreviousId);
		}
		// Size the pill from the word it will show: setTitle: translates the
		// built-in names, so measuring the English "All" cut the Russian pill.
		// A folder's own title is the account's text, not ours, and stays raw.
		BOOL builtIn = (i == 0) || !title.length;
		NSString *shown = builtIn ? TGLocalized(label) : label;
		CGFloat w = MIN([shown sizeWithFont:font].width + kFolderPillPad, kFolderPillMax);
		UIButton *pill = [UIButton buttonWithType:UIButtonTypeCustom];
		// One expression for the height, used again for the radius below: a
		// capsule is half of whatever this comes to.
		CGFloat pillHeight = kFolderTabRow - TGDoubled(TGMetricFolderPillInset);
		pill.frame = CGRectMake(x, TGMetricFolderPillInset, w, pillHeight);
		pill.tag = 100 + i;
		[pill setTitle:shown forState:UIControlStateNormal];
		pill.titleLabel.font = font;
		pill.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
		pill.layer.cornerRadius = TGHalf(pillHeight);
		TGPaintFolderPill(pill, shownActive);
		[pill addTarget:self action:@selector(folderTabTapped:)
			  forControlEvents:UIControlEventTouchUpInside];
		if (i > 0){
			// A folder pill can be picked up and put elsewhere: held long
			// enough it follows the finger, and wherever it drops is the
			// order the strip keeps. "All chats" stays first - its slot is
			// what main_chat_list_position says, and the strip never moves.
			UILongPressGestureRecognizer *drag =
					[[UILongPressGestureRecognizer alloc]
					initWithTarget:self action:@selector(folderDragged:)];
			drag.minimumPressDuration = 0.45;
			[pill addGestureRecognizer:drag];
		}
		[strip addSubview:pill];
		x += w + kFolderPillGap;
	}

	// The archive is a list too, and the strip is where the folders are
	// switched; leaving it out meant a small account had no archive at all
	// until the list grew past the point that used to reveal the strip.
	if ([TGClient shared].archivedChats.count > 0){
		NSString *label = TGLocalized(@"Archived");
		CGFloat w = MIN([label sizeWithFont:font].width + kFolderPillPad, kFolderPillMax);
		UIButton *pill = [UIButton buttonWithType:UIButtonTypeCustom];
		CGFloat pillHeight = kFolderTabRow - TGDoubled(TGMetricFolderPillInset);
		pill.frame = CGRectMake(x, TGMetricFolderPillInset, w, pillHeight);
		pill.tag = kFolderArchiveTag;
		[pill setTitle:label forState:UIControlStateNormal];
		pill.titleLabel.font = font;
		pill.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
		pill.layer.cornerRadius = TGHalf(pillHeight);
		[pill setBackgroundColor:[[TGTheme shared] cardBackgroundColour]];
		[pill setTitleColor:[[TGTheme shared] primaryTextColour]
				   forState:UIControlStateNormal];
		pill.layer.borderWidth = TGMetricHairline;
		pill.layer.borderColor = [[TGTheme shared] separatorColour].CGColor;
		[pill addTarget:self action:@selector(folderTabTapped:)
			  forControlEvents:UIControlEventTouchUpInside];
		[strip addSubview:pill];
		x += w + kFolderPillGap;
	}

	strip.contentSize = CGSizeMake(x, kFolderTabRow);
}

/// The archive pill carries a tag outside the folder indexes, so it never
/// goes through runFolderChoice:; every other index is a regular switch.
- (void)folderTabTapped:(UIButton *)pill {
	if (pill.tag == kFolderArchiveTag){
		[self openArchive];
		return;
	}
	NSLog(@"TGClient: B3 pill tag=%ld folders=%lu", (long)pill.tag,
			(unsigned long)[TGClient shared].folders.count);
	NSInteger choice = pill.tag - 100;
	NSArray *folders = [TGClient shared].folders;
	NSInteger target = 0;
	if (choice > 0 && choice - 1 < (NSInteger)folders.count &&
			[folders[choice - 1] isKindOfClass:NSDictionary.class])
		target = [folders[choice - 1][@"id"] integerValue];
	if (target == self.folderId)
		return;
	// The strip is rebuilt during the choice, so remember which pill was lit
	// to let the old and new highlights trade places through one fade. The
	// list waits for its own answer: fading an empty table before a folder's
	// chats arrive would flash.
	self.folderHighlightPending = YES;
	self.folderHighlightPreviousId = self.folderId;
	self.folderListFadePending = YES;
	[self runFolderChoice:choice];
}

/// A held pill follows the finger; where it drops is its new slot among the
/// folders. The strip's own scrolling is pinned shut while a pill is up -
/// otherwise the pan gesture and the drag fight over one finger.
- (void)folderDragged:(UILongPressGestureRecognizer *)gesture {
	UIButton *pill = (UIButton *)gesture.view;
	UIScrollView *strip = (UIScrollView *)pill.superview;
	if (![strip isKindOfClass:UIScrollView.class] || pill.tag <= 100)
		return;

	if (gesture.state == UIGestureRecognizerStateBegan){
		CGPoint here = [gesture locationInView:pill];
		self.folderDragOffset = here.x - TGHalf(pill.bounds.size.width);
		self.folderDragFrame = pill.frame;
		strip.scrollEnabled = NO;
		pill.transform = CGAffineTransformMakeScale(TGTransformScalePillActive, TGTransformScalePillActive);
		pill.alpha = TGAlphaPillInactive;
	}
	else if (gesture.state == UIGestureRecognizerStateChanged){
		CGPoint here = [gesture locationInView:strip];
		// Content coordinates: a pill's frame lives where the strip scrolls
		// over, and the finger's x is in the visible half of it.
		CGFloat x_in_content = here.x - strip.contentOffset.x
				- self.folderDragOffset;
		CGFloat first = TGMetricPad, last = strip.contentSize.width
				- self.folderDragFrame.size.width - TGMetricPad;
		if (x_in_content < first) x_in_content = first;
		if (x_in_content > last)  x_in_content = last;
		pill.frame = CGRectMake(x_in_content, self.folderDragFrame.origin.y,
				self.folderDragFrame.size.width,
				self.folderDragFrame.size.height);
	}
	else if (gesture.state == UIGestureRecognizerStateEnded ||
			 gesture.state == UIGestureRecognizerStateCancelled){
		strip.scrollEnabled = YES;
		pill.transform = CGAffineTransformIdentity;
		pill.alpha = TGAlphaOpaque;

		BOOL cancelled = gesture.state == UIGestureRecognizerStateCancelled;
		if (cancelled){
			[self.tableView reloadData];   // back where the data says
			return;
		}

		// The slot is where the pill's centre sits among the other pills:
		// every centre it cleared on the way over counts as a slot ahead.
		NSArray *folders = [TGClient shared].folders;
		NSInteger from = pill.tag - 101;
		if (from < 0 || from >= (NSInteger)folders.count)
			return;
		CGPoint centreInStrip = [gesture locationInView:strip];
		CGFloat centre = centreInStrip.x - strip.contentOffset.x;
		NSInteger slot = 0;
		for (NSInteger i = 0; i < (NSInteger)folders.count; i++){
			if (i == from)
				continue;
			UIView *other = [strip viewWithTag:101 + i];
			if (!other)
				continue;
			if (other.center.x < centre)
				slot++;
		}
		if (slot == from){
			[self.tableView reloadData];   // a hand back down on its slot
			return;
		}

		NSMutableArray *order = [NSMutableArray array];
		// The dragged one leaves the line, then comes back wherever the
		// drop said - the slot already counts what stayed left of the
		// pill's centre on both readings of "left".
		[folders enumerateObjectsUsingBlock:^(NSDictionary *folder, NSUInteger idx,
											  BOOL *stop __unused){
			if ((NSInteger)idx != from)
				[order addObject:@([folder[@"id"] integerValue])];
		}];
		[order insertObject:folders[from][@"id"]
					atIndex:MIN(slot, (NSInteger)order.count)];
		[[TGClient shared] reorderFoldersToLocalIds:order mainListAt:0];
		[self.tableView reloadData];
	}
}

/// Sticky section header. In a plain table the pinning keeps the pill strip
/// at the top edge while the chat list scrolls beneath it, so the folder
/// switcher outlives the collapsing search header - after the chats load,
/// hideHeaderAboveFrom still parks the big header above the fold, as it
/// always has, and the pills are no longer riding along with it.
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	// Folders live on the title's chevron now. Keeping a second sticky row
	// would put the old pill strip back above the stories every time.
	return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	return nil;
}

- (void)rebuildTableHeader {
	BOOL fadeStories = self.storiesFadePending;
	self.storiesFadePending = NO;
	// Telegram stacks the header in this order: the expanded story row,
	// the search field, then the folder pills. The story row is a pull-down
	// sheet that is normally collapsed into the title avatar.
	CGFloat width = self.tableView.bounds.size.width ?: 320;
	UIColor *bg = [[TGTheme shared] listBackgroundColour];
	BOOL hasStories = self.storiesExpanded && [self collapsedStoryRow] != nil;
	CGFloat storyH = hasStories ? TGMetricStoryStripRow : TGMetricZero;
	CGFloat searchH = TGMetricRow;
	BOOL hasFolders = !self.showsArchive && [TGClient shared].folders.count > 0;
	CGFloat folderH = hasFolders ? kFolderTabRow : TGMetricZero;
	CGFloat height = storyH + searchH + folderH;

	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
	header.backgroundColor = bg;

	if (hasStories){
		if (!self.headerStoriesCell)
			self.headerStoriesCell = [TGStoryStripRowCell
					cellForRow:TGStoryStripRow(@[], nil)];
		self.headerStoriesCell.frame = CGRectMake(0, 0, width, storyH);
		self.headerStoriesCell.backgroundColor = bg;
		self.headerStoriesCell.contentView.backgroundColor = bg;
		[self configureStoriesCell:self.headerStoriesCell];
		[header addSubview:self.headerStoriesCell];
	}
	self.searchBar.frame = CGRectMake(0, storyH, width, searchH);
	[header addSubview:self.searchBar];

	if (hasFolders)
		[self buildFolderTabsInto:header atY:(storyH + searchH) width:width
				folders:[TGClient shared].folders];

	if (fadeStories && !hasStories){
		CATransition *fade = [CATransition animation];
		fade.type = kCATransitionFade;
		fade.duration = TGAnimationDurationFast;
		// Collapsing removes the strip and changes the header height; the
		// rows below move by that height in one frame, which the table fade
		// covers.
		[self.tableView.layer addAnimation:fade forKey:@"tg.stories"];
	}

	self.tableView.tableHeaderView = header;
	if (fadeStories && hasStories){
		// Expanding adds the strip as a new row. Fading its content in is
		// enough - the space for it is already part of the new header.
		UIView *content = self.headerStoriesCell.contentView;
		content.alpha = TGAlphaTransparent;
		[UIView animateWithDuration:TGAnimationDurationFast animations:^{
			content.alpha = TGAlphaOpaque;
		}];
	}
	if (self.folderHighlightPending){
		NSArray *folders = [TGClient shared].folders;
		NSInteger oldTag = 0, newTag = 0;
		for (NSInteger i = 0; i <= (NSInteger)folders.count; i++){
			NSInteger folderId = 0;
			if (i > 0 && [folders[i - 1] isKindOfClass:NSDictionary.class])
				folderId = [folders[i - 1][@"id"] integerValue];
			if (folderId == self.folderHighlightPreviousId)
				oldTag = 100 + i;
			if (folderId == self.folderId)
				newTag = 100 + i;
		}
		void (^fadePill)(NSInteger, BOOL) = ^(NSInteger tag, BOOL active){
			UIButton *pill = (UIButton *)[header viewWithTag:tag];
			if (![pill isKindOfClass:UIButton.class])
				return;
			CATransition *fade = [CATransition animation];
			fade.type = kCATransitionFade;
			fade.duration = TGAnimationDurationFast;
			[pill.layer addAnimation:fade forKey:@"tg.folderHighlight"];
			TGPaintFolderPill(pill, active);
		};
		// The old and new chosen pills are already in the header; only their
		// colours change, so one fade covers both halves of the move.
		if (oldTag && oldTag != newTag)
			fadePill(oldTag, NO);
		if (newTag && newTag != oldTag)
			fadePill(newTag, YES);
		self.folderHighlightPending = NO;
	}
	self.headerHeight = height;
	self.parkOffset = TGMetricZero;
	[self refreshListTitleView];
}

/// "All chats" is the union of the main list and every folder's chats.
/// The folder asks run in parallel; whatever each returns that the
/// list has not seen yet joins the merge. The result refreshes the table
/// only while the user is still looking at All chats.

@end
