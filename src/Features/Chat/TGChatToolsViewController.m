//
// TGChatToolsViewController.m
//
#import "TGChatToolsViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGListViewController.h"
#import "TGChatViewController.h"

/// One row: a title, the value it currently holds, and what a tap does.
static NSMutableDictionary *TGRow(NSString *title, NSString *detail,
								  void (^tap)(void)) {
	NSMutableDictionary *row = [@{@"title" : title ?: @""} mutableCopy];
	if (detail.length)
		row[@"detail"] = detail;
	if (tap)
		row[@"tap"] = [tap copy];
	return row;
}

static NSMutableDictionary *TGOpenRow(NSString *title, NSString *detail,
									  void (^tap)(void)) {
	NSMutableDictionary *row = TGRow(title, detail, tap);
	row[@"opens"] = @YES;
	return row;
}

static NSMutableDictionary *TGSwitchRow(NSString *title, BOOL on,
									   void (^toggle)(void)) {
	NSMutableDictionary *row = TGRow(title, nil, toggle);
	row[@"switch"] = @YES;
	row[@"on"] = @(on);
	return row;
}

static NSDictionary *TGSection(NSString *header, NSString *footer, NSArray *rows) {
	NSMutableDictionary *section = [NSMutableDictionary dictionary];
	if (header) section[@"header"] = header;
	if (footer) section[@"footer"] = footer;
	section[@"rows"] = rows ?: @[];
	return section;
}

/// A colour as TDLib's RGB integer: 0xRRGGBB.
static NSInteger TGRGB(UIColor *colour) {
	CGFloat r = 0.5, g = 0.5, b = 0.5, a = 1;
	[colour getRed:&r green:&g blue:&b alpha:&a];
	return ((NSInteger)lround(r * 255) << 16) |
		   ((NSInteger)lround(g * 255) << 8) |
			(NSInteger)lround(b * 255);
}

/// A solid JPEG for the background request, which wants a file rather than a
/// colour. 64x64 is enough because the fill repeats.
static NSString *TGWriteBackground(UIColor *colour) {
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(TGMetricListAvatar, TGMetricListAvatar), YES, 1);
	[colour setFill];
	UIRectFill(CGRectMake(0, 0, TGMetricListAvatar, TGMetricListAvatar));
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	NSData *jpeg = UIImageJPEGRepresentation(image, 0.9);
	if (!jpeg.length)
		return nil;
	NSString *path = [NSTemporaryDirectory()
			stringByAppendingPathComponent:@"tg-chat-background.jpg"];
	return [jpeg writeToFile:path atomically:YES] ? path : nil;
}

@interface TGChatToolsViewController ()
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSDictionary *chat;
@property (nonatomic, strong) NSDictionary *groupInfo;
@property (nonatomic, assign) BOOL protectedContent;
@property (nonatomic, assign) BOOL translatable;
@property (nonatomic, assign) BOOL defaultSilent;
@property (nonatomic, assign) BOOL reactionsAll;
@property (nonatomic, assign) NSInteger slowMode;
@property (nonatomic, assign) NSInteger accentId;
@property (nonatomic, assign) NSInteger profileAccentId;
@property (nonatomic, assign) int64_t discussionChatId;
@property (nonatomic, copy) NSString *note;
@property (nonatomic, copy) NSString *themeName;
@end

@implementation TGChatToolsViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Chat Tools";
	[self applyTheme];
	[self rebuild];
	[self loadChat];

}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	[self.tableView reloadData];
}

- (void)applyTheme {
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

#pragma mark - state

- (void)loadChat {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatRecordForChat:self.chatId completion:^(NSDictionary *chat){
		TGChatToolsViewController *me = weakSelf;
		if (!me || !chat)
			return;
		me.chat = chat;
		me.protectedContent = [chat[@"has_protected_content"] boolValue];
		me.translatable = [chat[@"is_translatable"] boolValue];
		me.defaultSilent = [chat[@"default_disable_notification"] boolValue];
		me.note = chat[@"client_data"] ?: @"";
		NSString *theme = chat[@"theme"][@"name"];
		me.themeName = theme.length ? theme : @"Default";
		me.accentId = [chat[@"accent_color_id"] integerValue];
		me.profileAccentId = [chat[@"profile_accent_color_id"] integerValue];
		NSString *kind = chat[@"available_reactions"][@"@type"];
		me.reactionsAll = kind.length
				? [kind isEqualToString:@"chatAvailableReactionsAll"] : YES;
		[me rebuild];
	}];

	[[TGClient shared] groupFullInfoForChat:self.chatId completion:^(NSDictionary *info){
		TGChatToolsViewController *me = weakSelf;
		if (!me || !info)
			return;
		me.groupInfo = info;
		me.slowMode = [info[@"slow_mode_delay"] integerValue];
		me.discussionChatId = [info[@"linked_chat_id"] longLongValue];
		[me rebuild];
	}];
}

- (void)rebuild {
	__weak typeof(self) weakSelf = self;

	NSMutableArray *insights = [NSMutableArray array];
	[insights addObject:TGOpenRow(@"Suggested Chats", nil,
			^{ [weakSelf showRecommendedChats]; })];

	NSMutableArray *moderation = [NSMutableArray array];
	[moderation addObject:TGRow(@"Slow Mode",
			self.slowMode ? TGLocalizedFormat(@"%@s", @(self.slowMode))
						  : @"Off", ^{ [weakSelf chooseSlowMode]; })];
	[moderation addObject:TGRow(@"Available Reactions",
			self.reactionsAll ? @"All" : @"Some Reactions", ^{ [weakSelf chooseReactions]; })];
	[moderation addObject:TGSwitchRow(@"Restrict Saving Content",
			self.protectedContent, ^{ [weakSelf toggleProtected]; })];
	[moderation addObject:TGSwitchRow(@"Translate",
			self.translatable, ^{ [weakSelf toggleTranslatable]; })];
	[moderation addObject:TGSwitchRow(@"Send Without Sound",
			self.defaultSilent, ^{ [weakSelf toggleDefaultSilent]; })];

	NSMutableArray *appearance = [NSMutableArray array];
	[appearance addObject:TGRow(@"Accent Color",
			[NSString stringWithFormat:@"%ld", (long)self.accentId],
			^{ [weakSelf chooseAccent:NO]; })];
	[appearance addObject:TGRow(@"Change Profile Color",
			[NSString stringWithFormat:@"%ld", (long)self.profileAccentId],
			^{ [weakSelf chooseAccent:YES]; })];
	[appearance addObject:TGRow(@"Color Theme", self.themeName ?: @"Default",
			^{ [weakSelf chooseTheme]; })];
	[appearance addObject:TGRow(@"Wallpaper", @"Set", ^{ [weakSelf chooseBackground]; })];
	[appearance addObject:TGRow(@"Reset Chat Wallpapers", nil, ^{ [weakSelf resetBackground]; })];

	NSMutableArray *group = [NSMutableArray array];
	[group addObject:TGRow(@"Discussion Group",
			self.discussionChatId ? @"Linked" : @"None",
			^{ [weakSelf chooseDiscussionGroup]; })];
	[group addObject:TGRow(@"Location", nil, ^{ [weakSelf setLocation]; })];
	[group addObject:TGRow(@"Local Note", self.note.length ? self.note : @"None",
			^{ [weakSelf editNote]; })];
	[group addObject:TGRow(@"Owner After Leaving", nil,
			^{ [weakSelf showOwnerAfterLeaving]; })];

	NSMutableArray *photo = [NSMutableArray array];
	[photo addObject:TGRow(@"Emoji", nil, ^{ [weakSelf chooseEmojiPhoto]; })];
	[photo addObject:TGRow(@"Report Profile Photo", nil, ^{ [weakSelf reportPhoto]; })];

	NSMutableArray *admin = [NSMutableArray array];
	[admin addObject:TGRow(@"Approve", nil,
			^{ [weakSelf processJoinRequests:YES]; })];
	[admin addObject:TGRow(@"Decline All", nil,
			^{ [weakSelf processJoinRequests:NO]; })];
	[admin addObject:TGRow(@"Join Requests", nil,
			^{ [weakSelf answerJoinRequestQuery]; })];

	NSMutableArray *folders = [NSMutableArray array];
	[folders addObject:TGRow(@"Add to Folder", nil,
			^{ [weakSelf addToChatList]; })];

	self.sections = @[
		TGSection(@"Channels", nil, insights),
		TGSection(@"Moderation", nil, moderation),
		TGSection(@"Appearance", nil, appearance),
		TGSection(@"This Chat", nil, group),
		TGSection(@"Photo", nil, photo),
		TGSection(@"Join Requests", nil, admin),
		TGSection(@"Chat Folders", nil, folders),
	];
	[self.tableView reloadData];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self.sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return self.sections[section][@"header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return self.sections[section][@"footer"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = self.sections[indexPath.section][@"rows"][indexPath.row];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"row"];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.text = row[@"title"];
	cell.textLabel.font = TGFontBody();
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.detailTextLabel.text = row[@"detail"];
	cell.detailTextLabel.font = TGFontSubhead();
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.accessoryView = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	if ([row[@"switch"] boolValue]){
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.on = [row[@"on"] boolValue];
		toggle.tag = indexPath.section * 1000 + indexPath.row;
		[toggle addTarget:self action:@selector(switchChanged:)
		 forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}
	cell.accessoryType = (row[@"tap"] && [row[@"opens"] boolValue])
			? UITableViewCellAccessoryDisclosureIndicator
			: UITableViewCellAccessoryNone;
	cell.selectionStyle = row[@"tap"] ? UITableViewCellSelectionStyleBlue
									  : UITableViewCellSelectionStyleNone;
	return cell;
}

- (void)switchChanged:(UISwitch *)toggle {
	NSInteger section = toggle.tag / 1000;
	NSInteger rowIndex = toggle.tag % 1000;
	if (section >= (NSInteger)self.sections.count)
		return;
	NSArray *rows = self.sections[(NSUInteger)section][@"rows"];
	if (rowIndex >= (NSInteger)rows.count)
		return;
	void (^tap)(void) = rows[(NSUInteger)rowIndex][@"tap"];
	if (tap)
		tap();
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section >= (NSInteger)self.sections.count)
		return;
	NSArray *rows = self.sections[indexPath.section][@"rows"];
	if (indexPath.row >= (NSInteger)rows.count)
		return;
	NSDictionary *row = rows[indexPath.row];
	if ([row[@"switch"] boolValue]){
		[tableView deselectRowAtIndexPath:indexPath animated:NO];
		return;
	}
	void (^tap)(void) = row[@"tap"];
	if (!tap)
		return;
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	tap();
}

#pragma mark - insights

- (void)showRecommendedChats {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] recommendedChatsWithCompletion:^(NSArray *chats){
		TGChatToolsViewController *me = weakSelf;
		if (!me)
			return;
		if (!chats.count){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Suggested Chats" inView:me.view];
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *chat in chats){
			[rows addObject:@{@"title" : chat[@"title"] ?: @"Channel",
							  @"detail" : @"Open",
							  @"opens" : @YES,
							  @"tap" : ^{
				TGChatViewController *vc = [[TGChatViewController alloc] init];
				vc.chatId = [chat[@"id"] longLongValue];
				vc.chatTitle = chat[@"title"];
				vc.isGroup = YES;
				vc.hidesBottomBarWhenPushed = YES;
				[me.navigationController pushViewController:vc animated:YES];
			}}];
		}
		TGListViewController *list = [[TGListViewController alloc] init];
		list.listTitle = @"Suggested Chats";
		list.rows = rows;
		list.hidesBottomBarWhenPushed = YES;
		[me.navigationController pushViewController:list animated:YES];
	}];
}

- (void)chooseSlowMode {
	NSArray *titles = @[@"Off",
						TGLocalizedPluralValue(@"%@ second", @"%@ seconds", @"5", 5),
						TGLocalizedPluralValue(@"%@ second", @"%@ seconds", @"10", 10),
						TGLocalizedPluralValue(@"%@ second", @"%@ seconds", @"30", 30),
						TGLocalizedPluralValue(@"%@ minute", @"%@ minutes", @"1", 1),
						TGLocalizedPluralValue(@"%@ minute", @"%@ minutes", @"5", 5),
						TGLocalizedPluralValue(@"%@ minute", @"%@ minutes", @"15", 15),
						TGLocalizedPluralValue(@"%@ hour", @"%@ hours", @"1", 1)];
	static const NSInteger seconds[] = {0, 5, 10, 30, 60, 300, 900, 3600};
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles title:@"Slow Mode" destructiveIndex:-1
			inView:self.view onChoice:^(NSInteger index){
		[[TGClient shared] setSlowModeDelayForChat:weakSelf.chatId
				seconds:seconds[index] completion:^(BOOL ok){
			TGChatToolsViewController *me = weakSelf;
			if (!ok){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Slow Mode" inView:me.view];
				return;
			}
			me.slowMode = seconds[index];
			[me rebuild];
		}];
	}];
}

- (void)chooseReactions {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"All reactions", @"Only 👍 ❤️ 🔥"]
						title:@"Available Reactions"
			 destructiveIndex:-1 inView:self.view onChoice:^(NSInteger index){
		NSString *mode = index == 0 ? @"all" : @"some";
		[[TGClient shared] setAvailableReactionsForChat:weakSelf.chatId
				mode:mode completion:^(BOOL ok){
			TGChatToolsViewController *me = weakSelf;
			if (!ok){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Reactions" inView:me.view];
				return;
			}
			me.reactionsAll = (index == 0);
			[me rebuild];
		}];
	}];
}

- (void)toggleProtected {
	__weak typeof(self) weakSelf = self;
	BOOL next = !self.protectedContent;
	[[TGClient shared] toggleProtectedContentForChat:self.chatId on:next
			completion:^(BOOL ok){
		TGChatToolsViewController *me = weakSelf;
		if (!ok){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Restrict Saving Content" inView:me.view];
			return;
		}
		me.protectedContent = next;
		[me rebuild];
	}];
}

- (void)toggleTranslatable {
	self.translatable = !self.translatable;
	[[TGClient shared] toggleTranslatableForChat:self.chatId on:self.translatable];
	[self rebuild];
}

- (void)toggleDefaultSilent {
	self.defaultSilent = !self.defaultSilent;
	[[TGClient shared] toggleDefaultSilentForChat:self.chatId on:self.defaultSilent];
	[self rebuild];
}

#pragma mark - appearance

- (void)chooseAccent:(BOOL)profile {
	NSArray *titles = @[@"0", @"1", @"2", @"3", @"4", @"5", @"6"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles
						title:(profile ? @"Change Profile Color" : @"Accent Color")
			 destructiveIndex:-1 inView:self.view onChoice:^(NSInteger index){
		if (profile){
			[[TGClient shared] setChatProfileAccentColour:weakSelf.chatId colourId:index];
			weakSelf.profileAccentId = index;
		} else {
			[[TGClient shared] setChatAccentColour:weakSelf.chatId colourId:index];
			weakSelf.accentId = index;
		}
		[weakSelf rebuild];
	}];
}

- (void)chooseTheme {
	NSArray *themes = @[@"Default", @"❤️", @"🔥", @"🎉", @"🌊", @"🍀", @"🌙"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:themes title:@"Color Theme" destructiveIndex:-1
			inView:self.view onChoice:^(NSInteger index){
		NSString *name = index == 0 ? @"" : themes[index];
		[[TGClient shared] setChatTheme:weakSelf.chatId name:name completion:^(BOOL ok){
			TGChatToolsViewController *me = weakSelf;
			if (!ok){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Color Theme" inView:me.view];
				return;
			}
			me.themeName = index == 0 ? @"Default" : themes[index];
			[me rebuild];
		}];
	}];
}

- (void)chooseBackground {
	NSArray *titles = @[@"Accent", @"Secondary", @"Destructive", @"Grouped"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles title:@"Wallpaper" destructiveIndex:-1
			inView:self.view onChoice:^(NSInteger index){
		UIColor *colour = [[TGTheme shared] accentColour];
		if (index == 1)
			colour = [[TGTheme shared] secondaryTextColour];
		else if (index == 2)
			colour = [[TGTheme shared] destructiveColour];
		else if (index == 3)
			colour = [[TGTheme shared] groupedBackgroundColour];
		NSString *path = TGWriteBackground(colour);
		if (!path){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Wallpaper" inView:weakSelf.view];
			return;
		}
		[[TGClient shared] setChatBackground:weakSelf.chatId imagePath:path
				colour:TGRGB(colour) onlyForSelf:!weakSelf.isGroup
				completion:^(BOOL ok){
			[TGAlertSheet showMessage:(ok ? @"Done"
										   : @"An error occurred.")
								title:@"Wallpaper" inView:weakSelf.view];
		}];
	}];
}

- (void)resetBackground {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:@"Reset Chat Wallpapers" action:@"Reset"
				  destructive:YES inView:self.view onConfirm:^{
		[[TGClient shared] deleteChatBackground:weakSelf.chatId restorePrevious:YES];
	}];
}

#pragma mark - this chat

- (void)chooseDiscussionGroup {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] suitableDiscussionChatsWithCompletion:^(NSArray *chats){
		TGChatToolsViewController *me = weakSelf;
		if (!me)
			return;
		NSMutableArray *titles = [NSMutableArray arrayWithObject:@"None"];
		NSMutableArray *all = [NSMutableArray arrayWithObject:@{}];
		for (NSDictionary *chat in chats){
			[titles addObject:chat[@"title"] ?: @"Group"];
			[all addObject:chat];
		}
		[TGAlertSheet showChoices:titles title:@"Discussion Group"
				destructiveIndex:-1 inView:me.view onChoice:^(NSInteger index){
			NSDictionary *chat = all[index];
			int64_t discussionId = [chat[@"id"] longLongValue];
			[[TGClient shared] setDiscussionGroup:discussionId forChat:weakSelf.chatId
					completion:^(BOOL ok){
				if (ok){
					weakSelf.discussionChatId = discussionId;
					[weakSelf rebuild];
				}
				[TGAlertSheet showMessage:(ok ? @"Done"
											   : @"An error occurred.")
									title:@"Discussion Group" inView:weakSelf.view];
			}];
		}];
	}];
}

- (void)setLocation {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Location" message:nil placeholder:@"Address"
					   text:nil action:@"Save" inView:self.view
				   onSubmit:^(NSString *address){
		[[TGClient shared] setLocationAddress:address forChat:weakSelf.chatId
				completion:^(BOOL ok){
			[TGAlertSheet showMessage:(ok ? @"Done"
										   : @"An error occurred.")
								title:@"Location" inView:weakSelf.view];
		}];
	}];
}

- (void)editNote {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Local Note"
					message:nil
				placeholder:@"Note"
					   text:self.note action:@"Save" inView:self.view
				 onSubmit:^(NSString *note){
		[[TGClient shared] setClientNote:note forChat:weakSelf.chatId
				completion:^(BOOL ok){
			if (!ok)
				return;
			weakSelf.note = note;
			[weakSelf rebuild];
		}];
	}];
}

- (void)showOwnerAfterLeaving {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] ownerAfterLeavingChat:self.chatId completion:^(NSDictionary *user){
		TGChatToolsViewController *me = weakSelf;
		if (!me)
			return;
		NSString *say = user[@"name"] ?: @"An error occurred.";
		[TGAlertSheet showMessage:say title:@"Owner After Leaving" inView:me.view];
	}];
}

#pragma mark - photo

- (void)chooseEmojiPhoto {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] defaultChatPhotoEmojiStickersWithCompletion:^(NSArray *stickers){
		TGChatToolsViewController *me = weakSelf;
		if (!me)
			return;
		if (!stickers.count){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Emoji" inView:me.view];
			return;
		}
		NSMutableArray *titles = [NSMutableArray array];
		for (NSDictionary *sticker in stickers)
			[titles addObject:sticker[@"emoji"] ?: @"🙂"];
		[TGAlertSheet showChoices:titles title:@"Emoji"
				destructiveIndex:-1 inView:me.view onChoice:^(NSInteger index){
			NSDictionary *sticker = stickers[index];
			UIColor *colour = [[TGTheme shared] accentColour];
			[[TGClient shared] setEmojiPhotoForChat:weakSelf.chatId
					customEmojiId:[sticker[@"customEmojiId"] longLongValue]
					colour:TGRGB(colour) completion:^(BOOL ok){
				[TGAlertSheet showMessage:(ok ? @"Done"
											   : @"An error occurred.")
									title:@"Emoji" inView:weakSelf.view];
			}];
		}];
	}];
}

- (void)reportPhoto {
	NSArray *titles = @[@"Spam", @"Violence", @"Pornography", @"Child abuse",
						@"Copyright", @"Wrong location", @"Fake", @"Other"];
	NSArray *reasons = @[@"spam", @"violence", @"pornography", @"childAbuse",
						 @"copyright", @"location", @"fake", @"custom"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles title:@"Report Profile Photo" destructiveIndex:0
			inView:self.view onChoice:^(NSInteger index){
		[TGAlertSheet showConfirm:nil
							title:@"Report Profile Photo" action:@"Report"
					  destructive:YES inView:weakSelf.view onConfirm:^{
			[[TGClient shared] reportChatPhotoInChat:weakSelf.chatId
					reason:reasons[index] detail:@""
					completion:^(BOOL ok){
				[TGAlertSheet showMessage:(ok
								? @"Telegram moderators will review your report. Thank you!"
								: @"An error occurred.")
									title:@"Report Profile Photo" inView:weakSelf.view];
			}];
		}];
	}];
}

#pragma mark - join requests and folders

- (void)processJoinRequests:(BOOL)approve {
	__weak typeof(self) weakSelf = self;
	NSString *action = approve ? @"Approve" : @"Decline All";
	[TGAlertSheet showConfirm:nil
						title:@"Join Requests" action:action
				  destructive:!approve inView:self.view onConfirm:^{
		[[TGClient shared] processAllJoinRequests:weakSelf.chatId link:@""
				approve:approve completion:^(BOOL ok){
			[TGAlertSheet showMessage:(ok ? @"Done"
										   : @"An error occurred.")
								title:@"Join Requests" inView:weakSelf.view];
		}];
	}];
}

- (void)answerJoinRequestQuery {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] joinRequestsForChat:self.chatId completion:^(NSArray *requests){
		TGChatToolsViewController *me = weakSelf;
		if (!me)
			return;
		if (!requests.count){
			[TGAlertSheet showMessage:@"None"
								title:@"Join Requests" inView:me.view];
			return;
		}
		NSMutableArray *titles = [NSMutableArray array];
		for (NSDictionary *request in requests){
			NSString *name = request[@"name"];
			[titles addObject:name.length ? name : @"Someone"];
		}
		[TGAlertSheet showChoices:titles
							title:@"Join Requests"
				 destructiveIndex:-1
						   inView:me.view
						 onChoice:^(NSInteger index){
			NSDictionary *request = requests[(NSUInteger)index];
			int64_t userId = [request[@"id"] longLongValue];
			[TGAlertSheet showChoices:@[@"Approve", @"Decline"]
								title:request[@"name"] ?: @"Join Requests"
					 destructiveIndex:1
							   inView:weakSelf.view
							 onChoice:^(NSInteger answer){
				[[TGClient shared] processJoinRequest:userId inChat:weakSelf.chatId
											 approve:(answer == 0)];
			}];
		}];
	}];
}

- (void)addToChatList {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatListsForChat:self.chatId completion:^(NSArray *lists){
		TGChatToolsViewController *me = weakSelf;
		if (!me)
			return;
		if (!lists.count){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Add to Folder" inView:me.view];
			return;
		}
		NSMutableArray *titles = [NSMutableArray array];
		for (NSDictionary *list in lists){
			NSString *kind = list[@"@type"] ?: @"";
			if ([kind isEqualToString:@"chatListMain"])
				[titles addObject:@"All Chats"];
			else if ([kind isEqualToString:@"chatListArchive"])
				[titles addObject:@"Archive"];
			else if ([kind isEqualToString:@"chatListFolder"]){
				NSInteger folderId = [list[@"chat_folder_id"] integerValue];
				NSString *name = nil;
				for (NSDictionary *folder in [TGClient shared].folders)
					if ([folder[@"id"] integerValue] == folderId)
						name = folder[@"title"];
				[titles addObject:name.length ? name
						: [NSString stringWithFormat:@"Folder %ld", (long)folderId]];
			} else {
				[titles addObject:@"List"];
			}
		}
		[TGAlertSheet showChoices:titles title:@"Add to Folder"
				destructiveIndex:-1 inView:me.view onChoice:^(NSInteger index){
			[[TGClient shared] addChat:weakSelf.chatId toList:lists[index]
					completion:^(BOOL ok){
				[TGAlertSheet showMessage:(ok ? @"Done"
											   : @"An error occurred.")
									title:@"Add to Folder" inView:weakSelf.view];
			}];
		}];
	}];
}

@end
