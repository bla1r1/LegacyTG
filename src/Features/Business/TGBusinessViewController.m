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
@end

//
// TGBusinessViewController.m - the official Telegram Business presentation:
// one icon-tile row per feature, in PremiumIntroScreen's businessPerks order.
// The account-level settings themselves live on the pushed pages.
//

/// A presentation row: a 29 pt tile, the feature name and the description
/// official gives it. Settings root colours the same tile through TGIcons, so
/// the Business page does not draw a second kind of icon.
static NSDictionary *TGBBusinessPerk(NSString *title, NSString *description,
									 NSString *action, NSString *icon,
									 UIColor *tile) {
	NSMutableDictionary *row = [(action
			? TGBOpenAction(title, description, action)
			: TGBInfo(title, description)) mutableCopy];
	row[@"icon"] = icon;
	row[@"tile"] = tile;
	return row;
}

#pragma mark - the shared list screen


@implementation TGBusinessViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Telegram Business";
	[self rebuildSections];
}

#pragma mark - the presentation

- (void)rebuildSections {
	// PremiumIntroScreen's businessPerks: location, hours, quick replies,
	// greeting, away, links, intro, chatbots. The two rows with no page in
	// this client stay informational rather than opening an invented console.
	NSArray *rows = @[
		TGBBusinessPerk(@"Location",
				@"Display the location of your business on your account.",
				@"location", @"pin", TGIconTileCoral()),
		TGBBusinessPerk(@"Opening Hours",
				@"Show to your customers when you are open for business.",
				@"hours", @"recent", TGIconTileAmber()),
		TGBBusinessPerk(@"Quick Replies",
				@"Set up shortcuts with rich text and media to respond to messages faster.",
				nil, @"reply", TGIconTileGreen()),
		TGBBusinessPerk(@"Greeting Messages",
				@"Greet customers when they message you the first time or after a period of no activity.",
				@"greeting", @"chat", TGIconTileSky()),
		TGBBusinessPerk(@"Away Messages",
				@"Automatically reply with a message when you are away.",
				@"away", @"mute", TGIconTileViolet()),
		TGBBusinessPerk(@"Links to Chat",
				@"Create links that start a chat with you, suggesting the first message.",
				@"links", @"mention", TGIconTileAzure()),
		TGBBusinessPerk(@"Start Page", nil, @"intro", @"compose",
				TGIconTilePurple()),
		TGBBusinessPerk(@"Chatbots",
				@"Add any third-party chatbots that will process customer interactions.",
				nil, @"contacts", TGIconTileGrey()),
	];
	self.sections = @[TGBSection(nil,
			@"Turn your account to a business page with these additional features.",
			rows)];
	[self rebuild];
}

#pragma mark - the shared cell

- (NSDictionary *)perkRowAt:(NSIndexPath *)path {
	if (path.section >= (NSInteger)self.sections.count)
		return nil;
	NSArray *rows = self.sections[(NSUInteger)path.section][@"rows"];
	return path.row < (NSInteger)rows.count ? rows[(NSUInteger)path.row] : nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path {
	NSDictionary *row = [self perkRowAt:path];
	return row[@"icon"] ? TGMetricBusinessRow
						: [super tableView:tableView heightForRowAtIndexPath:path];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)path {
	NSDictionary *row = [self perkRowAt:path];
	if (!row[@"icon"])
		return [super tableView:tableView cellForRowAtIndexPath:path];

	static NSString *reuse = @"TGBusinessPerkCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:reuse];
	TGTheme *theme = [TGTheme shared];
	[theme styleCell:cell];
	cell.textLabel.text = row[@"title"];
	cell.textLabel.font = TGFontRow();
	cell.textLabel.textColor = [theme primaryTextColour];
	cell.detailTextLabel.text = row[@"detail"] ?: @"";
	cell.detailTextLabel.font = TGFontCaption();
	cell.detailTextLabel.textColor = [theme secondaryTextColour];
	cell.detailTextLabel.numberOfLines = 2;
	cell.imageView.image = [TGIcons settingsIconNamed:row[@"icon"]
											   color:row[@"tile"]];
	BOOL tappable = row[@"action"] != nil;
	cell.accessoryType = (tappable && [row[@"opens"] boolValue])
			? UITableViewCellAccessoryDisclosureIndicator
			: UITableViewCellAccessoryNone;
	cell.selectionStyle = tappable ? UITableViewCellSelectionStyleDefault
								   : UITableViewCellSelectionStyleNone;
	return cell;
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
