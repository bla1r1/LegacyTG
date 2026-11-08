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
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"

static NSString *const kGroupPresetKey   = @"TGDefaultGroupAdminRights";
static NSString *const kChannelPresetKey = @"TGDefaultChannelAdminRights";

@interface TGAdminRightsViewController ()
@property (nonatomic, assign) BOOL busy;
@end

@implementation TGAdminRightsViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Admin Rights";
	[self applyTheme];

}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)applyTheme {
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (NSString *)savedPresetForKey:(NSString *)key {
	NSString *saved = [NSUserDefaults.standardUserDefaults stringForKey:key];
	return saved.length ? saved : nil;
}

- (NSString *)labelForPreset:(NSString *)preset {
	if ([preset isEqualToString:@"readonly"]) return @"Read-Only Mode";
	if ([preset isEqualToString:@"posting"])  return @"Posting Members";
	if ([preset isEqualToString:@"full"])     return @"Admin";
	if ([preset isEqualToString:@"standard"]) return @"Default";
	return @"Default";
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return section == 0 ? @"Group"
						: @"Channel";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)path
{
	UITableViewCell *cell = [[UITableViewCell alloc]
			initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.font = TGFontRow();
	cell.detailTextLabel.font = TGFontBody();
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.textLabel.text = @"Admin Rights";
	NSString *key = path.section == 0 ? kGroupPresetKey : kChannelPresetKey;
	cell.detailTextLabel.text = [self labelForPreset:[self savedPresetForKey:key]];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = self.busy ? UITableViewCellSelectionStyleNone
									: UITableViewCellSelectionStyleBlue;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
	if (self.busy)
		return;
	[tableView deselectRowAtIndexPath:path animated:YES];
	BOOL channel = path.section == 1;
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
		[weakSelf.tableView reloadData];
		void (^done)(BOOL, NSString *) = ^(BOOL ok, NSString *error){
			TGAdminRightsViewController *me = weakSelf;
			if (!me)
				return;
			me.busy = NO;
			if (!ok){
				[TGAlertSheet showMessage:(error ?: @"An error occurred.")
									title:@"Admin Rights" inView:me.view];
				[me.tableView reloadData];
				return;
			}
			[NSUserDefaults.standardUserDefaults setObject:preset
					forKey:(channel ? kChannelPresetKey : kGroupPresetKey)];
			[NSUserDefaults.standardUserDefaults synchronize];
			[me.tableView reloadData];
		};
		if (channel)
			[[TGClient shared] setDefaultChannelAdministratorRightsPreset:preset
																completion:done];
		else
			[[TGClient shared] setDefaultGroupAdministratorRightsPreset:preset
															  completion:done];
	}];
}

@end
