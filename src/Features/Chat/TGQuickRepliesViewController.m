//
// TGQuickRepliesViewController.m
//
#import "TGQuickRepliesViewController.h"
#import "TGLocalization.h"
#import "TGQuickReplyMessagesViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGAlertSheet.h"

@interface TGQuickRepliesViewController ()
@property (nonatomic, strong) NSMutableArray *shortcuts;
@property (nonatomic, assign) BOOL loaded;
@end

@implementation TGQuickRepliesViewController

- (void)viewDidLoad {
	self.title = @"Quick Replies";
	[super viewDidLoad];
	self.navigationItem.rightBarButtonItem = self.editButtonItem;
	[[NSNotificationCenter defaultCenter] addObserverForName:TGQuickRepliesChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){ [self rebuild]; }];
	[self loadShortcuts];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self rebuild];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
	[super setEditing:editing animated:animated];
	// Leaving Edit is also leaving the local drag copy: the client's list has
	// the message counts and whatever order the server accepted.
	if (!editing)
		[self rebuild];
}

- (void)loadShortcuts {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] loadQuickReplyShortcutsWithCompletion:^(NSArray *shortcuts){
		TGQuickRepliesViewController *me = weakSelf;
		if (!me)
			return;
		me.loaded = YES;
		me.shortcuts = [shortcuts mutableCopy] ?: [NSMutableArray array];
		[me rebuild];
	}];
}

- (void)rebuild {
	// A write may have added or removed a shortcut while the manager is open;
	// the client's list is the truth, but the local copy preserves a drag the
	// server has not echoed yet.
	NSArray *fromClient = [TGClient shared].quickReplyShortcuts;
	// While Edit is up the local copy is the drag in progress; every other
	// time the client's list carries the counts and order Telegram holds.
	if (!self.tableView.editing || !self.shortcuts.count ||
		fromClient.count != self.shortcuts.count)
		self.shortcuts = [fromClient mutableCopy] ?: [NSMutableArray array];

	__weak typeof(self) weakSelf = self;
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *shortcut in self.shortcuts){
		NSInteger shortcutId = [shortcut[@"id"] integerValue];
		NSString *name = shortcut[@"name"] ?: @"Shortcut";
		NSInteger count = [shortcut[@"messageCount"] integerValue];
		NSString *preview = shortcut[@"preview"];
		NSString *detail = count
				? [NSString stringWithFormat:@"%@%@",
						[NSString stringWithFormat:TGLocalized(@"%@ messages"), @(count)],
						preview.length ? [@" · " stringByAppendingString:preview] : @""]
				: @"Empty";
		if (self.sendChatId){
			[rows addObject:TGFeatureRow(name, detail, ^{
				[weakSelf sendShortcut:shortcutId name:name];
			})];
		} else {
			[rows addObject:TGFeatureOpenRow(name, detail, ^{
				TGQuickReplyMessagesViewController *screen =
						[[TGQuickReplyMessagesViewController alloc]
								initWithShortcutId:shortcutId name:name];
				screen.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:screen animated:YES];
			})];
		}
	}
	if (!rows.count){
		NSMutableDictionary *empty = TGFeatureRow(self.loaded
				? @"No Quick Replies" : @"Loading...", nil, nil);
		empty[TGFeatureRowKind] = TGFeatureKindPlain;
		[rows addObject:empty];
	}

	NSMutableArray *actions = [NSMutableArray array];
	if (!self.sendChatId){
		[actions addObject:TGFeatureAction(@"New Quick Reply", ^{ [weakSelf createShortcut]; })];
	}
	self.sections = @[
		TGFeatureSection(nil, nil, rows),
		self.sendChatId ? TGFeatureSection(nil, nil, @[])
						: TGFeatureSection(nil, nil, actions),
	];
	[self reloadRows];
}

- (void)createShortcut {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"New Quick Reply"
					message:nil
				placeholder:@"Shortcut"
					   text:nil
					 action:@"Next"
					 inView:self.view
				   onSubmit:^(NSString *name){
		[[TGClient shared] checkQuickReplyShortcutName:name
											completion:^(BOOL ok, NSString *error){
			if (!ok){
				[weakSelf toast:error ?: @"An error occurred."];
				return;
			}
			[TGAlertSheet showInput:@"Message"
							message:nil
						placeholder:@"Message"
							   text:nil
							 action:@"Save"
							 inView:weakSelf.view
						   onSubmit:^(NSString *text){
				[[TGClient shared] addQuickReplyShortcutMessage:name text:text
													 completion:^(NSDictionary *message,
																  NSString *error){
					if (!message){
						[weakSelf toast:error ?: @"An error occurred."];
						return;
					}
					[weakSelf loadShortcuts];
				}];
			}];
		}];
	}];
}

- (void)sendShortcut:(NSInteger)shortcutId name:(NSString *)name {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sendQuickReplyShortcutMessages:shortcutId
											   toChat:self.sendChatId
											sendingId:(int32_t)arc4random()
										   completion:^(NSArray *messages, NSString *error){
		if (!messages.count && error.length){
			[weakSelf toast:error];
			return;
		}
		[weakSelf.navigationController popViewControllerAnimated:YES];
	}];
}

#pragma mark - editing

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return !self.sendChatId && indexPath.section == 0 && self.shortcuts.count > 0;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return !self.sendChatId && indexPath.section == 0 && self.shortcuts.count > 1;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
		   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView
		moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
			  toIndexPath:(NSIndexPath *)destinationIndexPath {
	if (sourceIndexPath.row >= (NSInteger)self.shortcuts.count ||
		destinationIndexPath.row >= (NSInteger)self.shortcuts.count)
		return;
	NSDictionary *moved = self.shortcuts[sourceIndexPath.row];
	[self.shortcuts removeObjectAtIndex:sourceIndexPath.row];
	[self.shortcuts insertObject:moved atIndex:destinationIndexPath.row];

	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *shortcut in self.shortcuts)
		[ids addObject:shortcut[@"id"]];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] reorderQuickReplyShortcuts:ids completion:^(BOOL ok, NSString *error){
		if (!ok)
			[weakSelf toast:error ?: @"An error occurred."];
	}];
	[self rebuild];
}

- (void)tableView:(UITableView *)tableView
		commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
		 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete ||
		indexPath.row >= (NSInteger)self.shortcuts.count)
		return;
	NSDictionary *shortcut = self.shortcuts[indexPath.row];
	NSInteger shortcutId = [shortcut[@"id"] integerValue];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						 title:@"Delete Quick Reply"
						action:@"Delete"
				   destructive:YES
						inView:self.view
					 onConfirm:^{
		[[TGClient shared] deleteQuickReplyShortcut:shortcutId
										completion:^(BOOL ok, NSString *error){
			if (!ok){
				[weakSelf toast:error ?: @"An error occurred."];
				return;
			}
			[weakSelf loadShortcuts];
		}];
	}];
}

@end
