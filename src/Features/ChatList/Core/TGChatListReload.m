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
#import "TGChatParityModel.h"


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



@implementation TGChatListViewController (TGChatListReload)

#pragma mark - reload and stories
- (void)applyFolderListFadeIfNeeded {
	if (!self.folderListFadePending)
		return;
	self.folderListFadePending = NO;
	CATransition *fade = [CATransition animation];
	fade.type = kCATransitionFade;
	fade.duration = TGAnimationDurationFast;
	[self.tableView.layer addAnimation:fade forKey:@"tg.folderList"];
}

- (void)reload {
	if (self.showsArchive){
		self.chats = [TGClient shared].archivedChats;
		[self reloadStoriesIfNeeded];
		[self.tableView reloadData];
		[self fetchMissingAvatars];
		return;
	}

	if (self.folderId != 0){
		NSInteger folder = self.folderId;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] chatsInFolder:folder completion:^(NSArray *chats){
			// A late answer for a folder the user already left must not fill
			// the folder now on screen.
			if (!TGChatFolderAnswerStillWanted(folder, weakSelf.folderId))
				return;
			weakSelf.chats = chats;
			// An answer for a folder the user already left must not spend
			// the next switch's fade.
			[weakSelf applyFolderListFadeIfNeeded];
			[weakSelf reloadStoriesIfNeeded];
			[weakSelf.tableView reloadData];
			[weakSelf fetchMissingAvatars];
		}];
		return;
	}

	// "All chats" means all of them: tdlib's chatListMain holds only the
	// chats with no folder, the rest lives behind chatListFolder requests.
	// The merge below fills the gap in the background.
	NSArray *baseChats = self.mergedChats ?: [TGClient shared].chats;
	if (!baseChats.count && self.cachedChats.count)
		baseChats = self.cachedChats;
	// Once the live list is here the snapshot has done its job; keeping it
	// would let a logout or a cleared account bring the old rows back.
	if ([TGClient shared].chats.count)
		self.cachedChats = @[];
	self.chats = baseChats;
	[self reloadStoriesIfNeeded];
	[self applyFolderListFadeIfNeeded];
	[self.tableView reloadData];
	[self rebuildTableHeader];
	// The search field is a pull-down: Telegram opens on the stories row,
	// not on a search bar. Park past the header once the table has a real
	// height; a deliberate pull brings it back (scrollViewWillEndDragging).
	if (!self.userRevealed && !self.searchResults && !self.showsArchive &&
			self.folderId == 0 && self.tableView.contentOffset.y < self.parkOffset - 1.0f){
		[self.tableView layoutIfNeeded];
		if (self.tableView.contentSize.height > self.tableView.bounds.size.height)
			self.tableView.contentOffset = CGPointMake(TGMetricZero, self.parkOffset);
	}
	[self fetchMissingAvatars];
	if ([TGClient shared].chats.count)
		[self saveChatSnapshot:baseChats];
	[self mergeAllFolderChats];

	BOOL hasContent = ([self visibleChats].count > 0 || self.searchResults != nil || [self headerRows].count > 0);
	if ([TGClient shared].chats.count || self.cachedChats.count || self.mergedChats.count)
		self.listAnswered = YES;
	if (!hasContent && !self.listAnswered) {
		// TDLib has not answered yet; an empty state now would be a guess.
		NSString *loading = TGLocalized(@"Loading...");
		if (!self.emptyView) {
			self.emptyView = [TGEmptyView emptyViewWithFrame:self.view.bounds
			                                           image:[TGIcons emptyChatsIllustration]
			                                           title:loading
			                                        subtitle:nil
			                                     buttonTitle:nil
			                                          target:nil
			                                          action:nil];
			[self.view addSubview:self.emptyView];
		} else if (![self.emptyView.titleLabel.text isEqualToString:loading]) {
			self.emptyView.titleLabel.text = loading;
		}
		self.emptyView.hidden = NO;
	} else if (!hasContent) {
		NSString *empty = [TGClient shared].archivedChats.count
				? TGLocalized(@"All of your chats are archived.")
				: TGLocalized(@"You have no\nconversations yet.");
		// The "Loading..." view has a one-line title and no button; rebuild
		// rather than retitle it, or the two-line sentence clips.
		if (self.emptyView && ![self.emptyView.titleLabel.text isEqualToString:empty]) {
			[self.emptyView removeFromSuperview];
			self.emptyView = nil;
		}
		if (!self.emptyView) {
			self.emptyView = [TGEmptyView emptyViewWithFrame:self.view.bounds
			                                           image:[TGIcons emptyChatsIllustration]
			                                           title:empty
			                                        subtitle:nil
			                                     buttonTitle:TGLocalized(@"Start Messaging")
			                                          target:self
			                                          action:@selector(composeTapped)];
			[self.view addSubview:self.emptyView];
		}
		self.emptyView.hidden = NO;
	} else if (self.emptyView) {
		self.emptyView.hidden = YES;
	}
}

/// Chat list header rows. The archive strip sits below the pinned pills as
/// the first row of the list, and the initial scroll parks it behind the
/// pills band, so All chats opens clean and the strip needs a pull down.
/// The strip only joins once the list holds enough rows to park it: a bare
/// start (archive row drawn over an empty list) parks nothing and the strip
/// would sit there for the whole load.
- (NSArray *)headerRows {
	if (self.searchResults || self.showsArchive || self.folderId != 0)
		return @[];
	NSMutableArray *rows = [NSMutableArray array];
	if ([TGClient shared].archivedChats.count > 0)
		[rows addObject:@"archive"];
	return rows;
}

- (BOOL)hasArchiveRow {
	return NO;
}

/// The strip is re-read at most once every half minute: the chat list reloads
/// on every chat update, and each refresh here is one request per chat.
- (void)reloadStoriesIfNeeded {
	if (self.storyRowsLoading)
		return;
	if (self.storyRowsReadAt &&
		-[self.storyRowsReadAt timeIntervalSinceNow] < 30.0)
		return;
	self.storyRowsLoading = YES;
	NSString *list = self.showsArchive ? @"archive" : @"main";
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] activeStoryRowsForList:list completion:^(NSArray *rows){
		TGChatListViewController *me = weakSelf;
		if (!me)
			return;
		// The per-chat read is a first pass; updateChatActiveStories may
		// already have delivered a row for a chat outside its sixty. Keep
		// both, but only rows belonging to the list that was asked for: the
		// archive and a folder must not inherit each other's strip.
		NSArray *merged = TGStoryRowsForList(rows, me.storyRows, list);
		me.storyRows = merged;
		if (me.storiesExpanded && ![me collapsedStoryRow]){
			// The last story expired while the strip was open; fold it away
			// with the same fade as a scroll collapse.
			me.storiesExpanded = NO;
			me.storiesFadePending = YES;
		}
		// An empty answer often means the chat list had not loaded yet, not
		// that nobody has a story. Only a real answer earns the cooldown;
		// otherwise the strip stayed empty for thirty seconds after launch.
		me.storyRowsReadAt = merged.count ? [NSDate date] : nil;
		me.storyRowsLoading = NO;
		[me rebuildTableHeader];
		[me refreshListTitleView];
		[me fetchMissingAvatars];
	}];
}

- (void)showStoryRow:(NSDictionary *)row {
	NSArray *infos = row[@"stories"];
	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *info in infos)
		if ([info[@"storyId"] isKindOfClass:NSNumber.class])
			[ids addObject:info[@"storyId"]];
	if (!ids.count){
		[TGAlertSheet showMessage:@"An error occurred."
							title:@"Stories" inView:self.view];
		return;
	}
	TGStoryViewerViewController *viewer = [[TGStoryViewerViewController alloc]
			initWithChatId:[row[@"chatId"] longLongValue]
					 title:row[@"title"] ?: @"Stories"
				   stories:ids
				startIndex:0
				 canManage:[row[@"isOwn"] boolValue]];
	__weak typeof(self) weakSelf = self;
	viewer.onStoriesChanged = ^{
		TGChatListViewController *me = weakSelf;
		me.storyRowsReadAt = nil;
		[me reloadStoriesIfNeeded];
	};
	UINavigationController *nav = [[UINavigationController alloc]
			initWithRootViewController:viewer];
	nav.navigationBar.barStyle = UIBarStyleBlack;
	nav.navigationBar.translucent = YES;
	[self presentViewController:nav animated:YES completion:nil];
}

/// Held stories bubble: move the chat's stories between the main strip and
/// the archive, which is the hide Telegram offers for another account's
/// stories. Own stories have no archive move; the row says so.
- (void)runStoryRowMenu:(NSDictionary *)row {
	BOOL archived = [row[@"list"] isEqualToString:@"archive"];
	if ([row[@"isOwn"] boolValue] && !archived){
		[TGAlertSheet showMessage:@"An error occurred." title:@"Stories" inView:self.view];
		return;
	}
	NSArray *choices = archived
			? @[@"Restore"] : @[@"Hide"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices title:row[@"title"] ?: @"Stories"
				destructiveIndex:-1 inView:self.view onChoice:^(NSInteger choice){
		TGChatListViewController *me = weakSelf;
		if (!me)
			return;
		int64_t chatId = [row[@"chatId"] longLongValue];
		[[TGClient shared] setActiveStoriesList:(archived ? @"main" : @"archive")
										forChat:chatId
									 completion:^(BOOL ok, NSString *error){
			if (!ok){
				[TGAlertSheet showMessage:error ?: @"An error occurred."
									title:@"Stories" inView:me.view];
				return;
			}
			me.storyRowsReadAt = nil;
			[me reloadStoriesIfNeeded];
		}];
	}];
}

- (void)openStoryComposer {
	int64_t savedId = [[TGClient shared] savedMessagesChatId];
	if (!savedId){
		[TGAlertSheet showMessage:@"An error occurred."
							title:@"New Story" inView:self.view];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[TGStoryComposerViewController openFromController:self chatId:savedId
												title:@"Your Story" onPosted:^{
		TGChatListViewController *me = weakSelf;
		me.storyRowsReadAt = nil;
		[me reloadStoriesIfNeeded];
	}];
}

- (void)openStoriesMenu {
	int64_t savedId = [[TGClient shared] savedMessagesChatId];
	if (!savedId){
		[TGAlertSheet showMessage:@"An error occurred."
							title:@"Stories" inView:self.view];
		return;
	}
	// The manager is My Profile, as in the official client: Stories and Archive on
	// one screen. A story moved there shows in the strip on the way back.
	TGProfileViewController *profile = [[TGProfileViewController alloc]
			initWithChatId:savedId userId:savedId title:@"My Profile"];
	profile.storedMediaKind = @"stories";
	profile.hidesBottomBarWhenPushed = YES;
	self.storyRowsReadAt = nil;
	[self.navigationController pushViewController:profile animated:YES];
}

- (void)openArchive {
	TGChatListViewController *archive = [[TGChatListViewController alloc] init];
	archive.showsArchive = YES;
	archive.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:archive animated:YES];
}

- (void)reloadTableDebounced {
	[NSObject cancelPreviousPerformRequestsWithTarget:self.tableView selector:@selector(reloadData) object:nil];
	[self.tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.05];
}

/// Avatars are fetched once each and cached by file id.
// The decode side of the avatar flood. Two at a time, one autorelease pool
// each: the parallel burst once filled a GCD thread with no pool until the
// thread's memory blew out mid-chat-load (a real-account crash, SIGSEGV 0x0
// inside the icon decode - every avatar asked for the same thread).
static dispatch_semaphore_t TGAvtDecodeGate(NSInteger cap) {
	static dispatch_semaphore_t gate = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		gate = dispatch_semaphore_create((long)cap);
	});
	return gate;
}


@end
