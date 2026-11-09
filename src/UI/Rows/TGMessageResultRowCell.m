//
// TGMessageResultRowCell.m
//
#import "TGMessageResultRowCell.h"
#import "TGRows.h"
#import "TGIcons.h"
#import "TGStyle.h"
#import "TGTheme.h"

@interface TGMessageResultRowCell ()
@property (nonatomic, strong) UIImageView *faceView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *textLabelCustom;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) NSDictionary *row;
@end

@implementation TGMessageResultRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	(void)row;
	(void)tableView;
	return TGMetricPersonRow;
}

+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row {
	static NSString *reuse = @"TGMessageResultRowCell";
	TGMessageResultRowCell *cell =
			[tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGMessageResultRowCell alloc] initWithStyle:UITableViewCellStyleDefault
											reuseIdentifier:reuse];
	[cell configureWithRow:row];
	return cell;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
			   reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault
				reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	_faceView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_faceView.contentMode = UIViewContentModeScaleAspectFill;
	_faceView.clipsToBounds = YES;
	[self.contentView addSubview:_faceView];

	_titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_titleLabel.font = TGFontBodyStrong();
	_titleLabel.backgroundColor = [UIColor clearColor];
	_titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	_titleLabel.numberOfLines = 1;
	[self.contentView addSubview:_titleLabel];

	_dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_dateLabel.font = TGFontCaption();
	_dateLabel.textAlignment = NSTextAlignmentRight;
	_dateLabel.backgroundColor = [UIColor clearColor];
	_dateLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	_dateLabel.numberOfLines = 1;
	[self.contentView addSubview:_dateLabel];

	_textLabelCustom = [[UILabel alloc] initWithFrame:CGRectZero];
	_textLabelCustom.font = TGFontCaption();
	_textLabelCustom.backgroundColor = [UIColor clearColor];
	_textLabelCustom.lineBreakMode = NSLineBreakByTruncatingTail;
	_textLabelCustom.numberOfLines = 1;
	[self.contentView addSubview:_textLabelCustom];

	[self applyTheme];
	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.row = nil;
	self.faceView.image = nil;
	self.titleLabel.text = nil;
	self.dateLabel.text = nil;
	self.textLabelCustom.text = nil;
	[self applyTheme];
}

- (void)configureWithRow:(NSDictionary *)row {
	self.row = row;
	TGTheme *theme = [TGTheme shared];
	[theme styleCell:self];
	self.accessoryType = UITableViewCellAccessoryNone;
	self.accessoryView = nil;
	self.selectionStyle = row[TGRowTap] ? UITableViewCellSelectionStyleDefault
			: UITableViewCellSelectionStyleNone;

	NSString *title = row[TGRowTitle] ?: @"";
	NSString *text = row[TGRowMessageText] ?: @"";
	NSString *date = row[TGRowMessageDate] ?: @"";
	self.titleLabel.text = title;
	self.textLabelCustom.text = text;
	self.dateLabel.text = date;

	UIImage *given = row[TGRowAvatarImage];
	if ([given isKindOfClass:UIImage.class]){
		self.faceView.image = [TGIcons roundedImage:given
				size:CGSizeMake(TGMetricListAvatar, TGMetricListAvatar)
				radius:TGHalf(TGMetricListAvatar)
				corners:UIRectCornerAllCorners];
	} else {
		int64_t peer = [row[TGRowPeerId] longLongValue];
		NSString *initials = [TGIcons initialsForTitle:title];
		self.faceView.image = [TGIcons avatarWithInitials:
				initials.length ? initials : @"?"
				size:TGMetricListAvatar colourId:peer];
	}
	[self applyTheme];
	[self setNeedsLayout];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	self.backgroundColor = [theme cardBackgroundColour];
	self.contentView.backgroundColor = [theme cardBackgroundColour];
	self.titleLabel.textColor = [theme primaryTextColour];
	self.textLabelCustom.textColor = [theme secondaryTextColour];
	self.dateLabel.textColor = [theme secondaryTextColour];
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGRect bounds = self.contentView.bounds;
	CGFloat height = bounds.size.height;
	CGFloat left = TGMetricGutter;
	CGFloat avatarSide = TGMetricListAvatar;
	self.faceView.frame = CGRectMake(left, TGCenteredOrigin(height, avatarSide),
			avatarSide, avatarSide);

	CGFloat x = left + avatarSide + TGMetricPadMedium;
	CGFloat right = bounds.size.width - TGMetricPadMedium;
	CGFloat dateWidth = 0;
	if (self.dateLabel.text.length){
		CGSize size = [self.dateLabel sizeThatFits:
				CGSizeMake(TGMetricCallLabelWidth, TGMetricLineCaption)];
		dateWidth = ceilf(size.width);
		self.dateLabel.frame = CGRectMake(right - dateWidth,
				TGCenteredOrigin(height, TGMetricLineRow),
				dateWidth, TGMetricLineCaption);
	} else {
		self.dateLabel.frame = CGRectZero;
	}

	CGFloat titleRight = right - (dateWidth > 0
			? dateWidth + TGMetricPadSmall : 0);
	CGFloat titleWidth = MAX(0, titleRight - x);
	CGFloat total = TGMetricLineRow + TGMetricPadTiny + TGMetricLineCaption;
	CGFloat top = TGCenteredOrigin(height, total);
	self.titleLabel.frame = CGRectMake(x, top, titleWidth, TGMetricLineRow);
	self.textLabelCustom.frame = CGRectMake(x, top + TGMetricLineRow +
			TGMetricPadTiny, MAX(0, right - x), TGMetricLineCaption);
}

@end
