#import "TGSettingsViewController.h"
#import "TGTheme.h"
#import "TGThemeFile.h"
#import "TGStorageViewController.h"
#import "TGSessionsViewController.h"
#import "TGDeviceViewController.h"
#import "TGDevice.h"
#import "TGCapabilities.h"
#import "TGEditProfileViewController.h"
#import "TGProfileViewController.h"
#import "TGQRViewController.h"
#import "TGPlaceholderViewController.h"
#import "TGIcons.h"

#import "TGSettingsViewControllerInternal.h"
#import "TGPeerStore.h"
#import "TGChatThemeStore.h"
#import "TGStyle.h"
#import "TGLocalization.h"
#import "TGAccountStore.h"
#import "TGChatListStore.h"
#import "TGProfileStore.h"
#import "TGSessionsStore.h"
#import "TGSettingsStore.h"


static const CGFloat kSettingsSearchWidth = 200.0f;
static const CGFloat kSettingsSearchHeight = 44.0f;

/// The two pages that delete rows keep their own bookkeeping in their
/// category; the base class owns the one delegate method UIKit keeps.
@interface TGSettingsViewController (TGSettingsEditing)
- (BOOL)canEditBlockedRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)canEditProxyRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)commitBlockedEditingStyle:(UITableViewCellEditingStyle)editingStyle
				forRowAtIndexPath:(NSIndexPath *)indexPath
					  inTableView:(UITableView *)tableView;
- (void)commitProxyEditingStyle:(UITableViewCellEditingStyle)editingStyle
			   forRowAtIndexPath:(NSIndexPath *)indexPath
					 inTableView:(UITableView *)tableView;
@end

@implementation TGSettingsViewController

@synthesize profileCell = _profileCell;

/// The profile-photo action clears this slot after an upload: the peer store
/// re-reads the account so the new file id, and with it the new picture, is
/// what the next rebuild asks for.
- (void)setProfileCell:(UITableViewCell *)profileCell {
	_profileCell = profileCell;
	if (!profileCell){
		int64_t uid = [[TGProfileStore shared].me[@"id"] longLongValue];
		__weak typeof(self) weakSelf = self;
		if (uid)
			[[TGPeerStore shared] refreshPeerForId:uid completion:^(TGPeer *peer){
				(void)peer;
				[weakSelf rebuild];
			}];
	}
}

- (id)init {
	self = [super init];
	if (self)
		self.checksSectionIcons = NO;
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	// iOS 7 lays content out under the bars; these screens position their own
	// frames and expect the old behaviour.
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.contentInset = UIEdgeInsetsMake(0, 0, TGMetricTabBarH, 0);
	self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
	[self applyTheme];

	self.privacy  = [NSMutableDictionary dictionary];
	self.muted    = [NSMutableDictionary dictionary];
	self.previews = [NSMutableDictionary dictionary];
	self.suggestFrequent = YES;
	NSDictionary *savedDiagnostics = [NSUserDefaults.standardUserDefaults
			objectForKey:@"TGCallDiagnosticsSent"];
	self.callDiagnostics = savedDiagnostics
			? [savedDiagnostics mutableCopy] : [NSMutableDictionary dictionary];

	self.title = TGLocalized([self pageTitle]);

	if (self.page == TGSettingsPageRecentCalls) {
		UISegmentedControl *filter = [[UISegmentedControl alloc] initWithItems:@[@"All", @"Missed"]];
		filter.selectedSegmentIndex = self.recentCallsFilter;
		[filter addTarget:self action:@selector(recentCallsFilterChanged:) forControlEvents:UIControlEventValueChanged];
		self.navigationItem.titleView = filter;
	} else if (self.page == TGSettingsPageRoot) {
		// The account name lives in the header, not in a navigation title.
		// Only the bar's title is cleared: self.title = nil also blanked the
		// tab bar's "Settings" label and the subpages' back button.
		self.navigationItem.title = @"";
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
				initWithImage:[self qrBarIcon]
				style:UIBarButtonItemStylePlain
				target:self action:@selector(openQRCode)];
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
				initWithTitle:@"Edit" style:UIBarButtonItemStylePlain
					   target:self action:@selector(openEditProfile)];
	} else if (self.page == TGSettingsPageLanguage){
		// Official puts the language search in the navigation bar.
		UISearchBar *search = [[UISearchBar alloc] initWithFrame:
				CGRectMake(0, 0, kSettingsSearchWidth, kSettingsSearchHeight)];
		search.delegate = self;
		search.placeholder = @"Search";
		self.languageSearchBar = search;
		self.navigationItem.titleView = search;
	}

	[self rebuild];
	[self loadForPage];

	// Repaint on theme change notification.
	__weak typeof(self) weakSelf = self;
	[[NSNotificationCenter defaultCenter] addObserverForName:TGThemeChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){
		[weakSelf repaint];
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:TGPrivacyRulesChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){
		[weakSelf privacyRulesChanged];
	}];
	// The verification row has nothing to show until Telegram asks; when it
	// does, the row fills in without the page being reopened.
	[[NSNotificationCenter defaultCenter] addObserverForName:TGApplicationVerificationRequiredNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){
		[weakSelf rebuild];
	}];
	// The Appearance page's colour lists arrive by update; it re-reads while
	// open instead of waiting for Telegram to be asked again on reopen.
	[[NSNotificationCenter defaultCenter] addObserverForName:TGAccentColorsChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){
		if (weakSelf.page == TGSettingsPageAppearance)
			[weakSelf rebuild];
	}];
	// Account status and Telegram's appearance defaults are pushed, so the
	// page that draws them re-reads while it is open - a freeze that starts
	// during a session should not need Settings closed and reopened.
	[[NSNotificationCenter defaultCenter] addObserverForName:TGAccountStatusChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){
		if (weakSelf.page == TGSettingsPagePrivacy)
			[weakSelf rebuild];
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:TGAppearanceDefaultsChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){
		if (weakSelf.page == TGSettingsPageAppearance)
			[weakSelf rebuild];
	}];
	// The Active Notifications page is a view of the client's local list:
	// removing one row, or TDLib replacing the list, must reach it without a
	// reopen. The summary row on the page above reads the same count.
	[[NSNotificationCenter defaultCenter] addObserverForName:TGActiveNotificationsChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){
		if (weakSelf.page == TGSettingsPageActiveNotifications ||
			weakSelf.page == TGSettingsPageNotifications)
			[weakSelf rebuild];
	}];
	// Autosave and language state can change on another client while these
	// pages are open. Both re-read their whole record rather than patching
	// one row from an update that carries only one scope or one string.
	[[NSNotificationCenter defaultCenter] addObserverForName:TGAutosaveSettingsChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){
		[weakSelf autosaveSettingsChanged];
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:TGLanguagePackStringsChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){
		[weakSelf languagePackStringsChanged:note.userInfo[@"packId"]];
	}];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

/// Restyle everything this screen owns and redraw it.
- (void)repaint {
	[TGIcons flush];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[[TGTheme shared] styleTabBar:self.tabBarController.tabBar];
	[self applyTheme];
	[self rebuild];
}

- (NSString *)pageTitle {
	switch (self.page){
		case TGSettingsPageAppearance:    return @"Appearance";
		case TGSettingsPageData:          return @"Data and Storage";
		case TGSettingsPageFolders:       return @"Chat Folders";
		case TGSettingsPageProxy:         return @"Proxy";
		case TGSettingsPageDownloads:     return @"Downloads";
		case TGSettingsPageAutosave:      return @"Auto-Download";
		case TGSettingsPageNotifications: return @"Notifications";
		case TGSettingsPageNotificationSounds: return @"Sound";
		case TGSettingsPageActiveNotifications: return @"Notifications";
		case TGSettingsPagePrivacy:       return @"Privacy and Security";
		case TGSettingsPagePasscode:      return @"Passcode Lock";
		case TGSettingsPageLanguage:      return @"Language";
		case TGSettingsPageBlocked:       return @"Blocked Users";
		case TGSettingsPagePowerSaving:   return @"Power Saving";
		case TGSettingsPageRecentCalls:   return @"Recent Calls";
		case TGSettingsPageWallpaper:     return @"Chat Wallpaper";
		case TGSettingsPageChatThemes:    return @"Chat Themes";
		case TGSettingsPageAutoNight:     return @"Auto-Night Theme";
		case TGSettingsPagePaymentData:   return @"Orders and Payment Data";
#if TG_DEV
		case TGSettingsPageDebug:         return @"Dev Settings";
		case TGSettingsPageLanguageDev:   return @"Language Packs";
		case TGSettingsPagePaymentDev:    return @"Invoice Tools";
#endif
		default:                          return @"Settings";
	}
}

- (void)applyTheme {
	[super applyTheme];
	[[TGTheme shared] styleGroupedTable:self.tableView];
}



- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	// The bar belongs to the screen. A page pushed after a scroll must still
	// show Back, so nothing in this controller ever hides it.
	if (self.navigationController.navigationBarHidden)
		[self.navigationController setNavigationBarHidden:NO animated:NO];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self rebuild];
	// The Archive switches are the one page that reads copy TDLib holds:
	// the cached copy answers the first draw, the network refresh redraws.
	if (self.page == TGSettingsPageData)
		[[TGSettingsStore shared] refreshArchiveChatListSettings:^{ [self rebuild]; }];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	// A Saved Messages retry must not reach into a screen the user has left.
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(openSavedMessages) object:nil];
	self.savedMessagesRetries = 0;
}

#pragma mark - reordering, where a page has an order

/// Only the folders page has one, and the order belongs to the pill strip
/// above the chat list. A table already knows how to drag rows, so this is
/// the Edit button and the two delegate methods rather than a gesture.
- (BOOL)tableView:(UITableView *)tableView
		canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return self.page == TGSettingsPageFolders &&
		   indexPath.section == 0 &&
		   indexPath.row < (NSInteger)[TGChatListStore shared].folders.count;
}

- (void)tableView:(UITableView *)tableView
		moveRowAtIndexPath:(NSIndexPath *)from
			   toIndexPath:(NSIndexPath *)to {
	NSMutableArray *order = [NSMutableArray array];
	for (NSDictionary *folder in [TGChatListStore shared].folders)
		if ([folder[@"id"] integerValue])
			[order addObject:folder[@"id"]];
	if (from.row >= (NSInteger)order.count || to.row >= (NSInteger)order.count)
		return;

	NSNumber *moved = order[(NSUInteger)from.row];
	[order removeObjectAtIndex:(NSUInteger)from.row];
	[order insertObject:moved atIndex:(NSUInteger)to.row];

	// All Chats stays first: this app's strip draws it as the leading pill and
	// has nowhere to put it in the middle.
	[[TGSettingsStore shared] reorderFolderIds:order mainListAt:0];
}

/// Only the pages whose categories can delete rows get a delete control.
/// Folders drag, so they keep none; the folder's own sheet deletes.
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
		   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.page == TGSettingsPageBlocked || self.page == TGSettingsPageProxy)
		return UITableViewCellEditingStyleDelete;
	return UITableViewCellEditingStyleNone;
}

/// UIKit keeps one implementation of these two selectors per class, so the
/// base class owns them and sends each page to its category's helper.
- (BOOL)tableView:(UITableView *)tableView
		canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.page == TGSettingsPageBlocked)
		return [self canEditBlockedRowAtIndexPath:indexPath];
	if (self.page == TGSettingsPageProxy)
		return [self canEditProxyRowAtIndexPath:indexPath];
	// A row that may not be edited shows no reorder control either.
	if (self.page == TGSettingsPageFolders)
		return [self tableView:tableView canMoveRowAtIndexPath:indexPath];
	return NO;
}

- (void)tableView:(UITableView *)tableView
		commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
		 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.page == TGSettingsPageBlocked)
		[self commitBlockedEditingStyle:editingStyle
					  forRowAtIndexPath:indexPath
							inTableView:tableView];
	else if (self.page == TGSettingsPageProxy)
		[self commitProxyEditingStyle:editingStyle
					forRowAtIndexPath:indexPath
						  inTableView:tableView];
}

- (void)openPage:(TGSettingsPage)page {
	TGSettingsViewController *next = [[TGSettingsViewController alloc] init];
	next.page = page;
	next.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:next animated:YES];
}

/// The root page still describes its header as the old row kind in its page
/// builder; the shared profile-header row is built here from the same account
/// record, so the page keeps describing a header and the cell stays generic.
- (NSMutableDictionary *)profileHeaderRow {
	NSDictionary *me = [TGProfileStore shared].me;
	NSString *name = [me[@"first_name"] length] ? me[@"first_name"]
			: ([me[@"username"] length] ? me[@"username"] : @"Telegram");
	if ([me[@"last_name"] length])
		name = [NSString stringWithFormat:@"%@ %@", name, me[@"last_name"]];
	NSString *phone = [me[@"phone"] length]
			? [NSString stringWithFormat:@"+%@", me[@"phone"]] : @"";
	NSString *username = [me[@"username"] length]
			? [NSString stringWithFormat:@"@%@", me[@"username"]] : @"";
	NSString *detail = (phone.length && username.length)
			? [NSString stringWithFormat:@"%@ • %@", phone, username]
			: (phone.length ? phone : username);

	NSNumber *userId = me[@"id"];
	int64_t uid = [userId longLongValue];
	// One avatar path for the whole app: the peer store downloads each file
	// once and keeps the rounded picture; this header used its own copy and
	// came up as the initials plate after the move to the shared row.
	UIImage *avatar = uid ? [[TGPeerStore shared] cachedAvatarForPeer:uid
			side:TGMetricProfileAvatar] : nil;
	void (^loader)(UIImageView *) = nil;
	if (uid && !avatar){
		loader = ^(UIImageView *view){
			__weak UIImageView *weakView = view;
			[[TGPeerStore shared] loadAvatarForPeer:uid side:TGMetricProfileAvatar
					completion:^(UIImage *image){
				if (image && weakView)
					weakView.image = image;
			}];
		};
	}

	__weak typeof(self) weakSelf = self;
	return TGProfileHeaderRow(userId, name, detail, avatar, loader, ^{
		[weakSelf openMyProfile];
	});
}

- (NSArray *)sectionsReplacingLegacyRows:(NSArray *)sections {
	NSMutableArray *prepared = [NSMutableArray arrayWithCapacity:sections.count];
	for (NSDictionary *section in sections){
		if (![section isKindOfClass:NSDictionary.class]){
			[prepared addObject:section];
			continue;
		}
		NSArray *rows = section[@"rows"];
		NSMutableArray *newRows = [NSMutableArray arrayWithCapacity:rows.count];
		for (NSDictionary *row in rows){
			if ([[row isKindOfClass:NSDictionary.class] ? row[TGRowKind] : nil
					isEqualToString:TGKindProfile]){
				[newRows addObject:[self profileHeaderRow]];
			} else {
				[newRows addObject:row];
			}
		}
		NSMutableDictionary *newSection = [section mutableCopy];
		newSection[@"rows"] = newRows;
		[prepared addObject:newSection];
	}
	return prepared;
}

/// Rebuild the rows from whatever the client has answered so far, and redraw.
/// Everything that arrives asynchronously calls this rather than reaching into
/// a cell by index.
- (void)rebuild {
	self.sections = [self sectionsReplacingLegacyRows:[self buildSections]];
	[self reloadRows];
}

/// The version, the way their page ends with one.
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	(void)tableView;
	(void)section;
	return nil;
}

#pragma mark - loading

/// Three scopes arrive as three updates when they are reset at once.
- (void)notificationSettingsChanged {
	if (self.page != TGSettingsPageNotifications &&
		self.page != TGSettingsPageNotificationSounds)
		return;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(loadForPage) object:nil];
	[self performSelector:@selector(loadForPage) withObject:nil afterDelay:0.3];
}

/// updateAutosaveSettings moves one scope at a time and a client change can
/// be a short run of them. The Autosave page and the Data row read the whole
/// record, so one re-read a third of a second later covers the burst.
- (void)autosaveSettingsChanged {
	if (self.page != TGSettingsPageAutosave && self.page != TGSettingsPageData)
		return;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(loadForPage) object:nil];
	[self performSelector:@selector(loadForPage) withObject:nil afterDelay:0.3];
}

/// A privacy rule flipped here or on another client; a reset moves several
/// at once, so the re-read waits out the burst like the one above.
- (void)privacyRulesChanged {
	if (self.page != TGSettingsPagePrivacy)
		return;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(loadForPage) object:nil];
	[self performSelector:@selector(loadForPage) withObject:nil afterDelay:0.3];
}

- (void)recentCallsFilterChanged:(UISegmentedControl *)sender {
	self.recentCallsFilter = sender.selectedSegmentIndex;
	[self rebuild];
}

/// Four updates land on this screen - added, finished, paused, removed - and
/// a sweep of the list fires one per file. One re-read a third of a second
/// later covers the burst; the list is a single request.
- (void)downloadsChanged {
	if (self.page != TGSettingsPageDownloads)
		return;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(loadForPage) object:nil];
	[self performSelector:@selector(loadForPage) withObject:nil afterDelay:0.3];
}

- (void)loadForPage {
	__weak typeof(self) weakSelf = self;

	if (self.page == TGSettingsPageRoot){
		// The root rows name their values, as the official client's do. All
		// four answers are cached by the client or cheap to ask for; none of
		// them blocks the first draw, and a failed answer leaves the row as
		// it was rather than inventing a value.
		[[TGSettingsStore shared] storageStatsWithCompletion:^(long long bytes, NSInteger files){
			(void)files;
			weakSelf.rootCacheBytes = bytes;
			weakSelf.rootCacheLoaded = YES;
			[weakSelf rebuild];
		}];
		[[TGSessionsStore shared] sessionsWithInactiveTtlCompletion:^(NSArray *sessions,
															  NSInteger ttlDays){
			(void)ttlDays;
			NSInteger others = 0;
			NSString *device = nil;
			for (NSDictionary *session in sessions){
				if ([session[@"isCurrent"] boolValue])
					device = session[@"name"];
				else
					others++;
			}
			weakSelf.rootDeviceName = device;
			weakSelf.rootSessionCount = others;
			[weakSelf rebuild];
		}];
		[[TGSettingsStore shared] languagesWithCompletion:^(NSArray *languages,
													 NSString *current){
			NSString *name = current;
			for (NSDictionary *language in languages)
				if ([language[@"id"] isEqualToString:current ?: @""]){
					name = language[@"name"] ?: current;
					break;
				}
			weakSelf.rootLanguageName = name;
			[weakSelf rebuild];
		}];
		[[TGSettingsStore shared] proxiesWithCompletion:^(NSArray *proxies){
			if (!proxies.count){
				weakSelf.rootProxyDetail = nil;
			} else {
				NSString *detail = @"Disabled";
				for (NSDictionary *proxy in proxies)
					if ([proxy[@"enabled"] boolValue]){
						NSString *kind = proxy[@"kind"];
						if ([kind isEqualToString:@"socks5"]) detail = @"SOCKS5";
						else if ([kind isEqualToString:@"mtproto"]) detail = @"MTProto";
						else if ([kind isEqualToString:@"http"]) detail = @"HTTP";
						else if ([kind isEqualToString:@"web"]) detail = @"Web";
						else detail = @"Disabled";
						break;
					}
				weakSelf.rootProxyDetail = detail;
			}
			[weakSelf rebuild];
		}];
		return;
	}

	if (self.page == TGSettingsPageAppearance){
		// The colour list comes from updateAccentColors and is cached on the
		// client; the selection is a field of the account record, so it takes
		// one getMe. A page opened before the update still draws 0-6, which
		// the schema promises are valid.
		[[TGProfileStore shared] myAccentColorsWithCompletion:^(NSInteger accent,
														  NSInteger profile){
			weakSelf.accentColorId = accent;
			weakSelf.profileAccentColorId = profile;
			weakSelf.accentColorsLoaded = YES;
			[weakSelf rebuild];
		}];
		return;
	}

	if (self.page == TGSettingsPageFolders){
		// Nothing to reorder until there are two.
		if ([TGChatListStore shared].folders.count > 1)
			self.navigationItem.rightBarButtonItem = self.editButtonItem;
		// The folders themselves arrive through updateChatFolders, which the
		// client already keeps; only the suggestions have to be asked for.
		[[TGSettingsStore shared] recommendedFoldersWithCompletion:^(NSArray *folders){
			weakSelf.recommendedFolders = folders;
			[weakSelf rebuild];
		}];
		if (!weakSelf.folderChatCounts)
			weakSelf.folderChatCounts = [NSMutableDictionary dictionary];
		for (NSDictionary *folder in [TGChatListStore shared].folders){
			NSInteger folderId = [folder[@"id"] integerValue];
			if (!folderId)
				continue;
			[[TGSettingsStore shared] chatCountForFolder:folder
									   completion:^(NSInteger count){
				weakSelf.folderChatCounts[@(folderId)] = @(count);
				if (weakSelf.page == TGSettingsPageFolders)
					[weakSelf rebuild];
			}];
		}
		// onChatsChanged is the chat list's; taking it over here left the list
		// deaf to new messages until the app restarted.
		[[NSNotificationCenter defaultCenter] removeObserver:self name:TGChatsChangedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rebuild)
													 name:TGChatsChangedNotification object:nil];
		return;
	}

	if (self.page == TGSettingsPageDownloads){
		[[NSNotificationCenter defaultCenter] removeObserver:self
				name:TGDownloadsChangedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
				selector:@selector(downloadsChanged)
					name:TGDownloadsChangedNotification object:nil];
		[[TGSettingsStore shared] fileDownloadsMatching:nil activeOnly:NO
									  completion:^(NSArray *downloads, NSInteger active){
			weakSelf.downloads = downloads;
			weakSelf.activeDownloads = active;
			[weakSelf rebuild];
		}];
		return;
	}

	if (self.page == TGSettingsPageProxy){
		[[TGSettingsStore shared] proxiesWithCompletion:^(NSArray *proxies){
			weakSelf.proxies = proxies;
			[weakSelf rebuild];
		}];
		return;
	}

	if (self.page == TGSettingsPageNotifications){
		[[NSNotificationCenter defaultCenter] removeObserver:self
				name:TGNotificationSettingsChangedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
				selector:@selector(notificationSettingsChanged)
					name:TGNotificationSettingsChangedNotification object:nil];
		for (NSString *scope in @[@"private", @"groups", @"channels"]){
			[[TGSettingsStore shared] notificationsMutedForScope:scope
											   completion:^(BOOL muted){
				weakSelf.muted[scope] = @(muted);
				[weakSelf rebuild];
			}];
			[[TGSettingsStore shared] notificationPreviewForScope:scope
												completion:^(BOOL show){
				weakSelf.previews[scope] = @(show);
				[weakSelf rebuild];
			}];
		}
		// The Notifications page used to read savedSounds before the Sound page
		// had ever loaded them. Load them here so the summary is not blank.
		[[TGSettingsStore shared] savedNotificationSoundsWithCompletion:^(NSArray *sounds){
			weakSelf.savedSounds = sounds;
			weakSelf.savedSoundsLoaded = YES;
			[weakSelf rebuild];
		}];
		return;
	}

	if (self.page == TGSettingsPageNotificationSounds){
		// A sound added or removed here, or on another client, arrives as
		// updateSavedNotificationSounds and the same settings notification.
		[[NSNotificationCenter defaultCenter] removeObserver:self
				name:TGNotificationSettingsChangedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
				selector:@selector(notificationSettingsChanged)
					name:TGNotificationSettingsChangedNotification object:nil];
		[[TGSettingsStore shared] savedNotificationSoundsWithCompletion:^(NSArray *sounds){
			weakSelf.savedSounds = sounds;
			weakSelf.savedSoundsLoaded = YES;
			[weakSelf rebuild];
		}];
		return;
	}

	if (self.page == TGSettingsPageActiveNotifications){
		// No request exists for this list: updateActiveNotifications is the
		// only copy, and it is already on the client.
		[self rebuild];
		return;
	}

	if (self.page == TGSettingsPagePrivacy){
		// Official shows an activity item in the bar until the account answers.
		if (!self.navigationItem.rightBarButtonItem){
			UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
					initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			[spinner startAnimating];
			self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
					initWithCustomView:spinner];
		}
		for (NSString *setting in [TGSettingsViewController privacySettings])
			[[TGSettingsStore shared] privacyRule:setting completion:^(NSString *value){
				weakSelf.privacy[setting] = value;
				[weakSelf rebuild];
				[weakSelf updatePrivacySpinner];
			}];
		[[TGSettingsStore shared] accountTtlWithCompletion:^(NSInteger days){
			weakSelf.accountTtl = days;
			weakSelf.accountTtlLoaded = YES;
			[weakSelf rebuild];
			[weakSelf updatePrivacySpinner];
		}];
		[[TGSettingsStore shared] defaultMessageAutoDeleteTimeWithCompletion:^(NSInteger seconds){
			weakSelf.autoDeleteDefault = seconds;
			[weakSelf rebuild];
		}];
		[[TGAccountStore shared] hasPasswordWithCompletion:^(BOOL has, NSString *email){
			weakSelf.hasPassword = has;
			weakSelf.passwordKnown = YES;
			[weakSelf rebuild];
			[weakSelf updatePrivacySpinner];
		}];
		NSNumber *savedPersonal =
				[NSUserDefaults.standardUserDefaults objectForKey:
						TGAccountStoreDefaultsKey(@"TGPersonalChatId")];
		if (savedPersonal)
			weakSelf.personalChatId = savedPersonal.longLongValue;
		// TDLib stores the negative, so the row and the option are opposites.
		[[TGSettingsStore shared] optionValue:@"disable_top_chats" completion:^(id value){
			weakSelf.suggestFrequent = ![value boolValue];
			[weakSelf rebuild];
		}];
		return;
	}

	if (self.page == TGSettingsPageData){
		[[TGSettingsStore shared] storageStatsWithCompletion:^(long long bytes, NSInteger files){
			(void)files;
			weakSelf.rootCacheBytes = bytes;
			weakSelf.rootCacheLoaded = YES;
			[weakSelf rebuild];
		}];
		[[TGSettingsStore shared] networkStatsWithCompletion:^(long long sent, long long got){
			weakSelf.networkSent = sent;
			weakSelf.networkReceived = got;
			[weakSelf rebuild];
		}];
		[[TGSettingsStore shared] autoDownloadSettingsPresetsWithCompletion:^(NSDictionary *presets){
			weakSelf.autoDownloadPresets = presets;
			[weakSelf rebuild];
		}];
		// The Autosave row's detail is the exception count; reading the
		// settings once here also satisfies TDLib's rule that set/clear work
		// only after getAutosaveSettings has answered.
		[[TGSettingsStore shared] autosaveSettingsWithCompletion:^(NSDictionary *settings){
			weakSelf.autosaveSettings = settings;
			[weakSelf rebuild];
		}];
		return;
	}

	if (self.page == TGSettingsPageAutosave){
		[[TGSettingsStore shared] autosaveSettingsWithCompletion:^(NSDictionary *settings){
			weakSelf.autosaveSettings = settings;
			[weakSelf rebuild];
		}];
		return;
	}

	if (self.page == TGSettingsPageLanguage || self.page == TGSettingsPageLanguageDev){
		[[TGSettingsStore shared] languagesWithCompletion:^(NSArray *languages,
													NSString *current){
			weakSelf.languages = languages;
			weakSelf.currentLanguage = current;
			[weakSelf rebuild];
			if (current.length)
				[[TGSettingsStore shared] languagePackInfo:current
										 completion:^(NSDictionary *info){
					weakSelf.languageInfo = info;
					[weakSelf rebuild];
				}];
		}];
		NSString *code = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]
				?: weakSelf.countryCode ?: @"US";
		weakSelf.countryCode = code;
		[[TGSettingsStore shared] countryInfoForCode:code completion:^(NSDictionary *country){
			weakSelf.countryInfo = country;
			[weakSelf rebuild];
		}];
		[[TGSettingsStore shared] preferredCountryLanguageForCode:code
												completion:^(NSString *language){
			weakSelf.preferredCountryLanguage = language;
			[weakSelf rebuild];
		}];
		[[TGSettingsStore shared] countryFlagEmojiForCode:code completion:^(NSString *emoji){
			weakSelf.countryFlag = emoji;
			[weakSelf rebuild];
		}];
		return;
	}

	if (self.page == TGSettingsPageBlocked){
		[[TGSettingsStore shared] blockedUsersWithCompletion:^(NSArray *users){
			weakSelf.blocked = users;
			[weakSelf rebuild];
		}];
		return;
	}

	if (self.page == TGSettingsPageRecentCalls){
		[[TGSettingsStore shared] recentCallsWithCompletion:^(NSArray *calls){
			weakSelf.calls = calls;
			[weakSelf rebuild];
		}];
		return;
	}

	if (self.page == TGSettingsPagePaymentData){
		[[TGSettingsStore shared] savedOrderInfoWithCompletion:^(NSDictionary *order,
														  NSString *error){
			weakSelf.savedOrder = order;
			weakSelf.savedOrderError = error;
			weakSelf.savedOrderLoaded = YES;
			[weakSelf rebuild];
		}];
		return;
	}

	if (self.page == TGSettingsPageDebug){
		// optionValue: hands back the value itself, not the option object.
		// Subscripting it again asked an NSString for objectForKeyedSubscript:,
		// which took the app down every time this page opened.
		[[TGSettingsStore shared] optionValue:@"version" completion:^(id value){
			weakSelf.tdlibVersion = [value isKindOfClass:NSString.class]
					? value : @"unavailable";
			[weakSelf rebuild];
		}];
	}
}

- (void)updatePrivacySpinner {
	if (self.page != TGSettingsPagePrivacy)
		return;
	BOOL rules = self.privacy.count >= [TGSettingsViewController privacySettings].count;
	if (rules && self.passwordKnown && self.accountTtlLoaded)
		self.navigationItem.rightBarButtonItem = nil;
}

/// TDLib's names without the prefix, in the order every client lists them.
+ (NSArray *)privacySettings {
	static NSArray *settings = nil;
	if (!settings)
		settings = @[@"ShowStatus", @"ShowProfilePhoto", @"ShowPhoneNumber",
					 @"ShowBirthdate", @"AllowCalls", @"AllowChatInvites",
					 @"ShowLinkInForwardedMessages"];
	return settings;
}

+ (NSArray *)privacyTitles {
	static NSArray *titles = nil;
	if (!titles)
		titles = @[@"Last Seen & Online", @"Profile Photos", @"Phone Number",
				   @"Birthday", @"Calls", @"Groups & Channels",
				   @"Forwarded Messages"];
	return titles;
}


#pragma mark - table

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSString *text = self.sections[section][@"header"];
	return text.length ? TGSettingsHeaderText(text) : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	NSString *text = self.sections[section][@"footer"];
	return text.length ? TGLocalized(text) : nil;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
	[[TGTheme shared] styleHeaderFooterView:view];
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
	[[TGTheme shared] styleHeaderFooterView:view];
}



- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	(void)tableView;
	(void)section;
	return UITableViewAutomaticDimension;
}

@end

// vim:ft=objc
