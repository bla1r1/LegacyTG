//
// TGProfileHeaderView.m
//
#import "TGProfileHeaderView.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGIcons.h"
#import "TGNameWithStatus.h"
#import "TGLocalization.h"

NSString *const TGProfileHeaderName = @"name";
NSString *const TGProfileHeaderAvatar = @"avatar";
NSString *const TGProfileHeaderInitials = @"initials";
NSString *const TGProfileHeaderColourId = @"colourId";
NSString *const TGProfileHeaderEmojiStatusId = @"emojiStatusId";
NSString *const TGProfileHeaderVerified = @"verified";
NSString *const TGProfileHeaderStatus = @"status";
NSString *const TGProfileHeaderStatusColour = @"statusColour";
NSString *const TGProfileHeaderActions = @"actions";
NSString *const TGProfileHeaderActionTitle = @"title";
NSString *const TGProfileHeaderActionGlyph = @"glyph";
NSString *const TGProfileHeaderActionKey = @"key";
NSString *const TGProfileHeaderMusic = @"music";
NSString *const TGProfileHeaderMusicTitle = @"title";
NSString *const TGProfileHeaderMusicPerformer = @"performer";

// The header stacks a picture, a name and a status line, then the action
// plates. These named steps are the header's own; the values are the style
// scale the rest of the app uses.
static const CGFloat kHeaderAvatarTop = TGMetricPadLarge;
static const CGFloat kHeaderNameTop = TGMetricPad;
static const CGFloat kHeaderStatusTop = TGMetricPad + TGMetricLineTitle;
static const CGFloat kHeaderActionsTop = TGMetricPad + TGMetricLineTitle +
		TGMetricLineBody + TGMetricPadMedium;
static const CGFloat kHeaderTextInset = TGMetricPadMedium;
static const CGFloat kHeaderNameBadge = TGMetricLineCaption;
static const CGFloat kHeaderTileGap = 6.0f;
static const CGFloat kHeaderTileMargin = TGMetricPadMedium;
static const CGFloat kHeaderTileMaxWidth = 96.0f;
static const CGFloat kHeaderMusicInset = TGMetricPadMedium;
static const CGFloat kHeaderMusicTitleTop = TGMetricPadSmall;
static const CGFloat kHeaderMusicArtistTop = TGMetricPadSmall +
		TGMetricLineMicro;
static const CGFloat kHeaderMusicHeight = TGMetricRow;
static const CGFloat kHeaderMusicGlyph = TGMetricSearchIconSize;
static const CGFloat kHeaderMusicChevron = TGMetricGiftStar;

/// A 1 pt image of one colour, stretched by UIButton as its pressed background.
static UIImage *TGHeaderSolidImage(UIColor *colour) {
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), YES, 0);
	[colour setFill];
	UIRectFill(CGRectMake(0, 0, 1, 1));
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

@interface TGProfileHeaderView ()
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) NSArray *actions;
@property (nonatomic, strong) NSDictionary *music;
@end

@implementation TGProfileHeaderView

+ (CGFloat)heightForWidth:(CGFloat)width model:(NSDictionary *)model {
	(void)width;
	CGFloat side = TGMetricProfileAvatar;
	NSArray *actions = model[TGProfileHeaderActions];
	CGFloat actionsHeight = actions.count ? TGMetricActionTile : 0;
	CGFloat height = kHeaderAvatarTop + side + kHeaderActionsTop +
			actionsHeight + TGMetricPadMedium;
	NSDictionary *music = model[TGProfileHeaderMusic];
	if ([music isKindOfClass:NSDictionary.class])
		height += kHeaderMusicHeight + TGMetricPad;
	return height;
}

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;
	self.backgroundColor = [[TGTheme shared] groupedBackgroundColour];
	return self;
}

- (void)configureWithModel:(NSDictionary *)model {
	for (UIView *view in [self.subviews copy])
		[view removeFromSuperview];

	CGFloat width = self.bounds.size.width;
	CGFloat side = TGMetricProfileAvatar;
	TGTheme *theme = [TGTheme shared];
	self.actions = model[TGProfileHeaderActions];
	self.music = [model[TGProfileHeaderMusic] isKindOfClass:NSDictionary.class]
			? model[TGProfileHeaderMusic] : nil;

	_avatarView = [[UIImageView alloc] initWithFrame:
			CGRectMake(TGCenteredOrigin(width, side), kHeaderAvatarTop,
					side, side)];
	_avatarView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
			UIViewAutoresizingFlexibleRightMargin;
	_avatarView.contentMode = UIViewContentModeScaleAspectFill;
	_avatarView.opaque = NO;
	_avatarView.backgroundColor = [UIColor clearColor];
	_avatarView.userInteractionEnabled = YES;
	UIImage *avatar = model[TGProfileHeaderAvatar];
	if (![avatar isKindOfClass:UIImage.class]){
		NSString *initials = model[TGProfileHeaderInitials];
		avatar = [TGIcons avatarWithInitials:
				[initials isKindOfClass:NSString.class] ? initials : @""
				size:side colourId:[model[TGProfileHeaderColourId] longLongValue]];
	}
	_avatarView.image = avatar;
	UITapGestureRecognizer *avatarTap = [[UITapGestureRecognizer alloc]
			initWithTarget:self action:@selector(avatarTapped)];
	[_avatarView addGestureRecognizer:avatarTap];
	[self addSubview:_avatarView];

	NSString *name = model[TGProfileHeaderName] ?: @"";
	_nameLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(kHeaderTextInset, kHeaderAvatarTop + side + kHeaderNameTop,
					width - TGDoubled(kHeaderTextInset), TGMetricLineTitle)];
	_nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_nameLabel.font = TGFontTitle();
	_nameLabel.textAlignment = NSTextAlignmentCenter;
	_nameLabel.backgroundColor = [UIColor clearColor];
	_nameLabel.textColor = [theme primaryTextColour];
	_nameLabel.attributedText = TGNameWithStatus(name,
			[model[TGProfileHeaderEmojiStatusId] longLongValue], TGFontTitle(),
			[theme primaryTextColour]);
	[self addSubview:_nameLabel];

	CGFloat measuredNameW = [name sizeWithFont:TGFontTitle()].width;
	if (_nameLabel.attributedText.length > 0 &&
			[_nameLabel.attributedText respondsToSelector:
					@selector(boundingRectWithSize:options:context:)]){
		CGRect r = [_nameLabel.attributedText boundingRectWithSize:
				CGSizeMake(CGFLOAT_MAX, TGMetricLineTitle)
				options:NSStringDrawingUsesLineFragmentOrigin |
						NSStringDrawingUsesFontLeading
				context:nil];
		measuredNameW = ceilf(r.size.width);
	}
	CGFloat markX = TGHalf(width) + TGHalf(MIN(measuredNameW,
			_nameLabel.bounds.size.width)) + TGMetricPadSmall;
	CGFloat markY = kHeaderAvatarTop + side + kHeaderNameTop +
			TGCenteredOrigin(TGMetricLineTitle, kHeaderNameBadge);
	if ([model[TGProfileHeaderVerified] boolValue]){
		UIImageView *badge = [[UIImageView alloc] initWithFrame:
				CGRectMake(markX, markY, kHeaderNameBadge, kHeaderNameBadge)];
		badge.image = [TGIcons verifiedBadge];
		badge.contentMode = UIViewContentModeScaleAspectFit;
		[self addSubview:badge];
	}

	_statusLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(kHeaderTextInset, kHeaderAvatarTop + side + kHeaderStatusTop,
					width - TGDoubled(kHeaderTextInset), TGMetricLineBody)];
	_statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_statusLabel.font = TGFontSubhead();
	_statusLabel.textAlignment = NSTextAlignmentCenter;
	_statusLabel.backgroundColor = [UIColor clearColor];
	[self addSubview:_statusLabel];
	self.statusColour = model[TGProfileHeaderStatusColour] ?:
			[theme secondaryTextColour];
	self.statusText = model[TGProfileHeaderStatus];

	[self buildActionsAtY:(kHeaderAvatarTop + side + kHeaderActionsTop)];

	if (self.music){
		CGFloat musicY = kHeaderAvatarTop + side + kHeaderActionsTop +
				(self.actions.count ? TGMetricActionTile : 0) + TGMetricPad;
		[self buildMusicStripAtY:musicY width:width];
	}
}

- (void)buildActionsAtY:(CGFloat)y {
	if (!self.actions.count)
		return;
	CGFloat width = self.bounds.size.width;
	CGFloat tileW = (width - TGDoubled(kHeaderTileMargin) -
			kHeaderTileGap * (self.actions.count - 1)) /
			(CGFloat)MAX(self.actions.count, 1);
	if (tileW > kHeaderTileMaxWidth)
		tileW = kHeaderTileMaxWidth;
	CGFloat totalW = self.actions.count * tileW +
			(self.actions.count - 1) * kHeaderTileGap;
	CGFloat startX = TGCenteredOrigin(width, totalW);
	TGTheme *theme = [TGTheme shared];

	for (NSUInteger i = 0; i < self.actions.count; i++){
		NSDictionary *action = self.actions[i];
		UIButton *tile = [UIButton buttonWithType:UIButtonTypeCustom];
		tile.frame = CGRectMake(startX + i * (tileW + kHeaderTileGap), y,
				tileW, TGMetricActionTile);
		if ([TGTheme drawsSkeuomorphicChrome]){
			[tile setBackgroundImage:[TGTheme buttonImageForStyle:
					TGButtonStyleSecondary highlighted:NO
					height:TGMetricActionTile]
					forState:UIControlStateNormal];
			[tile setBackgroundImage:[TGTheme buttonImageForStyle:
					TGButtonStyleSecondary highlighted:YES
					height:TGMetricActionTile]
					forState:UIControlStateHighlighted];
			tile.backgroundColor = [UIColor clearColor];
		} else {
			tile.backgroundColor = [theme cardBackgroundColour];
			[tile setBackgroundImage:TGHeaderSolidImage(
					[theme groupedBackgroundColour])
					forState:UIControlStateHighlighted];
		}
		tile.layer.cornerRadius = TGMetricCornerControl;
		tile.clipsToBounds = YES;
		tile.tag = (NSInteger)i;
		[tile addTarget:self action:@selector(actionTapped:)
				forControlEvents:UIControlEventTouchUpInside];
		[self addSubview:tile];

		UIImageView *glyph = [[UIImageView alloc] initWithFrame:
				CGRectMake(TGCenteredOrigin(tileW, TGMetricMenuGlyph),
						TGMetricPad, TGMetricMenuGlyph, TGMetricMenuGlyph)];
		glyph.image = [TGIcons menuGlyphNamed:action[TGProfileHeaderActionGlyph]];
		glyph.contentMode = UIViewContentModeScaleAspectFit;
		[TGIcons tintImageView:glyph colour:[theme accentColour]];
		[tile addSubview:glyph];

		UILabel *label = [[UILabel alloc] initWithFrame:
				CGRectMake(0, TGMetricActionTile - TGMetricQuoteForwardLine,
						tileW, TGMetricLineMicro)];
		label.text = TGLocalized(action[TGProfileHeaderActionTitle] ?: @"");
		label.font = TGFontMicro();
		label.textAlignment = NSTextAlignmentCenter;
		label.textColor = [theme accentColour];
		label.backgroundColor = [UIColor clearColor];
		[tile addSubview:label];
	}
}

- (void)buildMusicStripAtY:(CGFloat)y width:(CGFloat)width {
	TGTheme *theme = [TGTheme shared];
	UIView *band = [[UIView alloc] initWithFrame:
			CGRectMake(kHeaderMusicInset, y,
					width - TGDoubled(kHeaderMusicInset), kHeaderMusicHeight)];
	band.backgroundColor = [theme cardBackgroundColour];
	band.layer.cornerRadius = TGMetricCornerControl;
	[self addSubview:band];

	UIImageView *glyph = [[UIImageView alloc] initWithFrame:
			CGRectMake(TGMetricPadMedium,
					TGCenteredOrigin(kHeaderMusicHeight, kHeaderMusicGlyph),
					kHeaderMusicGlyph, kHeaderMusicGlyph)];
	glyph.image = [TGIcons glyphNamed:@"music" colour:[theme accentColour]
								side:kHeaderMusicGlyph];
	glyph.contentMode = UIViewContentModeScaleAspectFit;
	[band addSubview:glyph];

	CGFloat textX = TGMetricPadMedium + kHeaderMusicGlyph + TGMetricPad;
	CGFloat textW = band.bounds.size.width - textX - TGMetricPadMedium -
			kHeaderMusicChevron - TGMetricPad;
	UILabel *title = [[UILabel alloc] initWithFrame:
			CGRectMake(textX, kHeaderMusicTitleTop, textW,
					TGMetricLineCaption)];
	title.font = TGFontMetaStrong();
	title.textColor = [theme accentColour];
	title.backgroundColor = [UIColor clearColor];
	title.lineBreakMode = NSLineBreakByTruncatingTail;
	title.text = self.music[TGProfileHeaderMusicTitle] ?: TGLocalized(@"Audio");
	[band addSubview:title];

	UILabel *artist = [[UILabel alloc] initWithFrame:
			CGRectMake(textX, kHeaderMusicArtistTop, textW,
					TGMetricLineCaption)];
	artist.font = TGFontMeta();
	artist.textColor = [theme secondaryTextColour];
	artist.backgroundColor = [UIColor clearColor];
	artist.lineBreakMode = NSLineBreakByTruncatingTail;
	artist.text = self.music[TGProfileHeaderMusicPerformer] ?:
			TGLocalized(@"Unknown artist");
	[band addSubview:artist];

	UIImageView *chevron = [[UIImageView alloc] initWithFrame:
			CGRectMake(band.bounds.size.width - TGMetricPadMedium -
					kHeaderMusicChevron,
					TGCenteredOrigin(kHeaderMusicHeight, kHeaderMusicChevron),
					kHeaderMusicChevron, kHeaderMusicChevron)];
	chevron.image = [TGIcons glyphNamed:@"forward"
			colour:[theme secondaryTextColour] side:kHeaderMusicChevron];
	chevron.contentMode = UIViewContentModeScaleAspectFit;
	[band addSubview:chevron];

	UIButton *tap = [UIButton buttonWithType:UIButtonTypeCustom];
	tap.frame = band.bounds;
	[tap addTarget:self action:@selector(musicTapped)
			forControlEvents:UIControlEventTouchUpInside];
	[band addSubview:tap];
}

- (void)setStatusText:(NSString *)statusText {
	_statusText = [statusText copy];
	self.statusLabel.text = _statusText;
}

- (void)setStatusColour:(UIColor *)statusColour {
	_statusColour = statusColour;
	self.statusLabel.textColor = statusColour ?:
			[[TGTheme shared] secondaryTextColour];
}

- (void)setAvatarImage:(UIImage *)avatarImage {
	_avatarImage = avatarImage;
	if ([avatarImage isKindOfClass:UIImage.class])
		self.avatarView.image = avatarImage;
}

- (void)avatarTapped {
	if (self.avatarTap)
		self.avatarTap();
}

- (void)actionTapped:(UIButton *)tile {
	if (tile.tag < 0 || tile.tag >= (NSInteger)self.actions.count)
		return;
	NSDictionary *action = self.actions[(NSUInteger)tile.tag];
	NSString *key = action[TGProfileHeaderActionKey];
	if (!key.length)
		key = [action[TGProfileHeaderActionTitle] lowercaseString];
	if (key.length && self.actionTap)
		self.actionTap(key);
}

- (void)musicTapped {
	if (self.musicTap)
		self.musicTap();
}

@end

// vim:ft=objc
