//
// TGFeatureListViewController.m
//
#import "TGFeatureListViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGSnackbar.h"

NSString *const TGFeatureRowTitle       = @"title";
NSString *const TGFeatureRowDetail      = @"detail";
NSString *const TGFeatureRowKind        = @"kind";
NSString *const TGFeatureRowTap         = @"tap";
NSString *const TGFeatureRowChecked     = @"checked";
NSString *const TGFeatureRowSubtitle    = @"subtitle";
NSString *const TGFeatureRowDestructive = @"destructive";
NSString *const TGFeatureRowOpens       = @"opens";

NSString *const TGFeatureKindPlain       = @"plain";
NSString *const TGFeatureKindDisclosure  = @"disclosure";
NSString *const TGFeatureKindCheck       = @"check";
NSString *const TGFeatureKindAction      = @"action";
NSString *const TGFeatureKindDestructive = @"destructive";

NSMutableDictionary *TGFeatureRow(NSString *title, NSString *detail, void (^tap)(void)) {
	NSMutableDictionary *row = [@{TGFeatureRowKind  : TGFeatureKindDisclosure,
								  TGFeatureRowTitle : title ?: @""} mutableCopy];
	if (detail.length)
		row[TGFeatureRowDetail] = detail;
	if (tap)
		row[TGFeatureRowTap] = [tap copy];
	return row;
}

NSMutableDictionary *TGFeatureOpenRow(NSString *title, NSString *detail, void (^tap)(void)) {
	NSMutableDictionary *row = TGFeatureRow(title, detail, tap);
	row[TGFeatureRowOpens] = @YES;
	return row;
}

NSMutableDictionary *TGFeatureAction(NSString *title, void (^tap)(void)) {
	NSMutableDictionary *row = [@{TGFeatureRowKind  : TGFeatureKindAction,
								  TGFeatureRowTitle : title ?: @""} mutableCopy];
	if (tap)
		row[TGFeatureRowTap] = [tap copy];
	return row;
}

NSMutableDictionary *TGFeatureCheck(NSString *title, NSString *detail, BOOL checked,
								  void (^tap)(void)) {
	NSMutableDictionary *row = [@{TGFeatureRowKind    : TGFeatureKindCheck,
								  TGFeatureRowTitle   : title ?: @"",
								  TGFeatureRowChecked : @(checked)} mutableCopy];
	if (detail.length)
		row[TGFeatureRowDetail] = detail;
	if (tap)
		row[TGFeatureRowTap] = [tap copy];
	return row;
}

NSDictionary *TGFeatureSection(NSString *header, NSString *footer, NSArray *rows) {
	NSMutableDictionary *section = [NSMutableDictionary dictionary];
	if (header) section[@"header"] = header;
	if (footer) section[@"footer"] = footer;
	section[@"rows"] = rows ?: @[];
	return section;
}

@interface TGFeatureListViewController ()
@end

@implementation TGFeatureListViewController

- (id)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[self applyTheme];
}

- (void)applyTheme {
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self.tableView reloadData];
}

- (void)reloadRows {
	[self.tableView reloadData];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)[self.sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return self.sections[section][@"header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return self.sections[section][@"footer"];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view
	   forSection:(NSInteger)section {
	// The system's grouped header is left as it is: it follows the table's
	// style, and a hand-painted one was what the token lint exists to stop.
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = self.sections[indexPath.section][@"rows"][indexPath.row];
	NSString *kind = row[TGFeatureRowKind] ?: TGFeatureKindPlain;
	BOOL subtitle = [row[TGFeatureRowSubtitle] boolValue];
	NSString *ident = subtitle ? @"subtitle" : (kind ?: @"plain");
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
	if (!cell){
		cell = [[UITableViewCell alloc] initWithStyle:(subtitle
				? UITableViewCellStyleSubtitle : UITableViewCellStyleValue1)
									  reuseIdentifier:ident];
	}
	cell.textLabel.text = row[TGFeatureRowTitle];
	cell.detailTextLabel.text = row[TGFeatureRowDetail];
	cell.detailTextLabel.numberOfLines = subtitle ? 2 : 1;
	cell.textLabel.textColor = [kind isEqualToString:TGFeatureKindDestructive]
			? [[TGTheme shared] destructiveColour] : [[TGTheme shared] primaryTextColour];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleDefault;
	if ([kind isEqualToString:TGFeatureKindCheck])
		cell.accessoryType = [row[TGFeatureRowChecked] boolValue]
				? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	else if ([kind isEqualToString:TGFeatureKindDisclosure])
		cell.accessoryType = [row[TGFeatureRowOpens] boolValue]
				? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
	else if ([kind isEqualToString:TGFeatureKindAction])
		cell.textLabel.textColor = [[TGTheme shared] accentColour];

	if (row[TGFeatureRowTap] == nil) {
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = self.sections[indexPath.section][@"rows"][indexPath.row];
	void (^tap)(void) = row[TGFeatureRowTap];
	if (!tap)
		return;
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	tap();
}

@end

#pragma mark - result screen

@interface TGFeatureResultViewController ()
@property (nonatomic, strong) UITextView *textView;
@end

@implementation TGFeatureResultViewController

- (instancetype)initWithTitle:(NSString *)title body:(NSString *)body {
	self = [super initWithNibName:nil bundle:nil];
	if (!self)
		return nil;
	self.title = title;
	_body = [body copy];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.view.backgroundColor = [[TGTheme shared] groupedBackgroundColour];

	self.textView = [[UITextView alloc] initWithFrame:UIEdgeInsetsInsetRect(
			self.view.bounds, UIEdgeInsetsMake(TGMetricPadLarge, TGMetricPadLarge,
											   TGMetricPadLarge, TGMetricPadLarge))];
	self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
									 UIViewAutoresizingFlexibleHeight;
	self.textView.editable = NO;
	self.textView.font = TGFontBody();
	self.textView.textColor = [[TGTheme shared] primaryTextColour];
	self.textView.backgroundColor = [[TGTheme shared] cardBackgroundColour];
	self.textView.text = self.body ?: @"";
	[self.view addSubview:self.textView];

	__weak typeof(self) weakSelf = self;
	UIBarButtonItem *copy = [[UIBarButtonItem alloc] initWithTitle:@"Copy"
			style:UIBarButtonItemStyleBordered
		   target:self action:@selector(copyText)];
	self.navigationItem.rightBarButtonItem = copy;
	if (self.onSend){
		UIBarButtonItem *send = [[UIBarButtonItem alloc] initWithTitle:@"Send"
				style:UIBarButtonItemStyleDone
			   target:self action:@selector(sendText)];
		self.navigationItem.rightBarButtonItems = @[send, copy];
	}
	(void)weakSelf;
}

- (void)copyText {
	[UIPasteboard generalPasteboard].string = self.textView.text ?: @"";
	UIView *host = self.navigationController.view ?: self.view;
	[TGSnackbar showInView:host text:@"Copied to clipboard." seconds:2 onCommit:nil];
}

- (void)sendText {
	if (self.onSend)
		self.onSend(self.textView.text ?: @"");
	[self.navigationController popViewControllerAnimated:YES];
}

@end
