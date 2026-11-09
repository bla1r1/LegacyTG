#import "TGDiceViewController.h"
#import "TGAlertSheet.h"
#import "TGClient.h"
#import "TGRows.h"

@interface TGDiceViewController ()
@property (nonatomic, strong) NSDictionary *state;
@end

@implementation TGDiceViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.chatTitle.length
			? [NSString stringWithFormat:@"%@ · %@", self.chatTitle,
					TGLocalized(@"Dice")]
			: TGLocalized(@"Stake");
	[self rebuildSections];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:TGLocalized(@"Update")
					style:UIBarButtonItemStylePlain
				   target:self action:@selector(refreshTapped)];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(stateChanged:)
				name:TGStakeDiceStateChangedNotification object:nil];
	[self refresh];
}

- (void)stateChanged:(NSNotification *)note {
	// The cached state is internal; a notification means a newer one exists,
	// so the panel asks once rather than reading a property it may not see.
	[self refresh];
}

- (void)refreshTapped {
	[self refresh];
}

- (void)refresh {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] stakeDiceStateWithCompletion:^(NSDictionary *state,
													  NSString *error){
		TGDiceViewController *me = weakSelf;
		if (!me)
			return;
		if (error.length){
			[TGAlertSheet showMessage:error title:TGLocalized(@"Stake")
							   inView:me.view];
			return;
		}
		me.state = state;
		[me rebuildSections];
	}];
}

#pragma mark - rows

- (NSArray *)suggestedStakes {
	id value = self.state[@"suggestedStakeGramAmounts"];
	return [value isKindOfClass:NSArray.class] ? value : @[];
}

- (NSArray *)prizeTable {
	id value = self.state[@"prizePerMille"];
	return [value isKindOfClass:NSArray.class] ? value : @[];
}

- (void)rebuildSections {
	NSMutableArray *statusRows = [NSMutableArray array];
	NSMutableArray *suggestedRows = [NSMutableArray array];
	NSMutableArray *prizeRows = [NSMutableArray array];
	if (!self.state){
		[statusRows addObject:TGRow(TGKindPlain, TGLocalized(@"Loading..."))];
	} else {
		for (NSDictionary *model in TGDiceStatusRows(self.state, self.chatId))
			[statusRows addObject:TGSubtitleRow(model[@"title"],
					model[@"detail"], nil)];
		for (NSDictionary *model in TGDiceSuggestedRows([self suggestedStakes]))
			[suggestedRows addObject:TGSubtitleRow(model[@"title"], nil, nil)];
		for (NSDictionary *model in TGDicePrizeRows([self prizeTable]))
			[prizeRows addObject:TGSubtitleRow(model[@"title"],
					model[@"detail"], nil)];
	}
	self.sections = @[
		TGSection(TGLocalized(@"Status"), nil, statusRows),
		TGSection(TGLocalized(@"Suggested Stakes"), nil, suggestedRows),
		TGSection(TGLocalized(@"Prize per 1000"), nil, prizeRows),
	];
	[self reloadRows];
}

@end
