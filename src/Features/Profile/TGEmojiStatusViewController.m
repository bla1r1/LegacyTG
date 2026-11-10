#import "TGEmojiStatusViewController.h"
#import "TGLocalization.h"
#import "TGAlertSheet.h"
#import "TGProfileStore.h"
#import "TGCustomEmojiStore.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGIcons.h"
#import "TGRows.h"
#import "TGGridRowCell.h"

/// The status durations Telegram offers. Forever is 0, which is what TDLib
/// stores for a status with no end.
static const NSTimeInterval kStatusHour = 60 * 60;
static const NSTimeInterval kStatusTwoHours = 2 * kStatusHour;
static const NSTimeInterval kStatusEightHours = 8 * kStatusHour;
static const NSTimeInterval kStatusTwoDays = 48 * kStatusHour;

#pragma mark - the picker

@interface TGEmojiStatusViewController ()
@property (nonatomic, strong) NSMutableDictionary *stickerByEmojiId;
@property (nonatomic, strong) NSArray *themedIds;
@property (nonatomic, strong) NSArray *defaultIds;
@property (nonatomic, strong) NSArray *recentIds;
@property (nonatomic, strong) NSArray *refusedIds;
@end

@implementation TGEmojiStatusViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.subjectTitle.length ? self.subjectTitle
			: TGLocalized(@"Emoji Status");
	self.stickerByEmojiId = [NSMutableDictionary dictionary];
	self.themedIds = @[];
	self.defaultIds = @[];
	self.recentIds = @[];
	self.refusedIds = @[];
	[self applyTheme];

	if (self.target != TGEmojiStatusTargetChat)
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
				initWithTitle:TGLocalized(@"Clear")
						style:UIBarButtonItemStylePlain
					   target:self action:@selector(clearTapped)];

	[self loadLists];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(emojiPictureReady:)
				name:TGCustomEmojiLoadedNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)emojiPictureReady:(NSNotification *)note {
	(void)note;
	[self reloadRows];
}

#pragma mark - the lists

/// Three lists, in the order Telegram shows them: the themed strip first,
/// the default shelf under it, then what was worn lately. A chat has no
/// recent list, and it has one extra list of statuses it refuses.
- (void)loadLists {
	__weak typeof(self) weakSelf = self;
	if (self.target == TGEmojiStatusTargetChat){
		__block NSArray *themed = nil, *standard = nil, *refused = nil;
		__block NSInteger pending = 3;
		void (^done)(void) = ^{
			TGEmojiStatusViewController *me = weakSelf;
			if (!me || --pending > 0)
				return;
			[me buildSectionsWithThemed:themed default:standard
								recent:@[] refused:refused];
		};
		[[TGProfileStore shared] themedChatEmojiStatusesWithCompletion:^(NSArray *ids){
			themed = ids; done();
		}];
		[[TGProfileStore shared] defaultChatEmojiStatusesWithCompletion:^(NSArray *ids){
			standard = ids; done();
		}];
		[[TGProfileStore shared] disallowedChatEmojiStatusesWithCompletion:^(NSArray *ids){
			refused = ids; done();
		}];
		return;
	}

	__block NSArray *themed = nil, *standard = nil, *recent = nil;
	__block NSInteger pending = 3;
	void (^done)(void) = ^{
		TGEmojiStatusViewController *me = weakSelf;
		if (!me || --pending > 0)
			return;
		NSMutableArray *recentIds = [NSMutableArray array];
		for (NSDictionary *row in recent)
			if ([row[@"emojiId"] longLongValue] > 0)
				[recentIds addObject:row[@"emojiId"]];
		[me buildSectionsWithThemed:themed default:standard
							recent:recentIds refused:@[]];
	};
	[[TGProfileStore shared] themedEmojiStatusesWithCompletion:^(NSArray *ids){
		themed = ids; done();
	}];
	[[TGProfileStore shared] defaultEmojiStatusesWithCompletion:^(NSArray *ids){
		standard = ids; done();
	}];
	[[TGProfileStore shared] recentEmojiStatusesWithCompletion:^(NSArray *rows){
		recent = rows; done();
	}];
}

- (NSArray *)uniqueIds:(NSArray *)ids excluding:(NSSet *)excluded {
	NSMutableArray *out = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];
	for (id raw in ids ?: @[]){
		NSNumber *identifier = @([raw longLongValue]);
		if ([identifier longLongValue] <= 0)
			continue;
		if ([seen containsObject:identifier] || [excluded containsObject:identifier])
			continue;
		[seen addObject:identifier];
		[out addObject:identifier];
	}
	return out;
}

- (void)buildSectionsWithThemed:(NSArray *)themed
						default:(NSArray *)standard
						 recent:(NSArray *)recent
						refused:(NSArray *)refused {
	NSMutableSet *used = [NSMutableSet set];
	NSArray *themedIds = [self uniqueIds:themed excluding:nil];
	[used addObjectsFromArray:themedIds];
	NSArray *defaultIds = [self uniqueIds:standard excluding:used];
	[used addObjectsFromArray:defaultIds];
	NSArray *recentIds = [self uniqueIds:recent excluding:used];
	[used addObjectsFromArray:recentIds];
	NSArray *refusedIds = [self uniqueIds:refused excluding:nil];

	self.themedIds = themedIds;
	self.defaultIds = defaultIds;
	self.recentIds = recentIds;
	self.refusedIds = refusedIds;
	[self rebuildSections];

	NSMutableArray *all = [NSMutableArray array];
	for (NSArray *list in @[themedIds, defaultIds, recentIds, refusedIds])
		[all addObjectsFromArray:list];
	[self fetchStickersForIds:all];
}

- (CGFloat)gridWidth {
	CGFloat width = self.tableView.bounds.size.width - TGMetricGridTableMargin;
	return width > 0 ? width : TGMetricScreenWidth - TGMetricGridTableMargin;
}

- (NSInteger)gridColumns {
	return MIN(TGGridColumnsForWidth([self gridWidth], TGMetricEmojiCell),
			TGMetricEmojiStatusGridColumns);
}

- (NSArray *)rowsForIds:(NSArray *)ids {
	__weak typeof(self) weakSelf = self;
	NSInteger columns = [self gridColumns];
	CGFloat side = TGGridTileSideForWidth([self gridWidth], columns);
	NSMutableArray *rows = [NSMutableArray array];
	for (NSUInteger start = 0; start < ids.count;
			start += (NSUInteger)columns){
		NSRange range = NSMakeRange(start, MIN((NSUInteger)columns,
				ids.count - start));
		NSArray *lineIds = [ids subarrayWithRange:range];
		NSMutableArray *tiles = [NSMutableArray array];
		for (NSNumber *identifier in lineIds){
			NSDictionary *sticker = self.stickerByEmojiId[identifier] ?: @{};
			NSMutableDictionary *tile = [NSMutableDictionary dictionary];
			UIImage *image = [[TGCustomEmojiStore shared]
					imageForId:identifier.longLongValue side:side];
			if (image)
				tile[TGGridItemImage] = image;
			if ([sticker[@"emoji"] isKindOfClass:NSString.class])
				tile[TGGridItemEmoji] = sticker[@"emoji"];
			[tiles addObject:tile];
		}
		[rows addObject:TGGridRow(tiles, columns, ^(NSInteger index){
			NSUInteger absolute = start + (NSUInteger)index;
			if (absolute < ids.count)
				[weakSelf chooseEmojiId:[ids[absolute] longLongValue]];
		})];
	}
	return rows;
}

- (void)rebuildSections {
	NSMutableArray *sections = [NSMutableArray array];
	if (self.themedIds.count)
		[sections addObject:TGSection(TGLocalized(@"Emoji Statuses"), nil,
				[self rowsForIds:self.themedIds])];
	if (self.defaultIds.count)
		[sections addObject:TGSection(TGLocalized(@"Default"), nil,
				[self rowsForIds:self.defaultIds])];
	if (self.recentIds.count)
		[sections addObject:TGSection(TGLocalized(@"Recently Used"), nil,
				[self rowsForIds:self.recentIds])];
	if (self.refusedIds.count)
		[sections addObject:TGSection(TGLocalized(@"Emoji Status"), nil,
				[self rowsForIds:self.refusedIds])];
	if (self.target != TGEmojiStatusTargetChat){
		__weak typeof(self) weakSelf = self;
		[sections addObject:TGSection(nil, nil, @[
			TGTapRow(TGLocalized(@"Clear Recent Emoji"), nil,
					^{ [weakSelf clearRecent]; }),
		])];
	}
	self.sections = sections;
	[self reloadRows];
}

/// Custom emoji ids are not characters: the character and the picture both
/// come from getCustomEmojiStickers. One request covers every id on screen;
/// the pictures themselves are then served by TGCustomEmojiStore.
- (void)fetchStickersForIds:(NSArray *)ids {
	if (!ids.count)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] customEmojiStickersForIds:ids
									  completion:^(NSArray *stickers){
		TGEmojiStatusViewController *me = weakSelf;
		if (!me)
			return;
		for (NSDictionary *sticker in stickers){
			NSNumber *identifier = sticker[@"customEmojiId"];
			if (![identifier isKindOfClass:NSNumber.class])
				continue;
			me.stickerByEmojiId[identifier] = sticker;
		}
		[[TGCustomEmojiStore shared] receiveStickers:stickers forIds:ids];
		[me rebuildSections];
	}];
}

#pragma mark - clearing recent

- (void)clearRecent {
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] clearRecentEmojiStatusesWithCompletion:^(BOOL ok, NSString *error){
		[weakSelf showResult:ok error:error title:TGLocalized(@"Recently Used")];
		if (ok)
			[weakSelf loadLists];
	}];
}

#pragma mark - setting a status

- (void)chooseEmojiId:(int64_t)emojiId {
	__weak typeof(self) weakSelf = self;
	NSArray *titles = @[
		TGLocalizedPluralValue(@"%@ hour", @"%@ hours", @"1", 1),
		TGLocalizedPluralValue(@"%@ hour", @"%@ hours", @"2", 2),
		TGLocalizedPluralValue(@"%@ hour", @"%@ hours", @"8", 8),
		TGLocalizedPluralValue(@"%@ day", @"%@ days", @"2", 2),
		TGLocalized(@"Forever"),
	];
	NSArray *durations = @[@(kStatusHour), @(kStatusTwoHours),
						   @(kStatusEightHours), @(kStatusTwoDays), @(0)];
	[TGAlertSheet showChoices:titles
						title:TGLocalized(@"Set Emoji Status")
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		if (index < 0 || index >= (NSInteger)durations.count)
			return;
		NSTimeInterval seconds = [durations[(NSUInteger)index] doubleValue];
		int64_t expiration = seconds > 0
				? (int64_t)([[NSDate date] timeIntervalSince1970] + seconds) : 0;
		[weakSelf applyEmojiId:emojiId expirationDate:expiration];
	}];
}

- (void)applyEmojiId:(int64_t)emojiId expirationDate:(int64_t)expiration {
	__weak typeof(self) weakSelf = self;
	NSString *title = self.subjectTitle ?: TGLocalized(@"Emoji Status");
	if (self.target == TGEmojiStatusTargetChat){
		[[TGProfileStore shared] setChatEmojiStatus:emojiId expirationDate:expiration
									  inChat:self.chatId
								  completion:^(BOOL ok, NSString *error){
			[weakSelf showResult:ok error:error title:title];
		}];
		return;
	}
	if (self.target == TGEmojiStatusTargetUser){
		[[TGProfileStore shared] setUserEmojiStatus:emojiId expirationDate:expiration
									  forUser:self.userId
								   completion:^(BOOL ok, NSString *error){
			[weakSelf showResult:ok error:error title:title];
		}];
		return;
	}
	[[TGProfileStore shared] setEmojiStatus:emojiId expirationDate:expiration
						  completion:^(BOOL ok, NSString *error){
		[weakSelf showResult:ok error:error title:title];
	}];
}

- (void)clearTapped {
	__weak typeof(self) weakSelf = self;
	if (self.target == TGEmojiStatusTargetUser){
		[[TGProfileStore shared] setUserEmojiStatus:0 expirationDate:0
									  forUser:self.userId
								   completion:^(BOOL ok, NSString *error){
			[weakSelf showResult:ok error:error title:TGLocalized(@"Emoji Status")];
		}];
		return;
	}
	[[TGProfileStore shared] setEmojiStatus:0 expirationDate:0
						  completion:^(BOOL ok, NSString *error){
		[weakSelf showResult:ok error:error title:TGLocalized(@"Emoji Status")];
	}];
}

- (void)showResult:(BOOL)ok error:(NSString *)error title:(NSString *)title {
	[TGAlertSheet showMessage:(ok ? TGLocalized(@"Saved")
								   : (error ?: TGLocalized(@"An error occurred.")))
						title:title inView:self.view];
}

@end

// vim:ft=objc
