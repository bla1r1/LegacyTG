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
#import "TGSendStore.h"


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
	NSInteger slot = [TGChatListStore activeAccountSlot];
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
				@"emojiStatusId", @"previewKind", @"previewFileId", @"previewReactionSummary", @"previewPollVotes", @"unreadReactions", @"unreadPollVotes", @"folderIds", @"lastFailed"];
	});
	NSMutableDictionary *row = [NSMutableDictionary dictionaryWithCapacity:keys.count];
	for (NSString *key in keys){
		id value = chat[key];
		if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class] || [value isKindOfClass:NSArray.class])
			row[key] = value;
	}
	return row[@"id"] ? row : nil;
}



@implementation TGChatListViewController (TGChatListLifecycle)

#pragma mark - lifecycle
- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = self.showsArchive ? TGLocalized(@"Archived Chats") : TGLocalized(@"Chats");
	[self buildListTitleView];
	[self refreshListTitleView];
	// The last list is drawn before TDLib answers, so a cold start is the
	// previous conversation list rather than a blank screen.
	self.cachedChats = (self.showsArchive || self.folderId != 0)
			? @[] : [self loadChatSnapshot];
	self.chats = self.cachedChats;
	self.avatars = [[TGImageLruCache alloc] initWithCapacity:120];
	self.avatarsRequested = [NSMutableSet set];

	self.navigationItem.rightBarButtonItem = nil;
	[self buildHeaderButtons];

	self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, TGMetricScreenWidth, TGMetricRow)];
	self.searchBar.delegate = self;
	self.searchBar.placeholder = @"Search";
	[self styleSearchBar];
	[self rebuildTableHeader];

	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(rowHeld:)];
	[self.tableView addGestureRecognizer:hold];
	[self installLegacySwipeActions];

	self.tableView.rowHeight = kRowHeight;
	// Each row draws its own hairline from under the text; see TGChatRowCell.
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	__weak typeof(self) weakSelf = self;
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[[TGTheme shared] stylePlainTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[[TGTheme shared] styleTabBar:self.tabBarController.tabBar];

	[[NSNotificationCenter defaultCenter] addObserverForName:TGThemeChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		usingBlock:^(NSNotification *note){
		[TGIcons flush];
		weakSelf.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
		[[TGTheme shared] styleNavigationBar:weakSelf.navigationController.navigationBar];
		[[TGTheme shared] stylePlainTable:weakSelf.tableView];
		[[TGTheme shared] styleTabBar:weakSelf.tabBarController.tabBar];
		[weakSelf styleSearchBar];
		[weakSelf refreshListTitleView];
		[weakSelf rebuildTableHeader];
		[weakSelf.tableView reloadData];
	}];

	[TGChatListStore shared].onChatsChanged = ^{
		// Reset signature so folder-merged chats refresh on new messages or new chats
		weakSelf.mergedSignature = nil;
		// While the cache fills, updates arrive in floods - one per chat.
		// A reload for each means the table re-lays out dozens of times and
		// the old 4S crawls; coalescing the floods to a few ticks keeps the
		// load quick and visibly the same.
		[NSObject cancelPreviousPerformRequestsWithTarget:weakSelf
				selector:@selector(reload) object:nil];
		[weakSelf performSelector:@selector(reload) withObject:nil afterDelay:0.3];
	};
	// A status or preview custom emoji picture arrived: the visible rows draw it,
	// at most every 0.3 s while a burst comes in.
	[[NSNotificationCenter defaultCenter] addObserverForName:TGCustomEmojiLoadedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		usingBlock:^(NSNotification *note){
		TGChatListViewController *me = weakSelf;
		if (!me)
			return;
		[NSObject cancelPreviousPerformRequestsWithTarget:me
				selector:@selector(reloadVisibleRows) object:nil];
		[me performSelector:@selector(reloadVisibleRows) withObject:nil afterDelay:0.3];
	}];
	// A send was refused or retried: the last-message mark on that chat's row
	// changes, and TGChatRow rebuilds it from the store.
	[[NSNotificationCenter defaultCenter] addObserverForName:TGSendStoreMessageStateChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		usingBlock:^(NSNotification *note){
		TGChatListViewController *me = weakSelf;
		if (me)
			[me reloadVisibleRows];
	}];
	// M24: a preview thumbnail landed; the rows showing it redraw in place.
	[[NSNotificationCenter defaultCenter] addObserverForName:TGChatListPreviewImageLoadedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		usingBlock:^(NSNotification *note){
		TGChatListViewController *me = weakSelf;
		if (me)
			[me reloadVisibleRows];
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:TGStoriesChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		usingBlock:^(NSNotification *note){
		TGChatListViewController *me = weakSelf;
		if (!me)
			return;
		NSNumber *chatId = note.userInfo[@"chatId"];
		if (!chatId)
			chatId = note.userInfo[@"row"][@"chatId"];
		if (note.userInfo[@"remove"]){
			NSMutableArray *kept = [NSMutableArray array];
			for (NSDictionary *row in me.storyRows)
				if ([row[@"chatId"] longLongValue] != [chatId longLongValue])
					[kept addObject:row];
			me.storyRows = kept;
		} else if (note.userInfo[@"row"]){
			NSMutableArray *rows = [me.storyRows mutableCopy] ?: [NSMutableArray array];
			NSMutableArray *kept = [NSMutableArray array];
			for (NSDictionary *row in rows)
				if ([row[@"chatId"] longLongValue] != [chatId longLongValue])
					[kept addObject:row];
			[kept addObject:note.userInfo[@"row"]];
			[kept sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b){
				return [b[@"order"] compare:a[@"order"]];
			}];
			rows = kept;
			me.storyRows = rows;
		}
		[me rebuildTableHeader];
		[me refreshListTitleView];
		[me fetchMissingAvatars];
	}];

	[TGChatListStore shared].onArchiveChanged = ^{
		[weakSelf.tableView reloadData];
	};
	[TGChatListStore shared].onConnectionState = ^(TGConnectionState state, NSString *text){
		// The list keeps its name; the network line is the second line of the
		// title view. Replacing the title took a chosen folder away on every
		// reconnect (B4), and the state is not what the screen is.
		weakSelf.connectionLine = TGNetworkSubtitleForState((NSInteger)state, text);
		if (state == TGConnectionStateReady){
			BOOL wasAnswered = weakSelf.listAnswered;
			weakSelf.listAnswered = YES;
			// A fresh account's list is empty; ready is the first moment that
			// is a fact rather than a guess. Reload so the empty state (or
			// the first chats) replaces the placeholder.
			if (!wasAnswered)
				[weakSelf reload];
		}
		[weakSelf refreshListTitleView];
	};
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self buildHeaderButtons];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	// The header cannot be parked inside viewDidLoad: the table has no
	// height yet there, so the first layout left the search field on screen.
	if (!self.userRevealed && !self.searchResults && !self.showsArchive &&
			self.folderId == 0 && self.tableView.contentOffset.y < self.parkOffset - 1.0f &&
			self.tableView.contentSize.height > self.tableView.bounds.size.height)
		self.tableView.contentOffset = CGPointMake(TGMetricZero, self.parkOffset);
}

/// The two lines at the top of the list. The name is always there; the
/// connection line appears under it only while TDLib is not ready, the way the
/// official client keeps "Chats" and breathes "Connecting..." beneath it.
- (void)buildListTitleView {
	UIView *box = [[UIView alloc] initWithFrame:CGRectMake(TGMetricZero, TGMetricZero,
			kListTitleWidth, kListTitleHeight)];
	box.backgroundColor = [UIColor clearColor];

	UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(TGMetricZero,
			TGMetricBorderWidth, kListTitleWidth, TGMetricLineRow)];
	name.font = TGFontHeader();
	name.textColor = [[TGTheme shared] barTitleColour];
	name.backgroundColor = [UIColor clearColor];
	name.textAlignment = NSTextAlignmentCenter;
	name.lineBreakMode = NSLineBreakByTruncatingTail;
	name.shadowColor = [[TGTheme shared] navBarTextShadowColour];
	name.shadowOffset = TGMetricShadowOffsetNav;
	[box addSubview:name];

	// The passcode lock used to be a left bar item. Official keeps it beside
	// the title, so it lives here and the bar keeps only Edit.
	UIButton *lock = [UIButton buttonWithType:UIButtonTypeCustom];
	CGFloat lockSide = TGMetricLineSubhead;
	lock.frame = CGRectMake(TGMetricPadTiny, TGCenteredOrigin(kListTitleHeight,
			lockSide), lockSide, lockSide);
	[lock setImage:TGChatListLockIcon(lockSide, [[TGTheme shared] barTitleColour])
		  forState:UIControlStateNormal];
	[lock addTarget:self action:@selector(lockAppTapped)
   forControlEvents:UIControlEventTouchUpInside];
	lock.hidden = ![TGPasscode hasPasscode];
	[box addSubview:lock];
	self.listLockButton = lock;

	// The folder strip on the table header is the only folder switcher;
	// official keeps no chevron on the title.

	// The collapsed story: an active peer's face appears beside the title
	// once the strip is scrolled away, and tapping it opens that story.
	UIButton *story = [UIButton buttonWithType:UIButtonTypeCustom];
	story.frame = CGRectMake(TGMetricZero, TGCenteredOrigin(kListTitleHeight,
			kListStorySide), kListStorySide, kListStorySide);
	story.layer.cornerRadius = TGHalf(kListStorySide);
	story.clipsToBounds = YES;
	story.hidden = YES;
	[story addTarget:self action:@selector(openCollapsedStory)
   forControlEvents:UIControlEventTouchUpInside];
	[box addSubview:story];
	self.listStoryAvatar = story;

	UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(TGMetricZero,
			TGMetricBorderWidth + TGMetricLineRow, kListTitleWidth,
			TGMetricLineMicro)];
	subtitle.font = TGFontMeta();
	subtitle.textColor = [[TGTheme shared] barSubtitleColour];
	subtitle.backgroundColor = [UIColor clearColor];
	subtitle.textAlignment = NSTextAlignmentCenter;
	subtitle.lineBreakMode = NSLineBreakByTruncatingTail;
	subtitle.hidden = YES;
	[box addSubview:subtitle];

	self.listTitleView = box;
	self.listTitleLabel = name;
	self.listSubtitleLabel = subtitle;
	self.navigationItem.titleView = box;
}

- (void)refreshListTitleView {
	if (!self.listTitleView)
		[self buildListTitleView];

	NSString *name = [self titleForCurrentList];
	if (self.editingChats){
		NSUInteger chosen = self.tableView.indexPathsForSelectedRows.count;
		name = chosen ? TGLocalizedFormat(@"%d Selected", (int)chosen)
					  : TGLocalized(@"Chats");
	}
	if (![name isKindOfClass:NSString.class])
		name = TGLocalized(@"Chats");
	BOOL hasLine = self.connectionLine.length > 0;
	self.title = name;
	self.listTitleLabel.text = name;
	NSString *line = hasLine ? self.connectionLine : @"";
	// "Connecting" and "Updating" are different sentences under the same
	// title; replacing one with the other read as a blink. Only a visible
	// line changing needs the fade - a first appearance is the label's own
	// hidden flag.
	if (hasLine && self.listSubtitleLabel.text.length &&
			![self.listSubtitleLabel.text isEqualToString:line] &&
			self.listSubtitleLabel.window){
		CATransition *fade = [CATransition animation];
		fade.type = kCATransitionFade;
		fade.duration = TGAnimationDurationFast;
		[self.listSubtitleLabel.layer addAnimation:fade forKey:@"tg.connection"];
	}
	self.listSubtitleLabel.text = line;
	self.listSubtitleLabel.hidden = !hasLine;
	// One line centres itself in the bar; two share it, the name on top and
	// the network beneath, which is the same stack the chat header uses.
	self.listTitleLabel.frame = CGRectMake(TGMetricZero,
			hasLine ? TGMetricBorderWidth : TGCenteredOrigin(kListTitleHeight,
					TGMetricLineRow),
			kListTitleWidth, TGMetricLineRow);
	self.listTitleLabel.textColor = [[TGTheme shared] barTitleColour];
	self.listTitleLabel.shadowColor = [[TGTheme shared] navBarTextShadowColour];
	self.listSubtitleLabel.textColor = [[TGTheme shared] barSubtitleColour];
	if (self.listLockButton){
		BOOL showLock = [TGPasscode hasPasscode] && !self.editingChats;
		self.listLockButton.hidden = !showLock;
		if (showLock){
			CGFloat lockSide = TGMetricLineSubhead;
			CGFloat textWidth = [name sizeWithFont:self.listTitleLabel.font].width;
			CGFloat x = MAX(TGMetricPadTiny,
					(kListTitleWidth - textWidth) * 0.5f - lockSide - TGMetricPadTiny);
			self.listLockButton.frame = CGRectMake(x,
					hasLine ? TGCenteredOrigin(TGMetricLineRow, lockSide)
							: TGCenteredOrigin(kListTitleHeight, lockSide),
					lockSide, lockSide);
		}
	}

	BOOL hasFolders = NO;
	NSDictionary *story = [self collapsedStoryRow];
	BOOL showStory = story != nil && !hasLine && !self.storiesExpanded;
	self.listStoryAvatar.hidden = !showStory;

	CGSize text = [name sizeWithFont:self.listTitleLabel.font];
	CGFloat total = text.width;
	if (showStory)
		total += kListStorySide + kListStoryGap;
	CGFloat x = TGHalf(kListTitleWidth) - TGHalf(total);
	CGFloat top = CGRectGetMinY(self.listTitleLabel.frame);

	if (showStory){
		self.listStoryAvatar.frame = CGRectMake(x, TGCenteredOrigin(kListTitleHeight,
				kListStorySide), kListStorySide, kListStorySide);
		int64_t peerId = [story[@"chatId"] longLongValue];
		UIImage *image = story[@"avatarImage"];
		if (!image && peerId)
			image = [[TGPeerStore shared] cachedAvatarForPeer:peerId
													   side:kListStorySide];
		if (!image){
			NSString *title = [story[@"title"] isKindOfClass:NSString.class]
					? story[@"title"] : @"?";
			NSString *first = [TGIcons initialsForTitle:title];
			image = [TGIcons avatarWithInitials:first size:kListStorySide
									 colourId:[story[@"chatId"] longLongValue]];
		}
		[self.listStoryAvatar setImage:image forState:UIControlStateNormal];
		if (!story[@"avatarImage"] && !story[@"isOwn"] && peerId){
			__weak typeof(self) weakSelf = self;
			[[TGPeerStore shared] loadAvatarForPeer:peerId
											 side:kListStorySide
									   completion:^(UIImage *loaded){
				if (!loaded)
					return;
				[weakSelf.listStoryAvatar setImage:loaded
										  forState:UIControlStateNormal];
			}];
		}
		x += kListStorySide + kListStoryGap;
	}
	self.listTitleLabel.frame = CGRectMake(x, top, text.width, TGMetricLineRow);
}

/// The peer whose story collapses into the title when the strip is off
/// screen. Own stories stay in the strip; this is the first other account
/// with something to watch.

@end
