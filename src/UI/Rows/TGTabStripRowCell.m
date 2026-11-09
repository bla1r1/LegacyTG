//
// TGTabStripRowCell.m
//
#import "TGTabStripRowCell.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGLocalization.h"

/// The selected tab's underline.
static const CGFloat kTabStripLine = 2.0f;

@interface TGTabStripRowCell ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableArray *tabButtons;
@property (nonatomic, strong) NSMutableArray *underlines;
@property (nonatomic, strong) NSDictionary *row;
@property (nonatomic, copy) void (^tabTap)(NSString *kind);
@property (nonatomic, copy) void (^tabHold)(NSString *kind);
@property (nonatomic, copy) void (^offsetChanged)(CGFloat offset);
@property (nonatomic, assign) CGFloat restoredOffset;
@property (nonatomic, assign) BOOL offsetRestored;
@end

@implementation TGTabStripRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	(void)row;
	(void)tableView;
	return TGMetricFolderTabRow;
}

+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row {
	static NSString *reuse = @"TGTabStripRowCell";
	TGTabStripRowCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGTabStripRowCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];
	[cell configureWithRow:row];
	return cell;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
			   reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.backgroundColor = [UIColor clearColor];
	self.contentView.backgroundColor = [UIColor clearColor];

	_scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
	_scrollView.showsHorizontalScrollIndicator = NO;
	_scrollView.showsVerticalScrollIndicator = NO;
	_scrollView.scrollsToTop = NO;
	_scrollView.delegate = self;
	[self.contentView addSubview:_scrollView];

	_tabButtons = [NSMutableArray array];
	_underlines = [NSMutableArray array];
	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.row = nil;
	self.tabTap = nil;
	self.tabHold = nil;
	self.offsetChanged = nil;
	self.restoredOffset = 0;
	self.offsetRestored = NO;
}

- (void)configureWithRow:(NSDictionary *)row {
	self.row = row;
	self.tabTap = row[TGRowTabStripTap];
	self.tabHold = row[TGRowTabStripHold];
	self.offsetChanged = row[TGRowTabStripOffsetChanged];
	self.restoredOffset = [row[TGRowTabStripOffset] doubleValue];
	self.offsetRestored = NO;
	[self rebuildTabs];
}

- (void)rebuildTabs {
	NSArray *tabs = self.row[TGRowTabStripItems];
	if (![tabs isKindOfClass:NSArray.class])
		tabs = @[];
	NSString *selected = self.row[TGRowTabStripSelected];
	TGTheme *theme = [TGTheme shared];
	UIColor *accent = self.row[TGRowTabStripAccentColour] ?:
			[theme accentColour];
	UIColor *secondary = self.row[TGRowTabStripSecondaryColour] ?:
			[theme secondaryTextColour];
	UIColor *background = self.row[TGRowTabStripBackgroundColour] ?:
			[theme groupedBackgroundColour];
	self.scrollView.backgroundColor = background;
	self.backgroundColor = background;
	self.contentView.backgroundColor = background;

	while (self.tabButtons.count < tabs.count){
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.titleLabel.font = TGFontCaptionStrong();
		button.tag = (NSInteger)self.tabButtons.count;
		[button addTarget:self action:@selector(tabTapped:)
				forControlEvents:UIControlEventTouchUpInside];
		UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
				initWithTarget:self action:@selector(tabHeld:)];
		hold.minimumPressDuration = 0.5;
		[button addGestureRecognizer:hold];
		[self.scrollView addSubview:button];
		[self.tabButtons addObject:button];

		UIView *line = [[UIView alloc] initWithFrame:CGRectZero];
		line.userInteractionEnabled = NO;
		[self.scrollView addSubview:line];
		[self.underlines addObject:line];
	}

	for (NSUInteger i = 0; i < self.tabButtons.count; i++){
		UIButton *button = self.tabButtons[i];
		UIView *line = self.underlines[i];
		if (i >= tabs.count){
			button.hidden = YES;
			line.hidden = YES;
			continue;
		}
		NSDictionary *tab = [tabs[i] isKindOfClass:NSDictionary.class]
				? tabs[i] : @{};
		NSString *kind = tab[@"kind"];
		NSString *title = TGLocalized(tab[@"title"] ?: @"");
		BOOL isSelected = [kind isEqualToString:selected];
		button.hidden = NO;
		line.hidden = !isSelected;
		[button setTitle:title forState:UIControlStateNormal];
		[button setTitleColor:(isSelected ? accent : secondary)
					forState:UIControlStateNormal];
		line.backgroundColor = accent;
	}
	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect bounds = self.contentView.bounds;
	self.scrollView.frame = bounds;
	NSArray *tabs = self.row[TGRowTabStripItems];
	CGFloat x = TGMetricPadMedium;
	for (NSUInteger i = 0; i < self.tabButtons.count; i++){
		UIButton *button = self.tabButtons[i];
		UIView *line = self.underlines[i];
		if (i >= tabs.count || button.hidden){
			button.frame = CGRectZero;
			line.frame = CGRectZero;
			continue;
		}
		NSDictionary *tab = [tabs[i] isKindOfClass:NSDictionary.class]
				? tabs[i] : @{};
		UIFont *font = TGFontCaptionStrong();
		NSString *title = TGLocalized(tab[@"title"] ?: @"");
		CGFloat width = ceilf([title sizeWithFont:font].width) +
				TGDoubled(TGMetricPadMedium);
		button.frame = CGRectMake(x, 0, width, bounds.size.height);
		if (!line.hidden)
			line.frame = CGRectMake(x + TGMetricPadSmall,
					bounds.size.height - kTabStripLine,
					width - TGDoubled(TGMetricPadSmall), kTabStripLine);
		else
			line.frame = CGRectZero;
		x += width;
	}
	self.scrollView.contentSize = CGSizeMake(x + TGMetricPadMedium,
			bounds.size.height);
	if (!self.offsetRestored){
		self.offsetRestored = YES;
		CGFloat maxX = MAX(0, self.scrollView.contentSize.width -
				bounds.size.width);
		self.scrollView.contentOffset = CGPointMake(
				MIN(MAX(self.restoredOffset, 0), maxX), 0);
	}
}

- (void)tabTapped:(UIButton *)button {
	NSArray *tabs = self.row[TGRowTabStripItems];
	if (button.tag < 0 || button.tag >= (NSInteger)tabs.count)
		return;
	NSDictionary *tab = tabs[(NSUInteger)button.tag];
	NSString *kind = tab[@"kind"];
	if (kind.length && self.tabTap)
		self.tabTap(kind);
}

- (void)tabHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	UIButton *button = (UIButton *)hold.view;
	NSArray *tabs = self.row[TGRowTabStripItems];
	if (button.tag < 0 || button.tag >= (NSInteger)tabs.count)
		return;
	NSDictionary *tab = tabs[(NSUInteger)button.tag];
	NSString *kind = tab[@"kind"];
	if (kind.length && self.tabHold)
		self.tabHold(kind);
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	if (self.offsetChanged)
		self.offsetChanged(scrollView.contentOffset.x);
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
				  willDecelerate:(BOOL)decelerate {
	if (!decelerate && self.offsetChanged)
		self.offsetChanged(scrollView.contentOffset.x);
}

- (void)applyTheme {
	if (!self.row)
		return;
	[self rebuildTabs];
}

@end

// vim:ft=objc
