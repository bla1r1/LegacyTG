//
// TGProfileHeaderRowCell.m - the shared account header drawing.
//
#import "TGProfileHeaderRowCell.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGIcons.h"

/// The account header: the picture, the name under it, the phone under that.
/// Same offsets as the header Settings grew privately, now in one place.
static const CGFloat kMeAvatarTop  = TGMetricPadLarge + TGMetricPadTiny;
static const CGFloat kMeNameTop    = TGMetricPadMedium;
static const CGFloat kMeNameLine   = TGMetricLineTitle + TGMetricPadTiny;
static const CGFloat kMeTextInset  = TGMetricPadMedium;

@interface TGProfileHeaderRowCell ()
@property (nonatomic, strong) NSDictionary *row;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *phoneLabel;
@property (nonatomic, copy) void (^avatarLoader)(UIImageView *);
@property (nonatomic, assign) BOOL avatarLoaderStarted;
@end

@implementation TGProfileHeaderRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	(void)row;
	(void)tableView;
	return TGMetricSettingsProfileRow;
}

+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row {
	static NSString *reuse = @"TGProfileHeaderRowCell";
	TGProfileHeaderRowCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGProfileHeaderRowCell alloc]
				initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
	[cell configureWithRow:row];
	return cell;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
			   reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	_avatarView = [[UIImageView alloc] initWithFrame:CGRectZero];
	// Pre-baked circle bitmap: no CALayer cornerRadius or rasterizing mask on
	// scrolling headers.
	_avatarView.contentMode = UIViewContentModeScaleAspectFill;
	_avatarView.opaque = NO;
	_avatarView.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:_avatarView];

	_nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_nameLabel.font = TGFontTitle();
	_nameLabel.textAlignment = NSTextAlignmentCenter;
	_nameLabel.backgroundColor = [UIColor clearColor];
	_nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:_nameLabel];

	_phoneLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_phoneLabel.font = TGFontBody();
	_phoneLabel.textAlignment = NSTextAlignmentCenter;
	_phoneLabel.adjustsFontSizeToFitWidth = YES;
	_phoneLabel.backgroundColor = [UIColor clearColor];
	_phoneLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:_phoneLabel];

	[self applyTheme];
	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.row = nil;
	self.avatarLoader = nil;
	self.avatarLoaderStarted = NO;
}

- (void)configureWithRow:(NSDictionary *)row {
	self.row = row;
	self.avatarLoader = row[TGRowImageLoader];
	self.avatarLoaderStarted = NO;
	[self applyTheme];
	[self setNeedsLayout];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	[theme styleGroupedCell:self forRow:0 totalRows:1];
	self.selectionStyle = self.row[TGRowTap]
			? UITableViewCellSelectionStyleBlue
			: UITableViewCellSelectionStyleNone;

	NSString *name = self.row[TGRowTitle] ?: @"";
	self.nameLabel.text = name;
	self.nameLabel.textColor = [theme primaryTextColour];
	self.phoneLabel.text = self.row[TGRowDetail] ?: @"";
	self.phoneLabel.textColor = [theme secondaryTextColour];

	UIImage *avatar = self.row[TGRowImage];
	if ([avatar isKindOfClass:UIImage.class]){
		self.avatarView.image = avatar;
	} else {
		self.avatarView.image = [TGIcons avatarWithInitials:
				[TGIcons initialsForTitle:name]
				size:TGMetricProfileAvatar
				colourId:[self.row[TGRowPeerId] longLongValue]];
	}
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGFloat width = self.contentView.bounds.size.width;
	CGFloat side = TGMetricProfileAvatar;
	self.avatarView.frame = CGRectMake(TGCenteredOrigin(width, side),
			kMeAvatarTop, side, side);
	self.nameLabel.frame = CGRectMake(kMeTextInset,
			kMeAvatarTop + side + kMeNameTop,
			width - TGDoubled(kMeTextInset), kMeNameLine);
	self.phoneLabel.frame = CGRectMake(kMeTextInset,
			kMeAvatarTop + side + kMeNameTop + kMeNameLine,
			width - TGDoubled(kMeTextInset), TGMetricLineRow);

	if (!self.avatarLoaderStarted && self.avatarLoader &&
			self.avatarView.bounds.size.width > 0){
		self.avatarLoaderStarted = YES;
		self.avatarLoader(self.avatarView);
	}
}

@end

// vim:ft=objc
