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
#import "TGSettingsPageModels.h"
#import "TGSettingsFormatting.h"
#import "TGRowsViewController.h"
#import "TGRows.h"
#import "TGRowCell.h"
#import <objc/runtime.h>
#import "TGChatListStore.h"
#import "TGMessageStore.h"
#import "TGProfileStore.h"
#import "TGSettingsStore.h"


static char TGAutoDownloadBaselineKey;

/// The model names a tile colour; the page owns the actual palette. One place
/// so every row of a section uses the same tile size and inset.
static UIColor *TGPageIconColour(NSString *name) {
	if ([name isEqualToString:@"green"])  return TGIconTileGreen();
	if ([name isEqualToString:@"azure"])  return TGIconTileAzure();
	if ([name isEqualToString:@"cyan"])   return TGIconTileCyan();
	if ([name isEqualToString:@"coral"])  return TGIconTileCoral();
	if ([name isEqualToString:@"sky"])    return TGIconTileSky();
	if ([name isEqualToString:@"amber"])  return TGIconTileAmber();
	if ([name isEqualToString:@"violet"]) return TGIconTileViolet();
	if ([name isEqualToString:@"orchid"]) return TGIconTileOrchid();
	if ([name isEqualToString:@"red"])    return TGIconTileRed();
	if ([name isEqualToString:@"slate"])  return TGIconTileSlate();
	if ([name isEqualToString:@"gold"])   return TGIconTileGold();
	return TGIconTileGrey();
}

/// A model row in the shared row shape. The caller attaches the tap or the
/// toggle; everything visible comes from the model.
static NSMutableDictionary *TGPageRowFromModel(NSDictionary *descriptor) {
	NSMutableDictionary *row = TGRow(descriptor[TGPageModelRowKind],
			descriptor[TGPageModelRowTitle]);
	if (descriptor[TGPageModelRowDetail])
		row[TGRowDetail] = descriptor[TGPageModelRowDetail];
	if (descriptor[TGPageModelRowIcon]){
		row[TGRowIcon] = descriptor[TGPageModelRowIcon];
		row[TGRowColour] = TGPageIconColour(descriptor[TGPageModelRowColour]);
	}
	if (descriptor[TGPageModelRowOn])
		row[TGRowOn] = descriptor[TGPageModelRowOn];
	return row;
}

static NSArray *TGPageSectionsFromModel(NSArray *model, NSArray *rows) {
	NSMutableArray *sections = [NSMutableArray array];
	for (NSUInteger i = 0; i < model.count; i++){
		NSDictionary *section = model[i];
		[sections addObject:TGSection(section[TGPageModelHeader],
				section[TGPageModelFooter], rows[i])];
	}
	return sections;
}

static NSString *TGChatNameForId(NSNumber *chatId) {
	for (NSArray *list in @[[TGChatListStore shared].chats ?: @[],
							[TGChatListStore shared].archivedChats ?: @[]])
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
@interface TGAutoDownloadConnectionViewController : TGRowsViewController
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
	[self rebuildSections];
}

- (void)setPreset:(NSDictionary *)preset {
	_preset = [preset copy];
	long long photo = [_preset[@"maxPhotoSize"] longLongValue];
	long long video = [_preset[@"maxVideoSize"] longLongValue];
	self.photoSizeText = photo > 0 ? TGSettingsAutoDownloadBytes(photo)
			: TGLocalized(@"Off");
	self.videoSizeText = video > 0 ? TGSettingsAutoDownloadBytes(video)
			: TGLocalized(@"Off");
	if (self.isViewLoaded)
		[self rebuildSections];
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
	[[TGSettingsStore shared] applyAutoDownloadPreset:next forNetwork:self.network
									completion:^(BOOL ok){
		if (ok && weakSelf.onChanged)
			weakSelf.onChanged();
	}];
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSMutableDictionary *master = [TGSwitchRow(TGLocalized(@"Auto-Download"),
			[self enabled], ^(BOOL on){ [weakSelf setEnabled:on]; }) mutableCopy];
	master[TGRowEnabled] = @([self.preset isKindOfClass:NSDictionary.class]);
	self.sections = @[TGSection(TGLocalized(@"Auto-Download"), nil, @[
		master,
		TGTapRow(TGLocalized(@"Photos"), self.photoSizeText, nil),
		TGTapRow(TGLocalized(@"Videos"), self.videoSizeText, nil),
	])];
	[self reloadRows];
}

@end

/// Network Usage, without the TDLib diagnostics that used to share its row.
@interface TGDataUsageViewController : TGRowsViewController
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
	self.title = TGLocalized(@"Data Usage");
	[self rebuildSections];
	__weak typeof(self) weakSelf = self;
	[[TGSettingsStore shared] networkStatsWithCompletion:^(long long sent, long long received){
		weakSelf.sent = sent;
		weakSelf.received = received;
		weakSelf.sentText = TGBytes(sent);
		weakSelf.receivedText = TGBytes(received);
		weakSelf.loaded = YES;
		[weakSelf rebuildSections];
	}];
}

- (void)rebuildSections {
	NSString *loading = TGLocalized(@"Loading...");
	NSString *received = self.loaded ? self.receivedText : loading;
	NSString *sent = self.loaded ? self.sentText : loading;
	__weak typeof(self) weakSelf = self;
	self.sections = @[
		TGSection(TGLocalized(@"Data Usage"), nil, @[
			TGTapRow(TGLocalized(@"Data Received"), received, nil),
			TGTapRow(TGLocalized(@"Data Sent"), sent, nil),
		]),
		TGSection(nil, nil, @[
			TGCentredDestructiveRow(TGLocalized(@"Reset Statistics"), ^{
				[weakSelf confirmReset];
			}),
		]),
	];
	[self reloadRows];
}

- (void)confirmReset {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:TGLocalized(@"Do you want to reset your usage statistics?")
						title:TGLocalized(@"Reset Statistics")
					   action:TGLocalized(@"Reset")
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGSettingsStore shared] resetNetworkStats];
		weakSelf.sent = 0;
		weakSelf.received = 0;
		weakSelf.sentText = TGBytes(0);
		weakSelf.receivedText = TGBytes(0);
		[weakSelf rebuildSections];
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
	// Official's auto-download value is one compact size. A fractional zero
	// ("120,0 МБ") was wider than the value column and got an ellipsis.
	if ([medium isKindOfClass:NSDictionary.class] &&
		[medium[@"enabled"] boolValue])
		cellularDetail = TGSettingsAutoDownloadBytes(
				[medium[@"maxPhotoSize"] longLongValue]);
	if ([high isKindOfClass:NSDictionary.class] &&
		[high[@"enabled"] boolValue])
		wifiDetail = TGSettingsAutoDownloadBytes(
				[high[@"maxPhotoSize"] longLongValue]);

	NSMutableArray *autosaveRows = [NSMutableArray array];
	NSArray *scopes = @[
		@[@"private", @"Private Chats", @"contacts", @"azure"],
		@[@"groups", @"Groups", @"folder", @"green"],
		@[@"channels", @"Channels", @"notifications", @"sky"],
	];
	for (NSArray *pair in scopes){
		NSString *scope = pair[0];
		NSDictionary *scopeSettings = autosave[scope];
		BOOL on = [scopeSettings[@"photos"] boolValue] ||
				[scopeSettings[@"videos"] boolValue];
		[autosaveRows addObject:TGIconTapOpenRow(pair[1], on ? @"On" : @"Off",
				pair[2], TGPageIconColour(pair[3]), ^{
			weakSelf.autosaveScope = scope;
			[weakSelf openPage:TGSettingsPageAutosave];
		})];
	}

	NSMutableArray *downloadRows = [NSMutableArray array];
	[downloadRows addObject:TGIconTapOpenRow(@"Using Cellular", cellularDetail,
			@"cellular", TGIconTileGrey(), ^{
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
	[downloadRows addObject:TGIconTapOpenRow(@"Using Wi-Fi", wifiDetail,
			@"wifi", TGIconTileAzure(), ^{
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
	if (weakSelf.autoDownloadChanged){
		NSMutableDictionary *reset = [TGActionRow(@"Reset", ^{
			NSDictionary *mobile = (baseline ?: weakSelf.autoDownloadPresets)[@"medium"];
			NSDictionary *wifi = (baseline ?: weakSelf.autoDownloadPresets)[@"high"];
			[[TGSettingsStore shared] applyAutoDownloadPreset:mobile forNetwork:@"mobile"
											completion:^(BOOL ok){
				[[TGSettingsStore shared] applyAutoDownloadPreset:wifi forNetwork:@"wifi"
												completion:^(BOOL ok2){
					if (ok && ok2 && baseline)
						weakSelf.autoDownloadPresets = baseline;
					weakSelf.autoDownloadChanged = !(ok && ok2);
					[weakSelf toast:(ok && ok2 ? @"Done" : @"An error occurred.")];
					[weakSelf rebuild];
				}];
			}];
		}) mutableCopy];
		reset[TGRowIcon] = @"undo";
		reset[TGRowColour] = TGIconTileGrey();
		[downloadRows addObject:reset];
	} else {
		NSMutableDictionary *reset = TGRow(TGKindPlain, @"Reset");
		reset[TGRowIcon] = @"undo";
		reset[TGRowColour] = TGIconTileGrey();
		[downloadRows addObject:reset];
	}

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

		TGSection(@"Auto-Download", nil, downloadRows),

		TGSection(@"Save to Photos",
			@"Automatically save all new media from private chats to your Photos app.",
			autosaveRows),

		// Official's connectionProxy is a plain disclosure row: no icon in
		// this section.
		TGSection(@"Connection Type", nil, @[
			TGOpenRow(@"Proxy", weakSelf.rootProxyDetail ?: @"None", ^{
				[weakSelf openPage:TGSettingsPageProxy];
			}),
		]),
	];
}

- (NSArray *)powerSavingSections {
	__weak typeof(self) weakSelf = self;
	NSArray *model = TGPowerSavingPageModel(
			[TGCapabilities animatedStickersWanted],
			[TGCapabilities gifAutoplayWanted],
			[TGCapabilities wallpaperWanted]);
	NSMutableArray *sectionRows = [NSMutableArray array];
	for (NSDictionary *section in model){
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *descriptor in section[TGPageModelRows]){
			NSMutableDictionary *row = TGPageRowFromModel(descriptor);
			NSString *action = descriptor[TGPageModelRowAction];
			if ([action isEqualToString:@"gifs"]){
				row[TGRowToggle] = [^(BOOL on){
					[TGCapabilities setGifAutoplayWanted:on];
					[weakSelf rebuild];
				} copy];
			} else if ([action isEqualToString:@"stickers"]){
				row[TGRowToggle] = [^(BOOL on){
					[TGCapabilities setAnimatedStickersWanted:on];
					[weakSelf rebuild];
				} copy];
			} else if ([action isEqualToString:@"wallpaper"]){
				row[TGRowToggle] = [^(BOOL on){
					[TGCapabilities setWallpaperWanted:on];
					[weakSelf rebuild];
				} copy];
			}
			[rows addObject:row];
		}
		[sectionRows addObject:rows];
	}
	return TGPageSectionsFromModel(model, sectionRows);
}

- (NSArray *)folderSections {
	__weak typeof(self) weakSelf = self;
	NSArray *folders = [TGChatListStore shared].folders;

	if (!weakSelf.folderTagsLoaded){
		weakSelf.folderTagsEnabled = YES;
		weakSelf.folderTagsLoaded = YES;
	}
#if TG_DEV
	BOOL dev = YES;
#else
	BOOL dev = NO;
#endif
	NSArray *model = TGFoldersPageModel(folders, self.recommendedFolders,
			self.folderChatCounts, self.folderTagsEnabled, dev);

	NSMutableArray *sectionRows = [NSMutableArray array];
	for (NSDictionary *section in model){
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *descriptor in section[TGPageModelRows]){
			NSMutableDictionary *row = TGPageRowFromModel(descriptor);
			NSString *action = descriptor[TGPageModelRowAction];
			if ([action isEqualToString:@"createFolder"]){
				row[TGRowTap] = [^{
					[TGAlertSheet showInput:@"New Folder"
									message:nil
								placeholder:@"Name"
									   text:nil
									 action:@"Create"
									 inView:weakSelf.view
								   onSubmit:^(NSString *name){
						[[TGSettingsStore shared] createFolderNamed:name icon:nil withChats:@[]
												  completion:^(NSInteger folderId){
							if (!folderId){
								[weakSelf toast:@"An error occurred."];
								return;
							}
							[weakSelf toast:@"Done"];
						}];
					}];
				} copy];
			} else if ([action isEqualToString:@"openFolder"]){
				NSInteger index = [descriptor[TGPageModelRowIndex] integerValue];
				if (index < 0 || index >= (NSInteger)folders.count)
					continue;
				NSDictionary *folder = folders[(NSUInteger)index];
				row[TGRowOpens] = @YES;
				row[TGRowTap] = [^{
					[weakSelf runFolderActionFor:folder];
				} copy];
			} else if ([action isEqualToString:@"addFolderLink"]){
				row[TGRowTap] = [^{ [weakSelf addFolderByInviteLink]; } copy];
			} else if ([action isEqualToString:@"createRecommended"]){
				NSInteger index = [descriptor[TGPageModelRowIndex] integerValue];
				NSArray *recommended = weakSelf.recommendedFolders;
				if (index < 0 || index >= (NSInteger)recommended.count)
					continue;
				NSDictionary *entry = recommended[(NSUInteger)index];
				row[TGRowTap] = [^{
					[[TGSettingsStore shared] createRecommendedFolder:entry[@"folder"]
													completion:^(NSInteger folderId){
						[weakSelf toast:folderId ? @"Done" : @"An error occurred."];
					}];
				} copy];
			} else if ([action isEqualToString:@"toggleTags"]){
				row[TGRowToggle] = [^(BOOL on){
					weakSelf.folderTagsEnabled = on;
					[[TGSettingsStore shared] toggleFolderTags:on];
				} copy];
			}
			[rows addObject:row];
		}
		[sectionRows addObject:rows];
	}
	return TGPageSectionsFromModel(model, sectionRows);
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
				[[TGSettingsStore shared] editFolder:folderId name:name chats:nil
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
	[[TGSettingsStore shared] chatsToLeaveForFolder:folderId completion:^(NSArray *suggested){
		TGSettingsViewController *me = weakSelf;
		if (!me)
			return;
		void (^remove)(NSArray *) = ^(NSArray *leave){
			[[TGSettingsStore shared] deleteFolder:folderId leavingChats:leave];
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
	[[TGSettingsStore shared] folderDetails:[folder[@"id"] integerValue]
							 completion:^(NSDictionary *current){
		if (!current){
			[weakSelf toast:@"An error occurred."];
			return;
		}
		[[TGSettingsStore shared] defaultIconNameForFolder:current
										 completion:^(NSString *name){
			(void)name;
			[TGAlertSheet showMessage:@"Done"
								title:@"Default" inView:weakSelf.view];
		}];
	}];
}

- (void)showChatCountForFolder:(NSDictionary *)folder {
	__weak typeof(self) weakSelf = self;
	[[TGSettingsStore shared] folderDetails:[folder[@"id"] integerValue]
							 completion:^(NSDictionary *current){
		if (!current){
			[weakSelf toast:@"An error occurred."];
			return;
		}
		[[TGSettingsStore shared] chatCountForFolder:current completion:^(NSInteger count){
			[TGAlertSheet showMessage:[NSString stringWithFormat:@"%ld", (long)count]
								title:@"Chats" inView:weakSelf.view];
		}];
	}];
}

- (void)showNewChatsForFolder:(NSInteger)folderId named:(NSString *)title {
	__weak typeof(self) weakSelf = self;
	[[TGSettingsStore shared] newChatsForFolder:folderId completion:^(NSArray *chatIds){
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
			[[TGSettingsStore shared] processNewChats:chatIds forFolder:folderId
									completion:^(BOOL ok){
				[me toast:(ok ? @"Done" : @"An error occurred.")];
			}];
		}];
	}];
}

- (void)showInviteLinksForFolder:(NSInteger)folderId named:(NSString *)title {
	__weak typeof(self) weakSelf = self;
	[[TGSettingsStore shared] inviteLinksForFolder:folderId completion:^(NSArray *links){
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
	[[TGSettingsStore shared] chatsForFolderInviteLink:folderId completion:^(NSArray *chatIds){
		[[TGSettingsStore shared] createInviteLinkForFolder:folderId name:title
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
				[[TGSettingsStore shared] chatsForFolderInviteLink:folderId
						completion:^(NSArray *chatIds){
					[[TGSettingsStore shared] editInviteLinkForFolder:folderId link:url
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
			[[TGSettingsStore shared] deleteInviteLinkForFolder:folderId link:url
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
		[[TGSettingsStore shared] checkFolderInviteLink:url completion:^(NSDictionary *folder){
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
				[[TGSettingsStore shared] addFolderByInviteLink:url chatIds:missing
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
		[[TGSettingsStore shared] folderDetails:folderId completion:^(NSDictionary *current){
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
			[[TGSettingsStore shared] editFolder:folderId
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
	[[TGSettingsStore shared] folderDetails:folderId completion:^(NSDictionary *current){
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
			[[TGSettingsStore shared] editFolder:folderId name:nil chats:left
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
	// An empty page read as broken; it now says why there is nothing to show.
	if (!self.downloads.count)
		return @[TGSection(nil,
				@"No downloads yet. Files you download in chats will appear here.", @[])];
	[sections addObject:TGSection(@"Files", nil, rows)];

	if (self.downloads.count)
		[sections addObject:TGSection(nil, nil, @[
			TGActionRow(self.activeDownloads > 0 ? @"Pause All" : @"Resume All", ^{
				[[TGSettingsStore shared] setAllDownloadsPaused:
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
					[[TGSettingsStore shared] clearDownloadsDeletingFromCache:YES];
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
			[[TGSettingsStore shared] setDownloadOfFile:fileId
										  paused:[choice isEqualToString:@"Pause"]];
			[weakSelf loadForPage];
		} else if ([choice isEqualToString:@"File Info"]){
			// The action sheet has to be gone before a second presentation
			// starts, or UIKit drops the new one on iOS 6.
			dispatch_async(dispatch_get_main_queue(), ^{
				[TGFileInfoViewController presentForFile:fileId fromView:weakSelf.view];
			});
		} else if ([choice isEqualToString:@"Remove"]){
			[[TGSettingsStore shared] removeFileFromDownloads:fileId deleteFromCache:NO];
			[weakSelf loadForPage];
		} else {
			[[TGSettingsStore shared] removeFileFromDownloads:fileId deleteFromCache:YES];
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

	for (NSMutableDictionary *proxy in self.proxies){
		// One ping per proxy per open. Official's ProxyServersStatuses polls;
		// this phone cannot afford that and the page only needs the answer
		// that is on screen.
		if (!proxy[@"pingState"]){
			proxy[@"pingState"] = @"pending";
			NSString *server = proxy[@"server"];
			NSInteger port = [proxy[@"port"] integerValue];
			NSString *kind = proxy[@"kind"];
			[[TGSettingsStore shared] pingProxyAtServer:server port:port kind:kind
										username:nil password:nil secret:nil
									  completion:^(double seconds){
				proxy[@"pingState"] = @"done";
				proxy[@"ping"] = @(seconds);
				if (weakSelf.page == TGSettingsPageProxy)
					[weakSelf rebuild];
			}];
		}
	}

	BOOL connected = [TGProfileStore shared].connectionState == TGConnectionStateReady;
	NSArray *model = TGProxyPageModel(self.proxies, anyEnabled, connected, NO);
	NSMutableArray *sectionRows = [NSMutableArray array];
	for (NSDictionary *section in model){
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *descriptor in section[TGPageModelRows]){
			NSMutableDictionary *row = TGPageRowFromModel(descriptor);
			NSString *action = descriptor[TGPageModelRowAction];
			if ([action isEqualToString:@"useProxy"]){
				row[TGRowToggle] = [^(BOOL on){
					if (!on){
						[[TGSettingsStore shared] disableProxy];
						[weakSelf loadForPage];
						return;
					}
					for (NSDictionary *proxy in weakSelf.proxies){
						[[TGSettingsStore shared] enableProxy:[proxy[@"id"] integerValue]];
						break;
					}
					[weakSelf loadForPage];
				} copy];
			} else if ([action isEqualToString:@"addProxy"]){
				row[TGRowTap] = [^{ [weakSelf addProxyByAsking]; } copy];
			} else if ([action isEqualToString:@"openProxy"]){
				NSInteger index = [descriptor[TGPageModelRowIndex] integerValue];
				if (index < 0 || index >= (NSInteger)weakSelf.proxies.count)
					continue;
				NSDictionary *proxy = weakSelf.proxies[(NSUInteger)index];
				NSString *name = descriptor[TGPageModelRowTitle];
				row[TGRowTap] = [^{
					[weakSelf editProxyAddress:proxy named:name];
				} copy];
			}
			[rows addObject:row];
		}
		[sectionRows addObject:rows];
	}
	return TGPageSectionsFromModel(model, sectionRows);
}

- (BOOL)canEditProxyRowAtIndexPath:(NSIndexPath *)indexPath {
	// Section 0 is the Use Proxy switch. Section 1 starts with Add Proxy, so
	// the saved servers are rows 1..count there.
	if (indexPath.section != 1)
		return NO;
	return TGSettingsProxyRowEditable(indexPath.row, (NSInteger)self.proxies.count);
}

- (void)commitProxyEditingStyle:(UITableViewCellEditingStyle)editingStyle
			   forRowAtIndexPath:(NSIndexPath *)indexPath
					 inTableView:(UITableView *)tableView {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	// Section 1 starts with Add Proxy; only the saved proxies after it can
	// be deleted.
	if (indexPath.section != 1 ||
		!TGSettingsProxyRowEditable(indexPath.row,
				(NSInteger)self.proxies.count))
		return;
	NSInteger index = indexPath.row - 1;
	[[TGSettingsStore shared] removeProxy:[self.proxies[(NSUInteger)index][@"id"] integerValue]];
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
			if (![[TGSettingsStore shared] addProxyFromLink:text completion:added])
				[me toast:@"An error occurred."];
			return;
		}

		NSArray *parts = [text componentsSeparatedByString:@":"];
		NSInteger port = parts.count > 1 ? [parts[1] integerValue] : 0;
		if (parts.count < 2 || port <= 0){
			[me toast:@"An error occurred."];
			return;
		}
		[[TGSettingsStore shared] addProxyAtServer:parts[0] port:port kind:@"socks5"
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
			[[TGSettingsStore shared] enableProxy:proxyId];
			[me loadForPage];
		} else if (index == 1){
			[me checkProxy:proxy named:name];
		} else if (index == 2){
			[me editProxyAddress:proxy named:name];
		} else {
			[[TGSettingsStore shared] removeProxy:proxyId];
			[me loadForPage];
		}
	}];
}

- (void)checkProxy:(NSDictionary *)proxy named:(NSString *)name {
	__weak typeof(self) weakSelf = self;
	NSString *server = proxy[@"server"];
	NSInteger port = [proxy[@"port"] integerValue];
	NSString *kind = proxy[@"kind"];

	[[TGSettingsStore shared] testProxyAtServer:server port:port kind:kind
								username:nil password:nil secret:nil
							  completion:^(BOOL works){
		TGSettingsViewController *me = weakSelf;
		if (!works){
			[me toast:[NSString stringWithFormat:
					@"%@ will not carry Telegram.", name]];
			return;
		}
		[[TGSettingsStore shared] pingProxyAtServer:server port:port kind:kind
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
		[[TGSettingsStore shared] editProxy:proxyId
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
	[[TGSettingsStore shared] sentDocuments:nil completion:^(NSArray *messages){
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
			NSString *chat = [[TGMessageStore shared] titleForChat:
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
			NSString *title = [[TGMessageStore shared] titleForChat:
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
		[[TGSettingsStore shared] applyAutoDownloadPreset:preset forNetwork:network
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
	[[TGSettingsStore shared] setAutosaveSettingsForScope:scope
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
		[[TGSettingsStore shared] clearAutosaveSettingsExceptionsWithCompletion:^(BOOL ok){
			if (!ok){
				[weakSelf toast:@"An error occurred."];
				return;
			}
			[[TGSettingsStore shared] autosaveSettingsWithCompletion:^(NSDictionary *settings){
				weakSelf.autosaveSettings = settings;
				[weakSelf rebuild];
			}];
		}];
	}];
}

@end