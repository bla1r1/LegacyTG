//
// TGNewContactViewController - the three fields a new contact is made of:
// a name for you to read and a number for Telegram to match on. The import
// makes the user when Telegram has never met the number, and the contact is
// what adds them.
//
#import <UIKit/UIKit.h>
#import "TGNewContactViewController.h"

#import "TGClient.h"
#import "TGTheme.h"
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGIcons.h"

@interface TGNewContactFieldCell : UITableViewCell
@property (nonatomic, strong) UITextField *field;
- (void)configureWithPlaceholder:(NSString *)placeholder
							text:(NSString *)text
						delegate:(id<UITextFieldDelegate>)delegate
						keyboard:(UIKeyboardType)keyboard;
@end

@implementation TGNewContactFieldCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
			   reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect b = self.contentView.bounds;
	CGFloat inset = TGMetricGutter;
	_field.frame = CGRectMake(inset, 0, MAX(0, b.size.width - TGDoubled(inset)),
			b.size.height);
}

- (void)configureWithPlaceholder:(NSString *)placeholder
							text:(NSString *)text
						delegate:(id<UITextFieldDelegate>)delegate
						keyboard:(UIKeyboardType)keyboard {
	_field.delegate = delegate;
	_field.font = TGFontRow();
	_field.returnKeyType = UIReturnKeyDone;
	_field.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	_field.text = [text isKindOfClass:NSString.class] ? text : @"";
	_field.keyboardType = keyboard;
	_field.textColor = [[TGTheme shared] primaryTextColour];
	_field.keyboardAppearance = UIKeyboardAppearanceDefault;
	_field.attributedPlaceholder = [[NSAttributedString alloc]
			initWithString:placeholder
				attributes:@{NSForegroundColorAttributeName:
							 [[TGTheme shared] secondaryTextColour]}];
	if (_field.superview != self.contentView)
		[self.contentView addSubview:_field];
	[self setNeedsLayout];
}

@end

@interface TGNewContactViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *firstField;
@property (nonatomic, strong) UITextField *lastField;
@property (nonatomic, strong) UITextField *phoneField;
@property (nonatomic, strong) UIBarButtonItem *doneItem;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL saving;
@end

@implementation TGNewContactViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	// A caller that names the screen (Edit, or a form opened from a profile)
	// keeps that title; only an unnamed form is a New Contact.
	if (!self.title.length)
		self.title = @"New Contact";
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.doneItem = [[UIBarButtonItem alloc]
			initWithImage:[TGIcons glyphNamed:@"checkboxSelected"
									   colour:[[TGTheme shared] accentColour]
										 side:TGMetricMenuGlyph]
			style:UIBarButtonItemStylePlain
		   target:self action:@selector(save)];
	self.navigationItem.rightBarButtonItem = self.doneItem;
	// The form is modal, as official presents it: Close on the left, the
	// Done check on the right, and no back chevron from a stack.
	if (self.navigationController.viewControllers.firstObject == self){
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
				initWithTitle:@"Close" style:UIBarButtonItemStylePlain
					   target:self action:@selector(closeTapped)];
	}

	self.firstField = [self fieldWithPlaceholder:TGLocalized(@"First Name") text:self.first];
	self.lastField  = [self fieldWithPlaceholder:TGLocalized(@"Last Name")  text:self.last];
	self.phoneField = [self fieldWithPlaceholder:TGLocalized(@"Phone number") text:self.phone];
	self.phoneField.keyboardType = UIKeyboardTypePhonePad;
	for (UITextField *field in @[self.firstField, self.lastField, self.phoneField])
		[field addTarget:self action:@selector(fieldChanged:)
		forControlEvents:UIControlEventEditingChanged];
	[self updateDoneState];

	if (self.firstField.text.length)
		[self.phoneField becomeFirstResponder];
	else
		[self.firstField becomeFirstResponder];

	[self applyTheme];

	__weak typeof(self) weakSelf = self;
	[[NSNotificationCenter defaultCenter] addObserverForName:TGThemeChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note) {
		[weakSelf applyTheme];
		[weakSelf.tableView reloadData];
	}];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)closeTapped {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)applyTheme {
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	if (self.firstField) {
		self.firstField.textColor = [[TGTheme shared] primaryTextColour];
		self.firstField.keyboardAppearance = UIKeyboardAppearanceDefault;
	}
	if (self.lastField) {
		self.lastField.textColor = [[TGTheme shared] primaryTextColour];
		self.lastField.keyboardAppearance = UIKeyboardAppearanceDefault;
	}
	if (self.phoneField) {
		self.phoneField.textColor = [[TGTheme shared] primaryTextColour];
		self.phoneField.keyboardAppearance = UIKeyboardAppearanceDefault;
	}
}

- (UITextField *)fieldWithPlaceholder:(NSString *)placeholder text:(NSString *)text {
	UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
	field.text = [text isKindOfClass:NSString.class] ? text : @"";
	field.font = TGFontRow();
	field.delegate = self;
	field.returnKeyType = UIReturnKeyDone;
	field.keyboardAppearance = UIKeyboardAppearanceDefault;
	field.textColor = [[TGTheme shared] primaryTextColour];
	field.attributedPlaceholder = [[NSAttributedString alloc]
			initWithString:placeholder
				attributes:@{NSForegroundColorAttributeName:
							 [[TGTheme shared] secondaryTextColour]}];
	return field;
}

- (NSString *)phoneDigits {
	NSString *phone = self.phoneField.text ?: @"";
	return [phone stringByReplacingOccurrencesOfString:@"\\D" withString:@""
			options:NSRegularExpressionSearch
			range:NSMakeRange(0, phone.length)];
}

/// Telegram keeps Done inactive until there is a name and a number it could
/// dial; a disabled button says that without nagging in a sheet.
- (void)updateDoneState {
	BOOL ready = self.firstField.text.length > 0 && [self phoneDigits].length >= 5;
	self.doneItem.enabled = ready && !self.saving;
}

- (void)fieldChanged:(UITextField *)field {
	[self updateDoneState];
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
	if (field == self.firstField)
		[self.lastField becomeFirstResponder];
	else if (field == self.lastField)
		[self.phoneField becomeFirstResponder];
	else
		[field resignFirstResponder];
	return YES;
}

#pragma mark - the table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return section == 0 ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 0)
		return nil;
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return TGMetricPadMedium;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
	if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
		UITableViewHeaderFooterView *sectionHeader = (UITableViewHeaderFooterView *)view;
		sectionHeader.textLabel.font = TGFontMetaStrong();
		sectionHeader.textLabel.textColor = [[TGTheme shared] sectionHeaderColour];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *first = @"TGNewContactFirst";
	static NSString *last = @"TGNewContactLast";
	static NSString *phone = @"TGNewContactPhone";
	NSString *reuse = indexPath.section == 0
			? (indexPath.row == 0 ? first : last) : phone;
	TGNewContactFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGNewContactFieldCell alloc] initWithStyle:UITableViewCellStyleDefault
											 reuseIdentifier:reuse];

	UITextField *field = indexPath.section == 0
			? (indexPath.row == 0 ? self.firstField : self.lastField)
			: self.phoneField;
	cell.field = field;
	if (indexPath.section == 0)
		[cell configureWithPlaceholder:(indexPath.row == 0
					? TGLocalized(@"First Name") : TGLocalized(@"Last Name"))
								  text:field.text
							  delegate:self
							  keyboard:UIKeyboardTypeDefault];
	else
		[cell configureWithPlaceholder:TGLocalized(@"Phone number")
								  text:field.text
							  delegate:self
							  keyboard:UIKeyboardTypePhonePad];
	cell.backgroundColor = [[TGTheme shared] cardBackgroundColour];
	cell.contentView.backgroundColor = [[TGTheme shared] cardBackgroundColour];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	if ([cell isKindOfClass:[TGNewContactFieldCell class]])
		[((TGNewContactFieldCell *)cell).field becomeFirstResponder];
}

#pragma mark - saving

- (void)beginSaving {
	self.saving = YES;
	[self.view endEditing:YES];
	self.spinner = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	[self.spinner startAnimating];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithCustomView:self.spinner];
	[self updateDoneState];
}

- (void)endSaving {
	self.saving = NO;
	[self.spinner stopAnimating];
	self.spinner = nil;
	self.navigationItem.rightBarButtonItem = self.doneItem;
	[self updateDoneState];
}

/// The import makes the user when Telegram has never met the number; the
/// contact is what adds them, and it answers on the phone number either way.
- (void)save {
	NSString *first = [self.firstField.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *last  = [self.lastField.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *phone = self.phoneField.text ?: @"";

	if (!first.length || [self phoneDigits].length < 5){
		[TGAlertSheet showMessage:@"An error occurred."
							title:@"New Contact" inView:self.view];
		return;
	}

	[self beginSaving];
	__weak typeof(self) weakSelf = self;
	NSString *screenTitle = self.title.length ? self.title : @"New Contact";
	void (^finish)(BOOL, int64_t) = ^(BOOL ok, int64_t userId){
		TGNewContactViewController *me = weakSelf;
		if (!me)
			return;
		[me endSaving];
		if (!ok){
			[TGAlertSheet showMessage:@"An error occurred."
								title:screenTitle inView:me.view];
			return;
		}
		[TGAlertSheet showMessage:@"Done" title:screenTitle inView:me.view];
		// The form is presented modally from the contacts list and from a
		// profile; a pop on that navigation root does nothing. A pushed form
		// still goes back the way it came.
		if (me.presentingViewController &&
				me.navigationController.viewControllers.firstObject == me)
			[me dismissViewControllerAnimated:YES completion:nil];
		else
			[me.navigationController popViewControllerAnimated:YES];
	};

	// Editing an existing contact: addContact updates the name and number for
	// the user id the profile already knows. Importing by phone would create a
	// second contact instead.
	if (self.userId){
		[[TGClient shared] addContactWithUserId:self.userId
									  firstName:first
									   lastName:last
										  phone:phone
									 completion:^(BOOL ok){
			finish(ok, self.userId);
		}];
		return;
	}

	[[TGClient shared] importContactNamed:first lastName:last phone:phone
							   completion:^(int64_t userId){
		TGNewContactViewController *me = weakSelf;
		if (!me)
			return;
		// A zero id means the import answered nothing: addContact would be
		// sent with user_id 0 and Telegram would refuse a contact that has no
		// person behind it.
		if (userId == 0) {
			[me endSaving];
			[TGAlertSheet showMessage:@"An error occurred."
								title:screenTitle inView:me.view];
			return;
		}
		[[TGClient shared] addContactWithUserId:userId
									  firstName:first
									   lastName:last
										  phone:phone
									 completion:^(BOOL ok){
			finish(ok, userId);
		}];
	}];
}

@end

// vim:ft=objc
