//
// TGRowsDataSource.m
//
#import "TGRowsDataSource.h"
#import "TGRows.h"
#import "TGStyle.h"
#import "TGGridRowCell.h"
#import "TGLocalization.h"

#pragma mark - counts and heights without a table

NSInteger TGRowsDataSourceSectionCount(NSArray *sections) {
	return [sections isKindOfClass:NSArray.class] ? (NSInteger)sections.count : 0;
}

static NSDictionary *TGRowsDataSourceSectionAt(NSArray *sections, NSInteger i) {
	if (![sections isKindOfClass:NSArray.class] || i < 0 ||
			i >= (NSInteger)sections.count)
		return nil;
	id section = sections[(NSUInteger)i];
	return [section isKindOfClass:NSDictionary.class] ? section : nil;
}

NSInteger TGRowsDataSourceRowCount(NSArray *sections, NSInteger section) {
	NSArray *rows = TGRowsDataSourceSectionAt(sections, section)[@"rows"];
	return [rows isKindOfClass:NSArray.class] ? (NSInteger)rows.count : 0;
}

NSDictionary *TGRowsDataSourceRow(NSArray *sections, NSInteger section,
		NSInteger row) {
	NSArray *rows = TGRowsDataSourceSectionAt(sections, section)[@"rows"];
	if (![rows isKindOfClass:NSArray.class] || row < 0 ||
			row >= (NSInteger)rows.count)
		return nil;
	id value = rows[(NSUInteger)row];
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static BOOL TGRowsGridHasCaptions(NSDictionary *row) {
	NSArray *items = row[TGRowGridItems];
	if (![items isKindOfClass:NSArray.class])
		return NO;
	for (NSDictionary *item in items){
		if ([item isKindOfClass:NSDictionary.class] &&
				[item[TGGridItemCaption] length])
			return YES;
	}
	return NO;
}

CGFloat TGRowsDataSourceHeight(NSDictionary *row, CGFloat width) {
	if (![row isKindOfClass:NSDictionary.class])
		return TGMetricRow;
	NSNumber *height = row[TGRowHeight];
	if ([height isKindOfClass:NSNumber.class])
		return [height doubleValue];

	NSString *kind = row[TGRowKind] ?: TGKindPlain;
	if ([kind isEqualToString:TGKindPeerRow])
		return TGMetricPersonRow;
	if ([kind isEqualToString:TGKindGrid]){
		NSInteger columns = [row[TGRowGridColumns] integerValue];
		if (columns < 1)
			columns = 1;
		return TGGridRowHeightForWidth(width, columns,
				TGRowsGridHasCaptions(row));
	}
	// These cells measure their own content: a field, a caption, a picture or
	// a title that wraps. The instance method asks the class for the height.
	if ([kind isEqualToString:TGKindField] ||
			[kind isEqualToString:TGKindMultilineField] ||
			[kind isEqualToString:TGKindNote] ||
			[kind isEqualToString:TGKindPhoto] ||
			[kind isEqualToString:TGKindImageCheck] ||
			[kind isEqualToString:TGKindToggleInfo] ||
			row[TGRowTitleLines])
		return -1;
	return TGMetricRow;
}

#if TARGET_OS_IPHONE

#import "TGRowCell.h"
#import "TGPeerRowCell.h"
#import "TGFieldRowCell.h"

@interface TGRowsDataSource () <TGFieldRowCellDelegate>
@property (nonatomic, strong) NSMutableDictionary *storedFieldText;
@property (nonatomic, weak) TGFieldRowCell *activeFieldCell;
@property (nonatomic, assign) BOOL reloadingFieldRows;
@end

@implementation TGRowsDataSource

@synthesize tableView = _tableView;

- (instancetype)init {
	return [self initWithTableView:nil];
}

- (instancetype)initWithTableView:(UITableView *)tableView {
	self = [super init];
	if (self){
		_sections = @[];
		_tableView = tableView;
		if (tableView){
			tableView.dataSource = self;
			tableView.delegate = self;
		}
	}
	return self;
}

- (void)setSections:(NSArray *)sections {
	_sections = TGRowsApplyingFieldTexts(sections ?: @[], self.storedFieldText);
}

- (void)reloadRows {
	TGFieldRowCell *active = self.activeFieldCell;
	NSString *activeKey = active.fieldIdentifier;
	if (activeKey.length)
		self.storedFieldText[activeKey] = [active text] ?: @"";
	self.reloadingFieldRows = YES;
	[self.tableView reloadData];
	self.reloadingFieldRows = NO;
}

- (NSMutableDictionary *)storedFieldText {
	if (!_storedFieldText)
		_storedFieldText = [NSMutableDictionary dictionary];
	return _storedFieldText;
}

- (NSDictionary *)rowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath)
		return nil;
	return TGRowsDataSourceRow(self.sections, indexPath.section, indexPath.row);
}

#pragma mark - table data

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	(void)tableView;
	return TGRowsDataSourceSectionCount(self.sections);
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
	(void)tableView;
	return TGRowsDataSourceRowCount(self.sections, section);
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {
	(void)tableView;
	return TGLocalizedOrNil(
			TGRowsDataSourceSectionAt(self.sections, section)[@"header"]);
}

- (NSString *)tableView:(UITableView *)tableView
titleForFooterInSection:(NSInteger)section {
	(void)tableView;
	return TGLocalizedOrNil(
			TGRowsDataSourceSectionAt(self.sections, section)[@"footer"]);
}

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = [self rowAtIndexPath:indexPath];
	if (!row)
		return TGMetricRow;
	CGFloat height = TGRowsDataSourceHeight(row, tableView.bounds.size.width);
	if (height >= 0)
		return height;

	NSString *kind = row[TGRowKind];
	if ([kind isEqualToString:TGKindField] ||
			[kind isEqualToString:TGKindMultilineField])
		return [TGFieldRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindNote])
		return [TGNoteRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindPhoto])
		return [TGPhotoRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindImageCheck])
		return [TGImageCheckRowCell heightForRow:row inTableView:tableView];
	return [TGRowCell heightForRow:row inTableView:tableView];
}

- (void)applyRowExtrasToCell:(UITableViewCell *)cell
						 row:(NSDictionary *)row {
	NSString *kind = row[TGRowKind];
	if (![kind isEqualToString:TGKindPeerRow] &&
			![kind isEqualToString:TGKindGrid]){
		UIImage *picture = row[TGRowAvatarImage];
		if ([picture isKindOfClass:UIImage.class])
			cell.imageView.image = picture;
	}
	UIImage *trailing = row[TGRowTrailingImage];
	if ([trailing isKindOfClass:UIImage.class]){
		UIImageView *view = [[UIImageView alloc] initWithImage:trailing];
		[view sizeToFit];
		cell.accessoryView = view;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = [self rowAtIndexPath:indexPath];
	if (!row){
		return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:nil];
	}
	NSString *kind = row[TGRowKind];
	NSArray *rows = TGRowsDataSourceSectionAt(self.sections,
			indexPath.section)[@"rows"];
	UITableViewCell *cell;
	if ([kind isEqualToString:TGKindPeerRow]){
		cell = [TGPeerRowCell cellForTableView:tableView row:row];
	} else if ([kind isEqualToString:TGKindField] ||
			[kind isEqualToString:TGKindMultilineField]){
		TGFieldRowCell *field = [TGFieldRowCell cellForTableView:tableView
				row:row rowIndex:indexPath.row totalRows:rows.count];
		field.fieldDelegate = self;
		cell = field;
	} else if ([kind isEqualToString:TGKindNote]){
		cell = [TGNoteRowCell cellForTableView:tableView row:row];
	} else if ([kind isEqualToString:TGKindPhoto]){
		cell = [TGPhotoRowCell cellForTableView:tableView row:row];
	} else if ([kind isEqualToString:TGKindImageCheck]){
		cell = [TGImageCheckRowCell cellForTableView:tableView row:row];
	} else if ([kind isEqualToString:TGKindGrid]){
		cell = [TGGridRowCell cellForTableView:tableView row:row];
	} else {
		cell = [TGRowCell cellForTableView:tableView row:row
				rowIndex:indexPath.row totalRows:rows.count];
		[(TGRowCell *)cell applyAppendedOptions:row];
	}
	[self applyRowExtrasToCell:cell row:row];
	return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = [self rowAtIndexPath:indexPath];
	if (!row)
		return;
	NSString *kind = row[TGRowKind];
	if ([kind isEqualToString:TGKindField] ||
			[kind isEqualToString:TGKindMultilineField]){
		UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
		if ([cell isKindOfClass:TGFieldRowCell.class])
			[(TGFieldRowCell *)cell focus];
		return;
	}
	void (^tap)(void) = row[TGRowTap];
	if (!tap)
		return;
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	tap();
}

- (BOOL)tableView:(UITableView *)tableView
canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	(void)tableView;
	(void)indexPath;
	return NO;
}

- (BOOL)tableView:(UITableView *)tableView
canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return [[self rowAtIndexPath:indexPath][TGRowCanMove] boolValue];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from
	  toIndexPath:(NSIndexPath *)to {
	(void)tableView;
	void (^move)(NSInteger, NSInteger) = [self rowAtIndexPath:from][TGRowMove];
	if (move)
		move(from.row, to.row);
}

#pragma mark - field text

- (void)fieldRowCell:(TGFieldRowCell *)cell didChangeText:(NSString *)text {
	NSString *key = cell.fieldIdentifier;
	if (key.length)
		self.storedFieldText[key] = text ?: @"";
}

- (void)fieldRowCellDidBeginEditing:(TGFieldRowCell *)cell {
	self.activeFieldCell = cell;
}

- (void)fieldRowCellDidEndEditing:(TGFieldRowCell *)cell {
	if (self.activeFieldCell == cell)
		self.activeFieldCell = nil;
	if (self.reloadingFieldRows)
		return;
	NSString *key = cell.fieldIdentifier;
	if (key.length)
		[self.storedFieldText removeObjectForKey:key];
}

@end

#endif

// vim:ft=objc
