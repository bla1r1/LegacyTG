//
// TGUsernameSettingsViewController.m - the account's usernames.
//
// Telegram now keeps more than one username on an account: one editable name
// and any number of collectible ones, each switched on or off and ordered.
// The Edit Profile row used to show the first of them as a string with nothing
// to do about the rest. This is the screen behind that row.
//
#import "TGUsernameSettingsViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGSettingsFormatting.h"
#import "TGRows.h"
#import "TGAccountStore.h"
#import "TGSettingsStore.h"


@interface TGUsernameSettingsViewController ()
@property (nonatomic, strong) NSDictionary *usernames;
@property (nonatomic, strong) NSMutableArray *active;
@property (nonatomic, strong) NSMutableArray *disabled;
@property (nonatomic, copy) NSString *editable;
@property (nonatomic, copy) NSString *inlineText;
@property (nonatomic, assign) BOOL busy;
/// The answer under the field: Checking username..., the name is available,
/// already taken or invalid. Empty until the field differs from the account.
@property (nonatomic, copy) NSString *statusText;
/// 0 checking, 1 available, 2 an error. The line takes the theme's colours.
@property (nonatomic, assign) NSInteger statusTone;
@end

@implementation TGUsernameSettingsViewController

- (instancetype)init {
	return [super init];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Username";
	self.active = [NSMutableArray array];
	self.disabled = [NSMutableArray array];
	self.inlineText = @"";
	[self rebuildSections];
	[self applyTheme];
	[self load];
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	[self load];
}

- (void)load {
	__weak typeof(self) weakSelf = self;
	[[TGAccountStore shared] accountUsernamesWithCompletion:^(NSDictionary *usernames){
		TGUsernameSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.usernames = usernames;
		me.active = [usernames[@"active_usernames"] isKindOfClass:NSArray.class]
				? [usernames[@"active_usernames"] mutableCopy] : [NSMutableArray array];
		me.disabled = [usernames[@"disabled_usernames"] isKindOfClass:NSArray.class]
				? [usernames[@"disabled_usernames"] mutableCopy] : [NSMutableArray array];
		me.editable = usernames[@"editable_username"] ?: @"";
		me.inlineText = me.editable;
		me.statusText = nil;
		[me clearStoredFieldText];
		[me updateEditButton];
		[me rebuildSections];
		[me reloadRows];
	}];
}

- (void)updateEditButton {
	BOOL canOrder = self.active.count > 1;
	self.navigationItem.rightBarButtonItem = canOrder
			? [[UIBarButtonItem alloc] initWithTitle:(self.tableView.editing ? @"Done" : @"Edit")
											  style:UIBarButtonItemStylePlain
											 target:self action:@selector(toggleEditing)]
			: nil;
}

- (void)toggleEditing {
	[self.tableView setEditing:!self.tableView.editing animated:YES];
	[self updateEditButton];
}

#pragma mark - rows

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *sections = [NSMutableArray array];

	NSMutableArray *accountRows = [NSMutableArray array];
	NSMutableDictionary *field = TGFieldRow(@"username", self.inlineText,
			^(NSString *text){
		[weakSelf usernameChanged:text];
	});
	field[TGRowFieldIdentifier] = @"username";
	field[TGRowFieldPrefix] = @"t.me/";
	field[TGRowFieldAutocapitalization] = @(UITextAutocapitalizationTypeNone);
	field[TGRowFieldAutocorrection] = @(UITextAutocorrectionTypeNo);
	field[TGRowFieldReturnKey] = @(UIReturnKeyDone);
	field[TGRowFieldReturn] = ^{
		[weakSelf.view endEditing:YES];
	};
	field[TGRowFieldEndEditing] = ^(NSString *text){
		[weakSelf usernameEditingEnded:text];
	};
	[accountRows addObject:field];

	if (self.statusText.length){
		NSMutableDictionary *status = TGRow(TGKindNote, self.statusText);
		status[TGRowTextTone] = @(self.statusTone);
		[accountRows addObject:status];
	}
	if (self.editable.length){
		NSMutableDictionary *remove = TGRedRow(@"Remove", ^{
			[weakSelf removeUsername];
		});
		[accountRows addObject:remove];
	}
	[sections addObject:TGSection(nil,
			@"Usernames must have at least 5 characters.", accountRows)];

	NSMutableArray *activeRows = [NSMutableArray array];
	for (NSString *username in self.active){
		BOOL primary = [username isEqualToString:self.editable];
		NSMutableDictionary *row = [TGSubtitleRow(
				[@"@" stringByAppendingString:username],
				primary ? @"Primary" : @"Active", nil) mutableCopy];
		row[TGRowKind] = TGKindToggle;
		row[TGRowOn] = @YES;
		row[TGRowEnabled] = @(!(primary || self.busy));
		row[TGRowCanMove] = @(self.active.count > 1);
		row[TGRowToggle] = ^(BOOL on){
			[weakSelf setUsername:username active:on];
		};
		row[TGRowMove] = ^(NSInteger from, NSInteger to){
			[weakSelf moveUsernameFrom:from to:to];
		};
		[activeRows addObject:row];
	}
	[sections addObject:TGSection(@"LINKS ORDER", nil, activeRows)];

	NSMutableArray *disabledRows = [NSMutableArray array];
	for (NSString *username in self.disabled){
		NSMutableDictionary *row = [TGSubtitleRow(
				[@"@" stringByAppendingString:username], @"Disabled", nil) mutableCopy];
		row[TGRowKind] = TGKindToggle;
		row[TGRowOn] = @NO;
		row[TGRowEnabled] = @(!self.busy);
		row[TGRowToggle] = ^(BOOL on){
			[weakSelf setUsername:username active:on];
		};
		[disabledRows addObject:row];
	}
	[sections addObject:TGSection(nil, nil, disabledRows)];

	self.sections = sections;
}

- (void)moveUsernameFrom:(NSInteger)from to:(NSInteger)to {
	NSArray *before = [self.active copy];
	NSUInteger source = (NSUInteger)from, destination = (NSUInteger)to;
	NSString *name = self.active[source];
	[self.active removeObjectAtIndex:source];
	[self.active insertObject:name atIndex:destination];
	[self saveOrderRestoring:before];
}

- (void)saveOrderRestoring:(NSArray *)before {
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	[[TGAccountStore shared] reorderActiveUsernames:self.active
			completion:^(BOOL ok, NSString *error){
		TGUsernameSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.busy = NO;
		if (!ok){
			me.active = [before mutableCopy];
			[me rebuildSections];
			[me reloadRows];
			[TGAlertSheet showMessage:(error ?: @"An error occurred.")
								title:@"Username Order" inView:me.view];
			return;
		}
		[me load];
	}];
}

- (void)setUsername:(NSString *)username active:(BOOL)on {
	if (self.busy){
		[self rebuildSections];
		[self reloadRows];
		return;
	}
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	[[TGAccountStore shared] toggleUsernameIsActive:username isActive:on
			completion:^(BOOL ok, NSString *error){
		TGUsernameSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.busy = NO;
		if (!ok){
			[me rebuildSections];
			[me reloadRows];
			[TGAlertSheet showMessage:(error ?: @"An error occurred.")
								title:@"Username" inView:me.view];
			return;
		}
		// A name moving between active and disabled changes both sections,
		// so the list is re-read rather than the one row being flipped.
		[me load];
	}];
}

#pragma mark - choosing

- (void)updateStatusText:(NSString *)text tone:(NSInteger)tone {
	BOOL had = self.statusText.length > 0;
	BOOL has = text.length > 0;
	self.statusText = text;
	self.statusTone = tone;
	[self rebuildSections];
	if (!self.isViewLoaded){
		return;
	}
	if (had == has){
		if (has)
			[self.tableView reloadRowsAtIndexPaths:@[
					[NSIndexPath indexPathForRow:1 inSection:0]]
					withRowAnimation:UITableViewRowAnimationNone];
		return;
	}
	// Inserting or removing the one status row keeps the text field (and the
	// keyboard) alive; reloading the whole section would recreate the field
	// under the user's finger.
	[self.tableView beginUpdates];
	if (has){
		[self.tableView insertRowsAtIndexPaths:@[
				[NSIndexPath indexPathForRow:1 inSection:0]]
				withRowAnimation:UITableViewRowAnimationNone];
	} else {
		[self.tableView deleteRowsAtIndexPaths:@[
				[NSIndexPath indexPathForRow:1 inSection:0]]
				withRowAnimation:UITableViewRowAnimationNone];
	}
	[self.tableView endUpdates];
}

#pragma mark - live availability

/// Typing stops for half a second before the check goes out: one request per
/// pause, not one per keystroke, which is what TDLib's rate limits expect.
- (void)usernameChanged:(NSString *)text {
	self.inlineText = text ?: @"";
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(checkUsernameNow) object:nil];
	NSString *typed = TGUsernameNormalized(self.inlineText);
	if (!TGUsernameShouldCheck(typed, self.editable)){
		[self updateStatusText:nil tone:0];
		return;
	}
	[self updateStatusText:TGUsernameAvailabilityText(@"checking", typed) tone:0];
	[self performSelector:@selector(checkUsernameNow) withObject:nil afterDelay:0.5];
}

- (void)checkUsernameNow {
	NSString *typed = TGUsernameNormalized(self.inlineText);
	if (!TGUsernameShouldCheck(typed, self.editable))
		return;
	__weak typeof(self) weakSelf = self;
	// A user account checks its own name, which TDLib spells as chat_id 0.
	[[TGSettingsStore shared] checkUsername:typed forChat:0 completion:^(NSString *result){
		TGUsernameSettingsViewController *me = weakSelf;
		if (!me)
			return;
		NSString *current = TGUsernameNormalized(me.inlineText);
		if (!TGUsernameAnswerStillApplies(typed, current))
			return;
		NSInteger tone = [result isEqualToString:@"ok"] ? 1
				: ([result isEqualToString:@"checking"] ? 0 : 2);
		[me updateStatusText:TGUsernameAvailabilityText(result, typed) tone:tone];
	}];
}

- (void)usernameEditingEnded:(NSString *)text {
	self.inlineText = text ?: @"";
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(checkUsernameNow) object:nil];
	NSString *typed = TGUsernameNormalized(self.inlineText);
	if (!TGUsernameShouldCheck(typed, self.editable))
		return;
	__weak typeof(self) weakSelf = self;
	[[TGAccountStore shared] setUsername:typed completion:^(BOOL ok){
		if (!ok){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Username" inView:weakSelf.view];
			[weakSelf rebuildSections];
			[weakSelf reloadRows];
			return;
		}
		[weakSelf load];
	}];
}

- (void)removeUsername {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:@"Remove"
					   action:@"Remove"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGAccountStore shared] setUsername:@"" completion:^(BOOL ok){
			if (!ok){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Remove" inView:weakSelf.view];
				return;
			}
			[weakSelf load];
		}];
	}];
}

@end
