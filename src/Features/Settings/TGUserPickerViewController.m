//
// TGUserPickerViewController.m - contact picker for privacy exception lists.
//
#import "TGUserPickerViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGRows.h"

@interface TGUserPickerViewController ()
@property (nonatomic, strong) NSMutableSet *selectedIds;
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, copy) NSString *pickerTitle;
- (void)rebuildSections;
- (void)toggleContact:(NSDictionary *)contact;
@end

@implementation TGUserPickerViewController

- (instancetype)initWithSelectedUserIds:(NSSet *)userIds title:(NSString *)title {
	self = [super init];
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
	[self rebuildSections];
	[self loadContacts];
}

- (void)loadContacts {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] contactsWithCompletion:^(NSArray *contacts){
		dispatch_async(dispatch_get_main_queue(), ^{
			weakSelf.contacts = contacts ?: @[];
			[weakSelf rebuildSections];
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

- (NSString *)nameForContact:(NSDictionary *)contact {
	NSString *first = contact[@"first_name"] ?: @"";
	NSString *last = contact[@"last_name"] ?: @"";
	NSString *name = [[NSString stringWithFormat:@"%@ %@", first, last]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (!name.length)
		name = contact[@"username"] ?: TGLocalized(@"User");
	return name;
}

- (void)rebuildSections {
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:self.contacts.count];
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *contact in self.contacts){
		NSNumber *uid = contact[@"id"] ?: @([contact[@"user_id"] longLongValue]);
		NSString *username = contact[@"username"];
		NSString *detail = username.length
				? [@"@" stringByAppendingString:username]
				: (contact[@"phone"] ?: @"");
		NSMutableDictionary *row = TGPeerRow(uid, [self nameForContact:contact],
				detail, nil);
		row[TGRowAvatarUser] = @YES;
		row[TGRowAccessory] = TGRowAccessoryCheck;
		row[TGRowChecked] = @([self.selectedIds containsObject:uid]);
		row[TGRowTap] = ^{ [weakSelf toggleContact:contact]; };
		[rows addObject:row];
	}
	self.sections = @[TGSection(nil, nil, rows)];
}

- (void)toggleContact:(NSDictionary *)contact {
	NSNumber *uid = contact[@"id"] ?: @([contact[@"user_id"] longLongValue]);
	if (!uid)
		return;
	if ([self.selectedIds containsObject:uid])
		[self.selectedIds removeObject:uid];
	else
		[self.selectedIds addObject:uid];
	[self rebuildSections];
	[self.tableView reloadData];
}

@end
