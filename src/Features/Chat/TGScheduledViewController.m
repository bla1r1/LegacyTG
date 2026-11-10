//
// TGScheduledViewController - the queue behind a scheduled send. One section
// of rows, each answering with the menu a waiting message has: send it now,
// send it when they are next online, move it, or take it away.
//
// Nothing here asks for a reason: the only thing this screen does is that
// one list, so the words in the rows are the messages themselves.
#import "TGScheduledViewController.h"
#import "TGAlertSheet.h"
#import "TGMessageStore.h"
#import "TGSendStore.h"
#import "TGEmptyView.h"
#import "TGIcons.h"
#import "TGSheet.h"
#import "TGTheme.h"
#import "TGUIFormat.h"
#import "TGStyle.h"
#import "TGRows.h"

@interface TGScheduledViewController ()
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) UIDatePicker *picker;
@property (nonatomic, strong) TGSheet *pickerSheet;
@property (nonatomic, assign) int64_t pickerMessageId;
@end

@implementation TGScheduledViewController

- (void)viewDidLoad {
	[super viewDidLoad];


	self.title = TGLocalized(@"Scheduled Messages");
	self.messages = @[];
	[self applyTheme];
	[self reload];
}

- (void)rebuildSections {
	NSArray *models = TGScheduledRowModels(self.messages,
			[[NSDate date] timeIntervalSince1970]);
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:models.count];
	__weak typeof(self) weakSelf = self;
	for (NSUInteger index = 0; index < models.count; index++){
		NSDictionary *model = models[index];
		NSMutableDictionary *row = [TGSubtitleRow(model[@"title"],
				model[@"detail"], ^{ [weakSelf showActionsForRow:index]; })
				mutableCopy];
		row[TGRowHeight] = @(TGMetricPersonRow);
		[rows addObject:row];
	}
	self.sections = @[TGSection(nil, nil, rows)];
	[self reloadRows];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	[self reload];
}

- (void)refreshPulled {
	[self reload];
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] scheduledMessagesInChat:self.chatId completion:^(NSArray *messages){
		TGScheduledViewController *me = weakSelf;
		if (!me)
			return;
		me.messages = messages ?: @[];
		[me updateEmptyView];
		[me rebuildSections];
		NSLog(@"TDLIB SCHEDULED: %lu", (unsigned long)messages.count);
	}];
}

- (void)applyTheme {
	[super applyTheme];
	TGTheme *theme = [TGTheme shared];
	self.tableView.backgroundColor = [theme listBackgroundColour];
	self.tableView.separatorColor = [theme separatorColour];
}

- (void)updateEmptyView {
	if (self.messages.count) {
		[self hideEmpty];
		return;
	}
	[self showEmptyWithImage:[TGIcons emptySearchIllustration]
	                   title:TGLocalized(@"No scheduled messages here yet...")
	                subtitle:nil];
}

/// The menu a waiting message answers with: send it now, move its time, or
/// take it away.
- (void)showActionsForRow:(NSUInteger)row {
	if (row >= self.messages.count)
		return;
	NSDictionary *m = self.messages[row];
	int64_t messageId = [m[@"id"] longLongValue];
	NSString *what = m[@"text"] ?: TGLocalized(@"Message");
	__weak typeof(self) weakSelf = self;

	NSMutableArray *choices = [NSMutableArray arrayWithObjects:
			TGLocalized(@"Send Now"), TGLocalized(@"Edit Time"),
			TGLocalized(@"Delete"), nil];
	[TGAlertSheet showChoices:choices
						title:what.length > 60 ? [what substringToIndex:60] : what
			 destructiveIndex:2
					   inView:self.navigationController.view ?: self.view
					 onChoice:^(NSInteger index){
		void (^done)(BOOL) = ^(BOOL ok){
			NSString *say = ok ? TGLocalized(@"Done")
					: TGLocalized(@"An error occurred.");
			[TGAlertSheet showMessage:say title:nil inView:weakSelf.view];
			[weakSelf reload];
		};
		if (index == 0)
			[[TGSendStore shared] setSchedulingState:nil forMessage:messageId
										   inChat:weakSelf.chatId completion:done];
		else if (index == 1)
			[weakSelf pickDateFor:messageId];
		else {
			[TGAlertSheet showConfirm:nil
								title:TGLocalized(@"Delete")
							   action:TGLocalized(@"Delete")
						  destructive:YES
							   inView:weakSelf.navigationController.view ?: weakSelf.view
						   onConfirm:^{
				[[TGSendStore shared] deleteMessages:@[@(messageId)] inChat:weakSelf.chatId revoke:YES];
				[weakSelf reload];
			}];
		}
	}];
}

/// Swipe-to-delete is the same removal the hold menu offers, so the queue can
/// be emptied without opening a sheet for every row.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return self.messages.count > 0;
}

- (void)tableView:(UITableView *)tableView
		commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
		 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	if (indexPath.row >= (NSInteger)self.messages.count)
		return;
	int64_t messageId = [self.messages[(NSUInteger)indexPath.row][@"id"] longLongValue];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:TGLocalized(@"Delete")
					   action:TGLocalized(@"Delete")
				  destructive:YES
					   inView:self.navigationController.view ?: self.view
				   onConfirm:^{
		[[TGSendStore shared] deleteMessages:@[@(messageId)] inChat:weakSelf.chatId revoke:YES];
		[weakSelf reload];
	}];
}

/// The date a waiting message moves to. The picker's own bar closes it; a
/// refusal is heard rather than assumed, which is why this is a request.
- (void)pickDateFor:(int64_t)messageId {
	static const CGFloat kBar = TGMetricRow, kPicker = TGMetricPickerHeight;

	TGSheet *sheet = [TGSheet sheetForView:self.view.window ?: self.view];
	UIView *card = [sheet addCardOfHeight:kBar + kPicker edgeToEdge:YES];

	UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:
			CGRectMake(0, kBar, card.bounds.size.width, kPicker)];
	picker.datePickerMode = UIDatePickerModeDateAndTime;
	picker.minimumDate = [NSDate dateWithTimeIntervalSinceNow:60];
	picker.minuteInterval = 15;
	picker.date = [NSDate dateWithTimeIntervalSinceNow:60 * 60];
	[card addSubview:picker];

	UIToolbar *bar = [[UIToolbar alloc] initWithFrame:
			CGRectMake(0, 0, card.bounds.size.width, kBar)];
	bar.items = @[
		[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Cancel")
				style:UIBarButtonItemStylePlain
				target:self action:@selector(sheetDismissed)],
		[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
				target:nil action:nil],
		[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Schedule")
				style:UIBarButtonItemStyleDone
				target:self action:@selector(sheetCommitted)],
	];
	[card addSubview:bar];

	self.picker = picker;
	self.pickerSheet = sheet;
	self.pickerMessageId = messageId;
	[sheet present];
}

- (void)sheetDismissed {
	[self.pickerSheet dismiss];
	self.pickerSheet = nil;
}

- (void)sheetCommitted {
	NSTimeInterval date = [self.picker.date timeIntervalSince1970];
	[self.pickerSheet dismiss];
	self.pickerSheet = nil;

	__weak typeof(self) weakSelf = self;
	[[TGSendStore shared] setSchedulingState:[TGMessageStore scheduledAtDate:date]
							   forMessage:self.pickerMessageId
								   inChat:self.chatId
							   completion:^(BOOL ok){
		NSString *say = ok ? TGLocalized(@"Message Scheduled")
				: TGLocalized(@"An error occurred.");
		[TGAlertSheet showMessage:say title:nil inView:weakSelf.view];
		[weakSelf reload];
	}];
}

@end

// vim:ft=objc
