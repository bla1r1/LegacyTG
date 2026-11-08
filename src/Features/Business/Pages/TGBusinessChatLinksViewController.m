#import "TGBusinessViewController.h"
#import "TGBusinessMessagesViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGBusinessChatLinksViewController.h"
#import "TGBusinessBaseViewController.h"
#import "TGBusinessViewController.h"
#import "TGBusinessProfileViewController.h"
#import "TGBusinessGreetingViewController.h"
#import "TGBusinessAwayViewController.h"
#import "TGBusinessHoursViewController.h"
#import "TGBusinessLocationViewController.h"
#import "TGBusinessIntroViewController.h"

@interface TGBusinessChatLinksViewController ()
@property (nonatomic, strong) NSArray *links;
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


@implementation TGBusinessChatLinksViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Links to Chat";
	[self load];
}

- (void)load {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] businessChatLinksWithCompletion:^(NSArray *links, NSString *error){
		TGBusinessChatLinksViewController *page = weakSelf;
		if (!page)
			return;
		page.links = links ?: @[];
		page.loadError = error;
		[page rebuildSections];
	}];
}

- (void)rebuildSections {
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *link in self.links){
		NSString *title = link[@"title"];
		if (!title.length)
			title = link[@"link"] ?: @"Link";
		NSString *text = link[@"text"][@"text"];
		if (!text.length)
			text = @"No preset message";
		NSMutableDictionary *row = [TGBAction(title, text, @"link") mutableCopy];
		row[@"link"] = link;
		[rows addObject:row];
	}
	if (!rows.count){
		[rows addObject:TGBInfo(@"No links",
				self.loadError.length ? self.loadError
						: @"Create one to suggest a first message.")];
	}
	self.sections = @[
		TGBSection(@"LINKS TO CHAT",
				@"Each link starts a chat with this account and puts the text "
				@"in the other person's input field.", rows),
		TGBSection(nil, nil, @[
			TGBAction(@"Create a Link to Chat", nil, @"create"),
		]),
	];
	[self rebuild];
}

- (void)didChooseAction:(NSString *)action row:(NSDictionary *)row {
	if ([action isEqualToString:@"create"]){
		[self createLink];
		return;
	}
	if ([action isEqualToString:@"link"]){
		[self showActionsForLink:row[@"link"]];
	}
}

- (void)createLink {
	__weak typeof(self) weakSelf = self;
	[self askText:@"Create a Link to Chat"
		  message:@"A name only you see first."
	  placeholder:@"Link name" text:nil action:@"Next"
	   completion:^(NSString *title){
		[weakSelf askText:@"Create a Link to Chat"
				  message:@"The message that will be suggested to the other person."
			  placeholder:@"Preset message" text:nil action:@"Create"
			   completion:^(NSString *text){
			[[TGClient shared] createBusinessChatLinkWithText:text title:title
					completion:^(NSDictionary *link, NSString *error){
				TGBusinessChatLinksViewController *page = weakSelf;
				if (!page)
					return;
				if (error.length)
					[page showResult:NO error:error title:@"Links to Chat"];
				[page load];
			}];
		}];
	}];
}

- (void)showActionsForLink:(NSDictionary *)link {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Edit", @"Info", @"Delete"]
						title:link[@"title"] ?: @"Link to Chat"
			 destructiveIndex:2
					   inView:self.view
					 onChoice:^(NSInteger index){
		TGBusinessChatLinksViewController *page = weakSelf;
		if (!page)
			return;
		if (index == 0)
			[page editLink:link];
		else if (index == 1)
			[page showInfoForLink:link];
		else
			[page deleteLink:link];
	}];
}

- (void)editLink:(NSDictionary *)link {
	__weak typeof(self) weakSelf = self;
	NSString *title = link[@"title"] ?: @"";
	NSString *text = link[@"text"][@"text"] ?: @"";
	[self askText:@"Edit Link" message:@"The name only you see."
	  placeholder:@"Link name" text:title action:@"Next"
	   completion:^(NSString *newTitle){
		[weakSelf askText:@"Edit Link" message:@"The suggested first message."
			  placeholder:@"Preset message" text:text action:@"Save"
			   completion:^(NSString *newText){
			[[TGClient shared] editBusinessChatLink:link[@"link"]
											   text:newText title:newTitle
										 completion:^(NSDictionary *edited, NSString *error){
				TGBusinessChatLinksViewController *page = weakSelf;
				if (!page)
					return;
				if (error.length)
					[page showResult:NO error:error title:@"Links to Chat"];
				[page load];
			}];
		}];
	}];
}

- (void)showInfoForLink:(NSDictionary *)link {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] businessChatLinkInfoForName:TGBusinessLinkName(link[@"link"])
										 completion:^(NSDictionary *info, NSString *error){
		TGBusinessChatLinksViewController *page = weakSelf;
		if (!page)
			return;
		if (error.length){
			[page showResult:NO error:error title:@"Link Info"];
			return;
		}
		NSString *text = info[@"text"][@"text"] ?: @"No preset message";
		[page showMessage:[NSString stringWithFormat:
				@"Chat %@\n\n%@", info[@"chat_id"] ?: @0, text]
					 title:@"Link Info"];
	}];
}

- (void)deleteLink:(NSDictionary *)link {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"Anyone using this link will not start a chat with it."
						title:@"Delete Link"
					   action:@"Delete"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGClient shared] deleteBusinessChatLink:link[@"link"]
										completion:^(BOOL ok, NSString *error){
			TGBusinessChatLinksViewController *page = weakSelf;
			if (!page)
				return;
			if (!ok)
				[page showResult:NO error:error title:@"Links to Chat"];
			[page load];
		}];
	}];
}

@end
