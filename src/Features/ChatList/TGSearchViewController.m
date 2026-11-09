//
// TGSearchViewController - search controller for chats and messages.
//
#import "TGSearchViewController.h"
#import "TGLocalization.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGNameWithStatus.h"
#import "TGCustomEmojiStore.h"
#import "TGTheme.h"
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGPublicStoriesViewController.h"
#import "TGChatParityModel.h"
#import "TGRows.h"
#import "TGDateFormat.h"


@interface TGSearchViewController () <UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *bar;
@property (nonatomic, strong) UIView *scopeHost;
@property (nonatomic, strong) UIScrollView *scopeStrip;
@property (nonatomic, strong) NSMutableArray *scopeButtons;
@property (nonatomic, assign) NSInteger scope;
@property (nonatomic, strong) NSArray *recentQueries;
@property (nonatomic, strong) UILabel *noResultsView;
@property (nonatomic, strong) NSArray *chatHits;
@property (nonatomic, strong) NSArray *messageHits;
/// Who this account talks to most, shown before anything is typed - their
/// search opens on this rather than on a blank screen.
@property (nonatomic, strong) NSArray *frequent;
/// Where this account was last, under the frequent list.
@property (nonatomic, strong) NSArray *recent;
/// Chats opened from search - Telegram's own recently-found log, which is
/// what the remove and clear buttons act on.
@property (nonatomic, strong) NSArray *recentlyFound;
/// Contacts Telegram matched, which is its own section: a person who is not
/// a chat yet has no row among the chats.
@property (nonatomic, strong) NSArray *contactHits;
/// Hashtags Telegram answers for the prefix, and the tags this account has
/// searched for before.
@property (nonatomic, strong) NSArray *hashtagHits;
@property (nonatomic, strong) NSArray *recentTags;
/// Chat titles and recent tags that start with the query, ranked by TDLib.
@property (nonatomic, strong) NSArray *suggestions;
/// Public posts matching the query. Raw message dictionaries; the row reads
/// the chat id for a title and the content for its line.
@property (nonatomic, strong) NSArray *publicHits;
/// What Telegram will charge for public post search, and the offset of the
/// next page. The footer says both.
@property (nonatomic, strong) NSDictionary *publicLimits;
@property (nonatomic, copy) NSString *publicNextOffset;
@property (nonatomic, assign) BOOL publicLimitExceeded;
/// The query waiting for the public-search debounce. Typing a word is one
/// search, not one per letter - public queries cost an allowance.
@property (nonatomic, copy) NSString *pendingPublicQuery;
/// t.me links this account followed before it had a chat list.
@property (nonatomic, strong) NSArray *recentLinks;
@end

/// The bar in the navigation item, which is narrower than the screen so the
/// Cancel button has somewhere to sit.
static const CGFloat kSearchBarWidth = 240.0f;

/// Telegram's scopes, in the order its search shows them. The integers are
/// the tag on each pill; the array index is the same, so a tag is the scope.
enum {
	TGSearchScopeAll = 0,
	TGSearchScopeChats,
	TGSearchScopeMessages,
	TGSearchScopeMedia,
	TGSearchScopeLinks,
	TGSearchScopeFiles,
	TGSearchScopeMusic,
	TGSearchScopeVoice,
};

static NSArray *TGSearchScopeTitles(void) {
	return @[@"All", @"Chats", @"Messages", @"Media", @"Links",
			 @"Files", @"Music", @"Voice"];
}

/// Old searches live in this app rather than on the account: Telegram stores
/// the log per device and clears it when the user says so, which is exactly
/// what NSUserDefaults is.
static NSString *const kRecentQueriesKey = @"TGSearchRecentQueries";
static const NSInteger kRecentQueriesLimit = 8;

/// A message hit's date, in the same short form the chat list uses.
static NSString *TGSearchDateText(NSNumber *stamp) {
	if (![stamp isKindOfClass:NSNumber.class] || ![stamp longLongValue])
		return @"";
	char buf[TGDateFormatBufferSize + 1] = {0};
	size_t len = TGChatDateFormat((time_t)[stamp doubleValue],
			(time_t)[[NSDate date] timeIntervalSince1970], buf,
			TGDateFormatBufferSize);
	return len ? [[NSString alloc] initWithBytes:buf length:len
									   encoding:NSUTF8StringEncoding] : @"";
}

static NSString *TGPublicPostText(NSDictionary *message) {
	NSDictionary *content = [message[@"content"] isKindOfClass:NSDictionary.class]
			? message[@"content"] : nil;
	NSDictionary *text = [content[@"text"] isKindOfClass:NSDictionary.class]
			? content[@"text"] : nil;
	if (![text[@"text"] isKindOfClass:NSString.class])
		text = [content[@"caption"] isKindOfClass:NSDictionary.class]
				? content[@"caption"] : nil;
	if ([text[@"text"] isKindOfClass:NSString.class])
		return [text[@"text"] stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *kind = [content[@"@type"] isKindOfClass:NSString.class]
			? content[@"@type"] : nil;
	if ([kind hasPrefix:@"message"])
		return [kind substringFromIndex:7];
	return @"";
}

@implementation TGSearchViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.chatHits = @[];
	self.messageHits = @[];
	self.hashtagHits = @[];
	self.recentTags = @[];
	self.suggestions = @[];
	self.publicHits = @[];
	self.recentLinks = @[];
	self.publicNextOffset = @"";
	self.publicLimitExceeded = NO;
	self.scope = TGSearchScopeAll;
	self.recentQueries = [[NSUserDefaults standardUserDefaults]
			arrayForKey:TGAccountDefaultsKey(kRecentQueriesKey)] ?: @[];
	self.tableView.rowHeight = TGMetricPersonRow;
	if ([self.tableView respondsToSelector:@selector(setKeyboardDismissMode:)])
		self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

	self.bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, kSearchBarWidth, TGMetricRow)];
	self.bar.delegate = self;
	self.bar.placeholder = @"Search";
	self.navigationItem.titleView = self.bar;
	self.navigationItem.hidesBackButton = YES;
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain
				   target:self action:@selector(cancel)];

	[self applyTheme];

	__weak typeof(self) weakSelf = self;
	[[NSNotificationCenter defaultCenter] addObserverForName:TGThemeChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note) {
		[weakSelf applyTheme];
		[weakSelf reloadSearchRows];
	}];

	[[NSNotificationCenter defaultCenter] addObserverForName:TGCustomEmojiLoadedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note) {
		TGSearchViewController *me = weakSelf;
		if (!me) return;
		[NSObject cancelPreviousPerformRequestsWithTarget:me selector:@selector(reloadVisibleRows) object:nil];
		[me performSelector:@selector(reloadVisibleRows) withObject:nil afterDelay:0.3];
	}];

	// A row's fate is not a control: the hold reaches what a tap cannot, and
	// the same pattern as the topics list carries it.
	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(rowHeld:)];
	hold.minimumPressDuration = 0.55;
	[self.tableView addGestureRecognizer:hold];

	[self buildScopeBar];
	[self rebuildSections];
	[self loadFrequentChats];
	[self loadRecentTags];
	[self loadRecentLinks];
	[self.bar becomeFirstResponder];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)reloadVisibleRows {
	NSArray *visible = [self.tableView indexPathsForVisibleRows];
	if (visible.count) {
		[self.tableView reloadRowsAtIndexPaths:visible withRowAnimation:UITableViewRowAnimationNone];
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];
	if (self.scopeHost && self.tableView.tableHeaderView == self.scopeHost)
		[self layoutScopeButtons];
	[self updateEmptyState];
}

/// A scope with nothing in it says so where the rows would be. The public
/// stories row is an action, not a result, so it does not count.
- (void)updateEmptyState {
	if (!self.bar.text.length || [self showsFrequent]){
		if (self.tableView.backgroundView)
			self.tableView.backgroundView = nil;
		return;
	}
	NSInteger rows = 0;
	for (NSInteger section = 0; section < [self numberOfSectionsInTableView:self.tableView];
		 section++){
		// The public-stories row is an action, not a result, so it does not
		// keep the no-results label away.
		if (section == 6)
			continue;
		rows += [self tableView:self.tableView numberOfRowsInSection:section];
	}
	if (rows > 0){
		if (self.tableView.backgroundView)
			self.tableView.backgroundView = nil;
		return;
	}
	if (!self.noResultsView){
		self.noResultsView = [[UILabel alloc] initWithFrame:CGRectZero];
		self.noResultsView.font = TGFontBody();
		self.noResultsView.textColor = [[TGTheme shared] secondaryTextColour];
		self.noResultsView.textAlignment = NSTextAlignmentCenter;
		self.noResultsView.numberOfLines = 0;
		self.noResultsView.backgroundColor = [UIColor clearColor];
	}
	NSString *query = self.bar.text ?: @"";
	self.noResultsView.text = [NSString stringWithFormat:@"%@\n%@",
			TGLocalized(@"No Results"),
			TGLocalizedFormat(@"There were no results for \"%@\".\nTry a new search.", query)];
	if (self.tableView.backgroundView != self.noResultsView)
		self.tableView.backgroundView = self.noResultsView;
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	self.view.backgroundColor = [theme listBackgroundColour];
	[theme stylePlainTable:self.tableView];
	[theme styleSearchBar:self.bar];
	[theme styleNavigationBar:self.navigationController.navigationBar];
	if (self.scopeHost){
		self.scopeHost.backgroundColor = [theme listBackgroundColour];
		[self styleScopeButtons];
	}
}

#pragma mark - scope bar

/// The pills are one row above the results, as Telegram's scopes are. They
/// only appear once there is a query: an empty search has no scope to narrow.
- (void)buildScopeBar {
	TGTheme *theme = [TGTheme shared];
	CGFloat width = self.view.bounds.size.width;

	self.scopeHost = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width,
			TGMetricSearchScopeRow)];
	self.scopeHost.backgroundColor = [theme listBackgroundColour];
	self.scopeHost.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	self.scopeStrip = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width,
			TGMetricSearchScopeRow)];
	self.scopeStrip.showsHorizontalScrollIndicator = NO;
	self.scopeStrip.showsVerticalScrollIndicator = NO;
	self.scopeStrip.alwaysBounceHorizontal = YES;
	self.scopeStrip.backgroundColor = [UIColor clearColor];
	self.scopeStrip.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.scopeHost addSubview:self.scopeStrip];

	self.scopeButtons = [NSMutableArray array];
	NSArray *titles = TGSearchScopeTitles();
	for (NSInteger i = 0; i < (NSInteger)titles.count; i++){
		UIButton *pill = [UIButton buttonWithType:UIButtonTypeCustom];
		pill.tag = i;
		pill.titleLabel.font = TGFontCaption();
		pill.layer.cornerRadius = TGHalf(TGMetricSearchScopeHeight);
		pill.clipsToBounds = YES;
		[pill addTarget:self action:@selector(scopeTapped:)
			  forControlEvents:UIControlEventTouchUpInside];
		[self.scopeStrip addSubview:pill];
		[self.scopeButtons addObject:pill];
	}
	[self styleScopeButtons];
	[self layoutScopeButtons];
}

- (void)styleScopeButtons {
	TGTheme *theme = [TGTheme shared];
	NSArray *titles = TGSearchScopeTitles();
	for (UIButton *pill in self.scopeButtons){
		BOOL selected = (pill.tag == self.scope);
		[pill setTitle:titles[(NSUInteger)pill.tag] forState:UIControlStateNormal];
		[pill setTitleColor:(selected ? [theme onAccentColour]
									 : [theme primaryTextColour])
				  forState:UIControlStateNormal];
		pill.backgroundColor = selected ? [theme accentColour]
									   : [theme cardBackgroundColour];
	}
}

- (void)layoutScopeButtons {
	CGFloat width = self.view.bounds.size.width;
	CGRect hostFrame = self.scopeHost.frame;
	hostFrame.size.width = width;
	self.scopeHost.frame = hostFrame;
	self.scopeStrip.frame = CGRectMake(0, 0, width, TGMetricSearchScopeRow);

	CGFloat x = TGMetricPad;
	CGFloat y = TGCenteredOrigin(TGMetricSearchScopeRow,
								 TGMetricSearchScopeHeight);
	for (UIButton *pill in self.scopeButtons){
		NSString *title = [pill titleForState:UIControlStateNormal] ?: @"";
		CGFloat textWidth = [title sizeWithFont:pill.titleLabel.font].width;
		CGFloat pillWidth = textWidth + TGDoubled(TGMetricPad);
		pill.frame = CGRectMake(x, y, pillWidth, TGMetricSearchScopeHeight);
		x += pillWidth + TGMetricSearchScopeGap;
	}
	self.scopeStrip.contentSize = CGSizeMake(x + TGMetricPad,
											 TGMetricSearchScopeRow);
}

- (void)setScopeBarVisible:(BOOL)visible {
	UIView *wanted = visible ? self.scopeHost : nil;
	if (self.tableView.tableHeaderView == wanted)
		return;
	self.tableView.tableHeaderView = wanted;
	if (visible)
		[self layoutScopeButtons];
}

- (void)scopeTapped:(UIButton *)pill {
	if (pill.tag < 0 || pill.tag >= (NSInteger)TGSearchScopeTitles().count)
		return;
	self.scope = pill.tag;
	[self styleScopeButtons];
	[self reloadSearchRows];
	[self.tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
}

#pragma mark - recent query log

- (void)rememberQuery:(NSString *)query {
	NSString *trimmed = [query stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!trimmed.length)
		return;
	NSMutableArray *fresh = [NSMutableArray arrayWithObject:trimmed];
	for (NSString *old in self.recentQueries)
		if (![old isEqualToString:trimmed] &&
			(NSInteger)fresh.count < kRecentQueriesLimit)
			[fresh addObject:old];
	self.recentQueries = fresh;
	[[NSUserDefaults standardUserDefaults] setObject:fresh
											  forKey:TGAccountDefaultsKey(kRecentQueriesKey)];
}

- (void)clearRecentQueries {
	self.recentQueries = @[];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:TGAccountDefaultsKey(kRecentQueriesKey)];
	[self reloadSearchRows];
}

- (void)cancel {
	[self.bar resignFirstResponder];
	[self.navigationController popViewControllerAnimated:YES];
}

/// Before a query there is nothing to match, and a blank list reads as a
/// broken screen. Telegram's own answer is the people you talk to most.
- (void)loadFrequentChats {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] topChatsWithCompletion:^(NSArray *chats){
		TGSearchViewController *me = weakSelf;
		if (!me || me.bar.text.length)
			return;
		me.frequent = chats ?: @[];
		[me reloadSearchRows];
	}];
	[[TGClient shared] recentlyOpenedChatsWithCompletion:^(NSArray *chats){
		TGSearchViewController *me = weakSelf;
		if (!me || me.bar.text.length)
			return;
		// What is already in the people row is not worth a second row.
		NSMutableSet *shown = [NSMutableSet set];
		for (NSDictionary *chat in me.frequent)
			if (chat[@"id"])
				[shown addObject:chat[@"id"]];
		NSMutableArray *rest = [NSMutableArray array];
		for (NSDictionary *chat in (chats ?: @[]))
			if (![shown containsObject:chat[@"id"]])
				[rest addObject:chat];
		me.recent = rest;
		[me reloadSearchRows];
	}];
	[self loadRecentlyFound];
}

- (void)loadRecentlyFound {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchRecentlyFoundChats:@"" completion:^(NSArray *chats){
		TGSearchViewController *me = weakSelf;
		if (!me || me.bar.text.length)
			return;
		me.recentlyFound = chats ?: @[];
		[me reloadSearchRows];
	}];
}

- (void)loadRecentTags {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] recentHashtagsWithCompletion:^(NSArray *tags){
		TGSearchViewController *me = weakSelf;
		if (!me || me.bar.text.length)
			return;
		me.recentTags = tags ?: @[];
		[me reloadSearchRows];
	}];
}

- (void)loadRecentLinks {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] recentlyVisitedTMeUrlsWithReferrer:@""
											   completion:^(NSArray *urls){
		TGSearchViewController *me = weakSelf;
		if (!me || me.bar.text.length)
			return;
		me.recentLinks = urls ?: @[];
		[me reloadSearchRows];
	}];
}

/// True while the search is empty, which is when the frequent list is what
/// the table shows.
- (BOOL)showsFrequent {
	return !self.bar.text.length &&
		   (self.frequent.count > 0 || self.recent.count > 0 ||
			self.recentlyFound.count > 0 || self.recentTags.count > 0 ||
			self.recentLinks.count > 0 || self.recentQueries.count > 0);
}

/// While the search is empty the sections are the people, the places, the
/// recently-found log, the tags and the links. A row is read out of whichever
/// list its section stands for.
- (NSDictionary *)emptyStateRowAt:(NSIndexPath *)indexPath {
	NSArray *list = nil;
	if (indexPath.section == 0)
		list = self.frequent;
	else if (indexPath.section == 1)
		list = self.recent;
	else if (indexPath.section == 2)
		list = self.recentlyFound;
	return indexPath.row < (NSInteger)list.count ? list[indexPath.row] : nil;
}

/// The hold lands wherever the finger is, so the row is found from the point;
/// a miss does nothing rather than guessing the last row. Only the people row
/// answers it: Telegram ranks that list by numbers, and the only say anyone
/// has over it is to take someone out of it. The places row is a log, not a
/// ranking, and a chat falls out of it by itself the next day. A recent tag
/// has two lists behind it and the sheet offers both removals.
- (void)rowHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan || !self.showsFrequent)
		return;
	CGPoint where = [hold locationInView:self.tableView];
	NSIndexPath *path = [self.tableView indexPathForRowAtPoint:where];
	if (!path)
		return;

	if (path.section == 5){
		if (path.row >= (NSInteger)self.recentQueries.count)
			return;
		NSString *query = self.recentQueries[path.row];
		NSMutableArray *rest = [self.recentQueries mutableCopy];
		[rest removeObject:query];
		self.recentQueries = rest;
		[[NSUserDefaults standardUserDefaults] setObject:rest
												  forKey:TGAccountDefaultsKey(kRecentQueriesKey)];
		[self reloadSearchRows];
		return;
	}

	if (path.section == 3){
		if (path.row >= (NSInteger)self.recentTags.count)
			return;
		NSString *tag = self.recentTags[path.row];
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:@[@"Remove from Recent", @"Remove"]
							title:[NSString stringWithFormat:@"#%@", tag]
				 destructiveIndex:-1
						   inView:self.view
						 onChoice:^(NSInteger index){
			TGSearchViewController *me = weakSelf;
			if (!me)
				return;
			if (index == 0)
				[[TGClient shared] removeRecentHashtag:tag];
			else
				[[TGClient shared] removeSearchedForTag:tag];
			NSMutableArray *rest = [me.recentTags mutableCopy];
			[rest removeObject:tag];
			me.recentTags = rest;
			[me reloadSearchRows];
		}];
		return;
	}

	if (path.section != 0 && path.section != 2)
		return;
	if (path.row >= (NSInteger)(path.section == 0 ? self.frequent.count
												 : self.recentlyFound.count))
		return;

	NSDictionary *chat = path.section == 0 ? self.frequent[path.row]
										   : self.recentlyFound[path.row];
	NSString *name = chat[@"title"] ?: @"Chats";
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:name
					   action:@"Remove"
				  destructive:NO
					   inView:self.view
					onConfirm:^{
		if (path.section == 0)
			[[TGClient shared] forgetTopChat:[chat[@"id"] longLongValue]];
		else
			[[TGClient shared] forgetRecentlyFoundChat:[chat[@"id"] longLongValue]];
		TGSearchViewController *me = weakSelf;
		if (!me)
			return;
		NSMutableArray *rest = [(path.section == 0 ? me.frequent
												   : me.recentlyFound) mutableCopy];
		[rest removeObject:chat];
		if (path.section == 0)
			me.frequent = rest;
		else
			me.recentlyFound = rest;
		[me reloadSearchRows];
	}];
}

#pragma mark - scope filtering

static BOOL TGSearchKindIsMedia(NSString *kind) {
	return [kind isEqualToString:@"messagePhoto"] ||
		   [kind isEqualToString:@"messageVideo"] ||
		   [kind isEqualToString:@"messageAnimation"] ||
		   [kind isEqualToString:@"messageVideoNote"];
}

static BOOL TGSearchKindIsFile(NSString *kind) {
	return [kind isEqualToString:@"messageDocument"];
}

static BOOL TGSearchKindIsMusic(NSString *kind) {
	return [kind isEqualToString:@"messageAudio"];
}

static BOOL TGSearchKindIsVoice(NSString *kind) {
	return [kind isEqualToString:@"messageVoiceNote"];
}

/// TDLib hands search results as whole messages; the scope is a filter over
/// the same answer rather than a second request, which is why switching a
/// pill is instant on a 4S.
static BOOL TGSearchMessageHasLink(NSDictionary *message) {
	NSString *text = [message[@"text"] isKindOfClass:NSString.class]
			? message[@"text"] : @"";
	if (!text.length)
		return NO;
	NSString *lower = text.lowercaseString;
	return [lower rangeOfString:@"http://"].location != NSNotFound ||
		   [lower rangeOfString:@"https://"].location != NSNotFound ||
		   [lower rangeOfString:@"www."].location != NSNotFound ||
		   [lower rangeOfString:@"t.me/"].location != NSNotFound ||
		   [lower rangeOfString:@"tg://"].location != NSNotFound;
}

static BOOL TGSearchMessageMatchesScope(NSDictionary *message, NSInteger scope) {
	NSString *kind = [message[@"kind"] isKindOfClass:NSString.class]
			? message[@"kind"] : @"";
	switch (scope){
		case TGSearchScopeMedia: return TGSearchKindIsMedia(kind);
		case TGSearchScopeLinks: return TGSearchMessageHasLink(message);
		case TGSearchScopeFiles: return TGSearchKindIsFile(kind);
		case TGSearchScopeMusic: return TGSearchKindIsMusic(kind);
		case TGSearchScopeVoice: return TGSearchKindIsVoice(kind);
		default: return YES;
	}
}

/// The messages the current scope shows. All and Messages are the same list;
/// the other scopes narrow it by what the message carries.
- (NSArray *)scopedMessageHits {
	if (self.scope == TGSearchScopeAll || self.scope == TGSearchScopeMessages)
		return self.messageHits;
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *message in self.messageHits)
		if (TGSearchMessageMatchesScope(message, self.scope))
			[out addObject:message];
	return out;
}

- (BOOL)scopeShowsChats {
	return self.scope == TGSearchScopeAll || self.scope == TGSearchScopeChats;
}

- (BOOL)scopeShowsMessages {
	return self.scope == TGSearchScopeAll || self.scope >= TGSearchScopeMessages;
}

- (BOOL)scopeShowsPublic {
	return self.scope == TGSearchScopeAll;
}

#pragma mark - searching

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)query {
	if (!query.length) {
		self.chatHits = @[];
		self.messageHits = @[];
		self.contactHits = @[];
		self.hashtagHits = @[];
		self.suggestions = @[];
		self.publicHits = @[];
		self.publicLimits = nil;
		self.publicLimitExceeded = NO;
		self.pendingPublicQuery = nil;
		self.scope = TGSearchScopeAll;
		[self styleScopeButtons];
		[self setScopeBarVisible:NO];
		[NSObject cancelPreviousPerformRequestsWithTarget:self
				selector:@selector(flushPublicSearch) object:nil];
		// Back to the people and the places rather than to nothing.
		[self loadFrequentChats];
		[self loadRecentTags];
		[self loadRecentLinks];
		[self reloadSearchRows];
		return;
	}

	// A new query starts on All, as Telegram's does; the pills narrow the
	// same answer once the user picks one.
	[self setScopeBarVisible:YES];

	// The loaded list first, so there is something on screen before the
	// server answers; what comes back replaces it.
	NSMutableArray *titles = [NSMutableArray array];
	for (NSDictionary *c in [TGClient shared].chats)
		if ([c[@"title"] rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound)
			[titles addObject:c];
	self.chatHits = titles;
	self.hashtagHits = @[];
	self.suggestions = @[];
	self.publicHits = @[];
	self.publicLimitExceeded = NO;
	[self reloadSearchRows];

	__weak typeof(self) weakSelf = self;
	// Matching titles here only ever found chats already loaded, so a chat
	// this account has and has not opened, and every public chat, were
	// unfindable by name.
	[[TGClient shared] searchChatsForQuery:query completion:^(NSArray *chats){
		TGSearchViewController *me = weakSelf;
		if (!me || ![me.bar.text isEqualToString:query]) return;
		me.chatHits = chats ?: @[];
		[me refreshPrefixSuggestionsForQuery:query extra:@[]];
		[me reloadSearchRows];
	}];
	[[TGClient shared] searchContactsForQuery:query completion:^(NSArray *users){
		TGSearchViewController *me = weakSelf;
		if (!me || ![me.bar.text isEqualToString:query]) return;
		me.contactHits = users ?: @[];
		[me reloadSearchRows];
	}];
	[[TGClient shared] searchMessages:query completion:^(NSArray *messages) {
		TGSearchViewController *me = weakSelf;
		if (!me || ![me.bar.text isEqualToString:query]) return;
		me.messageHits = messages ?: @[];
		[me reloadSearchRows];
	}];
	[[TGClient shared] searchHashtags:query limit:10 completion:^(NSArray *tags){
		TGSearchViewController *me = weakSelf;
		if (!me || ![me.bar.text isEqualToString:query]) return;
		me.hashtagHits = tags ?: @[];
		[me refreshPrefixSuggestionsForQuery:query extra:tags];
		[me reloadSearchRows];
	}];
	[self refreshPrefixSuggestionsForQuery:query extra:@[]];
	[self searchPublicPostsForQuery:query];
}

/// Prefix suggestions are a local problem: the strings are the chat titles
/// this account already has and the tags it searched for. TDLib does the
/// word-prefix match, which is why "te leg" and "tel" agree here.
- (void)refreshPrefixSuggestionsForQuery:(NSString *)query extra:(NSArray *)extra {
	NSMutableArray *strings = [NSMutableArray array];
	for (NSDictionary *chat in [TGClient shared].chats){
		NSString *title = chat[@"title"];
		if (title.length && ![strings containsObject:title])
			[strings addObject:title];
	}
	for (NSString *tag in self.recentTags){
		NSString *hashed = [@"#" stringByAppendingString:tag];
		if (![strings containsObject:hashed])
			[strings addObject:hashed];
	}
	for (NSString *tag in extra ?: @[]){
		NSString *hashed = [@"#" stringByAppendingString:tag];
		if (![strings containsObject:hashed])
			[strings addObject:hashed];
	}
	if (!strings.count)
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] stringsMatchingPrefix:strings query:query limit:10
								  completion:^(NSArray *matches){
		TGSearchViewController *me = weakSelf;
		if (!me || ![me.bar.text isEqualToString:query])
			return;
		me.suggestions = matches ?: @[];
		[me reloadSearchRows];
	}];
}

/// Public post search costs a server query, and Telegram says how many are
/// free before it is asked. The limit answer is shown whether or not the
/// search goes ahead, so a blocked row says why instead of looking broken.
/// The wait is one query per typed word rather than one per key.
- (void)searchPublicPostsForQuery:(NSString *)query {
	self.pendingPublicQuery = query;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(flushPublicSearch) object:nil];
	[self performSelector:@selector(flushPublicSearch)
			   withObject:nil afterDelay:0.4];
}

- (void)flushPublicSearch {
	NSString *query = self.pendingPublicQuery;
	if (!query.length || ![self.bar.text isEqualToString:query])
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] publicPostSearchLimitsForQuery:query completion:^(NSDictionary *limits){
		TGSearchViewController *me = weakSelf;
		if (!me || ![me.bar.text isEqualToString:query])
			return;
		me.publicLimits = limits;
		if (limits &&
			![limits[@"currentIsFree"] boolValue] &&
			[limits[@"remainingFree"] integerValue] <= 0){
			me.publicLimitExceeded = YES;
			[me reloadSearchRows];
			return;
		}
		[[TGClient shared] searchPublicPosts:query offset:@"" limit:20 starCount:0
								  completion:^(NSArray *messages, NSString *next,
											   NSDictionary *answerLimits, BOOL exceeded){
			TGSearchViewController *live = weakSelf;
			if (!live || ![live.bar.text isEqualToString:query])
				return;
			live.publicHits = messages ?: @[];
			live.publicNextOffset = next ?: @"";
			if (answerLimits)
				live.publicLimits = answerLimits;
			live.publicLimitExceeded = exceeded;
			[live reloadSearchRows];
		}];
	}];
}

- (void)loadMorePublicPosts {
	NSString *query = self.bar.text;
	NSString *offset = self.publicNextOffset;
	if (!query.length || !offset.length || self.publicLimitExceeded)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchPublicPosts:query offset:offset limit:20 starCount:0
							  completion:^(NSArray *messages, NSString *next,
										   NSDictionary *limits, BOOL exceeded){
		TGSearchViewController *me = weakSelf;
		if (!me || ![me.bar.text isEqualToString:query])
			return;
		NSMutableArray *joined = [me.publicHits mutableCopy];
		[joined addObjectsFromArray:messages ?: @[]];
		me.publicHits = joined;
		me.publicNextOffset = next ?: @"";
		if (limits)
			me.publicLimits = limits;
		me.publicLimitExceeded = exceeded;
		[me reloadSearchRows];
	}];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[self rememberQuery:searchBar.text];
	[searchBar resignFirstResponder];
}

#pragma mark - rows

- (void)reloadSearchRows {
	[self rebuildSections];
	[self.tableView reloadData];
}

- (void)rebuildSections {
	self.sections = [self showsFrequent] ? [self frequentSections]
			: [self searchSections];
}

- (NSString *)publicFooter {
	if (self.scope != TGSearchScopeAll)
		return nil;
	if (self.publicLimitExceeded){
		NSInteger wait = [self.publicLimits[@"nextFreeIn"] integerValue];
		if (wait > 0){
			NSInteger minutes = MAX(1, (wait + 59) / 60);
			// The pack's own sentence already contains "in"; appending the
			// "in %@ minutes" phrase produced "in in 15 minutes".
			NSString *duration = TGLocalizedFormat(@"%@ minutes", @(minutes));
			return TGLocalizedFormat(@"free search unlocks in %@", duration);
		}
		return TGLocalized(@"No Results");
	}
	NSInteger left = [self.publicLimits[@"remainingFree"] integerValue];
	if (self.publicLimits && left > 0)
		return TGLocalizedFormat(@"%@ free searches remaining today.", @(left));
	return nil;
}

- (NSMutableDictionary *)peerRowForChat:(NSDictionary *)chat detail:(id)detail {
	int64_t chatId = [chat[@"id"] longLongValue];
	NSString *title = [chat[@"title"] length] ? chat[@"title"] : @"Loading...";
	NSString *line = [detail isKindOfClass:NSString.class] ? detail : nil;
	NSMutableDictionary *row = TGPeerRow(@(chatId), title, line, nil);
	// The cell asks the peer store for the picture when the row is on screen;
	// building a hit list must not start fifty downloads or draw fifty
	// initials the user will never see.
	row[TGRowAvatarUser] = @(chatId > 0);
	return row;
}

- (NSMutableDictionary *)peerRowForContact:(NSDictionary *)contact {
	int64_t userId = [contact[@"id"] longLongValue];
	NSString *name = [contact[@"name"] length] ? contact[@"name"]
			: [[TGClient shared] nameForUserId:userId];
	NSMutableDictionary *row = TGPeerRow(@(userId), name ?: @"", nil, nil);
	row[TGRowAvatarUser] = @YES;
	int64_t statusId = [[TGClient shared] emojiStatusIdForUser:userId];
	if (statusId > 0)
		row[TGRowStatusEmojiId] = @(statusId);
	return row;
}

- (NSMutableDictionary *)messageResultFor:(NSDictionary *)m
								  chatKey:(NSString *)chatKey
								   titleKey:(NSString *)titleKey
									textKey:(NSString *)textKey {
	int64_t chatId = [m[chatKey] longLongValue];
	NSString *title = [m[titleKey] length] ? m[titleKey]
			: [[TGClient shared] titleForChat:chatId] ?: @"Post";
	NSString *text = textKey.length ? m[textKey] : TGPublicPostText(m);
	NSString *date = TGSearchDateText(m[@"date"]);
	int64_t messageId = [m[@"id"] longLongValue];
	__weak typeof(self) weakSelf = self;
	NSMutableDictionary *row = TGMessageResultRow(@(chatId), title, text, date, ^{
		[weakSelf openChatId:chatId title:title messageId:messageId isGroup:NO];
	});
	return row;
}

- (void)openChatId:(int64_t)chatId title:(NSString *)title
		 messageId:(int64_t)messageId isGroup:(BOOL)isGroup {
	if (!chatId)
		return;
	[self.bar resignFirstResponder];
	[[TGClient shared] rememberFoundChat:chatId];
	[self rememberQuery:self.bar.text];
	TGChatViewController *chat = [[TGChatViewController alloc] init];
	chat.chatId = chatId;
	chat.chatTitle = title;
	chat.isGroup = isGroup;
	if (messageId)
		chat.initialMessageId = messageId;
	chat.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:chat animated:YES];
}

- (void)openContactHit:(NSDictionary *)u {
	int64_t userId = [u[@"id"] longLongValue];
	NSString *name = [u[@"name"] length] ? u[@"name"]
			: [[TGClient shared] nameForUserId:userId];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] privateChatWithUser:userId completion:^(int64_t privateId){
		TGSearchViewController *me = weakSelf;
		if (!me || !privateId)
			return;
		[me openChatId:privateId title:name ?: @"" messageId:0 isGroup:NO];
	}];
}

- (void)applyQuery:(NSString *)query {
	self.bar.text = query;
	[self searchBar:self.bar textDidChange:query];
}

- (NSDictionary *)clearRowWithTitle:(NSString *)title
							 handler:(void (^)(void))handler {
	return TGRedRow(title, handler);
}

- (NSArray *)frequentSections {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *people = [NSMutableArray array];
	for (NSDictionary *chat in self.frequent){
		NSMutableDictionary *row = [self peerRowForChat:chat
				detail:chat[@"previewText"]];
		int64_t chatId = [chat[@"id"] longLongValue];
		int64_t statusId = [chat[@"emojiStatusId"] longLongValue];
		if (statusId == 0 && chatId > 0)
			statusId = [[TGClient shared] emojiStatusIdForUser:chatId];
		if (statusId > 0)
			row[TGRowStatusEmojiId] = @(statusId);
		row[TGRowTap] = ^{ [weakSelf openChatId:chatId
				title:chat[@"title"] ?: @"" messageId:0
				isGroup:[chat[@"isGroup"] boolValue]]; };
		[people addObject:row];
	}

	NSMutableArray *recent = [NSMutableArray array];
	for (NSDictionary *chat in self.recent){
		NSMutableDictionary *row = [self peerRowForChat:chat
				detail:chat[@"previewText"]];
		int64_t chatId = [chat[@"id"] longLongValue];
		row[TGRowTap] = ^{ [weakSelf openChatId:chatId
				title:chat[@"title"] ?: @"" messageId:0
				isGroup:[chat[@"isGroup"] boolValue]]; };
		[recent addObject:row];
	}

	NSMutableArray *found = [NSMutableArray array];
	for (NSDictionary *chat in self.recentlyFound){
		NSMutableDictionary *row = [self peerRowForChat:chat
				detail:chat[@"previewText"]];
		int64_t chatId = [chat[@"id"] longLongValue];
		row[TGRowTap] = ^{ [weakSelf openChatId:chatId
				title:chat[@"title"] ?: @"" messageId:0
				isGroup:[chat[@"isGroup"] boolValue]]; };
		[found addObject:row];
	}
	if (found.count)
		[found addObject:[self clearRowWithTitle:@"Clear" handler:^{
			[TGAlertSheet showConfirm:nil title:@"Clear" action:@"Clear"
					destructive:YES inView:weakSelf.view onConfirm:^{
				[[TGClient shared] clearRecentlyFoundChats];
				weakSelf.recentlyFound = @[];
				[weakSelf reloadSearchRows];
			}];
		}]];

	NSMutableArray *tags = [NSMutableArray array];
	for (NSString *tag in self.recentTags){
		NSMutableDictionary *row = [TGTapRow([NSString stringWithFormat:@"#%@", tag],
				@"Recent", ^{ [weakSelf applyQuery:[NSString stringWithFormat:@"#%@", tag]]; })
				mutableCopy];
		row[TGRowIcon] = @"search";
		row[TGRowColour] = [[TGTheme shared] secondaryTextColour];
		[tags addObject:row];
	}
	if (tags.count)
		[tags addObject:[self clearRowWithTitle:@"Clear" handler:^{
			[TGAlertSheet showConfirm:@"Do you want to clear your search history?"
					title:@"Clear" action:@"Clear" destructive:YES
					inView:weakSelf.view onConfirm:^{
				[[TGClient shared] clearSearchedForTags];
				weakSelf.recentTags = @[];
				[weakSelf reloadSearchRows];
			}];
		}]];

	NSMutableArray *links = [NSMutableArray array];
	for (NSDictionary *link in self.recentLinks){
		NSString *url = link[@"url"] ?: @"";
		NSDictionary *row = TGTapRow(url, nil, ^{
			[weakSelf openRecentTMeLink:url];
		});
		[links addObject:row];
	}

	NSMutableArray *queries = [NSMutableArray array];
	for (NSString *query in self.recentQueries){
		NSMutableDictionary *row = [TGTapRow(query, @"Recent", ^{
			[weakSelf applyQuery:query];
		}) mutableCopy];
		row[TGRowIcon] = @"search";
		row[TGRowColour] = [[TGTheme shared] secondaryTextColour];
		[queries addObject:row];
	}
	if (queries.count)
		[queries addObject:[self clearRowWithTitle:@"Clear" handler:^{
			[TGAlertSheet showConfirm:@"Do you want to clear your search history?"
					title:@"Clear" action:@"Clear" destructive:YES
					inView:weakSelf.view onConfirm:^{
				[weakSelf clearRecentQueries];
			}];
		}]];

	return @[
		TGSection(self.frequent.count ? @"People" : nil, nil, people),
		TGSection(self.recent.count ? @"Recent" : nil, nil, recent),
		TGSection(self.recentlyFound.count ? @"Recent" : nil, nil, found),
		TGSection(self.recentTags.count ? @"Hashtag search" : nil, nil, tags),
		TGSection(self.recentLinks.count ? @"RECENTLY VISITED" : nil, nil, links),
		TGSection(nil, nil, queries),
	];
}

- (NSArray *)searchSections {
	__weak typeof(self) weakSelf = self;
	BOOL all = self.scope == TGSearchScopeAll;
	BOOL chats = [self scopeShowsChats];
	NSArray *messages = [self scopedMessageHits];

	NSMutableArray *suggestions = [NSMutableArray array];
	if (all)
		for (NSString *suggestion in self.suggestions){
			[suggestions addObject:TGTapRow(suggestion, @"Suggest", ^{
				[weakSelf applyQuery:suggestion];
			})];
		}

	NSMutableArray *chatRows = [NSMutableArray array];
	if (chats)
		for (NSDictionary *chat in self.chatHits){
			NSMutableDictionary *row = [self peerRowForChat:chat
					detail:chat[@"text"]];
			int64_t chatId = [chat[@"id"] longLongValue];
			row[TGRowTap] = ^{ [weakSelf openChatId:chatId
					title:chat[@"title"] ?: @"" messageId:0
					isGroup:[chat[@"isGroup"] boolValue]]; };
			[chatRows addObject:row];
		}

	NSMutableArray *contactRows = [NSMutableArray array];
	if (chats)
		for (NSDictionary *contact in self.contactHits){
			NSMutableDictionary *row = [self peerRowForContact:contact];
			row[TGRowTap] = ^{ [weakSelf openContactHit:contact]; };
			[contactRows addObject:row];
		}

	NSMutableArray *messageRows = [NSMutableArray array];
	if (self.scope != TGSearchScopeChats)
		for (NSDictionary *m in messages){
			NSMutableDictionary *row = [self messageResultFor:m
					chatKey:@"chatId" titleKey:@"chatTitle" textKey:@"text"];
			[messageRows addObject:row];
		}

	NSMutableArray *hashtags = [NSMutableArray array];
	if (self.scope != TGSearchScopeChats)
		for (NSString *tag in self.hashtagHits){
			NSString *hashed = [NSString stringWithFormat:@"#%@", tag];
			[hashtags addObject:TGTapRow(hashed, @"Public Post Search", ^{
				[weakSelf applyQuery:hashed];
			})];
		}

	NSMutableArray *publicRows = [NSMutableArray array];
	NSString *publicFooter = nil;
	if ([self scopeShowsPublic]){
		for (NSDictionary *m in self.publicHits){
			NSMutableDictionary *row = [self messageResultFor:m
					chatKey:@"chat_id" titleKey:@"chatTitle" textKey:@""];
			[publicRows addObject:row];
		}
		if (self.publicNextOffset.length && !self.publicLimitExceeded)
			[publicRows addObject:TGActionRow(@"Public Posts", ^{
				[weakSelf loadMorePublicPosts];
			})];
		publicFooter = [self publicFooter];
	}

	NSMutableArray *stories = [NSMutableArray array];
	if ([self scopeShowsPublic]){
		NSMutableDictionary *row = TGPeerRow(nil, @"Stories", nil, ^{
			TGPublicStoriesViewController *viewer =
					[[TGPublicStoriesViewController alloc]
							initWithTag:weakSelf.bar.text ?: @""];
			viewer.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:viewer animated:YES];
		});
		row[TGRowAccessory] = TGRowAccessoryDisclosure;
		[stories addObject:row];
	}

	NSString *messagesHeader = nil;
	if (self.scope != TGSearchScopeChats && messages.count)
		messagesHeader = all ? @"Messages"
				: TGSearchScopeTitles()[(NSUInteger)self.scope];

	return @[
		TGSection(all && suggestions.count ? @"Suggested Chats" : nil, nil, suggestions),
		TGSection(chatRows.count ? @"Chats" : nil, nil, chatRows),
		TGSection(contactRows.count ? @"Contacts" : nil, nil, contactRows),
		TGSection(messagesHeader, nil, messageRows),
		TGSection(all && hashtags.count ? @"Hashtag search" : nil, nil, hashtags),
		TGSection(all && publicRows.count ? @"Public Posts" : nil,
				publicFooter, publicRows),
		TGSection(all ? @"Stories" : nil, nil, stories),
	];
}

/// Telegram's own link handler, trimmed to what a recent t.me URL can be:
/// a chat, a message, an invite or a plain address.
- (void)openRecentTMeLink:(NSString *)link {
	if (!link.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] internalLinkKind:link completion:^(NSString *kind, NSString *value){
		TGSearchViewController *me = weakSelf;
		if (!me)
			return;
		if ([kind isEqualToString:@"publicChat"] && value.length){
			[[TGClient shared] chatWithUsername:value completion:^(int64_t chatId, NSString *title){
				TGSearchViewController *live = weakSelf;
				if (!live || !chatId)
					return;
				TGChatViewController *chat = [[TGChatViewController alloc] init];
				chat.chatId = chatId;
				chat.chatTitle = title.length ? title : value;
				chat.hidesBottomBarWhenPushed = YES;
				[live.navigationController pushViewController:chat animated:YES];
			}];
			return;
		}
		if ([kind isEqualToString:@"message"] && value.length){
			[[TGClient shared] messageLinkInfo:value completion:^(int64_t chatId, int64_t messageId){
				TGSearchViewController *live = weakSelf;
				if (!live || !chatId)
					return;
				TGChatViewController *chat = [[TGChatViewController alloc] init];
				chat.chatId = chatId;
				chat.chatTitle = [[TGClient shared] titleForChat:chatId] ?: @"Chat";
				chat.initialMessageId = messageId;
				chat.hidesBottomBarWhenPushed = YES;
				[live.navigationController pushViewController:chat animated:YES];
			}];
			return;
		}
		if ([kind isEqualToString:@"inviteLink"] && value.length){
			[[TGClient shared] joinChatByInviteLink:value completion:^(int64_t chatId, NSString *title){
				TGSearchViewController *live = weakSelf;
				if (!live || !chatId)
					return;
				TGChatViewController *chat = [[TGChatViewController alloc] init];
				chat.chatId = chatId;
				chat.chatTitle = title.length ? title : @"Chat";
				chat.hidesBottomBarWhenPushed = YES;
				[live.navigationController pushViewController:chat animated:YES];
			}];
			return;
		}
		NSURL *url = [NSURL URLWithString:link];
		if (url)
			[[UIApplication sharedApplication] openURL:url];
	}];
}

@end

// vim:ft=objc
