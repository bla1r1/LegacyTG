#import "TGBusinessViewController.h"
#import "TGBusinessMessagesViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGBusinessHoursViewController.h"
#import "TGBusinessBaseViewController.h"
#import "TGBusinessViewController.h"
#import "TGBusinessProfileViewController.h"
#import "TGBusinessChatLinksViewController.h"
#import "TGBusinessGreetingViewController.h"
#import "TGBusinessAwayViewController.h"
#import "TGBusinessLocationViewController.h"
#import "TGBusinessIntroViewController.h"

@interface TGBusinessHoursViewController ()
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSInteger startHour;
@property (nonatomic, assign) NSInteger endHour;
@property (nonatomic, strong) NSMutableArray *days;
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


@implementation TGBusinessHoursViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Business Hours";
	self.startHour = 9;
	self.endHour = 18;
	self.days = [NSMutableArray arrayWithArray:@[@YES, @YES, @YES, @YES, @YES, @NO, @NO]];
	[self load];
}

- (void)load {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] businessInfoWithCompletion:^(NSDictionary *info, NSString *error){
		TGBusinessHoursViewController *page = weakSelf;
		if (!page)
			return;
		NSArray *intervals = info[@"opening_hours"][@"opening_hours"];
		if ([intervals isKindOfClass:NSArray.class] && intervals.count){
			page.enabled = YES;
			[page.days replaceObjectAtIndex:0 withObject:@NO];
			[page.days replaceObjectAtIndex:1 withObject:@NO];
			[page.days replaceObjectAtIndex:2 withObject:@NO];
			[page.days replaceObjectAtIndex:3 withObject:@NO];
			[page.days replaceObjectAtIndex:4 withObject:@NO];
			[page.days replaceObjectAtIndex:5 withObject:@NO];
			[page.days replaceObjectAtIndex:6 withObject:@NO];
			BOOL first = YES;
			for (NSDictionary *interval in intervals){
				NSInteger start = [interval[@"start_minute"] integerValue];
				NSInteger end = [interval[@"end_minute"] integerValue];
				if (first){
					page.startHour = (start % 1440) / 60;
					page.endHour = (end % 1440) / 60;
					first = NO;
				}
				NSInteger day = start / 1440;
				if (day >= 0 && day < 7)
					[page.days replaceObjectAtIndex:(NSUInteger)day withObject:@YES];
			}
		}
		[page rebuildSections];
	}];
	[self rebuildSections];
}

- (void)rebuildSections {
	NSMutableArray *dayRows = [NSMutableArray array];
	for (NSInteger day = 0; day < 7; day++)
		[dayRows addObject:TGBSwitch(TGBDayName(day), nil,
				[NSString stringWithFormat:@"day%ld", (long)day],
				[self.days[(NSUInteger)day] boolValue], self.enabled)];
	self.sections = @[
		TGBSection(@"BUSINESS HOURS",
				@"Turn this on to show an opening-hours schedule to customers.",
				@[
			TGBSwitch(@"Show Business Hours", nil, @"enabled", self.enabled, YES),
			TGBInfo(@"Time Zone", [NSTimeZone localTimeZone].name ?: @"UTC"),
			TGBAction(@"Daily Hours", [NSString stringWithFormat:@"%@ to %@",
					TGBClockTime(self.startHour * 60), TGBClockTime(self.endHour * 60)],
					@"hours"),
		]),
		TGBSection(@"DAYS OPEN", @"The schedule is sent as one interval per open day.",
				dayRows),
	];
	[self rebuild];
}

- (NSDictionary *)openingHours {
	NSMutableArray *intervals = [NSMutableArray array];
	for (NSInteger day = 0; day < 7; day++){
		if (![self.days[(NSUInteger)day] boolValue])
			continue;
		NSInteger start = day * 1440 + self.startHour * 60;
		NSInteger end = day * 1440 + self.endHour * 60;
		if (end <= start)
			end = start + 60;
		[intervals addObject:@{@"@type" : @"businessOpeningHoursInterval",
							   @"start_minute" : @(start),
							   @"end_minute" : @(end)}];
	}
	return @{@"timeZone" : [NSTimeZone localTimeZone].name ?: @"UTC",
			 @"intervals" : intervals};
}

- (void)save {
	NSDictionary *object = [self openingHours];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setBusinessOpeningHoursTimeZone:object[@"timeZone"]
											 intervals:self.enabled ? object[@"intervals"] : nil
											completion:^(BOOL ok, NSString *error){
		TGBusinessHoursViewController *page = weakSelf;
		if (!page)
			return;
		if (!ok){
			[page showResult:NO error:error title:@"Business Hours"];
			[page load];
			return;
		}
		[page rebuildSections];
	}];
}

- (void)didChooseAction:(NSString *)action row:(NSDictionary *)row {
	if (![action isEqualToString:@"hours"])
		return;
	__weak typeof(self) weakSelf = self;
	[self askText:@"Opening Time" message:@"Hour of the day, 0 to 23."
	  placeholder:@"9" text:[NSString stringWithFormat:@"%ld", (long)self.startHour]
		   action:@"Next" completion:^(NSString *text){
		NSInteger start = MAX(0, MIN(23, [text integerValue]));
		[weakSelf askText:@"Closing Time" message:@"Hour of the day, 0 to 23."
			  placeholder:@"18" text:[NSString stringWithFormat:@"%ld", (long)weakSelf.endHour]
				   action:@"Save" completion:^(NSString *close){
			weakSelf.startHour = start;
			weakSelf.endHour = MAX(0, MIN(23, [close integerValue]));
			if (weakSelf.endHour <= weakSelf.startHour)
				weakSelf.endHour = MIN(23, weakSelf.startHour + 1);
			[weakSelf save];
		}];
	}];
}

- (void)toggleKey:(NSString *)key on:(BOOL)on sender:(UISwitch *)sender {
	if ([key isEqualToString:@"enabled"]){
		self.enabled = on;
		[self save];
		return;
	}
	if ([key hasPrefix:@"day"]){
		NSInteger day = [[key substringFromIndex:3] integerValue];
		if (day >= 0 && day < 7)
			[self.days replaceObjectAtIndex:(NSUInteger)day withObject:@(on)];
		[self save];
	}
}

@end
