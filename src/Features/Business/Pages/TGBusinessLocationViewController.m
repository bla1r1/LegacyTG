#import "TGBusinessViewController.h"
#import "TGBusinessMessagesViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGBusinessLocationViewController.h"
#import "TGBusinessBaseViewController.h"
#import "TGBusinessViewController.h"
#import "TGBusinessProfileViewController.h"
#import "TGBusinessChatLinksViewController.h"
#import "TGBusinessGreetingViewController.h"
#import "TGBusinessAwayViewController.h"
#import "TGBusinessHoursViewController.h"
#import "TGBusinessIntroViewController.h"

@interface TGBusinessLocationViewController ()
@property (nonatomic, copy) NSString *address;
@property (nonatomic, strong) NSNumber *latitude;
@property (nonatomic, strong) NSNumber *longitude;
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


@implementation TGBusinessLocationViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Location";
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] businessInfoWithCompletion:^(NSDictionary *info, NSString *error){
		TGBusinessLocationViewController *page = weakSelf;
		if (!page)
			return;
		page.address = [info[@"location"][@"address"] isKindOfClass:NSString.class]
				? info[@"location"][@"address"] : @"";
		id latitude = info[@"location"][@"location"][@"latitude"];
		id longitude = info[@"location"][@"location"][@"longitude"];
		page.latitude = [latitude isKindOfClass:NSNumber.class] ? latitude : nil;
		page.longitude = [longitude isKindOfClass:NSNumber.class] ? longitude : nil;
		[page rebuildSections];
	}];
	[self rebuildSections];
}

- (void)rebuildSections {
	NSString *coordinates = self.latitude && self.longitude
			? [NSString stringWithFormat:@"%.4f, %.4f",
					self.latitude.doubleValue, self.longitude.doubleValue]
			: @"Not set";
	self.sections = @[
		TGBSection(@"LOCATION",
				@"Display the location of the business on this account.",
				@[
			TGBAction(@"Address", self.address.length ? self.address : @"Enter Address",
					@"address"),
			TGBAction(@"Coordinates", coordinates, @"coordinates"),
			TGBAction(@"Save Location", nil, @"save"),
		]),
		TGBSection(nil, nil, @[
			TGBDestructive(@"Delete Location", @"delete"),
		]),
	];
	[self rebuild];
}

- (void)didChooseAction:(NSString *)action row:(NSDictionary *)row {
	__weak typeof(self) weakSelf = self;
	if ([action isEqualToString:@"address"]){
		[self askText:@"Address" message:nil placeholder:@"Enter Address"
				 text:self.address action:@"Save" completion:^(NSString *text){
			weakSelf.address = text;
			[weakSelf rebuildSections];
		}];
	} else if ([action isEqualToString:@"coordinates"]){
		[self askText:@"Latitude" message:@"Decimal degrees."
		  placeholder:@"50.4501"
				 text:self.latitude ? [NSString stringWithFormat:@"%.6f",
						 self.latitude.doubleValue] : nil
			   action:@"Next" completion:^(NSString *text){
			NSNumber *latitude = @([text doubleValue]);
			[weakSelf askText:@"Longitude" message:@"Decimal degrees."
				  placeholder:@"30.5234"
						 text:weakSelf.longitude ? [NSString stringWithFormat:@"%.6f",
								 weakSelf.longitude.doubleValue] : nil
					   action:@"Save" completion:^(NSString *lon){
				weakSelf.latitude = latitude;
				weakSelf.longitude = @([lon doubleValue]);
				[weakSelf rebuildSections];
			}];
		}];
	} else if ([action isEqualToString:@"save"]){
		if (!self.latitude || !self.longitude){
			[self showMessage:@"Set the coordinates before saving; Telegram needs a point on the map."
						 title:@"Location"];
			return;
		}
		[[TGClient shared] setBusinessLocationLatitude:self.latitude
											 longitude:self.longitude
											   address:self.address
											completion:^(BOOL ok, NSString *error){
			[weakSelf showResult:ok error:error title:@"Location"];
		}];
	} else if ([action isEqualToString:@"delete"]){
		[[TGClient shared] setBusinessLocationLatitude:nil longitude:nil address:nil
											completion:^(BOOL ok, NSString *error){
			TGBusinessLocationViewController *page = weakSelf;
			if (!ok){
				[page showResult:NO error:error title:@"Location"];
				return;
			}
			page.address = @"";
			page.latitude = nil;
			page.longitude = nil;
			[page rebuildSections];
		}];
	}
}

@end
