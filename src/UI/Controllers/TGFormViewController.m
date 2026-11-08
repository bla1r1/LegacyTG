#import "TGFormViewController.h"
#import "TGTableViewCell.h"
#import "TGTheme.h"
#import "TGStyle.h"

@implementation TGFormRow

+ (instancetype)rowWithTitle:(NSString *)title detail:(NSString *)detail onSelect:(void (^)(void))onSelect {
	TGFormRow *r = [[self alloc] init];
	r.title = title;
	r.detail = detail;
	r.onSelect = onSelect;
	return r;
}

+ (instancetype)disclosureWithTitle:(NSString *)title detail:(NSString *)detail onSelect:(void (^)(void))onSelect {
	TGFormRow *r = [self rowWithTitle:title detail:detail onSelect:onSelect];
	r.disclosure = YES;
	return r;
}

+ (instancetype)switchWithTitle:(NSString *)title value:(BOOL)val onToggle:(void (^)(BOOL on))onToggle {
	TGFormRow *r = [[self alloc] init];
	r.title = title;
	r.isSwitch = YES;
	r.switchValue = val;
	r.onToggle = onToggle;
	return r;
}

+ (instancetype)checkWithTitle:(NSString *)title checked:(BOOL)checked onSelect:(void (^)(void))onSelect {
	TGFormRow *r = [[self alloc] init];
	r.title = title;
	r.checked = checked;
	r.onSelect = onSelect;
	return r;
}

+ (instancetype)actionWithTitle:(NSString *)title destructive:(BOOL)destructive onSelect:(void (^)(void))onSelect {
	TGFormRow *r = [[self alloc] init];
	r.title = title;
	r.destructive = destructive;
	r.onSelect = onSelect;
	return r;
}

@end

@implementation TGFormSection

+ (instancetype)sectionWithHeader:(NSString *)header rows:(NSArray<TGFormRow *> *)rows {
	return [self sectionWithHeader:header footer:nil rows:rows];
}

+ (instancetype)sectionWithHeader:(NSString *)header footer:(NSString *)footer rows:(NSArray<TGFormRow *> *)rows {
	TGFormSection *s = [[self alloc] init];
	s.header = header;
	s.footer = footer;
	s.rows = rows ?: @[];
	return s;
}

@end

@implementation TGFormViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.sections = self.sections ?: @[];
}

- (void)reloadSections {
	[self.tableView reloadData];
}

#pragma mark - Table Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section >= (NSInteger)self.sections.count) return 0;
	return (NSInteger)self.sections[section].rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section >= (NSInteger)self.sections.count) return nil;
	return self.sections[section].header;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section >= (NSInteger)self.sections.count) return nil;
	return self.sections[section].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellId = @"TGFormCell";
	TGTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
	if (!cell) {
		cell = [TGTableViewCell cellWithStyle:TGTableCellKindValue1 reuseIdentifier:cellId];
	}

	TGFormRow *row = self.sections[indexPath.section].rows[indexPath.row];
	cell.title = row.title;
	cell.detail = row.detail;
	cell.destructive = row.destructive;
	cell.checked = row.checked;
	cell.showsDisclosure = row.disclosure;

	if (row.isSwitch) {
		[cell setSwitchOn:row.switchValue onToggle:row.onToggle];
	}

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section >= (NSInteger)self.sections.count) return;
	TGFormRow *row = self.sections[indexPath.section].rows[indexPath.row];
	if (row.onSelect) {
		row.onSelect();
	}
}

@end
