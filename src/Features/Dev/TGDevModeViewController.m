//
// TGDevModeViewController.m
//
#import "TGDevModeViewController.h"
#import "TGChatViewController.h"
#import "TGDevShowcase.h"
#import "TGNavController.h"
#import "TGSettingsViewController.h"
#import "TGLocalization.h"
#import "TGStyle.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGRowsViewController.h"
#import "TGRows.h"

/// The fixture chats. They live here and not in the chat list, so a real account's
/// list is only that account's.
@interface TGDevChatsViewController : TGRowsViewController
@property (nonatomic, strong) NSArray *chats;
@end

@implementation TGDevChatsViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Dev Chats");
	self.chats = [TGDevShowcase allShowcaseChats];
	[self rebuildSections];
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSArray *titles = TGDevChatRowTitles(self.chats);
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:titles.count];
	for (NSUInteger index = 0; index < titles.count; index++){
		NSDictionary *chatRecord = self.chats[index];
		[rows addObject:TGOpenRow(titles[index], nil, ^{
			[weakSelf openChat:chatRecord];
		})];
	}
	self.sections = @[TGSection(nil, nil, rows)];
	[self reloadRows];
}

- (void)openChat:(NSDictionary *)row {
	TGChatViewController *chat = [[TGChatViewController alloc] init];
	chat.chatId = [row[@"id"] longLongValue];
	chat.chatTitle = row[@"title"];
	chat.isGroup = [row[@"isGroup"] boolValue];
	chat.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:chat animated:YES];
}

@end

@implementation TGDevModeViewController

+ (void)presentFrom:(UIViewController *)host {
	if (host.presentedViewController)
		return;
	[host presentViewController:[[self alloc] init] animated:YES completion:nil];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	TGDevChatsViewController *chats = [[TGDevChatsViewController alloc]
			initWithStyle:UITableViewStyleGrouped];
	TGSettingsViewController *settings = [[TGSettingsViewController alloc] init];
	settings.page = TGSettingsPageDebug;

	UINavigationController *chatsNC = [[TGNavController alloc] initWithRootViewController:chats];
	chatsNC.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Dev Chats"
													   image:[TGIcons chats] tag:0];
	UINavigationController *settingsNC = [[TGNavController alloc] initWithRootViewController:settings];
	settingsNC.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Dev Settings"
														  image:[TGIcons settings] tag:1];
	for (UIViewController *root in @[chats, settings])
		root.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
				initWithTitle:@"Close" style:UIBarButtonItemStylePlain
					   target:self action:@selector(closeTapped)];
	self.viewControllers = @[chatsNC, settingsNC];
	[self applyTheme];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme)
												 name:TGThemeChangedNotification object:nil];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applyTheme {
	[[TGTheme shared] styleTabBar:self.tabBar];
}

- (void)closeTapped {
	[self dismissViewControllerAnimated:YES completion:nil];
}

@end
