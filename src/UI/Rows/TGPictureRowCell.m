//
// TGPictureRowCell.m - the shared thumbnail + two lines + value row.
//
#import "TGPictureRowCell.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGIcons.h"
#import "TGLocalization.h"

@interface TGPictureRowCell ()
@property (nonatomic, strong) UIView *plateView;
@property (nonatomic, strong) UIImageView *pictureView;
@property (nonatomic, strong) UIImageView *glyphView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *trailingLabel;
@property (nonatomic, strong) NSDictionary *row;
@end

@implementation TGPictureRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	(void)tableView;
	NSNumber *height = row[TGRowHeight];
	return height ? [height doubleValue] : TGMetricPersonRow;
}

+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row {
	static NSString *reuse = @"TGPictureRowCell";
	TGPictureRowCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGPictureRowCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];
	[cell configureWithRow:row];
	return cell;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
			   reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	_plateView = [[UIView alloc] initWithFrame:CGRectZero];
	_plateView.clipsToBounds = YES;
	_plateView.layer.cornerRadius = TGMetricCornerSmall;
	[self.contentView addSubview:_plateView];

	_pictureView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_pictureView.contentMode = UIViewContentModeScaleAspectFill;
	_pictureView.clipsToBounds = YES;
	[_plateView addSubview:_pictureView];

	_glyphView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_glyphView.contentMode = UIViewContentModeCenter;
	[_plateView addSubview:_glyphView];

	_placeholderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_placeholderLabel.textAlignment = NSTextAlignmentCenter;
	_placeholderLabel.backgroundColor = [UIColor clearColor];
	[_plateView addSubview:_placeholderLabel];

	_titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_titleLabel.font = TGFontRow();
	_titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	_titleLabel.numberOfLines = 1;
	_titleLabel.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:_titleLabel];

	_subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_subtitleLabel.font = TGFontCaption();
	_subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	_subtitleLabel.numberOfLines = 1;
	_subtitleLabel.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:_subtitleLabel];

	_trailingLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_trailingLabel.font = TGFontCaption();
	_trailingLabel.textAlignment = NSTextAlignmentRight;
	_trailingLabel.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:_trailingLabel];

	[self applyTheme];
	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.row = nil;
	self.pictureView.image = nil;
	self.glyphView.image = nil;
	self.placeholderLabel.text = nil;
	self.trailingLabel.text = nil;
	[self applyTheme];
}

- (void)configureWithRow:(NSDictionary *)row {
	self.row = row;
	[self applyTheme];
	[self setNeedsLayout];
}

- (void)applyTheme {
	if (!self.row)
		return;
	TGTheme *theme = [TGTheme shared];
	[theme styleCell:self];
	self.selectionStyle = self.row[TGRowTap]
			? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;

	UIImage *picture = self.row[TGRowPictureImage];
	NSString *glyph = self.row[TGRowPictureGlyph];
	NSString *placeholder = self.row[TGRowPicturePlaceholder];
	UIColor *glyphColour = self.row[TGRowPictureGlyphColour] ?:
			[theme secondaryTextColour];

	self.plateView.backgroundColor = [theme fileTileColour];
	self.pictureView.hidden = ![picture isKindOfClass:UIImage.class];
	// A black glyph on the file plate disappears in a dark theme on iOS 6,
	// where nothing tints it: the colour goes straight into the bitmap.
	if (!self.pictureView.hidden && [TGTheme drawsSkeuomorphicChrome])
		picture = [TGIcons image:picture filledWith:glyphColour] ?: picture;
	self.pictureView.image = self.pictureView.hidden ? nil : picture;
	self.glyphView.hidden = self.pictureView.hidden
			? !(glyph.length > 0) : YES;
	self.glyphView.image = self.glyphView.hidden ? nil
			: [TGIcons glyphNamed:glyph colour:glyphColour
							 side:TGMetricMenuGlyph];
	self.placeholderLabel.hidden = self.pictureView.hidden
			? !(placeholder.length > 0) : YES;
	self.placeholderLabel.text = self.placeholderLabel.hidden
			? nil : placeholder;
	self.placeholderLabel.font = TGFontRow();
	self.placeholderLabel.textColor = [theme primaryTextColour];

	NSString *title = self.row[TGRowTitle] ?: @"";
	self.titleLabel.text = [self.row[TGRowRawTitle] boolValue]
			? title : TGLocalized(title);
	self.titleLabel.textColor = self.row[TGRowTitleColour] ?:
			[theme primaryTextColour];
	self.titleLabel.font = TGFontRow();

	NSString *subtitle = self.row[TGRowDetail];
	if (![subtitle isKindOfClass:NSString.class])
		subtitle = nil;
	self.subtitleLabel.hidden = subtitle.length == 0;
	self.subtitleLabel.text = [self.row[TGRowRawDetail] boolValue]
			? subtitle : TGLocalized(subtitle);
	self.subtitleLabel.textColor = [theme secondaryTextColour];

	NSString *trailing = self.row[TGRowAccessory];
	self.trailingLabel.text = [trailing isKindOfClass:NSString.class]
			? trailing : nil;
	self.trailingLabel.textColor = self.row[TGRowAccessoryColour] ?:
			[theme secondaryTextColour];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect bounds = self.contentView.bounds;
	CGFloat height = bounds.size.height;
	CGFloat side = TGMetricListAvatar;
	CGFloat left = TGMetricGutter;
	CGFloat top = TGCenteredOrigin(height, side);
	self.plateView.frame = CGRectMake(left, top, side, side);
	self.pictureView.frame = CGRectMake(0, 0, side, side);
	self.glyphView.frame = CGRectMake(0, 0, side, side);
	self.placeholderLabel.frame = CGRectMake(0, 0, side, side);

	CGFloat textX = left + side + TGMetricPadMedium;
	CGFloat right = bounds.size.width - TGMetricPadMedium;
	CGFloat trailingWidth = 0;
	if (self.trailingLabel.text.length){
		CGSize size = [self.trailingLabel sizeThatFits:
				CGSizeMake(TGMetricCallLabelWidth, TGMetricLineCaption)];
		trailingWidth = size.width;
		self.trailingLabel.frame = CGRectMake(right - trailingWidth,
				TGCenteredOrigin(height, TGMetricLineCaption),
				trailingWidth, TGMetricLineCaption);
	} else {
		self.trailingLabel.frame = CGRectZero;
	}
	CGFloat textWidth = MAX(0, right - textX -
			(trailingWidth > 0 ? trailingWidth + TGMetricPadSmall : 0));
	CGFloat titleHeight = TGMetricLineRow;
	CGFloat subtitleHeight = self.subtitleLabel.hidden
			? 0 : TGMetricLineCaption;
	CGFloat gap = self.subtitleLabel.hidden ? 0 : TGMetricPadTiny;
	CGFloat stack = titleHeight + gap + subtitleHeight;
	CGFloat textTop = TGCenteredOrigin(height, stack);
	self.titleLabel.frame = CGRectMake(textX, textTop, textWidth, titleHeight);
	if (!self.subtitleLabel.hidden)
		self.subtitleLabel.frame = CGRectMake(textX,
				textTop + titleHeight + gap, textWidth, subtitleHeight);
}

@end

// vim:ft=objc
