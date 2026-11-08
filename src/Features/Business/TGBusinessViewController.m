#import "TGBusinessViewController.h"
#import "TGBusinessMessagesViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGBusinessViewController.h"
#import "TGBusinessBaseViewController.h"
#import "TGBusinessProfileViewController.h"
#import "TGBusinessChatLinksViewController.h"
#import "TGBusinessGreetingViewController.h"
#import "TGBusinessAwayViewController.h"
#import "TGBusinessHoursViewController.h"
#import "TGBusinessLocationViewController.h"
#import "TGBusinessIntroViewController.h"

@interface TGBusinessViewController ()
@property (nonatomic, strong) NSDictionary *info;
@property (nonatomic, strong) NSArray *features;
@property (nonatomic, copy) NSString *loadError;
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


@implementation TGBusinessViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Telegram Business";
	[self load];
}

- (void)load {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] businessInfoWithCompletion:^(NSDictionary *info, NSString *error){
		TGBusinessViewController *me = weakSelf;
		if (!me)
			return;
		if (error)
			me.loadError = error;
		else
			me.info = info ?: @{};
		[me rebuildSections];
	}];
	[[TGClient shared] businessFeaturesForSource:nil
									  completion:^(NSArray *features, NSString *error){
		TGBusinessViewController *me = weakSelf;
		if (!me)
			return;
		if (error)
			me.loadError = error;
		else
			me.features = features ?: @[];
		[me rebuildSections];
	}];
}

- (NSString *)locationDetail {
	NSString *address = self.info[@"location"][@"address"];
	return address.length ? address : @"Set";
}

- (NSString *)hoursDetail {
	NSArray *intervals = self.info[@"opening_hours"][@"opening_hours"];
	if (![intervals isKindOfClass:NSArray.class] || !intervals.count)
		return @"Off";
	return [NSString stringWithFormat:@"%lu intervals", (unsigned long)intervals.count];
}

- (NSString *)introDetail {
	NSString *title = self.info[@"start_page"][@"title"];
	return title.length ? title : @"Off";
}

- (NSString *)greetingDetail {
	NSDictionary *settings = self.info[@"greeting_message_settings"];
	return [settings isKindOfClass:NSDictionary.class] ? @"On" : @"Off";
}

- (NSString *)awayDetail {
	NSDictionary *settings = self.info[@"away_message_settings"];
	if (![settings isKindOfClass:NSDictionary.class])
		return @"Off";
	NSString *schedule = settings[@"schedule"][@"@type"];
	if ([schedule isEqualToString:@"businessAwayMessageScheduleOutsideOfOpeningHours"])
		return @"Outside hours";
	if ([schedule isEqualToString:@"businessAwayMessageScheduleCustom"])
		return @"Custom schedule";
	return @"Always";
}

- (void)rebuildSections {
	NSDictionary *me = [TGClient shared].me;
	NSString *name = [[NSString stringWithFormat:@"%@ %@",
			me[@"first_name"] ?: @"", me[@"last_name"] ?: @""]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (!name.length)
		name = @"Set up";

	NSMutableArray *sections = [NSMutableArray array];
	[sections addObject:TGBSection(nil,
			@"Business settings apply to this account. Telegram owns the "
			@"feature list; a row Telegram refuses opens with its own sentence "
			@"instead of disappearing.",
			@[
		TGBOpenAction(@"Business Profile", name, @"profile"),
		TGBOpenAction(@"Links to Chat", @"Short links that suggest a first message", @"links"),
	])];

	[sections addObject:TGBSection(@"AUTOMATED MESSAGES", nil, @[
		TGBOpenAction(@"Greeting Messages", [self greetingDetail], @"greeting"),
		TGBOpenAction(@"Away Messages", [self awayDetail], @"away"),
	])];

	[sections addObject:TGBSection(@"BUSINESS INFO", nil, @[
		TGBOpenAction(@"Location", [self locationDetail], @"location"),
		TGBOpenAction(@"Opening Hours", [self hoursDetail], @"hours"),
		TGBOpenAction(@"Intro", [self introDetail], @"intro"),
	])];

	[sections addObject:TGBSection(@"CHATBOTS",
			@"TDLib names business profile and message calls for a business "
			@"bot's connection. A user account has no connection id; these "
			@"pages send the real request and show Telegram's refusal.",
			@[
		TGBOpenAction(@"Business Connection",
				TGBusinessStoredConnectionId().length ? TGBusinessStoredConnectionId() : @"Not set",
				@"connection"),
		TGBOpenAction(@"Business Messages", @"Send, edit, read and pin", @"messages"),
	])];

	NSMutableArray *featureRows = [NSMutableArray array];
	for (NSString *type in self.features)
		[featureRows addObject:TGBInfo(TGBusinessFeatureTitle(type), @"Included")];
	if (!featureRows.count)
		[featureRows addObject:TGBInfo(@"Business features",
				self.loadError.length ? self.loadError : @"Telegram did not list any")];
	[sections addObject:TGBSection(@"BUSINESS FEATURES",
			@"getBusinessFeatures answers what this account may use. A "
			@"subscription adds the rest.", featureRows)];

	self.sections = sections;
	[self rebuild];
}

- (void)didChooseAction:(NSString *)action row:(NSDictionary *)row {
	if ([action isEqualToString:@"profile"]){
		[self push:[[TGBusinessProfileViewController alloc] init]];
	} else if ([action isEqualToString:@"links"]){
		[self push:[[TGBusinessChatLinksViewController alloc] init]];
	} else if ([action isEqualToString:@"greeting"]){
		[self push:[[TGBusinessGreetingViewController alloc] init]];
	} else if ([action isEqualToString:@"away"]){
		[self push:[[TGBusinessAwayViewController alloc] init]];
	} else if ([action isEqualToString:@"location"]){
		[self push:[[TGBusinessLocationViewController alloc] init]];
	} else if ([action isEqualToString:@"hours"]){
		[self push:[[TGBusinessHoursViewController alloc] init]];
	} else if ([action isEqualToString:@"intro"]){
		[self push:[[TGBusinessIntroViewController alloc] init]];
	} else if ([action isEqualToString:@"connection"]){
		[self push:[[TGBusinessConnectionViewController alloc] init]];
	} else if ([action isEqualToString:@"messages"]){
		[self push:[[TGBusinessMessagesViewController alloc] init]];
	}
}

- (void)push:(UIViewController *)page {
	page.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:page animated:YES];
}

@end
