#import "TGBusinessViewController.h"
#import "TGBusinessMessagesViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGBusinessGreetingViewController.h"
#import "TGBusinessBaseViewController.h"
#import "TGBusinessViewController.h"
#import "TGBusinessProfileViewController.h"
#import "TGBusinessChatLinksViewController.h"
#import "TGBusinessAwayViewController.h"
#import "TGBusinessHoursViewController.h"
#import "TGBusinessLocationViewController.h"
#import "TGBusinessIntroViewController.h"
#import "TGBusinessStore.h"
#import "TGProfileStore.h"

@interface TGBusinessGreetingViewController ()
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSInteger shortcutId;
@property (nonatomic, assign) NSInteger inactivityDays;
@property (nonatomic, assign) BOOL existing;
@property (nonatomic, assign) BOOL newChats;
@property (nonatomic, assign) BOOL contacts;
@property (nonatomic, assign) BOOL nonContacts;
@property (nonatomic, assign) BOOL excludeSelected;
@property (nonatomic, assign) BOOL loaded;
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


@implementation TGBusinessGreetingViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Greeting Messages";
	self.existing = YES;
	self.newChats = YES;
	self.contacts = YES;
	self.nonContacts = YES;
	self.inactivityDays = 7;
	[self load];
}

- (void)load {
	__weak typeof(self) weakSelf = self;
	[[TGBusinessStore shared] businessInfoWithCompletion:^(NSDictionary *info, NSString *error){
		TGBusinessGreetingViewController *page = weakSelf;
		if (!page)
			return;
		NSDictionary *settings = info[@"greeting_message_settings"];
		if ([settings isKindOfClass:NSDictionary.class]){
			page.enabled = YES;
			page.shortcutId = [settings[@"shortcut_id"] integerValue];
			page.inactivityDays = [settings[@"inactivity_days"] integerValue];
			page.existing = [settings[@"recipients"][@"select_existing_chats"] boolValue];
			page.newChats = [settings[@"recipients"][@"select_new_chats"] boolValue];
			page.contacts = [settings[@"recipients"][@"select_contacts"] boolValue];
			page.nonContacts = [settings[@"recipients"][@"select_non_contacts"] boolValue];
			page.excludeSelected = [settings[@"recipients"][@"exclude_selected"] boolValue];
		}
		page.loaded = YES;
		[page rebuildSections];
	}];
	[self rebuildSections];
}

- (void)rebuildSections {
	self.sections = @[
		TGBSection(@"GREETING MESSAGE", nil, @[
			TGBSwitch(@"Send Greeting Message", nil, @"enabled", self.enabled, YES),
			TGBAction(@"Shortcut",
					[NSString stringWithFormat:@"%ld", (long)self.shortcutId],
					@"shortcut"),
			TGBAction(@"If Inactive For",
					[NSString stringWithFormat:@"%ld", (long)self.inactivityDays],
					@"days"),
		]),
		TGBSection(@"RECIPIENTS", nil, @[
			TGBSwitch(@"Existing Chats", nil, @"existing", self.existing, self.enabled),
			TGBSwitch(@"New Chats", nil, @"new", self.newChats, self.enabled),
			TGBSwitch(@"Contacts", nil, @"contacts", self.contacts, self.enabled),
			TGBSwitch(@"Non-Contacts", nil, @"nonContacts", self.nonContacts, self.enabled),
			TGBSwitch(@"Excluded Chats", nil, @"exclude", self.excludeSelected, self.enabled),
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
	[[TGBusinessStore shared] setBusinessGreetingMessageEnabled:self.enabled
											 shortcutId:self.shortcutId
										 inactivityDays:self.inactivityDays
											 recipients:[self recipients]
											 completion:^(BOOL ok, NSString *error){
		TGBusinessGreetingViewController *page = weakSelf;
		if (!page)
			return;
		if (!ok){
			[page showResult:NO error:error title:@"Greeting Messages"];
			[page load];
			return;
		}
		[page rebuildSections];
	}];
}

- (void)didChooseAction:(NSString *)action row:(NSDictionary *)row {
	__weak typeof(self) weakSelf = self;
	if ([action isEqualToString:@"shortcut"]){
		[self askText:@"Shortcut"
			  message:nil
		  placeholder:@"1" text:[NSString stringWithFormat:@"%ld", (long)self.shortcutId]
			   action:@"Save" completion:^(NSString *text){
			weakSelf.shortcutId = [text integerValue];
			[weakSelf save];
		}];
	} else if ([action isEqualToString:@"days"]){
		[self askText:@"If Inactive For"
			  message:nil
		  placeholder:@"7" text:[NSString stringWithFormat:@"%ld", (long)self.inactivityDays]
			   action:@"Save" completion:^(NSString *text){
			weakSelf.inactivityDays = MAX(0, [text integerValue]);
			[weakSelf save];
		}];
	}
}

- (void)toggleKey:(NSString *)key on:(BOOL)on sender:(UISwitch *)sender {
	if ([key isEqualToString:@"enabled"]) self.enabled = on;
	else if ([key isEqualToString:@"existing"]) self.existing = on;
	else if ([key isEqualToString:@"new"]) self.newChats = on;
	else if ([key isEqualToString:@"contacts"]) self.contacts = on;
	else if ([key isEqualToString:@"nonContacts"]) self.nonContacts = on;
	else if ([key isEqualToString:@"exclude"]) self.excludeSelected = on;
	[self save];
}

@end
