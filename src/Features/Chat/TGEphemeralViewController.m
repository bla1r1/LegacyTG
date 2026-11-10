#import "TGEphemeralViewController.h"
#import "TGLocalization.h"
#import "TGAlertSheet.h"
#import "TGMessageStore.h"
#import "TGSendStore.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGRows.h"

@interface TGEphemeralViewController ()
@property (nonatomic, strong) UITextView *composer;
@property (nonatomic, strong) UILabel *placeholder;
@property (nonatomic, assign) int64_t receiverUserId;
@property (nonatomic, assign) NSInteger replyId;
@property (nonatomic, assign) NSInteger lastEphemeralId;
@property (nonatomic, assign) int64_t lastMessageId;
@property (nonatomic, copy)   NSString *resultText;
@property (nonatomic, copy)   NSString *lastSentText;
@end

@implementation TGEphemeralViewController

- (id)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Ephemeral");
	self.receiverUserId = self.chatId > 0 ? self.chatId : 0;
	self.replyId = 0;
	self.lastEphemeralId = 0;
	self.lastMessageId = 0;
	self.resultText = TGLocalized(@"None");
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:TGLocalized(@"Receiver") style:UIBarButtonItemStylePlain
				   target:self action:@selector(changeReceiver)];

	CGFloat height = TGMetricRow * 3;
	UIView *header = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, self.tableView.bounds.size.width,
					   height + TGMetricPadLarge)];
	header.backgroundColor = [UIColor clearColor];
	self.composer = [[UITextView alloc] initWithFrame:
			CGRectMake(TGMetricPadMedium, TGMetricPad,
					   header.bounds.size.width - TGDoubled(TGMetricPadMedium),
					   height)];
	self.composer.font = TGFontBody();
	self.composer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.composer.layer.cornerRadius = TGMetricCornerControl;
	self.composer.clipsToBounds = YES;
	[header addSubview:self.composer];

	self.placeholder = [[UILabel alloc] initWithFrame:
			CGRectMake(TGMetricPadLarge, TGMetricPad,
					   self.composer.bounds.size.width - TGDoubled(TGMetricPadLarge),
					   TGMetricLineBody)];
	self.placeholder.text = TGLocalized(@"Message");
	self.placeholder.font = TGFontBody();
	self.placeholder.backgroundColor = [UIColor clearColor];
	self.placeholder.userInteractionEnabled = NO;
	[header addSubview:self.placeholder];
	self.tableView.tableHeaderView = header;
	[self rebuildSections];
	[self applyTheme];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:TGThemeChangedNotification object:nil];
}

- (void)applyTheme {
	[super applyTheme];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
	self.tableView.backgroundColor = [[TGTheme shared] groupedBackgroundColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.composer.backgroundColor = [[TGTheme shared] cardBackgroundColour];
	self.composer.textColor = [[TGTheme shared] primaryTextColour];
	self.placeholder.textColor = [[TGTheme shared] placeholderColour];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

/// The text view has no placeholder support on this OS, so an empty field
/// keeps a label over it until the first character arrives.
- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(textChanged:)
				name:UITextViewTextDidChangeNotification object:self.composer];
	[self textChanged:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self
			name:UITextViewTextDidChangeNotification object:self.composer];
}

- (void)textChanged:(NSNotification *)note {
	self.placeholder.hidden = self.composer.text.length > 0;
}

#pragma mark - table

- (void)runAction:(NSUInteger)index {
	switch (index){
		case 0: [self send]; break;
		case 1: [self editLast]; break;
		case 2: [self editCaption]; break;
		case 3: [self deleteLast]; break;
		case 4: [self stripContent]; break;
		case 5:
			self.composer.text = @"";
			[self textChanged:nil];
			break;
	}
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSArray *sectionTitles = TGEphemeralSectionTitles();

	NSMutableArray *target = [NSMutableArray array];
	[target addObject:TGSubtitleRow(TGLocalized(@"Receiver"),
			TGEphemeralReceiverDetail(self.receiverUserId),
			^{ [weakSelf changeReceiver]; })];
	[target addObject:TGSubtitleRow(TGLocalized(@"Reply"),
			TGEphemeralReplyDetail(self.replyId),
			^{ [weakSelf changeReply]; })];

	NSArray *actionTitles = TGEphemeralActionTitles();
	NSMutableArray *actions = [NSMutableArray arrayWithCapacity:actionTitles.count];
	for (NSUInteger index = 0; index < actionTitles.count; index++){
		NSString *title = actionTitles[index];
		void (^tap)(void) = ^{ [weakSelf runAction:index]; };
		[actions addObject:index == 3 ? TGRedRow(title, tap)
				: TGActionRow(title, tap)];
	}

	NSMutableDictionary *result = [TGSubtitleRow(self.resultText ?:
			TGLocalized(@"None"), TGEphemeralResultDetail(self.lastSentText), nil)
			mutableCopy];
	result[TGRowTitleLines] = @0;
	result[TGRowDetailLines] = @2;

	self.sections = @[
		TGSection(sectionTitles[0], nil, target),
		TGSection(sectionTitles[1], nil, actions),
		TGSection(sectionTitles[2], nil, @[result]),
	];
	[self reloadRows];
}

#pragma mark - the calls

- (void)setResult:(NSString *)text {
	self.resultText = text;
	[self rebuildSections];
}

- (void)send {
	NSString *text = self.composer.text;
	if (!text.length){
		[self setResult:TGLocalized(@"An error occurred.")];
		return;
	}
	if (!self.receiverUserId){
		[self setResult:TGLocalized(@"An error occurred.")];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGSendStore shared] sendEphemeralText:text
								  toChat:self.chatId
						  receiverUserId:self.receiverUserId
						 ephemeralReplyId:self.replyId
							  completion:^(NSDictionary *message, NSString *error){
		TGEphemeralViewController *me = weakSelf;
		if (!me)
			return;
		if (error.length || !message){
			[me setResult:(error ?: TGLocalized(@"An error occurred."))];
			return;
		}
		me.lastSentText = text;
		me.lastMessageId = [message[@"id"] longLongValue];
		me.lastEphemeralId = [message[@"ephemeralMessageId"] integerValue];
		if (!me.lastEphemeralId)
			me.lastEphemeralId = (NSInteger)me.lastMessageId;
		[me setResult:[NSString stringWithFormat:
				@"%@ %lld, %ld",
				TGLocalized(@"Sent"), me.lastMessageId,
				(long)me.lastEphemeralId]];
	}];
}

- (void)editLast {
	NSInteger messageId = [self askMessageId:TGLocalized(@"Edit Message")];
	if (!messageId)
		return;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:TGLocalized(@"Edit Message") message:nil
				placeholder:TGLocalized(@"Message") text:self.composer.text
				action:TGLocalized(@"Save")
					 inView:self.view onSubmit:^(NSString *text){
		[[TGMessageStore shared] editEphemeralMessage:messageId text:text
									   receiver:weakSelf.receiverUserId
										 inChat:weakSelf.chatId
									 completion:^(BOOL ok, NSString *error){
			[weakSelf setResult:(ok ? TGLocalized(@"Edited")
									: (error ?: TGLocalized(@"An error occurred.")))];
		}];
	}];
}

- (void)editCaption {
	NSInteger messageId = [self askMessageId:TGLocalized(@"Edit Caption")];
	if (!messageId)
		return;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:TGLocalized(@"Edit Caption") message:nil
				placeholder:TGLocalized(@"Caption") text:nil
				action:TGLocalized(@"Save")
					 inView:self.view onSubmit:^(NSString *caption){
		[[TGMessageStore shared] editEphemeralMessageCaption:messageId caption:caption
											  receiver:weakSelf.receiverUserId
												inChat:weakSelf.chatId
											completion:^(BOOL ok, NSString *error){
			[weakSelf setResult:(ok ? TGLocalized(@"Edited")
									: (error ?: TGLocalized(@"An error occurred.")))];
		}];
	}];
}

- (void)deleteLast {
	NSInteger messageId = [self askMessageId:TGLocalized(@"Delete Message")];
	if (!messageId)
		return;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:TGLocalized(@"Delete Message")
						title:TGLocalized(@"Delete Message")
					   action:TGLocalized(@"Delete")
				  destructive:YES inView:self.view onConfirm:^{
		[[TGMessageStore shared] deleteEphemeralMessage:messageId
										 receiver:weakSelf.receiverUserId
										   inChat:weakSelf.chatId
									   completion:^(BOOL ok, NSString *error){
			[weakSelf setResult:(ok ? TGLocalized(@"Message Deleted")
									: (error ?: TGLocalized(@"An error occurred.")))];
		}];
	}];
}

- (void)stripContent {
	if (!self.lastMessageId){
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showInput:TGLocalized(@"Clear") message:nil
					placeholder:TGLocalized(@"Message") text:nil
					action:TGLocalized(@"Clear")
						 inView:self.view onSubmit:^(NSString *text){
			[weakSelf stripMessageId:(int64_t)[text longLongValue]];
		}];
		return;
	}
	[self stripMessageId:self.lastMessageId];
}

- (void)stripMessageId:(int64_t)messageId {
	if (!messageId){
		[self setResult:TGLocalized(@"An error occurred.")];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] deleteMessageEphemeralContent:messageId inChat:self.chatId
										  completion:^(BOOL ok, NSString *error){
		[weakSelf setResult:(ok ? TGLocalized(@"Message Deleted")
								: (error ?: TGLocalized(@"An error occurred.")))];
	}];
}

/// The id to act on: the ephemeral id from the last send, or the regular
/// message id when Telegram answered with a message that carried no
/// ephemeral id. A screen with neither says to send one rather than asking
/// for a number the user cannot know.
- (NSInteger)askMessageId:(NSString *)title {
	NSInteger value = self.lastEphemeralId ?: (NSInteger)self.lastMessageId;
	if (!value)
		[self setResult:TGLocalized(@"An error occurred.")];
	return value;
}

- (void)changeReceiver {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:TGLocalized(@"Receiver") message:nil
				placeholder:TGLocalized(@"user id")
					   text:(self.receiverUserId
							   ? [NSString stringWithFormat:@"%lld", self.receiverUserId]
							   : nil)
					 action:TGLocalized(@"Set") inView:self.view
				 onSubmit:^(NSString *text){
		weakSelf.receiverUserId = [text longLongValue];
		[weakSelf rebuildSections];
	}];
}

- (void)changeReply {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:TGLocalized(@"Reply") message:nil
				placeholder:TGLocalized(@"ephemeral id")
					   text:(self.replyId ? [NSString stringWithFormat:@"%ld",
							   (long)self.replyId] : nil)
					 action:TGLocalized(@"Set") inView:self.view
				 onSubmit:^(NSString *text){
		weakSelf.replyId = (NSInteger)[text longLongValue];
		[weakSelf rebuildSections];
	}];
}

@end
