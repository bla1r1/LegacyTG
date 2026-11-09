//
// TGThemeGridRowCell.m - the Chat Themes grid.
//
#import "TGThemeGridRowCell.h"
#import "TGThemeCardsRowCell.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGStyle.h"

/// The grid and carousel share the card plate: the theme's card role, not the
/// table's black background, and repainted on reuse after a theme change.
static void TGStyleThemeGridCell(UITableViewCell *cell) {
	if (!cell)
		return;
	UIColor *background = [[TGTheme shared] cardBackgroundColour];
	cell.backgroundColor = background;
	cell.contentView.backgroundColor = background;
	if (cell.backgroundView)
		cell.backgroundView.backgroundColor = background;
}

@interface TGThemeGridRowCell ()
@property (nonatomic, strong) NSDictionary *row;
@property (nonatomic, strong) NSArray *themes;
@property (nonatomic, copy) NSString *currentId;
@property (nonatomic, copy) void (^selectBlock)(NSString *themeId);
@end

@implementation TGThemeGridRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	(void)tableView;
	NSUInteger count = [row[TGRowThemes] count];
	NSUInteger columns = TGMetricThemeGridColumns;
	NSUInteger rows = (count + columns - 1) / columns;
	if (!rows)
		return TGMetricThemeCardRow;
	return TGDoubled(TGMetricPad) + rows * TGMetricThemeCardH +
			(rows - 1) * TGMetricThemeGridGap;
}

+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row {
	static NSString *reuse = @"TGThemeGridRowCell";
	TGThemeGridRowCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGThemeGridRowCell alloc]
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
	TGStyleThemeGridCell(self);
	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.row = nil;
	self.themes = nil;
	self.currentId = nil;
	self.selectBlock = nil;
	for (UIView *view in [self.contentView.subviews copy])
		[view removeFromSuperview];
}

- (void)configureWithRow:(NSDictionary *)row {
	self.row = row;
	self.selectBlock = row[TGRowThemeTap];
	[self applyTheme];
}

- (void)setThemes:(NSArray *)themes currentThemeId:(NSString *)currentId {
	TGStyleThemeGridCell(self);
	self.themes = [themes copy] ?: @[];
	self.currentId = [currentId copy];
	for (UIView *view in [self.contentView.subviews copy])
		[view removeFromSuperview];
	for (NSUInteger i = 0; i < self.themes.count; i++){
		NSDictionary *entry = self.themes[i];
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = (NSInteger)i;
		[button setImage:TGAppearanceThemeCardImage(entry,
				[entry[@"id"] isEqualToString:self.currentId],
				CGSizeMake(TGMetricThemeCardW, TGMetricThemeCardH), YES)
				forState:UIControlStateNormal];
		[button addTarget:self action:@selector(cardTapped:)
		 forControlEvents:UIControlEventTouchUpInside];
		[self.contentView addSubview:button];
	}
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
	[self setThemes:self.row[TGRowThemes]
		currentThemeId:self.row[TGRowCurrentTheme]];
	TGStyleThemeGridCell(self);
}

- (void)layoutSubviews {
	[super layoutSubviews];
	NSUInteger count = self.themes.count;
	if (!count)
		return;
	NSUInteger columns = TGMetricThemeGridColumns;
	CGFloat gap = TGMetricThemeGridGap;
	for (NSUInteger i = 0; i < count; i++){
		NSUInteger row = i / columns;
		NSUInteger column = i % columns;
		NSUInteger inRow = MIN(columns, count - row * columns);
		CGFloat rowWidth = inRow * TGMetricThemeCardW + (inRow - 1) * gap;
		CGFloat rowX = TGCenteredOrigin(CGRectGetWidth(self.contentView.bounds),
				rowWidth);
		UIView *view = self.contentView.subviews[i];
		view.frame = CGRectMake(rowX + column * (TGMetricThemeCardW + gap),
				TGMetricPad + row * (TGMetricThemeCardH + gap),
				TGMetricThemeCardW, TGMetricThemeCardH);
	}
}

@end

// vim:ft=objc
