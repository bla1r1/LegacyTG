#import "TGEditProfileViewController.h"
#import "TGSheet.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGUsernameSettingsViewController.h"
#import "TGEmojiStatusViewController.h"
#import "TGRows.h"

// Profile editing: avatar photo, names, bio, birthday, phone, username and the
// profile's default tab.
static const CGFloat kBirthdayYearRow = TGMetricRow;

typedef void (^TGEditRequest)(void (^completion)(BOOL ok, NSString *error));

/// The three answers the privacy sheet offers, spelled as the Settings page
/// spells them.
static NSString *TGBirthdayPrivacyLabel(NSString *value) {
	if ([value isEqualToString:@"everybody"]) return @"Everybody";
	if ([value isEqualToString:@"contacts"])  return @"My Contacts";
	if ([value isEqualToString:@"nobody"])    return @"Nobody";
	return @"...";
}

@interface TGEditProfileViewController ()
		<UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) NSString *firstText;
@property (nonatomic, copy) NSString *lastText;
@property (nonatomic, copy) NSString *bioText;
@property (nonatomic, assign) NSInteger bioLengthMax;
@property (nonatomic, assign) BOOL bioEdited;
@property (nonatomic, assign) BOOL firstEdited;
@property (nonatomic, assign) BOOL lastEdited;
@property (nonatomic, assign) BOOL userInfoLoaded;
@property (nonatomic, assign) BOOL waitingForProfile;
@property (nonatomic, copy) NSString *originalFirst;
@property (nonatomic, copy) NSString *originalLast;
@property (nonatomic, copy) NSString *originalBio;
@property (nonatomic, strong) UIImage *photoImage;
@property (nonatomic, assign) NSInteger birthDay;
@property (nonatomic, assign) NSInteger birthMonth;
@property (nonatomic, assign) NSInteger birthYear;
@property (nonatomic, assign) BOOL birthdayChanged;
@property (nonatomic, copy) NSString *birthdayPrivacy;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *phoneNumber;
@property (nonatomic, copy) NSString *mainProfileTab;
@property (nonatomic, strong) TGSheet *birthdaySheet;
@property (nonatomic, strong) UIDatePicker *birthdayPicker;
@property (nonatomic, strong) UISegmentedControl *birthdayYearSwitch;
@property (nonatomic, assign) BOOL saving;
@end

@implementation TGEditProfileViewController

- (instancetype)init {
	return [super init];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"";
	[self applyTheme];

	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain
				   target:self action:@selector(cancel)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:@"Done" style:UIBarButtonItemStyleDone
				   target:self action:@selector(save)];

	NSDictionary *me = [TGClient shared].me;
	self.firstText = me[@"first_name"] ?: @"";
	self.lastText = me[@"last_name"] ?: @"";
	self.firstEdited = NO;
	self.lastEdited = NO;
	self.originalFirst = self.firstText;
	self.originalLast = self.lastText;
	self.originalBio = @"";
	self.bioText = @"";
	self.username = me[@"username"] ?: @"";
	self.phoneNumber = me[@"phone"] ?: @"";
	[self rebuildSections];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] request:@{
		@"@type"   : @"getUserFullInfo",
		@"user_id" : me[@"id"] ?: @0,
	} completion:^(NSDictionary *full){
		id raw = full[@"bio"];
		NSString *bio = [raw isKindOfClass:NSDictionary.class] ? raw[@"text"] : raw;
		if (![bio isKindOfClass:NSString.class])
			bio = @"";
		weakSelf.originalBio = bio;
		if (!weakSelf.bioEdited){
			weakSelf.bioText = bio;
			[weakSelf rebuildSections];
			[weakSelf reloadRows];
		}
	}];

	// `me` is built from getMe and has no last name; the user record does.
	[self loadUserInfo];

	[[TGClient shared] myBirthdayWithCompletion:^(NSInteger day, NSInteger month,
												 NSInteger year){
		weakSelf.birthDay = day;
		weakSelf.birthMonth = month;
		weakSelf.birthYear = year;
		[weakSelf rebuildSections];
		[weakSelf reloadRows];
	}];

	[[TGClient shared] bioLengthMaxWithCompletion:^(NSInteger max){
		weakSelf.bioLengthMax = max;
		[weakSelf rebuildSections];
		[weakSelf reloadRows];
	}];

	[[TGClient shared] privacyRule:@"ShowBirthdate" completion:^(NSString *value){
		weakSelf.birthdayPrivacy = value;
		[weakSelf rebuildSections];
		[weakSelf reloadRows];
	}];

	[[TGClient shared] myMainProfileTabWithCompletion:^(NSString *tab){
		weakSelf.mainProfileTab = tab;
		[weakSelf rebuildSections];
		[weakSelf reloadRows];
	}];
}

#pragma mark - rows

- (void)rebuildSections {
	NSDictionary *me = [TGClient shared].me;
	__weak typeof(self) weakSelf = self;
	NSMutableArray *sections = [NSMutableArray array];

	// The picture: the initials stand in until the photo download answers.
	NSString *name = [me[@"first_name"] length] ? me[@"first_name"] : @"?";
	NSNumber *fileId = [[TGClient shared] photoFileIdForUserId:
			[me[@"id"] longLongValue]];
	NSMutableDictionary *photo = TGRow(TGKindPhoto, @"");
	photo[TGRowImage] = self.photoImage ?: [TGIcons avatarWithInitials:
			[TGIcons initialsForTitle:name]
			size:TGMetricProfileAvatar
			colourId:[me[@"id"] longLongValue]];
	photo[TGRowAccessoryTitle] = fileId ? @"Change Photo" : @"Set Photo";
	photo[TGRowAccessoryTap] = ^{
		[weakSelf changePhoto];
	};
	if (fileId){
		NSInteger value = fileId.integerValue;
		photo[TGRowImageLoader] = ^(UIImageView *view){
			[[TGClient shared] downloadFile:value
								   priority:TGDownloadPriorityAvatar
								 completion:^(NSString *path){
				[TGIcons loadImageAtPath:path into:view];
			}];
		};
	}
	[sections addObject:TGSection(nil, nil, @[photo])];

	NSMutableDictionary *first = TGFieldRow(@"First name", self.firstText,
			^(NSString *text){
		weakSelf.firstText = text;
		weakSelf.firstEdited = YES;
	});
	first[TGRowFieldIdentifier] = @"first";
	first[TGRowFieldReturnKey] = @(UIReturnKeyNext);
	first[TGRowFieldReturn] = ^{
		[weakSelf focusFieldWithIdentifier:@"last"];
	};
	NSMutableDictionary *last = TGFieldRow(@"Last Name", self.lastText,
			^(NSString *text){
		weakSelf.lastText = text;
		weakSelf.lastEdited = YES;
	});
	last[TGRowFieldIdentifier] = @"last";
	last[TGRowFieldReturn] = ^{
		[weakSelf.view endEditing:YES];
	};
	// Official SettingsUI: no header over the names, the hint as a footer.
	[sections addObject:TGSection(nil,
			@"Enter your name and add an optional profile photo.", @[first, last])];

	NSMutableDictionary *bio = TGMultilineFieldRow(@"Bio", self.bioText,
			^(NSString *text){
		weakSelf.bioText = text;
		weakSelf.bioEdited = YES;
	});
	bio[TGRowFieldIdentifier] = @"bio";
	if (self.bioLengthMax > 0)
		bio[TGRowFieldMaxLength] = @(self.bioLengthMax);
	[sections addObject:TGSection(@"Bio", nil, @[bio])];

	NSMutableArray *birthdayRows = [NSMutableArray array];
	[birthdayRows addObject:TGTapRow(@"Birthday", [self birthdayText], ^{
		[weakSelf editBirthday];
	})];
	if (self.birthDay > 0){
		[birthdayRows addObject:TGTapRow(@"Birthday",
				self.birthdayPrivacy.length
						? TGBirthdayPrivacyLabel(self.birthdayPrivacy) : nil,
				^{
			[weakSelf askBirthdayPrivacy];
		})];
	}
	[sections addObject:TGSection(@"Birthday", nil, birthdayRows)];

	NSMutableArray *accountRows = [NSMutableArray array];
	NSString *phoneDetail = self.phoneNumber.length
			? [NSString stringWithFormat:@"+%@", self.phoneNumber] : nil;
	NSMutableDictionary *phoneRow = TGRow(TGKindDisclosure, @"Phone Number");
	if (phoneDetail)
		phoneRow[TGRowDetail] = phoneDetail;
	[accountRows addObject:phoneRow];
	[accountRows addObject:TGOpenRow(@"Username",
			self.username.length ? [NSString stringWithFormat:@"@%@", self.username] : nil,
			^{
		[weakSelf openUsernames];
	})];
	BOOL hasStatus = [[TGClient shared] emojiStatusIdForUser:
			[[TGClient shared].me[@"id"] longLongValue]] != 0;
	[accountRows addObject:TGOpenRow(hasStatus ? @"Change Emoji Status"
			: @"Set Emoji Status", nil, ^{
		[weakSelf openEmojiStatus];
	})];
	[accountRows addObject:TGOpenRow(@"Channel", nil, ^{
		[weakSelf choosePersonalChannel];
	})];
	[sections addObject:TGSection(@"Edit Account", nil, accountRows)];

	static NSArray *names = nil;
	if (!names)
		names = @[@"posts", @"gifts", @"media", @"files",
				  @"links", @"music", @"voice", @"gifs"];
	NSString *tab = self.mainProfileTab.length ? self.mainProfileTab : @"posts";
	NSUInteger index = [names indexOfObject:tab];
	NSString *tabTitle = index == NSNotFound ? tab
			: [tab stringByReplacingCharactersInRange:NSMakeRange(0, 1)
					withString:[[tab substringToIndex:1] uppercaseString]];
	NSDictionary *mainTab = TGTapRow(@"Set as Main Tab", tabTitle, ^{
		[weakSelf chooseMainProfileTab];
	});
	[sections addObject:TGSection(@"Profile", nil, @[mainTab])];

	NSMutableDictionary *logOut = TGRedRow(@"Log out", ^{
		[weakSelf confirmLogOut];
	});
	[sections addObject:TGSection(nil, nil, @[logOut])];

	self.sections = sections;
}

#pragma mark - saving

/// The last name lives on the user record, not in getMe's summary. Read it
/// before comparing fields: otherwise saving a new first name would send an
/// empty last name and erase the real one.
- (void)loadUserInfo {
	NSDictionary *me = [TGClient shared].me;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] userInfo:[me[@"id"] longLongValue]
					 completion:^(NSDictionary *user){
		TGEditProfileViewController *controller = weakSelf;
		if (!controller)
			return;
		BOOL waiting = controller.waitingForProfile;
		controller.waitingForProfile = NO;
		if (!user){
			if (waiting)
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Edit Profile" inView:controller.view];
			return;
		}
		NSString *first = user[@"first_name"] ?: @"";
		NSString *last = user[@"last_name"] ?: @"";
		controller.originalFirst = first;
		controller.originalLast = last;
		if (!controller.firstEdited)
			controller.firstText = first;
		if (!controller.lastEdited)
			controller.lastText = last;
		id usernames = user[@"usernames"];
		id active = [usernames isKindOfClass:NSDictionary.class] ? usernames[@"active_usernames"] : nil;
		controller.username = ([active isKindOfClass:NSArray.class] ? [active firstObject] : nil)
				?: (user[@"username"] ?: @"");
		controller.phoneNumber = user[@"phone_number"] ?: @"";
		controller.userInfoLoaded = YES;
		[controller rebuildSections];
		[controller reloadRows];
		if (waiting)
			[controller save];
	}];
}

- (void)updateSavingState:(BOOL)saving {
	self.saving = saving;
	self.navigationItem.rightBarButtonItem.enabled = !saving;
	self.navigationItem.rightBarButtonItem.title = saving ? @"Saving" : @"Done";
}

- (void)cancel {
	[self.navigationController popViewControllerAnimated:YES];
}

- (void)save {
	if (self.saving || self.waitingForProfile)
		return;
	if (!self.userInfoLoaded){
		self.waitingForProfile = YES;
		[self loadUserInfo];
		return;
	}
	NSString *first = [self.firstText
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *last = [self.lastText
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!first.length){
		[TGAlertSheet showMessage:@"Enter a Name"
							title:@"Edit Profile" inView:self.view];
		return;
	}

	NSString *bio = self.bioText ?: @"";
	NSString *originalFirst = self.originalFirst ?: @"";
	NSString *originalLast = self.originalLast ?: @"";
	NSString *originalBio = self.originalBio ?: @"";

	NSMutableArray *operations = [NSMutableArray array];
	if (![first isEqualToString:originalFirst] || ![last isEqualToString:originalLast]){
		[operations addObject:^(void (^done)(BOOL, NSString *)){
			[[TGClient shared] setName:first last:last completion:done];
		}];
	}
	if (![bio isEqualToString:originalBio]){
		[operations addObject:^(void (^done)(BOOL, NSString *)){
			[[TGClient shared] setBio:bio completion:done];
		}];
	}
	if (self.birthdayChanged){
		[operations addObject:^(void (^done)(BOOL, NSString *)){
			[[TGClient shared] setBirthdayDay:self.birthDay
										month:self.birthMonth
										 year:self.birthYear
								   completion:done];
		}];
	}

	if (!operations.count){
		[self.navigationController popViewControllerAnimated:YES];
		return;
	}

	[self updateSavingState:YES];
	__weak typeof(self) weakSelf = self;
	__block NSUInteger pending = operations.count;
	__block NSString *failure = nil;
	for (TGEditRequest request in operations){
		request(^(BOOL ok, NSString *error){
			if (!ok && !failure)
				failure = error ?: @"An error occurred.";
			if (--pending > 0)
				return;
			[weakSelf updateSavingState:NO];
			if (failure){
				[TGAlertSheet showMessage:failure title:@"Edit Profile"
									inView:weakSelf.view];
				return;
			}
			[weakSelf.navigationController popViewControllerAnimated:YES];
		});
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self rebuildSections];
	[self applyTheme];
}

#pragma mark - birthday

- (NSString *)birthdayText {
	if (self.birthDay <= 0)
		return nil;
	static NSArray *months = nil;
	if (!months) months = @[@"", @"January", @"February", @"March", @"April",
			@"May", @"June", @"July", @"August", @"September", @"October",
			@"November", @"December"];
	NSString *month = (self.birthMonth > 0 && self.birthMonth < 13)
			? months[self.birthMonth] : @"";
	if (self.birthYear > 0){
		NSString *key = [month stringByAppendingString:@" %1$@, %2$@"];
		return TGLocalizedFormat(key,
				[NSString stringWithFormat:@"%ld", (long)self.birthDay],
				[NSString stringWithFormat:@"%ld", (long)self.birthYear]);
	}
	NSString *key = [month stringByAppendingString:@" %@"];
	return TGLocalizedFormat(key,
			[NSString stringWithFormat:@"%ld", (long)self.birthDay]);
}

/// A date picker in a sheet: iOS 7 has no way to put one in a row, and a
/// birthday is picked once. The card is edge to edge, as a modal sheet is,
/// with the picker's own toolbar across the top of it. The year is a switch
/// because Telegram allows a day and month with no year.
- (void)editBirthday {
	static const CGFloat kBar = TGMetricRow, kPicker = TGMetricPickerHeight;

	TGSheet *sheet = [TGSheet sheetForView:self.view.window ?: self.view];
	UIView *card = [sheet addCardOfHeight:kBar + kBirthdayYearRow + kPicker
							 edgeToEdge:YES];

	UISegmentedControl *year = [[UISegmentedControl alloc]
			initWithItems:@[@"Year", @"No"]];
	year.selectedSegmentIndex = (self.birthDay > 0 && self.birthYear <= 0) ? 1 : 0;
	year.frame = CGRectMake(TGMetricGutter, kBar,
			card.bounds.size.width - TGDoubled(TGMetricGutter),
			TGMetricSegmentedHeight);
	year.center = CGPointMake(year.center.x,
			kBar + TGHalf(kBirthdayYearRow));
	[card addSubview:year];

	UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:
			CGRectMake(0, kBar + kBirthdayYearRow, card.bounds.size.width, kPicker)];
	picker.datePickerMode = UIDatePickerModeDate;
	picker.maximumDate = [NSDate date];
	if (self.birthDay > 0){
		NSDateComponents *components = [[NSDateComponents alloc] init];
		components.day = self.birthDay;
		components.month = self.birthMonth;
		components.year = self.birthYear > 0 ? self.birthYear : 1990;
		NSDate *date = [[NSCalendar currentCalendar] dateFromComponents:components];
		if (date) picker.date = date;
	}
	[card addSubview:picker];

	UIToolbar *bar = [[UIToolbar alloc] initWithFrame:
			CGRectMake(0, 0, card.bounds.size.width, kBar)];
	bar.items = @[
		[[UIBarButtonItem alloc] initWithTitle:(self.birthDay > 0 ? @"Remove" : @"Cancel")
				style:UIBarButtonItemStylePlain target:self action:@selector(clearBirthday)],
		[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
				target:nil action:nil],
		[[UIBarButtonItem alloc] initWithTitle:@"Done"
				style:UIBarButtonItemStyleDone target:self action:@selector(commitBirthday)],
	];
	[card addSubview:bar];

	self.birthdayPicker = picker;
	self.birthdayYearSwitch = year;
	self.birthdaySheet = sheet;
	[sheet present];
}

- (void)commitBirthday {
	NSDateComponents *c = [[NSCalendar currentCalendar]
			components:(NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit)
			  fromDate:self.birthdayPicker.date];
	self.birthDay = c.day;
	self.birthMonth = c.month;
	self.birthYear = self.birthdayYearSwitch.selectedSegmentIndex == 0 ? c.year : 0;
	self.birthdayChanged = YES;
	[self closeBirthdaySheet];
}

- (void)clearBirthday {
	self.birthDay = self.birthMonth = self.birthYear = 0;
	self.birthdayChanged = YES;
	[self closeBirthdaySheet];
}

- (void)closeBirthdaySheet {
	[self.birthdaySheet dismiss];
	self.birthdaySheet = nil;
	self.birthdayPicker = nil;
	self.birthdayYearSwitch = nil;
	[self rebuildSections];
	[self reloadRows];
}

- (void)askBirthdayPrivacy {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Everybody", @"My Contacts", @"Nobody"]
						title:@"Birthday"
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		if (index < 0 || index > 2)
			return;
		NSString *value = @[@"everybody", @"contacts", @"nobody"][(NSUInteger)index];
		weakSelf.birthdayPrivacy = value;
		[[TGClient shared] setPrivacyRule:@"ShowBirthdate" to:value];
		[weakSelf rebuildSections];
		[weakSelf reloadRows];
	}];
}

#pragma mark - photo

- (void)changePhoto {
	if (![UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypePhotoLibrary])
		return;
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
		didFinishPickingMediaWithInfo:(NSDictionary *)info {
	[picker dismissViewControllerAnimated:YES completion:nil];
	UIImage *image = info[UIImagePickerControllerOriginalImage];
	if (!image)
		return;

	UIImage *scaled = [TGIcons decodedImage:image
								fittingSize:CGSizeMake(TGMetricUploadPhotoSide, TGMetricUploadPhotoSide) fill:NO scale:TGMetricScaleFull];
	NSString *path = [NSTemporaryDirectory()
			stringByAppendingPathComponent:@"profile-photo.jpg"];
	if (![UIImageJPEGRepresentation(scaled, TGCompressionQualityStandard) writeToFile:path atomically:YES])
		return;

	self.photoImage = scaled;      // show it before the upload finishes
	[self rebuildSections];
	[self reloadRows];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setProfilePhotoAtPath:path completion:^(BOOL ok){
		if (ok)
			return;
		[TGAlertSheet showMessage:@"An error occurred."
							title:@"Set Profile Photo" inView:weakSelf.view];
	}];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - account actions

- (void)openUsernames {
	TGUsernameSettingsViewController *usernames =
			[[TGUsernameSettingsViewController alloc] init];
	usernames.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:usernames animated:YES];
}

- (void)openEmojiStatus {
	TGEmojiStatusViewController *status =
			[[TGEmojiStatusViewController alloc] init];
	status.target = TGEmojiStatusTargetSelf;
	status.userId = [[TGClient shared].me[@"id"] longLongValue];
	status.subjectTitle = @"Emoji Status";
	status.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:status animated:YES];
}

- (void)choosePersonalChannel {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] suitablePersonalChatsWithCompletion:^(NSArray *chats){
		NSMutableArray *titles = [NSMutableArray arrayWithObject:@"None"];
		NSMutableArray *ids = [NSMutableArray arrayWithObject:@0];
		for (NSDictionary *chat in chats){
			NSString *title = chat[@"title"] ?: [[TGClient shared]
					titleForChat:[chat[@"id"] longLongValue]];
			[titles addObject:title.length ? title : @"Channel"];
			[ids addObject:chat[@"id"] ?: @0];
		}
		[TGAlertSheet showChoices:titles title:@"Channel"
				 destructiveIndex:-1 inView:weakSelf.view
						 onChoice:^(NSInteger index){
			[[TGClient shared] setPersonalChat:[ids[(NSUInteger)index] longLongValue]
									completion:^(BOOL ok){
				if (!ok)
					[TGAlertSheet showMessage:@"An error occurred."
										title:@"Channel"
									   inView:weakSelf.view];
			}];
		}];
	}];
}

- (void)confirmLogOut {
	[TGAlertSheet showConfirm:@"Are you sure you want to log out from this device?"
						title:@"Log out" action:@"Log Out"
				  destructive:YES inView:self.view onConfirm:^{
		[[TGClient shared] logOut];
	}];
}

- (void)chooseMainProfileTab {
	NSArray *tabs = @[@"posts", @"gifts", @"media", @"files",
					  @"links", @"music", @"voice", @"gifs"];
	NSArray *titles = @[@"Posts", @"Gifts", @"Media", @"Files",
						@"Links", @"Music", @"Voice", @"GIFs"];
	NSString *current = self.mainProfileTab.length ? self.mainProfileTab : @"posts";
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles
						title:@"Set as Main Tab"
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		if (index < 0 || index >= (NSInteger)tabs.count)
			return;
		NSString *tab = tabs[(NSUInteger)index];
		[[TGClient shared] setMainProfileTab:tab completion:^(BOOL ok, NSString *error){
			if (!ok){
				[TGAlertSheet showMessage:(error ?: @"An error occurred.")
									title:@"Set as Main Tab" inView:weakSelf.view];
				return;
			}
			weakSelf.mainProfileTab = tab;
			[weakSelf rebuildSections];
			[weakSelf reloadRows];
		}];
	}];
}

@end

// vim:ft=objc
