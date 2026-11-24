//
// TGPinnedMessagesViewController.m - list of all pinned messages in a chat.
//
#import "TGPinnedMessagesViewController.h"
#import "TGMessageStore.h"
#import "TGAlertSheet.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGStyle.h"
#import "TGRows.h"
#import "TGBarItem.h"
#import "TGLocalization.h"
#import "TGUIFormat.h"
#import "TGMessageLayout.h"

@interface TGPinnedMessagesViewController ()
@property (nonatomic, strong) NSMutableArray *messages;
@end

@implementation TGPinnedMessagesViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.pageKind = TGPageKindList;
	self.title = TGLocalized(@"Pinned Messages");
	self.messages = [NSMutableArray array];

	[self applyTheme];
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	[self reload];
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] pinnedMessagesForChat:self.chatId completion:^(NSArray *messages){
		TGPinnedMessagesViewController *me = weakSelf;
		if (!me)
			return;
		me.messages = messages ? [messages mutableCopy] : [NSMutableArray array];
		[me updateNavigationItem];
		[me updateEmptyView];
		[me rebuildSections];
	}];
}

- (void)updateNavigationItem {
	if (self.messages.count) {
		self.navigationItem.rightBarButtonItem = [TGBarItem plainItemWithTitle:TGLocalized(@"Unpin All")
		                                                                target:self
		                                                                action:@selector(unpinAllTapped)];
	} else {
		self.navigationItem.rightBarButtonItem = nil;
	}
}

- (void)updateEmptyView {
	if (self.messages.count) {
		[self hideEmpty];
		return;
	}
	[self showEmptyWithImage:[TGIcons emptySearchIllustration]
	                   title:TGLocalized(@"No pinned messages here yet...")
	                subtitle:nil];
}

- (void)rebuildSections {
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:self.messages.count];
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	__weak typeof(self) weakSelf = self;

	for (NSUInteger i = 0; i < self.messages.count; i++) {
		NSDictionary *m = self.messages[i];
		int64_t msgId = [m[@"id"] longLongValue];

		NSString *author = m[@"senderName"] ?: m[@"from"];
		if (!author.length)
			author = TGLocalized(@"Pinned Message");

		NSString *body = m[@"text"];
		if (!body.length)
			body = TGDescribeMessageContent(m);
		if (!body.length)
			body = TGLocalized(@"Message");

		NSTimeInterval stamp = [m[@"date"] doubleValue];
		NSString *dateStr = stamp > 0 ? TGUIFormatChatDate(stamp, now) : @"";

		NSMutableDictionary *row = [TGSubtitleRow(author, body, ^{
			[weakSelf selectMessageWithId:msgId];
		}) mutableCopy];

		row[TGRowRawTitle] = @YES;
		row[TGRowRawDetail] = @YES;
		if (dateStr.length)
			row[TGRowDetail] = dateStr;
		row[TGRowHeight] = @(TGMetricPersonRow);

		[rows addObject:row];
	}

	self.sections = @[TGSection(nil, nil, rows)];
	[self reloadRows];
}

- (void)selectMessageWithId:(int64_t)msgId {
	void (^cb)(int64_t) = self.onSelectMessage;
	[self.navigationController popViewControllerAnimated:YES];
	if (cb)
		cb(msgId);
}

- (void)unpinAllTapped {
	int64_t chatId = self.chatId;
	int64_t threadId = self.threadId;
	__weak typeof(self) weakSelf = self;

	[TGAlertSheet showConfirm:nil
	                    title:TGLocalized(@"Unpin All Messages")
	                   action:TGLocalized(@"Unpin All Messages")
	              destructive:YES
	                   inView:self.view
	                onConfirm:^{
		[[TGMessageStore shared] unpinAllMessagesInChat:chatId thread:threadId];
		[weakSelf.messages removeAllObjects];
		[weakSelf updateNavigationItem];
		[weakSelf updateEmptyView];
		[weakSelf rebuildSections];
	}];
}

#pragma mark - Swipe to unpin

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.row < (NSInteger)self.messages.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGLocalized(@"Unpin");
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	if (indexPath.row >= (NSInteger)self.messages.count)
		return;

	NSDictionary *m = self.messages[(NSUInteger)indexPath.row];
	int64_t msgId = [m[@"id"] longLongValue];
	[[TGMessageStore shared] unpinMessage:msgId inChat:self.chatId];

	[self.messages removeObjectAtIndex:(NSUInteger)indexPath.row];
	[self updateNavigationItem];
	[self updateEmptyView];
	[self rebuildSections];
}

@end
