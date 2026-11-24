#import "TGDeviceViewController.h"
#import "TGDevice.h"
#import "TGCapabilities.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGSettingsFormatting.h"
#import "TGTheme.h"
#import "TGRows.h"
#import "TGRowCell.h"
#import "TGAccountStore.h"
#import "TGSettingsStore.h"
#import "TGDatabaseKey.h"


@interface TGDeviceViewController ()
@property (nonatomic, strong) NSArray *capabilities;
@end

@implementation TGDeviceViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.pageKind = TGPageKindSettings;
	self.title = TGLocalized(@"Device");
	self.capabilities = [TGCapabilities all];
	[self rebuildSections];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)rebuildSections {
	NSDictionary *info = [NSBundle mainBundle].infoDictionary;
	NSMutableArray *sections = [NSMutableArray array];

	[sections addObject:TGSection(TGSettingsHeaderText(@"SOFTWARE"), nil, @[
		TGTapRow(TGLocalized(@"iOS"),
				[UIDevice currentDevice].systemVersion, nil),
		TGTapRow(TGLocalized(@"LegacyTG"),
				[NSString stringWithFormat:@"%@ (%@)",
						info[@"CFBundleShortVersionString"] ?: @"?",
						info[@"CFBundleVersion"] ?: @"?"], nil),
	])];

	[sections addObject:TGSection(TGSettingsHeaderText(@"HARDWARE"), nil, @[
		TGTapRow(TGLocalized(@"Model"), [TGDevice modelName], nil),
		TGTapRow(TGLocalized(@"Chip and Memory"),
				[NSString stringWithFormat:@"%@, %lu MB",
						[TGDevice chip] ?: @"?",
						(unsigned long)[TGDevice memoryMB]], nil),
		TGTapRow(TGLocalized(@"Device Tier"), [TGDevice tierName], nil),
	])];

	__weak typeof(self) weakSelf = self;
	NSMutableArray *tuningRows = [NSMutableArray array];

	[tuningRows addObject:TGSwitchRow(TGLocalized(@"Database Encryption"),
			[TGCapabilities databaseEncryptionWanted], ^(BOOL on){
		[TGCapabilities setDatabaseEncryptionWanted:on];
		if (on){
			NSData *newKey = [TGDatabaseKey ensureKey];
			[[TGSettingsStore shared] setDatabaseEncryptionKey:newKey
					completion:^(BOOL ok, NSString *error){
				if (!ok){
					[TGCapabilities setDatabaseEncryptionWanted:NO];
					[TGAlertSheet showMessage:(error ?: @"Could not encrypt database.")
										title:TGLocalized(@"Database Encryption")
									   inView:weakSelf.view];
				}
				[weakSelf rebuildSections];
			}];
		} else {
			[[TGSettingsStore shared] decryptDatabaseWithCompletion:^(BOOL ok, NSString *error){
				if (!ok){
					[TGCapabilities setDatabaseEncryptionWanted:YES];
					[TGAlertSheet showMessage:(error ?: @"Could not decrypt database.")
										title:TGLocalized(@"Database Encryption")
									   inView:weakSelf.view];
				}
				[weakSelf rebuildSections];
			}];
		}
	})];

	[tuningRows addObject:TGSwitchRow(TGLocalized(@"Custom Emoji"),
			[TGCapabilities customEmojiWanted], ^(BOOL on){
		[TGCapabilities setCustomEmojiWanted:on];
		[weakSelf rebuildSections];
	})];

	[tuningRows addObject:TGSwitchRow(TGLocalized(@"Chat List Thumbnails"),
			[TGCapabilities chatThumbnailsWanted], ^(BOOL on){
		[TGCapabilities setChatThumbnailsWanted:on];
		[weakSelf rebuildSections];
	})];

	[tuningRows addObject:TGSwitchRow(TGLocalized(@"Group Chat Avatars"),
			[TGCapabilities groupAvatarsWanted], ^(BOOL on){
		[TGCapabilities setGroupAvatarsWanted:on];
		[weakSelf rebuildSections];
	})];

	[tuningRows addObject:TGSwitchRow(TGLocalized(@"Pause Updates on Scroll"),
			[TGCapabilities pauseUpdatesDuringScrollWanted], ^(BOOL on){
		[TGCapabilities setPauseUpdatesDuringScrollWanted:on];
		[weakSelf rebuildSections];
	})];

	[tuningRows addObject:TGSwitchRow(TGLocalized(@"Chat Wallpaper"),
			[TGCapabilities wallpaperWanted], ^(BOOL on){
		[TGCapabilities setWallpaperWanted:on];
		[weakSelf rebuildSections];
	})];

	[tuningRows addObject:TGSwitchRow(TGLocalized(@"GIF Autoplay"),
			[TGCapabilities gifAutoplayWanted], ^(BOOL on){
		[TGCapabilities setGifAutoplayWanted:on];
		[weakSelf rebuildSections];
	})];

	if (NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_6_1) {
		[tuningRows addObject:TGSwitchRow(TGLocalized(@"Skeuomorphic Chrome"),
				[TGCapabilities skeuomorphicChromeWanted], ^(BOOL on){
			[TGCapabilities setSkeuomorphicChromeWanted:on];
			[[NSNotificationCenter defaultCenter] postNotificationName:TGThemeChangedNotification object:nil];
			[weakSelf rebuildSections];
		})];
	}

	[sections addObject:TGSection(TGSettingsHeaderText(@"PERFORMANCE & TUNING"),
			TGLocalized(@"Disable heavy features to reduce memory pressure and eliminate scroll stutter on older hardware."),
			tuningRows)];

	self.capabilities = [TGCapabilities all];
	NSMutableArray *featureRows = [NSMutableArray array];
	for (TGCapability *capability in self.capabilities){
		NSMutableDictionary *row = [TGDeviceCapabilityRowModel(capability.name,
				capability.available, capability.requirement) mutableCopy];
		if (capability.available)
			row[TGRowDetailColour] = [[TGTheme shared] onlineColour];
		[featureRows addObject:row];
	}
	[sections addObject:TGSection(TGSettingsHeaderText(@"FEATURES"), nil,
			featureRows)];

	[sections addObject:TGSection(nil, nil, @[
		TGCentredDestructiveRow(TGLocalized(@"Log out"), ^{
			[TGAlertSheet showConfirm:
					TGLocalized(@"Are you sure you want to log out from this device?")
								title:TGLocalized(@"Log out")
							   action:TGLocalized(@"Log out")
						  destructive:YES
							   inView:weakSelf.view
							onConfirm:^{ [[TGAccountStore shared] logOut]; }];
		}),
	])];

	self.sections = sections;
	[self reloadRows];
}

- (NSDictionary *)rowAtPath:(NSIndexPath *)path {
	if (path.section < 0 || path.section >= (NSInteger)self.sections.count)
		return nil;
	NSArray *rows = self.sections[(NSUInteger)path.section][@"rows"];
	if (path.row < 0 || path.row >= (NSInteger)rows.count)
		return nil;
	return rows[(NSUInteger)path.row];
}

@end
