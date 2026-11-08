#import "TGSessionsViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGAlertSheet.h"
#import "TGQRViewController.h"
#import "TGWebsitesViewController.h"

@interface TGSessionsViewController ()
@property (nonatomic, strong) NSArray *sessions;
/// Days a session may sit idle before Telegram signs it out, from the same
/// getActiveSessions answer that filled `sessions`.
@property (nonatomic, assign) NSInteger inactiveTtl;
@property (nonatomic, assign) BOOL ttlLoaded;
@end

@implementation TGSessionsViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Devices";
	[self applyTheme];
	[self refresh];

	__weak typeof(self) weakSelf = self;
	// A new login waiting to be confirmed arrives as updateUnconfirmedSession
	// while this list is open; re-reading is how the row gets its Confirm.
	[[NSNotificationCenter defaultCenter] addObserverForName:TGSessionsChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note) {
		[weakSelf refresh];
	}];
}

- (void)applyTheme {
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	self.navigationItem.rightBarButtonItem = [self otherSessions].count
			? self.editButtonItem : nil;
}

- (void)refresh {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sessionsWithInactiveTtlCompletion:^(NSArray *sessions, NSInteger ttlDays){
		weakSelf.sessions = sessions;
		weakSelf.inactiveTtl = ttlDays;
		weakSelf.ttlLoaded = YES;
		weakSelf.navigationItem.rightBarButtonItem = [weakSelf otherSessions].count
				? weakSelf.editButtonItem : nil;
		[weakSelf.tableView reloadData];
	}];
}

/// Current session first, the way every client orders this list.
- (NSArray *)othersOnly {
	NSMutableArray *others = [NSMutableArray array];
	for (NSDictionary *session in self.sessions)
		if (![session[@"isCurrent"] boolValue])
			[others addObject:session];
	return others;
}

- (NSArray *)unconfirmedSessions {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *session in self.sessions)
		if (![session[@"isCurrent"] boolValue] &&
			[session[@"isUnconfirmed"] boolValue])
			[out addObject:session];
	return out;
}

- (NSArray *)otherSessions {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *session in self.sessions)
		if (![session[@"isCurrent"] boolValue] &&
			![session[@"isUnconfirmed"] boolValue])
			[out addObject:session];
	return out;
}

- (NSDictionary *)currentSession {
	for (NSDictionary *session in self.sessions)
		if ([session[@"isCurrent"] boolValue])
			return session;
	return nil;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *kinds = [self sectionKinds];
	if (indexPath.section >= (NSInteger)kinds.count)
		return NO;
	return [kinds[(NSUInteger)indexPath.section] isEqualToString:@"other"] &&
			[self otherSessions].count > 0;
}

- (void)tableView:(UITableView *)tableView
		commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
		 forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *kinds = [self sectionKinds];
	if (editingStyle != UITableViewCellEditingStyleDelete ||
		indexPath.section >= (NSInteger)kinds.count ||
		![kinds[(NSUInteger)indexPath.section] isEqualToString:@"other"])
		return;
	NSArray *others = [self otherSessions];
	if (indexPath.row >= (NSInteger)others.count)
		return;
	int64_t sessionId = [others[(NSUInteger)indexPath.row][@"id"] longLongValue];
	[[TGClient shared] terminateSession:sessionId];
	[self performSelector:@selector(refresh) withObject:nil afterDelay:1.0];
}

/// The TTL is a span, not a number of days; the official row says "6 months"
/// rather than "180".
- (NSString *)ttlDetail {
	NSInteger days = self.inactiveTtl;
	if (days <= 0)
		return @"Disabled";
	if (days == 7)
		return TGLocalizedPluralValue(@"%@ week", @"%@ weeks", @"1", 1);
	if (days == 180)
		return TGLocalizedPluralValue(@"%@ month", @"%@ months", @"6", 6);
	if (days == 365 || days == 366)
		return TGLocalizedPluralValue(@"%@ year", @"%@ years", @"1", 1);
	if (days == 30)
		return TGLocalizedPluralValue(@"%@ month", @"%@ months", @"1", 1);
	if (days == 90)
		return TGLocalizedPluralValue(@"%@ month", @"%@ months", @"3", 3);
	return TGLocalizedPluralValue(@"%@ day", @"%@ days",
			[NSString stringWithFormat:@"%ld", (long)days], days);
}

/// The official order: this device with its terminate action, incomplete
/// attempts when there are any, the other sessions, websites, then the TTL.
- (NSArray *)sectionKinds {
	NSMutableArray *kinds = [NSMutableArray arrayWithObject:@"this"];
	if ([self unconfirmedSessions].count)
		[kinds addObject:@"unconfirmed"];
	[kinds addObject:@"other"];
	[kinds addObject:@"websites"];
	[kinds addObject:@"ttl"];
	return kinds;
}



#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (NSInteger)[self sectionKinds].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSArray *kinds = [self sectionKinds];
	if (section >= (NSInteger)kinds.count)
		return nil;
	NSString *kind = kinds[(NSUInteger)section];
	if ([kind isEqualToString:@"this"])        return @"THIS DEVICE";
	if ([kind isEqualToString:@"unconfirmed"]) return @"INCOMPLETE LOGIN ATTEMPTS";
	if ([kind isEqualToString:@"other"])       return TGLocalized(@"ACTIVE SESSIONS");
	if ([kind isEqualToString:@"websites"])    return @"Websites";
	return TGLocalized(@"IF AWAY FOR");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSArray *kinds = [self sectionKinds];
	if (section >= (NSInteger)kinds.count)
		return 0;
	NSString *kind = kinds[(NSUInteger)section];
	if ([kind isEqualToString:@"this"])
		return 1 + ([self othersOnly].count > 0 ? 1 : 0);
	if ([kind isEqualToString:@"unconfirmed"])
		return (NSInteger)[self unconfirmedSessions].count;
	if ([kind isEqualToString:@"other"])
		return MAX((NSInteger)[self otherSessions].count, (NSInteger)1);
	if ([kind isEqualToString:@"websites"])
		return 2;
	return 1;   // terminate if away
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"row"];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.textLabel.textAlignment = NSTextAlignmentLeft;

	NSArray *kinds = [self sectionKinds];
	if (indexPath.section >= (NSInteger)kinds.count)
		return cell;
	NSString *kind = kinds[(NSUInteger)indexPath.section];

	if ([kind isEqualToString:@"this"] && indexPath.row == 1){
		cell.textLabel.text = @"Terminate all other sessions";
		cell.textLabel.textColor = [[TGTheme shared] destructiveColour];
		cell.detailTextLabel.text = nil;
		cell.textLabel.textAlignment = NSTextAlignmentCenter;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	if ([kind isEqualToString:@"websites"]){
		cell.textLabel.text = indexPath.row == 1 ? @"Scan QR Code" : @"Active Websites";
		cell.detailTextLabel.text = nil;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	if ([kind isEqualToString:@"ttl"]){
		NSString *detail = self.ttlLoaded ? [self ttlDetail] : @"...";
		cell.textLabel.text = TGLocalized(@"If Away For");
		cell.detailTextLabel.text = detail;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	if ([kind isEqualToString:@"other"] && ![self otherSessions].count){
		cell.textLabel.text = @"No other sessions";
		cell.detailTextLabel.text = nil;
		cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}

	NSDictionary *session = nil;
	if ([kind isEqualToString:@"this"]){
		session = [self currentSession];
	} else if ([kind isEqualToString:@"unconfirmed"]){
		NSArray *rows = [self unconfirmedSessions];
		if (indexPath.row < (NSInteger)rows.count)
			session = rows[(NSUInteger)indexPath.row];
	} else {
		NSArray *rows = [self otherSessions];
		if (indexPath.row < (NSInteger)rows.count)
			session = rows[(NSUInteger)indexPath.row];
	}
	if (!session){
		cell.textLabel.text = @"Loading...";
		cell.detailTextLabel.text = nil;
		cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}
	cell.textLabel.text = session[@"name"];
	NSMutableArray *parts = [NSMutableArray array];
	if ([session[@"platform"] length])
		[parts addObject:session[@"platform"]];
	if ([session[@"ip"] length])
		[parts addObject:session[@"ip"]];
	if ([kind isEqualToString:@"this"])
		[parts addObject:@"online"];
	if ([session[@"isUnconfirmed"] boolValue])
		[parts addObject:@"Confirm"];
	cell.detailTextLabel.text = [parts componentsJoinedByString:@" · "];
	// This device's own row opens the same switches, because a phone that
	// should not ring is a setting about the session, not about the others.
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	NSArray *kinds = [self sectionKinds];
	if (indexPath.section >= (NSInteger)kinds.count)
		return;
	NSString *kind = kinds[(NSUInteger)indexPath.section];

	if ([kind isEqualToString:@"websites"] && indexPath.row == 1){
		TGQRViewController *scanner = [[TGQRViewController alloc] init];
		scanner.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:scanner animated:YES];
		return;
	}

	if ([kind isEqualToString:@"ttl"]){
		// 1-366 days is TDLib's own range. The presets are the spans their
		// page offers; anything finer would be a number nobody means.
		NSArray *titles = @[
			TGLocalizedPluralValue(@"%@ week", @"%@ weeks", @"1", 1),
			TGLocalizedPluralValue(@"%@ month", @"%@ months", @"1", 1),
			TGLocalizedPluralValue(@"%@ month", @"%@ months", @"3", 3),
			TGLocalizedPluralValue(@"%@ month", @"%@ months", @"6", 6),
			TGLocalizedPluralValue(@"%@ year", @"%@ years", @"1", 1),
		];
		NSArray *days = @[@7, @30, @90, @180, @365];
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:titles
							title:@"Automatically Terminate Old Sessions"
						  message:nil
				 destructiveIndex:-1
						   inView:self.view
						 onChoice:^(NSInteger index){
			[[TGClient shared] setInactiveSessionTtlDays:[days[(NSUInteger)index] integerValue]
											 completion:^(BOOL ok, NSString *error){
				if (!ok){
					[TGAlertSheet showMessage:(error ?: @"An error occurred.")
										title:@"Automatically Terminate Old Sessions"
									   inView:weakSelf.view];
					return;
				}
				[weakSelf performSelector:@selector(refresh)
							   withObject:nil afterDelay:0.5];
			}];
		}];
		return;
	}

	if ([kind isEqualToString:@"websites"]){
		TGWebsitesViewController *sites = [[TGWebsitesViewController alloc] init];
		sites.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:sites animated:YES];
		return;
	}

	if ([kind isEqualToString:@"this"] && indexPath.row == 1){
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showConfirm:nil
							title:@"Terminate all other sessions"
						   action:@"Terminate"
					  destructive:YES
						   inView:self.view
						onConfirm:^{
			[[TGClient shared] terminateAllOtherSessions:^(BOOL ok){
				TGSessionsViewController *me = weakSelf;
				if (!ok){
					[TGAlertSheet showMessage:@"An error occurred."
										title:@"Active Sessions" inView:me.view];
					return;
				}
				// The server needs a moment before the list reflects it.
				[me performSelector:@selector(refresh) withObject:nil afterDelay:1.0];
			}];
		}];
		return;
	}

	BOOL isCurrent = [kind isEqualToString:@"this"];
	NSDictionary *session = nil;
	if (isCurrent){
		session = [self currentSession];
	} else if ([kind isEqualToString:@"unconfirmed"]){
		NSArray *rows = [self unconfirmedSessions];
		if (indexPath.row < (NSInteger)rows.count)
			session = rows[(NSUInteger)indexPath.row];
	} else if ([kind isEqualToString:@"other"]){
		NSArray *rows = [self otherSessions];
		if (indexPath.row < (NSInteger)rows.count)
			session = rows[(NSUInteger)indexPath.row];
	}
	if (!session)
		return;
	int64_t sessionId = [session[@"id"] longLongValue];
	if (!sessionId)
		return;

	__weak typeof(self) weakSelf = self;
	void (^signOut)(void) = ^{
		[TGAlertSheet showConfirm:nil
							title:@"Log Out"
						   action:@"Log Out"
					  destructive:YES
						   inView:weakSelf.view
						onConfirm:^{
			[[TGClient shared] terminateSession:sessionId];
			// The server needs a moment before the list reflects it.
			[weakSelf performSelector:@selector(refresh) withObject:nil afterDelay:1.0];
		}];
	};

	// A session's three switches are worth reaching from its row: a device that
	// should not accept secret chats or ring can be told so without signing it
	// out, and a login Telegram has not seen confirmed gets its Confirm beside
	// them.
	BOOL canAccept = [session[@"canAcceptSecretChats"] boolValue];
	NSString *secretTitle = [NSString stringWithFormat:@"%@ %@",
			TGLocalized(canAccept ? @"Disable" : @"Enable"),
			TGLocalized(@"New Secret Chats")];
	BOOL canAcceptCalls = [session[@"canAcceptCalls"] boolValue];
	NSString *callsTitle = [NSString stringWithFormat:@"%@ %@",
			TGLocalized(canAcceptCalls ? @"Disable" : @"Enable"),
			TGLocalized(@"Calls")];
	NSMutableArray *choices = [NSMutableArray array];
	if ([session[@"isUnconfirmed"] boolValue])
		[choices addObject:@"Confirm"];
	[choices addObject:secretTitle];
	[choices addObject:callsTitle];
	if (!isCurrent)
		[choices addObject:@"Log Out"];

	[TGAlertSheet showChoices:choices
						title:session[@"name"]
			 destructiveIndex:isCurrent ? -1 : (NSInteger)choices.count - 1
					   inView:self.view
					 onChoice:^(NSInteger index){
		NSString *choice = choices[(NSUInteger)index];
		if ([choice isEqualToString:@"Confirm"]){
			[[TGClient shared] confirmSession:sessionId];
			[weakSelf performSelector:@selector(refresh) withObject:nil afterDelay:1.0];
			return;
		}
		if ([choice isEqualToString:secretTitle]){
			[[TGClient shared] toggleSession:sessionId canAcceptSecretChats:!canAccept];
			[weakSelf performSelector:@selector(refresh) withObject:nil afterDelay:0.5];
			return;
		}
		if ([choice isEqualToString:callsTitle]){
			[[TGClient shared] toggleSession:sessionId
							   canAcceptCalls:!canAcceptCalls
								   completion:^(BOOL ok, NSString *error){
				if (!ok){
					[TGAlertSheet showMessage:(error ?: @"An error occurred.")
										title:session[@"name"]
									   inView:weakSelf.view];
					return;
				}
				[weakSelf performSelector:@selector(refresh)
							   withObject:nil afterDelay:0.5];
			}];
			return;
		}
		signOut();
	}];
}

@end

// vim:ft=objc
