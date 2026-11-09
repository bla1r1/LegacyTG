//
// TGRowsViewController.m
//
#import "TGRowsViewController.h"
#import "TGRows.h"
#import "TGLocalization.h"
#import "TGRowCell.h"
#import "TGPeerRowCell.h"
#import "TGMessageResultRowCell.h"
#import "TGPictureRowCell.h"
#import "TGTabStripRowCell.h"
#import "TGGridRowCell.h"
#import "TGFieldRowCell.h"
#import "TGProfileHeaderRowCell.h"
#import "TGChatPreviewRowCell.h"
#import "TGThemeCardsRowCell.h"
#import "TGThemeGridRowCell.h"
#import "TGSnackbar.h"
#import "TGStyle.h"

@interface TGRowsViewController () <TGFieldRowCellDelegate>
@property (nonatomic, strong) NSMutableDictionary *storedFieldText;
@property (nonatomic, weak) TGFieldRowCell *activeFieldCell;
@property (nonatomic, assign) BOOL reloadingFieldRows;
@end

@implementation TGRowsViewController

@synthesize sections = _sections;

- (id)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self)
		_checksSectionIcons = YES;
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(keyboardWillChange:)
				name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(keyboardWillChange:)
				name:UIKeyboardWillChangeFrameNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(keyboardWillHide:)
				name:UIKeyboardWillHideNotification object:nil];
	[self tg_updateCopyButton];
	[self applyTheme];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applyTheme {
	[super applyTheme];
	[self reloadRows];
}

- (void)setSections:(NSArray *)sections {
	_sections = TGRowsApplyingFieldTexts(sections, self.storedFieldText);
#ifdef DEBUG
	if (self.checksSectionIcons){
		for (NSDictionary *section in sections){
			if (![section isKindOfClass:NSDictionary.class])
				continue;
			NSArray *rows = section[@"rows"];
			NSAssert(TGRowsSectionIconsConsistent(rows),
					@"a section mixes rows with and without an icon: %@", rows);
		}
	}
#endif
}

- (void)reloadRows {
	if (!self.sections.count && (self.listRows || self.emptyText || self.listFooter))
		[self rebuildListSections];
	TGFieldRowCell *active = self.activeFieldCell;
	NSString *activeKey = active.fieldIdentifier;
	if (activeKey.length)
		self.storedFieldText[activeKey] = [active text] ?: @"";
	self.reloadingFieldRows = YES;
	[self.tableView reloadData];
	self.reloadingFieldRows = NO;
	if (activeKey.length)
		[self focusFieldWithIdentifier:activeKey];
}

- (void)clearStoredFieldText {
	[self.storedFieldText removeAllObjects];
	self.activeFieldCell = nil;
}

- (void)focusFieldWithIdentifier:(NSString *)identifier {
	if (!identifier.length)
		return;
	NSIndexPath *path = [self indexPathForFieldIdentifier:identifier];
	if (!path)
		return;
	[self.tableView scrollToRowAtIndexPath:path
			atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
	[self.tableView layoutIfNeeded];
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:path];
	if ([cell isKindOfClass:TGFieldRowCell.class])
		[(TGFieldRowCell *)cell focus];
}

- (NSIndexPath *)indexPathForFieldIdentifier:(NSString *)identifier {
	for (NSUInteger section = 0; section < self.sections.count; section++){
		NSArray *rows = self.sections[section][@"rows"];
		for (NSUInteger row = 0; row < rows.count; row++){
			if ([TGRowFieldKey(rows[row]) isEqualToString:identifier])
				return [NSIndexPath indexPathForRow:(NSInteger)row
										 inSection:(NSInteger)section];
		}
	}
	return nil;
}

- (void)toast:(NSString *)text {
	UIView *host = self.navigationController.view ?: self.view;
	[TGSnackbar showInView:host text:text seconds:2 onCommit:nil];
}

- (NSMutableDictionary *)storedFieldText {
	if (!_storedFieldText)
		_storedFieldText = [NSMutableDictionary dictionary];
	return _storedFieldText;
}

#pragma mark - keyboard

- (void)keyboardWillChange:(NSNotification *)note {
	NSDictionary *info = note.userInfo;
	CGRect frame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
	frame = [self.view convertRect:frame fromView:nil];
	CGFloat overlap = CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(frame);
	if (overlap < 0)
		overlap = 0;
	UIEdgeInsets inset = self.tableView.contentInset;
	inset.bottom = overlap;
	self.tableView.contentInset = inset;
	self.tableView.scrollIndicatorInsets = inset;
	if (self.activeFieldCell){
		NSIndexPath *path = [self.tableView indexPathForCell:self.activeFieldCell];
		if (path)
			[self.tableView scrollToRowAtIndexPath:path
					atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	}
}

- (void)keyboardWillHide:(NSNotification *)note {
	(void)note;
	UIEdgeInsets inset = self.tableView.contentInset;
	inset.bottom = 0;
	self.tableView.contentInset = inset;
	self.tableView.scrollIndicatorInsets = inset;
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

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	(void)tableView;
	return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
	(void)tableView;
	return (NSInteger)[self.sections[(NSUInteger)section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {
	(void)tableView;
	return TGLocalizedOrNil(self.sections[(NSUInteger)section][@"header"]);
}

- (NSString *)tableView:(UITableView *)tableView
titleForFooterInSection:(NSInteger)section {
	(void)tableView;
	return TGLocalizedOrNil(self.sections[(NSUInteger)section][@"footer"]);
}

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = self.sections[(NSUInteger)indexPath.section]
			[@"rows"][(NSUInteger)indexPath.row];
	NSString *kind = row[TGRowKind];
	if ([kind isEqualToString:TGKindPeerRow])
		return [TGPeerRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindMessageResult])
		return [TGMessageResultRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindProfileHeader] ||
			[kind isEqualToString:TGKindProfile])
		return [TGProfileHeaderRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindChatPreview] ||
			[kind isEqualToString:TGKindPreview])
		return [TGChatPreviewRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindThemeCards])
		return [TGThemeCardsRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindThemeGrid])
		return [TGThemeGridRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindField] ||
			[kind isEqualToString:TGKindMultilineField])
		return [TGFieldRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindNote])
		return [TGNoteRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindPhoto])
		return [TGPhotoRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindImageCheck])
		return [TGImageCheckRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindPicture])
		return [TGPictureRowCell heightForRow:row inTableView:tableView];
	if ([kind isEqualToString:TGKindTabStrip])
		return [TGTabStripRowCell heightForRow:row inTableView:tableView];
	return [TGRowCell heightForRow:row inTableView:tableView];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *rows = self.sections[(NSUInteger)indexPath.section][@"rows"];
	NSDictionary *row = rows[(NSUInteger)indexPath.row];
	NSString *kind = row[TGRowKind];
	if ([kind isEqualToString:TGKindPeerRow])
		return [TGPeerRowCell cellForTableView:tableView row:row];
	if ([kind isEqualToString:TGKindMessageResult])
		return [TGMessageResultRowCell cellForTableView:tableView row:row];
	if ([kind isEqualToString:TGKindProfileHeader] ||
			[kind isEqualToString:TGKindProfile])
		return [TGProfileHeaderRowCell cellForTableView:tableView row:row];
	if ([kind isEqualToString:TGKindChatPreview] ||
			[kind isEqualToString:TGKindPreview])
		return [TGChatPreviewRowCell cellForTableView:tableView row:row];
	if ([kind isEqualToString:TGKindThemeCards])
		return [TGThemeCardsRowCell cellForTableView:tableView row:row];
	if ([kind isEqualToString:TGKindThemeGrid])
		return [TGThemeGridRowCell cellForTableView:tableView row:row];
	if ([kind isEqualToString:TGKindField] ||
			[kind isEqualToString:TGKindMultilineField]){
		TGFieldRowCell *cell = [TGFieldRowCell cellForTableView:tableView row:row
				rowIndex:indexPath.row totalRows:rows.count];
		cell.fieldDelegate = self;
		return cell;
	}
	if ([kind isEqualToString:TGKindNote])
		return [TGNoteRowCell cellForTableView:tableView row:row];
	if ([kind isEqualToString:TGKindPhoto])
		return [TGPhotoRowCell cellForTableView:tableView row:row];
	if ([kind isEqualToString:TGKindImageCheck])
		return [TGImageCheckRowCell cellForTableView:tableView row:row];
	if ([kind isEqualToString:TGKindPicture])
		return [TGPictureRowCell cellForTableView:tableView row:row];
	if ([kind isEqualToString:TGKindTabStrip])
		return [TGTabStripRowCell cellForTableView:tableView row:row];
	return [TGRowCell cellForTableView:tableView row:row
							 rowIndex:indexPath.row totalRows:rows.count];
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = self.sections[(NSUInteger)indexPath.section]
			[@"rows"][(NSUInteger)indexPath.row];
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

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	(void)tableView;
	(void)indexPath;
	return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = self.sections[(NSUInteger)indexPath.section]
			[@"rows"][(NSUInteger)indexPath.row];
	return [row[TGRowCanMove] boolValue];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from
	  toIndexPath:(NSIndexPath *)to {
	NSDictionary *row = self.sections[(NSUInteger)from.section]
			[@"rows"][(NSUInteger)from.row];
	void (^move)(NSInteger, NSInteger) = row[TGRowMove];
	if (move)
		move(from.row, to.row);
}

#pragma mark - flat list compatibility

- (void)setListRows:(NSArray *)rows {
	_listRows = [rows copy] ?: @[];
	[self rebuildListSections];
	if (self.isViewLoaded)
		[self reloadRows];
}

- (void)setEmptyText:(NSString *)emptyText {
	_emptyText = [emptyText copy];
	[self rebuildListSections];
	if (self.isViewLoaded)
		[self reloadRows];
}

- (void)setListFooter:(NSString *)listFooter {
	_listFooter = [listFooter copy];
	[self rebuildListSections];
	if (self.isViewLoaded)
		[self reloadRows];
}

- (void)setOffersCopy:(BOOL)offersCopy {
	_offersCopy = offersCopy;
	if (self.isViewLoaded)
		[self tg_updateCopyButton];
}

- (void)tg_updateCopyButton {
	if (!self.offersCopy)
		return;
	if (self.navigationItem.rightBarButtonItem)
		return;
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:TGLocalized(@"Copy") style:UIBarButtonItemStylePlain
				   target:self action:@selector(copyAllRows)];
}

- (void)copyAllRows {
	NSMutableArray *lines = [NSMutableArray array];
	if (self.listFooter.length)
		[lines addObject:TGLocalized(self.listFooter)];
	for (NSDictionary *row in self.listRows){
		NSString *title = row[TGRowTitle] ?: @"";
		NSString *detail = row[TGRowDetail] ?: @"";
		[lines addObject:detail.length
				? [NSString stringWithFormat:@"%@: %@", title, detail]
				: title];
	}
	[UIPasteboard generalPasteboard].string =
			[lines componentsJoinedByString:@"\n"];
	[self toast:TGLocalized(@"Copied to clipboard.")];
}

/// The flat entry list becomes one section, with the empty sentence as a
/// secondary row and footer the way the old list showed it.
- (void)rebuildListSections {
	NSArray *source = self.listRows ?: @[];
	NSArray *rows = TGRowsFromListEntries(source);
	NSString *footer = source.count ? self.listFooter : self.emptyText;
	if (!source.count){
		NSString *text = self.emptyText.length ? self.emptyText
				: TGLocalized(@"None");
		rows = @[TGRow(TGKindPlain, text)];
	}
	self.sections = @[TGSection(nil, footer, rows)];
}

@end

#pragma mark - grid rows

@implementation TGGridRowsViewController

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = self.sections[(NSUInteger)indexPath.section]
			[@"rows"][(NSUInteger)indexPath.row];
	if ([row[TGRowKind] isEqualToString:TGKindGrid])
		return [TGGridRowCell heightForRow:row inTableView:tableView];
	return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = self.sections[(NSUInteger)indexPath.section]
			[@"rows"][(NSUInteger)indexPath.row];
	if ([row[TGRowKind] isEqualToString:TGKindGrid])
		return [TGGridRowCell cellForTableView:tableView row:row];
	return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

@end
