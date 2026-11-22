#import "TGBusinessViewController.h"
#import "TGBusinessMessagesViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGBusinessProfileViewController.h"
#import "TGBusinessBaseViewController.h"
#import "TGBusinessViewController.h"
#import "TGBusinessChatLinksViewController.h"
#import "TGBusinessGreetingViewController.h"
#import "TGBusinessAwayViewController.h"
#import "TGBusinessHoursViewController.h"
#import "TGBusinessLocationViewController.h"
#import "TGBusinessIntroViewController.h"
#import "TGBusinessStore.h"
#import "TGProfileStore.h"
#import "TGPresent.h"

@interface TGBusinessProfileViewController ()
@property (nonatomic, copy) NSString *firstName;
@property (nonatomic, copy) NSString *lastName;
@property (nonatomic, copy) NSString *bio;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, assign) BOOL isPublic;
@property (nonatomic, assign) BOOL pickingPhoto;
@end

//
// TGBusinessViewController.m - Telegram Business settings, the profile
// fields, the automated messages, the location/hours/intro and links to
// chat.
//
// The account-level settings are real subscriber features. The profile
// checksum through setBusinessAccount* carries a business connection id and
// is declared bot-only; when a user account tries it, Telegram answers with
// its refusal and the alert shows that sentence. The row stays visible
// because hiding it would leave a Business subscriber with a page that
// silently does less than the official client.
//




#pragma mark - the shared list screen


@implementation TGBusinessProfileViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.pageKind = TGPageKindForm;
	self.title = @"Business";
	NSDictionary *me = [TGProfileStore shared].me;
	self.firstName = me[@"first_name"] ?: @"";
	self.lastName = me[@"last_name"] ?: @"";
	self.username = me[@"username"] ?: @"";
	__weak typeof(self) weakSelf = self;
	[[TGBusinessStore shared] businessProfileForUser:[me[@"id"] longLongValue]
										 completion:^(NSDictionary *full){
		TGBusinessProfileViewController *page = weakSelf;
		if (!page)
			return;
		NSString *bio = full[@"bio"][@"text"];
		if ([bio isKindOfClass:NSString.class])
			page.bio = bio;
		[page rebuildSections];
	}];
	[self rebuildSections];
}

- (void)rebuildSections {
	NSString *name = [[NSString stringWithFormat:@"%@ %@",
			self.firstName ?: @"", self.lastName ?: @""]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	self.sections = @[
		TGBSection(@"PROFILE", nil,
				@[
			TGBAction(@"Name", name.length ? name : @"Set", @"firstName"),
			TGBAction(@"Last Name", self.lastName.length ? self.lastName : @"Set", @"lastName"),
			TGBAction(@"Bio", self.bio.length ? self.bio : @"Add Bio", @"bio"),
			TGBAction(@"Username", self.username.length
					? [@"@" stringByAppendingString:self.username] : @"Set", @"username"),
			TGBAction(@"Edit Profile Photo", nil, @"photo"),
			TGBSwitch(@"Public Photo", nil, @"public", self.isPublic, YES),
		]),
		TGBSection(nil, nil, @[
			TGBDestructive(@"Remove Photo", @"removePhoto"),
		]),
	];
	[self rebuild];
}

- (void)didChooseAction:(NSString *)action row:(NSDictionary *)row {
	__weak typeof(self) weakSelf = self;
	if ([action isEqualToString:@"firstName"]){
		[self askText:@"First Name" message:nil placeholder:@"First name"
				 text:self.firstName action:@"Save"
		   completion:^(NSString *text){
			weakSelf.firstName = text;
			[weakSelf saveName];
		}];
	} else if ([action isEqualToString:@"lastName"]){
		[self askText:@"Last Name" message:nil placeholder:@"Last name"
				 text:self.lastName action:@"Save"
		   completion:^(NSString *text){
			weakSelf.lastName = text;
			[weakSelf saveName];
		}];
	} else if ([action isEqualToString:@"bio"]){
		[self askText:@"Bio" message:nil placeholder:@"Add Bio"
				 text:self.bio action:@"Save"
		   completion:^(NSString *text){
			[[TGBusinessStore shared] setBusinessAccountBio:text
										connectionId:TGBusinessStoredConnectionId()
										  completion:^(BOOL ok, NSString *error){
				[weakSelf finishProfileChange:ok error:error title:@"Bio"];
			}];
		}];
	} else if ([action isEqualToString:@"username"]){
		NSString *current = self.username.length
				? [@"@" stringByAppendingString:self.username] : @"";
		[self askText:@"Username" message:nil
			placeholder:@"username" text:current action:@"Save"
		   completion:^(NSString *text){
			NSString *username = [text stringByReplacingOccurrencesOfString:@"@" withString:@""];
			[[TGBusinessStore shared] setBusinessAccountUsername:username
											 connectionId:TGBusinessStoredConnectionId()
											   completion:^(BOOL ok, NSString *error){
				if (ok)
					weakSelf.username = username;
				[weakSelf finishProfileChange:ok error:error title:@"Username"];
			}];
		}];
	} else if ([action isEqualToString:@"photo"]){
		[self pickPhoto];
	} else if ([action isEqualToString:@"removePhoto"]){
		[[TGBusinessStore shared] setBusinessAccountProfilePhotoAtPath:nil
													   public:self.isPublic
												   connectionId:TGBusinessStoredConnectionId()
													 completion:^(BOOL ok, NSString *error){
			[weakSelf finishProfileChange:ok error:error title:@"Edit Profile Photo"];
		}];
	}
}

- (void)saveName {
	__weak typeof(self) weakSelf = self;
	[[TGBusinessStore shared] setBusinessAccountName:self.firstName
										 last:self.lastName
								 connectionId:TGBusinessStoredConnectionId()
								   completion:^(BOOL ok, NSString *error){
		[weakSelf finishProfileChange:ok error:error title:@"Save"];
	}];
}

- (void)finishProfileChange:(BOOL)ok error:(NSString *)error title:(NSString *)title {
	[self rebuildSections];
	if (!ok)
		[self showResult:NO error:error title:title];
}

- (void)toggleKey:(NSString *)key on:(BOOL)on sender:(UISwitch *)sender {
	if ([key isEqualToString:@"public"]){
		self.isPublic = on;
		[self rebuildSections];
	}
}

- (void)pickPhoto {
	if (![UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypePhotoLibrary]){
		[self showMessage:@"An error occurred."
					 title:@"Edit Profile Photo"];
		return;
	}
	self.pickingPhoto = YES;
	__weak typeof(self) weakSelf = self;
	[TGPresent pickMediaFrom:self source:TGMediaSourceLibrary videos:NO sourceView:nil
					  onPick:^(NSDictionary *info){ [weakSelf didPickMedia:info]; }];
}

/// What the library handed back, once the picker has gone.
- (void)didPickMedia:(NSDictionary *)info {
	if (!self.pickingPhoto)
		return;
	self.pickingPhoto = NO;
	UIImage *image = info[UIImagePickerControllerOriginalImage];
	if (!image)
		return;
	UIImage *scaled = [TGIcons decodedImage:image
								fittingSize:CGSizeMake(TGMetricUploadPhotoSide,
													   TGMetricUploadPhotoSide)
									   fill:NO scale:TGMetricScaleFull];
	NSString *path = [NSTemporaryDirectory()
			stringByAppendingPathComponent:@"business-photo.jpg"];
	if (![UIImageJPEGRepresentation(scaled, TGCompressionQualityStandard)
			writeToFile:path atomically:YES]){
		[self showMessage:@"An error occurred." title:@"Edit Profile Photo"];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGBusinessStore shared] setBusinessAccountProfilePhotoAtPath:path
													 public:self.isPublic
												 connectionId:TGBusinessStoredConnectionId()
												   completion:^(BOOL ok, NSString *error){
		[weakSelf finishProfileChange:ok error:error title:@"Edit Profile Photo"];
	}];
}

@end
