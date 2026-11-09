#import "TGSessionsViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGAlertSheet.h"
#import "TGQRViewController.h"
#import "TGWebsitesViewController.h"
#import "TGRows.h"

@interface TGSessionsViewController ()
@property (nonatomic, strong) NSArray *sessions;
/// Days a session may sit idle before Telegram signs it out, from the same
/// getActiveSessions answer that filled `sessions`.
@property (nonatomic, assign) NSInteger inactiveTtl;
@property (nonatomic, assign) BOOL ttlLoaded;
@end

@implementation TGSessionsViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Devices");
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

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
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
		[weakSelf rebuildSections];
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

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSArray *kinds = [self sectionKinds];
	NSMutableArray *sections = [NSMutableArray array];

	for (NSString *kind in kinds){
		if ([kind isEqualToString:@"this"]){
			NSMutableArray *rows = [NSMutableArray array];
			NSDictionary *current = [self currentSession];
			if (current){
				[rows addObject:TGSubtitleRow(TGSessionRowTitle(current),
						TGSessionRowDetail(current, YES),
						^{ [weakSelf showSessionActions:current isCurrent:YES]; })];
			} else {
				[rows addObject:TGRow(TGKindPlain, @"Loading...")];
			}
			if ([self othersOnly].count){
				[rows addObject:TGRedRow(@"Terminate all other sessions", ^{
					[weakSelf confirmTerminateAll];
				})];
			}
			[sections addObject:TGSection(TGLocalized(@"THIS DEVICE"), nil, rows)];
		} else if ([kind isEqualToString:@"unconfirmed"]){
			NSMutableArray *rows = [NSMutableArray array];
			for (NSDictionary *session in [self unconfirmedSessions]){
				[rows addObject:TGSubtitleRow(TGSessionRowTitle(session),
						TGSessionRowDetail(session, NO),
						^{ [weakSelf showSessionActions:session isCurrent:NO]; })];
			}
			[sections addObject:TGSection(
					TGLocalized(@"INCOMPLETE LOGIN ATTEMPTS"), nil, rows)];
		} else if ([kind isEqualToString:@"other"]){
			NSMutableArray *rows = [NSMutableArray array];
			NSArray *others = [self otherSessions];
			if (!others.count){
				[rows addObject:TGRow(TGKindPlain, @"No other sessions")];
			} else {
				for (NSDictionary *session in others){
					[rows addObject:TGSubtitleRow(TGSessionRowTitle(session),
							TGSessionRowDetail(session, NO),
							^{ [weakSelf showSessionActions:session isCurrent:NO]; })];
				}
			}
			[sections addObject:TGSection(TGLocalized(@"ACTIVE SESSIONS"), nil, rows)];
		} else if ([kind isEqualToString:@"websites"]){
			[sections addObject:TGSection(TGLocalized(@"Websites"), nil, @[
				TGTapRow(@"Active Websites", nil, ^{ [weakSelf openWebsites]; }),
				TGTapRow(@"Scan QR Code", nil, ^{ [weakSelf openScanner]; }),
			])];
		} else if ([kind isEqualToString:@"ttl"]){
			[sections addObject:TGSection(TGLocalized(@"IF AWAY FOR"), nil, @[
				TGTapRow(TGLocalized(@"If Away For"),
						TGSessionTtlDetail(self.inactiveTtl, self.ttlLoaded),
						^{ [weakSelf showTtlChoices]; }),
			])];
		}
	}

	self.sections = sections;
	[self reloadRows];
}

#pragma mark - actions

- (void)openWebsites {
	TGWebsitesViewController *sites = [[TGWebsitesViewController alloc] init];
	sites.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:sites animated:YES];
}

- (void)openScanner {
	TGQRViewController *scanner = [[TGQRViewController alloc] init];
	scanner.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:scanner animated:YES];
}

- (void)confirmTerminateAll {
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
}

- (void)showTtlChoices {
	// 1-366 days is TDLib's own range. The presets are the spans their page
	// offers; anything finer would be a number nobody means.
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
}

- (void)showSessionActions:(NSDictionary *)session isCurrent:(BOOL)isCurrent {
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
