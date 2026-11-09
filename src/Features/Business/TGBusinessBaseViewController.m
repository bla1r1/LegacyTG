#import "TGBusinessBaseViewController.h"
#import "TGBusinessViewController.h"
#import "TGAlertSheet.h"
#import "TGRows.h"

//
// TGBusinessBaseViewController.m - the shared list screen for the Business
// pages. Subclasses still describe rows with TGBusinessRows; the base turns
// them into the app's TGRows so one cell family draws every page.
//

@implementation TGBusinessBaseViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.sections = @[];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)applyTheme {
	[super applyTheme];
}

- (void)rebuild {
	[self reloadRows];
}

/// Subclasses hand over TGBusinessRows dictionaries. Copy their own keys
/// (action, switch, link) onto the TGRows row and attach the callbacks; the
/// business "kind" is an NSNumber and must not overwrite TGRowKind.
- (void)setSections:(NSArray *)sections {
	NSMutableArray *converted = [NSMutableArray arrayWithCapacity:sections.count];
	for (NSDictionary *section in sections){
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *row in section[@"rows"] ?: @[])
			[rows addObject:[self tgRowForBusinessRow:row]];
		[converted addObject:TGSection(section[@"header"], section[@"footer"], rows)];
	}
	[super setSections:converted];
}

- (NSDictionary *)tgRowForBusinessRow:(NSDictionary *)business {
	if ([business[TGRowKind] isKindOfClass:NSString.class])
		return business;

	TGBusinessRowKind kind = (TGBusinessRowKind)[business[@"kind"] integerValue];
	NSString *title = business[@"title"] ?: @"";
	NSString *detail = business[@"detail"];
	NSString *action = business[@"action"];
	BOOL opens = [business[@"opens"] boolValue];
	__weak typeof(self) weakSelf = self;

	NSMutableDictionary *row = nil;
	if (kind == TGBusinessRowSwitch){
		NSString *key = business[@"switch"];
		void (^changed)(BOOL) = ^(BOOL on){
			[weakSelf toggleKey:key on:on sender:nil];
		};
		if (detail.length){
			row = [TGSwitchInfoRow(title, detail, business[@"icon"],
					business[@"colour"], [business[@"on"] boolValue], changed)
					mutableCopy];
		} else {
			row = [TGSwitchRow(title, [business[@"on"] boolValue], changed)
					mutableCopy];
		}
		row[TGRowEnabled] = business[@"enabled"] ?: @YES;
	} else if (kind == TGBusinessRowDestructive){
		row = [TGRedRow(title, action
				? ^{ [weakSelf didChooseAction:action row:business]; }
				: nil) mutableCopy];
	} else if (action){
		void (^tap)(void) = ^{ [weakSelf didChooseAction:action row:business]; };
		row = (opens ? [TGOpenRow(title, detail, tap) mutableCopy]
				: [TGTapRow(title, detail, tap) mutableCopy]);
	} else {
		row = [TGTapRow(title, detail, nil) mutableCopy];
	}

	if (business[@"icon"])
		row[TGRowIcon] = business[@"icon"];
	if (business[@"colour"])
		row[TGRowColour] = business[@"colour"];
	return row;
}

- (NSDictionary *)rowAt:(NSIndexPath *)path {
	if (path.section >= (NSInteger)self.sections.count)
		return nil;
	NSArray *rows = self.sections[(NSUInteger)path.section][@"rows"];
	return path.row < (NSInteger)rows.count ? rows[(NSUInteger)path.row] : nil;
}

- (void)showResult:(BOOL)ok error:(NSString *)error title:(NSString *)title {
	NSString *text = ok ? @"Done"
			: (error.length ? error : @"An error occurred.");
	[self showMessage:text title:title];
}

- (void)showMessage:(NSString *)message title:(NSString *)title {
	[TGAlertSheet showMessage:message title:title inView:self.view];
}

- (void)askText:(NSString *)title
		message:(NSString *)message
	placeholder:(NSString *)placeholder
		   text:(NSString *)text
		 action:(NSString *)action
	 completion:(void (^)(NSString *))completion {
	[TGAlertSheet showInput:title message:message placeholder:placeholder
					   text:text action:action inView:self.view
				 onSubmit:completion];
}

- (void)didChooseAction:(NSString *)action row:(NSDictionary *)row {}
- (void)toggleKey:(NSString *)key on:(BOOL)on sender:(UISwitch *)sender {}

@end
