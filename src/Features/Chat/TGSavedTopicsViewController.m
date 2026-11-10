//
// TGSavedTopicsViewController.m - the Saved Messages topics list.
//
// TDLib answers loadSavedMessagesTopics with an ok and topic rows ride
// updateSavedMessagesTopic one per touched row; the client keeps them, this
// screen reads that array. A row's id is a message thread id, so a tap
// opens the Saved chat at the topic the same way forum topics open.
#import "TGSavedTopicsViewController.h"
#import "TGAlertSheet.h"
#import "TGChatViewController.h"
#import "TGMessageStore.h"
#import "TGMessageStore.h"
#import "TGEmptyView.h"
#import "TGDateFormat.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGLocalization.h"
#import "TGPeerRowCell.h"
#import "TGRows.h"

static NSString *TGSavedTopicDateText(NSNumber *stamp) {
	if (![stamp isKindOfClass:NSNumber.class] || ![stamp longLongValue])
		return @"";
	char buf[TGDateFormatBufferSize + 1] = {0};
	size_t len = TGChatDateFormat((time_t)[stamp doubleValue],
			(time_t)[[NSDate date] timeIntervalSince1970], buf,
			TGDateFormatBufferSize);
	return len ? [[NSString alloc] initWithBytes:buf length:len
									   encoding:NSUTF8StringEncoding] : @"";
}

@interface TGSavedTopicsViewController ()
@property (nonatomic, strong) TGEmptyView *emptyView;
@property (nonatomic, assign) BOOL loaded;
- (void)updateEmptyView;
@end

@implementation TGSavedTopicsViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
	[super viewDidLoad];


	self.title = @"Saved Messages";
	self.tableView.rowHeight = TGMetricTopicRow;
	[self applyTheme];

	UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
	[refresh addTarget:self action:@selector(reloadRows)
	  forControlEvents:UIControlEventValueChanged];
	self.refreshControl = refresh;

	// A topic's lot holds in the row, and rows are not controls: the hold
	// reaches what a tap cannot.
	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(topicHeld:)];
	hold.minimumPressDuration = 0.55;
	[self.tableView addGestureRecognizer:hold];

	// Topic rows stream from TDLib through the update the client keeps;
	// loading once is what starts the stream, an update is what continues it.
	[[TGMessageStore shared] loadSavedMessagesTopics];

	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(topicsChanged:)
				name:TGSavedTopicsChangedNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserverForName:
			TGThemeChangedNotification object:nil
			queue:[NSOperationQueue mainQueue]
		   usingBlock:^(NSNotification *note){
		__weak typeof(self) weakSelf = self;
		[weakSelf applyTheme];
		weakSelf.emptyView = nil;
		weakSelf.tableView.backgroundView = nil;
		[weakSelf updateEmptyView];
		[weakSelf.tableView reloadData];
	}];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)topicsChanged:(NSNotification *)note {
	self.loaded = YES;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(reloadRows) object:nil];
	[self performSelector:@selector(reloadRows) withObject:nil afterDelay:0.3];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	[[TGMessageStore shared] loadSavedMessagesTopics];
	[self reloadRows];
	// TDLib answers through updates, not a completion, so an account with no
	// topics is only known to be empty after the first stream had a moment.
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
		TGSavedTopicsViewController *me = weakSelf;
		if (!me || me.topics.count)
			return;
		me.loaded = YES;
		[me updateEmptyView];
	});
}

- (void)reloadRows {
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		if (weakSelf.topics.count)
			weakSelf.loaded = YES;
		[weakSelf.refreshControl endRefreshing];
		[weakSelf updateEmptyView];
		[weakSelf rebuildSections];
		[weakSelf.tableView reloadData];
	});
}

- (void)rebuildSections {
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:self.topics.count];
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *topic in self.topics){
		NSMutableDictionary *row = [self topicRow:topic];
		int64_t topicId = [topic[@"id"] longLongValue];
		row[TGRowTap] = ^{ [weakSelf openTopicWithId:topicId
				title:topic[@"title"] ?: @"Saved"]; };
		[rows addObject:row];
	}
	self.sections = @[TGSection(nil, nil, rows)];
}

- (void)openTopicWithId:(int64_t)topicId title:(NSString *)title {
	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = [TGMessageStore shared].savedMessagesChatId;
	vc.threadId = topicId;
	vc.chatTitle = title ?: @"Saved";
	vc.isGroup = NO;
	[self.navigationController pushViewController:vc animated:YES];
}

- (void)updateEmptyView {
	if (!self.loaded || self.topics.count) {
		self.tableView.backgroundView = nil;
		self.emptyView = nil;
		return;
	}
	if (!self.emptyView) {
		self.emptyView = [TGEmptyView emptyViewWithFrame:self.tableView.bounds
				image:[TGIcons emptySearchIllustration]
				title:@"No topics here yet"
				subtitle:nil
				buttonTitle:nil
				target:nil
				action:nil];
	}
	self.tableView.backgroundView = self.emptyView;
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	self.tableView.backgroundColor = [theme listBackgroundColour];
	self.tableView.separatorColor = [theme separatorColour];
	[theme styleNavigationBar:self.navigationController.navigationBar];
}

- (NSArray *)topics {
	return [TGMessageStore shared].savedTopics;
}

/// The hold lands wherever the finger is, so the row is found from the
/// point; a miss does nothing.
- (void)topicHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	CGPoint where = [hold locationInView:self.tableView];
	NSIndexPath *path = [self.tableView indexPathForRowAtPoint:where];
	if (!path || path.row >= (NSInteger)self.topics.count)
		return;

	NSDictionary *t = self.topics[path.row];
	int64_t topicId = [t[@"id"] longLongValue];
	NSString *name = t[@"title"] ?: @"";
	if (!topicId)
		return;

	BOOL pinned = [t[@"pinned"] boolValue];
	NSMutableArray *items = [@[pinned ? @"Unpin" : @"Pin", @"Jump to Date",
							   @"Tags for Messages", @"Unpin All Messages"] mutableCopy];
	[items addObjectsFromArray:@[@"Clear Before Today", @"Clear Before Week",
								 @"Clear Before Month", @"Clear All"]];

	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:items
						title:name
			 destructiveIndex:(NSInteger)[items indexOfObject:@"Clear All"]
					   inView:self.view
					 onChoice:^(NSInteger index){
		NSString *what = items[(NSUInteger)index];
		if ([what isEqualToString:@"Pin"] || [what isEqualToString:@"Unpin"]){
			[[TGMessageStore shared] toggleSavedTopicPinned:topicId pinned:!pinned];
			[weakSelf reloadRows];
			return;
		}
		if ([what isEqualToString:@"Jump to Date"]){
			[weakSelf jumpToDateInTopic:topicId named:name];
			return;
		}
		if ([what isEqualToString:@"Tags for Messages"]){
			[weakSelf showTagsOfTopic:topicId named:name];
			return;
		}
		if ([what isEqualToString:@"Unpin All Messages"]){
			// One request takes the whole list down at once; toggling each
			// row would leave a half-pinned list if the screen closed.
			[TGAlertSheet showConfirm:nil
								title:@"Unpin All Messages"
							   action:@"Unpin"
						  destructive:NO
							   inView:weakSelf.view
							onConfirm:^{
				[[TGMessageStore shared] setPinnedSavedTopics:@[]];
				[weakSelf reloadRows];
			}];
			return;
		}
		// Clearing "before when" is a whole date range - days ago - and
		// every deletion keeps what came after it.
		if ([what isEqualToString:@"Clear All"]){
			[TGAlertSheet showConfirm:nil
								title:@"Clear All"
							   action:@"Clear"
						  destructive:YES
							   inView:weakSelf.view
							onConfirm:^{
				[[TGMessageStore shared] deleteSavedTopicHistory:topicId];
				[weakSelf reloadRows];
			}];
			return;
		}
		[TGAlertSheet showConfirm:nil
							title:@"Clear"
						   action:what
					  destructive:YES
						   inView:weakSelf.view
						onConfirm:^{
			NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
			// From the start of the boundary day: "before today" keeps today.
			NSInteger days = [what isEqualToString:@"Clear Before Today"] ? 1
					: ([what isEqualToString:@"Clear Before Week"] ? 7 : 30);
			[[TGMessageStore shared] clearSavedTopicMessagesBefore:topicId
													minDate:(NSInteger)(now - days * 86400)
													maxDate:(NSInteger)now];
			[weakSelf reloadRows];
		}];
	}];
}

/// The topic's own jump: getSavedMessagesTopicMessageByDate answers the last
/// message on or before a day, which is what the chat's date picker looks up
/// for an ordinary chat.
- (void)jumpToDateInTopic:(int64_t)topicId named:(NSString *)name {
	NSArray *days = @[@"Today", @"A Week Ago", @"A Month Ago", @"A Year Ago"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:days
						title:(name.length ? name : @"Topic")
					  message:nil
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		NSInteger ago = index == 0 ? 0 : (index == 1 ? 7 : (index == 2 ? 30 : 365));
		NSInteger when = (NSInteger)[[NSDate date] timeIntervalSince1970]
				- ago * 86400;
		[[TGMessageStore shared] savedTopicMessageAtDate:topicId
											 date:when
									   completion:^(NSDictionary *message){
			TGSavedTopicsViewController *me = weakSelf;
			if (!me)
				return;
			int64_t messageId = [message[@"id"] longLongValue];
			if (!messageId){
				[TGAlertSheet showMessage:@"An error occurred."
									  title:(name.length ? name : @"Topic")
									 inView:me.view];
				return;
			}
			TGChatViewController *vc = [[TGChatViewController alloc] init];
			vc.chatId = [TGMessageStore shared].savedMessagesChatId;
			vc.threadId = topicId;
			vc.chatTitle = name.length ? name : @"Saved";
			vc.isGroup = NO;
			vc.initialMessageId = messageId;
			[me.navigationController pushViewController:vc animated:YES];
		}];
	}];
}

/// A topic's tags: the emoji is the tag and the label is what this account
/// wrote over it. setSavedMessagesTagLabel is how a label is changed, and it
/// is the only writable half.
- (void)showTagsOfTopic:(int64_t)topicId named:(NSString *)name {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] savedTopicsTags:topicId completion:^(NSArray *tags){
		TGSavedTopicsViewController *me = weakSelf;
		if (!me)
			return;
		NSArray *list = [tags isKindOfClass:NSArray.class] ? tags : @[];
		if (!list.count){
			[TGAlertSheet showMessage:@"None"
								  title:(name.length ? name : @"Topic")
								 inView:me.view];
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *tag in list){
			NSString *label = [me labelForSavedTag:tag];
			[rows addObject:[NSString stringWithFormat:@"%@  ×%@", label,
							 tag[@"count"] ?: @(0)]];
		}
		[TGAlertSheet showChoices:rows
							title:(name.length ? name : @"Topic")
						  message:nil
				   destructiveIndex:-1
						   inView:me.view
						 onChoice:^(NSInteger index){
			NSDictionary *tag = list[(NSUInteger)index];
			[TGAlertSheet showInput:@"Tag"
							message:nil
						placeholder:[me labelForSavedTag:tag]
							   text:tag[@"label"]
							 action:@"Save"
							 inView:me.view
						 onSubmit:^(NSString *typed){
				[[TGMessageStore shared] labelSavedTag:tag label:typed];
			}];
		}];
	}];
}

- (NSString *)labelForSavedTag:(NSDictionary *)tag {
	NSString *label = tag[@"label"];
	if (label.length)
		return label;
	NSString *emoji = tag[@"tag"][@"emoji"];
	return emoji.length ? emoji : @"Tag";
}

#pragma mark - the rows

- (NSMutableDictionary *)topicRow:(NSDictionary *)topic {
	NSMutableDictionary *row = TGPeerRow(@([topic[@"id"] longLongValue]),
			topic[@"title"] ?: TGLocalized(@"Saved Messages"),
			[topic[@"text"] length] ? topic[@"text"]
					: TGLocalized(@"No messages here yet..."), nil);
	row[TGRowHeight] = @(TGMetricTopicRow);
	row[TGRowAvatarImage] = [TGIcons savedMessagesAvatarOfSide:TGMetricListAvatar];
	row[TGRowPin] = @([topic[@"pinned"] boolValue]);
	NSString *date = TGSavedTopicDateText(topic[@"date"]);
	if (date.length)
		row[TGRowAccessory] = date;
	return row;
}

@end
