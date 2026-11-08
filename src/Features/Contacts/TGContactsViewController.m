#import "TGContactsViewController.h"
#import "TGLocalization.h"
#import "TGNewContactViewController.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGNameWithStatus.h"
#import "TGCustomEmojiStore.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGEmptyView.h"
#import "TGMemberAvatarStore.h"
#import "TGStatusText.h"
#import "TGContactSort.h"

@interface TGContactsViewController () <UISearchBarDelegate>
@property (nonatomic, strong) TGEmptyView *emptyView;
@property (nonatomic, strong) NSArray *users;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray *filteredUsers;
@property (nonatomic, assign) BOOL isSearching;
/// The same contacts split by their first letter, so the list reads like
/// Telegram's address book instead of one long run of names.
@property (nonatomic, strong) NSArray *sections;
/// Who is ticked, while this screen is picking rather than opening.
@property (nonatomic, strong) NSMutableSet *picked;
/// How many contacts this account has uploaded from a phone's address book.
/// The footer is where it stays visible after an import.
@property (nonatomic, assign) NSInteger importedCount;
@property (nonatomic, assign) BOOL sortByLastSeen;
- (void)updateSearchEmptyViewForQuery:(NSString *)query;
@end

/// A contact row with its avatar inset and a fixed size. The stock cell sized
/// the image view to the picture and put it at x 0 on iOS 6, so a large
/// photo filled the row's height flush against the screen edge.
@interface TGContactCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UIImageView *checkView;
@property (nonatomic, assign) int64_t avatarUser;
@property (nonatomic, assign) BOOL showsCheck;
@property (nonatomic, assign) BOOL checked;
@end

@implementation TGContactCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	if ((self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier])) {
		_avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(TGMetricPad, TGMetricZero, TGMetricListAvatar, TGMetricListAvatar)];
		_avatarView.contentMode = UIViewContentModeScaleAspectFill;
		_avatarView.clipsToBounds = YES;
		_avatarView.opaque = NO;
		_avatarView.backgroundColor = [UIColor clearColor];
		[self.contentView addSubview:_avatarView];

		_checkView = [[UIImageView alloc] initWithFrame:CGRectZero];
		_checkView.contentMode = UIViewContentModeScaleAspectFit;
		[self.contentView addSubview:_checkView];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat side = TGMetricListAvatar;
	CGFloat h = self.contentView.bounds.size.height;
	CGFloat checkSide = TGMetricMenuGlyph;
	CGFloat left = TGMetricPad;
	if (self.showsCheck){
		self.checkView.frame = CGRectMake(left, TGCenteredOrigin(h, checkSide), checkSide, checkSide);
		left += checkSide + TGMetricPadSmall;
	} else {
		self.checkView.frame = CGRectZero;
	}
	self.avatarView.frame = CGRectMake(left, TGCenteredOrigin(h, side), side, side);
	CGFloat x = left + side + TGMetricPadMedium;
	// To the content view's edge: UIKit sized the labels for the picture as
	// it was before the inset, and the names came out cut short.
	CGFloat width = MAX(TGMetricZero, self.contentView.bounds.size.width - x - TGMetricPadMedium);
	for (UILabel *label in @[self.textLabel, self.detailTextLabel]) {
		CGRect f = label.frame;
		f.origin.x = x;
		f.size.width = width;
		label.frame = f;
	}
}
@end

static NSString *TGContactName(NSDictionary *u);

/// A name's section letter. Anything that is not a letter lands in "#", the
/// way the phone's address book groups punctuation and emoji.
static NSString *TGContactSectionTitle(NSString *name) {
	NSString *trimmed = [name stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!trimmed.length)
		return @"#";
	NSRange r = [trimmed rangeOfComposedCharacterSequenceAtIndex:0];
	if (r.length != 1)
		return @"#";
	NSString *first = [[trimmed substringWithRange:r] uppercaseString];
	unichar c = [first characterAtIndex:0];
	if ((c >= 'A' && c <= 'Z') || (c >= 0x0400 && c <= 0x04FF))
		return first;
	return @"#";
}

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
		self.sections = @[@{@"title": @"", @"users": self.users}];
	} else {
		self.users = TGContactsSortedByName(self.users);
		self.sections = TGContactSections(self.users);
	}
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
	[self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (self.isSearching)
		return 1;
	return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (self.isSearching)
		return (NSInteger)self.filteredUsers.count;
	if (section < 0 || section >= (NSInteger)self.sections.count)
		return 0;
	return [self.sections[(NSUInteger)section][@"users"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (self.isSearching || self.sortByLastSeen)
		return nil;
	if (section < 0 || section >= (NSInteger)self.sections.count)
		return nil;
	return self.sections[(NSUInteger)section][@"title"];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
	[[TGTheme shared] styleHeaderFooterView:view];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	if (self.isSearching || self.sortByLastSeen)
		return nil;
	// A short list reads worse with a rail down the side; Telegram keeps it
	// for an address book that is actually long.
	if (self.sections.count < 8)
		return nil;
	NSMutableArray *titles = [NSMutableArray array];
	for (NSDictionary *section in self.sections)
		[titles addObject:section[@"title"]];
	return titles;
}

- (NSInteger)tableView:(UITableView *)tableView
 sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
	return index;
}

- (NSDictionary *)userAtIndexPath:(NSIndexPath *)indexPath {
	if (self.isSearching) {
		if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.filteredUsers.count)
			return nil;
		return self.filteredUsers[(NSUInteger)indexPath.row];
	}
	if (indexPath.section < 0 || indexPath.section >= (NSInteger)self.sections.count)
		return nil;
	NSArray *users = self.sections[(NSUInteger)indexPath.section][@"users"];
	if (indexPath.row < 0 || indexPath.row >= (NSInteger)users.count)
		return nil;
	return users[(NSUInteger)indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGContactCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGContactCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									reuseIdentifier:reuse];

	NSDictionary *u = [self userAtIndexPath:indexPath];
	if (!u)
		return cell;
	NSString *name = TGContactName(u);
	int64_t uid = [u[@"id"] longLongValue];
	int64_t statusEmojiId = [[TGClient shared] emojiStatusIdForUser:uid];
	UIColor *bg = [[TGTheme shared] listBackgroundColour];
	cell.backgroundColor = bg;
	cell.contentView.backgroundColor = bg;
	cell.textLabel.backgroundColor = bg;
	cell.textLabel.opaque = YES;
	cell.textLabel.attributedText = TGNameWithStatus(name ?: @"", statusEmojiId, TGFontBody(), [[TGTheme shared] primaryTextColour]);
	cell.textLabel.font = TGFontBody();
	cell.detailTextLabel.backgroundColor = bg;
	cell.detailTextLabel.opaque = YES;

	NSString *presence = TGStatusTextFromTDStatus(u[@"status"]);
	if (presence.length) {
		cell.detailTextLabel.text = presence;
		if ([u[@"status"][@"@type"] isEqualToString:@"userStatusOnline"]) {
			cell.detailTextLabel.textColor = [[TGTheme shared] accentColour];
		} else {
			cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
		}
	} else if ([u[@"username"] length]) {
		cell.detailTextLabel.text = [@"@" stringByAppendingString:u[@"username"]];
		cell.detailTextLabel.textColor = [[TGTheme shared] accentColour];
	} else if ([u[@"phone"] length]) {
		cell.detailTextLabel.text = [NSString stringWithFormat:@"+%@", u[@"phone"]];
		cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	} else {
		cell.detailTextLabel.text = @"";
	}
	cell.detailTextLabel.font = TGFontCaption();
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.accessoryType = UITableViewCellAccessoryNone;

	TGContactCell *contactCell = (TGContactCell *)cell;
	contactCell.avatarUser = uid;
	contactCell.showsCheck = [self isPicking];
	contactCell.checked = [self.picked containsObject:u[@"id"]];
	contactCell.checkView.hidden = !contactCell.showsCheck;
	if (contactCell.showsCheck){
		NSString *glyph = contactCell.checked ? @"checkboxSelected"
											  : @"checkboxUnselected";
		contactCell.checkView.image = [TGIcons glyphNamed:glyph
												   colour:contactCell.checked
														  ? [[TGTheme shared] accentColour]
														  : [[TGTheme shared] secondaryTextColour]
													 side:TGMetricMenuGlyph];
	}
	[contactCell setNeedsLayout];

	UIImage *photo = [[TGMemberAvatarStore shared] cachedAvatarForUser:uid side:TGMetricListAvatar];
	if (photo) {
		contactCell.avatarView.image = [TGIcons roundedImage:photo
														size:CGSizeMake(TGMetricListAvatar, TGMetricListAvatar)
													  radius:TGHalf(TGMetricListAvatar)
													 corners:UIRectCornerAllCorners];
	} else {
		contactCell.avatarView.image = [TGIcons avatarWithInitials:[TGIcons initialsForTitle:name]
															  size:TGMetricListAvatar
														  colourId:uid];
		__weak TGContactCell *weakCell = contactCell;
		__weak UITableView *weakTable = tableView;
		[[TGMemberAvatarStore shared] loadAvatarForUser:uid side:TGMetricListAvatar completion:^(UIImage *img){
			if (!img) return;
			dispatch_async(dispatch_get_main_queue(), ^{
				TGContactCell *c = weakCell;
				if (!c || c.avatarUser != uid) return;
				c.avatarView.image = [TGIcons roundedImage:img
													  size:CGSizeMake(TGMetricListAvatar, TGMetricListAvatar)
													radius:TGHalf(TGMetricListAvatar)
												   corners:UIRectCornerAllCorners];
			});
		}];
	}
	cell.imageView.image = nil;

	return cell;
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	NSDictionary *u = [self userAtIndexPath:indexPath];
	if (!u)
		return;
	if ([self isPicking]){
		NSNumber *userId = u[@"id"];
		if ([self.picked containsObject:userId])
			[self.picked removeObject:userId];
		else
			[self.picked addObject:userId];
		self.navigationItem.rightBarButtonItem.enabled = self.picked.count > 0;
		[tableView reloadRowsAtIndexPaths:@[indexPath]
						 withRowAnimation:UITableViewRowAnimationNone];
		return;
	}
	NSString *name = TGContactName(u);
	int64_t uid = [u[@"id"] longLongValue];
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

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

/// The system's caption is grey on grey over a dark list, which is what
/// this screen had: every other list styles its own.

@end

// vim:ft=objc
