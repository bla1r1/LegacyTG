#import "TGBusinessViewController.h"
#import "TGBusinessMessagesViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGBusinessAwayViewController.h"
#import "TGBusinessBaseViewController.h"
#import "TGBusinessViewController.h"
#import "TGBusinessProfileViewController.h"
#import "TGBusinessChatLinksViewController.h"
#import "TGBusinessGreetingViewController.h"
#import "TGBusinessHoursViewController.h"
#import "TGBusinessLocationViewController.h"
#import "TGBusinessIntroViewController.h"

@interface TGBusinessAwayViewController ()
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSInteger shortcutId;
@property (nonatomic, copy) NSString *schedule;
@property (nonatomic, assign) int32_t startDate;
@property (nonatomic, assign) int32_t endDate;
@property (nonatomic, assign) BOOL offlineOnly;
@property (nonatomic, assign) BOOL existing;
@property (nonatomic, assign) BOOL newChats;
@property (nonatomic, assign) BOOL contacts;
@property (nonatomic, assign) BOOL nonContacts;
@property (nonatomic, assign) BOOL excludeSelected;
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


@implementation TGBusinessAwayViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Away Messages";
	self.schedule = @"always";
	self.existing = YES;
	self.newChats = YES;
	self.contacts = YES;
	self.nonContacts = YES;
	self.startDate = (int32_t)[NSDate date].timeIntervalSince1970;
	self.endDate = self.startDate + 86400;
	[self load];
}

- (void)load {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] businessInfoWithCompletion:^(NSDictionary *info, NSString *error){
		TGBusinessAwayViewController *page = weakSelf;
		if (!page)
			return;
		NSDictionary *settings = info[@"away_message_settings"];
		if ([settings isKindOfClass:NSDictionary.class]){
			page.enabled = YES;
			page.shortcutId = [settings[@"shortcut_id"] integerValue];
			page.offlineOnly = [settings[@"offline_only"] boolValue];
			NSString *type = settings[@"schedule"][@"@type"];
			if ([type isEqualToString:@"businessAwayMessageScheduleOutsideOfOpeningHours"])
				page.schedule = @"outside";
			else if ([type isEqualToString:@"businessAwayMessageScheduleCustom"]){
				page.schedule = @"custom";
				page.startDate = [settings[@"schedule"][@"start_date"] intValue];
				page.endDate = [settings[@"schedule"][@"end_date"] intValue];
			} else
				page.schedule = @"always";
			page.existing = [settings[@"recipients"][@"select_existing_chats"] boolValue];
			page.newChats = [settings[@"recipients"][@"select_new_chats"] boolValue];
			page.contacts = [settings[@"recipients"][@"select_contacts"] boolValue];
			page.nonContacts = [settings[@"recipients"][@"select_non_contacts"] boolValue];
			page.excludeSelected = [settings[@"recipients"][@"exclude_selected"] boolValue];
		}
		[page rebuildSections];
	}];
	[self rebuildSections];
}

- (NSString *)scheduleDetail {
	if ([self.schedule isEqualToString:@"outside"]) return @"Outside of Business Hours";
	if ([self.schedule isEqualToString:@"custom"]) return @"Custom Schedule";
	return @"Always Send";
}

- (void)rebuildSections {
	NSMutableArray *rows = [NSMutableArray array];
	[rows addObject:TGBSwitch(@"Send Away Message", nil, @"enabled", self.enabled, YES)];
	[rows addObject:TGBAction(@"Shortcut ID",
			[NSString stringWithFormat:@"%ld", (long)self.shortcutId], @"shortcut")];
	[rows addObject:TGBAction(@"Schedule", [self scheduleDetail], @"schedule")];
	if ([self.schedule isEqualToString:@"custom"]){
		[rows addObject:TGBAction(@"Start Time",
				[NSString stringWithFormat:@"%d", self.startDate], @"start")];
		[rows addObject:TGBAction(@"End Time",
				[NSString stringWithFormat:@"%d", self.endDate], @"end")];
	}
	self.sections = @[
		TGBSection(@"AWAY MESSAGE",
				@"Automatically reply with a message when this account is away.",
				rows),
		TGBSection(@"SCHEDULE",
				@"Custom times are unix seconds, which is what TDLib carries.",
				@[
			TGBSwitch(@"Only if Offline",
					@"Do not send the away message if you were recently online.",
					@"offline", self.offlineOnly, self.enabled),
		]),
		TGBSection(@"RECIPIENTS", nil, @[
			TGBSwitch(@"Existing Chats", nil, @"existing", self.existing, self.enabled),
			TGBSwitch(@"New Chats", nil, @"new", self.newChats, self.enabled),
			TGBSwitch(@"Contacts", nil, @"contacts", self.contacts, self.enabled),
			TGBSwitch(@"Non-Contacts", nil, @"nonContacts", self.nonContacts, self.enabled),
			TGBSwitch(@"Exclude Selected", nil, @"exclude", self.excludeSelected, self.enabled),
		]),
	];
	[self rebuild];
}

- (NSDictionary *)recipients {
	return TGBusinessRecipients(self.existing, self.newChats, self.contacts,
								self.nonContacts, self.excludeSelected);
}

- (void)save {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setBusinessAwayMessageEnabled:self.enabled
										 shortcutId:self.shortcutId
										   schedule:self.schedule
										  startDate:self.startDate
											endDate:self.endDate
										offlineOnly:self.offlineOnly
										 recipients:[self recipients]
										 completion:^(BOOL ok, NSString *error){
		TGBusinessAwayViewController *page = weakSelf;
		if (!page)
			return;
		if (!ok){
			[page showResult:NO error:error title:@"Away Messages"];
			[page load];
			return;
		}
		[page rebuildSections];
	}];
}

- (void)didChooseAction:(NSString *)action row:(NSDictionary *)row {
	__weak typeof(self) weakSelf = self;
	if ([action isEqualToString:@"shortcut"]){
		[self askText:@"Shortcut ID"
			  message:@"The quick reply shortcut that holds the away text."
		  placeholder:@"1" text:[NSString stringWithFormat:@"%ld", (long)self.shortcutId]
			   action:@"Save" completion:^(NSString *text){
			weakSelf.shortcutId = [text integerValue];
			[weakSelf save];
		}];
	} else if ([action isEqualToString:@"schedule"]){
		[TGAlertSheet showChoices:@[@"Always Send", @"Outside of Business Hours",
									@"Custom Schedule"]
							title:@"Away Schedule"
				 destructiveIndex:-1 inView:self.view
						 onChoice:^(NSInteger index){
			weakSelf.schedule = index == 1 ? @"outside"
					: (index == 2 ? @"custom" : @"always");
			[weakSelf save];
		}];
	} else if ([action isEqualToString:@"start"] || [action isEqualToString:@"end"]){
		BOOL start = [action isEqualToString:@"start"];
		[self askText:start ? @"Start Time" : @"End Time"
			  message:@"Unix seconds."
		  placeholder:@"1700000000"
				 text:[NSString stringWithFormat:@"%d", start ? self.startDate : self.endDate]
			   action:@"Save" completion:^(NSString *text){
			if (start) weakSelf.startDate = (int32_t)[text longLongValue];
			else       weakSelf.endDate = (int32_t)[text longLongValue];
			[weakSelf save];
		}];
	}
}

- (void)toggleKey:(NSString *)key on:(BOOL)on sender:(UISwitch *)sender {
	if ([key isEqualToString:@"enabled"]) self.enabled = on;
	else if ([key isEqualToString:@"offline"]) self.offlineOnly = on;
	else if ([key isEqualToString:@"existing"]) self.existing = on;
	else if ([key isEqualToString:@"new"]) self.newChats = on;
	else if ([key isEqualToString:@"contacts"]) self.contacts = on;
	else if ([key isEqualToString:@"nonContacts"]) self.nonContacts = on;
	else if ([key isEqualToString:@"exclude"]) self.excludeSelected = on;
	[self save];
}

@end
