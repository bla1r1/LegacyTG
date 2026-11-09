#import "TGCloseFriendsViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGAlertSheet.h"
#import "TGRows.h"

@interface TGCloseFriendsViewController ()
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, strong) NSMutableSet *selected;
@property (nonatomic, assign) BOOL loaded;
- (void)rebuildSections;
- (void)toggleContact:(NSDictionary *)contact;
@end

@implementation TGCloseFriendsViewController

- (instancetype)init {
	self = [super init];
	if (self){
		_selected = [NSMutableSet set];
		_contacts = @[];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Close Friends");

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] closeFriendsWithCompletion:^(NSArray *ids){
		TGCloseFriendsViewController *me = weakSelf;
		if (!me)
			return;
		[me.selected setSet:[NSSet setWithArray:ids]];
		[[TGClient shared] contactsWithCompletion:^(NSArray *contacts){
			TGCloseFriendsViewController *again = weakSelf;
			if (!again)
				return;
			again.contacts = contacts ?: @[];
			again.loaded = YES;
			[again rebuildSections];
			[again.tableView reloadData];
		}];
	}];
}

- (NSString *)contactName:(NSDictionary *)contact {
	NSString *first = contact[@"first_name"] ?: @"";
	NSString *last = contact[@"last_name"] ?: @"";
	NSString *name = [[NSString stringWithFormat:@"%@ %@", first, last]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (!name.length)
		name = contact[@"username"] ?: TGLocalized(@"Contact");
	return name;
}

- (void)rebuildSections {
	NSMutableArray *rows = [NSMutableArray array];
	if (!self.loaded || !self.contacts.count){
		[rows addObject:TGRow(TGKindPlain,
				self.loaded ? TGLocalized(@"None") : TGLocalized(@"Loading..."))];
	} else {
		__weak typeof(self) weakSelf = self;
		for (NSDictionary *contact in self.contacts){
			NSNumber *userId = contact[@"id"];
			if (![userId isKindOfClass:NSNumber.class])
				continue;
			NSString *username = contact[@"username"];
			NSString *detail = username.length
					? [@"@" stringByAppendingString:username]
					: (contact[@"phone"] ?: @"");
			NSMutableDictionary *row = TGPeerRow(userId,
					[self contactName:contact], detail, nil);
			row[TGRowAvatarUser] = @YES;
			row[TGRowAccessory] = TGRowAccessoryCheck;
			row[TGRowChecked] = @([self.selected containsObject:userId]);
			row[TGRowTap] = ^{ [weakSelf toggleContact:contact]; };
			[rows addObject:row];
		}
	}

	NSString *footer = nil;
	if (!self.loaded)
		footer = TGLocalized(@"Loading...");
	else if (!self.contacts.count)
		footer = TGLocalized(@"None");
	else
		footer = [NSString stringWithFormat:TGLocalized(@"%@ Selected"),
				@(self.selected.count)];
	self.sections = @[TGSection(TGLocalized(@"Close Friends"), footer, rows)];
}

- (void)toggleContact:(NSDictionary *)contact {
	NSNumber *userId = contact[@"id"];
	if (![userId isKindOfClass:NSNumber.class])
		return;

	NSMutableSet *before = [self.selected copy];
	if ([self.selected containsObject:userId])
		[self.selected removeObject:userId];
	else
		[self.selected addObject:userId];
	[self rebuildSections];
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setCloseFriends:self.selected.allObjects
							completion:^(BOOL ok, NSString *error){
		TGCloseFriendsViewController *me = weakSelf;
		if (!me)
			return;
		if (!ok){
			// The check goes back where it was; the server's sentence is why.
			[me.selected setSet:before];
			[me rebuildSections];
			[me.tableView reloadData];
			[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
								title:TGLocalized(@"Close Friends") inView:me.view];
			return;
		}
		if (me.onCountChanged)
			me.onCountChanged((NSInteger)me.selected.count);
		[me rebuildSections];
		[me.tableView reloadData];
	}];
}

@end
