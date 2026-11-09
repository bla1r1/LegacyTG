#import "TGActiveNotificationsViewController.h"
#import "TGClient.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGRows.h"

/// One date format for every row; creating one per cell was the usual
/// reason a notification list scrolls badly on an A5.
static NSString *TGNotificationDateText(NSNumber *timestamp) {
	static NSDateFormatter *formatter = nil;
	if (!formatter){
		formatter = [[NSDateFormatter alloc] init];
		formatter.dateStyle = NSDateFormatterShortStyle;
		formatter.timeStyle = NSDateFormatterShortStyle;
	}
	return [formatter stringFromDate:
			[NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]]];
}

@implementation TGActiveNotificationsViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Notifications");
	[self applyTheme];

	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:TGLocalized(@"Clear All")
					style:UIBarButtonItemStylePlain
				   target:self action:@selector(clearAll)];

	__weak typeof(self) weakSelf = self;
	[[NSNotificationCenter defaultCenter]
			addObserverForName:TGActiveNotificationsChangedNotification
						object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){
		[weakSelf reloadList];
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	[self reloadList];
}

- (NSArray *)groups {
	return [TGClient shared].activeNotificationGroups ?: @[];
}

- (BOOL)pending {
	return [TGClient shared].havePendingNotifications;
}

- (void)reloadList {
	self.navigationItem.rightBarButtonItem.enabled = self.groups.count > 0;
	[self rebuildSections];
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *sections = [NSMutableArray array];

	if (self.pending){
		[sections addObject:TGSection(nil, nil, @[
			TGRow(TGKindPlain, TGLocalized(@"Updating...")),
		])];
	}

	NSArray *groups = self.groups;
	if (!groups.count){
		[sections addObject:TGSection(TGLocalized(@"NOTIFICATIONS"), nil, @[
			TGRow(TGKindPlain, TGLocalized(@"None")),
		])];
	} else {
		for (NSDictionary *group in groups){
			NSString *title = [[TGClient shared] titleForChat:
					[group[@"chatId"] longLongValue]] ?: TGLocalized(@"Notifications");
			NSString *header = [NSString stringWithFormat:@"%@ · %@ · %@",
					title, group[@"type"] ?: TGLocalized(@"Messages"),
					group[@"totalCount"] ?: @(0)];
			NSMutableArray *rows = [NSMutableArray array];
			NSArray *notifications = group[@"notifications"];
			for (NSDictionary *note in notifications){
				NSString *detail = [NSString stringWithFormat:@"%@ · %@",
						note[@"kind"] ?: TGLocalized(@"Notifications"),
						TGNotificationDateText(note[@"date"])];
				[rows addObject:TGSubtitleRow(note[@"text"] ?: TGLocalized(@"Notifications"),
						detail, ^{ [weakSelf removeNotification:note inGroup:group]; })];
			}
			if (!rows.count)
				[rows addObject:TGRow(TGKindPlain, TGLocalized(@"None"))];
			[sections addObject:TGSection(header, nil, rows)];
		}
	}

	self.sections = sections;
	[self reloadRows];
}

- (void)removeNotification:(NSDictionary *)note inGroup:(NSDictionary *)group {
	int32_t groupId = (int32_t)[group[@"id"] intValue];
	int32_t notificationId = (int32_t)[note[@"id"] intValue];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[TGLocalized(@"Delete")]
						title:note[@"text"] ?: TGLocalized(@"Notifications")
			 destructiveIndex:0
					   inView:self.view
					 onChoice:^(NSInteger choice){
		[[TGClient shared] removeNotification:notificationId inGroup:groupId
								   completion:^(BOOL ok, NSString *error){
			if (!ok)
				[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
									title:TGLocalized(@"Notifications")
								   inView:weakSelf.view];
			[weakSelf reloadList];
		}];
	}];
}

- (void)clearAll {
	if (!self.groups.count)
		return;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:TGLocalized(@"Clear All")
					   action:TGLocalized(@"Clear")
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		NSArray *groups = weakSelf.groups;
		for (NSDictionary *group in groups){
			int32_t maxId = 0;
			for (NSDictionary *row in group[@"notifications"])
				maxId = MAX(maxId, (int32_t)[row[@"id"] intValue]);
			[[TGClient shared] removeNotificationGroup:(int32_t)[group[@"id"] intValue]
									  maxNotificationId:maxId
											 completion:^(BOOL ok, NSString *error){
				(void)error;
				[weakSelf reloadList];
			}];
		}
	}];
}

@end
