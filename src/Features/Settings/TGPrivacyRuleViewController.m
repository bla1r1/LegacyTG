//
// TGPrivacyRuleViewController.m - detail screen for a privacy rule with exception lists.
//
#import "TGPrivacyRuleViewController.h"
#import "TGUserPickerViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"

@interface TGPrivacyRuleViewController ()
@property (nonatomic, copy) NSString *setting;
@property (nonatomic, copy) NSString *ruleTitle;
@property (nonatomic, copy) NSString *ruleType; // "everybody", "contacts", "nobody"
@property (nonatomic, strong) NSMutableArray *allowUserIds;
@property (nonatomic, strong) NSMutableArray *restrictUserIds;
@property (nonatomic, assign) BOOL loaded;
@end

@implementation TGPrivacyRuleViewController

- (instancetype)initWithSetting:(NSString *)setting title:(NSString *)title {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_setting = [setting copy];
		_ruleTitle = [title copy] ?: TGLocalized(@"Privacy");
		_ruleType = @"everybody";
		_allowUserIds = [NSMutableArray array];
		_restrictUserIds = [NSMutableArray array];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.ruleTitle;
	self.tableView.rowHeight = TGMetricRow;
	[self loadDetails];
}

- (void)loadDetails {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] privacyRuleDetails:self.setting
							   completion:^(NSString *ruleType, NSArray *allowUserIds, NSArray *restrictUserIds){
		dispatch_async(dispatch_get_main_queue(), ^{
			weakSelf.ruleType = ruleType.length ? ruleType : @"everybody";
			weakSelf.allowUserIds = [NSMutableArray arrayWithArray:allowUserIds ?: @[]];
			weakSelf.restrictUserIds = [NSMutableArray arrayWithArray:restrictUserIds ?: @[]];
			weakSelf.loaded = YES;
			[weakSelf.tableView reloadData];
		});
	}];
}

- (void)saveRule {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setPrivacyRule:self.setting
								 type:self.ruleType
						 allowUserIds:self.allowUserIds
					  restrictUserIds:self.restrictUserIds
						   completion:^(BOOL ok, NSString *error){
		dispatch_async(dispatch_get_main_queue(), ^{
			if (!ok) {
				[TGAlertSheet showMessage:(error ?: @"Failed to save privacy rule")
									title:weakSelf.ruleTitle inView:weakSelf.view];
			} else {
				if (weakSelf.onChanged) {
					weakSelf.onChanged(weakSelf.setting, weakSelf.ruleType);
				}
				[[NSNotificationCenter defaultCenter]
						postNotificationName:TGPrivacyRulesChangedNotification object:nil];
			}
		});
	}];
}

#pragma mark - Table View Data Source & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0) {
		return 3; // Everybody, My Contacts, Nobody
	}
	return 2; // Always Allow, Never Allow
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0) {
		return [NSString stringWithFormat:@"WHO CAN SEE MY %@", [self.ruleTitle uppercaseString]];
	}
	return @"ADD EXCEPTIONS";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 0) {
		if ([self.setting isEqualToString:@"ShowStatus"]) {
			return @"You won't see Last Seen or Online times for people with whom you don't share yours. Approximate times will be shown instead.";
		} else if ([self.setting isEqualToString:@"ShowProfilePhoto"]) {
			return @"You can restrict who can see your profile photo and choose exceptions.";
		} else if ([self.setting isEqualToString:@"ShowPhoneNumber"]) {
			return @"Users who have your number saved in their contacts will also see it on Telegram.";
		} else if ([self.setting isEqualToString:@"AllowCalls"] || [self.setting isEqualToString:@"ShowPeerToPeerCall"]) {
			return @"Choose who can call you.";
		} else if ([self.setting isEqualToString:@"ShowLinkInForwardedMessages"]) {
			return @"Messages you send will link to your account when forwarded by others.";
		} else if ([self.setting isEqualToString:@"AllowChatInvites"]) {
			return @"You can restrict who can add you to groups and channels.";
		}
	}
	return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	TGTheme *theme = [TGTheme shared];
	if (indexPath.section == 0) {
		static NSString *ident = @"TGPrivacyChoiceCell";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ident];
		}
		[theme styleCell:cell];
		cell.textLabel.font = TGFontRow();
		cell.textLabel.textColor = [theme primaryTextColour];

		NSArray *options = @[TGLocalized(@"Everybody"), TGLocalized(@"My Contacts"), TGLocalized(@"Nobody")];
		NSArray *keys = @[@"everybody", @"contacts", @"nobody"];
		cell.textLabel.text = options[indexPath.row];

		BOOL selected = [self.ruleType isEqualToString:keys[indexPath.row]];
		cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
		return cell;
	}

	static NSString *identEx = @"TGPrivacyExceptionCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identEx];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identEx];
	}
	[theme styleCell:cell];
	cell.textLabel.font = TGFontRow();
	cell.textLabel.textColor = [theme primaryTextColour];
	cell.detailTextLabel.font = TGFontBody();
	cell.detailTextLabel.textColor = [theme cellDetailColour];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	if (indexPath.row == 0) {
		cell.textLabel.text = TGLocalized(@"Always Allow");
		cell.detailTextLabel.text = self.allowUserIds.count > 0
				? [NSString stringWithFormat:@"%lu %@", (unsigned long)self.allowUserIds.count,
						self.allowUserIds.count == 1 ? @"user" : @"users"]
				: TGLocalized(@"Never");
	} else {
		cell.textLabel.text = TGLocalized(@"Never Allow");
		cell.detailTextLabel.text = self.restrictUserIds.count > 0
				? [NSString stringWithFormat:@"%lu %@", (unsigned long)self.restrictUserIds.count,
						self.restrictUserIds.count == 1 ? @"user" : @"users"]
				: TGLocalized(@"Never");
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.section == 0) {
		NSArray *keys = @[@"everybody", @"contacts", @"nobody"];
		self.ruleType = keys[indexPath.row];
		[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
					  withRowAnimation:UITableViewRowAnimationNone];
		[self saveRule];
		return;
	}

	__weak typeof(self) weakSelf = self;
	if (indexPath.row == 0) {
		NSSet *currentSet = [NSSet setWithArray:self.allowUserIds];
		TGUserPickerViewController *picker =
				[[TGUserPickerViewController alloc] initWithSelectedUserIds:currentSet
																	  title:TGLocalized(@"Always Allow")];
		picker.onDone = ^(NSSet *chosenIds){
			weakSelf.allowUserIds = [NSMutableArray arrayWithArray:chosenIds.allObjects];
			[weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
							  withRowAnimation:UITableViewRowAnimationNone];
			[weakSelf saveRule];
		};
		picker.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:picker animated:YES];
	} else {
		NSSet *currentSet = [NSSet setWithArray:self.restrictUserIds];
		TGUserPickerViewController *picker =
				[[TGUserPickerViewController alloc] initWithSelectedUserIds:currentSet
																	  title:TGLocalized(@"Never Allow")];
		picker.onDone = ^(NSSet *chosenIds){
			weakSelf.restrictUserIds = [NSMutableArray arrayWithArray:chosenIds.allObjects];
			[weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
							  withRowAnimation:UITableViewRowAnimationNone];
			[weakSelf saveRule];
		};
		picker.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:picker animated:YES];
	}
}

@end
