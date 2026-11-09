#import "TGForwardPicker.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGUIFormat.h"
#import "TGStyle.h"
#import "TGChatParityModel.h"
#import "TGRows.h"

/// The sheet's title view: "Share" over "Select Chats", as official has it.
static const CGFloat kPickerTitleWidth  = TGMetricShareTitleWidth;
static const CGFloat kPickerTitleHeight = TGMetricRow;
static const CGFloat kPickerRowHeight   = TGMetricShareRow;
static const CGFloat kPickerPanelHeight = TGMetricRow;

@interface TGForwardPicker () <UISearchBarDelegate>
@property (nonatomic, strong) NSArray *chats;
@property (nonatomic, strong) NSArray *recentChats;
@property (nonatomic, strong) NSMutableDictionary *avatars;   // fileId -> UIImage
@property (nonatomic, strong) NSMutableSet *avatarsRequested;
@property (nonatomic, strong) NSMutableSet *selectedChatIds;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UILabel *sendCountLabel;
@property (nonatomic, copy) NSString *query;
@end

@implementation TGForwardPicker

- (instancetype)init {
	return [super initWithStyle:UITableViewStylePlain];
}

- (void)applyTheme {
	[super applyTheme];
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.chats = [TGClient shared].chats ?: @[];
	self.recentChats = @[];
	self.avatars = [NSMutableDictionary dictionary];
	self.avatarsRequested = [NSMutableSet set];
	self.selectedChatIds = [NSMutableSet set];
	self.query = @"";

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	// The sheet's bar: X on the left, a two-line Share / Select Chats title,
	// no right item. The count lives on the Send button at the bottom.
	UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
	close.frame = CGRectMake(0, 0, TGMetricRow, TGMetricRow);
	[close setImage:[TGIcons glyphNamed:@"close"
								 colour:[[TGTheme shared] barButtonColour]
								   side:TGMetricMenuGlyph]
		   forState:UIControlStateNormal];
	[close addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:close];
	self.navigationItem.rightBarButtonItem = nil;

	[self buildTitleView];

	self.searchBar = [[UISearchBar alloc] initWithFrame:
			CGRectMake(0, 0, self.tableView.bounds.size.width, TGMetricRow)];
	self.searchBar.placeholder = @"Search";
	self.searchBar.delegate = self;
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[[TGTheme shared] styleSearchBar:self.searchBar];
	self.tableView.tableHeaderView = self.searchBar;

	[self buildSendPanel];

	__weak typeof(self) weakSelf = self;
	[[NSNotificationCenter defaultCenter] addObserverForName:TGThemeChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){
		TGForwardPicker *me = weakSelf;
		if (!me) return;
		[TGIcons flush];
		[me applyTheme];
		[[TGTheme shared] styleSearchBar:me.searchBar];
		[me rebuildSections];
	}];

	[self fetchMissingAvatars];
	[self updateSendItem];
	[self rebuildSections];

	[[TGClient shared] topChatsWithCompletion:^(NSArray *chats){
		TGForwardPicker *me = weakSelf;
		if (!me)
			return;
		me.recentChats = chats ?: @[];
		[me fetchMissingAvatars];
		[me rebuildSections];
		[me updateEmptyState];
	}];
}

- (void)buildTitleView {
	UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kPickerTitleWidth,
			kPickerTitleHeight)];
	UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, TGMetricBorderWidth,
			kPickerTitleWidth, TGMetricLineRow)];
	title.text = @"Share";
	title.font = TGFontHeader();
	title.textColor = [[TGTheme shared] barTitleColour];
	title.textAlignment = NSTextAlignmentCenter;
	title.backgroundColor = [UIColor clearColor];
	title.shadowColor = [[TGTheme shared] navBarTextShadowColour];
	title.shadowOffset = TGMetricShadowOffsetNav;
	[box addSubview:title];

	UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(0,
			TGMetricBorderWidth + TGMetricLineRow, kPickerTitleWidth, TGMetricLineMicro)];
	subtitle.text = @"Select Chats";
	subtitle.font = TGFontMeta();
	subtitle.textColor = [[TGTheme shared] barSubtitleColour];
	subtitle.textAlignment = NSTextAlignmentCenter;
	subtitle.backgroundColor = [UIColor clearColor];
	[box addSubview:subtitle];
	self.navigationItem.titleView = box;
}

- (void)buildSendPanel {
	UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(0,
			self.view.bounds.size.height - kPickerPanelHeight,
			self.view.bounds.size.width, kPickerPanelHeight)];
	panel.tag = 0x71A1;
	panel.backgroundColor = [[TGTheme shared] inputBarColour];
	panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

	UIView *hair = [[UIView alloc] initWithFrame:CGRectMake(0, 0,
			panel.bounds.size.width, TGMetricHairline)];
	hair.backgroundColor = [[TGTheme shared] separatorColour];
	hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[panel addSubview:hair];

	self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.sendButton.frame = CGRectMake(TGMetricPadLarge, TGMetricPadSmall,
			panel.bounds.size.width - TGDoubled(TGMetricPadLarge),
			kPickerPanelHeight - TGDoubled(TGMetricPadSmall));
	self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.sendButton.titleLabel.font = TGFontBodyStrong();
	[self.sendButton setTitle:TGLocalized(@"Send") forState:UIControlStateNormal];
	[self.sendButton setTitleColor:[[TGTheme shared] onAccentColour] forState:UIControlStateNormal];
	self.sendButton.backgroundColor = [[TGTheme shared] accentColour];
	self.sendButton.layer.cornerRadius = TGMetricCornerControl;
	[self.sendButton addTarget:self action:@selector(send) forControlEvents:UIControlEventTouchUpInside];
	[panel addSubview:self.sendButton];

	self.sendCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMaxX(self.sendButton.frame) - TGMetricRow,
			CGRectGetMinY(self.sendButton.frame), TGMetricPadLarge, self.sendButton.bounds.size.height)];
	self.sendCountLabel.font = TGFontCaptionStrong();
	self.sendCountLabel.textColor = [[TGTheme shared] onAccentColour];
	self.sendCountLabel.textAlignment = NSTextAlignmentCenter;
	self.sendCountLabel.backgroundColor = [UIColor clearColor];
	self.sendCountLabel.hidden = YES;
	[panel addSubview:self.sendCountLabel];

	[self.view addSubview:panel];
	UIEdgeInsets insets = self.tableView.contentInset;
	insets.bottom = kPickerPanelHeight;
	self.tableView.contentInset = insets;
	self.tableView.scrollIndicatorInsets = insets;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)cancel {
	if (self.navigationController && self.navigationController.viewControllers.count > 1 &&
		self.navigationController.viewControllers.firstObject != self){
		[self.navigationController popViewControllerAnimated:YES];
	} else {
		[self dismissViewControllerAnimated:YES completion:nil];
	}
}

#pragma mark - what the table shows

- (NSArray *)matchingChats {
	// With no query the sheet shows the people this account talks to most,
	// which is official's recent list; typing searches the whole chat list.
	NSArray *base = self.query.length
			? self.chats
			: (self.recentChats.count ? self.recentChats : self.chats);
	int64_t saved = [[TGClient shared] savedMessagesChatId];
	NSMutableArray *matches = [NSMutableArray array];
	for (NSDictionary *chat in base) {
		int64_t chatId = [chat[@"id"] longLongValue];
		if (chatId == self.sourceChatId || chatId == saved)
			continue;
		NSString *title = chat[@"title"] ?: @"";
		NSString *username = chat[@"username"] ?: @"";
		if (TGUIFormatChatMatches(title, self.query) ||
				TGUIFormatChatMatches(username, self.query))
			[matches addObject:chat];
	}
	return matches;
}

- (void)updateSendItem {
	NSUInteger count = self.selectedChatIds.count;
	self.sendButton.enabled = count > 0;
	self.sendButton.alpha = count > 0 ? TGAlphaOpaque : TGAlphaDisabled;
	self.sendCountLabel.text = count > 0 ? [NSString stringWithFormat:@"%lu",
			(unsigned long)count] : @"";
	self.sendCountLabel.hidden = count == 0;
	[self updateEmptyState];
}

- (void)updateEmptyState {
	BOOL empty = [self matchingChats].count == 0;
	if (!empty){
		if (self.tableView.backgroundView)
			self.tableView.backgroundView = nil;
		return;
	}
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
	label.font = TGFontBody();
	label.textColor = [[TGTheme shared] secondaryTextColour];
	label.textAlignment = NSTextAlignmentCenter;
	label.text = TGLocalized(@"No Results");
	self.tableView.backgroundView = label;
}

- (NSArray *)selectedChatIdsInOrder {
	return TGSelectedChatIdsInOrder(self.chats, self.selectedChatIds);
}

- (void)send {
	NSArray *ids = [self selectedChatIdsInOrder];
	if (!ids.count)
		return;
	if (self.onPicked)
		for (NSNumber *chatId in ids)
			self.onPicked(chatId.longLongValue);
	[self cancel];
}

- (void)fetchMissingAvatars {
	__weak typeof(self) weakSelf = self;
	CGFloat side = TGMetricListAvatar;
	for (NSDictionary *c in self.chats){
		NSNumber *fileId = c[@"photoFileId"];
		if (![fileId isKindOfClass:NSNumber.class] || self.avatars[fileId] || [self.avatarsRequested containsObject:fileId])
			continue;
		[self.avatarsRequested addObject:fileId];

		[[TGClient shared] downloadFile:[fileId integerValue] completion:^(NSString *path){
			if (!path.length) return;
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
				UIImage *photo = [UIImage imageWithContentsOfFile:path];
				if (!photo) return;
				// Bake the circle into the bitmap: a corner radius on a
				// recycled scrolling layer is the mask the design rules ban.
				UIImage *rounded = [TGIcons roundedImage:photo
													size:CGSizeMake(side, side)
											  radius:TGHalf(side)
											 corners:UIRectCornerAllCorners];
				dispatch_async(dispatch_get_main_queue(), ^{
					TGForwardPicker *me = weakSelf;
					if (!me || !rounded) return;
					me.avatars[fileId] = rounded;
					[me rebuildSections];
				});
			});
		}];
	}
}

#pragma mark - search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	self.query = [searchText stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	[self updateEmptyState];
	[self rebuildSections];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

#pragma mark - rows

- (void)rebuildSections {
	NSArray *matches = [self matchingChats];
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:matches.count];
	__weak typeof(self) weakSelf = self;
	for (NSUInteger index = 0; index < matches.count; index++){
		NSDictionary *c = matches[index];
		NSString *title = c[@"title"] ?: @"";
		NSMutableDictionary *row = TGPeerRow(c[@"id"], title,
				c[@"text"] ?: @"",
				^{ [weakSelf toggleChatAtIndex:index]; });
		row[TGRowHeight] = @(kPickerRowHeight);
		if ([c[@"isVerified"] boolValue])
			row[TGRowVerified] = @YES;

		NSNumber *fileId = c[@"photoFileId"];
		UIImage *photo = [fileId isKindOfClass:NSNumber.class]
				? self.avatars[fileId] : nil;
		if ([c[@"isSaved"] boolValue])
			photo = [TGIcons savedMessagesAvatarOfSide:TGMetricListAvatar];
		if (photo)
			row[TGRowAvatarImage] = photo;

		NSNumber *chatId = c[@"id"];
		BOOL selected = [chatId isKindOfClass:NSNumber.class] &&
				[self.selectedChatIds containsObject:chatId];
		row[TGRowAccessory] = TGRowAccessoryCheck;
		row[TGRowChecked] = @(selected);
		[rows addObject:row];
	}

	self.sections = @[TGSection(
			TGForwardPickerSectionHeader(self.query, matches.count), nil, rows)];
	[self reloadRows];
}

- (void)toggleChatAtIndex:(NSUInteger)index {
	NSArray *matches = [self matchingChats];
	if (index >= matches.count)
		return;
	NSNumber *chatId = matches[index][@"id"];
	if (![chatId isKindOfClass:NSNumber.class])
		return;
	if ([self.selectedChatIds containsObject:chatId])
		[self.selectedChatIds removeObject:chatId];
	else
		[self.selectedChatIds addObject:chatId];
	[self updateSendItem];
	[self rebuildSections];
}

@end

// vim:ft=objc
