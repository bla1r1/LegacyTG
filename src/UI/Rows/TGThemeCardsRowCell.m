//
// TGThemeCardsRowCell.m - the horizontal theme carousel.
//
#import "TGThemeCardsRowCell.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGThemeFile.h"
#import "TGThemeList.h"
#import "TGChatThemeStore.h"
#import "TGStyle.h"

static NSCache *TGThemeCardCache;

/// 32-bit devices have a 16 MB internal cache ceiling. The preview and card
/// caches take 3 MB each; the chat theme store owns the other 10 MB.
static NSUInteger TGAppearanceImageCacheLimit(void) {
	return sizeof(void *) == 4 ? 3 * 1024 * 1024 : 32 * 1024 * 1024;
}

static UIImage *TGAppearancePatternImage(void) {
	static UIImage *pattern = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		pattern = [UIImage imageNamed:@"builtin-wallpaper-0-thumbnail.jpg"];
	});
	return pattern;
}

static void TGDrawImageFillingRect(UIImage *image, CGRect rect,
								   CGBlendMode blendMode) {
	if (!image || image.size.width <= 0 || image.size.height <= 0)
		return;
	CGFloat scale = MAX(rect.size.width / image.size.width,
			rect.size.height / image.size.height);
	CGSize drawn = CGSizeMake(image.size.width * scale, image.size.height * scale);
	CGRect frame = CGRectMake(CGRectGetMinX(rect) + TGCenteredOrigin(rect.size.width, drawn.width),
			CGRectGetMinY(rect) + TGCenteredOrigin(rect.size.height, drawn.height),
			drawn.width, drawn.height);
	[image drawInRect:frame blendMode:blendMode alpha:TGAlphaOpaque];
}

static void TGDrawImageFillingRectAlpha(UIImage *image, CGRect rect,
										CGBlendMode blendMode, CGFloat alpha) {
	if (!image || image.size.width <= 0 || image.size.height <= 0)
		return;
	CGFloat scale = MAX(rect.size.width / image.size.width,
			rect.size.height / image.size.height);
	CGSize drawn = CGSizeMake(image.size.width * scale, image.size.height * scale);
	CGRect frame = CGRectMake(CGRectGetMinX(rect) + TGCenteredOrigin(rect.size.width, drawn.width),
			CGRectGetMinY(rect) + TGCenteredOrigin(rect.size.height, drawn.height),
			drawn.width, drawn.height);
	[image drawInRect:frame blendMode:blendMode alpha:alpha];
}

/// The wallpaper behind the theme cards. A theme may carry a picture; without
/// one, Telegram's own doodle pattern is laid over the chat paper, dark on a
/// dark theme so white doodles do not turn into a light card.
static void TGDrawAppearanceWallpaper(UIImage *paper, UIColor *paperColour,
									  CGRect rect, BOOL dark) {
	if (paper && paper.size.width > 0){
		TGDrawImageFillingRect(paper, rect, kCGBlendModeNormal);
		return;
	}
	[paperColour setFill];
	UIRectFill(rect);
	if (dark)
		return;
	UIImage *pattern = TGAppearancePatternImage();
	if (!pattern)
		return;
	TGDrawImageFillingRect(pattern, rect, kCGBlendModeNormal);
}

/// A theme background fill: a solid colour, a two-stop gradient, or the
/// freeform run Telegram sends for emoji themes. All of them are baked here.
static void TGDrawAppearanceFill(NSDictionary *fill, UIColor *fallback,
								 CGRect rect) {
	NSArray *colours = fill[@"colors"];
	if (![colours isKindOfClass:NSArray.class] || !colours.count){
		[fallback setFill];
		UIRectFill(rect);
		return;
	}
	if (colours.count == 1){
		[(UIColor *)colours.firstObject setFill];
		UIRectFill(rect);
		return;
	}
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	NSMutableArray *cgColours = [NSMutableArray arrayWithCapacity:colours.count];
	for (UIColor *colour in colours)
		[cgColours addObject:(__bridge id)colour.CGColor];
	CGGradientRef gradient = CGGradientCreateWithColors(space,
			(__bridge CFArrayRef)cgColours, NULL);
	CGContextDrawLinearGradient(ctx, gradient,
			CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)),
			CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)), 0);
	CGGradientRelease(gradient);
	CGColorSpaceRelease(space);
}

UIImage *TGAppearanceThemeCardImage(NSDictionary *entry, BOOL selected,
									CGSize size, BOOL showsName) {
	BOOL emojiTheme = [entry[@"emoji"] boolValue] ||
			TGChatThemeIdIsEmoji(entry[@"id"]);
	BOOL dark = emojiTheme ? [[TGTheme shared] isNightModeEnabled]
			: [entry[@"dark"] boolValue];
	NSDictionary *palette = emojiTheme
			? [[TGChatThemeStore shared] paletteForEntry:entry dark:dark]
			: [TGTheme cardPaletteForThemeEntry:entry];
	UIImage *pattern = emojiTheme
			? [[TGChatThemeStore shared] patternImageForThemeNamed:entry[@"name"]
					dark:dark]
			: nil;
	NSString *key = [NSString stringWithFormat:@"%@|%d|%.0f|%.0f|%d|%d|%lu",
			entry[@"id"], selected, size.width, size.height, showsName, dark,
			(unsigned long)pattern.hash];
	UIImage *cached = [TGThemeCardCache objectForKey:key];
	if (cached)
		return cached;

	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	CGRect rect = CGRectMake(0, 0, size.width, size.height);
	UIBezierPath *card = [UIBezierPath bezierPathWithRoundedRect:rect
			cornerRadius:TGMetricCornerCard];
	[card addClip];
	if (emojiTheme){
		UIImage *background = [[TGChatThemeStore shared]
				cardWallpaperForThemeNamed:entry[@"name"] dark:dark size:size];
		if (background)
			[background drawInRect:rect];
		else {
			TGDrawAppearanceFill(palette[@"wallpaperFill"], palette[@"wallpaper"], rect);
			if (pattern && pattern.size.width > 0 && pattern.size.height > 0){
				CGFloat intensity = [palette[@"patternIntensity"] doubleValue] / 100.0f;
				intensity = MAX(0.0f, MIN(1.0f, intensity));
				TGDrawImageFillingRectAlpha(pattern, rect, kCGBlendModeNormal, intensity);
			}
		}
	} else {
		TGDrawAppearanceWallpaper(nil, palette[@"wallpaper"], rect, dark);
	}

	CGFloat bubbleX = TGMetricPadMedium;
	CGFloat bubbleY = TGMetricPadMedium;
	CGRect mine = CGRectMake(bubbleX, bubbleY, TGMetricThemeCardBubbleW,
			TGMetricThemeCardBubbleH);
	UIBezierPath *minePath = [UIBezierPath bezierPathWithRoundedRect:mine
			cornerRadius:TGMetricCornerSmall];
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	NSArray *mineStops = palette[@"bubbleMineGradient"];
	if (mineStops.count < 2)
		mineStops = @[palette[@"bubbleMine"], palette[@"bubbleMine"]];
	CGContextSaveGState(ctx);
	[minePath addClip];
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	NSMutableArray *mineCGColours = [NSMutableArray array];
	for (UIColor *colour in mineStops)
		[mineCGColours addObject:(__bridge id)colour.CGColor];
	CGGradientRef gradient = CGGradientCreateWithColors(space,
			(__bridge CFArrayRef)mineCGColours, NULL);
	CGContextDrawLinearGradient(ctx, gradient,
			CGPointMake(0, CGRectGetMinY(mine)),
			CGPointMake(0, CGRectGetMaxY(mine)), 0);
	CGGradientRelease(gradient);
	CGColorSpaceRelease(space);
	CGContextRestoreGState(ctx);

	CGRect theirs = CGRectMake(bubbleX, CGRectGetMaxY(mine) + TGMetricThemeCardBubbleGap,
			TGMetricThemeCardBubbleW - TGMetricPadSmall,
			TGMetricThemeCardBubbleH - TGMetricPadSmall);
	UIBezierPath *theirsPath = [UIBezierPath bezierPathWithRoundedRect:theirs
			cornerRadius:TGMetricCornerSmall];
	[palette[@"bubbleTheirs"] setFill];
	[theirsPath fill];

	NSString *emoji = emojiTheme ? entry[@"name"]
			: (dark ? @"🌙" : ([entry[@"id"] isEqualToString:@"classic"]
					? @"🏠" : @"🎨"));
	CGRect emojiRect = CGRectMake(0, CGRectGetMaxY(theirs) + TGMetricPadSmall,
			CGRectGetWidth(rect), TGMetricThemeCardEmojiH);
	[emoji drawInRect:emojiRect withFont:TGFontRow()
		lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];

	// A base theme's name is a label under the card; an emoji theme's name is
	// the glyph itself, so it is never drawn twice.
	if (showsName && !emojiTheme){
		NSString *name = TGSettingsThemeDisplayName(entry);
		[palette[@"text"] setFill];
		[name drawInRect:CGRectMake(bubbleX, CGRectGetHeight(rect) -
				TGMetricThemeCardNameH - TGMetricPadSmall, CGRectGetWidth(rect) -
				TGDoubled(bubbleX), TGMetricThemeCardNameH)
			   withFont:TGFontMicro()
		  lineBreakMode:NSLineBreakByTruncatingTail
			  alignment:NSTextAlignmentCenter];
	}

	if (selected){
		CGRect ringRect = CGRectInset(rect, TGMetricBorderThick,
				TGMetricBorderThick);
		UIBezierPath *ring = [UIBezierPath bezierPathWithRoundedRect:ringRect
				cornerRadius:TGMetricCornerCard];
		ring.lineWidth = TGMetricBorderThick;
		[palette[@"accent"] setStroke];
		[ring stroke];
	}

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (!TGThemeCardCache){
		TGThemeCardCache = [[NSCache alloc] init];
		TGThemeCardCache.totalCostLimit = TGAppearanceImageCacheLimit();
	}
	if (image)
		[TGThemeCardCache setObject:image forKey:key];
	return image;
}

static UIImage *TGThemeCardImage(NSDictionary *entry, BOOL selected,
								 BOOL showsName) {
	return TGAppearanceThemeCardImage(entry, selected,
			CGSizeMake(TGMetricThemeCardW, TGMetricThemeCardH), showsName);
}

/// The carousel and grid rows are ordinary grouped cells: their plate is the
/// theme's card role, not the table's black background. It has to be repainted
/// here as well as in the cell factory because the cell is reused after a
/// theme change.
static void TGStyleThemeCardsCell(UITableViewCell *cell) {
	if (!cell)
		return;
	UIColor *background = [[TGTheme shared] cardBackgroundColour];
	cell.backgroundColor = background;
	cell.contentView.backgroundColor = background;
	if (cell.backgroundView)
		cell.backgroundView.backgroundColor = background;
}

@interface TGThemeCardsRowCell ()
@property (nonatomic, strong) NSDictionary *row;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) NSArray *themes;
@property (nonatomic, strong) NSArray *buttons;
@property (nonatomic, strong) NSArray *labels;
@property (nonatomic, copy) NSString *currentId;
@property (nonatomic, assign) BOOL showsNames;
@property (nonatomic, copy) void (^selectBlock)(NSString *themeId);
@end

@implementation TGThemeCardsRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	(void)row;
	(void)tableView;
	return TGMetricThemeCardRow;
}

+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row {
	static NSString *reuse = @"TGThemeCardsRowCell";
	TGThemeCardsRowCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGThemeCardsRowCell alloc]
				initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
	[cell configureWithRow:row];
	return cell;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
			   reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	_scroll = [[UIScrollView alloc] init];
	_scroll.showsHorizontalScrollIndicator = NO;
	_scroll.showsVerticalScrollIndicator = NO;
	_scroll.alwaysBounceHorizontal = YES;
	[self.contentView addSubview:_scroll];
	TGStyleThemeCardsCell(self);
	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.row = nil;
	self.themes = nil;
	self.buttons = nil;
	self.labels = nil;
	self.currentId = nil;
	self.selectBlock = nil;
	for (UIView *view in [self.scroll.subviews copy])
		[view removeFromSuperview];
}

- (void)configureWithRow:(NSDictionary *)row {
	self.row = row;
	self.selectBlock = row[TGRowThemeTap];
	[self applyTheme];
}

- (void)setThemes:(NSArray *)themes currentThemeId:(NSString *)currentId {
	TGStyleThemeCardsCell(self);
	self.themes = [themes copy] ?: @[];
	self.currentId = [currentId copy];
	for (UIView *view in [self.scroll.subviews copy])
		[view removeFromSuperview];
	NSMutableArray *labels = [NSMutableArray array];
	NSMutableArray *buttons = [NSMutableArray array];
	for (NSUInteger i = 0; i < self.themes.count; i++){
		NSDictionary *entry = self.themes[i];
		BOOL selected = [entry[@"id"] isEqualToString:self.currentId];
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = (NSInteger)i;
		[button setImage:TGThemeCardImage(entry, selected, !self.showsNames)
				forState:UIControlStateNormal];
		[button addTarget:self action:@selector(cardTapped:)
		 forControlEvents:UIControlEventTouchUpInside];
		[self.scroll addSubview:button];
		[buttons addObject:button];
		if (self.showsNames){
			UILabel *label = [[UILabel alloc] init];
			label.text = TGSettingsThemeDisplayName(entry);
			label.font = TGFontMicro();
			label.textAlignment = NSTextAlignmentCenter;
			label.textColor = selected ? [[TGTheme shared] accentColour]
					: [[TGTheme shared] primaryTextColour];
			label.backgroundColor = [UIColor clearColor];
			[self.scroll addSubview:label];
			[labels addObject:label];
		}
	}
	self.buttons = buttons;
	self.labels = labels;
	[self setNeedsLayout];
}

- (void)cardTapped:(UIButton *)button {
	if (button.tag < 0 || button.tag >= (NSInteger)self.themes.count)
		return;
	NSDictionary *entry = self.themes[(NSUInteger)button.tag];
	if (self.selectBlock)
		self.selectBlock(entry[@"id"]);
}

- (void)applyTheme {
	if (!self.row)
		return;
	self.showsNames = [self.row[TGRowThemeNames] boolValue];
	[self setThemes:self.row[TGRowThemes]
		currentThemeId:self.row[TGRowCurrentTheme]];
	TGStyleThemeCardsCell(self);
}

- (void)layoutSubviews {
	[super layoutSubviews];
	self.scroll.frame = self.contentView.bounds;
	CGFloat x = TGMetricPadMedium;
	CGFloat cardY = self.showsNames ? TGMetricPad
			: TGCenteredOrigin(CGRectGetHeight(self.contentView.bounds),
					TGMetricThemeCardH);
	for (NSUInteger i = 0; i < self.buttons.count; i++){
		UIView *view = self.buttons[i];
		view.frame = CGRectMake(x, cardY, TGMetricThemeCardW, TGMetricThemeCardH);
		if (self.showsNames && i < self.labels.count){
			UILabel *label = self.labels[i];
			label.frame = CGRectMake(x, CGRectGetMaxY(view.frame) + TGMetricPadTiny,
					TGMetricThemeCardW, TGMetricThemeCardNameH);
		}
		x += TGMetricThemeCardW + TGMetricPad;
	}
	self.scroll.contentSize = CGSizeMake(x, CGRectGetHeight(self.contentView.bounds));
}

@end

// vim:ft=objc
