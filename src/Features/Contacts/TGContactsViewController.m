#import "TGContactsViewController.h"
#import "TGLocalization.h"
#import "TGNewContactViewController.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGCustomEmojiStore.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGEmptyView.h"
#import "TGStatusText.h"
#import "TGContactSort.h"
#import "TGPeerRowCell.h"
#import "TGRows.h"

@interface TGContactsViewController () <UISearchBarDelegate>
@property (nonatomic, strong) TGEmptyView *emptyView;
@property (nonatomic, strong) NSArray *users;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray *filteredUsers;
@property (nonatomic, assign) BOOL isSearching;
/// Who is ticked, while this screen is picking rather than opening.
@property (nonatomic, strong) NSMutableSet *picked;
/// How many contacts this account has uploaded from a phone's address book.
/// The footer is where it stays visible after an import.
@property (nonatomic, assign) NSInteger importedCount;
@property (nonatomic, assign) BOOL sortByLastSeen;
- (void)updateSearchEmptyViewForQuery:(NSString *)query;
@end

static NSString *TGContactName(NSDictionary *u);

/// Contacts grouped in the order the list already sorted them. The "#"
/// bucket always comes last, so it does not push A down the screen.
static NSArray *TGContactSections(NSArray *users) {
	NSMutableArray *sections = [NSMutableArray array];
	NSMutableDictionary *byTitle = [NSMutableDictionary dictionary];
	for (NSDictionary *user in users){
		NSString *title = TGContactSectionTitle(TGContactName(user));
		NSMutableArray *bucket = byTitle[title];
		if (!bucket){
			bucket = [NSMutableArray array];
			byTitle[title] = bucket;
			[sections addObject:@{@"title" : title, @"users" : bucket}];
		}
		[bucket addObject:user];
	}
	// "#" is appended last; then the letters are already in sorted-name order.
	NSArray *sorted = [sections sortedArrayUsingComparator:^NSComparisonResult(id a, id b){
		NSString *ta = a[@"title"], *tb = b[@"title"];
		if ([ta isEqualToString:@"#"]) return NSOrderedDescending;
		if ([tb isEqualToString:@"#"]) return NSOrderedAscending;
		return [ta localizedCaseInsensitiveCompare:tb];
	}];
	return sorted;
}

@implementation TGContactsViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	if ([[NSUserDefaults standardUserDefaults] objectForKey:@"TGContactsSortByLastSeen"]) {
		self.sortByLastSeen = [[NSUserDefaults standardUserDefaults] boolForKey:@"TGContactsSortByLastSeen"];
	} else {
		self.sortByLastSeen = YES;
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"TGContactsSortByLastSeen"];
	}

	self.picked = [NSMutableSet set];
	// A caller may already have named the screen (the New Message picker);
	// keep that title and treat it as a picker with no Sort/add controls.
	BOOL newMessagePicker = [self.title isEqualToString:@"New Message"];
	if (!self.title.length)
		self.title = [self isPicking]
				? (self.addingToChatId ? @"Add Members" : @"New Group")
				: @"Contacts";
	if ([self isPicking]){
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
				initWithTitle:(self.addingToChatId ? @"Add" : @"Create")
						style:UIBarButtonItemStyleDone
					   target:self action:@selector(commitPicking)];
		self.navigationItem.rightBarButtonItem.enabled = NO;
	} else if (!newMessagePicker) {
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
				initWithTitle:@"Sort"
						style:UIBarButtonItemStylePlain
					   target:self
					   action:@selector(sortTapped)];
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
				initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
									 target:self
									 action:@selector(addContactTapped)];
	}
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.users = @[];
	self.sections = @[];
	self.tableView.rowHeight = TGMetricPersonRow;
	self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(TGMetricZero, TGMetricZero, self.view.bounds.size.width, TGMetricRow)];
	[[TGTheme shared] styleSearchBar:self.searchBar];
	self.searchBar.delegate = self;
	self.searchBar.placeholder = @"Search Contacts";
	self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
	// Keep the navigation title; the search field lives in the table header
	// (and scrolls with it), so "Contacts" and "New Message" stay visible.
	self.tableView.tableHeaderView = self.searchBar;
	// No separators drawn under the last contact, across the empty screen.
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[[TGTheme shared] stylePlainTable:self.tableView];

	__weak typeof(self) weakContacts = self;
	[[NSNotificationCenter defaultCenter] addObserverForName:TGThemeChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){
		TGContactsViewController *me = weakContacts;
		[TGIcons flush];
		me.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
		[[TGTheme shared] stylePlainTable:me.tableView];
		[[TGTheme shared] styleNavigationBar:me.navigationController.navigationBar];
		[[TGTheme shared] styleSearchBar:me.searchBar];
		[me.tableView reloadData];
	}];

	[[NSNotificationCenter defaultCenter] addObserverForName:TGCustomEmojiLoadedNotification
													  object:nil
													   queue:[NSOperationQueue mainQueue]
												  usingBlock:^(NSNotification *note){
		TGContactsViewController *me = weakContacts;
		if (!me) return;
		[NSObject cancelPreviousPerformRequestsWithTarget:me selector:@selector(reloadVisibleRows) object:nil];
		[me performSelector:@selector(reloadVisibleRows) withObject:nil afterDelay:0.3];
	}];

	[self loadContacts];
}

- (void)reloadVisibleRows {
	NSArray *visible = [self.tableView indexPathsForVisibleRows];
	if (visible.count) {
		[self.tableView reloadRowsAtIndexPaths:visible withRowAnimation:UITableViewRowAnimationNone];
	}
}

- (void)sortTapped {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[(self.sortByLastSeen
								? [@"✓ " stringByAppendingString:TGLocalized(@"by Last Seen")]
								: @"by Last Seen"),
								(self.sortByLastSeen
								? @"by Name"
								: [@"✓ " stringByAppendingString:TGLocalized(@"by Name")])]
						title:@"Sort"
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		TGContactsViewController *me = weakSelf;
		if (!me) return;
		BOOL sortLastSeen = (index == 0);
		if (me.sortByLastSeen != sortLastSeen) {
			me.sortByLastSeen = sortLastSeen;
			[[NSUserDefaults standardUserDefaults] setBool:sortLastSeen forKey:@"TGContactsSortByLastSeen"];
			[me sortAndGroupContacts];
			[me.tableView reloadData];
		}
	}];
}

- (void)sortAndGroupContacts {
	if (self.sortByLastSeen) {
		self.users = TGContactsSortedByLastSeen(self.users);
	} else {
		self.users = TGContactsSortedByName(self.users);
	}
	[self rebuildSections];
}

- (NSArray *)sectionGroups {
	NSArray *users = self.isSearching ? self.filteredUsers : self.users;
	if (self.isSearching || self.sortByLastSeen)
		return @[@{@"title" : @"", @"users" : users ?: @[]}];
	return TGContactSections(users ?: @[]);
}

- (void)rebuildSections {
	NSMutableArray *sections = [NSMutableArray array];
	for (NSDictionary *group in [self sectionGroups]){
		NSArray *users = group[@"users"];
		NSMutableArray *rows = [NSMutableArray arrayWithCapacity:users.count];
		for (NSDictionary *user in users)
			[rows addObject:[self rowForUser:user]];
		NSString *header = [group[@"title"] length] ? group[@"title"] : nil;
		[sections addObject:TGSection(header, nil, rows)];
	}
	self.sections = sections;
}

- (NSMutableDictionary *)rowForUser:(NSDictionary *)u {
	NSString *name = TGContactName(u);
	NSNumber *userId = u[@"id"];
	int64_t uid = [userId longLongValue];
	int64_t statusEmojiId = [[TGClient shared] emojiStatusIdForUser:uid];

	NSString *subtitle = @"";
	BOOL online = NO;
	NSString *presence = TGStatusTextFromTDStatus(u[@"status"]);
	if (presence.length) {
		subtitle = presence;
		online = [u[@"status"][@"@type"] isEqualToString:@"userStatusOnline"];
	} else if ([u[@"username"] length]) {
		subtitle = [@"@" stringByAppendingString:u[@"username"]];
		online = YES;
	} else if ([u[@"phone"] length]) {
		subtitle = [NSString stringWithFormat:@"+%@", u[@"phone"]];
	}

	__weak typeof(self) weakSelf = self;
	NSMutableDictionary *row = TGPeerRow(userId, name, subtitle, ^{
		[weakSelf selectUser:u];
	});
	row[TGRowAvatarUser] = @YES;
	row[TGRowOnline] = @(online);
	if (statusEmojiId > 0)
		row[TGRowStatusEmojiId] = @(statusEmojiId);
	if ([self isPicking]){
		row[TGRowAccessory] = TGRowAccessoryCheck;
		row[TGRowChecked] = @([self.picked containsObject:userId]);
	}
	return row;
}

- (void)addContactTapped {
	TGNewContactViewController *vc = [[TGNewContactViewController alloc] init];
	UINavigationController *nav = [[UINavigationController alloc]
			initWithRootViewController:vc];
	[self presentViewController:nav animated:YES completion:nil];
}

/// The count is the account's, not the list's: TDLib answers it separately,
/// and after an import it is the only place the result is visible.
- (void)updateImportedFooter {
	UILabel *footer = [[UILabel alloc] initWithFrame:
			CGRectMake(0, 0, self.view.bounds.size.width, TGMetricLineRow)];
	footer.text = self.importedCount
			? TGLocalizedPluralValue(@"%@ contact", @"%@ contacts",
					[NSString stringWithFormat:@"%ld", (long)self.importedCount],
					self.importedCount)
			: @"Contacts";
	footer.font = TGFontCaption();
	footer.textAlignment = NSTextAlignmentCenter;
	footer.textColor = [[TGTheme shared] secondaryTextColour];
	footer.backgroundColor = [UIColor clearColor];
	self.tableView.tableFooterView = footer;
}

- (void)loadContacts {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] importedContactCountWithCompletion:^(NSInteger count){
		TGContactsViewController *me = weakSelf;
		if (!me)
			return;
		me.importedCount = count;
		[me updateImportedFooter];
	}];
	[[TGClient shared] contactsWithCompletion:^(NSArray *users){
		TGContactsViewController *me = weakSelf;
		if (!me)
			return;
		me.users = users ?: @[];
		[me sortAndGroupContacts];
		[me.tableView reloadData];

		if (me.users.count == 0) {
			if (!me.emptyView) {
				me.emptyView = [TGEmptyView emptyViewWithFrame:me.view.bounds
				                                         image:[TGIcons emptyContactsIllustration]
				                                         title:@"Contacts"
				                                      subtitle:nil
				                                   buttonTitle:@"Add Contact"
				                                        target:me
				                                        action:@selector(addContactTapped)];
				[me.view addSubview:me.emptyView];
			}
			me.emptyView.hidden = NO;
		} else if (me.emptyView) {
			me.emptyView.hidden = YES;
		}
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self loadContacts];
}

- (void)reloadTableDebounced {
	[NSObject cancelPreviousPerformRequestsWithTarget:self.tableView selector:@selector(reloadData) object:nil];
	[self.tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.05];
}

static NSString *TGContactName(NSDictionary *u) {
	return TGContactDisplayName(u);
}

#pragma mark - search bar

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	NSString *trimmed = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!trimmed.length) {
		self.isSearching = NO;
		self.filteredUsers = @[];
		[self updateSearchEmptyViewForQuery:nil];
		[self rebuildSections];
		[self.tableView reloadData];
		return;
	}
	self.isSearching = YES;
	NSString *query = [trimmed lowercaseString];
	NSMutableArray *matches = [NSMutableArray array];
	for (NSDictionary *user in self.users) {
		NSString *first = [user[@"first_name"] lowercaseString] ?: @"";
		NSString *last = [user[@"last_name"] lowercaseString] ?: @"";
		NSString *full = [NSString stringWithFormat:@"%@ %@", first, last];
		NSString *uname = [user[@"username"] lowercaseString] ?: @"";
		NSString *phone = user[@"phone"] ?: @"";
		if ([first rangeOfString:query].location != NSNotFound ||
			[last rangeOfString:query].location != NSNotFound ||
			[full rangeOfString:query].location != NSNotFound ||
			[uname rangeOfString:query].location != NSNotFound ||
			[phone rangeOfString:query].location != NSNotFound) {
			[matches addObject:user];
		}
	}
	self.filteredUsers = matches;
	[self updateSearchEmptyViewForQuery:trimmed];
	[self rebuildSections];
	[self.tableView reloadData];
}

- (void)updateSearchEmptyViewForQuery:(NSString *)query {
	if (self.isSearching && self.filteredUsers.count == 0 && query.length){
		UILabel *empty = [[UILabel alloc] initWithFrame:self.tableView.bounds];
		empty.text = TGLocalized(@"No matching\ncontacts found");
		empty.textAlignment = NSTextAlignmentCenter;
		empty.numberOfLines = 2;
		empty.font = TGFontBody();
		empty.textColor = [[TGTheme shared] secondaryTextColour];
		empty.backgroundColor = [UIColor clearColor];
		self.tableView.backgroundView = empty;
	} else {
		self.tableView.backgroundView = nil;
	}
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	searchBar.text = @"";
	[searchBar setShowsCancelButton:NO animated:YES];
	[searchBar resignFirstResponder];
	self.isSearching = NO;
	self.filteredUsers = @[];
	[self updateSearchEmptyViewForQuery:nil];
	[self rebuildSections];
	[self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	(void)tableView;
	if (self.isSearching || self.sortByLastSeen)
		return nil;
	// A short list reads worse with a rail down the side; Telegram keeps it
	// for an address book that is actually long.
	if (self.sections.count < 8)
		return nil;
	NSMutableArray *titles = [NSMutableArray array];
	for (NSDictionary *section in self.sections){
		NSString *title = section[@"header"];
		[titles addObject:title.length ? title : @""];
	}
	return titles;
}

- (NSInteger)tableView:(UITableView *)tableView
 sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
	(void)tableView;
	(void)title;
	return index;
}

- (void)selectUser:(NSDictionary *)u {
	if ([self isPicking]){
		[self togglePickedUser:u];
		return;
	}
	NSString *name = TGContactName(u);
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] privateChatWithUser:[u[@"id"] longLongValue]
								completion:^(int64_t chatId){
		TGContactsViewController *me = weakSelf;
		if (!me || chatId == 0)
			return;
		TGChatViewController *vc = [[TGChatViewController alloc] init];
		vc.chatId = chatId;
		vc.chatTitle = name;
		vc.hidesBottomBarWhenPushed = YES;
		[me.navigationController pushViewController:vc animated:YES];
	}];
}

- (void)togglePickedUser:(NSDictionary *)u {
	NSNumber *userId = u[@"id"];
	if ([self.picked containsObject:userId])
		[self.picked removeObject:userId];
	else
		[self.picked addObject:userId];
	self.navigationItem.rightBarButtonItem.enabled = self.picked.count > 0;
	[self rebuildSections];
	[self.tableView reloadData];
}

/// Either mode ticks rows; the difference is what the button at the top does
/// with them.
- (BOOL)isPicking {
	return self.picksGroupMembers || self.addingToChatId != 0;
}

/// A group needs a name and at least one other person - TDLib refuses an
/// empty one - so the name is asked for once the picking is done.
- (void)commitPicking {
	NSArray *userIds = self.picked.allObjects;
	if (!userIds.count)
		return;

	__weak typeof(self) weakSelf = self;
	if (self.addingToChatId){
		int64_t chatId = self.addingToChatId;
		// One person is addChatMember, the request their own client sends
		// when a profile's "Add to Group" names a single user; the batch
		// form is for the picker's many. Same answer either way.
		if (userIds.count == 1){
			NSNumber *only = userIds.firstObject;
			[[TGClient shared] addUser:only.longLongValue
								toChat:chatId
							completion:^(BOOL ok, NSArray *refused){
				TGContactsViewController *me = weakSelf;
				if (!ok)
					[TGAlertSheet showMessage:@"An error occurred."
										  title:@"Add Members" inView:me.view];
				[me.navigationController popViewControllerAnimated:YES];
			}];
			return;
		}
		// One request for the whole pick: the N-request loop this replaced
		// answered the server once per contact and could strand half of the
		// batch on a slow connection.
		[[TGClient shared] addUsers:userIds toChat:chatId completion:^(BOOL ok, NSArray *refused){
			TGContactsViewController *me = weakSelf;
			if (refused.count)
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Add Members" inView:me.view];
			[me.navigationController popViewControllerAnimated:YES];
		}];
		return;
	}

	[TGAlertSheet showInput:@"New Group"
					message:TGLocalizedPlural(@"%d Selected", @"%d Selected",
							(NSInteger)userIds.count)
				placeholder:@"Group Name"
					   text:nil
					 action:@"Create"
					 inView:self.view
				   onSubmit:^(NSString *title){
		[[TGClient shared] createGroupNamed:title withUsers:userIds
								 completion:^(int64_t chatId, NSArray *failed){
			TGContactsViewController *me = weakSelf;
			if (!chatId){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"New Group" inView:me.view];
				return;
			}
			TGChatViewController *chat = [[TGChatViewController alloc] init];
			chat.chatId = chatId;
			chat.chatTitle = title;
			chat.hidesBottomBarWhenPushed = YES;
			// Replaces this screen rather than stacking on it: going back
			// from the new group belongs in the chat list.
			NSMutableArray *stack = [me.navigationController.viewControllers mutableCopy];
			[stack removeLastObject];
			[stack addObject:chat];
			[me.navigationController setViewControllers:stack animated:YES];

			if (failed.count)
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"New Group" inView:chat.view];
		}];
	}];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

/// The system's caption is grey on grey over a dark list, which is what
/// this screen had: every other list styles its own.

@end

// vim:ft=objc
