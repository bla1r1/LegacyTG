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
#import "TGRows.h"

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

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Chat Tools");
	[self rebuild];
	[self loadChat];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
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
	NSDictionary *state = @{
		@"slowMode" : @(self.slowMode),
		@"reactionsAll" : @(self.reactionsAll),
		@"protectedContent" : @(self.protectedContent),
		@"translatable" : @(self.translatable),
		@"defaultSilent" : @(self.defaultSilent),
		@"accentId" : @(self.accentId),
		@"profileAccentId" : @(self.profileAccentId),
		@"themeName" : self.themeName ?: @"Default",
		@"discussionChatId" : @(self.discussionChatId),
		@"note" : self.note ?: @"",
	};
	NSArray *model = TGChatToolsSectionsModel(state);
	NSMutableArray *sections = [NSMutableArray arrayWithCapacity:model.count];
	for (NSUInteger sectionIndex = 0; sectionIndex < model.count; sectionIndex++){
		NSDictionary *sectionModel = model[sectionIndex];
		NSArray *rowModels = sectionModel[@"rows"];
		NSMutableArray *rows = [NSMutableArray arrayWithCapacity:rowModels.count];
		for (NSUInteger rowIndex = 0; rowIndex < rowModels.count; rowIndex++){
			NSDictionary *rowModel = rowModels[rowIndex];
			NSString *title = rowModel[@"title"];
			NSString *detail = rowModel[@"detail"];
			if ([rowModel[@"switch"] boolValue]){
				BOOL on = [rowModel[@"on"] boolValue];
				void (^changed)(BOOL) = ^(BOOL value){
					(void)value;
					if (sectionIndex == 1 && rowIndex == 2)
						[weakSelf toggleProtected];
					else if (sectionIndex == 1 && rowIndex == 3)
						[weakSelf toggleTranslatable];
					else if (sectionIndex == 1 && rowIndex == 4)
						[weakSelf toggleDefaultSilent];
				};
				[rows addObject:TGSwitchRow(title, on, changed)];
				continue;
			}
			void (^tap)(void) = [self tapForSection:sectionIndex
					index:rowIndex];
			if ([rowModel[@"opens"] boolValue])
				[rows addObject:TGSubtitleOpenRow(title, detail, tap)];
			else
				[rows addObject:TGSubtitleRow(title, detail, tap)];
		}
		[sections addObject:TGSection(sectionModel[@"header"], nil, rows)];
	}
	self.sections = sections;
	[self reloadRows];
}

- (void (^)(void))tapForSection:(NSUInteger)section index:(NSUInteger)index {
	__weak typeof(self) weakSelf = self;
	if (section == 0)
		return ^{ [weakSelf showRecommendedChats]; };
	if (section == 1){
		if (index == 0)
			return ^{ [weakSelf chooseSlowMode]; };
		if (index == 1)
			return ^{ [weakSelf chooseReactions]; };
		return nil;
	}
	if (section == 2){
		if (index == 0)
			return ^{ [weakSelf chooseAccent:NO]; };
		if (index == 1)
			return ^{ [weakSelf chooseAccent:YES]; };
		if (index == 2)
			return ^{ [weakSelf chooseTheme]; };
		if (index == 3)
			return ^{ [weakSelf chooseBackground]; };
		return ^{ [weakSelf resetBackground]; };
	}
	if (section == 3){
		if (index == 0)
			return ^{ [weakSelf chooseDiscussionGroup]; };
		if (index == 1)
			return ^{ [weakSelf setLocation]; };
		if (index == 2)
			return ^{ [weakSelf editNote]; };
		return ^{ [weakSelf showOwnerAfterLeaving]; };
	}
	if (section == 4)
		return index == 0 ? ^{ [weakSelf chooseEmojiPhoto]; }
				: ^{ [weakSelf reportPhoto]; };
	if (section == 5){
		if (index == 0)
			return ^{ [weakSelf processJoinRequests:YES]; };
		if (index == 1)
			return ^{ [weakSelf processJoinRequests:NO]; };
		return ^{ [weakSelf answerJoinRequestQuery]; };
	}
	return ^{ [weakSelf addToChatList]; };
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
