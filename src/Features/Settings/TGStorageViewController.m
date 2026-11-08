#import "TGStorageViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGSettingsFormatting.h"

// Their storage page opens with a ring: the total in the middle, one arc per
// kind of file, the same colours in the list underneath. A column of numbers
// says the same thing and none of it at a glance.
static const CGFloat kRingSide  = TGMetricStorageRingSide;
static const CGFloat kRingWidth = TGMetricStorageRingWidth;
/// Room under the ring for the total it holds, and the box that total is set
/// in - a line and a half, because it is two lines when the figure is long.
static const CGFloat kRingHeaderRoom = 54.0f;
static const CGFloat kRingTotalLine  = TGMetricVoicePillWidth;

@interface TGStorageViewController ()
@property (nonatomic, strong) NSArray *categories;   // name / bytes / kinds
@property (nonatomic, strong) NSArray *categoryRows;    // preformatted title / size
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

- (NSInteger)keepMediaSectionIndex {
	return [self hasClearSection] ? 2 : 1;
}

- (NSInteger)maxCacheSectionIndex {
	return [self hasClearSection] ? 3 : 2;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Storage Usage";
	self.categories = @[];
	self.selectedKinds = [NSMutableSet set];
	[self applyTheme];
	[self refresh];
	[self loadStorageOptions];
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
				[weakSelf.tableView reloadData];
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
				[weakSelf.tableView reloadData];
			});
		}
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)applyTheme {
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
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
		[weakSelf.tableView reloadData];
	}];
	[[TGClient shared] storageBreakdownWithCompletion:^(NSArray *categories,
														long long total){
		weakSelf.categories = categories;
		weakSelf.total = total;
		weakSelf.totalText = TGBytes(total);
		[weakSelf rebuildCategoryRows];
		weakSelf.loaded = YES;
		[weakSelf.tableView reloadData];
	}];
}

/// Percentages and sizes are formatted here, once per refresh, rather than in
/// cellForRow: the no-NSNumber rule applies to cell layout too, and a
/// formatter per row is a compile per scroll.
- (void)rebuildCategoryRows {
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:self.categories.count];
	for (NSDictionary *category in self.categories){
		long long bytes = [category[@"bytes"] longLongValue];
		double share = self.total > 0 ? (bytes / (double)self.total) * 100 : 0;
		[rows addObject:@{
			@"name" : category[@"name"] ?: @"",
			@"kinds" : category[@"kinds"] ?: @[],
			@"title" : [NSString stringWithFormat:@"%@  %.1f%%",
					category[@"name"] ?: @"", share],
			@"size" : TGBytes(bytes),
		}];
	}
	self.categoryRows = rows;
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [self hasClearSection] ? 4 : 3;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	return section == 0 ? [self ringHeader] : nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return section == 0 ? kRingSide + 54 : 24;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == [self keepMediaSectionIndex]) {
		return @"KEEP MEDIA";
	}
	if (section == [self maxCacheSectionIndex]) {
		return @"MAXIMUM CACHE SIZE";
	}
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == [self keepMediaSectionIndex]) {
		return @"Photos, videos and other files from cloud chats that have not been accessed during this period will be removed from this device to save disk space.";
	}
	if (section == [self maxCacheSectionIndex]) {
		return @"If your cache size exceeds this limit, the oldest unused media will be removed from the device.";
	}
	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return self.loaded ? MAX((NSUInteger)1, self.categoryRows.count) : 1;
	return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)path
{
	TGTheme *theme = [TGTheme shared];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"row"];
	[theme styleCell:cell];
	cell.imageView.image = nil;
	cell.textLabel.font = TGFontRow();
	cell.textLabel.textColor = [theme primaryTextColour];
	cell.textLabel.textAlignment = NSTextAlignmentLeft;
	cell.detailTextLabel.font = TGFontBody();
	cell.detailTextLabel.textColor = [theme cellDetailColour];
	cell.selectionStyle = UITableViewCellSelectionStyleDefault;
	cell.accessoryType = UITableViewCellAccessoryNone;

	if ([self hasClearSection] && path.section == 1){
		cell.textLabel.text = self.working
				? @"Clearing the Cache"
				: [NSString stringWithFormat:@"%@  %@",
						@"Clear Selected", self.selectedText ?: @""];
		cell.textLabel.textAlignment = NSTextAlignmentCenter;
		cell.textLabel.textColor = self.working
				? [theme secondaryTextColour] : [theme destructiveColour];
		cell.detailTextLabel.text = @"";
		return cell;
	}

	if (path.section == [self keepMediaSectionIndex]) {
		cell.textLabel.text = @"Keep Media";
		static NSArray *keepLabels = nil;
		if (!keepLabels) keepLabels = @[@"3 days", @"1 week", @"1 month", @"Forever"];
		cell.detailTextLabel.text = keepLabels[self.keepMediaIndex];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}

	if (path.section == [self maxCacheSectionIndex]) {
		cell.textLabel.text = @"Maximum Cache Size";
		static NSArray *maxLabels = nil;
		if (!maxLabels) maxLabels = @[@"5 GB", @"20 GB", @"50 GB", @"No Limit"];
		cell.detailTextLabel.text = maxLabels[self.maxCacheIndex];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}

	if (!self.loaded){
		cell.textLabel.text = @"Loading...";
		cell.textLabel.textColor = [theme secondaryTextColour];
		cell.detailTextLabel.text = @"";
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}

	if (!self.categoryRows.count){
		cell.textLabel.text = @"No media files yet";
		cell.textLabel.textColor = [theme secondaryTextColour];
		cell.detailTextLabel.text = @"";
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}

	NSDictionary *category = self.categoryRows[path.row];
	cell.textLabel.text = category[@"title"];
	cell.detailTextLabel.text = category[@"size"];
	cell.imageView.image = [self dotOfColour:TGSliceColour(path.row)];
	NSArray *kinds = category[@"kinds"];
	BOOL allSelected = kinds.count > 0;
	for (NSString *kind in kinds)
		if (![self.selectedKinds containsObject:kind]){
			allSelected = NO;
			break;
		}
	cell.accessoryType = allSelected
			? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
	[tableView deselectRowAtIndexPath:path animated:YES];
	if (self.working || !self.loaded)
		return;

	if ([self hasClearSection] && path.section == 1){
		__weak typeof(self) weakSelf = self;
		NSArray *kinds = self.selectedKinds.allObjects;
		if (!kinds.count)
			return;
		[TGAlertSheet showConfirm:@"Are you sure you want to clear cache?"
							title:@"Clear Selected"
						   action:@"Clear"
					  destructive:YES
						   inView:self.view
						onConfirm:^{ [weakSelf clearKinds:kinds]; }];
		return;
	}

	if (path.section == [self keepMediaSectionIndex]) {
		static NSArray *keepLabels = nil;
		if (!keepLabels) keepLabels = @[@"3 days", @"1 week", @"1 month", @"Forever"];
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:keepLabels
							title:@"Keep Media"
				 destructiveIndex:-1
						   inView:self.view
						 onChoice:^(NSInteger index){
			weakSelf.keepMediaIndex = index;
			static const int64_t seconds[4] = {259200, 604800, 2592000, 0};
			[[TGClient shared] setOption:@"storage_max_time_from_last_access" integerValue:seconds[index]];
			[[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"TGStorageKeepMedia"];
			[weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:[weakSelf keepMediaSectionIndex]]
							  withRowAnimation:UITableViewRowAnimationNone];
		}];
		return;
	}

	if (path.section == [self maxCacheSectionIndex]) {
		static NSArray *maxLabels = nil;
		if (!maxLabels) maxLabels = @[@"5 GB", @"20 GB", @"50 GB", @"No Limit"];
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:maxLabels
							title:@"Maximum Cache Size"
				 destructiveIndex:-1
						   inView:self.view
						 onChoice:^(NSInteger index){
			weakSelf.maxCacheIndex = index;
			static const int64_t bytes[4] = {5LL * 1024 * 1024 * 1024, 20LL * 1024 * 1024 * 1024, 50LL * 1024 * 1024 * 1024, 0};
			[[TGClient shared] setOption:@"storage_max_files_size" integerValue:bytes[index]];
			[[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"TGStorageMaxCache"];
			[weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:[weakSelf maxCacheSectionIndex]]
							  withRowAnimation:UITableViewRowAnimationNone];
		}];
		return;
	}

	if (!self.categories.count)
		return;
	NSDictionary *category = self.categories[path.row];
	NSArray *kinds = category[@"kinds"];
	if (!kinds.count)
		return;               // "Other" is whatever the walk could not name

	// A tap selects the panel; nothing is deleted until the bottom button.
	TGSettingsToggleKinds(self.selectedKinds, kinds);
	[self updateSelectedBytes];
	[self.tableView reloadData];
}

- (void)updateSelectedBytes {
	self.selectedBytes = TGSettingsSelectedBytes(self.categories, self.selectedKinds);
	[self updateSelectedText];
}

- (void)clearKinds:(NSArray *)kinds {
	self.working = YES;
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] clearCacheOfTypes:kinds completion:^(long long freed){
		weakSelf.working = NO;
		[weakSelf.selectedKinds removeAllObjects];
		weakSelf.selectedBytes = 0;
		[weakSelf updateSelectedText];
		[weakSelf refresh];
		(void)freed;
		[TGAlertSheet showMessage:@"Cache cleared."
							title:@"Storage Usage" inView:weakSelf.view];
	}];
}

@end

// vim:ft=objc
