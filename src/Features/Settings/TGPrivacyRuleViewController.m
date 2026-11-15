//
// TGPrivacyRuleViewController.m - detail screen for a privacy rule with exception lists.
//
#import "TGPrivacyRuleViewController.h"
#import "TGUserPickerViewController.h"
#import "TGLocalization.h"
#import "TGAlertSheet.h"
#import "TGRows.h"
#import "TGSettingsStore.h"
#import "TGSettingsPageModels.h"
#import "TGProfileStore.h"
#import "TGIcons.h"
#import "TGStyle.h"


@interface TGPrivacyRuleViewController ()
@property (nonatomic, copy) NSString *setting;
@property (nonatomic, copy) NSString *ruleTitle;
@property (nonatomic, copy) NSString *ruleType; // "everybody", "contacts", "nobody"
@property (nonatomic, strong) NSMutableArray *allowUserIds;
@property (nonatomic, strong) NSMutableArray *restrictUserIds;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) int64_t publicPhotoId;
@end

@interface TGPrivacyRuleViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@end

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
	[self loadPublicPhoto];
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

	NSMutableArray *sections = [@[
		TGSection(header, TGPrivacyRuleFooterText(self.setting), choiceRows),
		TGSection(@"ADD EXCEPTIONS", nil, exceptionRows),
	] mutableCopy];
	// The photo page, once someone cannot see the real picture, offers the
	// public one for them (official's Set / Update / Remove Public Photo).
	if (TGPrivacyOffersPublicPhoto(self.setting, self.ruleType, self.restrictUserIds.count)){
		NSMutableArray *photoRows = [NSMutableArray array];
		[photoRows addObject:TGOpenRow(self.publicPhotoId ? TGLocalized(@"Update Public Photo")
				: TGLocalized(@"Set Public Photo"), nil, ^{ [weakSelf pickPublicPhoto]; })];
		if (self.publicPhotoId){
			NSMutableDictionary *remove = [TGOpenRow(TGLocalized(@"Remove Public Photo"), nil,
					^{ [weakSelf removePublicPhoto]; }) mutableCopy];
			remove[TGRowDestructive] = @YES;
			[photoRows addObject:remove];
		}
		[sections addObject:TGSection(nil, TGLocalized(@"You can upload a public photo for those who are restricted from viewing your real profile photo."), photoRows)];
	}
	self.sections = sections;
	[self reloadRows];
}

#pragma mark - actions

- (void)loadPublicPhoto {
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] publicPhotoIdWithCompletion:^(int64_t photoId){
		weakSelf.publicPhotoId = photoId;
		if (weakSelf.loaded)
			[weakSelf rebuildSections];
	}];
}

- (void)pickPublicPhoto {
	if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
		return;
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
		didFinishPickingMediaWithInfo:(NSDictionary *)info {
	[picker dismissViewControllerAnimated:YES completion:nil];
	UIImage *image = info[UIImagePickerControllerOriginalImage];
	if (!image)
		return;
	UIImage *scaled = [TGIcons decodedImage:image
								fittingSize:CGSizeMake(TGMetricUploadPhotoSide, TGMetricUploadPhotoSide)
									   fill:NO scale:TGMetricScaleFull];
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"public-photo.jpg"];
	if (![UIImageJPEGRepresentation(scaled, TGCompressionQualityStandard) writeToFile:path atomically:YES])
		return;
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] setPublicPhotoAtPath:path completion:^(BOOL ok){
		TGPrivacyRuleViewController *me = weakSelf;
		if (!me)
			return;
		[TGAlertSheet showMessage:ok ? TGLocalized(@"This photo will be shown to those who are restricted from viewing your main photo.")
								  : TGLocalized(@"An error occurred.")
							title:nil inView:me.view];
		[me loadPublicPhoto];
	}];
}

- (void)removePublicPhoto {
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] removePublicPhoto:self.publicPhotoId completion:^(BOOL ok){
		if (ok)
			[weakSelf loadPublicPhoto];
	}];
}

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
