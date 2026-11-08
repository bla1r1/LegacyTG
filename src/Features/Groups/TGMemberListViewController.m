#import "TGMemberListViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGLocalization.h"
#import "TGGroupLogic.h"
#import "TGMemberCell.h"
#import "TGGroupMemberActions.h"
#import "TGContactsViewController.h"

@implementation TGMemberListViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if (!self.listTitle.length)
		self.listTitle = TGLocalized(@"Members");
	self.title = self.listTitle;
	self.tableView.rowHeight = TGMetricPersonRow;
	[self applyTheme];

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

- (void)applyTheme {
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
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
		[me.tableView reloadData];
	}];
}

#pragma mark - table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.members.count + (self.canAddMembers ? 1 : 0);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.canAddMembers && indexPath.row == 0)
		return TGMetricRow;
	return TGMetricPersonRow;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.canAddMembers && indexPath.row == 0){
		static NSString *addReuse = @"addMember";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:addReuse];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:addReuse];
		TGTheme *theme = [TGTheme shared];
		[theme styleCell:cell];
		cell.textLabel.text = TGLocalized(@"Add Member");
		cell.textLabel.font = TGFontBody();
		cell.textLabel.textColor = [theme accentColour];
		cell.selectionStyle = UITableViewCellSelectionStyleDefault;
		cell.accessoryType = UITableViewCellAccessoryNone;
		return cell;
	}

	NSInteger index = indexPath.row - (self.canAddMembers ? 1 : 0);
	if (index < 0 || index >= (NSInteger)self.members.count)
		return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:nil];
	NSDictionary *member = self.members[(NSUInteger)index];
	int64_t userId = [member[@"id"] longLongValue];
	NSString *name = TGMemberRowName(member);
	if (!name.length)
		name = [[TGClient shared] nameForUserId:userId];
	if (!name.length)
		name = TGLocalized(@"Member");

	static NSString *memberReuse = @"memberListRow";
	TGMemberCell *cell = [tableView dequeueReusableCellWithIdentifier:memberReuse];
	if (!cell)
		cell = [[TGMemberCell alloc] initWithStyle:UITableViewCellStyleDefault
								  reuseIdentifier:memberReuse];
	TGTheme *theme = [TGTheme shared];
	[theme styleCell:cell];
	cell.textLabel.font = TGFontBody();
	cell.textLabel.textColor = [theme primaryTextColour];
	cell.selectionStyle = UITableViewCellSelectionStyleDefault;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	int64_t statusEmojiId = [[TGClient shared] emojiStatusIdForUser:userId];
	[cell setName:name userId:userId status:member[@"status"] tag:member[@"tag"]
	  statusEmojiId:statusEmojiId inTable:tableView];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.canAddMembers && indexPath.row == 0){
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		TGContactsViewController *contacts = [[TGContactsViewController alloc] init];
		contacts.addingToChatId = self.chatId;
		contacts.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:contacts animated:YES];
		return;
	}
	NSInteger index = indexPath.row - (self.canAddMembers ? 1 : 0);
	if (index < 0 || index >= (NSInteger)self.members.count)
		return;
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[TGGroupMemberActions openProfileForMember:self.members[(NSUInteger)index]
										  from:self];
}

@end
