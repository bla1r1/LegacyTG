//
// TGProfileAppearanceViewController.m — the account's name colour and profile
// colour, drawn from the updateAccentColors palette as a grid of swatches
// rather than a word list. Two tabs, one live preview of the signed-in user,
// and an Apply step so a colour is never written before the user confirms it.
//
#import "TGProfileAppearanceViewController.h"
#import "TGProfileStore.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGIcons.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGRows.h"
#import "TGRowCell.h"
#import "TGRowGeometry.h"
#import "TGBarItem.h"
#import "TGSegmentedControl.h"
#import "TGLabel.h"

/// Telegram's swatch is 44 pt on a phone, per the parity spec; the gap and
/// gutter come from the spacing scale.
static const CGFloat kSwatchSide = 44.0f;
static const CGFloat kSwatchGap = TGMetricPadSmall;
static const CGFloat kSwatchInset = TGMetricPadMedium;
static const NSInteger kSwatchColumns = 5;

/// The width a row's content has. Before iOS 7 a grouped table insets its
/// cells, so laying five swatches out across the table's own width pushed the
/// fifth through the group's right border.
static CGFloat TGAppearanceContentWidth(UITableView *tableView) {
	return TGRowContentWidth(tableView.bounds.size.width,
			tableView.style == UITableViewStyleGrouped,
			NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_6_1);
}
static const CGFloat kSwatchRow = kSwatchSide + TGMetricPadMedium;

static const NSInteger kTabProfile = 0;
static const NSInteger kTabName = 1;

/// One swatch: the account colour filled into a rounded tile, with a selection
/// ring and a baked checkmark over it. The ring is the theme's accent, not the
/// swatch colour, so a selection is visible on any palette entry.
static UIImage *TGAppearanceSwatch(UIColor *colour, BOOL selected) {
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(kSwatchSide, kSwatchSide), NO, 0);
	CGRect rect = CGRectMake(0, 0, kSwatchSide, kSwatchSide);
	UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect
													cornerRadius:TGMetricCornerControl];
	[colour setFill];
	[path fill];
	if (selected) {
		UIBezierPath *ring = [UIBezierPath bezierPathWithRoundedRect:
				CGRectInset(rect, TGMetricBorderWidth, TGMetricBorderWidth)
				cornerRadius:TGMetricCornerControl];
		ring.lineWidth = TGMetricBorderThick;
		[[[TGTheme shared] accentColour] setStroke];
		[ring stroke];
		UIImage *tick = [TGIcons ticksColour:[[TGTheme shared] onAccentColour] read:NO];
		[tick drawInRect:CGRectMake(TGCenteredOrigin(kSwatchSide, TGMetricTicksWidth),
				TGCenteredOrigin(kSwatchSide, TGMetricTicksHeight),
				TGMetricTicksWidth, TGMetricTicksHeight)];
	}
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

/// The avatar with a 2 pt ring in the profile colour, baked so the preview row
/// never needs a masked layer over a scrolling table.
static UIImage *TGAppearanceAvatar(UIImage *avatar, UIColor *ring) {
	UIGraphicsBeginImageContextWithOptions(avatar.size, NO, 0);
	CGRect rect = CGRectMake(0, 0, avatar.size.width, avatar.size.height);
	[avatar drawInRect:rect];
	UIBezierPath *ringPath = [UIBezierPath bezierPathWithOvalInRect:
			CGRectInset(rect, TGMetricBorderWidth, TGMetricBorderWidth)];
	ringPath.lineWidth = TGMetricBorderThick;
	[ring setStroke];
	[ringPath stroke];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

#pragma mark - the swatch grid

/// The swatch strip and the live preview are drawn into the shared cell's
/// content view. The screen owns the buttons, the cell family stays the one
/// renderer; tags below its own range keep reuse from doubling the strip.
static const NSInteger kSwatchButtonTag = 8100;

@interface TGAppearanceSwatchButton : UIButton
@property (nonatomic, copy) void (^onTap)(void);
@end

@implementation TGAppearanceSwatchButton
- (void)tapped {
	void (^tap)(void) = self.onTap;
	if (tap)
		tap();
}
@end

#pragma mark - the screen

@interface TGProfileAppearanceViewController ()
@property (nonatomic, assign) NSInteger tab;
@property (nonatomic, assign) NSInteger pendingAccentId;
@property (nonatomic, assign) NSInteger pendingProfileId;
@property (nonatomic, assign) int64_t backgroundEmojiId;
@property (nonatomic, assign) int64_t profileBackgroundEmojiId;
@property (nonatomic, assign) BOOL accentChanged;
@property (nonatomic, assign) BOOL profileChanged;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) NSArray *accentIds;
@property (nonatomic, strong) NSArray *profileIds;
@property (nonatomic, strong) NSCache *swatchCache;
@end

@implementation TGProfileAppearanceViewController

- (id)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (instancetype)initWithProfileTab:(BOOL)profileTab {
	self = [self init];
	if (self)
		_tab = profileTab ? kTabProfile : kTabName;
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.pageKind = TGPageKindForm;
	self.title = TGLocalized(@"Your Color");
	self.swatchCache = [[NSCache alloc] init];

	self.navigationItem.rightBarButtonItem = [TGBarItem itemWithTitle:@"Apply" primary:YES
			target:self action:@selector(applyTapped)];

	UISegmentedControl *tabs = TGContentSegments(@[TGLocalized(@"Profile"), TGLocalized(@"Name")]);
	tabs.selectedSegmentIndex = self.tab;
	[tabs addTarget:self action:@selector(tabChanged:)
   forControlEvents:UIControlEventValueChanged];
	UIView *header = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, self.tableView.bounds.size.width,
					   TGMetricSegmentedHeight + TGDoubled(TGMetricPadMedium))];
	header.backgroundColor = [UIColor clearColor];
	tabs.frame = CGRectMake(TGMetricGutter, TGMetricPadMedium,
			header.bounds.size.width - TGDoubled(TGMetricGutter),
			TGMetricSegmentedHeight);
	[header addSubview:tabs];
	self.tableView.tableHeaderView = header;

	[self loadColours];
	[self rebuildSections];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadColours)
			name:TGAccentColorsChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme)
			name:TGThemeChangedNotification object:nil];
}

- (void)applyTheme {
	[super applyTheme];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)tabChanged:(UISegmentedControl *)tabs {
	self.tab = tabs.selectedSegmentIndex;
	[self rebuildSections];
}

/// The ids come from updateAccentColors (cached on the client), the two chosen
/// ids and the two background-emoji ids from getMe. The emoji ids are what a
/// colour write has to hand back so picking a colour never erases the pattern.
- (void)loadColours {
	self.accentIds = [[TGProfileStore shared] availableAccentColorIds];
	self.profileIds = [[TGProfileStore shared] availableProfileAccentColorIds];

	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] myAccentColoursWithCompletion:
			^(NSInteger accent, NSInteger profile, int64_t emoji, int64_t profileEmoji){
		TGProfileAppearanceViewController *me = weakSelf;
		if (!me || me.loaded)
			return;
		me.loaded = YES;
		me.pendingAccentId = accent;
		me.pendingProfileId = profile;
		me.backgroundEmojiId = emoji;
		me.profileBackgroundEmojiId = profileEmoji;
		[me rebuildSections];
	}];
}

/// The one place the page's rows are built. A tab switch, a palette update and
/// a chosen swatch all replace the list here and reload once.
- (void)rebuildSections {
	// D21: the preview is the profile header the colour lands on (official
	// PeerNameColorScreen previews the profile), not a one-line person row
	// where a short name such as "." was lost.
	NSDictionary *me = [TGProfileStore shared].me;
	NSString *name = [me[@"first_name"] length] ? me[@"first_name"]
			: TGLocalized(@"Name");
	if ([me[@"last_name"] length])
		name = [NSString stringWithFormat:@"%@ %@", name, me[@"last_name"]];
	UIImage *avatar = [TGIcons avatarWithInitials:[TGIcons initialsForTitle:name]
											 size:TGMetricProfileAvatar
										 colourId:[me[@"id"] longLongValue]];
	UIColor *profileColour = [[TGProfileStore shared] accentColourForId:self.pendingProfileId
														  profile:YES];
	NSMutableDictionary *preview = TGProfileHeaderRow(me[@"id"], name,
			TGLocalized(@"online"),
			TGAppearanceAvatar(avatar, profileColour ?: [[TGTheme shared] separatorColour]),
			nil, nil);
	UIColor *nameColour = [[TGProfileStore shared] accentColourForId:self.pendingAccentId
															 profile:NO];
	if (nameColour)
		preview[TGRowTitleColour] = nameColour;

	NSArray *ids = self.activeIds;
	NSInteger count = (NSInteger)ids.count;
	NSInteger rowCount = (count + kSwatchColumns - 1) / kSwatchColumns;
	NSMutableArray *swatchRows = [NSMutableArray array];
	for (NSInteger row = 0; row < rowCount; row++){
		NSInteger start = row * kSwatchColumns;
		NSInteger end = MIN(start + kSwatchColumns, count);
		NSMutableArray *images = [NSMutableArray array];
		NSInteger active = [self activeId];
		for (NSInteger i = start; i < end; i++){
			NSInteger colourId = [ids[(NSUInteger)i] integerValue];
			[images addObject:[self swatchImageForId:colourId
					selected:(colourId == active)]];
		}
		NSMutableDictionary *row = [TGRow(TGKindSwatchStrip, @"") mutableCopy];
		row[TGRowSwatches] = images;
		NSArray *colourIds = [ids subarrayWithRange:
				NSMakeRange((NSUInteger)start, (NSUInteger)(end - start))];
		__weak typeof(self) weakSelf = self;
		row[TGRowSwatchTap] = ^(NSInteger index){
			if (index < 0 || index >= (NSInteger)colourIds.count)
				return;
			[weakSelf chooseColourId:[colourIds[(NSUInteger)index] integerValue]];
		};
		[swatchRows addObject:row];
	}

	NSMutableArray *sections = [NSMutableArray array];
	[sections addObject:TGSection(nil, nil, @[preview])];
	// D21: "Profile" and "Name" are the tab titles, not section headers.
	// Official puts the colours under the preview with its sentence as the
	// footer (ProfileColorSetup, NameColor).
	[sections addObject:TGSection(nil, self.tab == kTabProfile
			? @"Choose a color for your profile"
			: @"Your name and replies to your messages will be shown in the selected color.",
			swatchRows)];
	if (self.tab == kTabProfile){
		__weak typeof(self) weakSelf = self;
		[sections addObject:TGSection(nil, nil, @[
			TGCentredDestructiveRow(TGLocalized(@"Reset Profile Color"), ^{
				weakSelf.pendingProfileId = -1;
				weakSelf.profileChanged = YES;
				[weakSelf rebuildSections];
			}),
		])];
	}
	self.sections = sections;
	[self reloadRows];
}

- (NSInteger)activeId {
	return self.tab == kTabProfile ? self.pendingProfileId : self.pendingAccentId;
}

- (NSArray *)activeIds {
	return self.tab == kTabProfile ? self.profileIds : self.accentIds;
}

- (UIColor *)colourForActiveId:(NSInteger)colourId {
	UIColor *colour = [[TGProfileStore shared] accentColourForId:colourId
												  profile:(self.tab == kTabProfile)];
	return colour ?: [[TGTheme shared] fileTileColour];
}

/// Baked once per id per selection state; a palette is at most a few dozen
/// entries, so the cache stays tiny against the 16 MB ceiling.
- (UIImage *)swatchImageForId:(NSInteger)colourId selected:(BOOL)selected {
	NSString *key = [NSString stringWithFormat:@"%ld-%d-%ld", (long)colourId,
			selected, (long)self.tab];
	UIImage *cached = [self.swatchCache objectForKey:key];
	if (cached)
		return cached;
	UIImage *image = TGAppearanceSwatch([self colourForActiveId:colourId], selected);
	[self.swatchCache setObject:image forKey:key];
	return image;
}

#pragma mark - table

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path {
	NSDictionary *row = [self rowAtPath:path];
	if ([row[TGRowKind] isEqualToString:TGKindSwatchStrip])
		return kSwatchRow;
	return [super tableView:tableView heightForRowAtIndexPath:path];
}

- (NSDictionary *)rowAtPath:(NSIndexPath *)path {
	if (path.section < 0 || path.section >= (NSInteger)self.sections.count)
		return nil;
	NSArray *rows = self.sections[(NSUInteger)path.section][@"rows"];
	if (path.row < 0 || path.row >= (NSInteger)rows.count)
		return nil;
	return rows[(NSUInteger)path.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)path {
	NSDictionary *row = [self rowAtPath:path];
	NSString *kind = row[TGRowKind];
	if ([kind isEqualToString:TGKindSwatchStrip]){
		NSArray *rows = self.sections[(NSUInteger)path.section][@"rows"];
		TGRowCell *cell = [TGRowCell cellForTableView:tableView row:row
											 rowIndex:path.row totalRows:rows.count];
		[self decorateSwatchCell:cell row:row tableView:tableView];
		return cell;
	}
	UITableViewCell *cell = [super tableView:tableView
					   cellForRowAtIndexPath:path];
	if ([cell isKindOfClass:TGRowCell.class])
		[(TGRowCell *)cell applyAppendedOptions:row];
	return cell;
}

/// The swatch strip: five discs to a row, each a button that reports its slot
/// in `TGRowSwatchTap`. The images were baked once per id by the screen.
- (void)decorateSwatchCell:(TGRowCell *)cell
					   row:(NSDictionary *)row
				 tableView:(UITableView *)tableView {
	for (UIView *view in [cell.contentView.subviews copy])
		if (view.tag >= kSwatchButtonTag && view.tag < kSwatchButtonTag + kSwatchColumns)
			[view removeFromSuperview];

	NSArray *images = row[TGRowSwatches] ?: @[];
	void (^tap)(NSInteger) = row[TGRowSwatchTap];
	CGFloat width = TGAppearanceContentWidth(tableView);
	for (NSUInteger i = 0; i < images.count && i < (NSUInteger)kSwatchColumns; i++){
		TGAppearanceSwatchButton *tile = [TGAppearanceSwatchButton
				buttonWithType:UIButtonTypeCustom];
		tile.tag = kSwatchButtonTag + (NSInteger)i;
		tile.frame = TGRowStripCellFrame(i, width, kSwatchColumns, kSwatchInset,
				kSwatchGap, kSwatchRow, kSwatchSide);
		[tile setImage:images[i] forState:UIControlStateNormal];
		NSInteger index = (NSInteger)i;
		tile.onTap = ^{ if (tap) tap(index); };
		[tile addTarget:self action:@selector(swatchTapped:)
	   forControlEvents:UIControlEventTouchUpInside];
		[cell.contentView addSubview:tile];
	}
}

- (void)swatchTapped:(TGAppearanceSwatchButton *)button {
	[button tapped];
}

#pragma mark - choosing and applying

- (void)chooseColourId:(NSInteger)colourId {
	if (self.tab == kTabProfile){
		self.pendingProfileId = colourId;
		self.profileChanged = YES;
	} else {
		self.pendingAccentId = colourId;
		self.accentChanged = YES;
	}
	[self rebuildSections];
}

- (void)applyTapped {
	if (!self.loaded)
		return;

	__weak typeof(self) weakSelf = self;
	__block NSInteger pending = 0;
	__block BOOL failed = NO;
	if (self.profileChanged) pending++;
	if (self.accentChanged) pending++;

	if (!pending)
		return;

	void (^finish)(BOOL, NSString *) = ^(BOOL ok, NSString *error){
		TGProfileAppearanceViewController *me = weakSelf;
		if (!me)
			return;
		if (!ok){
			if (!failed){
				failed = YES;
				[TGAlertSheet showMessage:(error ?: @"An error occurred.")
									title:@"Your Color" inView:me.view];
			}
			return;
		}
		if (--pending == 0 && !failed)
			[me.navigationController popViewControllerAnimated:YES];
	};

	// The background emoji ids stay with the account; a colour write that
	// drops them would erase the pattern Telegram already stores. The client
	// reads them again at write time rather than trusting this screen's copy.
	if (self.profileChanged)
		[[TGProfileStore shared]
				setAccountProfileAccentColorPreservingBackgroundEmoji:self.pendingProfileId
														   completion:finish];
	if (self.accentChanged)
		[[TGProfileStore shared] setAccountAccentColorPreservingBackgroundEmoji:self.pendingAccentId
															   completion:finish];
}

@end
