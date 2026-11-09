//
// TGMessageAudienceViewController.m - the people behind a reaction or a view.
//
// TDLib gives reactions through getMessageAddedReactions and readers through
// getMessageViewers; both answer people and a time, and both are refused in
// chats where Telegram keeps that list private. The list screen therefore
// owns three states: the rows, "loading", and the sentence Telegram gave for
// why there are none - never an empty table that looks broken.
//
#import "TGMessageAudienceViewController.h"
#import "TGLocalization.h"
#import "TGAlertSheet.h"
#import "TGClient.h"
#import "TGCustomEmojiStore.h"
#import "TGDateFormat.h"
#import "TGOptions.h"
#import "TGProfileViewController.h"
#import "TGRows.h"

/// The same three shapes the chat list and the chat sheets use for a time.
static NSString *TGAudienceDate(NSTimeInterval unix) {
	char buf[TGDateFormatBufferSize + 1] = {0};
	size_t len = TGChatDateFormat((time_t)unix, (time_t)TGOptionNow(), buf,
								TGDateFormatBufferSize);
	return len ? [[NSString alloc] initWithBytes:buf length:len encoding:NSUTF8StringEncoding]
			   : @"";
}

@interface TGMessageAudienceViewController ()
@property (nonatomic, assign) TGMessageAudienceKind kind;
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t messageId;
@property (nonatomic, copy) NSString *emoji;
@property (nonatomic, assign) int64_t customEmojiId;
@property (nonatomic, strong) NSArray *people;
@property (nonatomic, copy) NSString *emptyText;
- (void)rebuildSections;
@end

@implementation TGMessageAudienceViewController

- (instancetype)initWithKind:(TGMessageAudienceKind)kind
						chat:(int64_t)chatId
					 message:(int64_t)messageId
					   emoji:(NSString *)emoji
			   customEmojiId:(int64_t)customEmojiId {
	self = [super init];
	if (!self)
		return nil;
	_kind = kind;
	_chatId = chatId;
	_messageId = messageId;
	_emoji = [emoji copy];
	_customEmojiId = customEmojiId;
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	self.people = @[];
	self.emptyText = TGLocalized(@"Loading...");

	if (self.kind == TGMessageAudienceKindReactions){
		NSString *glyph = self.emoji.length ? self.emoji : @"★";
		self.title = [NSString stringWithFormat:TGLocalized(@"%@ Reactions"), glyph];
	} else {
		self.title = TGLocalized(@"Viewers");
	}

	// An explicit back item, not only the system chevron: the list is also
	// opened from a URL-driven chat, where the stack is not always what the
	// bar assumes. It pops when it can and dismisses when it cannot.
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:TGLocalized(@"Back") style:UIBarButtonItemStylePlain
				   target:self action:@selector(closeScreen)];

	// Reaction rows keep the administrator's removal that used to live in a
	// tiny action sheet: a hold asks before taking one person's reactions
	// off this message and across the chat.
	if (self.kind == TGMessageAudienceKindReactions){
		UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
				initWithTarget:self action:@selector(rowHeld:)];
		hold.minimumPressDuration = 0.55;
		[self.tableView addGestureRecognizer:hold];
	}

	__weak typeof(self) weakSelf = self;
	[[NSNotificationCenter defaultCenter] addObserverForName:TGCustomEmojiLoadedNotification
													  object:nil
													   queue:[NSOperationQueue mainQueue]
												  usingBlock:^(NSNotification *note){
		TGMessageAudienceViewController *me = weakSelf;
		if (!me) return;
		[NSObject cancelPreviousPerformRequestsWithTarget:me selector:@selector(reloadVisibleRows) object:nil];
		[me performSelector:@selector(reloadVisibleRows) withObject:nil afterDelay:0.3];
	}];

	[self rebuildSections];
	[self loadPeople];
}

- (void)reloadVisibleRows {
	NSArray *visible = [self.tableView indexPathsForVisibleRows];
	if (visible.count) {
		[self.tableView reloadRowsAtIndexPaths:visible withRowAnimation:UITableViewRowAnimationNone];
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)closeScreen {
	if (self.navigationController.viewControllers.count > 1)
		[self.navigationController popViewControllerAnimated:YES];
	else
		[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - loading

- (void)loadPeople {
	if (self.kind == TGMessageAudienceKindReactions){
		NSDictionary *type = self.customEmojiId > 0
				? @{@"@type" : @"reactionTypeCustomEmoji",
					@"custom_emoji_id" : @(self.customEmojiId)}
				: @{@"@type" : @"reactionTypeEmoji", @"emoji" : self.emoji ?: @""};
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] addedReactionsOfMessage:self.messageId
											inChat:self.chatId
									  reactionType:type
											offset:nil
										completion:^(NSArray *rows, NSString *next){
			TGMessageAudienceViewController *me = weakSelf;
			if (!me)
				return;
			if (!rows.count){
				me.emptyText = TGLocalized(@"An error occurred.");
				[me rebuildSections];
				[me.tableView reloadData];
				return;
			}
			[me showReactionRows:rows];
		}];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] viewersOfMessage:self.messageId inChat:self.chatId
							completion:^(NSArray *viewers){
		TGMessageAudienceViewController *me = weakSelf;
		if (!me)
			return;
		if (viewers.count){
			[me showViewerRows:viewers];
			return;
		}
		// No viewer list is what a private chat answers. The read date is
		// still Telegram's answer, and its reason is the honest sentence
		// when there is no date either.
		[[TGClient shared] readDateOfMessage:me.messageId inChat:me.chatId
								  completion:^(NSTimeInterval date, NSString *reason){
			TGMessageAudienceViewController *again = weakSelf;
			if (!again)
				return;
			again.emptyText = date > 0
					? [NSString stringWithFormat:TGLocalized(@"Read %@."),
							TGAudienceDate(date)]
					: (reason ?: TGLocalized(@"An error occurred."));
			[again rebuildSections];
			[again.tableView reloadData];
		}];
	}];
}

- (void)showReactionRows:(NSArray *)reactions {
	NSString *glyph = self.emoji.length ? self.emoji : @"★";
	NSMutableArray *people = [NSMutableArray arrayWithCapacity:reactions.count];
	for (NSDictionary *r in reactions){
		NSDictionary *sender = r[@"sender"];
		int64_t userId = [sender[@"user_id"] longLongValue];
		int64_t chatId = [sender[@"chat_id"] longLongValue];
		NSString *name = userId
				? ([[TGClient shared] nameForUserId:userId] ?: TGLocalized(@"User"))
				: (chatId ? TGLocalized(@"Another chat") : TGLocalized(@"User"));
		if ([r[@"mine"] boolValue])
			name = [NSString stringWithFormat:TGLocalized(@"%@ (you)"), name];
		NSString *when = TGAudienceDate([r[@"date"] doubleValue]);
		NSString *detail = when.length
				? [NSString stringWithFormat:@"%@  ·  %@", glyph, when]
				: glyph;
		[people addObject:@{
			@"name"   : name ?: TGLocalized(@"User"),
			@"detail" : detail,
			@"userId" : @(userId),
			@"chatId" : @(chatId),
			@"date"   : r[@"date"] ?: @(0),
			@"sender" : sender ?: @{},
		}];
	}
	self.people = people;
	self.emptyText = nil;
	[self rebuildSections];
	[self.tableView reloadData];
	[self resolveMissingNames];
}

- (void)showViewerRows:(NSArray *)viewers {
	NSMutableArray *people = [NSMutableArray arrayWithCapacity:viewers.count];
	for (NSDictionary *v in viewers){
		int64_t userId = [v[@"user_id"] longLongValue];
		NSString *name = [[TGClient shared] nameForUserId:userId]
				?: TGLocalized(@"User");
		NSString *when = TGAudienceDate([v[@"view_date"] doubleValue]);
		[people addObject:@{
			@"name"   : name,
			@"detail" : when,
			@"userId" : @(userId),
			@"chatId" : @(0),
			@"date"   : v[@"view_date"] ?: @(0),
		}];
	}
	self.people = people;
	self.emptyText = nil;
	self.title = [NSString stringWithFormat:TGLocalized(@"%@ viewers"),
			@(viewers.count)];
	[self rebuildSections];
	[self.tableView reloadData];
	[self resolveMissingNames];
}

/// Names arrive with the same updateUser that carries the photo, so a row
/// whose name is not cached is asked for once; TDLib answers, the chip and
/// the row then read the same person.
- (void)resolveMissingNames {
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *row in self.people){
		int64_t userId = [row[@"userId"] longLongValue];
		if (!userId || [[TGClient shared] nameForUserId:userId].length)
			continue;
		[[TGClient shared] ensureUserName:userId completion:^{
			TGMessageAudienceViewController *me = weakSelf;
			if (!me)
				return;
			[me rebuildSections];
			[me.tableView reloadData];
		}];
	}
}

#pragma mark - rows

- (void)rebuildSections {
	NSMutableArray *rows = [NSMutableArray array];
	if (!self.people.count){
		[rows addObject:TGRow(TGKindPlain,
				self.emptyText ?: TGLocalized(@"Nobody"))];
		self.sections = @[TGSection(nil, nil, rows)];
		return;
	}

	__weak typeof(self) weakSelf = self;
	for (NSDictionary *person in self.people){
		int64_t userId = [person[@"userId"] longLongValue];
		int64_t chatId = [person[@"chatId"] longLongValue];
		int64_t statusId = userId
				? [[TGClient shared] emojiStatusIdForUser:userId]
				: (chatId ? [[TGClient shared] emojiStatusIdForChat:chatId] : 0);
		int64_t peerId = userId ?: chatId;
		NSMutableDictionary *row = TGPeerRow(@(peerId),
				person[@"name"] ?: TGLocalized(@"User"),
				person[@"detail"] ?: @"", nil);
		row[TGRowAvatarUser] = @(userId != 0);
		if (statusId > 0)
			row[TGRowStatusEmojiId] = @(statusId);
		NSString *title = person[@"name"] ?: @"";
		row[TGRowTap] = ^{
			TGMessageAudienceViewController *me = weakSelf;
			if (!me || !userId)
				return;
			// Telegram opens the person from a reaction or a reader, the same
			// way it does from a member row; the list is not a dead end.
			TGProfileViewController *profile = [[TGProfileViewController alloc]
					initWithChatId:userId userId:userId title:title];
			if (!profile)
				return;
			profile.hidesBottomBarWhenPushed = YES;
			[me.navigationController pushViewController:profile animated:YES];
		};
		[rows addObject:row];
	}
	self.sections = @[TGSection(nil, nil, rows)];
}

#pragma mark - table

/// A hold on a reactor, not a tap: removing somebody's reactions is an
/// administrator's correction, not what the list is for on a normal read.
- (void)rowHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	CGPoint where = [hold locationInView:self.tableView];
	NSIndexPath *path = [self.tableView indexPathForRowAtPoint:where];
	if (!path || path.row >= (NSInteger)self.people.count)
		return;
	NSDictionary *row = self.people[(NSUInteger)path.row];
	NSDictionary *sender = row[@"sender"];
	if (![sender isKindOfClass:NSDictionary.class] || !sender.count)
		return;

	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
							title:TGLocalized(@"Remove")
						   action:TGLocalized(@"Remove")
					  destructive:YES
						   inView:self.view
						onConfirm:^{
		TGMessageAudienceViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] deleteReactionsOfSender:sender
										ofMessage:me.messageId
										   inChat:me.chatId];
		[[TGClient shared] deleteAllReactionsOfSender:sender
											   inChat:me.chatId];
	}];
}

@end
