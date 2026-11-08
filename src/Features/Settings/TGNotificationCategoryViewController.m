//
// TGNotificationCategoryViewController.m
//
// The official per-category notifications page (NotificationsPeerCategory-
// Controller.swift): one switch for the scope, the display options that TDLib
// keeps on the scope record, and the exceptions list. Add/delete exception
// actions have no client call in this build; the list still shows what the
// account overrides today.
//
#import "TGNotificationCategoryViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGTableViewCell.h"
#import "TGSettingsFormatting.h"

@interface TGNotificationCategoryViewController ()
@property (nonatomic, copy) NSString *scope;
@property (nonatomic, copy) NSString *categoryTitle;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL preview;
@property (nonatomic, strong) NSArray *exceptions;
/// Built when an answer arrives, never in cellForRow:.
@property (nonatomic, strong) NSArray *sections;
@end

@implementation TGNotificationCategoryViewController

- (instancetype)initWithScope:(NSString *)scope title:(NSString *)title {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self){
		_scope = [scope copy];
		_categoryTitle = [title copy];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.categoryTitle;
	[self applyTheme];
	[self rebuildSections];
	[self load];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(themeChanged:)
				name:TGThemeChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(notificationSettingsChanged)
				name:TGNotificationSettingsChangedNotification object:nil];
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)applyTheme {
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)themeChanged:(NSNotification *)note {
	[self applyTheme];
	[self.tableView reloadData];
}

- (void)notificationSettingsChanged {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(load) object:nil];
	[self performSelector:@selector(load) withObject:nil afterDelay:0.3];
}

- (void)load {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] notificationsMutedForScope:self.scope
									   completion:^(BOOL muted){
		TGNotificationCategoryViewController *me = weakSelf;
		if (!me)
			return;
		me.enabled = !muted;
		[me rebuildSections];
	}];
	[[TGClient shared] notificationPreviewForScope:self.scope
										completion:^(BOOL show){
		TGNotificationCategoryViewController *me = weakSelf;
		if (!me)
			return;
		me.preview = show;
		[me rebuildSections];
	}];
	[[TGClient shared] notificationExceptionsWithCompletion:^(NSArray *chats){
		TGNotificationCategoryViewController *me = weakSelf;
		if (!me)
			return;
		// The client asks once for every scope; this page keeps the chats
		// that belong to its own category.
		me.exceptions = TGNotificationExceptionsForScope(chats, me.scope);
		[me rebuildSections];
	}];
}

#pragma mark - sections

- (NSDictionary *)rowAt:(NSIndexPath *)path {
	if (path.section >= (NSInteger)self.sections.count)
		return nil;
	NSArray *rows = self.sections[(NSUInteger)path.section][@"rows"];
	return path.row < (NSInteger)rows.count ? rows[(NSUInteger)path.row] : nil;
}

- (void)rebuildSections {
	NSMutableArray *sections = [NSMutableArray array];
	[sections addObject:@{@"rows" : @[
		@{@"kind" : @"switch", @"title" : @"Notifications", @"on" : @(self.enabled),
		  @"tag" : @0},
	]}];

	if (self.enabled || self.exceptions.count){
		[sections addObject:@{@"header" : @"Options", @"rows" : @[
			@{@"kind" : @"switch", @"title" : @"Message Preview",
			  @"on" : @(self.preview), @"tag" : @1},
			// The scope record's sound id is not exposed by the client's
			// scope setters, so this row names Telegram's default and keeps
			// the position official gives it.
			@{@"kind" : @"value", @"title" : @"Sound",
			  @"detail" : TGLocalized(@"Default")},
		]}];
	}

	NSMutableArray *exceptionRows = [NSMutableArray array];
	for (NSDictionary *chat in self.exceptions){
		[exceptionRows addObject:@{
			@"kind" : @"peer",
			@"title" : chat[@"title"] ?: @"Chat",
			@"detail" : TGNotificationExceptionDetail(chat),
			@"chatId" : chat[@"id"] ?: @0,
		}];
	}
	[sections addObject:@{@"header" : @"EXCEPTIONS",
						  @"rows" : exceptionRows}];
	self.sections = sections;
	[self.tableView reloadData];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)[self.sections[(NSUInteger)section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSString *header = self.sections[(NSUInteger)section][@"header"];
	return header.length ? header : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)path {
	NSDictionary *row = [self rowAt:path];
	TGTheme *theme = [TGTheme shared];
	NSString *kind = row[@"kind"];

	if ([kind isEqualToString:@"peer"]){
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"peer"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
										  reuseIdentifier:@"peer"];
		[theme styleCell:cell];
		cell.textLabel.text = row[@"title"];
		cell.textLabel.font = TGFontRow();
		cell.textLabel.textColor = [theme primaryTextColour];
		cell.detailTextLabel.text = row[@"detail"];
		cell.detailTextLabel.font = TGFontCaption();
		cell.detailTextLabel.textColor = [theme secondaryTextColour];
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}

	TGTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"value"];
	if (!cell)
		cell = [TGTableViewCell cellWithStyle:TGTableCellKindValue1 reuseIdentifier:@"value"];
	cell.title = row[@"title"];
	cell.detail = row[@"detail"];

	__weak typeof(self) weakSelf = self;
	if ([kind isEqualToString:@"switch"]){
		[cell setSwitchOn:[row[@"on"] boolValue] onToggle:^(BOOL on){
			if ([row[@"tag"] integerValue] == 0){
				weakSelf.enabled = on;
				[[TGClient shared] setScope:weakSelf.scope muted:!on];
			} else {
				weakSelf.preview = on;
				[[TGClient shared] setScope:weakSelf.scope showPreview:on];
			}
			[weakSelf rebuildSections];
		}];
	} else {
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	return cell;
}

- (void)toggleChanged:(UISwitch *)sender {
	if (sender.tag == 0){
		self.enabled = sender.on;
		[[TGClient shared] setScope:self.scope muted:!sender.on];
	} else {
		self.preview = sender.on;
		[[TGClient shared] setScope:self.scope showPreview:sender.on];
	}
	[self rebuildSections];
}

@end
