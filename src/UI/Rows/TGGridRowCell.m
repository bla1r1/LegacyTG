//
// TGGridRowCell.m - the shared picture grid row.
//
#import "TGGridRowCell.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGIcons.h"

/// One tile. The square plate is a subview so a caption can sit under it
/// without the rounded corners clipping the text.
@interface TGGridTileView : UIControl
@property (nonatomic, strong) UIView *plateView;
@property (nonatomic, strong) UIImageView *pictureView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) UIImageView *checkView;
@property (nonatomic, strong) UIImageView *lockView;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UILabel *captionLabel;
- (void)configureWithItem:(NSDictionary *)item theme:(TGTheme *)theme;
@end

@implementation TGGridTileView

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;

	_plateView = [[UIView alloc] initWithFrame:CGRectZero];
	_plateView.clipsToBounds = YES;
	[self addSubview:_plateView];

	_pictureView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_pictureView.contentMode = UIViewContentModeScaleAspectFill;
	_pictureView.clipsToBounds = YES;
	[_plateView addSubview:_pictureView];

	_placeholderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_placeholderLabel.textAlignment = NSTextAlignmentCenter;
	_placeholderLabel.backgroundColor = [UIColor clearColor];
	_placeholderLabel.adjustsFontSizeToFitWidth = YES;
	_placeholderLabel.minimumFontSize = TGFontSizeMicro;
	[_plateView addSubview:_placeholderLabel];

	_checkView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_checkView.contentMode = UIViewContentModeScaleAspectFit;
	[_plateView addSubview:_checkView];

	_lockView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_lockView.contentMode = UIViewContentModeCenter;
	[_plateView addSubview:_lockView];

	_badgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_badgeLabel.font = TGFontMicro();
	_badgeLabel.textAlignment = NSTextAlignmentCenter;
	_badgeLabel.clipsToBounds = YES;
	[_plateView addSubview:_badgeLabel];

	_captionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_captionLabel.font = TGFontCaption();
	_captionLabel.textAlignment = NSTextAlignmentCenter;
	_captionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	_captionLabel.numberOfLines = 1;
	_captionLabel.backgroundColor = [UIColor clearColor];
	[self addSubview:_captionLabel];

	return self;
}

- (void)configureWithItem:(NSDictionary *)item theme:(TGTheme *)theme {
	UIColor *fill = item[TGGridItemColour];
	self.plateView.backgroundColor = fill ?: [theme fileTileColour];

	UIImage *image = item[TGGridItemImage];
	if ([image isKindOfClass:UIImage.class]){
		self.pictureView.image = image;
		self.pictureView.hidden = NO;
		self.placeholderLabel.hidden = YES;
	} else {
		self.pictureView.image = nil;
		self.pictureView.hidden = YES;
		self.placeholderLabel.hidden = NO;
		id emoji = item[TGGridItemEmoji];
		if ([emoji isKindOfClass:NSString.class] && [emoji length]){
			self.placeholderLabel.text = emoji;
			self.placeholderLabel.font = TGFontEmoji();
		} else {
			id initials = item[TGGridItemInitials];
			self.placeholderLabel.text = [initials isKindOfClass:NSString.class]
					? initials : @"";
			self.placeholderLabel.font = TGFontRowStrong();
		}
		self.placeholderLabel.textColor = [theme primaryTextColour];
	}

	self.checkView.hidden = ![item[TGGridItemChecked] boolValue];
	self.checkView.image = self.checkView.hidden ? nil
			: [TGIcons ticksColour:([theme isDark] ? [theme onMediaColour]
					: [theme accentColour]) read:NO];

	self.lockView.hidden = ![item[TGGridItemLocked] boolValue];
	self.lockView.image = self.lockView.hidden ? nil
			: [TGIcons lockOfSide:TGMetricMenuGlyph
					colour:[theme onMediaColour]];

	id badge = item[TGGridItemBadge];
	NSString *badgeText = nil;
	if ([badge isKindOfClass:NSNumber.class] && [badge integerValue] > 0)
		badgeText = [NSString stringWithFormat:@"%ld", (long)[badge integerValue]];
	else if ([badge isKindOfClass:NSString.class] && [badge length])
		badgeText = badge;
	self.badgeLabel.hidden = badgeText.length == 0;
	self.badgeLabel.text = badgeText;
	self.badgeLabel.textColor = [theme onAccentColour];
	self.badgeLabel.backgroundColor = [theme destructiveColour];

	id caption = item[TGGridItemCaption];
	NSString *captionText = [caption isKindOfClass:NSString.class] ? caption : nil;
	self.captionLabel.text = captionText;
	self.captionLabel.textColor = [theme secondaryTextColour];
	self.captionLabel.hidden = captionText.length == 0;

	BOOL enabled = item[TGGridItemEnabled] == nil
			|| [item[TGGridItemEnabled] boolValue];
	self.enabled = enabled;
	self.alpha = enabled ? TGAlphaOpaque : TGAlphaSecondary;
	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat side = CGRectGetWidth(self.bounds);
	self.plateView.frame = CGRectMake(0, 0, side, side);
	self.plateView.layer.cornerRadius = TGMetricCornerSmall;
	self.pictureView.frame = CGRectMake(0, 0, side, side);
	self.placeholderLabel.frame = CGRectMake(0, 0, side, side);

	CGFloat tickW = TGMetricTicksWidth;
	CGFloat tickH = TGMetricTicksHeight;
	self.checkView.frame = CGRectMake(TGMetricPadSmall, TGMetricPadSmall,
			tickW, tickH);

	CGFloat lockSide = TGMetricMenuGlyph;
	self.lockView.frame = CGRectMake(TGCenteredOrigin(side, lockSide),
			TGCenteredOrigin(side, lockSide), lockSide, lockSide);

	CGFloat badgeSide = TGMetricBadgeH;
	self.badgeLabel.frame = CGRectMake(side - badgeSide - TGMetricPadSmall,
			TGMetricPadSmall, badgeSide, badgeSide);
	self.badgeLabel.layer.cornerRadius = TGHalf(badgeSide);

	self.captionLabel.frame = CGRectMake(0, side, side, TGMetricLineCaption);
}

@end

#pragma mark - the row

@interface TGGridRowCell ()
@property (nonatomic, strong) NSDictionary *row;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) NSMutableArray *tiles;
@property (nonatomic, copy) void (^rowTap)(NSInteger index);
@property (nonatomic, assign) BOOL captions;
@end

@implementation TGGridRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	NSInteger columns = [row[TGRowGridColumns] integerValue];
	if (columns < 1)
		columns = 1;
	NSArray *items = row[TGRowGridItems];
	CGFloat width = tableView.bounds.size.width - TGMetricGridTableMargin;
	if (width <= 0)
		width = TGMetricScreenWidth - TGMetricGridTableMargin;
	CGFloat side = TGGridTileSideForWidth(width, columns);
	if (side <= 0)
		return TGMetricRow;
	BOOL captions = NO;
	for (NSDictionary *item in items)
		if ([item[TGGridItemCaption] isKindOfClass:NSString.class] &&
				[item[TGGridItemCaption] length]){
			captions = YES;
			break;
		}
	NSInteger lines = items.count
			? (NSInteger)((items.count + (NSUInteger)columns - 1) /
					(NSUInteger)columns) : 1;
	CGFloat lineHeight = side + (captions
			? TGMetricLineCaption + TGMetricPadTiny : 0);
	return TGMetricGridInset * 2.0f + (CGFloat)lines * lineHeight +
			(CGFloat)(lines - 1) * TGMetricGridGap;
}

+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row {
	static NSString *reuse = @"TGGridRowCell";
	TGGridRowCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGGridRowCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];
	[cell configureWithRow:row];
	return cell;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
			   reuseIdentifier:(NSString *)reuse {
	self = [super initWithStyle:style reuseIdentifier:reuse];
	if (!self)
		return nil;
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.backgroundColor = [UIColor clearColor];
	self.contentView.backgroundColor = [UIColor clearColor];
	self.tiles = [NSMutableArray array];
	[self applyTheme];
	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.row = nil;
	self.items = nil;
	self.rowTap = nil;
	for (TGGridTileView *tile in self.tiles)
		tile.hidden = YES;
}

- (void)configureWithRow:(NSDictionary *)row {
	self.row = row;
	self.items = row[TGRowGridItems] ?: @[];
	self.rowTap = row[TGRowGridTap];

	NSInteger count = (NSInteger)self.items.count;
	while (self.tiles.count < (NSUInteger)count){
		TGGridTileView *tile = [[TGGridTileView alloc] initWithFrame:CGRectZero];
		tile.tag = (NSInteger)self.tiles.count;
		[tile addTarget:self action:@selector(tileTapped:)
				forControlEvents:UIControlEventTouchUpInside];
		UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
				initWithTarget:self action:@selector(tileHeld:)];
		hold.minimumPressDuration = TGAnimationDurationHighlight;
		[tile addGestureRecognizer:hold];
		[self.contentView addSubview:tile];
		[self.tiles addObject:tile];
	}

	TGTheme *theme = [TGTheme shared];
	self.captions = NO;
	for (NSUInteger i = 0; i < self.tiles.count; i++){
		TGGridTileView *tile = self.tiles[i];
		if (i >= self.items.count){
			tile.hidden = YES;
			continue;
		}
		NSDictionary *item = self.items[i];
		if ([item[TGGridItemCaption] isKindOfClass:NSString.class] &&
				[item[TGGridItemCaption] length])
			self.captions = YES;
		tile.hidden = NO;
		[tile configureWithItem:item theme:theme];
	}
	[self setNeedsLayout];
}

- (void)tileTapped:(TGGridTileView *)tile {
	NSInteger index = tile.tag;
	if (index < 0 || index >= (NSInteger)self.items.count)
		return;
	NSDictionary *item = self.items[(NSUInteger)index];
	if (item[TGGridItemEnabled] != nil &&
			![item[TGGridItemEnabled] boolValue])
		return;
	void (^tileTap)(void) = item[TGGridItemTap];
	if (tileTap){
		tileTap();
		return;
	}
	if (self.rowTap)
		self.rowTap(index);
}

- (void)tileHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	TGGridTileView *tile = (TGGridTileView *)hold.view;
	NSInteger index = tile.tag;
	if (index < 0 || index >= (NSInteger)self.items.count)
		return;
	NSDictionary *item = self.items[(NSUInteger)index];
	if (item[TGGridItemEnabled] != nil &&
			![item[TGGridItemEnabled] boolValue])
		return;
	void (^tileHold)(void) = item[TGGridItemHold];
	if (tileHold)
		tileHold();
}

- (void)applyTheme {
	if (!self.row)
		return;
	[self configureWithRow:self.row];
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGFloat width = CGRectGetWidth(self.contentView.bounds);
	NSInteger columns = [self.row[TGRowGridColumns] integerValue];
	if (columns < 1)
		columns = 1;
	CGFloat side = TGGridTileSideForWidth(width, columns);
	if (side <= 0)
		return;
	CGFloat captionHeight = self.captions
			? TGMetricLineCaption + TGMetricPadTiny : 0;
	CGFloat pitchX = side + TGMetricGridGap;
	CGFloat pitchY = side + captionHeight + TGMetricGridGap;

	for (NSUInteger i = 0; i < self.tiles.count; i++){
		TGGridTileView *tile = self.tiles[i];
		if (tile.hidden)
			continue;
		NSInteger column = (NSInteger)i % columns;
		NSInteger line = (NSInteger)i / columns;
		CGFloat x = TGMetricGridInset + (CGFloat)column * pitchX;
		CGFloat y = TGMetricGridInset + (CGFloat)line * pitchY;
		tile.frame = CGRectMake(x, y, side, side + captionHeight);
	}
}

@end

// vim:ft=objc
