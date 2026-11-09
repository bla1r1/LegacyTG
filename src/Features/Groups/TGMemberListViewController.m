#import "TGMemberListViewController.h"
#import "TGClient.h"
#import "TGLocalization.h"
#import "TGGroupLogic.h"
#import "TGGroupMemberActions.h"
#import "TGContactsViewController.h"
#import "TGRows.h"
#import "TGBadge.h"

@interface TGMemberListViewController ()
- (void)loadMembers;
- (void)rebuildSections;
- (void)openAddMember;
- (void)openProfileForMember:(NSDictionary *)member;
@end

@implementation TGMemberListViewController

- (instancetype)init {
	return [super init];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if (!self.listTitle.length)
		self.listTitle = TGLocalized(@"Members");
	self.title = self.listTitle;
	[self rebuildSections];

	// Group Settings passes the page it already holds; a direct opener (or a
	// screen that has not loaded yet) asks once rather than showing nothing.
	if (!self.members.count && self.chatId)
		[self loadMembers];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.title = self.listTitle.length ? self.listTitle : self.title;
	[self applyTheme];
}

- (void)loadMembers {
	int64_t chatId = self.chatId;
	if (!chatId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] membersOfChat:chatId completion:^(NSArray *members){
		TGMemberListViewController *me = weakSelf;
		if (!me)
			return;
		me.members = members ?: @[];
		[me rebuildSections];
		[me.tableView reloadData];
	}];
}

- (NSString *)nameForMember:(NSDictionary *)member {
	int64_t userId = [member[@"id"] longLongValue];
	NSString *name = TGMemberRowName(member);
	if (!name.length)
		name = [[TGClient shared] nameForUserId:userId];
	if (!name.length)
		name = TGLocalized(@"Member");
	return name;
}

- (void)rebuildSections {
	NSMutableArray *rows = [NSMutableArray array];
	__weak typeof(self) weakSelf = self;

	if (self.canAddMembers){
		[rows addObject:TGTapRow(TGLocalized(@"Add Member"), nil, ^{
			[weakSelf openAddMember];
		})];
	}

	for (NSDictionary *member in self.members){
		int64_t userId = [member[@"id"] longLongValue];
		NSMutableDictionary *row = TGPeerRow(@(userId),
				[self nameForMember:member], nil, nil);
		row[TGRowAvatarUser] = @YES;
		row[TGRowAccessory] = TGRowAccessoryDisclosure;
		int64_t statusEmojiId = [[TGClient shared] emojiStatusIdForUser:userId];
		if (statusEmojiId > 0)
			row[TGRowStatusEmojiId] = @(statusEmojiId);

		NSString *status = member[@"status"];
		NSString *tag = member[@"tag"];
		NSString *label = [tag isKindOfClass:NSString.class]
				? [tag stringByTrimmingCharactersInSet:
						[NSCharacterSet whitespaceAndNewlineCharacterSet]] : nil;
		if ([status isEqualToString:@"owner"]){
			row[TGRowBadge] = label.length ? label : TGLocalized(@"Owner");
			row[TGRowBadgeVariant] = @(TGBadgeVariantAccent);
			row[TGRowBadgeInline] = @YES;
		} else if ([status isEqualToString:@"admin"]){
			row[TGRowBadge] = label.length ? label : TGLocalized(@"Admin");
			row[TGRowBadgeVariant] = @(TGBadgeVariantMuted);
			row[TGRowBadgeInline] = @YES;
		}

		NSDictionary *captured = member;
		row[TGRowTap] = ^{ [weakSelf openProfileForMember:captured]; };
		[rows addObject:row];
	}
	self.sections = @[TGSection(nil, nil, rows)];
}

- (void)openAddMember {
	TGContactsViewController *contacts = [[TGContactsViewController alloc] init];
	contacts.addingToChatId = self.chatId;
	contacts.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:contacts animated:YES];
}

- (void)openProfileForMember:(NSDictionary *)member {
	[TGGroupMemberActions openProfileForMember:member from:self];
}

@end
