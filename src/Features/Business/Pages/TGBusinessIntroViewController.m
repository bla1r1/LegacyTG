#import "TGBusinessViewController.h"
#import "TGBusinessMessagesViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGBusinessIntroViewController.h"
#import "TGBusinessBaseViewController.h"
#import "TGBusinessViewController.h"
#import "TGBusinessProfileViewController.h"
#import "TGBusinessChatLinksViewController.h"
#import "TGBusinessGreetingViewController.h"
#import "TGBusinessAwayViewController.h"
#import "TGBusinessHoursViewController.h"
#import "TGBusinessLocationViewController.h"

@interface TGBusinessIntroViewController () <UIImagePickerControllerDelegate,
		UINavigationControllerDelegate>
@property (nonatomic, copy) NSString *introTitle;
@property (nonatomic, copy) NSString *introMessage;
@property (nonatomic, copy) NSString *stickerPath;
@property (nonatomic, assign) BOOL pickingSticker;
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


static NSString *const TGBusinessConnectionDefaultsKey = @"TGBusinessConnectionId";



/// The names Telegram's Business page uses for the feature type names the
/// server returns. A feature this wave has no screen for is still listed:
/// saying Telegram included it is more honest than dropping it silently.
static NSString *TGBusinessFeatureTitle(NSString *type) {
	if ([type isEqualToString:@"businessFeatureLocation"]) return @"Location";
	if ([type isEqualToString:@"businessFeatureOpeningHours"]) return @"Opening Hours";
	if ([type isEqualToString:@"businessFeatureQuickReplies"]) return @"Quick Replies";
	if ([type isEqualToString:@"businessFeatureGreetingMessage"]) return @"Greeting Messages";
	if ([type isEqualToString:@"businessFeatureAwayMessage"]) return @"Away Messages";
	if ([type isEqualToString:@"businessFeatureAccountLinks"]) return @"Links to Chat";
	if ([type isEqualToString:@"businessFeatureStartPage"]) return @"Intro";
	if ([type isEqualToString:@"businessFeatureBots"]) return @"Chatbots";
	if ([type isEqualToString:@"businessFeatureEmojiStatus"]) return @"Emoji Status";
	if ([type isEqualToString:@"businessFeatureChatFolderTags"]) return @"Chat Folder Tags";
	if ([type isEqualToString:@"businessFeatureUpgradedStories"]) return @"Upgraded Stories";
	return type ?: @"Feature";
}

/// businessRecipients, as the switches on the greeting and away pages hold
/// it. The defaults are Telegram's "all 1-to-1 chats".
static NSDictionary *TGBusinessRecipients(BOOL existing, BOOL newChats,
										  BOOL contacts, BOOL nonContacts,
										  BOOL excludeSelected) {
	return @{
		@"existing" : @(existing),
		@"new" : @(newChats),
		@"contacts" : @(contacts),
		@"nonContacts" : @(nonContacts),
		@"excludeSelected" : @(excludeSelected),
	};
}

#pragma mark - the shared list screen


@implementation TGBusinessIntroViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Intro";
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] businessInfoWithCompletion:^(NSDictionary *info, NSString *error){
		TGBusinessIntroViewController *page = weakSelf;
		if (!page)
			return;
		page.introTitle = [info[@"start_page"][@"title"] isKindOfClass:NSString.class]
				? info[@"start_page"][@"title"] : @"";
		page.introMessage = [info[@"start_page"][@"message"] isKindOfClass:NSString.class]
				? info[@"start_page"][@"message"] : @"";
		[page rebuildSections];
	}];
	[self rebuildSections];
}

- (void)rebuildSections {
	self.sections = @[
		TGBSection(@"CUSTOMIZE YOUR INTRO",
				@"The message people see before they start a chat with this account.",
				@[
			TGBAction(@"Title", self.introTitle.length ? self.introTitle : @"Set",
					@"title"),
			TGBAction(@"Message", self.introMessage.length ? self.introMessage : @"Enter Message",
					@"message"),
			TGBAction(@"Sticker", self.stickerPath.length ? @"Chosen" : @"Choose Sticker",
					@"sticker"),
			TGBAction(@"Save Intro", nil, @"save"),
		]),
		TGBSection(nil, nil, @[
			TGBDestructive(@"Reset to Default", @"reset"),
		]),
	];
	[self rebuild];
}

- (void)didChooseAction:(NSString *)action row:(NSDictionary *)row {
	__weak typeof(self) weakSelf = self;
	if ([action isEqualToString:@"title"]){
		[self askText:@"Intro Title" message:nil placeholder:@"Title"
				 text:self.introTitle action:@"Save" completion:^(NSString *text){
			weakSelf.introTitle = text;
			[weakSelf rebuildSections];
		}];
	} else if ([action isEqualToString:@"message"]){
		[self askText:@"Intro Message" message:nil placeholder:@"Enter Message"
				 text:self.introMessage action:@"Save" completion:^(NSString *text){
			weakSelf.introMessage = text;
			[weakSelf rebuildSections];
		}];
	} else if ([action isEqualToString:@"sticker"]){
		[self pickSticker];
	} else if ([action isEqualToString:@"save"]){
		if (!self.introTitle.length || !self.introMessage.length){
			[self showMessage:@"An intro needs a title and a message." title:@"Intro"];
			return;
		}
		[[TGClient shared] setBusinessStartPageTitle:self.introTitle
											 message:self.introMessage
										 stickerPath:self.stickerPath
										  completion:^(BOOL ok, NSString *error){
			[weakSelf showResult:ok error:error title:@"Intro"];
		}];
	} else if ([action isEqualToString:@"reset"]){
		[[TGClient shared] setBusinessStartPageTitle:nil message:nil stickerPath:nil
										  completion:^(BOOL ok, NSString *error){
			TGBusinessIntroViewController *page = weakSelf;
			if (!ok){
				[page showResult:NO error:error title:@"Intro"];
				return;
			}
			page.introTitle = @"";
			page.introMessage = @"";
			page.stickerPath = nil;
			[page rebuildSections];
		}];
	}
}

- (void)pickSticker {
	if (![UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypePhotoLibrary]){
		[self showMessage:@"The photo library is not on this device." title:@"Intro"];
		return;
	}
	self.pickingSticker = YES;
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
		didFinishPickingMediaWithInfo:(NSDictionary *)info {
	[picker dismissViewControllerAnimated:YES completion:nil];
	if (!self.pickingSticker)
		return;
	self.pickingSticker = NO;
	UIImage *image = info[UIImagePickerControllerOriginalImage];
	if (!image)
		return;
	NSString *path = [NSTemporaryDirectory()
			stringByAppendingPathComponent:@"business-intro.jpg"];
	if (![UIImageJPEGRepresentation(image, TGCompressionQualityStandard)
			writeToFile:path atomically:YES]){
		[self showMessage:@"Could not prepare the picture." title:@"Intro"];
		return;
	}
	self.stickerPath = path;
	[self rebuildSections];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	self.pickingSticker = NO;
	[picker dismissViewControllerAnimated:YES completion:nil];
}

@end
