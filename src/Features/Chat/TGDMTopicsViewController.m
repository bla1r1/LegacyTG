#import "TGDMTopicsViewController.h"
#import "TGLocalization.h"
#import "TGAlertSheet.h"
#import "TGClient.h"
#import "TGDMTopicViewController.h"
#import "TGRows.h"

@interface TGDMTopicsViewController ()
@property (nonatomic, strong) NSArray *topics;
@property (nonatomic, assign) BOOL loaded;
@end

@implementation TGDMTopicsViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.chatTitle.length
			? [NSString stringWithFormat:@"%@ · %@", self.chatTitle,
					TGLocalized(@"Direct")]
			: TGLocalized(@"Direct Messages");
	self.topics = [[TGClient shared] directMessagesChatTopicsForChat:self.chatId]
			?: @[];
	[self rebuildSections];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:TGLocalized(@"More") style:UIBarButtonItemStylePlain
				   target:self action:@selector(loadMoreTapped)];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(topicsChanged:)
				name:TGDirectMessagesTopicsChangedNotification object:nil];
	[self loadMore];
	if (self.chatId != 0) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] chatProfile:self.chatId completion:^(NSDictionary *info){
			int64_t dmId = [info[@"directMessagesChatId"] longLongValue];
			if (dmId != 0 && dmId != weakSelf.chatId) {
				weakSelf.chatId = dmId;
				weakSelf.topics = [[TGClient shared] directMessagesChatTopicsForChat:dmId] ?: @[];
				[weakSelf rebuildSections];
				[weakSelf loadMore];
			}
		}];
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.topics = [[TGClient shared] directMessagesChatTopicsForChat:self.chatId]
			?: @[];
	[self rebuildSections];
}

- (void)topicsChanged:(NSNotification *)note {
	NSNumber *chatId = note.userInfo[@"chatId"];
	if (chatId && [chatId longLongValue] != self.chatId)
		return;
	self.topics = [[TGClient shared] directMessagesChatTopicsForChat:self.chatId]
			?: @[];
	[self rebuildSections];
}

- (void)loadMore {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] loadDirectMessagesChatTopicsInChat:self.chatId limit:20
											   completion:^(BOOL ok, NSString *error){
		TGDMTopicsViewController *me = weakSelf;
		if (!me)
			return;
		me.loaded = YES;
		me.topics = [[TGClient shared] directMessagesChatTopicsForChat:me.chatId]
				?: @[];
		[me rebuildSections];
		if (!ok && error.length)
			[TGAlertSheet showMessage:error title:TGLocalized(@"Direct Messages")
							   inView:me.view];
	}];
}

- (void)loadMoreTapped {
	[self loadMore];
}

#pragma mark - rows

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSArray *models = TGDMTopicsRowModels(self.topics);
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:models.count];
	for (NSUInteger index = 0; index < models.count; index++){
		NSDictionary *model = models[index];
		NSDictionary *topic = self.topics[index];
		[rows addObject:TGSubtitleOpenRow(model[@"title"], model[@"detail"], ^{
			[weakSelf openTopic:topic];
		})];
	}
	self.sections = @[TGSection(self.topics.count ? TGLocalized(@"Topics") : nil,
			TGDMTopicsFooter(self.loaded, self.topics.count), rows)];
	[self reloadRows];
}

- (void)openTopic:(NSDictionary *)topic {
	TGDMTopicViewController *detail = [[TGDMTopicViewController alloc] init];
	detail.chatId = self.chatId;
	detail.topicId = [topic[@"topicId"] longLongValue];
	detail.topic = topic;
	detail.chatTitle = self.chatTitle;
	detail.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:detail animated:YES];
}

@end
