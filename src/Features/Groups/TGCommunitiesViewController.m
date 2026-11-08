//
// TGCommunitiesViewController.m
//
#import "TGCommunitiesViewController.h"
#import "TGCommunityViewController.h"
#import "TGClient.h"
#import "TGAlertSheet.h"

@implementation TGCommunitiesViewController

- (void)viewDidLoad {
	self.title = @"Community";
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserverForName:TGCommunitiesChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){ [self rebuild]; }];
	[self rebuild];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self rebuild];
}

- (void)rebuild {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *rows = [NSMutableArray array];
	NSArray *communities = [TGClient shared].communities;
	for (NSDictionary *community in communities){
		int64_t communityId = [community[@"id"] longLongValue];
		NSString *detail = community[@"status"];
		if (![community[@"haveAccess"] boolValue])
			detail = @"Unavailable";
		NSMutableDictionary *row = TGFeatureOpenRow(community[@"name"] ?: @"Community",
											  detail, ^{
			TGCommunityViewController *screen =
					[[TGCommunityViewController alloc] initWithCommunity:community];
			screen.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:screen animated:YES];
		});
		row[@"communityId"] = @(communityId);
		[rows addObject:row];
	}
	if (!rows.count){
		NSMutableDictionary *empty = TGFeatureRow(@"No Results", nil, nil);
		empty[TGFeatureRowKind] = TGFeatureKindPlain;
		[rows addObject:empty];
	}

	NSMutableArray *createRows = [NSMutableArray array];
	[createRows addObject:TGFeatureAction(@"Create Community", ^{ [weakSelf createCommunity]; })];

	self.sections = @[
		TGFeatureSection(nil,
				nil, rows),
		TGFeatureSection(nil,
				nil, createRows),
	];
	[self reloadRows];
}

- (void)createCommunity {
	TGClient *client = [TGClient shared];
	NSMutableArray *titles = [NSMutableArray array];
	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *chat in client.chats){
		if (![chat[@"isGroup"] boolValue])
			continue;
		NSString *title = chat[@"title"];
		if (!title.length)
			continue;
		[titles addObject:title];
		[ids addObject:chat[@"id"]];
	}
	if (!titles.count){
		[self toast:@"An error occurred."];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles
						title:@"Community"
					  message:nil
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		if (index < 0 || index >= (NSInteger)ids.count)
			return;
		int64_t chatId = [ids[index] longLongValue];
		[TGAlertSheet showInput:@"Community Name"
						message:nil
					placeholder:@"Community name"
						   text:nil
						 action:@"Create"
						 inView:weakSelf.view
					   onSubmit:^(NSString *name){
			[TGAlertSheet showChoices:@[@"Visible", @"Hidden"]
								title:@"Chat Visibility"
							  message:nil
					 destructiveIndex:-1
							   inView:weakSelf.view
							 onChoice:^(NSInteger pick){
				BOOL hidden = (pick == 1);
				[[TGClient shared] createCommunity:name chatId:chatId hidden:hidden
										completion:^(int64_t communityId, NSString *error){
					if (!communityId){
						[weakSelf toast:error ?: @"An error occurred."];
						return;
					}
					NSDictionary *row = @{
						@"id"         : @(communityId),
						@"name"       : name,
						@"haveAccess" : @YES,
						@"status"     : @"Owner",
					};
					TGCommunityViewController *screen =
							[[TGCommunityViewController alloc] initWithCommunity:row];
					screen.hidesBottomBarWhenPushed = YES;
					[weakSelf.navigationController pushViewController:screen animated:YES];
				}];
			}];
		}];
	}];
}

@end
