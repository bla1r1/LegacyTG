#import "TGBusinessViewController.h"
#import "TGBusinessMessagesViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGBusinessBaseViewController.h"
#import "TGBusinessViewController.h"
#import "TGBusinessProfileViewController.h"
#import "TGBusinessChatLinksViewController.h"
#import "TGBusinessGreetingViewController.h"
#import "TGBusinessAwayViewController.h"
#import "TGBusinessHoursViewController.h"
#import "TGBusinessLocationViewController.h"
#import "TGBusinessIntroViewController.h"


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


@implementation TGBusinessBaseViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.sections = @[];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	[self.tableView reloadData];
}

- (void)applyTheme {
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)rebuild {
	[self.tableView reloadData];
}

- (NSDictionary *)rowAt:(NSIndexPath *)path {
	if (path.section >= (NSInteger)self.sections.count)
		return nil;
	NSArray *rows = self.sections[(NSUInteger)path.section][@"rows"];
	return path.row < (NSInteger)rows.count ? rows[(NSUInteger)path.row] : nil;
}

- (void)showResult:(BOOL)ok error:(NSString *)error title:(NSString *)title {
	NSString *text = ok ? @"Done"
			: (error.length ? error : @"An error occurred.");
	[self showMessage:text title:title];
}

- (void)askText:(NSString *)title
		message:(NSString *)message
	placeholder:(NSString *)placeholder
		   text:(NSString *)text
		 action:(NSString *)action
	 completion:(void (^)(NSString *))completion {
	[TGAlertSheet showInput:title message:message placeholder:placeholder
					   text:text action:action inView:self.view
				 onSubmit:completion];
}

- (void)didChooseAction:(NSString *)action row:(NSDictionary *)row {}
- (void)toggleKey:(NSString *)key on:(BOOL)on sender:(UISwitch *)sender {}

#pragma mark - table

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSString *text = self.sections[(NSUInteger)section][@"header"];
	return text.length ? text : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	NSString *text = self.sections[(NSUInteger)section][@"footer"];
	return text.length ? text : nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)[self.sections[(NSUInteger)section][@"rows"] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path {
	return TGMetricRow;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)path {
	NSDictionary *row = [self rowAt:path];
	TGTheme *theme = [TGTheme shared];
	TGBusinessRowKind kind = (TGBusinessRowKind)[row[@"kind"] integerValue];

	if (kind == TGBusinessRowSwitch){
		static NSString *reuse = @"switch";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
										  reuseIdentifier:reuse];
		[theme styleCell:cell];
		cell.textLabel.font = TGFontRow();
		cell.textLabel.textColor = [theme primaryTextColour];
		cell.detailTextLabel.font = TGFontCaption();
		cell.detailTextLabel.textColor = [theme secondaryTextColour];
		cell.textLabel.text = row[@"title"];
		cell.detailTextLabel.text = row[@"detail"] ?: @"";
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.on = [row[@"on"] boolValue];
		toggle.enabled = [row[@"enabled"] boolValue];
		toggle.tag = (NSInteger)path.section * 1000 + path.row;
		[toggle addTarget:self action:@selector(switchChanged:)
		 forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		return cell;
	}

	static NSString *reuse = @"value";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:reuse];
	[theme styleCell:cell];
	cell.textLabel.font = TGFontRow();
	cell.detailTextLabel.font = TGFontBody();
	cell.detailTextLabel.textColor = [theme cellDetailColour];
	cell.textLabel.text = row[@"title"];
	cell.detailTextLabel.text = row[@"detail"] ?: @"";
	BOOL tappable = row[@"action"] != nil;
	cell.accessoryType = (tappable && [row[@"opens"] boolValue])
			? UITableViewCellAccessoryDisclosureIndicator
			: UITableViewCellAccessoryNone;
	cell.selectionStyle = tappable ? UITableViewCellSelectionStyleDefault
								   : UITableViewCellSelectionStyleNone;
	cell.textLabel.textColor = kind == TGBusinessRowDestructive
			? [theme destructiveColour] : [theme primaryTextColour];
	return cell;
}

- (void)switchChanged:(UISwitch *)sender {
	NSInteger section = sender.tag / 1000;
	NSInteger item = sender.tag % 1000;
	if (section >= (NSInteger)self.sections.count)
		return;
	NSArray *rows = self.sections[(NSUInteger)section][@"rows"];
	if (item >= (NSInteger)rows.count)
		return;
	NSDictionary *row = rows[(NSUInteger)item];
	[self toggleKey:row[@"switch"] on:sender.on sender:sender];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
	NSDictionary *row = [self rowAt:path];
	NSString *action = row[@"action"];
	if (!action.length)
		return;
	[tableView deselectRowAtIndexPath:path animated:YES];
	[self didChooseAction:action row:row];
}

@end
