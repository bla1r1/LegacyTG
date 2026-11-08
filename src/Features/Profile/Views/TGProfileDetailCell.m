#import "TGProfileViewControllerInternal.h"
#import "TGClientInternal.h"
#import "TGNameWithStatus.h"
#import "TGCustomEmojiStore.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGMemberCell.h"
#import "TGGroupMemberActions.h"
#import "TGProfileAudioViewController.h"
#import "TGProfileTrackCell.h"
#import "TGMusicPlayer.h"
#import "TGChatViewController.h"
#import "TGSimilarChannelsViewController.h"
#import "TGDMTopicsViewController.h"
#import "UIImage+WebP.h"
#import <AVFoundation/AVFoundation.h>
#import "TGProfileDetailCell.h"
#import "TGProfileViewController.h"



/// Flattened messages carry a unix date, not a formatted stamp; the shared
/// lists want a short one beside each row.
/// A file's size as the row prints it. The file info sheet has its own copy;
/// this one is only the compact line under a name here.
static NSString *TGProfileFileSize(NSNumber *bytes) {
	long long value = [bytes longLongValue];
	if (value <= 0)
		return nil;
	if (value < 1024)
		return [NSString stringWithFormat:@"%lld B", value];
	if (value < 1024 * 1024)
		return [NSString stringWithFormat:@"%.0f KB", value / 1024.0];
	return [NSString stringWithFormat:@"%.1f MB", value / (1024.0 * 1024.0)];
}

static NSString *TGProfileDurationText(NSNumber *seconds) {
	NSInteger value = [seconds integerValue];
	if (value <= 0)
		return nil;
	return [NSString stringWithFormat:@"%ld:%02ld", (long)(value / 60), (long)(value % 60)];
}

static NSString *TGProfileShortDate(NSNumber *date) {
	if (![date isKindOfClass:NSNumber.class] || !date.doubleValue)
		return nil;
	static NSDateFormatter *formatter = nil;
	if (!formatter){
		formatter = [[NSDateFormatter alloc] init];
		formatter.dateStyle = NSDateFormatterMediumStyle;
		formatter.timeStyle = NSDateFormatterNoStyle;
	}
	return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:date.doubleValue]];
}

/// The gift glyph: the sticker's own emoji drawn large. Every gift cell
/// starts here, and the sticker thumbnail replaces the image once the
/// download lands - until then the row is never blank (B5).
static UIImage *TGGiftGlyph(NSString *emoji) {
	if (!emoji.length || ![TGCapabilities canDrawEmoji:emoji])
		return nil;
	static NSCache *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; });
	NSString *key = [emoji stringByAppendingFormat:@"@40"];
	UIImage *cached = [cache objectForKey:key];
	if (cached)
		return cached;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(kGiftTile, kGiftTile), NO, 0);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	[emoji drawInRect:CGRectMake(kGiftTileInset, kGiftTileInset,
								 kGiftTile - TGDoubled(kGiftTileInset),
								 kGiftTile - TGDoubled(kGiftTileInset))
			 withFont:TGFontEmoji()
		lineBreakMode:NSLineBreakByClipping
		   alignment:NSTextAlignmentCenter];
#pragma clang diagnostic pop
	UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	[cache setObject:img forKey:key];
	return img;
}

/// The bar under the selected tab, and the room a text row leaves at its sides.
static const CGFloat kMediaTabLine = 2.0f;
static NSString *TGProfileUserName(NSDictionary *user) {
	if (!user) return @"";
	NSString *first = user[@"first_name"] ?: @"";
	NSString *last = user[@"last_name"] ?: @"";
	if (first.length && last.length)
		return [NSString stringWithFormat:@"%@ %@", first, last];
	return first.length ? first : last;
}

static const CGFloat kDetailInset = TGMetricPadWide;

static const CGFloat kMusicStripInset = TGMetricPadMedium;
static const CGFloat kMusicTitleTop   = TGMetricPadSmall;
static const CGFloat kMusicArtistTop  = TGMetricPadSmall + TGMetricLineMicro;
static const CGFloat kMusicChevronSide = TGMetricGiftStar;

static const CGFloat kMinDetailTextWidth = TGMetricActionRow;
static const CGFloat kSimilarChannelsOverlapRatio = 2.0f / 3.0f;

static int64_t TGProfileChatIdFromItem(id item) {
	if ([item isKindOfClass:[NSDictionary class]]) {
		id rawId = item[@"id"];
		if ([rawId respondsToSelector:@selector(longLongValue)])
			return [rawId longLongValue];
	} else if ([item respondsToSelector:@selector(longLongValue)]) {
		return [item longLongValue];
	}
	return 0;
}

static NSString *TGProfileRowGlyphName(NSString *kind) {
	if (![kind isKindOfClass:[NSString class]])
		return nil;
	if ([kind isEqualToString:@"phone"])
		return @"call";
	if ([kind isEqualToString:@"username"])
		return @"mention";
	if ([kind isEqualToString:@"birthday"])
		return @"star";
	if ([kind isEqualToString:@"bio"] || [kind isEqualToString:@"about"] ||
		[kind isEqualToString:@"note"] || [kind isEqualToString:@"addBio"])
		return @"edit";
	if ([kind isEqualToString:@"channel"] || [kind isEqualToString:@"linkedChat"] ||
		[kind isEqualToString:@"community"] || [kind isEqualToString:@"similarChannels"] ||
		[kind isEqualToString:@"directMessages"])
		return @"chat";
	if ([kind isEqualToString:@"businessLocation"])
		return @"archive";
	if ([kind isEqualToString:@"invite"])
		return @"forward";
	if ([kind isEqualToString:@"addContact"])
		return @"contacts";
	if ([kind isEqualToString:@"warning"])
		return @"close";
	return nil;
}

/// Overlaps up to three avatars with CoreGraphics into a single bitmap.
/// Each circular face is clipped in the context, separated from its neighbour
/// by a ring cut into the prior face using cardBackgroundColour.
static UIImage *TGProfileCompositeSimilarAvatars(NSArray *images, UIColor *ringColour) {
	if (!images.count)
		return nil;
	CGFloat side = TGMetricMenuGlyph;
	CGFloat scale = [UIScreen mainScreen].scale;
	CGFloat shift = ceilf(side * kSimilarChannelsOverlapRatio);
	NSUInteger count = images.count;
	CGFloat totalWidth = (count == 1) ? side : (shift * (count - 1) + side);
	CGSize totalSize = CGSizeMake(totalWidth, side);

	UIGraphicsBeginImageContextWithOptions(totalSize, NO, scale);
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	CGFloat ringWidth = TGMetricBorderThick;
	if (!ringColour)
		ringColour = [[TGTheme shared] cardBackgroundColour];

	for (NSUInteger i = 0; i < count; i++) {
		CGFloat x = i * shift;
		CGRect avatarRect = CGRectMake(x, 0, side, side);

		if (i > 0) {
			CGContextSaveGState(ctx);
			CGFloat prevX = (i - 1) * shift;
			CGRect prevRect = CGRectMake(prevX, 0, side, side);
			UIBezierPath *prevAvatarClip = [UIBezierPath bezierPathWithOvalInRect:prevRect];
			[prevAvatarClip addClip];

			CGRect ringRect = CGRectInset(avatarRect, -ringWidth, -ringWidth);
			UIBezierPath *ringPath = [UIBezierPath bezierPathWithOvalInRect:ringRect];
			[ringColour setFill];
			[ringPath fill];
			CGContextRestoreGState(ctx);
		}

		CGContextSaveGState(ctx);
		UIBezierPath *clipPath = [UIBezierPath bezierPathWithOvalInRect:avatarRect];
		[clipPath addClip];

		UIImage *img = images[i];
		[img drawInRect:avatarRect];
		CGContextRestoreGState(ctx);
	}

	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return result;
}

static NSString *TGProfileTruncateToThreeLines(NSString *text, UIFont *font, CGFloat width, CGFloat maxH) {
	if (!text.length)
		return @"";
	CGSize fullSize = [text sizeWithFont:font constrainedToSize:CGSizeMake(width, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
	if (fullSize.height <= maxH + 1.0f)
		return text;

	NSString *moreSuffix = @"... more";
	NSUInteger low = 0;
	NSUInteger high = text.length;
	NSUInteger best = 0;
	while (low <= high) {
		NSUInteger mid = (low + high) / 2;
		NSString *cand = [NSString stringWithFormat:@"%@ %@", [text substringToIndex:mid], moreSuffix];
		CGSize sz = [cand sizeWithFont:font constrainedToSize:CGSizeMake(width, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
		if (sz.height <= maxH + 1.0f) {
			best = mid;
			low = mid + 1;
		} else {
			if (mid == 0) break;
			high = mid - 1;
		}
	}
	NSString *base = [text substringToIndex:best];
	NSRange lastSpace = [base rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] options:NSBackwardsSearch];
	if (lastSpace.location != NSNotFound && lastSpace.location > 0) {
		base = [base substringToIndex:lastSpace.location];
	}
	base = [base stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!base.length && best > 0)
		base = [text substringToIndex:best];
	return [NSString stringWithFormat:@"%@... more", base];
}



@implementation TGProfileDetailCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])){
		_iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
		_iconView.contentMode = UIViewContentModeScaleAspectFit;
		_iconView.backgroundColor = [UIColor clearColor];
		[self.contentView addSubview:_iconView];

		_titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_titleLabel.font = TGFontMeta();
		_titleLabel.backgroundColor = [UIColor clearColor];
		[self.contentView addSubview:_titleLabel];

		_subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_subtitleLabel.font = TGFontBody();
		_subtitleLabel.numberOfLines = 0;
		_subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
		_subtitleLabel.backgroundColor = [UIColor clearColor];
		[self.contentView addSubview:_subtitleLabel];

		_rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
		_rightButton.backgroundColor = [UIColor clearColor];
		[_rightButton addTarget:self action:@selector(rightButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
		_rightButton.hidden = YES;
		[self.contentView addSubview:_rightButton];
	}
	return self;
}

- (void)rightButtonTapped:(UIButton *)button {
	if (self.onRightButtonTapped)
		self.onRightButtonTapped();
}

- (void)prepareForReuse {
	[super prepareForReuse];
	_iconWidth = 0;
	_iconView.image = nil;
	_rowKind = nil;
	_rowChatId = 0;
	_rightButton.hidden = YES;
	_onRightButtonTapped = nil;
	_subtitleLabel.attributedText = nil;
	_subtitleLabel.text = nil;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat width = self.contentView.bounds.size.width;
	CGFloat left = TGMetricPadLarge;
	if (self.iconView.image) {
		CGFloat iconW = (self.iconWidth > 0) ? self.iconWidth : TGMetricMenuGlyph;
		self.iconView.frame = CGRectMake(left, TGMetricPadMedium, iconW, TGMetricMenuGlyph);
		left += iconW + TGMetricPadMedium;
	} else {
		self.iconView.frame = CGRectZero;
	}
	CGFloat rightMargin = TGMetricPadLarge;
	if (self.rightButton && !self.rightButton.hidden) {
		CGFloat btnSide = TGMetricMenuGlyph;
		self.rightButton.frame = CGRectMake(width - TGMetricPadLarge - btnSide,
				TGCenteredOrigin(self.contentView.bounds.size.height, btnSide),
				btnSide, btnSide);
		rightMargin = TGMetricPadLarge + btnSide + TGMetricPadMedium;
	} else if (self.accessoryType != UITableViewCellAccessoryNone) {
		rightMargin = TGMetricMenuGlyph + TGMetricPadMedium;
	}
	CGFloat textWidth = width - left - rightMargin;
	if (textWidth < kMinDetailTextWidth) textWidth = kMinDetailTextWidth;

	CGFloat y = TGMetricPadSmall;
	if (self.titleLabel.text.length) {
		CGFloat titleH = [self.rowKind isEqualToString:@"community"] ? TGMetricLineBody : TGMetricLineCaption;
		self.titleLabel.frame = CGRectMake(left, y, textWidth, titleH);
		y += titleH + TGMetricPadTiny;
	} else {
		self.titleLabel.frame = CGRectZero;
	}

	CGSize valSize = [self.subtitleLabel.text sizeWithFont:self.subtitleLabel.font
										constrainedToSize:CGSizeMake(textWidth, CGFLOAT_MAX)
											lineBreakMode:NSLineBreakByWordWrapping];
	self.subtitleLabel.frame = CGRectMake(left, y, textWidth, ceilf(valSize.height));
}

@end
