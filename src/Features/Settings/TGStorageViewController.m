#import "TGStorageViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGSettingsFormatting.h"
#import "TGRows.h"
#import "TGRowCell.h"

// Their storage page opens with a ring: the total in the middle, one arc per
// kind of file, the same colours in the list underneath. A column of numbers
// says the same thing and none of it at a glance.
static const CGFloat kRingSide  = TGMetricStorageRingSide;
static const CGFloat kRingWidth = TGMetricStorageRingWidth;
/// Room under the ring for the total it holds, and the box that total is set
/// in - a line and a half, because it is two lines when the figure is long.
static const CGFloat kRingHeaderRoom = 54.0f;
static const CGFloat kRingTotalLine  = TGMetricVoicePillWidth;

static UIColor *TGSliceColour(NSUInteger index);

@interface TGStorageViewController ()
@property (nonatomic, strong) NSArray *categories;   // name / bytes / kinds
@property (nonatomic, assign) long long total;
@property (nonatomic, assign) NSInteger fileCount;
@property (nonatomic, assign) BOOL working;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) NSMutableSet *selectedKinds;
@property (nonatomic, assign) long long selectedBytes;
@property (nonatomic, copy) NSString *totalText;
@property (nonatomic, copy) NSString *selectedText;
@property (nonatomic, assign) NSInteger keepMediaIndex;
@property (nonatomic, assign) NSInteger maxCacheIndex;
@end

@implementation TGStorageViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_keepMediaIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"TGStorageKeepMedia"];
		if (_keepMediaIndex < 0 || _keepMediaIndex > 3) _keepMediaIndex = 3; // Forever default
		_maxCacheIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"TGStorageMaxCache"];
		if (_maxCacheIndex < 0 || _maxCacheIndex > 3) _maxCacheIndex = 3;  // No Limit default
	}
	return self;
}

- (BOOL)hasClearSection {
	return self.selectedKinds.count > 0;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Storage Usage");
	self.categories = @[];
	self.selectedKinds = [NSMutableSet set];
	[self refresh];
	[self loadStorageOptions];
	[self rebuildSections];
}

- (void)loadStorageOptions {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] optionValue:@"storage_max_time_from_last_access" completion:^(id val){
		if ([val isKindOfClass:[NSNumber class]]) {
			int64_t sec = [val longLongValue];
			NSInteger idx = 3; // Forever
			if (sec == 259200) idx = 0;       // 3 days
			else if (sec == 604800) idx = 1;  // 1 week
			else if (sec == 2592000) idx = 2; // 1 month
			dispatch_async(dispatch_get_main_queue(), ^{
				weakSelf.keepMediaIndex = idx;
				[weakSelf rebuildSections];
			});
		}
	}];
	[[TGClient shared] optionValue:@"storage_max_files_size" completion:^(id val){
		if ([val isKindOfClass:[NSNumber class]]) {
			int64_t bytes = [val longLongValue];
			NSInteger idx = 3; // No limit
			if (bytes == 5LL * 1024 * 1024 * 1024) idx = 0;       // 5 GB
			else if (bytes == 20LL * 1024 * 1024 * 1024) idx = 1; // 20 GB
			else if (bytes == 50LL * 1024 * 1024 * 1024) idx = 2; // 50 GB
			dispatch_async(dispatch_get_main_queue(), ^{
				weakSelf.maxCacheIndex = idx;
				[weakSelf rebuildSections];
			});
		}
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)refresh {
	__weak typeof(self) weakSelf = self;
	// The fast count is the one TDLib keeps in memory: it answers at once,
	// so the ring has a figure in it while the per-type walk - which reads
	// the database - is still going. On this hardware that walk is seconds.
	[[TGClient shared] storageStatsWithCompletion:^(long long bytes, NSInteger files){
		weakSelf.total = bytes;
		weakSelf.fileCount = files;
		weakSelf.loaded = YES;
		weakSelf.totalText = TGBytes(bytes);
		[weakSelf rebuildSections];
	}];
	[[TGClient shared] storageBreakdownWithCompletion:^(NSArray *categories,
														long long total){
		weakSelf.categories = categories;
		weakSelf.total = total;
		weakSelf.totalText = TGBytes(total);
		weakSelf.loaded = YES;
		[weakSelf rebuildSections];
	}];
}

#pragma mark - sections

/// The one place the page's rows are built. Storage changes from three
/// callbacks and every tap, so a row never reads a half-updated selection.
- (void)rebuildSections {
	NSMutableArray *categoryRows = [NSMutableArray array];
	if (!self.loaded){
		[categoryRows addObject:TGRow(TGKindPlain, TGLocalized(@"Loading..."))];
	} else if (!self.categories.count){
		[categoryRows addObject:TGRow(TGKindPlain, TGLocalized(@"No media files yet"))];
	} else {
		NSArray *rows = TGSettingsStorageCategoryRowModels(self.categories,
				self.total, self.selectedKinds);
		for (NSUInteger i = 0; i < rows.count; i++){
			NSMutableDictionary *row = [rows[i] mutableCopy];
			row[TGRowColour] = TGSliceColour(i);
			NSArray *kinds = row[@"storageKinds"] ?: @[];
			__weak typeof(self) weakSelf = self;
			row[TGRowTap] = ^{ [weakSelf toggleKinds:kinds]; };
			[categoryRows addObject:row];
		}
	}

	NSString *keepFooter = TGLocalized(@"Photos, videos and other files from cloud chats that have not been accessed during this period will be removed from this device to save disk space.");
	NSString *cacheFooter = TGLocalized(@"If your cache size exceeds this limit, the oldest unused media will be removed from the device.");
	static NSArray *keepLabels = nil;
	if (!keepLabels)
		keepLabels = @[
			TGLocalizedPluralValue(@"%@ day", @"%@ days", @"3", 3),
			TGLocalizedPluralValue(@"%@ week", @"%@ weeks", @"1", 1),
			TGLocalizedPluralValue(@"%@ month", @"%@ months", @"1", 1),
			TGLocalized(@"Forever"),
		];
	static NSArray *maxLabels = nil;
	if (!maxLabels)
		maxLabels = @[@"5 GB", @"20 GB", @"50 GB", TGLocalized(@"No Limit")];
	__weak typeof(self) weakSelf = self;

	NSMutableDictionary *keepRow = [TGOpenRow(TGLocalized(@"Keep Media"),
			keepLabels[self.keepMediaIndex], ^{ [weakSelf chooseKeepMedia]; })
			mutableCopy];
	NSMutableDictionary *cacheRow = [TGOpenRow(TGLocalized(@"Maximum Cache Size"),
			maxLabels[self.maxCacheIndex], ^{ [weakSelf chooseMaxCache]; })
			mutableCopy];

	NSMutableArray *sections = [NSMutableArray array];
	[sections addObject:TGSection(nil, nil, categoryRows)];
	if ([self hasClearSection]){
		NSMutableDictionary *clear;
		if (self.working){
			clear = [TGRow(TGKindPlain, TGLocalized(@"Clearing the Cache"))
					mutableCopy];
			clear[TGRowCentred] = @YES;
			clear[TGRowTitleColour] = [[TGTheme shared] secondaryTextColour];
		} else {
			NSString *title = [NSString stringWithFormat:@"%@  %@",
					TGLocalized(@"Clear Selected"), self.selectedText ?: @""];
			clear = [TGCentredDestructiveRow(title, ^{ [weakSelf confirmClear]; })
					mutableCopy];
		}
		[sections addObject:TGSection(nil, nil, @[clear])];
	}
	[sections addObject:TGSection(TGLocalized(@"KEEP MEDIA"), keepFooter,
			@[keepRow])];
	[sections addObject:TGSection(TGLocalized(@"MAXIMUM CACHE SIZE"),
			cacheFooter, @[cacheRow])];

	self.sections = sections;
	[self reloadRows];
}

/// The bottom button's label is written when the selection changes, not while
/// a cell is being laid out.
- (void)updateSelectedText {
	BOOL selected = self.selectedKinds.count > 0;
	self.selectedText = selected ? TGBytes(self.selectedBytes) : self.totalText;
}

/// Telegram's own chart palette, in the order their storage page uses it.
static UIColor *TGSliceColour(NSUInteger index) {
	NSArray *palette = [[TGTheme shared] chartPalette];
	return palette[index % palette.count];
}

#pragma mark - the ring

- (UIView *)ringHeader {
	TGTheme *theme = [TGTheme shared];
	CGFloat width = self.tableView.bounds.size.width ?: 320;
	UIView *header = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, width, kRingSide + kRingHeaderRoom)];
	header.backgroundColor = [UIColor clearColor];

	CGRect box = CGRectMake(TGCenteredOrigin(width, kRingSide), TGMetricPad,
			kRingSide, kRingSide);
	CGPoint centre = CGPointMake(CGRectGetMidX(box), CGRectGetMidY(box));
	CGFloat radius = TGHalf(kRingSide - kRingWidth);

	if (self.total > 0){
		CGFloat start = -M_PI_2;   // twelve o'clock, the way theirs starts
		for (NSUInteger i = 0; i < self.categories.count; i++){
			double share = [self.categories[i][@"bytes"] longLongValue] /
					(double)self.total;
			if (share <= 0)
				continue;
			CGFloat end = start + (CGFloat)(share * 2 * M_PI);

			CAShapeLayer *slice = [CAShapeLayer layer];
			slice.path = [UIBezierPath bezierPathWithArcCenter:centre radius:radius
					startAngle:start endAngle:end clockwise:YES].CGPath;
			slice.fillColor = [UIColor clearColor].CGColor;
			slice.strokeColor = TGSliceColour(i).CGColor;
			slice.lineWidth = kRingWidth;
			[header.layer addSublayer:slice];
			start = end;
		}
	} else {
		CAShapeLayer *empty = [CAShapeLayer layer];
		empty.path = [UIBezierPath bezierPathWithArcCenter:centre radius:radius
				startAngle:0 endAngle:2 * M_PI clockwise:YES].CGPath;
		empty.fillColor = [UIColor clearColor].CGColor;
		empty.strokeColor = [theme separatorColour].CGColor;
		empty.lineWidth = kRingWidth;
		[header.layer addSublayer:empty];
	}

	UILabel *totalLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(box.origin.x, centre.y - TGHalf(kRingTotalLine), kRingSide,
					kRingTotalLine)];
	totalLabel.text = self.loaded ? self.totalText : @"...";
	totalLabel.font = TGFontTitle();
	totalLabel.textAlignment = NSTextAlignmentCenter;
	totalLabel.textColor = [theme primaryTextColour];
	totalLabel.backgroundColor = [UIColor clearColor];
	totalLabel.adjustsFontSizeToFitWidth = YES;
	totalLabel.shadowColor = [theme etchedTextShadowColour];
	totalLabel.shadowOffset = TGMetricShadowOffsetEtched;
	[header addSubview:totalLabel];

	UILabel *caption = [[UILabel alloc] initWithFrame:
			CGRectMake(TGMetricPadMedium, kRingSide + TGMetricPadLarge,
					width - TGDoubled(TGMetricPadMedium), TGMetricLineRow)];
	caption.text = self.loaded ? @"Telegram Cache" : @"Loading...";
	caption.font = TGFontCaption();
	caption.textAlignment = NSTextAlignmentCenter;
	caption.textColor = [theme secondaryTextColour];
	caption.backgroundColor = [UIColor clearColor];
	caption.shadowColor = [theme etchedTextShadowColour];
	caption.shadowOffset = TGMetricShadowOffsetEtched;
	[header addSubview:caption];

	return header;
}

/// A filled disc in the slice's colour, standing in for their tick.
- (UIImage *)dotOfColour:(UIColor *)colour {
	CGFloat side = 22;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
	[colour setFill];
	[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, side, side)] fill];
	UIImage *dot = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return dot;
}

#pragma mark - table

/// The ring is a section header, not a row: the page's first group is the
/// category list, and the ring belongs above it.
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	(void)tableView;
	return section == 0 ? [self ringHeader] : nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	(void)tableView;
	if (section == 0)
		return kRingSide + TGMetricPadLarge + TGMetricLineRow;
	return TGMetricPadWide + TGMetricLineCaption;
}

/// The shared cell draws the row; the storage page adds the chart disc its
/// category rows need. The disc is a bitmap from the screen's own palette, so
/// the cell family never has to know about the storage chart.
- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)path {
	UITableViewCell *cell = [super tableView:tableView
					   cellForRowAtIndexPath:path];
	NSDictionary *row = [self rowAtPath:path];
	if ([cell isKindOfClass:TGRowCell.class])
		[(TGRowCell *)cell applyAppendedOptions:row];
	UIColor *colour = row[TGRowColour];
	if ([cell isKindOfClass:TGRowCell.class] &&
			[colour isKindOfClass:UIColor.class] &&
			![row[TGRowIcon] length])
		cell.imageView.image = [self dotOfColour:colour];
	return cell;
}

- (NSDictionary *)rowAtPath:(NSIndexPath *)path {
	if (path.section < 0 || path.section >= (NSInteger)self.sections.count)
		return nil;
	NSArray *rows = self.sections[(NSUInteger)path.section][@"rows"];
	if (path.row < 0 || path.row >= (NSInteger)rows.count)
		return nil;
	return rows[(NSUInteger)path.row];
}

#pragma mark - actions

- (void)toggleKinds:(NSArray *)kinds {
	if (self.working || !self.loaded || !kinds.count)
		return;
	TGSettingsToggleKinds(self.selectedKinds, kinds);
	[self updateSelectedBytes];
}

- (void)confirmClear {
	if (self.working || !self.loaded)
		return;
	NSArray *kinds = self.selectedKinds.allObjects;
	if (!kinds.count)
		return;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:TGLocalized(@"Are you sure you want to clear cache?")
						title:TGLocalized(@"Clear Selected")
					   action:TGLocalized(@"Clear")
				  destructive:YES
					   inView:self.view
					onConfirm:^{ [weakSelf clearKinds:kinds]; }];
}

- (void)chooseKeepMedia {
	static int64_t seconds[4] = {259200, 604800, 2592000, 0};
	NSArray *labels = @[
		TGLocalizedPluralValue(@"%@ day", @"%@ days", @"3", 3),
		TGLocalizedPluralValue(@"%@ week", @"%@ weeks", @"1", 1),
		TGLocalizedPluralValue(@"%@ month", @"%@ months", @"1", 1),
		TGLocalized(@"Forever"),
	];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:labels
						title:TGLocalized(@"Keep Media")
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		if (index < 0 || index > 3)
			return;
		weakSelf.keepMediaIndex = index;
		[[TGClient shared] setOption:@"storage_max_time_from_last_access"
						integerValue:seconds[index]];
		[[NSUserDefaults standardUserDefaults] setInteger:index
				forKey:@"TGStorageKeepMedia"];
		[weakSelf rebuildSections];
	}];
}

- (void)chooseMaxCache {
	static int64_t bytes[4] = {5LL * 1024 * 1024 * 1024,
			20LL * 1024 * 1024 * 1024, 50LL * 1024 * 1024 * 1024, 0};
	NSArray *labels = @[@"5 GB", @"20 GB", @"50 GB", TGLocalized(@"No Limit")];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:labels
						title:TGLocalized(@"Maximum Cache Size")
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		if (index < 0 || index > 3)
			return;
		weakSelf.maxCacheIndex = index;
		[[TGClient shared] setOption:@"storage_max_files_size"
						integerValue:bytes[index]];
		[[NSUserDefaults standardUserDefaults] setInteger:index
				forKey:@"TGStorageMaxCache"];
		[weakSelf rebuildSections];
	}];
}

- (void)updateSelectedBytes {
	self.selectedBytes = TGSettingsSelectedBytes(self.categories, self.selectedKinds);
	[self updateSelectedText];
	[self rebuildSections];
}

- (void)clearKinds:(NSArray *)kinds {
	self.working = YES;
	[self rebuildSections];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] clearCacheOfTypes:kinds completion:^(long long freed){
		weakSelf.working = NO;
		[weakSelf.selectedKinds removeAllObjects];
		weakSelf.selectedBytes = 0;
		[weakSelf updateSelectedText];
		[weakSelf refresh];
		(void)freed;
		[TGAlertSheet showMessage:TGLocalized(@"Cache cleared.")
							title:TGLocalized(@"Storage Usage") inView:weakSelf.view];
	}];
}

@end

// vim:ft=objc
