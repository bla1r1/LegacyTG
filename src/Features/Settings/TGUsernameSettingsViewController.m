//
// TGUsernameSettingsViewController.m - the account's usernames.
//
// Telegram now keeps more than one username on an account: one editable name
// and any number of collectible ones, each switched on or off and ordered.
// The Edit Profile row used to show the first of them as a string with nothing
// to do about the rest. This is the screen behind that row.
//
#import "TGUsernameSettingsViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGSettingsFormatting.h"

/// A switch that remembers which username it changes. The row is rebuilt on
/// every reload, so an index would point at whatever moved into its place.
@interface TGUsernameSwitch : UISwitch
@property (nonatomic, copy) NSString *username;
@end

@implementation TGUsernameSwitch
@end

@interface TGUsernameSettingsViewController () <UITextFieldDelegate>
@property (nonatomic, strong) NSDictionary *usernames;
@property (nonatomic, strong) NSMutableArray *active;
@property (nonatomic, strong) NSMutableArray *disabled;
@property (nonatomic, copy) NSString *editable;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, strong) UITextField *inlineField;
/// The answer under the field: Checking username..., the name is available,
/// already taken or invalid. Empty until the field differs from the account.
@property (nonatomic, copy) NSString *statusText;
/// 0 checking, 1 available, 2 an error. The line takes the theme's colours.
@property (nonatomic, assign) NSInteger statusTone;
@end

static const CGFloat kUsernamePrefixWidth = 42.0f;
static const CGFloat kUsernameFieldHeight = 44.0f;
static const CGFloat kUsernameFieldInset = 12.0f;

@implementation TGUsernameSettingsViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Username";
	self.active = [NSMutableArray array];
	self.disabled = [NSMutableArray array];
	[self applyTheme];
	[self load];

}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	[self load];
}

- (void)applyTheme {
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)load {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] accountUsernamesWithCompletion:^(NSDictionary *usernames){
		TGUsernameSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.usernames = usernames;
		me.active = [usernames[@"active_usernames"] isKindOfClass:NSArray.class]
				? [usernames[@"active_usernames"] mutableCopy] : [NSMutableArray array];
		me.disabled = [usernames[@"disabled_usernames"] isKindOfClass:NSArray.class]
				? [usernames[@"disabled_usernames"] mutableCopy] : [NSMutableArray array];
		me.editable = usernames[@"editable_username"] ?: @"";
		me.statusText = nil;
		[me updateEditButton];
		[me.tableView reloadData];
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

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 1) return @"LINKS ORDER";
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 0)
		return @"Usernames must have at least 5 characters.";
	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 1 + (self.statusText.length ? 1 : 0) +
				(self.editable.length ? 1 : 0);
	if (section == 1)
		return self.active.count;
	return self.disabled.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)path
{
	TGTheme *theme = [TGTheme shared];
	if (path.section == 0){
		NSInteger removeRow = 1 + (self.statusText.length ? 1 : 0);
		if (path.row == 1 && self.statusText.length){
			UITableViewCell *status = [[UITableViewCell alloc]
					initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
			[theme styleCell:status];
			status.textLabel.text = self.statusText;
			status.textLabel.font = TGFontCaption();
			status.textLabel.numberOfLines = 0;
			status.textLabel.textColor = self.statusTone == 2
					? [theme destructiveColour]
					: (self.statusTone == 1 ? [theme accentColour]
										   : [theme secondaryTextColour]);
			status.selectionStyle = UITableViewCellSelectionStyleNone;
			status.accessoryType = UITableViewCellAccessoryNone;
			return status;
		}
		UITableViewCell *cell = [[UITableViewCell alloc]
				initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
		[theme styleCell:cell];
		cell.textLabel.font = TGFontRow();
		cell.detailTextLabel.font = TGFontBody();
		cell.detailTextLabel.textColor = [theme cellDetailColour];
		if (path.row == 0){
			// The official field is inline, with t.me/ as a fixed prefix, not
			// an alert that hides what the link will look like.
			cell.textLabel.text = nil;
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			cell.accessoryType = UITableViewCellAccessoryNone;
			UILabel *prefix = [[UILabel alloc] initWithFrame:
					CGRectMake(kUsernameFieldInset, 0, kUsernamePrefixWidth,
							kUsernameFieldHeight)];
			prefix.font = TGFontRow();
			prefix.textColor = [theme secondaryTextColour];
			prefix.backgroundColor = [UIColor clearColor];
			prefix.text = @"t.me/";
			[cell.contentView addSubview:prefix];
			UITextField *field = [[UITextField alloc] initWithFrame:
					CGRectMake(kUsernameFieldInset + kUsernamePrefixWidth, 0,
							cell.contentView.bounds.size.width -
									kUsernameFieldInset - kUsernamePrefixWidth -
									kUsernameFieldInset,
							kUsernameFieldHeight)];
			field.font = TGFontRow();
			field.textColor = [theme primaryTextColour];
			field.placeholder = @"username";
			field.text = self.editable;
			field.autocapitalizationType = UITextAutocapitalizationTypeNone;
			field.autocorrectionType = UITextAutocorrectionTypeNo;
			field.returnKeyType = UIReturnKeyDone;
			field.delegate = self;
			[field addTarget:self action:@selector(usernameChanged:)
					forControlEvents:UIControlEventEditingChanged];
			[cell.contentView addSubview:field];
			self.inlineField = field;
		} else if (path.row == removeRow) {
			cell.textLabel.text = @"Remove";
			cell.textLabel.textColor = [theme destructiveColour];
			cell.textLabel.textAlignment = NSTextAlignmentCenter;
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		return cell;
	}

	BOOL isActive = path.section == 1;
	NSString *username = isActive ? self.active[(NSUInteger)path.row]
								 : self.disabled[(NSUInteger)path.row];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"username"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"username"];
	[theme styleCell:cell];
	cell.textLabel.text = [@"@" stringByAppendingString:username];
	cell.textLabel.font = TGFontRow();
	cell.textLabel.textColor = [theme primaryTextColour];
	cell.detailTextLabel.font = TGFontCaption();
	cell.detailTextLabel.textColor = [theme secondaryTextColour];
	cell.detailTextLabel.text = isActive
			? ([username isEqualToString:self.editable] ? @"Primary" : @"Active")
			: @"Disabled";
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.showsReorderControl = isActive;

	TGUsernameSwitch *toggle = [[TGUsernameSwitch alloc] init];
	toggle.username = username;
	toggle.on = isActive;
	// The editable name cannot be switched off; Telegram refuses it and the
	// switch says so before the request is sent.
	toggle.enabled = !(isActive && [username isEqualToString:self.editable]) && !self.busy;
	[toggle addTarget:self action:@selector(usernameSwitchChanged:)
	 forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)path {
	// Editing here is ordering only: a username is removed by switching it
	// off or by changing the editable name, not by deleting a row.
	return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)path {
	return path.section == 1 && self.active.count > 1;
}

- (void)tableView:(UITableView *)tableView
		moveRowAtIndexPath:(NSIndexPath *)from
			  toIndexPath:(NSIndexPath *)to
{
	NSArray *before = [self.active copy];
	NSString *name = self.active[(NSUInteger)from.row];
	[self.active removeObjectAtIndex:(NSUInteger)from.row];
	[self.active insertObject:name atIndex:(NSUInteger)to.row];
	[self saveOrderRestoring:before];
}

- (void)saveOrderRestoring:(NSArray *)before {
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] reorderActiveUsernames:self.active
			completion:^(BOOL ok, NSString *error){
		TGUsernameSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.busy = NO;
		if (!ok){
			me.active = [before mutableCopy];
			[me.tableView reloadData];
			[TGAlertSheet showMessage:(error ?: @"An error occurred.")
								title:@"Username Order" inView:me.view];
			return;
		}
		[me load];
	}];
}

- (void)usernameSwitchChanged:(TGUsernameSwitch *)sender {
	if (self.busy){
		sender.on = !sender.on;
		return;
	}
	NSString *username = sender.username;
	BOOL on = sender.on;
	self.busy = YES;
	sender.enabled = NO;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] toggleUsernameIsActive:username isActive:on
			completion:^(BOOL ok, NSString *error){
		TGUsernameSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.busy = NO;
		if (!ok){
			sender.on = !on;
			sender.enabled = YES;
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
	if (path.section != 0)
		return;
	[tableView deselectRowAtIndexPath:path animated:YES];
	NSInteger removeRow = 1 + (self.statusText.length ? 1 : 0);
	if (self.editable.length && path.row == removeRow){
		[self removeUsername];
		return;
	}
	if (path.row == 0)
		[self.inlineField becomeFirstResponder];
}

- (void)updateStatusText:(NSString *)text tone:(NSInteger)tone {
	BOOL had = self.statusText.length > 0;
	BOOL has = text.length > 0;
	self.statusText = text;
	self.statusTone = tone;
	if (!self.isViewLoaded || had == has){
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
- (void)usernameChanged:(UITextField *)field {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(checkUsernameNow) object:nil];
	NSString *typed = TGUsernameNormalized(field.text);
	if (!TGUsernameShouldCheck(typed, self.editable)){
		[self updateStatusText:nil tone:0];
		return;
	}
	[self updateStatusText:TGUsernameAvailabilityText(@"checking", typed) tone:0];
	[self performSelector:@selector(checkUsernameNow) withObject:nil afterDelay:0.5];
}

- (void)checkUsernameNow {
	NSString *typed = TGUsernameNormalized(self.inlineField.text);
	if (!TGUsernameShouldCheck(typed, self.editable))
		return;
	__weak typeof(self) weakSelf = self;
	// A user account checks its own name, which TDLib spells as chat_id 0.
	[[TGClient shared] checkUsername:typed forChat:0 completion:^(NSString *result){
		TGUsernameSettingsViewController *me = weakSelf;
		if (!me)
			return;
		NSString *current = TGUsernameNormalized(me.inlineField.text);
		if (!TGUsernameAnswerStillApplies(typed, current))
			return;
		NSInteger tone = [result isEqualToString:@"ok"] ? 1
				: ([result isEqualToString:@"checking"] ? 0 : 2);
		[me updateStatusText:TGUsernameAvailabilityText(result, typed) tone:tone];
	}];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(checkUsernameNow) object:nil];
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(checkUsernameNow) object:nil];
	NSString *typed = TGUsernameNormalized(textField.text);
	if (!TGUsernameShouldCheck(typed, self.editable))
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setUsername:typed completion:^(BOOL ok){
		if (!ok){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Username" inView:weakSelf.view];
			[weakSelf.tableView reloadData];
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
		[[TGClient shared] setUsername:@"" completion:^(BOOL ok){
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
