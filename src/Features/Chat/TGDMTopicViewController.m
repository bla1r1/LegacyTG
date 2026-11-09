#import "TGDMTopicViewController.h"
#import "TGLocalization.h"
#import "TGAlertSheet.h"
#import "TGClient.h"
#import "TGRows.h"

@interface TGDMTopicViewController ()
@property (nonatomic, strong) NSArray *history;
@property (nonatomic, strong) NSArray *actionTitles;
@end

@implementation TGDMTopicViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	NSString *name = self.topic[@"senderName"];
	self.title = name.length ? name : TGLocalized(@"Topic");
	self.history = @[];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:TGLocalized(@"Reply") style:UIBarButtonItemStylePlain
				   target:self action:@selector(replyTapped)];
	[self rebuildSections];
	[self loadTopic];
	[self loadHistory];
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSDictionary *topic = self.topic ?: @{};
	self.actionTitles = TGDMTopicActionTitles([topic[@"isMarkedUnread"] boolValue]);

	NSMutableArray *infoRows = [NSMutableArray array];
	for (NSArray *pair in TGDMTopicInfoPairs(topic))
		[infoRows addObject:TGSubtitleRow(pair[0], pair[1], nil)];

	NSMutableArray *actionRows = [NSMutableArray array];
	for (NSString *title in self.actionTitles){
		void (^tap)(void) = ^{ [weakSelf performAction:title]; };
		if ([title hasPrefix:TGLocalized(@"Delete")])
			[actionRows addObject:TGRedRow(title, tap)];
		else
			[actionRows addObject:TGActionRow(title, tap)];
	}

	NSMutableArray *historyRows = [NSMutableArray array];
	for (NSDictionary *message in self.history)
		[historyRows addObject:TGSubtitleRow(TGDMTopicMessageTitle(message),
				TGDMTopicMessageDetail(message), nil)];

	self.sections = @[
		TGSection(TGLocalized(@"Topic"), nil, infoRows),
		TGSection(TGLocalized(@"Actions"), nil, actionRows),
		TGSection(self.history.count ? TGLocalized(@"Messages") : nil, nil,
				historyRows),
	];
	[self reloadRows];
}

- (void)replyTapped {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Direct Messages"
					message:nil
				placeholder:@"Message"
					   text:nil
					 action:@"Send Message"
					 inView:self.view
				   onSubmit:^(NSString *text){
		[weakSelf sendDirectMessage:text];
	}];
}

- (void)sendDirectMessage:(NSString *)text {
	if (!text.length)
		return;
	NSDictionary *topicIdObj = @{
		@"@type" : @"messageTopicDirectMessages",
		@"direct_messages_chat_topic_id" : @(self.topicId)
	};
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] request:@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(self.chatId),
		@"topic_id" : topicIdObj,
		@"input_message_content" : @{
			@"@type" : @"inputMessageText",
			@"text" : @{
				@"@type" : @"formattedText",
				@"text" : text ?: @""
			}
		}
	} completion:^(NSDictionary *result){
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf loadHistory];
		});
	}];
}

- (void)loadTopic {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] directMessagesChatTopic:self.topicId inChat:self.chatId
									completion:^(NSDictionary *topic, NSString *error){
		TGDMTopicViewController *me = weakSelf;
		if (!me || !topic)
			return;
		me.topic = topic;
		[me rebuildSections];
	}];
}

- (void)loadHistory {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] directMessagesChatTopicHistory:self.topicId
											  inChat:self.chatId
									   fromMessageId:0 offset:0 limit:30
										  completion:^(NSArray *messages, NSString *error){
		TGDMTopicViewController *me = weakSelf;
		if (!me)
			return;
		me.history = messages ?: @[];
		[me rebuildSections];
	}];
}

#pragma mark - actions

- (void)performAction:(NSString *)title {
	if ([title isEqualToString:TGLocalized(@"Send Message")]){
		[self replyTapped];
		return;
	}
	if ([title isEqualToString:TGLocalized(@"Mark as Unread")] ||
		[title isEqualToString:TGLocalized(@"Mark as Read")]){
		BOOL mark = [title isEqualToString:TGLocalized(@"Mark as Unread")];
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] setDirectMessagesChatTopic:self.topicId
											  inChat:self.chatId
									markedAsUnread:mark
										  completion:^(BOOL ok, NSString *error){
			TGDMTopicViewController *me = weakSelf;
			if (!ok){
				[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
									title:TGLocalized(@"Topics") inView:me.view];
				return;
			}
			NSMutableDictionary *patched = [me.topic mutableCopy];
			patched[@"isMarkedUnread"] = @(mark);
			me.topic = patched;
			[me rebuildSections];
		}];
		return;
	}
	if ([title isEqualToString:TGLocalized(@"Jump to Date")]){
		[self jumpToDate];
		return;
	}
	if ([title isEqualToString:TGLocalized(@"Read All Reactions")]){
		[self runSimple:@"readAllDirectMessagesChatTopicReactions"
				  title:TGLocalized(@"Read All Reactions")];
		return;
	}
	if ([title isEqualToString:TGLocalized(@"Unpin All Messages")]){
		[self runSimple:@"unpinAllDirectMessagesChatTopicMessages"
				  title:TGLocalized(@"Unpin All Messages")];
		return;
	}
	if ([title isEqualToString:TGLocalized(@"Delete Messages")]){
		[self deleteByDate];
		return;
	}
	if ([title isEqualToString:TGLocalized(@"Delete All Messages")]){
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showConfirm:nil
							title:TGLocalized(@"Delete All Messages")
						   action:TGLocalized(@"Delete")
					  destructive:YES inView:self.view onConfirm:^{
			[[TGClient shared] deleteDirectMessagesChatTopicHistory:weakSelf.topicId
														  inChat:weakSelf.chatId
													  completion:^(BOOL ok,
																   NSString *error){
				[weakSelf finish:ok error:error
						title:TGLocalized(@"Delete All Messages")];
			}];
		}];
	}
}

/// The two calls with no options of their own share one path, so a typing
/// mistake in a selector cannot send the other one's request.
- (void)runSimple:(NSString *)selector title:(NSString *)title {
	__weak typeof(self) weakSelf = self;
	if ([selector isEqualToString:@"readAllDirectMessagesChatTopicReactions"]){
		[[TGClient shared] readAllDirectMessagesChatTopicReactions:self.topicId
														  inChat:self.chatId
													  completion:^(BOOL ok,
																   NSString *error){
			[weakSelf finish:ok error:error title:title];
		}];
		return;
	}
	[[TGClient shared] unpinAllDirectMessagesChatTopicMessages:self.topicId
													   inChat:self.chatId
												   completion:^(BOOL ok,
																NSString *error){
		[weakSelf finish:ok error:error title:title];
	}];
}

- (void)finish:(BOOL)ok error:(NSString *)error title:(NSString *)title {
	[TGAlertSheet showMessage:(ok ? TGLocalized(@"Done")
			: (error ?: TGLocalized(@"An error occurred.")))
						title:title inView:self.view];
	[self loadTopic];
	[self loadHistory];
}

- (NSArray *)dateChoices {
	return @[@"Today", @"Yesterday", @"Last 7 Days", @"Last 30 Days"];
}

- (NSTimeInterval)startOfDay:(NSDate *)date {
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSUInteger units = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
	NSDateComponents *parts = [calendar components:units fromDate:date];
	return [[calendar dateFromComponents:parts] timeIntervalSince1970];
}

- (void)jumpToDate {
	__weak typeof(self) weakSelf = self;
	NSArray *choices = [self dateChoices];
	[TGAlertSheet showChoices:choices title:@"Jump to Date"
			destructiveIndex:-1 inView:self.view onChoice:^(NSInteger index){
		NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
		NSTimeInterval day = [weakSelf startOfDay:[NSDate date]];
		NSInteger date = (NSInteger)day;
		if (index == 1)
			date = (NSInteger)(day - 86400);
		else if (index == 2)
			date = (NSInteger)(now - 7 * 86400);
		else if (index == 3)
			date = (NSInteger)(now - 30 * 86400);
		[[TGClient shared] directMessagesChatTopicMessageByDate:weakSelf.topicId
													   inChat:weakSelf.chatId
														 date:date
												   completion:^(NSDictionary *message,
																NSString *error){
			TGDMTopicViewController *me = weakSelf;
			if (!me)
				return;
			if (error.length){
				[TGAlertSheet showMessage:error title:@"Jump to Date"
								   inView:me.view];
				return;
			}
			if (!message){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Jump to Date" inView:me.view];
				return;
			}
			[TGAlertSheet showMessage:TGDMTopicMessageTitle(message)
								title:TGLocalized(@"Jump to Date") inView:me.view];
		}];
	}];
}

- (void)deleteByDate {
	__weak typeof(self) weakSelf = self;
	NSArray *choices = @[@"Last Hour", @"Last 24 Hours", @"Last 7 Days",
						 @"All Time"];
	[TGAlertSheet showChoices:choices title:@"Delete Messages"
			destructiveIndex:3 inView:self.view onChoice:^(NSInteger index){
		NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
		NSTimeInterval minDate = 0;
		if (index == 0)
			minDate = now - 3600;
		else if (index == 1)
			minDate = now - 86400;
		else if (index == 2)
			minDate = now - 7 * 86400;
		[TGAlertSheet showConfirm:nil
							title:@"Delete Messages" action:@"Delete"
					  destructive:YES inView:weakSelf.view onConfirm:^{
			[[TGClient shared] deleteDirectMessagesChatTopicMessages:weakSelf.topicId
															inChat:weakSelf.chatId
														   minDate:(NSInteger)minDate
														   maxDate:(NSInteger)now
														completion:^(BOOL ok,
																	 NSString *error){
				[weakSelf finish:ok error:error title:@"Delete Messages"];
			}];
		}];
	}];
}

@end
