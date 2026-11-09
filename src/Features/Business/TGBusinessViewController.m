#import "TGBusinessViewController.h"
#import "TGBusinessMessagesViewController.h"
#import "TGStyle.h"
#import "TGBusinessBaseViewController.h"
#import "TGBusinessProfileViewController.h"
#import "TGBusinessChatLinksViewController.h"
#import "TGBusinessGreetingViewController.h"
#import "TGBusinessAwayViewController.h"
#import "TGBusinessHoursViewController.h"
#import "TGBusinessLocationViewController.h"
#import "TGBusinessIntroViewController.h"
#import "TGRows.h"

@interface TGBusinessViewController ()
@end

//
// TGBusinessViewController.m - the official Telegram Business presentation:
// one icon-tile row per feature, in PremiumIntroScreen's businessPerks order.
// The account-level settings themselves live on the pushed pages.
//

@implementation TGBusinessViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Telegram Business";
	[self rebuildSections];
}

#pragma mark - the presentation

/// PremiumIntroScreen's businessPerks: location, hours, quick replies,
/// greeting, away, links, intro, chatbots. The two rows with no page in
/// this client stay informational rather than opening an invented console.
- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSArray *rows = @[
		[self perkRow:@"Location"
				detail:@"Display the location of your business on your account."
				action:@"location" icon:@"pin" tile:TGIconTileCoral()],
		[self perkRow:@"Opening Hours"
				detail:@"Show to your customers when you are open for business."
				action:@"hours" icon:@"recent" tile:TGIconTileAmber()],
		[self perkRow:@"Quick Replies"
				detail:@"Set up shortcuts with rich text and media to respond to messages faster."
				action:nil icon:@"reply" tile:TGIconTileGreen()],
		[self perkRow:@"Greeting Messages"
				detail:@"Greet customers when they message you the first time or after a period of no activity."
				action:@"greeting" icon:@"chat" tile:TGIconTileSky()],
		[self perkRow:@"Away Messages"
				detail:@"Automatically reply with a message when you are away."
				action:@"away" icon:@"mute" tile:TGIconTileViolet()],
		[self perkRow:@"Links to Chat"
				detail:@"Create links that start a chat with you, suggesting the first message."
				action:@"links" icon:@"mention" tile:TGIconTileAzure()],
		[self perkRow:@"Start Page" detail:nil action:@"intro" icon:@"compose"
				tile:TGIconTilePurple()],
		[self perkRow:@"Chatbots"
				detail:@"Add any third-party chatbots that will process customer interactions."
				action:nil icon:@"contacts" tile:TGIconTileGrey()],
	];
	self.sections = @[TGSection(nil,
			@"Turn your account to a business page with these additional features.",
			rows)];
	[self rebuild];
}

/// A presentation row: a 29 pt tile, the feature name and the description
/// official gives it. Settings root colours the same tile through TGIcons, so
/// the Business page does not draw a second kind of icon.
- (NSDictionary *)perkRow:(NSString *)title
				   detail:(NSString *)detail
				   action:(NSString *)action
					 icon:(NSString *)icon
					 tile:(UIColor *)tile {
	__weak typeof(self) weakSelf = self;
	NSMutableDictionary *row = action
			? [TGIconTapOpenRow(title, detail, icon, tile, nil) mutableCopy]
			: [TGIconTapRow(title, detail, icon, tile, nil) mutableCopy];
	row[TGRowSubtitle] = @YES;
	row[TGRowDetailLines] = @2;
	row[TGRowHeight] = @(TGMetricBusinessRow);
	if (action){
		row[TGRowTap] = ^{ [weakSelf didChooseAction:action row:nil]; };
	}
	return row;
}

#pragma mark - actions

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
