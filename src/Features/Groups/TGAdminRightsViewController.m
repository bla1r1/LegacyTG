//
// TGAdminRightsViewController.m - the two default administrator-rights
// presets, one for groups and one for channels.
//
// The protocol has no getter for these; Telegram keeps the last set value on
// the bot account. The row therefore remembers the preset this app last had
// accepted, and when the server refuses it says why rather than pretending
// the choice stuck. Both requests are bot-only: a user account is expected to
// see the refusal, which is the server answering the button.
//
#import "TGAdminRightsViewController.h"
#import "TGAlertSheet.h"
#import "TGRows.h"
#import "TGGroupStore.h"

static NSString *const kGroupPresetKey   = @"TGDefaultGroupAdminRights";
static NSString *const kChannelPresetKey = @"TGDefaultChannelAdminRights";

@interface TGAdminRightsViewController ()
@property (nonatomic, assign) BOOL busy;
@end

@implementation TGAdminRightsViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Admin Rights";
	[self rebuildSections];
}

- (NSString *)savedPresetForKey:(NSString *)key {
	NSString *saved = [NSUserDefaults.standardUserDefaults stringForKey:key];
	return saved.length ? saved : nil;
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSArray *details = TGAdminRightsRowDetails(
			[self savedPresetForKey:kGroupPresetKey],
			[self savedPresetForKey:kChannelPresetKey]);

	NSMutableDictionary *groupRow = [TGTapRow(TGAdminRightsRowTitles()[0],
			details[0], nil) mutableCopy];
	NSMutableDictionary *channelRow = [TGTapRow(TGAdminRightsRowTitles()[1],
			details[1], nil) mutableCopy];
	if (!self.busy){
		groupRow[TGRowTap] = ^{ [weakSelf showPresetsForChannel:NO]; };
		channelRow[TGRowTap] = ^{ [weakSelf showPresetsForChannel:YES]; };
	}

	self.sections = @[
		TGSection(@"Group", nil, @[groupRow]),
		TGSection(@"Channel", nil, @[channelRow]),
	];
	[self reloadRows];
}

#pragma mark - actions

- (void)showPresetsForChannel:(BOOL)channel {
	NSArray *presets = @[@"readonly", @"standard", @"posting", @"full"];
	NSArray *titles = @[@"Read-Only Mode", @"Default", @"Posting Members", @"Admin"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles
						title:@"Admin Rights"
						message:nil
			 destructiveIndex:-1
						 inView:self.view
					   onChoice:^(NSInteger index){
		NSString *preset = presets[(NSUInteger)index];
		weakSelf.busy = YES;
		[weakSelf rebuildSections];
		void (^done)(BOOL, NSString *) = ^(BOOL ok, NSString *error){
			TGAdminRightsViewController *me = weakSelf;
			if (!me)
				return;
			me.busy = NO;
			if (!ok){
				[TGAlertSheet showMessage:(error ?: @"An error occurred.")
									title:@"Admin Rights" inView:me.view];
				[me rebuildSections];
				return;
			}
			[NSUserDefaults.standardUserDefaults setObject:preset
					forKey:(channel ? kChannelPresetKey : kGroupPresetKey)];
			[NSUserDefaults.standardUserDefaults synchronize];
			[me rebuildSections];
		};
		if (channel)
			[[TGGroupStore shared] setDefaultChannelAdministratorRightsPreset:preset
																completion:done];
		else
			[[TGGroupStore shared] setDefaultGroupAdministratorRightsPreset:preset
															  completion:done];
	}];
}

@end
