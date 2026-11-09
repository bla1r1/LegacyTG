//
// TGProfileAppearanceViewController.m — the account's name colour and profile
// colour, drawn from the updateAccentColors palette as a grid of swatches
// rather than a word list. Two tabs, one live preview of the signed-in user,
// and an Apply step so a colour is never written before the user confirms it.
//
#import "TGProfileAppearanceViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGIcons.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGRows.h"
#import "TGRowCell.h"

/// Telegram's swatch is 44 pt on a phone, per the parity spec; the gap and
/// gutter come from the spacing scale.
static const CGFloat kSwatchSide = 44.0f;
static const CGFloat kSwatchGap = TGMetricPadSmall;
static const CGFloat kSwatchInset = TGMetricPadMedium;
static const NSInteger kSwatchColumns = 5;
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
static const NSInteger kPreviewAvatarTag = 8200;
static const NSInteger kPreviewNameTag = 8201;

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
	self.title = TGLocalized(@"Your Color");
	self.swatchCache = [[NSCache alloc] init];

	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:TGLocalized(@"Apply") style:UIBarButtonItemStyleDone
				   target:self action:@selector(applyTapped)];

	UISegmentedControl *tabs = [[UISegmentedControl alloc]
			initWithItems:@[TGLocalized(@"Profile"), TGLocalized(@"Name")]];
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
	self.accentIds = [[TGClient shared] availableAccentColorIds];
	self.profileIds = [[TGClient shared] availableProfileAccentColorIds];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] myAccentColoursWithCompletion:
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
	NSMutableDictionary *preview = [TGRow(TGKindAppearancePreview, @"")
			mutableCopy];
	NSDictionary *me = [TGClient shared].me;
	NSString *name = [me[@"first_name"] length] ? me[@"first_name"]
			: TGLocalized(@"Name");
	if ([me[@"last_name"] length])
		name = [NSString stringWithFormat:@"%@ %@", name, me[@"last_name"]];
	CGFloat side = TGMetricListAvatar;
	UIImage *avatar = [TGIcons avatarWithInitials:[TGIcons initialsForTitle:name]
											 size:side
										 colourId:[me[@"id"] longLongValue]];
	UIColor *profileColour = [[TGClient shared] accentColourForId:self.pendingProfileId
														  profile:YES];
	preview[TGRowPreviewImage] = TGAppearanceAvatar(avatar,
			profileColour ?: [[TGTheme shared] separatorColour]);
	preview[TGRowPreviewText] = name;
	preview[TGRowPreviewTextColour] = [[TGClient shared]
			accentColourForId:self.pendingAccentId profile:NO] ?:
			[[TGTheme shared] primaryTextColour];

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
	[sections addObject:TGSection(self.tab == kTabProfile
			? TGLocalized(@"Profile") : TGLocalized(@"Name"), nil, swatchRows)];
	if (self.tab == kTabProfile){
		__weak typeof(self) weakSelf = self;
		[sections addObject:TGSection(nil, nil, @[
			TGCentredDestructiveRow(TGLocalized(@"Reset"), ^{
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
	UIColor *colour = [[TGClient shared] accentColourForId:colourId
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
	if ([row[TGRowKind] isEqualToString:TGKindAppearancePreview])
		return TGMetricPersonRow;
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
	if ([kind isEqualToString:TGKindAppearancePreview] ||
			[kind isEqualToString:TGKindSwatchStrip]){
		NSArray *rows = self.sections[(NSUInteger)path.section][@"rows"];
		TGRowCell *cell = [TGRowCell cellForTableView:tableView row:row
											 rowIndex:path.row totalRows:rows.count];
		if ([kind isEqualToString:TGKindAppearancePreview])
			[self decoratePreviewCell:cell row:row tableView:tableView];
		else
			[self decorateSwatchCell:cell row:row tableView:tableView];
		return cell;
	}
	UITableViewCell *cell = [super tableView:tableView
					   cellForRowAtIndexPath:path];
	if ([cell isKindOfClass:TGRowCell.class])
		[(TGRowCell *)cell applyAppendedOptions:row];
	return cell;
}

/// The live preview: the picture with the pending profile ring and the name in
/// the pending accent colour. Both are baked by the screen, so the shared cell
/// only carries them.
- (void)decoratePreviewCell:(TGRowCell *)cell
						row:(NSDictionary *)row
				  tableView:(UITableView *)tableView {
	for (UIView *view in [cell.contentView.subviews copy])
		if (view.tag == kPreviewAvatarTag || view.tag == kPreviewNameTag)
			[view removeFromSuperview];

	CGFloat side = TGMetricListAvatar;
	UIImageView *avatarView = [[UIImageView alloc] initWithFrame:
			CGRectMake(TGMetricGutter,
					TGCenteredOrigin(TGMetricPersonRow, side), side, side)];
	avatarView.tag = kPreviewAvatarTag;
	avatarView.image = row[TGRowPreviewImage];
	[cell.contentView addSubview:avatarView];

	CGFloat width = tableView.bounds.size.width ?: TGMetricScreenWidth;
	UILabel *nameLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(TGMetricGutter + side + TGMetricPadMedium,
					TGCenteredOrigin(TGMetricPersonRow, TGMetricLineRow),
					width - TGMetricGutter - side - TGMetricPadMedium - TGMetricGutter,
					TGMetricLineRow)];
	nameLabel.tag = kPreviewNameTag;
	nameLabel.text = row[TGRowPreviewText];
	nameLabel.font = TGFontRowStrong();
	nameLabel.textColor = row[TGRowPreviewTextColour] ?:
			[[TGTheme shared] primaryTextColour];
	nameLabel.backgroundColor = [UIColor clearColor];
	[cell.contentView addSubview:nameLabel];
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
	CGFloat width = tableView.bounds.size.width ?: TGMetricScreenWidth;
	CGFloat usable = width - TGDoubled(kSwatchInset) -
			kSwatchGap * (kSwatchColumns - 1);
	CGFloat side = floorf(usable / kSwatchColumns);
	for (NSUInteger i = 0; i < images.count && i < (NSUInteger)kSwatchColumns; i++){
		TGAppearanceSwatchButton *tile = [TGAppearanceSwatchButton
				buttonWithType:UIButtonTypeCustom];
		tile.tag = kSwatchButtonTag + (NSInteger)i;
		tile.frame = CGRectMake(kSwatchInset + i * (side + kSwatchGap),
				TGCenteredOrigin(kSwatchRow, kSwatchSide), side, kSwatchSide);
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
		[[TGClient shared]
				setAccountProfileAccentColorPreservingBackgroundEmoji:self.pendingProfileId
														   completion:finish];
	if (self.accentChanged)
		[[TGClient shared] setAccountAccentColorPreservingBackgroundEmoji:self.pendingAccentId
															   completion:finish];
}

@end
