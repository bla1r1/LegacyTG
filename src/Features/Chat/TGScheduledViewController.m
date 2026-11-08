//
// TGScheduledViewController - the queue behind a scheduled send. One section
// of rows, each answering with the menu a waiting message has: send it now,
// send it when they are next online, move it, or take it away.
//
// Nothing here asks for a reason: the only thing this screen does is that
// one list, so the words in the rows are the messages themselves.
#import "TGScheduledViewController.h"
#import "TGAlertSheet.h"
#import "TGClient.h"
#import "TGEmptyView.h"
#import "TGIcons.h"
#import "TGSheet.h"
#import "TGTheme.h"
#import "TGUIFormat.h"
#import "TGStyle.h"
#import "TGTableViewCell.h"

@interface TGScheduledViewController ()
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) UIDatePicker *picker;
@property (nonatomic, strong) TGSheet *pickerSheet;
@property (nonatomic, assign) int64_t pickerMessageId;
@end

@implementation TGScheduledViewController

- (void)viewDidLoad {
	[super viewDidLoad];


	self.title = @"Scheduled Messages";
	self.messages = @[];
	self.tableView.rowHeight = TGMetricPersonRow;
	[self applyTheme];

	[self reload];

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
	[[TGClient shared] scheduledMessagesInChat:self.chatId completion:^(NSArray *messages){
		TGScheduledViewController *me = weakSelf;
		if (!me)
			return;
		me.messages = messages ?: @[];
		[me updateEmptyView];
		[me.tableView reloadData];
		NSLog(@"TDLIB SCHEDULED: %lu", (unsigned long)messages.count);
	}];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	self.tableView.backgroundColor = [theme listBackgroundColour];
	self.tableView.separatorColor = [theme separatorColour];
	[theme styleNavigationBar:self.navigationController.navigationBar];
}

- (void)updateEmptyView {
	if (self.messages.count) {
		[self hideEmpty];
		return;
	}
	[self showEmptyWithImage:[TGIcons emptySearchIllustration]
	                   title:@"No scheduled messages here yet..."
	                subtitle:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.messages.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
	if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
		UITableViewHeaderFooterView *footer = (UITableViewHeaderFooterView *)view;
		footer.textLabel.font = TGFontCaption();
		footer.textLabel.textColor = [[TGTheme shared] sectionHeaderColour];
		footer.contentView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGScheduledCell";
	TGTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [TGTableViewCell cellWithStyle:TGTableCellKindSubtitle reuseIdentifier:reuse];

	NSDictionary *m = self.messages[indexPath.row];
	NSString *text = m[@"text"];
	cell.title = text.length ? text : @"Message";

	// Telegram names the day and the clock first, then how long that is.
	// "in 2 h 15 min" alone never says when it lands.
	NSTimeInterval stamp = [m[@"date"] doubleValue];
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	NSString *when = TGUIFormatScheduledWhen(stamp, now);
	NSString *until = TGUIFormatScheduledRelative(stamp, now);
	cell.detail = when.length
			? (until.length ? [NSString stringWithFormat:@"%@  ·  %@", when, until] : when)
			: until;

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row >= (NSInteger)self.messages.count)
		return;
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	NSDictionary *m = self.messages[indexPath.row];
	int64_t messageId = [m[@"id"] longLongValue];
	NSString *what = m[@"text"] ?: @"Message";
	__weak typeof(self) weakSelf = self;

	NSMutableArray *choices = [NSMutableArray arrayWithObjects:
			@"Send Now", @"Edit Time", @"Delete", nil];
	[TGAlertSheet showChoices:choices
						title:what.length > 60 ? [what substringToIndex:60] : what
			 destructiveIndex:2
					   inView:self.navigationController.view ?: self.view
					 onChoice:^(NSInteger index){
		void (^done)(BOOL) = ^(BOOL ok){
			NSString *say = ok ? @"Done" : @"An error occurred.";
			[TGAlertSheet showMessage:say title:nil inView:weakSelf.view];
			[weakSelf reload];
		};
		if (index == 0)
			[[TGClient shared] setSchedulingState:nil forMessage:messageId
										   inChat:weakSelf.chatId completion:done];
		else if (index == 1)
			[weakSelf pickDateFor:messageId];
		else {
			[TGAlertSheet showConfirm:nil
								title:@"Delete"
							   action:@"Delete"
						  destructive:YES
							   inView:weakSelf.navigationController.view ?: weakSelf.view
						   onConfirm:^{
				[[TGClient shared] deleteMessages:@[@(messageId)] inChat:weakSelf.chatId];
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
						title:@"Delete"
					   action:@"Delete"
				  destructive:YES
					   inView:self.navigationController.view ?: self.view
				   onConfirm:^{
		[[TGClient shared] deleteMessages:@[@(messageId)] inChat:weakSelf.chatId];
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
		[[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain
				target:self action:@selector(sheetDismissed)],
		[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
				target:nil action:nil],
		[[UIBarButtonItem alloc] initWithTitle:@"Schedule" style:UIBarButtonItemStyleDone
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
	[[TGClient shared] setSchedulingState:[TGClient scheduledAtDate:date]
							   forMessage:self.pickerMessageId
								   inChat:self.chatId
							   completion:^(BOOL ok){
		NSString *say = ok ? @"Message Scheduled" : @"An error occurred.";
		[TGAlertSheet showMessage:say title:nil inView:weakSelf.view];
		[weakSelf reload];
	}];
}

@end

// vim:ft=objc
