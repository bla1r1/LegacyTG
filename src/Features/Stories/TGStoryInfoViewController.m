#import "TGStoryInfoViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGStoryText.h"
#import "TGRows.h"
#import "TGStoryStore.h"
#import "TGMessageStore.h"

/// The mappings live in TGStoryText.h so the host tests exercise the same
/// function the screen calls.

@interface TGStoryInfoViewController ()
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int32_t storyId;
@property (nonatomic, strong) NSDictionary *story;
@property (nonatomic, assign) TGStoryInfoMode mode;
@property (nonatomic, strong) NSMutableArray *rows;
@property (nonatomic, assign) BOOL reportStarted;
/// The sheet has no navigation bar, so closing is this control over the table.
@property (nonatomic, strong) UIButton *closeButton;
@end

@implementation TGStoryInfoViewController

- (instancetype)initWithChatId:(int64_t)chatId
					   storyId:(int32_t)storyId
						 story:(NSDictionary *)story
						  mode:(TGStoryInfoMode)mode {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self){
		_chatId = chatId;
		_storyId = storyId;
		_story = [story copy] ?: @{};
		_mode = mode;
		_rows = [NSMutableArray array];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.mode == TGStoryInfoModeReport ? @"Report Story" : @"Story";
	[[TGTheme shared] styleGroupedTable:self.tableView];

	self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[self.closeButton setImage:[TGIcons glyphNamed:@"close"
			colour:[[TGTheme shared] primaryTextColour]
			side:TGMetricStoryCloseSide - TGMetricPadSmall]
			forState:UIControlStateNormal];
	[self.closeButton addTarget:self action:@selector(doneTapped)
			forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:self.closeButton];
	[self buildRows];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (self.mode == TGStoryInfoModeReport && !self.reportStarted){
		self.reportStarted = YES;
		[self startReport];
	}
}

/// The one place the sheet's sections are built. Rows are shared-model rows;
/// interactions, forwards and statistics append to `rows` and call this again,
/// so a reload never reads a half-built list.
- (void)publishRows {
	self.sections = @[TGSection(
			self.mode == TGStoryInfoModeReport ? TGLocalized(@"Report")
											   : TGLocalized(@"Story"),
			nil, self.rows)];
	[self reloadRows];
}

- (void)buildRows {
	NSMutableArray *rows = [TGStoryInfoRowsModel(self.story,
			self.mode == TGStoryInfoModeReport) mutableCopy];
	__weak typeof(self) weakSelf = self;
	NSInteger firstAction = rows.count - 4;
	if (self.mode == TGStoryInfoModeInfo && firstAction >= 0){
		rows[(NSUInteger)firstAction][TGRowTap] =
				^{ [weakSelf loadInteractions]; };
		rows[(NSUInteger)firstAction + 1][TGRowTap] =
				^{ [weakSelf loadPublicForwards]; };
		rows[(NSUInteger)firstAction + 2][TGRowTap] =
				^{ [weakSelf loadStatistics]; };
		rows[(NSUInteger)firstAction + 3][TGRowTap] =
				^{ [weakSelf startReport]; };
	}
	self.rows = rows;
	[self publishRows];
}

- (void)loadInteractions {
	int64_t ownChat = [[TGMessageStore shared]savedMessagesChatId];
	__weak typeof(self) weakSelf = self;
	void (^done)(NSDictionary *, NSString *) = ^(NSDictionary *page, NSString *error){
		TGStoryInfoViewController *me = weakSelf;
		if (!me)
			return;
		if (!page){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Interactions" inView:me.view];
			return;
		}
		[me appendPage:page];
	};
	if (self.chatId == ownChat)
		[[TGStoryStore shared]storyInteractionsForStory:self.storyId
											   query:@""
										onlyContacts:NO
									   preferForwards:NO
								   preferWithReaction:NO
											   offset:@""
												limit:20
										  completion:done];
	else
		[[TGStoryStore shared]chatStoryInteractionsForStory:self.storyId
												fromChat:self.chatId
										   reactionEmoji:nil
										  preferForwards:NO
												  offset:@""
												   limit:20
											  completion:done];
}

- (void)appendPage:(NSDictionary *)page {
	NSArray *interactions = page[@"interactions"];
	NSMutableArray *added = [NSMutableArray array];
	[added addObject:TGStoryInfoRowModel(TGLocalized(@"Interactions"),
			[NSString stringWithFormat:@"%@ total, %@ forwards, %@ reactions",
					page[@"totalCount"] ?: @(0),
					page[@"totalForwardCount"] ?: @(0),
					page[@"totalReactionCount"] ?: @(0)], nil)];
	for (NSDictionary *row in interactions){
		NSString *kind = TGStoryInteractionNoun(row[@"kind"]);
		NSString *reaction = row[@"reaction"] ?: @"";
		NSString *detail = [NSString stringWithFormat:@"%@ · %@%@",
				TGStoryDateText(row[@"date"]), kind,
				reaction.length ? [@" · " stringByAppendingString:reaction] : @""];
		[added addObject:TGStoryInfoRowModel(row[@"name"] ?: TGLocalized(@"Someone"),
				detail, nil)];
	}
	if (!interactions.count)
		[added addObject:TGStoryInfoRowModel(TGLocalized(@"No views"), nil, nil)];
	[self.rows addObjectsFromArray:added];
	[self publishRows];
}

- (void)loadPublicForwards {
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]storyPublicForwards:self.storyId
								  fromChat:self.chatId
									offset:@""
									 limit:20
								completion:^(NSDictionary *page, NSString *error){
		TGStoryInfoViewController *me = weakSelf;
		if (!me)
			return;
		if (!page){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Forwarded Messages" inView:me.view];
			return;
		}
		NSMutableArray *added = [NSMutableArray array];
		[added addObject:TGStoryInfoRowModel(TGLocalized(@"Forwarded Messages"),
				[NSString stringWithFormat:@"%@ total",
						page[@"totalCount"] ?: @(0)], nil)];
		for (NSDictionary *row in page[@"forwards"]){
			NSString *title = row[@"title"];
			if (!title.length)
				title = [row[@"kind"] isEqualToString:@"story"]
						? TGLocalized(@"Story") : TGLocalized(@"Forwarded Messages");
			NSString *detail = row[@"text"];
			if (!detail.length)
				detail = TGStoryDateText(row[@"date"]);
			[added addObject:TGStoryInfoRowModel(title, detail, nil)];
		}
		[me.rows addObjectsFromArray:added];
		[me publishRows];
	}];
}

- (void)loadStatistics {
	__weak typeof(self) weakSelf = self;
	CGFloat white = 0;
	[[[TGTheme shared] listBackgroundColour] getWhite:&white alpha:NULL];
	[[TGStoryStore shared]storyStatistics:self.storyId
							  fromChat:self.chatId
								isDark:white < 0.5
							completion:^(NSDictionary *statistics, NSString *error){
		TGStoryInfoViewController *me = weakSelf;
		if (!me)
			return;
		if (!statistics){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Story Statistics" inView:me.view];
			return;
		}
		NSMutableArray *added = [NSMutableArray array];
		NSDictionary *interaction = statistics[@"interaction"] ?: @{};
		NSDictionary *reaction = statistics[@"reaction"] ?: @{};
		[added addObject:TGStoryInfoRowModel(TGLocalized(@"Interactions"),
				interaction[@"kind"] ?: TGLocalized(@"none"), nil)];
		for (NSString *line in interaction[@"lines"] ?: @[])
			[added addObject:TGStoryInfoRowModel(line, nil, nil)];
		[added addObject:TGStoryInfoRowModel(TGLocalized(@"Reactions"),
				reaction[@"kind"] ?: TGLocalized(@"none"), nil)];
		for (NSString *line in reaction[@"lines"] ?: @[])
			[added addObject:TGStoryInfoRowModel(line, nil, nil)];
		[me.rows addObjectsFromArray:added];
		[me publishRows];
	}];
}

#pragma mark - reporting

- (void)startReport {
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]reportStory:self.storyId
						  fromChat:self.chatId
						  optionId:@""
							  text:@""
						completion:^(NSDictionary *result, NSString *error){
		[weakSelf handleReport:result error:error];
	}];
}

- (void)handleReport:(NSDictionary *)result error:(NSString *)error {
	if (!result){
		[TGAlertSheet showMessage:error ?: @"An error occurred."
							title:@"Report Story" inView:self.view];
		return;
	}
	NSString *state = result[@"state"];
	if ([state isEqualToString:@"ok"]){
		[TGAlertSheet showMessage:@"Telegram moderators will review your report. Thank you!"
							title:@"Report Story" inView:self.view];
		return;
	}
	if ([state isEqualToString:@"options"]){
		NSArray *options = result[@"options"] ?: @[];
		NSMutableArray *titles = [NSMutableArray array];
		for (NSDictionary *option in options)
			[titles addObject:option[@"text"] ?: @"Report"];
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:titles title:result[@"title"] ?: @"Report Story"
					destructiveIndex:-1 inView:self.view onChoice:^(NSInteger choice){
			TGStoryInfoViewController *me = weakSelf;
			if (!me || choice < 0 || choice >= (NSInteger)options.count)
				return;
			NSDictionary *option = options[choice];
			[[TGStoryStore shared]reportStory:me.storyId
								  fromChat:me.chatId
								  optionId:option[@"id"] ?: @""
									  text:@""
								completion:^(NSDictionary *next, NSString *why){
				[me handleReport:next error:why];
			}];
		}];
		return;
	}
	if ([state isEqualToString:@"text"]){
		NSString *optionId = result[@"optionId"] ?: @"";
		BOOL optional = [result[@"optional"] boolValue];
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showInput:@"Report Story"
						message:optional ? nil : @"Additional details..."
					placeholder:@"Additional details..."
						   text:nil
						 action:@"Send"
						 inView:self.view
					   onSubmit:^(NSString *text){
			TGStoryInfoViewController *me = weakSelf;
			if (!me)
				return;
			[[TGStoryStore shared]reportStory:me.storyId
								  fromChat:me.chatId
								  optionId:optionId
									  text:text
								completion:^(NSDictionary *next, NSString *why){
				[me handleReport:next error:why];
			}];
		}];
		return;
	}
	[TGAlertSheet showMessage:@"An error occurred." title:@"Report Story" inView:self.view];
}

#pragma mark - table

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	CGFloat side = TGMetricStoryCloseSide;
	self.closeButton.frame = CGRectMake(self.view.bounds.size.width - side - TGMetricPadMedium,
			TGMetricPadMedium, side, side);
}

- (void)doneTapped {
	// Added as the viewer's overlay panel: take it off, leave the story.
	if (self.overlayPanel && self.parentViewController){
		[self willMoveToParentViewController:nil];
		[self.view removeFromSuperview];
		[self removeFromParentViewController];
		return;
	}
	if (self.presentingViewController)
		[self dismissViewControllerAnimated:YES completion:nil];
	else
		[self.navigationController popViewControllerAnimated:YES];
}

@end
