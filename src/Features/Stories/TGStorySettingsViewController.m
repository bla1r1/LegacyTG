#import "TGStorySettingsViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGChatViewController.h"

@interface TGStorySettingsViewController ()
@property (nonatomic, strong) NSArray *exceptions;
@end

@implementation TGStorySettingsViewController

- (instancetype)init {
	self = [super init];
	if (self){
		self.title = @"Story Notifications";
		self.emptyText = @"No Results";
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.listFooter = nil;
	[self reloadExceptions];
}

- (void)reloadExceptions {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] storyNotificationExceptionsWithCompletion:^(NSArray *chats){
		TGStorySettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.exceptions = chats ?: @[];
		[me rebuildRows];
	}];
}

- (void)rebuildRows {
	NSMutableArray *rows = [NSMutableArray array];
	__weak typeof(self) weakSelf = self;
	[rows addObject:@{@"title" : @"Update",
					  @"tap" : ^{ [weakSelf reloadExceptions]; }}];
	for (NSDictionary *chat in self.exceptions){
		BOOL muted = [chat[@"muteStories"] boolValue];
		[rows addObject:@{
			@"title" : chat[@"title"] ?: @"Chat",
			@"detail" : muted ? @"Notifications are muted." : nil,
			@"opens" : @YES,
			@"tap" : ^{ [weakSelf openChat:chat]; },
		}];
	}
	self.listRows = rows;
	[self.tableView reloadData];
}

- (void)openChat:(NSDictionary *)chat {
	int64_t chatId = [chat[@"id"] longLongValue];
	if (!chatId)
		return;
	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = chatId;
	vc.chatTitle = chat[@"title"];
	vc.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:vc animated:YES];
}

@end
