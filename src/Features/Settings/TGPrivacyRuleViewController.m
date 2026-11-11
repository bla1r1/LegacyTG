//
// TGPrivacyRuleViewController.m - detail screen for a privacy rule with exception lists.
//
#import "TGPrivacyRuleViewController.h"
#import "TGUserPickerViewController.h"
#import "TGLocalization.h"
#import "TGAlertSheet.h"
#import "TGRows.h"
#import "TGSettingsStore.h"


@interface TGPrivacyRuleViewController ()
@property (nonatomic, copy) NSString *setting;
@property (nonatomic, copy) NSString *ruleTitle;
@property (nonatomic, copy) NSString *ruleType; // "everybody", "contacts", "nobody"
@property (nonatomic, strong) NSMutableArray *allowUserIds;
@property (nonatomic, strong) NSMutableArray *restrictUserIds;
@property (nonatomic, assign) BOOL loaded;
@end

static NSString *TGPrivacyRuleFooterText(NSString *setting) {
	if ([setting isEqualToString:@"ShowStatus"])
		return TGLocalized(@"You won't see Last Seen or Online times for people with whom you don't share yours. Approximate times will be shown instead.");
	if ([setting isEqualToString:@"ShowProfilePhoto"])
		return TGLocalized(@"You can restrict who can see your profile photo and choose exceptions.");
	if ([setting isEqualToString:@"ShowPhoneNumber"])
		return TGLocalized(@"Users who have your number saved in their contacts will also see it on Telegram.");
	if ([setting isEqualToString:@"AllowCalls"] ||
		[setting isEqualToString:@"ShowPeerToPeerCall"])
		return TGLocalized(@"Choose who can call you.");
	if ([setting isEqualToString:@"ShowLinkInForwardedMessages"])
		return TGLocalized(@"Messages you send will link to your account when forwarded by others.");
	if ([setting isEqualToString:@"AllowChatInvites"])
		return TGLocalized(@"You can restrict who can add you to groups and channels.");
	return nil;
}

@implementation TGPrivacyRuleViewController

- (instancetype)initWithSetting:(NSString *)setting title:(NSString *)title {
	self = [super init];
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
	[self loadDetails];
}

- (void)loadDetails {
	__weak typeof(self) weakSelf = self;
	[[TGSettingsStore shared] privacyRuleDetails:self.setting
							   completion:^(NSString *ruleType, NSArray *allowUserIds, NSArray *restrictUserIds){
		dispatch_async(dispatch_get_main_queue(), ^{
			weakSelf.ruleType = ruleType.length ? ruleType : @"everybody";
			weakSelf.allowUserIds = [NSMutableArray arrayWithArray:allowUserIds ?: @[]];
			weakSelf.restrictUserIds = [NSMutableArray arrayWithArray:restrictUserIds ?: @[]];
			weakSelf.loaded = YES;
			[weakSelf rebuildSections];
		});
	}];
}

- (void)saveRule {
	__weak typeof(self) weakSelf = self;
	[[TGSettingsStore shared] setPrivacyRule:self.setting
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

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSArray *keys = TGPrivacyRuleOptionKeys();
	NSArray *titles = TGPrivacyRuleOptionTitles();
	NSMutableArray *choiceRows = [NSMutableArray array];
	for (NSUInteger i = 0; i < keys.count; i++){
		NSString *key = keys[i];
		BOOL selected = [self.ruleType isEqualToString:key];
		[choiceRows addObject:TGCheckRow(titles[i], nil, selected, ^{
			[weakSelf chooseRuleType:key];
		})];
	}

	NSString *header = [NSString stringWithFormat:@"WHO CAN SEE MY %@",
			[self.ruleTitle uppercaseString]];
	NSMutableArray *exceptionRows = [NSMutableArray array];
	[exceptionRows addObject:TGOpenRow(TGLocalized(@"Always Allow"),
			TGPrivacyExceptionDetail(self.allowUserIds.count),
			^{ [weakSelf openExceptionsAllowing:YES]; })];
	[exceptionRows addObject:TGOpenRow(TGLocalized(@"Never Allow"),
			TGPrivacyExceptionDetail(self.restrictUserIds.count),
			^{ [weakSelf openExceptionsAllowing:NO]; })];

	self.sections = @[
		TGSection(header, TGPrivacyRuleFooterText(self.setting), choiceRows),
		TGSection(@"ADD EXCEPTIONS", nil, exceptionRows),
	];
	[self reloadRows];
}

#pragma mark - actions

- (void)chooseRuleType:(NSString *)key {
	self.ruleType = key;
	[self rebuildSections];
	[self saveRule];
}

- (void)openExceptionsAllowing:(BOOL)allowing {
	NSArray *current = allowing ? self.allowUserIds : self.restrictUserIds;
	NSSet *currentSet = [NSSet setWithArray:current];
	TGUserPickerViewController *picker =
			[[TGUserPickerViewController alloc] initWithSelectedUserIds:currentSet
																  title:allowing
																		  ? TGLocalized(@"Always Allow")
																		  : TGLocalized(@"Never Allow")];
	__weak typeof(self) weakSelf = self;
	picker.onDone = ^(NSSet *chosenIds){
		NSMutableArray *ids = [NSMutableArray arrayWithArray:chosenIds.allObjects];
		if (allowing)
			weakSelf.allowUserIds = ids;
		else
			weakSelf.restrictUserIds = ids;
		[weakSelf rebuildSections];
		[weakSelf saveRule];
	};
	picker.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:picker animated:YES];
}

@end
