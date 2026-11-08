#import "TGGroupSettingsViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGSnackbar.h"
#import "TGContactsViewController.h"
#import "TGChatToolsViewController.h"
#import "TGGroupMemberActions.h"
#import "TGMemberCell.h"
#import "TGProfileViewController.h"
#import "TGIcons.h"
#import "TGGroupCallViewController.h"
#import "TGVideoChatSetupViewController.h"
#import "TGAntiSpamViewController.h"
#import "TGGroupSettingsViewController.h"
#import "TGGroupSwitch.h"
#import "TGGroupSettingsViewControllerInternal.h"



//
// TGGroupSettingsViewController.m - one screen for everything a group is.
//
// The group profile's More menu used to grow one row per setting: Photo,
// Name, Description, Invite Link, Permissions, Sign Messages, Join to Send,
// All History, Welcome Messages, Direct Messages, Import, Send as, Clear by
// Date, Chat Tools. Each row asked the server what it sat on and answered
// with a sheet. A settings screen can show the value, group the rows by what
// they change, and leave the profile menu for the things a profile does.
//
// The chat id is the only thing the caller passes. Every action here names
// that id directly, so nothing is routed through the profile controller
// behind this screen.
//

/// The rows a section can hold. A switch draws a UISwitch, a member row a
/// face, and everything else a value with a chevron.
typedef NS_ENUM(NSInteger, TGGroupRowKind) {
	TGGroupRowInfo = 0,
	TGGroupRowAction,
	TGGroupRowSwitch,
	TGGroupRowUsername,
	TGGroupRowMember,
};

/// A switch that names the setting it changes, so a reload can rebuild rows
/// without an index pointing at the wrong one.


static NSMutableDictionary *TGRow(NSString *title, NSString *detail,
								  NSString *action, TGGroupRowKind kind) {
	NSMutableDictionary *row = [@{@"kind" : @(kind), @"title" : title ?: @""}
			mutableCopy];
	if (detail)
		row[@"detail"] = detail;
	if (action)
		row[@"action"] = action;
	return row;
}

static NSMutableDictionary *TGInfoRow(NSString *title, NSString *detail,
									  NSString *action) {
	return TGRow(title, detail, action, TGGroupRowInfo);
}

static NSMutableDictionary *TGOpenRow(NSString *title, NSString *detail,
									  NSString *action) {
	NSMutableDictionary *row = TGInfoRow(title, detail, action);
	row[@"opens"] = @YES;
	return row;
}

static NSMutableDictionary *TGActionRow(NSString *title, NSString *detail,
										NSString *action, BOOL destructive) {
	NSMutableDictionary *row = TGRow(title, detail, action, TGGroupRowAction);
	if (destructive)
		row[@"destructive"] = @YES;
	return row;
}

static NSMutableDictionary *TGOpenActionRow(NSString *title, NSString *detail,
											NSString *action, BOOL destructive) {
	NSMutableDictionary *row = TGActionRow(title, detail, action, destructive);
	row[@"opens"] = @YES;
	return row;
}

/// The same row when the account has no right for it: the title and the
/// reason stay on screen, the chevron and the tap do not. That is what
/// Telegram does for a switch an administrator may see but not move.
static NSMutableDictionary *TGDisabledRow(NSString *title, NSString *reason,
										  NSString *action) {
	NSMutableDictionary *row = TGActionRow(title, reason, nil, NO);
	if (action)
		row[@"refusedAction"] = action;
	row[@"disabled"] = @YES;
	return row;
}

static NSMutableDictionary *TGSwitchRow(NSString *title, NSString *detail,
										NSString *key, BOOL on, BOOL enabled) {
	NSMutableDictionary *row = TGRow(title, detail, nil, TGGroupRowSwitch);
	row[@"switch"] = key;
	row[@"on"] = @(on);
	row[@"enabled"] = @(enabled);
	return row;
}

static NSMutableDictionary *TGUsernameRow(NSString *username, BOOL active) {
	NSMutableDictionary *row = TGRow([@"@" stringByAppendingString:username],
									 active ? @"Active" : @"Disabled",
									 nil, TGGroupRowUsername);
	row[@"switch"] = [@"@" stringByAppendingString:username];
	row[@"username"] = username;
	row[@"active"] = @(active);
	row[@"on"] = @(active);
	row[@"enabled"] = @YES;
	return row;
}

static NSDictionary *TGSection(NSString *header, NSString *footer, NSArray *rows) {
	NSMutableDictionary *section = [NSMutableDictionary dictionary];
	if (header) section[@"header"] = header;
	if (footer) section[@"footer"] = footer;
	section[@"rows"] = rows ?: @[];
	return section;
}




@implementation TGGroupSettingsViewController (TGGroupTable)

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.loaded ? (NSInteger)self.sections.count : 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section < 0 || section >= (NSInteger)self.sections.count)
		return 0;
	return [self.sections[(NSUInteger)section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section < 0 || section >= (NSInteger)self.sections.count)
		return nil;
	return self.sections[(NSUInteger)section][@"header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section < 0 || section >= (NSInteger)self.sections.count)
		return nil;
	return self.sections[(NSUInteger)section][@"footer"];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view
	   forSection:(NSInteger)section {
	if (![view isKindOfClass:UITableViewHeaderFooterView.class])
		return;
	UITableViewHeaderFooterView *footer = (UITableViewHeaderFooterView *)view;
	footer.textLabel.textColor = [[TGTheme shared] sectionHeaderColour];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path {
	NSDictionary *row = [self rowAtPath:path];
	return [row[@"kind"] integerValue] == TGGroupRowMember
			? TGMetricPersonRow : TGMetricRow;
}

- (NSDictionary *)rowAtPath:(NSIndexPath *)path {
	if (path.section < 0 || path.section >= (NSInteger)self.sections.count)
		return nil;
	NSArray *rows = self.sections[(NSUInteger)path.section][@"rows"];
	if (path.row < 0 || path.row >= (NSInteger)rows.count)
		return nil;
	return rows[(NSUInteger)path.row];
}

- (UITableViewCell *)valueCellForRow:(NSDictionary *)row
							 inTable:(UITableView *)tableView {
	static NSString *reuse = @"value";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:reuse];
	TGTheme *theme = [TGTheme shared];
	[theme styleCell:cell];
	cell.textLabel.font = TGFontRow();
	cell.textLabel.text = row[@"title"];
	cell.textLabel.textAlignment = NSTextAlignmentLeft;
	cell.detailTextLabel.font = TGFontBody();
	cell.detailTextLabel.text = row[@"detail"] ?: @"";
	BOOL disabled = [row[@"disabled"] boolValue];
	BOOL tappable = row[@"action"] != nil && !disabled;
	// The value on the right is blue only when tapping it changes something.
	// A read-only group leaves its name and photo black, the way Telegram's
	// member view does; blue there sells a tap that does not exist.
	cell.detailTextLabel.textColor = tappable ? [theme cellDetailColour]
											  : [theme secondaryTextColour];
	cell.accessoryType = (tappable && [row[@"opens"] boolValue])
			? UITableViewCellAccessoryDisclosureIndicator
			: UITableViewCellAccessoryNone;
	cell.selectionStyle = tappable ? UITableViewCellSelectionStyleDefault
								   : UITableViewCellSelectionStyleNone;
	if (disabled)
		cell.textLabel.textColor = [theme secondaryTextColour];
	else
		cell.textLabel.textColor = [row[@"destructive"] boolValue]
				? [theme destructiveColour] : [theme primaryTextColour];
	// Leave/Delete is the one row Telegram centres and leaves undecorated.
	if ([row[@"centered"] boolValue]){
		cell.textLabel.textAlignment = NSTextAlignmentCenter;
		cell.detailTextLabel.text = nil;
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
	return cell;
}

- (UITableViewCell *)switchCellForRow:(NSDictionary *)row
							  inTable:(UITableView *)tableView {
	static NSString *reuse = @"switch";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:reuse];
	TGTheme *theme = [TGTheme shared];
	[theme styleCell:cell];
	cell.textLabel.font = TGFontRow();
	cell.textLabel.textColor = [theme primaryTextColour];
	cell.detailTextLabel.font = TGFontCaption();
	cell.detailTextLabel.textColor = [theme secondaryTextColour];
	cell.textLabel.text = row[@"title"];
	cell.detailTextLabel.text = row[@"detail"] ?: @"";
	cell.selectionStyle = UITableViewCellSelectionStyleNone;

	TGGroupSwitch *toggle = [[TGGroupSwitch alloc] init];
	toggle.key = row[@"switch"];
	toggle.on = [row[@"on"] boolValue];
	toggle.enabled = [row[@"enabled"] boolValue] && !self.busy;
	[toggle addTarget:self action:@selector(switchChanged:)
	 forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	cell.showsReorderControl = [row[@"kind"] integerValue] == TGGroupRowUsername &&
			[row[@"active"] boolValue] && self.active.count > 1;
	return cell;
}

- (UITableViewCell *)memberCellForRow:(NSDictionary *)row
							  inTable:(UITableView *)tableView {
	static NSString *reuse = @"member";
	TGMemberCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGMemberCell alloc] initWithStyle:UITableViewCellStyleDefault
								  reuseIdentifier:reuse];
	TGTheme *theme = [TGTheme shared];
	[theme styleCell:cell];
	cell.textLabel.font = TGFontBody();
	cell.textLabel.textColor = [theme primaryTextColour];
	cell.selectionStyle = UITableViewCellSelectionStyleDefault;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	NSDictionary *member = row[@"member"];
	int64_t userId = [member[@"id"] longLongValue];
	NSString *name = [member[@"name"] length]
			? member[@"name"] : [[TGClient shared] nameForUserId:userId];
	[cell setName:name userId:userId status:member[@"status"]
				tag:member[@"tag"] inTable:tableView];
	return cell;
}

/// The old tap on a member: their action sheet. Kept on a hold now that a
/// tap belongs to the person's profile.
- (void)memberRowHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	NSIndexPath *path = [self.tableView indexPathForRowAtPoint:
			[hold locationInView:self.tableView]];
	NSDictionary *row = path ? [self rowAtPath:path] : nil;
	if (!row || [row[@"kind"] integerValue] != TGGroupRowMember)
		return;
	__weak typeof(self) weakSelf = self;
	[TGGroupMemberActions showForMember:row[@"member"]
								 inChat:self.chatId
								   from:self
							  onChanged:^{
		[weakSelf load];
	}];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)path {
	NSDictionary *row = [self rowAtPath:path];
	if (!row)
		return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:nil];
	TGGroupRowKind kind = (TGGroupRowKind)[row[@"kind"] integerValue];
	if (kind == TGGroupRowMember)
		return [self memberCellForRow:row inTable:tableView];
	if (kind == TGGroupRowSwitch || kind == TGGroupRowUsername)
		return [self switchCellForRow:row inTable:tableView];
	return [self valueCellForRow:row inTable:tableView];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)path {
	NSDictionary *row = [self rowAtPath:path];
	return [row[@"kind"] integerValue] == TGGroupRowUsername &&
		   [row[@"active"] boolValue] && self.active.count > 1;
}

- (NSIndexPath *)tableView:(UITableView *)tableView
targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source
	   toProposedIndexPath:(NSIndexPath *)proposed {
	return source.section == proposed.section ? proposed : source;
}

- (void)tableView:(UITableView *)tableView
		moveRowAtIndexPath:(NSIndexPath *)from
			  toIndexPath:(NSIndexPath *)to {
	NSUInteger fromRow = (NSUInteger)from.row;
	NSUInteger toRow = (NSUInteger)to.row;
	if (fromRow >= self.active.count || toRow >= self.active.count)
		return;
	NSArray *before = [self.active copy];
	NSString *name = self.active[fromRow];
	[self.active removeObjectAtIndex:fromRow];
	[self.active insertObject:name atIndex:toRow];
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] reorderSupergroupActiveUsernames:self.active inChat:self.chatId
			completion:^(BOOL ok, NSString *error){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		me.busy = NO;
		if (!ok){
			me.active = [before mutableCopy];
			[me showRefusal:error title:@"Username Order"];
			[me rebuild];
			return;
		}
		[me rebuild];
	}];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
	NSDictionary *row = [self rowAtPath:path];
	if (!row)
		return;
	if ([row[@"kind"] integerValue] == TGGroupRowMember){
		[tableView deselectRowAtIndexPath:path animated:YES];
		// The row is a person: open their profile, never a chat. Send
		// Message and the administrator actions live on the hold.
		[TGGroupMemberActions openProfileForMember:row[@"member"] from:self];
		return;
	}
	NSString *action = row[@"action"];
	if (!action.length || [row[@"disabled"] boolValue])
		return;
	[tableView deselectRowAtIndexPath:path animated:YES];
	[self runAction:action];
}


@end
