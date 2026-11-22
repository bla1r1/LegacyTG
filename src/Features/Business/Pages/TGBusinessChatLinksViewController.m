#import "TGBusinessViewController.h"
#import "TGBusinessMessagesViewController.h"
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
#import "TGBusinessStore.h"
#import "TGProfileStore.h"
#import "TGPresent.h"

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




#pragma mark - the shared list screen


@implementation TGBusinessChatLinksViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Links to Chat";
	[self load];
}

- (void)load {
	__weak typeof(self) weakSelf = self;
	[[TGBusinessStore shared] businessChatLinksWithCompletion:^(NSArray *links, NSString *error){
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
			text = @"Add a preset message...";
		NSMutableDictionary *row = [TGBAction(title, text, @"link") mutableCopy];
		row[@"link"] = link;
		[rows addObject:row];
	}
	if (!rows.count){
		[rows addObject:TGBInfo(@"Create a Link to Chat",
				self.loadError.length ? self.loadError : nil)];
	}
	self.sections = @[
		TGBSection(@"LINKS TO CHAT", nil, rows),
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
		  message:@"Add a name for this link that only you will see."
	  placeholder:@"Link name" text:nil action:@"Next"
	   completion:^(NSString *title){
		[weakSelf askText:@"Create a Link to Chat"
				  message:@"Add a message that will be entered in the message input field for anyone who starts a chat with you using this link:"
			  placeholder:@"Add a preset message..." text:nil action:@"Create"
			   completion:^(NSString *text){
			[[TGBusinessStore shared] createBusinessChatLinkWithText:text title:title
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
	[TGPresent showMenuTitles:@[@"Edit", @"Info", @"Delete"] destructiveIndex:2
			fromView:nil onController:self onChoice:^(NSInteger index){
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
	[self askText:@"Edit Link" message:@"Add a name for this link that only you will see."
	  placeholder:@"Link name" text:title action:@"Next"
	   completion:^(NSString *newTitle){
		[weakSelf askText:@"Edit Link" message:nil
			  placeholder:@"Add a preset message..." text:text action:@"Save"
			   completion:^(NSString *newText){
			[[TGBusinessStore shared] editBusinessChatLink:link[@"link"]
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
	[[TGBusinessStore shared] businessChatLinkInfoForName:TGBusinessLinkName(link[@"link"])
										 completion:^(NSDictionary *info, NSString *error){
		TGBusinessChatLinksViewController *page = weakSelf;
		if (!page)
			return;
		if (error.length){
			[page showResult:NO error:error title:@"Info"];
			return;
		}
		NSString *text = info[@"text"][@"text"] ?: @"Add a preset message...";
		[page showMessage:text title:@"Info"];
	}];
}

- (void)deleteLink:(NSDictionary *)link {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"Are you sure you want to delete this link? It will be completely gone."
						title:@"Delete Link"
					   action:@"Delete"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGBusinessStore shared] deleteBusinessChatLink:link[@"link"]
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
