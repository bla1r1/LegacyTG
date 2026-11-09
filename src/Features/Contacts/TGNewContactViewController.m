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
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGIcons.h"
#import "TGRows.h"

@interface TGNewContactViewController ()
@property (nonatomic, copy) NSString *firstText;
@property (nonatomic, copy) NSString *lastText;
@property (nonatomic, copy) NSString *phoneText;
@property (nonatomic, strong) UIBarButtonItem *doneItem;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL saving;
@end

@implementation TGNewContactViewController

- (instancetype)init {
	return [super init];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	// A caller that names the screen (Edit, or a form opened from a profile)
	// keeps that title; only an unnamed form is a New Contact.
	if (!self.title.length)
		self.title = @"New Contact";

	self.firstText = self.first ?: @"";
	self.lastText = self.last ?: @"";
	self.phoneText = self.phone ?: @"";

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

	__weak typeof(self) weakSelf = self;
	NSMutableDictionary *first = TGFieldRow(TGLocalized(@"First Name"),
			self.firstText, ^(NSString *text){
		weakSelf.firstText = text;
		[weakSelf updateDoneState];
	});
	first[TGRowFieldIdentifier] = @"first";
	first[TGRowFieldClear] = @YES;
	first[TGRowFieldReturnKey] = @(UIReturnKeyNext);
	first[TGRowFieldReturn] = ^{
		[weakSelf focusFieldWithIdentifier:@"last"];
	};

	NSMutableDictionary *last = TGFieldRow(TGLocalized(@"Last Name"),
			self.lastText, ^(NSString *text){
		weakSelf.lastText = text;
		[weakSelf updateDoneState];
	});
	last[TGRowFieldIdentifier] = @"last";
	last[TGRowFieldClear] = @YES;
	last[TGRowFieldReturnKey] = @(UIReturnKeyNext);
	last[TGRowFieldReturn] = ^{
		[weakSelf focusFieldWithIdentifier:@"phone"];
	};

	NSMutableDictionary *phone = TGFieldRow(TGLocalized(@"Phone number"),
			self.phoneText, ^(NSString *text){
		weakSelf.phoneText = text;
		[weakSelf updateDoneState];
	});
	phone[TGRowFieldIdentifier] = @"phone";
	phone[TGRowFieldKeyboard] = @(UIKeyboardTypePhonePad);
	phone[TGRowFieldClear] = @YES;
	phone[TGRowFieldReturn] = ^{
		[weakSelf.view endEditing:YES];
	};

	self.sections = @[
		TGSection(nil, nil, @[first, last]),
		TGSection(nil, nil, @[phone]),
	];
	// The form's two cards keep the old 10 pt breath above them.
	self.tableView.sectionHeaderHeight = TGMetricPadMedium;
	[self updateDoneState];
	[self.tableView reloadData];

	[self focusFieldWithIdentifier:self.firstText.length ? @"phone" : @"first"];
}

- (void)closeTapped {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (NSString *)phoneDigits {
	NSString *phone = self.phoneText ?: @"";
	return [phone stringByReplacingOccurrencesOfString:@"\\D" withString:@""
			options:NSRegularExpressionSearch
			range:NSMakeRange(0, phone.length)];
}

/// Telegram keeps Done inactive until there is a name and a number it could
/// dial; a disabled button says that without nagging in a sheet.
- (void)updateDoneState {
	BOOL ready = self.firstText.length > 0 && [self phoneDigits].length >= 5;
	self.doneItem.enabled = ready && !self.saving;
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
	NSString *first = [self.firstText stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *last  = [self.lastText stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *phone = self.phoneText ?: @"";

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
