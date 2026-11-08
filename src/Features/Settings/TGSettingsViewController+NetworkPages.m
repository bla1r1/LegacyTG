//
// TGSettingsViewController+NetworkPages.m
// Settings pages for data usage, network stats, power saving, folders, downloads, and proxies.
//
#import "TGSettingsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGAlertSheet.h"
#import "TGForwardPicker.h"
#import "TGNetworkViewController.h"
#import "TGStorageViewController.h"
#import "TGFileInfoViewController.h"
#import "TGSettingsViewController+Tier2.h"
#import <objc/runtime.h>

static char TGAutoDownloadBaselineKey;

/// The protocol name official puts in a saved proxy's status line.
static NSString *TGProxyTypeLabel(NSString *kind) {
	if ([kind isEqualToString:@"mtproto"]) return @"MTProto";
	if ([kind isEqualToString:@"http"])    return @"HTTP";
	if ([kind isEqualToString:@"web"])     return @"Web";
	return @"SOCKS5";
}

static NSString *TGChatNameForId(NSNumber *chatId) {
	for (NSArray *list in @[[TGClient shared].chats ?: @[],
							[TGClient shared].archivedChats ?: @[]])
		for (NSDictionary *chat in list)
			if ([chat[@"id"] longLongValue] == chatId.longLongValue){
				NSString *title = chat[@"title"];
				if (title.length)
					return title;
			}
	return [NSString stringWithFormat:@"Chat %@", chatId];
}

/// One connection's auto-download settings. The official page lists the media
/// types and their limits; this client has one preset per network, so the
/// same switches move that preset and say what it currently allows.
@interface TGAutoDownloadConnectionViewController : UITableViewController
@property (nonatomic, copy) NSString *network;
/// Which key in autoDownloadPresets this network maps to.
@property (nonatomic, copy) NSString *presetKey;
@property (nonatomic, strong) NSDictionary *preset;
@property (nonatomic, copy) NSString *photoSizeText;
@property (nonatomic, copy) NSString *videoSizeText;
@property (nonatomic, copy) void (^onChanged)(void);
@end

@implementation TGAutoDownloadConnectionViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
}

- (void)setPreset:(NSDictionary *)preset {
	_preset = [preset copy];
	long long photo = [_preset[@"maxPhotoSize"] longLongValue];
	long long video = [_preset[@"maxVideoSize"] longLongValue];
	self.photoSizeText = photo > 0 ? TGBytes(photo) : @"Off";
	self.videoSizeText = video > 0 ? TGBytes(video) : @"Off";
}

- (BOOL)enabled {
	return [self.preset[@"enabled"] boolValue];
}

- (void)setEnabled:(BOOL)enabled {
	// A tap before getAutoDownloadSettingsPresets answers has no sizes to
	// send; the switch stays disabled until the preset arrives.
	if (![self.preset isKindOfClass:NSDictionary.class])
		return;
	NSMutableDictionary *next = [self.preset mutableCopy];
	next[@"enabled"] = @(enabled);
	self.preset = next;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] applyAutoDownloadPreset:next forNetwork:self.network
									completion:^(BOOL ok){
		if (ok && weakSelf.onChanged)
			weakSelf.onChanged();
	}];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return @"Auto-Download";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"row"];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	if (path.row == 0){
		cell.textLabel.text = @"Auto-Download";
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.on = [self enabled];
		toggle.enabled = [self.preset isKindOfClass:NSDictionary.class];
		[toggle addTarget:self action:@selector(toggleChanged:)
		 forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		cell.detailTextLabel.text = nil;
		return cell;
	}
	cell.textLabel.text = path.row == 1 ? @"Photos" : @"Videos";
	cell.detailTextLabel.text = path.row == 1 ? self.photoSizeText : self.videoSizeText;
	return cell;
}

- (void)toggleChanged:(UISwitch *)sender {
	[self setEnabled:sender.on];
}

@end

/// Network Usage, without the TDLib diagnostics that used to share its row.
@interface TGDataUsageViewController : UITableViewController
@property (nonatomic, assign) long long sent;
@property (nonatomic, assign) long long received;
@property (nonatomic, copy) NSString *sentText;
@property (nonatomic, copy) NSString *receivedText;
@property (nonatomic, assign) BOOL loaded;
@end

@implementation TGDataUsageViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Data Usage";
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] networkStatsWithCompletion:^(long long sent, long long received){
		weakSelf.sent = sent;
		weakSelf.received = received;
		weakSelf.sentText = TGBytes(sent);
		weakSelf.receivedText = TGBytes(received);
		weakSelf.loaded = YES;
		[weakSelf.tableView reloadData];
	}];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return section == 0 ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return section == 0 ? @"Data Usage" : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"row"];
	if (path.section == 0){
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.text = path.row == 0 ? @"Received" : @"Sent";
		cell.detailTextLabel.text = self.loaded
				? (path.row == 0 ? self.receivedText : self.sentText) : @"Loading...";
		return cell;
	}
	cell.textLabel.text = @"Reset Statistics";
	cell.textLabel.textAlignment = NSTextAlignmentCenter;
	cell.textLabel.textColor = [[TGTheme shared] destructiveColour];
	cell.detailTextLabel.text = nil;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
	[tableView deselectRowAtIndexPath:path animated:YES];
	if (path.section != 1)
		return;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"Do you want to reset your usage statistics?"
						title:@"Reset Statistics"
					   action:@"Reset" destructive:YES inView:self.view
					onConfirm:^{
		[[TGClient shared] resetNetworkStats];
		weakSelf.sent = 0;
		weakSelf.received = 0;
		weakSelf.sentText = TGBytes(0);
		weakSelf.receivedText = TGBytes(0);
		[weakSelf.tableView reloadData];
	}];
}

@end

@implementation TGSettingsViewController (NetworkPages)

- (NSArray *)dataSections {
	__weak typeof(self) weakSelf = self;
	NSDictionary *autosave = self.autosaveSettings;
	// Keep the first answer apart from the edited copy: Reset needs the
	// values the page opened with, not the ones it just wrote back.
	if (self.autoDownloadPresets &&
		!objc_getAssociatedObject(self, &TGAutoDownloadBaselineKey))
		objc_setAssociatedObject(self, &TGAutoDownloadBaselineKey,
				self.autoDownloadPresets, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	NSDictionary *baseline = objc_getAssociatedObject(self, &TGAutoDownloadBaselineKey);

	NSDictionary *medium = self.autoDownloadPresets[@"medium"];
	NSDictionary *high = self.autoDownloadPresets[@"high"];
	NSString *cellularDetail = @"Off";
	NSString *wifiDetail = @"Off";
	if ([medium isKindOfClass:NSDictionary.class] &&
		[medium[@"enabled"] boolValue])
		cellularDetail = TGBytes([medium[@"maxPhotoSize"] longLongValue]);
	if ([high isKindOfClass:NSDictionary.class] &&
		[high[@"enabled"] boolValue])
		wifiDetail = TGBytes([high[@"maxPhotoSize"] longLongValue]);

	NSMutableArray *autosaveRows = [NSMutableArray array];
	NSArray *scopes = @[
		@[@"private", @"Private Chats"],
		@[@"groups", @"Groups"],
		@[@"channels", @"Channels"],
	];
	for (NSArray *pair in scopes){
		NSString *scope = pair[0];
		NSDictionary *scopeSettings = autosave[scope];
		BOOL on = [scopeSettings[@"photos"] boolValue] ||
				[scopeSettings[@"videos"] boolValue];
		[autosaveRows addObject:TGTapRow(pair[1], on ? @"On" : @"Off", ^{
			weakSelf.autosaveScope = scope;
			[weakSelf openPage:TGSettingsPageAutosave];
		})];
	}

	NSMutableArray *downloadRows = [NSMutableArray array];
	[downloadRows addObject:TGTapRow(@"Using Cellular", cellularDetail, ^{
		TGAutoDownloadConnectionViewController *page =
				[[TGAutoDownloadConnectionViewController alloc] init];
		page.title = @"Using Cellular";
		page.network = @"mobile";
		page.presetKey = @"medium";
		page.preset = weakSelf.autoDownloadPresets[@"medium"];
		__weak TGAutoDownloadConnectionViewController *weakPage = page;
		page.onChanged = ^{
			// The row above and a reopen read autoDownloadPresets, so the
			// edited copy has to go back into it.
			TGAutoDownloadConnectionViewController *me = weakPage;
			NSMutableDictionary *presets =
					[weakSelf.autoDownloadPresets mutableCopy] ?:
					[NSMutableDictionary dictionary];
			if (me.preset)
				presets[me.presetKey] = me.preset;
			weakSelf.autoDownloadPresets = presets;
			weakSelf.autoDownloadChanged = YES;
			[weakSelf rebuild];
		};
		page.hidesBottomBarWhenPushed = YES;
		[weakSelf.navigationController pushViewController:page animated:YES];
	})];
	[downloadRows addObject:TGTapRow(@"Using Wi-Fi", wifiDetail, ^{
		TGAutoDownloadConnectionViewController *page =
				[[TGAutoDownloadConnectionViewController alloc] init];
		page.title = @"Using Wi-Fi";
		page.network = @"wifi";
		page.presetKey = @"high";
		page.preset = weakSelf.autoDownloadPresets[@"high"];
		__weak TGAutoDownloadConnectionViewController *weakPage = page;
		page.onChanged = ^{
			TGAutoDownloadConnectionViewController *me = weakPage;
			NSMutableDictionary *presets =
					[weakSelf.autoDownloadPresets mutableCopy] ?:
					[NSMutableDictionary dictionary];
			if (me.preset)
				presets[me.presetKey] = me.preset;
			weakSelf.autoDownloadPresets = presets;
			weakSelf.autoDownloadChanged = YES;
			[weakSelf rebuild];
		};
		page.hidesBottomBarWhenPushed = YES;
		[weakSelf.navigationController pushViewController:page animated:YES];
	})];
	if (weakSelf.autoDownloadChanged)
		[downloadRows addObject:TGActionRow(@"Reset", ^{
			NSDictionary *mobile = (baseline ?: weakSelf.autoDownloadPresets)[@"medium"];
			NSDictionary *wifi = (baseline ?: weakSelf.autoDownloadPresets)[@"high"];
			[[TGClient shared] applyAutoDownloadPreset:mobile forNetwork:@"mobile"
											completion:^(BOOL ok){
				[[TGClient shared] applyAutoDownloadPreset:wifi forNetwork:@"wifi"
												completion:^(BOOL ok2){
					if (ok && ok2 && baseline)
						weakSelf.autoDownloadPresets = baseline;
					weakSelf.autoDownloadChanged = !(ok && ok2);
					[weakSelf toast:(ok && ok2 ? @"Done" : @"An error occurred.")];
					[weakSelf rebuild];
				}];
			}];
		})];
	else
		[downloadRows addObject:TGRow(TGKindPlain, @"Reset")];

	return @[
		TGSection(nil, nil, @[
			TGIconTapOpenRow(@"Cache", self.rootCacheLoaded
					? TGBytes(self.rootCacheBytes) : nil,
					@"data", TGIconTileGreen(), ^{
				TGStorageViewController *storage = [[TGStorageViewController alloc] init];
				storage.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:storage animated:YES];
			}),
			TGIconTapOpenRow(@"Data Usage",
					TGBytes(weakSelf.networkReceived + weakSelf.networkSent),
					@"notifications", TGIconTileAzure(), ^{
				TGDataUsageViewController *usage = [[TGDataUsageViewController alloc] init];
				usage.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:usage animated:YES];
			}),
		]),

		TGSection(nil, nil, downloadRows),

		TGSection(@"Save to Gallery",
			@"Automatically save all new media from private chats to your Photos app.",
			autosaveRows),

		TGSection(@"CONNECTION", nil, @[
			TGIconTapOpenRow(@"Proxy", weakSelf.rootProxyDetail ?: @"Disabled",
					@"data", TGIconTileGrey(), ^{
				[weakSelf openPage:TGSettingsPageProxy];
			}),
		]),
	];
}

- (NSArray *)powerSavingSections {
	__weak typeof(self) weakSelf = self;
	return @[
		TGSection(@"OPTIONS",
			@"Turn off Power Saving Mode to change these settings.",
			@[
			TGSwitchInfoRow(@"Loop Animated Stickers",
					@"Animated stickers will play continuously in chats.",
					@"sticker", TGIconTileGreen(),
					[TGCapabilities animatedStickersWanted], ^(BOOL on){
				[TGCapabilities setAnimatedStickersWanted:on];
				[weakSelf rebuild];
			}),
			TGSwitchInfoRow(@"Autoplay GIFs",
					@"Autoplay and loop GIFs in chats and in the keyboard.",
					@"video", TGIconTileOrchid(),
					[TGCapabilities gifAutoplayWanted], ^(BOOL on){
				[TGCapabilities setGifAutoplayWanted:on];
				[weakSelf rebuild];
			}),
			TGSwitchInfoRow(@"Chat Wallpaper", nil,
					@"chat", TGIconTileSky(),
					[TGCapabilities wallpaperWanted], ^(BOOL on){
				[TGCapabilities setWallpaperWanted:on];
				[weakSelf rebuild];
			}),
		]),
	];
}

- (NSArray *)folderSections {
	__weak typeof(self) weakSelf = self;
	NSArray *folders = [TGClient shared].folders;

	NSMutableArray *rows = [NSMutableArray array];
	// Official puts Create New Folder first, under the Folders header.
	[rows addObject:TGActionRow(@"Create New Folder", ^{
		[TGAlertSheet showInput:@"New Folder"
						message:nil
					placeholder:@"Name"
						   text:nil
						 action:@"Create"
						 inView:weakSelf.view
					   onSubmit:^(NSString *name){
			[[TGClient shared] createFolderNamed:name icon:nil withChats:@[]
									  completion:^(NSInteger folderId){
				if (!folderId){
					[weakSelf toast:@"An error occurred."];
					return;
				}
				[weakSelf toast:@"Done"];
			}];
		}];
	})];
	for (NSDictionary *folder in folders){
		NSString *title = folder[@"title"];
		if (!title.length)
			continue;
		NSNumber *count = weakSelf.folderChatCounts[@([folder[@"id"] integerValue])];
		// Official shows the raw count and leaves a zero folder blank.
		NSString *detail = count ? (count.integerValue ? count.stringValue : @"") : nil;
		[rows addObject:TGIconTapOpenRow(title, detail, @"folder", TGIconTileCyan(), ^{
			[weakSelf runFolderActionFor:folder];
		})];
	}
	if (!weakSelf.folderTagsLoaded){
		weakSelf.folderTagsEnabled = YES;
		weakSelf.folderTagsLoaded = YES;
	}
	[rows addObject:TGSwitchRow(@"Folder Tags", weakSelf.folderTagsEnabled,
			^(BOOL on){
		weakSelf.folderTagsEnabled = on;
		[[TGClient shared] toggleFolderTags:on];
	})];
	[rows addObject:TGActionRow(@"Add Folder", ^{
		[weakSelf addFolderByInviteLink];
	})];

	NSMutableArray *sections = [NSMutableArray array];
	[sections addObject:TGSection(@"Folders", nil, rows)];

	NSMutableArray *suggested = [NSMutableArray array];
	for (NSDictionary *entry in self.recommendedFolders){
		NSString *title = entry[@"title"];
		if (!title.length)
			continue;
		[suggested addObject:TGTapRow(title, entry[@"description"], ^{
			[[TGClient shared] createRecommendedFolder:entry[@"folder"]
											completion:^(NSInteger folderId){
				(void)title;
				[weakSelf toast:folderId ? @"Done" : @"An error occurred."];
			}];
		})];
	}
	if (suggested.count)
		[sections addObject:TGSection(@"RECOMMENDED FOLDERS", nil, suggested)];

	return sections;
}

- (void)runFolderActionFor:(NSDictionary *)folder {
	NSInteger folderId = [folder[@"id"] integerValue];
	NSString *title = folder[@"title"] ?: @"Folders";
	if (!folderId)
		return;

	NSArray *choices = @[@"Edit Folder", @"Add to Folder", @"Remove from Folder",
						 @"Share Folder", @"New Chats",
						 @"Default Icon", @"Chat Count", @"Delete Folder"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices
							title:title
				 destructiveIndex:7
						   inView:self.view
						 onChoice:^(NSInteger index){
		TGSettingsViewController *me = weakSelf;
		if (index == 0){
			[TGAlertSheet showInput:@"Edit Folder" message:nil
						placeholder:@"Name" text:title action:@"Save"
							 inView:me.view onSubmit:^(NSString *name){
				[[TGClient shared] editFolder:folderId name:name chats:nil
								   completion:^(BOOL ok){
					if (!ok)
						[me toast:@"An error occurred."];
				}];
			}];
		} else if (index == 1){
			[me addChatToFolder:folderId named:title];
		} else if (index == 2){
			[me removeChatFromFolder:folderId named:title];
		} else if (index == 3){
			[me showInviteLinksForFolder:folderId named:title];
		} else if (index == 4){
			[me showNewChatsForFolder:folderId named:title];
		} else if (index == 5){
			[me showDefaultIconForFolder:folder];
		} else if (index == 6){
			[me showChatCountForFolder:folder];
		} else {
			[me confirmDeleteFolder:folderId named:title];
		}
	}];
}

/// Deleting a folder can take chats with it, and Telegram names the ones it
/// suggests leaving: pinned and always-included chats. The prompt offers both
/// readings rather than assuming either.
- (void)confirmDeleteFolder:(NSInteger)folderId named:(NSString *)title {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatsToLeaveForFolder:folderId completion:^(NSArray *suggested){
		TGSettingsViewController *me = weakSelf;
		if (!me)
			return;
		void (^remove)(NSArray *) = ^(NSArray *leave){
			[[TGClient shared] deleteFolder:folderId leavingChats:leave];
			[me toast:@"Done"];
		};
		if (!suggested.count){
			[TGAlertSheet showConfirm:nil
								title:@"Delete Folder"
							   action:@"Delete" destructive:YES inView:me.view
							onConfirm:^{ remove(@[]); }];
			return;
		}
		[TGAlertSheet showChoices:@[@"Remove Folder",
									[NSString stringWithFormat:@"Remove Folder and Chats"]]
							title:title
						 message:nil
		 destructiveIndex:1 inView:me.view onChoice:^(NSInteger index){
			remove(index == 0 ? @[] : suggested);
		}];
	}];
}

- (void)showDefaultIconForFolder:(NSDictionary *)folder {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] folderDetails:[folder[@"id"] integerValue]
							 completion:^(NSDictionary *current){
		if (!current){
			[weakSelf toast:@"An error occurred."];
			return;
		}
		[[TGClient shared] defaultIconNameForFolder:current
										 completion:^(NSString *name){
			(void)name;
			[TGAlertSheet showMessage:@"Done"
								title:@"Default" inView:weakSelf.view];
		}];
	}];
}

- (void)showChatCountForFolder:(NSDictionary *)folder {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] folderDetails:[folder[@"id"] integerValue]
							 completion:^(NSDictionary *current){
		if (!current){
			[weakSelf toast:@"An error occurred."];
			return;
		}
		[[TGClient shared] chatCountForFolder:current completion:^(NSInteger count){
			[TGAlertSheet showMessage:[NSString stringWithFormat:@"%ld", (long)count]
								title:@"Chats" inView:weakSelf.view];
		}];
	}];
}

- (void)showNewChatsForFolder:(NSInteger)folderId named:(NSString *)title {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] newChatsForFolder:folderId completion:^(NSArray *chatIds){
		TGSettingsViewController *me = weakSelf;
		if (!me)
			return;
		if (!chatIds.count){
			[TGAlertSheet showMessage:@"Empty"
								title:title inView:me.view];
			return;
		}
		[TGAlertSheet showConfirm:nil
							title:@"New Chats" action:@"Add"
					  destructive:NO inView:me.view onConfirm:^{
			[[TGClient shared] processNewChats:chatIds forFolder:folderId
									completion:^(BOOL ok){
				[me toast:(ok ? @"Done" : @"An error occurred.")];
			}];
		}];
	}];
}

- (void)showInviteLinksForFolder:(NSInteger)folderId named:(NSString *)title {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] inviteLinksForFolder:folderId completion:^(NSArray *links){
		TGSettingsViewController *me = weakSelf;
		if (!me)
			return;
		NSMutableArray *rows = [NSMutableArray arrayWithObject:@"Create a New Link"];
		for (NSDictionary *link in links)
			[rows addObject:[NSString stringWithFormat:@"%@%@",
					[link[@"name"] length] ? [link[@"name"] stringByAppendingString:@" · "] : @"",
					link[@"link"]]];
		[TGAlertSheet showChoices:rows title:title destructiveIndex:-1
						   inView:me.view onChoice:^(NSInteger index){
			if (index == 0){
				[me createInviteLinkForFolder:folderId named:title];
				return;
			}
			[me showActionsForFolderLink:links[index - 1] folder:folderId
								   named:title];
		}];
	}];
}

- (void)createInviteLinkForFolder:(NSInteger)folderId named:(NSString *)title {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatsForFolderInviteLink:folderId completion:^(NSArray *chatIds){
		[[TGClient shared] createInviteLinkForFolder:folderId name:title
											chatIds:chatIds
										 completion:^(NSString *link){
			[TGAlertSheet showMessage:(link.length ? link
					: @"An error occurred.")
								title:@"Share Folder" inView:weakSelf.view];
		}];
	}];
}

- (void)showActionsForFolderLink:(NSDictionary *)link
						  folder:(NSInteger)folderId named:(NSString *)title {
	NSString *url = link[@"link"];
	if (!url.length)
		return;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Copy Link", @"Rename", @"Delete"]
							title:url destructiveIndex:2 inView:self.view
						 onChoice:^(NSInteger index){
		if (index == 0){
			[UIPasteboard generalPasteboard].string = url;
			[weakSelf toast:@"Link copied."];
			return;
		}
		if (index == 1){
			[TGAlertSheet showInput:@"Link" message:nil
						placeholder:@"Name" text:link[@"name"] ?: @""
							 action:@"Save" inView:weakSelf.view
						 onSubmit:^(NSString *name){
				[[TGClient shared] chatsForFolderInviteLink:folderId
						completion:^(NSArray *chatIds){
					[[TGClient shared] editInviteLinkForFolder:folderId link:url
							name:name chatIds:chatIds completion:^(BOOL ok){
						[weakSelf toast:(ok ? @"Done"
											: @"An error occurred.")];
					}];
				}];
			}];
			return;
		}
		[TGAlertSheet showConfirm:nil
							title:title action:@"Delete" destructive:YES
						   inView:weakSelf.view onConfirm:^{
			[[TGClient shared] deleteInviteLinkForFolder:folderId link:url
					completion:^(BOOL ok){
				[weakSelf toast:(ok ? @"Done"
									: @"An error occurred.")];
			}];
		}];
	}];
}

- (void)addFolderByInviteLink {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Add Folder"
					message:nil placeholder:@"t.me/addlist/…"
						 text:[UIPasteboard generalPasteboard].string
					 action:@"Check" inView:self.view
				 onSubmit:^(NSString *link){
		NSString *url = [link hasPrefix:@"http"] ? link
				: [@"https://" stringByAppendingString:link];
		[[TGClient shared] checkFolderInviteLink:url completion:^(NSDictionary *folder){
			TGSettingsViewController *me = weakSelf;
			if (!me)
				return;
			if (!folder){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Add Folder" inView:me.view];
				return;
			}
			NSArray *missing = folder[@"missing"] ?: @[];
			[TGAlertSheet showConfirm:nil title:@"Add Folder" action:@"Add"
						  destructive:NO inView:me.view onConfirm:^{
				[[TGClient shared] addFolderByInviteLink:url chatIds:missing
											 completion:^(BOOL ok){
					[me toast:(ok ? @"Done" : @"An error occurred.")];
				}];
			}];
		}];
	}];
}

- (void)addChatToFolder:(NSInteger)folderId named:(NSString *)title {
	TGForwardPicker *picker = [[TGForwardPicker alloc] init];
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(int64_t chatId){
		[[TGClient shared] folderDetails:folderId completion:^(NSDictionary *current){
			TGSettingsViewController *me = weakSelf;
			if (!current){
				[me toast:@"An error occurred."];
				return;
			}
			NSArray *included = current[@"included_chat_ids"] ?: @[];
			if ([included containsObject:@(chatId)]){
				(void)title;
				[me toast:@"Done"];
				return;
			}
			[[TGClient shared] editFolder:folderId
									 name:nil
									chats:[included arrayByAddingObject:@(chatId)]
							   completion:^(BOOL ok){
				(void)title;
				[me toast:ok ? @"Done" : @"An error occurred."];
			}];
		}];
	};
	picker.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:picker animated:YES];
}

- (void)removeChatFromFolder:(NSInteger)folderId named:(NSString *)title {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] folderDetails:folderId completion:^(NSDictionary *current){
		TGSettingsViewController *me = weakSelf;
		NSArray *included = current[@"included_chat_ids"] ?: @[];
		if (!included.count){
			(void)title;
			[me toast:@"Empty"];
			return;
		}

		NSMutableArray *names = [NSMutableArray array];
		for (NSNumber *chatId in included)
			[names addObject:TGChatNameForId(chatId)];
		[TGAlertSheet showChoices:names
							title:title
				 destructiveIndex:-1
						   inView:me.view
						 onChoice:^(NSInteger index){
			NSMutableArray *left = [included mutableCopy];
			[left removeObjectAtIndex:(NSUInteger)index];
			[[TGClient shared] editFolder:folderId name:nil chats:left
							   completion:^(BOOL ok){
				(void)title;
				[me toast:ok ? @"Done" : @"An error occurred."];
			}];
		}];
	}];
}

- (NSArray *)downloadSections {
	__weak typeof(self) weakSelf = self;

	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *download in self.downloads){
		long long size = [download[@"size"] longLongValue];
		// The pack has no "Paused"; its "Pause" (Пауза) reads as the state.
		NSString *state = [download[@"done"] boolValue] ? TGLocalized(@"Done")
				: ([download[@"paused"] boolValue] ? TGLocalized(@"Pause")
												   : TGLocalized(@"Downloading"));
		[rows addObject:TGTapRow(download[@"name"],
				[NSString stringWithFormat:@"%@ - %@", TGBytes(size), state], ^{
			[weakSelf runDownloadActionFor:download];
		})];
	}

	NSMutableArray *sections = [NSMutableArray array];
	[sections addObject:TGSection(self.downloads.count ? @"Files" : nil, nil, rows)];

	if (self.downloads.count)
		[sections addObject:TGSection(nil, nil, @[
			TGActionRow(self.activeDownloads > 0 ? @"Pause All" : @"Resume All", ^{
				[[TGClient shared] setAllDownloadsPaused:
						weakSelf.activeDownloads > 0];
				[weakSelf loadForPage];
			}),
			TGRedRow(@"Clear Download List", ^{
				[TGAlertSheet showConfirm:nil
									title:@"Clear Download List"
								   action:@"Clear"
							  destructive:YES
								   inView:weakSelf.view
								onConfirm:^{
					[[TGClient shared] clearDownloadsDeletingFromCache:YES];
					[weakSelf loadForPage];
				}];
			}),
		])];

	return sections;
}

- (void)runDownloadActionFor:(NSDictionary *)download {
	NSInteger fileId = [download[@"fileId"] integerValue];
	BOOL done = [download[@"done"] boolValue];
	BOOL paused = [download[@"paused"] boolValue];
	__weak typeof(self) weakSelf = self;

	NSMutableArray *choices = [NSMutableArray array];
	if (!done)
		[choices addObject:paused ? @"Resume" : @"Pause"];
	[choices addObject:@"File Info"];
	[choices addObject:@"Remove"];
	[choices addObject:@"Delete"];

	[TGAlertSheet showChoices:choices
						title:download[@"name"]
			 destructiveIndex:(NSInteger)choices.count - 1
					   inView:self.view
					 onChoice:^(NSInteger index){
		NSString *choice = choices[(NSUInteger)index];
		if ([choice isEqualToString:@"Pause"] || [choice isEqualToString:@"Resume"]){
			[[TGClient shared] setDownloadOfFile:fileId
										  paused:[choice isEqualToString:@"Pause"]];
			[weakSelf loadForPage];
		} else if ([choice isEqualToString:@"File Info"]){
			// The action sheet has to be gone before a second presentation
			// starts, or UIKit drops the new one on iOS 6.
			dispatch_async(dispatch_get_main_queue(), ^{
				[TGFileInfoViewController presentForFile:fileId fromView:weakSelf.view];
			});
		} else if ([choice isEqualToString:@"Remove"]){
			[[TGClient shared] removeFileFromDownloads:fileId deleteFromCache:NO];
			[weakSelf loadForPage];
		} else {
			[[TGClient shared] removeFileFromDownloads:fileId deleteFromCache:YES];
			[weakSelf loadForPage];
		}
	}];
}

- (NSArray *)proxySections {
	__weak typeof(self) weakSelf = self;
	BOOL anyEnabled = NO;
	for (NSDictionary *proxy in self.proxies)
		anyEnabled = anyEnabled || [proxy[@"enabled"] boolValue];
	self.navigationItem.rightBarButtonItem = self.proxies.count
			? self.editButtonItem : nil;

	// The ping writes back into the row, so the list needs mutable records.
	// It is one copy per open, and only the proxy page reaches this method.
	if (self.proxies.count &&
			![self.proxies[0] isKindOfClass:NSMutableDictionary.class]){
		NSMutableArray *mutable = [NSMutableArray arrayWithCapacity:self.proxies.count];
		for (NSDictionary *proxy in self.proxies)
			[mutable addObject:[proxy mutableCopy]];
		self.proxies = mutable;
	}

	NSMutableArray *rows = [NSMutableArray array];
	[rows addObject:TGSwitchRow(@"Use Proxy", anyEnabled, ^(BOOL on){
		if (!on){
			[[TGClient shared] disableProxy];
			[weakSelf loadForPage];
			return;
		}
		for (NSDictionary *proxy in weakSelf.proxies){
			[[TGClient shared] enableProxy:[proxy[@"id"] integerValue]];
			break;
		}
		[weakSelf loadForPage];
	})];
	for (NSMutableDictionary *proxy in self.proxies){
		NSString *typeName = TGProxyTypeLabel(proxy[@"kind"]);
		// One ping per proxy per open. Official's ProxyServersStatuses polls;
		// this phone cannot afford that and the page only needs the answer
		// that is on screen.
		if (!proxy[@"pingState"]){
			proxy[@"pingState"] = @"pending";
			NSString *server = proxy[@"server"];
			NSInteger port = [proxy[@"port"] integerValue];
			NSString *kind = proxy[@"kind"];
			[[TGClient shared] pingProxyAtServer:server port:port kind:kind
										username:nil password:nil secret:nil
									  completion:^(double seconds){
				proxy[@"pingState"] = @"done";
				proxy[@"ping"] = @(seconds);
				if (weakSelf.page == TGSettingsPageProxy)
					[weakSelf rebuild];
			}];
		}
		BOOL enabled = [proxy[@"enabled"] boolValue];
		BOOL pending = [proxy[@"pingState"] isEqualToString:@"pending"];
		double ping = [proxy[@"ping"] doubleValue];
		BOOL connected = [TGClient shared].connectionState == TGConnectionStateReady;
		NSString *status = TGProxyRowStatusText(enabled,
				enabled ? (pending || !connected) : pending, ping, typeName);
		NSString *name = [NSString stringWithFormat:@"%@:%@",
				proxy[@"server"] ?: @"?", proxy[@"port"] ?: @0];
		[rows addObject:TGTapRow(name, status, ^{
			[weakSelf editProxyAddress:proxy named:name];
		})];
	}
	[rows addObject:TGActionRow(@"Add Proxy", ^{ [weakSelf addProxyByAsking]; })];

	return @[
		TGSection(@"Saved Proxies", nil, rows),
#if TG_DEV
		TGSection(@"WEB PROXY CARRIER",
				  @"A web proxy runs its page in the client. TDLib asks for "
				  @"the page's messages and its failure through these two "
				  @"requests.", @[
			[weakSelf tier2ProxyCarrierRow],
		]),
#endif
	];
}

- (BOOL)canEditProxyRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGSettingsProxyRowEditable(indexPath.row, (NSInteger)self.proxies.count);
}

- (void)commitProxyEditingStyle:(UITableViewCellEditingStyle)editingStyle
			   forRowAtIndexPath:(NSIndexPath *)indexPath
					 inTableView:(UITableView *)tableView {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	// Row 0 is the Use Proxy switch and the last row is Add Proxy; only the
	// saved proxies between them can be deleted.
	if (!TGSettingsProxyRowEditable(indexPath.row, (NSInteger)self.proxies.count))
		return;
	NSInteger index = indexPath.row - 1;
	[[TGClient shared] removeProxy:[self.proxies[(NSUInteger)index][@"id"] integerValue]];
	[self loadForPage];
}

- (void)addProxyByAsking {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Add Proxy"
					message:nil
				placeholder:@"t.me/proxy?... or 1.2.3.4:1080"
					   text:nil
					 action:@"Add"
					 inView:self.view
				   onSubmit:^(NSString *text){
		TGSettingsViewController *me = weakSelf;
		void (^added)(NSInteger) = ^(NSInteger proxyId){
			if (!proxyId){
				[me toast:@"An error occurred."];
				return;
			}
			[me loadForPage];
		};

		if ([text rangeOfString:@"proxy"].location != NSNotFound &&
			[text rangeOfString:@"?"].location != NSNotFound){
			if (![[TGClient shared] addProxyFromLink:text completion:added])
				[me toast:@"An error occurred."];
			return;
		}

		NSArray *parts = [text componentsSeparatedByString:@":"];
		NSInteger port = parts.count > 1 ? [parts[1] integerValue] : 0;
		if (parts.count < 2 || port <= 0){
			[me toast:@"An error occurred."];
			return;
		}
		[[TGClient shared] addProxyAtServer:parts[0] port:port kind:@"socks5"
								   username:nil password:nil secret:nil
									 enable:YES completion:added];
	}];
}

- (void)runProxyActionFor:(NSDictionary *)proxy {
	NSInteger proxyId = [proxy[@"id"] integerValue];
	NSString *name = [NSString stringWithFormat:@"%@:%@",
			proxy[@"server"] ?: @"?", proxy[@"port"] ?: @0];
	__weak typeof(self) weakSelf = self;

	[TGAlertSheet showChoices:@[@"Use Proxy", @"Proxy Details",
								@"Proxy Details", @"Remove"]
						title:name
			 destructiveIndex:3
					   inView:self.view
					 onChoice:^(NSInteger index){
		TGSettingsViewController *me = weakSelf;
		if (index == 0){
			[[TGClient shared] enableProxy:proxyId];
			[me loadForPage];
		} else if (index == 1){
			[me checkProxy:proxy named:name];
		} else if (index == 2){
			[me editProxyAddress:proxy named:name];
		} else {
			[[TGClient shared] removeProxy:proxyId];
			[me loadForPage];
		}
	}];
}

- (void)checkProxy:(NSDictionary *)proxy named:(NSString *)name {
	__weak typeof(self) weakSelf = self;
	NSString *server = proxy[@"server"];
	NSInteger port = [proxy[@"port"] integerValue];
	NSString *kind = proxy[@"kind"];

	[[TGClient shared] testProxyAtServer:server port:port kind:kind
								username:nil password:nil secret:nil
							  completion:^(BOOL works){
		TGSettingsViewController *me = weakSelf;
		if (!works){
			[me toast:[NSString stringWithFormat:
					@"%@ will not carry Telegram.", name]];
			return;
		}
		[[TGClient shared] pingProxyAtServer:server port:port kind:kind
									username:nil password:nil secret:nil
								  completion:^(double seconds){
			[me toast:seconds >= 0
					? [NSString stringWithFormat:@"%@ works - %.0f ms",
							name, seconds * 1000.0]
					: [NSString stringWithFormat:@"%@ works", name]];
		}];
	}];
}

- (void)editProxyAddress:(NSDictionary *)proxy named:(NSString *)name {
	NSInteger proxyId = [proxy[@"id"] integerValue];
	BOOL wasEnabled = [proxy[@"enabled"] boolValue];
	NSString *kind = proxy[@"kind"];
	__weak typeof(self) weakSelf = self;

	[TGAlertSheet showInput:@"Proxy Details"
					message:nil
				placeholder:@"1.2.3.4:1080"
					   text:name
					 action:@"Save"
					 inView:self.view
				   onSubmit:^(NSString *text){
		TGSettingsViewController *me = weakSelf;
		NSArray *parts = [text componentsSeparatedByString:@":"];
		NSInteger port = parts.count > 1 ? [parts[1] integerValue] : 0;
		if (parts.count < 2 || port <= 0){
			[me toast:@"An error occurred."];
			return;
		}
		[[TGClient shared] editProxy:proxyId
							  server:parts[0]
								port:port
								kind:kind
							username:nil password:nil secret:nil
							  enable:wasEnabled
						  completion:^(BOOL ok){
			if (!ok){
				[me toast:@"An error occurred."];
				return;
			}
			[me loadForPage];
		}];
	}];
}

- (void)clearTemporaryFiles {
	NSFileManager *files = [NSFileManager defaultManager];
	NSString *tmp = NSTemporaryDirectory();
	long long freed = 0;
	for (NSString *entry in [files contentsOfDirectoryAtPath:tmp error:nil]){
		NSString *path = [tmp stringByAppendingPathComponent:entry];
		freed += [[files attributesOfItemAtPath:path error:nil] fileSize];
		[files removeItemAtPath:path error:nil];
	}
	[self toast:@"Done"];
}

/// Everything this account sent as a file, one sheet: name, size and the
/// day, and the chat it lives in if the list knows it.
- (void)showSentFilesSheet {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sentDocuments:nil completion:^(NSArray *messages){
		TGSettingsViewController *me = weakSelf;
		if (!me) return;
		if (!messages.count){
			[weakSelf toast:@"Empty"];
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *m in messages){
			NSString *name = (m[@"content"] ?: @{})[@"document"][@"file_name"];
			NSString *line = name.length ? name : @"File";
			NSString *chat = [[TGClient shared] titleForChat:
					[m[@"chat_id"] longLongValue]];
			if (chat.length)
				line = [line stringByAppendingFormat:@" — %@", chat];
			[rows addObject:line];
		}
		[TGAlertSheet showChoices:rows
							title:@"Files"
				 destructiveIndex:-1
						   inView:me.view
						 onChoice:^(NSInteger index){
			if (index >= (NSInteger)messages.count)
				return;
			NSDictionary *m = messages[index];
			NSString *title = [[TGClient shared] titleForChat:
					[m[@"chat_id"] longLongValue]] ?: @"Chat";
			Class chatClass = NSClassFromString(@"TGChatViewController");
			UIViewController *chat = [[chatClass alloc] init];
			[chat setValue:m[@"chat_id"] forKey:@"chatId"];
			[chat setValue:title forKey:@"chatTitle"];
			chat.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:chat animated:YES];
		}];
	}];
}

- (NSString *)autoDownloadPresetSummary {
	NSDictionary *medium = self.autoDownloadPresets[@"medium"];
	if (![medium isKindOfClass:NSDictionary.class])
		return @"Loading...";
	return [NSString stringWithFormat:@"Medium: photos %@, videos %@",
			TGBytes([medium[@"maxPhotoSize"] longLongValue]),
			TGBytes([medium[@"maxVideoSize"] longLongValue])];
}

- (void)chooseAutoDownloadPreset {
	if (!self.autoDownloadPresets){
		[self toast:@"An error occurred."];
		return;
	}
	__weak typeof(self) weakSelf = self;
	NSArray *keys = @[@"low", @"medium", @"high"];
	NSArray *names = @[@"Low (roaming)", @"Medium (mobile)", @"High (Wi-Fi)"];
	[TGAlertSheet showChoices:names
						title:@"Auto-Download"
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		TGSettingsViewController *me = weakSelf;
		if (!me || index >= (NSInteger)keys.count)
			return;
		NSDictionary *preset = me.autoDownloadPresets[keys[(NSUInteger)index]];
		NSString *network = @[@"roaming", @"mobile", @"wifi"][(NSUInteger)index];
		[[TGClient shared] applyAutoDownloadPreset:preset forNetwork:network
										completion:^(BOOL ok){
			if (!ok){
				[me toast:@"An error occurred."];
				return;
			}
			// The two switches read the app's own copy, so move whichever
			// network the chosen preset belongs to.
			BOOL enabled = [preset[@"enabled"] boolValue];
			if ([network isEqualToString:@"mobile"])
				[[NSUserDefaults standardUserDefaults] setBool:enabled
													   forKey:@"TGAutoDownloadMobile"];
			else if ([network isEqualToString:@"wifi"])
				[[NSUserDefaults standardUserDefaults] setBool:enabled
													   forKey:@"TGAutoDownloadWifi"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[me toast:@"Done"];
			[me rebuild];
		}];
	}];
}

- (NSArray *)autosaveSections {
	__weak typeof(self) weakSelf = self;
	if (!self.autosaveSettings){
		return @[TGSection(nil, @"Loading...", @[])];
	}

	NSDictionary *settings = self.autosaveSettings;
	NSMutableArray *sections = [NSMutableArray array];
	NSArray *scopes = @[
		@[@"private", @"Private Chats"],
		@[@"groups", @"Groups"],
		@[@"channels", @"Channels"],
	];
	for (NSArray *pair in scopes){
		NSString *scope = pair[0];
		if (self.autosaveScope.length && ![self.autosaveScope isEqualToString:scope])
			continue;
		NSDictionary *scopeSettings = settings[scope] ?: @{};
		BOOL photos = [scopeSettings[@"photos"] boolValue];
		BOOL videos = [scopeSettings[@"videos"] boolValue];
		[sections addObject:TGSection(pair[1], nil, @[
			TGSwitchRow(@"Photos", photos, ^(BOOL on){
				[weakSelf changeAutosaveScope:scope photos:on videos:videos];
			}),
			TGSwitchRow(@"Videos", videos, ^(BOOL on){
				[weakSelf changeAutosaveScope:scope photos:photos videos:on];
			}),
		])];
	}

	NSArray *exceptions = settings[@"exceptions"] ?: @[];
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *exception in exceptions){
		NSString *detail = [NSString stringWithFormat:@"%@ - %@",
				[exception[@"photos"] boolValue] ? @"On" : @"Off",
				[exception[@"videos"] boolValue] ? @"On" : @"Off"];
		int64_t chatId = [exception[@"chatId"] longLongValue];
		NSString *title = TGChatNameForId(exception[@"chatId"]);
		[rows addObject:TGTapRow(title, detail, ^{
			[weakSelf openChat:chatId title:title];
		})];
	}
	if (rows.count)
		[rows addObject:TGRedRow(@"Clear", ^{
			[weakSelf clearAutosaveExceptions];
		})];
	[sections addObject:TGSection(@"Exceptions",
			rows.count ? nil : @"Empty", rows)];

	return sections;
}

- (void)changeAutosaveScope:(NSString *)scope photos:(BOOL)photos videos:(BOOL)videos {
	NSMutableDictionary *settings = [self.autosaveSettings mutableCopy];
	if (!settings)
		return;
	NSMutableDictionary *scopeSettings = [settings[scope] mutableCopy];
	if (!scopeSettings)
		scopeSettings = [@{} mutableCopy];
	long long maxVideo = [scopeSettings[@"maxVideoSize"] longLongValue];
	if (maxVideo <= 0)
		maxVideo = 10 * 1024 * 1024;
	scopeSettings[@"photos"] = @(photos);
	scopeSettings[@"videos"] = @(videos);
	scopeSettings[@"maxVideoSize"] = @(maxVideo);
	settings[scope] = scopeSettings;
	self.autosaveSettings = settings;
	[self rebuild];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setAutosaveSettingsForScope:scope
											 photos:photos
											 videos:videos
									   maxVideoSize:maxVideo
										 completion:^(BOOL ok){
		if (!ok)
			[weakSelf toast:@"An error occurred."];
	}];
}

- (void)clearAutosaveExceptions {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:@"Clear"
					   action:@"Clear"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGClient shared] clearAutosaveSettingsExceptionsWithCompletion:^(BOOL ok){
			if (!ok){
				[weakSelf toast:@"An error occurred."];
				return;
			}
			[[TGClient shared] autosaveSettingsWithCompletion:^(NSDictionary *settings){
				weakSelf.autosaveSettings = settings;
				[weakSelf rebuild];
			}];
		}];
	}];
}

@end