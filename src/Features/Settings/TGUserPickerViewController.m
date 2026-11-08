//
// TGUserPickerViewController.m - contact picker for privacy exception lists.
//
#import "TGUserPickerViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGIcons.h"
#import "TGAlertSheet.h"

@interface TGUserPickerCell : UITableViewCell
- (void)applyContact:(NSDictionary *)contact
			selected:(BOOL)selected
			   theme:(TGTheme *)theme;
@end

@implementation TGUserPickerCell {
	UILabel *_name;
	UILabel *_detail;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
			   reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	_name = [[UILabel alloc] initWithFrame:CGRectZero];
	_name.font = TGFontRow();
	_name.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:_name];

	_detail = [[UILabel alloc] initWithFrame:CGRectZero];
	_detail.font = TGFontCaption();
	_detail.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:_detail];
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat x = TGMetricGutter;
	CGFloat width = MAX(0, self.contentView.bounds.size.width - x - TGMetricPadLarge - 30);
	_name.frame = CGRectMake(x, TGMetricPadSmall, width, TGMetricLineRow);
	_detail.frame = CGRectMake(x, TGMetricPadSmall + TGMetricLineRow, width, TGMetricLineCaption);
}

- (void)applyContact:(NSDictionary *)contact
			selected:(BOOL)selected
			   theme:(TGTheme *)theme {
	NSString *first = contact[@"first_name"] ?: @"";
	NSString *last = contact[@"last_name"] ?: @"";
	NSString *name = [[NSString stringWithFormat:@"%@ %@", first, last]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (!name.length)
		name = contact[@"username"] ?: @"User";
	_name.text = name;
	_name.textColor = [theme primaryTextColour];

	NSString *username = contact[@"username"];
	_detail.text = username.length ? [@"@" stringByAppendingString:username]
								   : (contact[@"phone"] ?: @"");
	_detail.textColor = [theme secondaryTextColour];

	self.accessoryView = [[UIImageView alloc] initWithImage:
			[TGIcons selectionCheckboxSelected:selected]];
	self.backgroundColor = [theme cardBackgroundColour];
	self.contentView.backgroundColor = [theme cardBackgroundColour];
}

@end

@interface TGUserPickerViewController ()
@property (nonatomic, strong) NSMutableSet *selectedIds;
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, copy) NSString *pickerTitle;
@end

@implementation TGUserPickerViewController

- (instancetype)initWithSelectedUserIds:(NSSet *)userIds title:(NSString *)title {
	self = [super initWithStyle:UITableViewStylePlain];
	if (self) {
		_selectedIds = [NSMutableSet setWithSet:userIds ?: [NSSet set]];
		_pickerTitle = [title copy] ?: TGLocalized(@"Add Users");
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.pickerTitle;
	self.navigationItem.rightBarButtonItem =
			[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
														  target:self
														  action:@selector(doneTapped)];
	self.tableView.rowHeight = TGMetricPersonRow;
	[self loadContacts];
}

- (void)loadContacts {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] contactsWithCompletion:^(NSArray *contacts){
		dispatch_async(dispatch_get_main_queue(), ^{
			weakSelf.contacts = contacts ?: @[];
			[weakSelf.tableView reloadData];
		});
	}];
}

- (void)doneTapped {
	if (self.onDone) {
		self.onDone([self.selectedIds copy]);
	}
	[self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.contacts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *ident = @"TGUserPickerCell";
	TGUserPickerCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
	if (!cell) {
		cell = [[TGUserPickerCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ident];
	}
	NSDictionary *c = self.contacts[indexPath.row];
	NSNumber *uid = c[@"id"] ?: @([c[@"user_id"] longLongValue]);
	BOOL selected = [self.selectedIds containsObject:uid];
	[cell applyContact:c selected:selected theme:[TGTheme shared]];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary *c = self.contacts[indexPath.row];
	NSNumber *uid = c[@"id"] ?: @([c[@"user_id"] longLongValue]);
	if (!uid) return;

	if ([self.selectedIds containsObject:uid]) {
		[self.selectedIds removeObject:uid];
	} else {
		[self.selectedIds addObject:uid];
	}
	[self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

@end
