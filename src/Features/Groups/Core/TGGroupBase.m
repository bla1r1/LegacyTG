#import "TGObservers.h"
#import "TGGroupSettingsViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGSnackbar.h"
#import "TGContactsViewController.h"
#import "TGChatToolsViewController.h"
#import "TGGroupMemberActions.h"
#import "TGMemberCell.h"
#import "TGProfileViewController.h"
#import "TGIcons.h"
#import "TGGroupCallViewController.h"
#import "TGVideoChatSetupViewController.h"
#import "TGAntiSpamViewController.h"
#import "TGGroupSettingsViewController.h"
#import "TGGroupSwitch.h"
#import "TGGroupSettingsViewControllerInternal.h"
#import "TGClientNotifications.h"



//
// TGGroupSettingsViewController.m - one screen for everything a group is.
//
// The group profile's More menu used to grow one row per setting: Photo,
// Name, Description, Invite Link, Permissions, Sign Messages, Join to Send,
// All History, Welcome Messages, Direct Messages, Import, Send as, Clear by
// Date, Chat Tools. Each row asked the server what it sat on and answered
// with a sheet. A settings screen can show the value, group the rows by what
// they change, and leave the profile menu for the things a profile does.
//
// The chat id is the only thing the caller passes. Every action here names
// that id directly, so nothing is routed through the profile controller
// behind this screen.
//

/// The rows a section can hold. A switch draws a UISwitch, a member row a
/// face, and everything else a value with a chevron.
typedef NS_ENUM(NSInteger, TGGroupRowKind) {
	TGGroupRowInfo = 0,
	TGGroupRowAction,
	TGGroupRowSwitch,
	TGGroupRowUsername,
	TGGroupRowMember,
};

/// A switch that names the setting it changes, so a reload can rebuild rows
/// without an index pointing at the wrong one.





@implementation TGGroupSettingsViewController (TGGroupBase)


- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	NSLog(@"TGGroupSettings: opened for chat %lld", self.chatId);
	self.title = self.chatTitle.length ? self.chatTitle : @"Group Settings";
	self.active = [NSMutableArray array];
	self.disabled = [NSMutableArray array];
	// The screen is real before the first answer: a pushed blank table and a
	// nav bar still saying the group's name read as "the tap did nothing".
	self.sections = @[];
	[self showLoading];
	self.loaded = YES;
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	[self applyTheme];
	[self load];

	// A tap opens the person's profile; a hold keeps the member sheet, the
	// same split the group profile uses.
	UILongPressGestureRecognizer *memberHold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(memberRowHeld:)];
	memberHold.minimumPressDuration = 0.5;
	memberHold.cancelsTouchesInView = YES;
	[self.tableView addGestureRecognizer:memberHold];

	__weak typeof(self) weakSelf = self;
	[TGObservers observe:TGThemeChangedNotification owner:self usingBlock:^(NSNotification *note) {
		[weakSelf applyTheme];
		[weakSelf rebuild];
	}];
	// A switch moved on another device is a full-info update here. The screen
	// re-reads rather than showing the value it opened with.
	[TGObservers observe:TGFullInfoChangedNotification owner:self usingBlock:^(NSNotification *note) {
		NSNumber *chatId = note.userInfo[@"id"];
		if (chatId && [chatId longLongValue] == weakSelf.chatId)
			[weakSelf load];
	}];
	[TGObservers observe:TGChatMembersChangedNotification owner:self usingBlock:^(NSNotification *note) {
		NSNumber *chatId = note.userInfo[@"chatId"];
		if (chatId && [chatId longLongValue] == weakSelf.chatId)
			[weakSelf load];
	}];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	[self load];
}

- (void)applyTheme {
	[super applyTheme];
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}


@end
