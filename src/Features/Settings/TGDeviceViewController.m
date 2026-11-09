#import "TGDeviceViewController.h"
#import "TGDevice.h"
#import "TGCapabilities.h"
#import "TGClient.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGSettingsFormatting.h"
#import "TGTheme.h"
#import "TGRows.h"
#import "TGRowCell.h"

@interface TGDeviceViewController ()
@property (nonatomic, strong) NSArray *capabilities;
@end

@implementation TGDeviceViewController

- (void)viewDidLoad {
	[super viewDidLoad];
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

	__weak typeof(self) weakSelf = self;
	[sections addObject:TGSection(nil, nil, @[
		TGCentredDestructiveRow(TGLocalized(@"Log out"), ^{
			[TGAlertSheet showConfirm:
					TGLocalized(@"Are you sure you want to log out from this device?")
								title:TGLocalized(@"Log out")
							   action:TGLocalized(@"Log out")
						  destructive:YES
							   inView:weakSelf.view
							onConfirm:^{ [[TGClient shared] logOut]; }];
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
