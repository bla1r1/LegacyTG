#import "TGObservers.h"
#import "TGProfileViewControllerInternal.h"
#import "TGProfileStore.h"
#import "TGNameWithStatus.h"
#import "TGCustomEmojiStore.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGMemberCell.h"
#import "TGGroupMemberActions.h"
#import "TGProfileAudioViewController.h"
#import "TGMusicPlayer.h"
#import "TGChatViewController.h"
#import "TGSimilarChannelsViewController.h"
#import "TGDMTopicsViewController.h"
#import "UIImage+WebP.h"
#import <AVFoundation/AVFoundation.h>
#import "TGProfileViewController.h"
#import "TGProfileHeaderView.h"
#import "TGNewContactViewController.h"
#import "TGLocalization.h"
#import "TGGroupSettingsViewController.h"
#import "TGProfileLogic.h"
#import "TGBarItem.h"
#import "TGPresent.h"








@implementation TGProfileViewController (TGProfileLifecycle)

#pragma mark - lifecycle
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
							  duration:(NSTimeInterval)duration {
	[super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	// Grid tiles are laid out to the width at build time; rebuilding the rows
	// lets the table re-ask their metrics at the new width.
	[self rebuildSections];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	// A profile carries no title in the bar: the name in the header already
	// says whose it is.
	self.title = @"";
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	[self applyTheme];
	[self updateNavigationItem];

	// The status line listens to the network too (B4): a profile opened
	// offline used to freeze at its captured last-seen.
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(statusLabelOwnerChanged:)
			name:TGConnectionStateChangedNotification object:nil];
	[nc addObserver:self selector:@selector(statusLabelOwnerChanged:)
			name:TGUserStatusChangedNotification object:nil];
	// A bio edited elsewhere, a member added to the group: the full record
	// arrives as its own update and this screen used to need a reopen.
	[nc addObserver:self selector:@selector(fullInfoChanged:)
			name:TGFullInfoChangedNotification object:nil];
	// Someone joined, was promoted or removed, or asked to join: the member
	// rows and the request count are both read in loadDetails.
	[nc addObserver:self selector:@selector(membersChanged:)
			name:TGChatMembersChangedNotification object:nil];

	[self buildHeader];
	[self rebuildSections];
	[self loadDetails];
	[self loadMedia];

	// A tap opens who they are; a hold keeps the member sheet that used to
	// be the only thing a tap did. Cancelling touches on recognition stops
	// the lift after a hold from also selecting the row underneath.
	UILongPressGestureRecognizer *memberHold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(memberRowHeld:)];
	memberHold.minimumPressDuration = 0.5;
	memberHold.cancelsTouchesInView = YES;
	[self.tableView addGestureRecognizer:memberHold];

	__weak typeof(self) weakSelf = self;
	[TGObservers observe:TGThemeChangedNotification owner:self usingBlock:^(NSNotification *note) {
		[weakSelf applyTheme];
		[weakSelf buildHeader];
		[weakSelf rebuildSections];
	}];

	[TGObservers observe:TGCustomEmojiLoadedNotification owner:self usingBlock:^(NSNotification *note) {
		TGProfileViewController *me = weakSelf;
		if (!me)
			return;
		[NSObject cancelPreviousPerformRequestsWithTarget:me selector:@selector(reloadEmojiStatusRows) object:nil];
		[me performSelector:@selector(reloadEmojiStatusRows) withObject:nil afterDelay:0.3];
	}];
}

- (void)reloadEmojiStatusRows {
	[self buildHeader];
	NSArray *visible = [self.tableView indexPathsForVisibleRows];
	if (visible.count) {
		[self.tableView reloadRowsAtIndexPaths:visible withRowAnimation:UITableViewRowAnimationNone];
	}
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	[self updateNavigationItem];
	if (self.isOwnProfile){
		NSString *ownName = TGProfileUserName([TGProfileStore shared].me);
		if (ownName.length)
			self.name = ownName;
		[self loadDetails];
	}
}

- (void)updateNavigationItem {
	NSMutableArray *items = [NSMutableArray array];
	// My Profile posts a story from the bar; every profile you may edit gets
	// the Edit word on the right.
	if (self.isOwnProfile){
		// Same control as the chat list's: the official ring at the bar's
		// button size, in the bar-button colour.
		UIBarButtonItem *story = [TGBarItem itemWithRole:TGBarRoleAddStory
				target:self action:@selector(addStoryTapped)];
		[items addObject:story];
	}
	// A creator or administrator can edit a group/channel profile too; the
	// role arrives after the first answer, so updateNavigationItem is called
	// again when it does.
	BOOL canEdit = self.isOwnProfile || self.isContact ||
			(self.chatId && self.canManage);
	if (canEdit){
		[items addObject:[TGBarItem itemWithRole:TGBarRoleEdit
				target:self action:@selector(editProfileTapped)]];
	}
	// Files, Music and Links search from the bar while their pane is open.
	NSString *kind = [self selectedMediaKind];
	if (!self.mediaSearchActive && TGProfileMediaKindSupportsSearch(kind)){
		[items addObject:[TGBarItem itemWithRole:TGBarRoleSearch
				target:self action:@selector(mediaSearchTapped)]];
	}
	self.navigationItem.rightBarButtonItems = items.count ? items : nil;
}

/// A contact's Edit fills the contact form with the name and number the
/// profile already knows; the form writes only on Done.
- (void)editProfileTapped {
	// A group or channel's Edit is its settings screen (official opens the
	// peer's edit mode there); the account editor would rename the user.
	// A user's profile carries its private chat id too; userId is 0 only
	// for a group or channel.
	if (self.chatId && !self.userId){
		TGGroupSettingsViewController *settings = [[TGGroupSettingsViewController alloc] init];
		settings.chatId = self.chatId;
		settings.chatTitle = self.name;
		settings.hidesBottomBarWhenPushed = YES;
		[TGPresent openController:settings from:self];
		return;
	}
	if (!self.isOwnProfile && self.isContact){
		TGNewContactViewController *edit = [[TGNewContactViewController alloc] init];
		edit.title = TGLocalized(@"Edit");
		edit.userId = self.userId;
		NSArray *words = [self.name componentsSeparatedByString:@" "];
		edit.first = words.firstObject ?: @"";
		edit.last = words.count > 1
				? [[words subarrayWithRange:NSMakeRange(1, words.count - 1)]
						componentsJoinedByString:@" "] : @"";
		edit.phone = self.phoneNumber ?: @"";
		[TGPresent presentModal:edit kind:TGModalForm from:self];
		return;
	}
	TGEditProfileViewController *edit = [[TGEditProfileViewController alloc] init];
	edit.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:edit animated:YES];
}

- (void)applyTheme {
	[super applyTheme];
	TGTheme *theme = [TGTheme shared];
	[theme styleGroupedTable:self.tableView];
	[theme styleNavigationBar:self.navigationController.navigationBar];
	if (self.similarChannelsCompositeImage) {
		self.similarChannelsCompositeImage = nil;
		[self checkAndCompositeSimilarChannelsAvatars];
	}
}

/// The profile as the current client draws it: a large picture centred, the
/// name and status under it, and a row of tiles for the things you actually do
/// here. The coloured block this replaced is the old design; everything since
/// Downloads decode off the main thread and the circle is baked into the
/// bitmap, so the scrolling header never carries a masked layer.
- (void)applyAvatarImageAtPath:(NSString *)path {
	if (!path.length)
		return;
	CGFloat side = TGMetricProfileAvatar;
	CGFloat scale = [UIScreen mainScreen].scale;
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		UIImage *image = [TGIcons decodedImageAtPath:path
										 fittingSize:CGSizeMake(side, side)
												fill:YES
											   scale:scale];
		UIImage *round = [TGIcons roundedImage:image
										 size:CGSizeMake(side, side)
									   radius:TGHalf(side)
									  corners:UIRectCornerAllCorners];
		if (!round)
			return;
		dispatch_async(dispatch_get_main_queue(), ^{
			weakSelf.avatarImage = round;
			weakSelf.headerView.avatarImage = round;
		});
	});
}


@end
