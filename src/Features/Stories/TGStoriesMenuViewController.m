#import "TGStoriesMenuViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGStoryComposerViewController.h"
#import "TGStoryAlbumsViewController.h"
#import "TGStoryArchiveViewController.h"
#import "TGStorySettingsViewController.h"
#import "TGStoryViewerViewController.h"
#import "TGPublicStoriesViewController.h"
#import "TGLiveStoryViewController.h"

@interface TGStoriesMenuViewController ()
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) NSString *chatTitle;
@end

@implementation TGStoriesMenuViewController

- (instancetype)initWithChatId:(int64_t)chatId title:(NSString *)title {
	self = [super init];
	if (self){
		_chatId = chatId;
		_chatTitle = [title copy] ?: @"Your Story";
		self.listTitle = @"Stories";
		self.emptyText = @"No Results";
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.listFooter = nil;
	[self rebuildRows];
}

- (void)rebuildRows {
	NSMutableArray *rows = [NSMutableArray array];
	__weak typeof(self) weakSelf = self;
	[rows addObject:@{@"title" : @"Add Story",
					  @"opens" : @YES,
					  @"tap" : ^{ [weakSelf addStory]; }}];
	[rows addObject:@{@"title" : @"My Story",
					  @"opens" : @YES,
					  @"tap" : ^{ [weakSelf openMyStory]; }}];
	[rows addObject:@{@"title" : @"Albums",
					  @"opens" : @YES,
					  @"tap" : ^{ [weakSelf openAlbums]; }}];
	[rows addObject:@{@"title" : @"Story Archive",
					  @"opens" : @YES,
					  @"tap" : ^{ [weakSelf openArchive]; }}];
	[rows addObject:@{@"title" : @"Story Notifications",
					  @"opens" : @YES,
					  @"tap" : ^{ [weakSelf openNotifications]; }}];
	[rows addObject:@{@"title" : @"Stories",
					  @"opens" : @YES,
					  @"tap" : ^{ [weakSelf openPublic]; }}];
	[rows addObject:@{@"title" : @"Start Live Story As",
					  @"opens" : @YES,
					  @"tap" : ^{ [weakSelf openLive]; }}];
	[rows addObject:@{@"title" : @"Enable Stealth Mode",
					  @"tap" : ^{ [weakSelf activateStealth]; }}];
	self.rows = rows;
	[self.tableView reloadData];
}

- (void)addStory {
	__weak typeof(self) weakSelf = self;
	[TGStoryComposerViewController openFromController:self chatId:self.chatId
												title:self.chatTitle onPosted:^{
		TGStoriesMenuViewController *me = weakSelf;
		if (me.onStoriesChanged)
			me.onStoriesChanged();
	}];
}

- (void)openMyStory {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] activeStoryRowForChat:self.chatId completion:^(NSDictionary *row){
		TGStoriesMenuViewController *me = weakSelf;
		if (!me)
			return;
		NSArray *infos = row[@"stories"];
		if (!infos.count){
			[TGAlertSheet showMessage:@"No stories"
								title:@"My Story" inView:me.view];
			return;
		}
		NSMutableArray *ids = [NSMutableArray array];
		for (NSDictionary *info in infos)
			if ([info[@"storyId"] isKindOfClass:NSNumber.class])
				[ids addObject:info[@"storyId"]];
		TGStoryViewerViewController *viewer = [[TGStoryViewerViewController alloc]
				initWithChatId:me.chatId
						 title:me.chatTitle
					   stories:ids
					startIndex:0
					 canManage:YES];
		viewer.hidesBottomBarWhenPushed = YES;
		viewer.onStoriesChanged = ^{
			if (me.onStoriesChanged)
				me.onStoriesChanged();
		};
		[me.navigationController pushViewController:viewer animated:YES];
	}];
}

- (void)openAlbums {
	TGStoryAlbumsViewController *albums = [[TGStoryAlbumsViewController alloc]
			initWithChatId:self.chatId storyToAdd:0];
	albums.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:albums animated:YES];
}

- (void)openArchive {
	TGStoryArchiveViewController *archive = [[TGStoryArchiveViewController alloc]
			initWithChatId:self.chatId title:self.chatTitle];
	archive.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:archive animated:YES];
}

- (void)openNotifications {
	TGStorySettingsViewController *settings = [[TGStorySettingsViewController alloc] init];
	settings.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:settings animated:YES];
}

- (void)openPublic {
	TGPublicStoriesViewController *public = [[TGPublicStoriesViewController alloc]
			initWithTag:@""];
	public.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:public animated:YES];
}

- (void)openLive {
	TGLiveStoryViewController *live = [[TGLiveStoryViewController alloc]
			initWithChatId:self.chatId groupCallId:0];
	live.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:live animated:YES];
}

- (void)activateStealth {
	// Stealth mode is a Premium feature; asking first would end in a refusal.
	if (![[TGClient shared].me[@"is_premium"] boolValue]){
		[TGAlertSheet showMessage:@"Premium Needed"
							title:@"Stealth Mode" inView:self.view];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"Enable Stealth Mode"
						title:@"Stealth Mode"
					   action:@"Enable"
				  destructive:NO
					   inView:self.view
					onConfirm:^{
		TGStoriesMenuViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] activateStoryStealthModeWithCompletion:^(BOOL ok, NSString *error){
			[TGAlertSheet showMessage:ok
					? @"Stealth Mode On"
					: (error ?: @"An error occurred.")
								title:@"Stealth Mode" inView:me.view];
		}];
	}];
}

@end
