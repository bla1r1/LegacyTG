//
// TGPeerRowCell.m
//
#import "TGPeerRowCell.h"
#import "TGRows.h"
#import "TGBadge.h"
#import "TGIcons.h"
#import "TGPeerStore.h"
#import "TGNameWithStatus.h"
#import "TGStyle.h"
#import "TGTheme.h"
#import <math.h>

static void TGPeerRowAppendVerified(NSMutableAttributedString *name, UIFont *font);

@interface TGPeerRowCell ()
@property (nonatomic, strong) UIImageView *faceView;
@property (nonatomic, strong) UIImageView *pinView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *trailingLabel;
@property (nonatomic, strong) UIImageView *checkView;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) UISwitch *toggleSwitch;
@property (nonatomic, strong) TGBadge *badgeView;
@property (nonatomic, strong) NSDictionary *row;
@property (nonatomic, assign) int64_t avatarPeer;
@property (nonatomic, copy) void (^switchToggleBlock)(BOOL);
@property (nonatomic, weak) UITableView *ownerTable;
@end

@implementation TGPeerRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	(void)tableView;
	NSNumber *height = row[TGRowHeight];
	return height ? [height doubleValue] : TGMetricPersonRow;
}

+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row {
	static NSString *reuse = @"TGPeerRowCell";
	TGPeerRowCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGPeerRowCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];
	[cell configureWithRow:row inTable:tableView];
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

	_pinView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_pinView.contentMode = UIViewContentModeScaleAspectFit;
	_pinView.hidden = YES;
	[self.contentView addSubview:_pinView];

	_nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_nameLabel.font = TGFontRow();
	_nameLabel.backgroundColor = [UIColor clearColor];
	_nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	_nameLabel.numberOfLines = 1;
	[self.contentView addSubview:_nameLabel];

	_subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_subtitleLabel.font = TGFontCaption();
	_subtitleLabel.backgroundColor = [UIColor clearColor];
	_subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	_subtitleLabel.numberOfLines = 1;
	[self.contentView addSubview:_subtitleLabel];

	_trailingLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_trailingLabel.font = TGFontCaption();
	_trailingLabel.textAlignment = NSTextAlignmentRight;
	_trailingLabel.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:_trailingLabel];

	_checkView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_checkView.contentMode = UIViewContentModeCenter;
	_checkView.hidden = YES;
	[self.contentView addSubview:_checkView];

	_chevronView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_chevronView.contentMode = UIViewContentModeCenter;
	_chevronView.hidden = YES;
	[self.contentView addSubview:_chevronView];

	_toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
	_toggleSwitch.hidden = YES;
	[_toggleSwitch addTarget:self action:@selector(toggleChanged:)
			forControlEvents:UIControlEventValueChanged];
	[self.contentView addSubview:_toggleSwitch];

	_badgeView = [TGBadge badgeWithCount:0];
	_badgeView.hidden = YES;
	[self.contentView addSubview:_badgeView];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.row = nil;
	self.ownerTable = nil;
	self.switchToggleBlock = nil;
	self.avatarPeer = 0;
	self.faceView.image = nil;
	self.pinView.hidden = YES;
	self.checkView.hidden = YES;
	self.chevronView.hidden = YES;
	self.toggleSwitch.hidden = YES;
	self.badgeView.hidden = YES;
	self.trailingLabel.text = nil;
	self.subtitleLabel.text = nil;
	self.nameLabel.attributedText = nil;
	self.accessoryView = nil;
	self.accessoryType = UITableViewCellAccessoryNone;
	self.selectionStyle = UITableViewCellSelectionStyleDefault;
	[self applyTheme];
}

#pragma mark - configuration

- (void)configureWithRow:(NSDictionary *)row inTable:(UITableView *)tableView {
	self.row = row;
	self.ownerTable = tableView;

	TGTheme *theme = [TGTheme shared];
	[theme styleCell:self];
	self.accessoryView = nil;
	self.accessoryType = UITableViewCellAccessoryNone;
	self.selectionStyle = row[TGRowTap] ? UITableViewCellSelectionStyleDefault
			: UITableViewCellSelectionStyleNone;

	NSString *title = row[TGRowTitle] ?: @"";
	UIColor *titleColour = row[TGRowTitleColour] ?: [theme primaryTextColour];
	int64_t statusEmojiId = [row[TGRowStatusEmojiId] longLongValue];
	NSMutableAttributedString *name = [TGNameWithStatus(title, statusEmojiId,
			TGFontRow(), titleColour) mutableCopy];
	if ([row[TGRowVerified] boolValue])
		TGPeerRowAppendVerified(name, TGFontRow());
	self.nameLabel.attributedText = name;
	self.nameLabel.font = TGFontRow();

	NSString *subtitle = row[TGRowDetail];
	if (![subtitle isKindOfClass:NSString.class])
		subtitle = nil;
	self.subtitleLabel.hidden = (subtitle.length == 0);
	self.subtitleLabel.text = subtitle;
	self.subtitleLabel.textColor = TGPeerRowSubtitleColour(
			[row[TGRowOnline] boolValue], [theme accentColour],
			[theme secondaryTextColour]);

	self.pinView.hidden = ![row[TGRowPin] boolValue];
	self.pinView.image = self.pinView.hidden ? nil
			: [TGIcons glyphNamed:@"pin" colour:[theme secondaryTextColour]
							side:TGMetricLineCaption];

	[self configureAccessory:row theme:theme];
	[self configureBadge:row theme:theme];
	[self configureAvatar:row];
	[self setNeedsLayout];
}

- (void)configureAccessory:(NSDictionary *)row theme:(TGTheme *)theme {
	NSString *accessory = row[TGRowAccessory];
	self.checkView.hidden = YES;
	self.chevronView.hidden = YES;
	self.toggleSwitch.hidden = YES;
	self.trailingLabel.text = nil;
	self.switchToggleBlock = nil;

	BOOL check = [accessory isEqualToString:TGRowAccessoryCheck];
	if (!accessory && row[TGRowChecked] != nil)
		check = YES;
	if (check){
		self.checkView.hidden = NO;
		self.checkView.image = [TGIcons selectionCheckboxSelected:
				[row[TGRowChecked] boolValue]];
		return;
	}
	if ([accessory isEqualToString:TGRowAccessoryDisclosure]){
		self.chevronView.hidden = NO;
		self.chevronView.image = [TGIcons skeuomorphicDisclosureChevron];
		return;
	}
	if ([accessory isEqualToString:TGRowAccessorySwitch]){
		self.toggleSwitch.hidden = NO;
		self.switchToggleBlock = row[TGRowToggle];
		[self.toggleSwitch setOn:[row[TGRowOn] boolValue] animated:NO];
		return;
	}
	if (accessory.length){
		self.trailingLabel.text = accessory;
		self.trailingLabel.textColor = [theme secondaryTextColour];
	}
}

- (void)configureBadge:(NSDictionary *)row theme:(TGTheme *)theme {
	id badge = row[TGRowBadge];
	(void)theme;
	if ([badge isKindOfClass:NSNumber.class]){
		self.badgeView.count = [badge integerValue];
	} else if ([badge isKindOfClass:NSString.class] && [badge length]){
		self.badgeView.text = badge;
	} else {
		self.badgeView.text = nil;
	}
	NSNumber *variant = row[TGRowBadgeVariant];
	self.badgeView.variant = variant
			? (TGBadgeVariant)[variant integerValue]
			: TGBadgeVariantNotification;
}

- (void)configureAvatar:(NSDictionary *)row {
	self.faceView.image = nil;
	int64_t peer = [row[TGRowPeerId] longLongValue];
	UIImage *given = row[TGRowAvatarImage];
	if ([given isKindOfClass:UIImage.class]){
		self.avatarPeer = peer;
		[self setFaceImage:given];
		return;
	}

	NSString *title = row[TGRowTitle] ?: @"";
	// A user row says so explicitly; a group or channel is its negative chat
	// id. Both have a picture now, not only the people.
	BOOL wantsPicture = [row[TGRowAvatarUser] boolValue] || peer < 0;
	if (peer != 0 && wantsPicture){
		UIImage *cached = [[TGPeerStore shared]
				cachedAvatarForPeer:peer side:TGMetricListAvatar];
		if (cached){
			self.avatarPeer = peer;
			[self setFaceImage:cached];
			return;
		}
		NSString *initials = [TGIcons initialsForTitle:title];
		self.faceView.image = [TGIcons avatarWithInitials:
				initials.length ? initials : @"?"
				size:TGMetricListAvatar colourId:peer];
		if (self.avatarPeer == peer)
			return;
		self.avatarPeer = peer;

		__weak typeof(self) weakSelf = self;
		__weak UITableView *weakTable = self.ownerTable;
		[[TGPeerStore shared] loadAvatarForPeer:peer
				side:TGMetricListAvatar completion:^(UIImage *image){
			if (!image)
				return;
			TGPeerRowCell *cell = weakSelf;
			UITableView *table = weakTable;
			if (!cell || !table || cell.avatarPeer != peer)
				return;
			[cell setFaceImage:image];
			NSIndexPath *path = [table indexPathForCell:cell];
			if (path)
				[table reloadRowsAtIndexPaths:@[path]
							 withRowAnimation:UITableViewRowAnimationNone];
		}];
		return;
	}

	self.avatarPeer = peer;
	NSString *initials = [TGIcons initialsForTitle:title];
	self.faceView.image = [TGIcons avatarWithInitials:
			initials.length ? initials : @"?"
			size:TGMetricListAvatar colourId:peer];
}

- (void)setFaceImage:(UIImage *)image {
	CGSize side = CGSizeMake(TGMetricListAvatar, TGMetricListAvatar);
	self.faceView.image = [TGIcons roundedImage:image size:side
			radius:TGHalf(TGMetricListAvatar) corners:UIRectCornerAllCorners];
}

- (void)applyTheme {
	if (!self.row)
		return;
	[self configureWithRow:self.row inTable:self.ownerTable];
}

- (void)toggleChanged:(UISwitch *)sender {
	void (^changed)(BOOL) = self.switchToggleBlock;
	if (changed)
		changed(sender.on);
}

#pragma mark - layout

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
	CGFloat titleX = x;
	if (!self.pinView.hidden){
		self.pinView.frame = CGRectMake(x,
				TGCenteredOrigin(height, TGMetricLineCaption),
				TGMetricLineCaption, TGMetricLineCaption);
		titleX = CGRectGetMaxX(self.pinView.frame) + TGMetricPadSmall;
	}

	CGFloat accessoryWidth = 0;
	if (!self.checkView.hidden)
		accessoryWidth = MAX(accessoryWidth, TGMetricMenuGlyph);
	if (!self.chevronView.hidden)
		accessoryWidth = MAX(accessoryWidth, TGMetricMenuGlyph);
	if (!self.toggleSwitch.hidden)
		accessoryWidth = MAX(accessoryWidth, self.toggleSwitch.bounds.size.width);
	if (self.trailingLabel.text.length){
		CGSize size = [self.trailingLabel sizeThatFits:
				CGSizeMake(TGMetricCallLabelWidth, TGMetricLineCaption)];
		accessoryWidth = MAX(accessoryWidth, size.width);
	}
	BOOL inlineBadge = [self.row[TGRowBadgeInline] boolValue];
	if (!self.badgeView.hidden && !inlineBadge){
		CGSize size = [self.badgeView sizeThatFits:CGSizeZero];
		accessoryWidth = MAX(accessoryWidth, size.width);
	}

	CGFloat textRight = right - (accessoryWidth > 0
			? accessoryWidth + TGMetricPadSmall : 0);
	CGFloat textWidth = MAX(0, textRight - titleX);
	CGFloat nameHeight = TGMetricLineRow;
	BOOL hasSubtitle = !self.subtitleLabel.hidden;
	CGFloat subtitleHeight = hasSubtitle ? TGMetricLineCaption : 0;
	CGFloat gap = hasSubtitle ? TGMetricPadTiny : 0;
	CGFloat total = nameHeight + gap + subtitleHeight;
	CGFloat top = TGCenteredOrigin(height, total);

	self.nameLabel.frame = CGRectMake(titleX, top, textWidth, nameHeight);
	if (hasSubtitle){
		self.subtitleLabel.frame = CGRectMake(x, top + nameHeight + gap,
				textWidth, subtitleHeight);
	}

	if (!self.checkView.hidden){
		CGFloat side = TGMetricMenuGlyph;
		self.checkView.frame = CGRectMake(right - side,
				TGCenteredOrigin(height, side), side, side);
	}
	if (!self.chevronView.hidden){
		CGFloat side = TGMetricMenuGlyph;
		self.chevronView.frame = CGRectMake(right - side,
				TGCenteredOrigin(height, side), side, side);
	}
	if (!self.toggleSwitch.hidden){
		CGSize size = self.toggleSwitch.bounds.size;
		self.toggleSwitch.frame = CGRectMake(right - size.width,
				TGCenteredOrigin(height, size.height), size.width, size.height);
	}
	if (self.trailingLabel.text.length){
		CGSize size = [self.trailingLabel sizeThatFits:
				CGSizeMake(TGMetricCallLabelWidth, TGMetricLineCaption)];
		self.trailingLabel.frame = CGRectMake(right - size.width, top,
				size.width, TGMetricLineCaption);
	}

	if (!self.badgeView.hidden){
		CGSize size = [self.badgeView sizeThatFits:CGSizeZero];
		if (inlineBadge){
			CGSize nameSize = [self.nameLabel sizeThatFits:
					CGSizeMake(textWidth, nameHeight)];
			CGFloat badgeX = MIN(titleX + ceilf(nameSize.width) + TGMetricPadSmall,
					right - size.width);
			self.badgeView.frame = CGRectMake(badgeX,
					TGCenteredOrigin(height, size.height), size.width, size.height);
		} else {
			CGFloat badgeY = self.trailingLabel.text.length
					? CGRectGetMaxY(self.trailingLabel.frame) + TGMetricPadTiny
					: TGCenteredOrigin(height, size.height);
			self.badgeView.frame = CGRectMake(right - size.width, badgeY,
					size.width, size.height);
		}
	}
}

@end

/// The verified tick follows the name as an attachment, the same way an emoji
/// status does. iOS 6 has no NSTextAttachment, so the name stays readable and
/// the tick is simply absent there.
static void TGPeerRowAppendVerified(NSMutableAttributedString *name, UIFont *font) {
	Class attachmentClass = NSClassFromString(@"NSTextAttachment");
	// iOS 6 has a private NSTextAttachment without -setBounds:, so the name
	// stays readable and the tick is simply absent there.
	if (!attachmentClass || !name ||
		![attachmentClass instancesRespondToSelector:@selector(setBounds:)])
		return;
	UIImage *badge = [TGIcons verifiedBadge];
	if (!badge)
		return;
	id attachment = [[attachmentClass alloc] init];
	if ([attachment respondsToSelector:@selector(setImage:)])
		[attachment setImage:badge];
	if ([attachment respondsToSelector:@selector(setBounds:)]){
		CGFloat side = ceilf(font.lineHeight);
		[attachment setBounds:CGRectMake(TGMetricZero, roundf(font.descender),
				side, side)];
	}
	NSAttributedString *space = [[NSAttributedString alloc] initWithString:@" "
			attributes:@{NSFontAttributeName : font}];
	[name appendAttributedString:space];
	if ([NSAttributedString respondsToSelector:
			@selector(attributedStringWithAttachment:)]){
		NSAttributedString *mark = [NSAttributedString
				attributedStringWithAttachment:attachment];
		if (mark)
			[name appendAttributedString:mark];
	}
}
