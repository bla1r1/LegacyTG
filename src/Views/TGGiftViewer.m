//
// TGGiftViewer.m - the gift detail sheet.
//
#import "TGTextDraw.h"
#import "TGGiftViewer.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGMediaStore.h"
#import "TGCapabilities.h"
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"

static const CGFloat kSide       = TGMetricPadLarge;   ///< card side margin, as TGAttachSheet pads its rows
static const CGFloat kRow        = TGMetricRow;
static const CGFloat kButton     = TGMetricButtonHeight;
static const CGFloat kClose      = TGMetricCloseSide;
static const CGFloat kAvatar     = TGMetricGiftAvatar;
static const CGFloat kStar       = TGMetricGiftStar;
static const CGFloat kCloseGlyph = 16.0f;   ///< the cross inside kClose
/// The caption column on the left of a row, and the gap between a value and
/// the face or star that sits in front of it.
static const CGFloat kCaptionW   = 100.0f;
static const CGFloat kValueGap   = 6.0f;
static const CGFloat kStarGap    = TGMetricPadSmall;
/// A value's own line, which is set against the middle of its row.
static const CGFloat kValueLine  = TGMetricLineRow;
/// The heading, which is one line of title type set a little tight.
static const CGFloat kTitleLine  = 24.0f;
/// The note a gift may carry, padded as a service plate is.
static const CGFloat kNotePadH   = TGMetricPadMedium + TGMetricPadTiny;
static const CGFloat kNotePadV   = TGMetricPadMedium;
static const CGFloat kTopMargin  = TGMetricPadMedium;
static const CGFloat kGapSmall   = TGMetricPadTiny;
static const CGFloat kGapMedium  = TGMetricPadMedium;
static const CGFloat kGapLarge   = TGMetricPadLarge;

// Both of these used to pick with respondsToSelector:, which lies on 6.1.6 -
// see TGTextDraw.h.
static CGSize TGGiftTextSize(NSString *text, UIFont *font) {
	return TGLineTextSize(text, font);
}

static CGFloat TGGiftTextHeight(NSString *text, UIFont *font, CGFloat width) {
	return TGTextHeight(text, font, width);
}

static UIImage *TGGiftArtworkGlyph(NSString *emoji, CGFloat side) {
	if (!emoji.length || ![TGCapabilities canDrawEmoji:emoji])
		return nil;
	static NSCache *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [[NSCache alloc] init];
	});
	NSString *key = [emoji stringByAppendingFormat:@"@%g", side];
	UIImage *cached = [cache objectForKey:key];
	if (cached)
		return cached;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	CGFloat inset = side * TGMetricEmojiArtworkInsetRatio;
	CGFloat emojiSize = side * TGMetricEmojiArtworkSizeRatio;
	[emoji drawInRect:CGRectMake(inset, inset, emojiSize, emojiSize)
			 withFont:TGFontBoldAtSize(side - inset * TGMetricEmojiArtworkFontInsetRatio)
		lineBreakMode:NSLineBreakByClipping
		   alignment:NSTextAlignmentCenter];
#pragma clang diagnostic pop
	UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (img)
		[cache setObject:img forKey:key];
	return img;
}

static UIImage *TGGiftCollectibleBackdrop(int32_t centerColor, int32_t edgeColor, CGFloat side) {
	static NSCache *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [[NSCache alloc] init];
	});
	NSString *key = [NSString stringWithFormat:@"%x-%x@%g", centerColor, edgeColor, side];
	UIImage *cached = [cache objectForKey:key];
	if (cached)
		return cached;

	static const CGFloat kRGBDivisor = 255.0f;
	CGFloat rC = ((centerColor >> 16) & 0xFF) / kRGBDivisor;
	CGFloat gC = ((centerColor >> 8)  & 0xFF) / kRGBDivisor;
	CGFloat bC = ( centerColor        & 0xFF) / kRGBDivisor;

	CGFloat rE = ((edgeColor >> 16) & 0xFF) / kRGBDivisor;
	CGFloat gE = ((edgeColor >> 8)  & 0xFF) / kRGBDivisor;
	CGFloat bE = ( edgeColor        & 0xFF) / kRGBDivisor;

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGFloat components[8] = {
		rC, gC, bC, 1.0f,
		rE, gE, bE, 1.0f
	};
	CGFloat locations[2] = { 0.0f, 1.0f };
	CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), YES, [UIScreen mainScreen].scale);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGPoint center = CGPointMake(TGHalf(side), TGHalf(side));
	CGFloat radius = side;
	CGContextDrawRadialGradient(ctx, gradient, center, 0, center, radius, kCGGradientDrawsAfterEndLocation);
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	CGGradientRelease(gradient);
	CGColorSpaceRelease(colorSpace);

	if (image)
		[cache setObject:image forKey:key];
	return image;
}

static NSString *TGGiftStamp(NSNumber *unix) {
	if (![unix isKindOfClass:NSNumber.class] || unix.doubleValue <= 0)
		return @"";
	static NSDateFormatter *fmt = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		// "27.01.26, 23:05" - the stamp the gift table reads.
		fmt = [[NSDateFormatter alloc] init];
		fmt.dateFormat = @"dd.MM.yy, HH:mm";
	});
	return [fmt stringFromDate:[NSDate dateWithTimeIntervalSince1970:unix.doubleValue]];
}

@interface TGGiftViewer ()
- (void)addTableAtY:(CGFloat)tableY
			  width:(CGFloat)width
			   gift:(NSDictionary *)gift
			  stars:(NSInteger)stars
	  isCollectible:(BOOL)isCollectible;
- (UILabel *)addRightLabel:(NSString *)text
						at:(CGPoint)rightCentre
					  bold:(BOOL)bold
					colour:(UIColor *)colour;
- (void)addFromRowAtY:(CGFloat)y right:(CGFloat)right gift:(NSDictionary *)gift;
@end

@implementation TGGiftViewer {
	UIView *_card;
}

+ (void)dismiss {
	[TGSheet dismissOpen];
}

+ (void)showGift:(NSDictionary *)gift inView:(UIView *)host {
	if (!gift || !host)
		return;
	TGGiftViewer *viewer = [TGGiftViewer sheetForView:host];
	[viewer buildWithGift:gift];
	[viewer present];
}

- (void)buildWithGift:(NSDictionary *)gift {
	TGTheme *theme = [TGTheme shared];
	CGFloat width = self.bounds.size.width ?: TGMetricScreenWidth;
	CGFloat inner = width - TGDoubled(kSide);

	BOOL isCollectible = [gift[@"isCollectible"] boolValue];
	NSString *emoji = gift[@"emoji"] ?: @"";
	NSString *note = [gift[@"note"] isKindOfClass:[NSString class]] && [gift[@"note"] length] > 0
			? gift[@"note"]
			: ([gift[@"message"] isKindOfClass:[NSString class]] ? gift[@"message"] : @"");
	NSInteger stars = MAX(0, [gift[@"starCount"] integerValue]);

	// Heights first: the card is as tall as its contents, the way the
	// official sheet grows for a gift that carries a note.
	UIFont *messageFont = TGFontBody();
	CGFloat artSide = floorf(MIN(TGMetricGiftArtMaxSide, inner * TGMetricGiftArtRatio));
	CGFloat messageH = note.length
			? TGGiftTextHeight(note, messageFont, inner - TGDoubled(kNotePadH)) + TGDoubled(kNotePadV) : 0;

	NSInteger rowCount = isCollectible ? 5 : 3;
	CGFloat y = kTopMargin;
	CGFloat artY = y + kClose + kGapSmall;
	CGFloat titleY = artY + artSide + kGapMedium;
	CGFloat tableY = titleY + kTitleLine + kGapMedium;
	CGFloat messageY = tableY + kRow * rowCount + (note.length ? kGapMedium : 0);
	CGFloat okY = messageY + messageH + kGapLarge;
	CGFloat cardHeight = okY + kButton + kGapLarge;

	_card = [self addCardOfHeight:cardHeight edgeToEdge:YES];

	UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
	close.frame = CGRectMake(kSide, y, kClose, kClose);
	close.layer.cornerRadius = TGHalf(kClose);
	close.layer.masksToBounds = YES;
	close.backgroundColor = [theme fileTileColour];
	[close setImage:[TGIcons glyphNamed:@"close"
								 colour:[[TGTheme shared] secondaryTextColour]
								   side:kCloseGlyph]
		   forState:UIControlStateNormal];
	[close setTitleColor:[theme secondaryTextColour] forState:UIControlStateNormal];
	[close setTitleColor:[theme placeholderColour] forState:UIControlStateHighlighted];
	close.titleLabel.font = TGFontBody();
	[close addTarget:self action:@selector(dismiss)
		  forControlEvents:UIControlEventTouchUpInside];
	[_card addSubview:close];

	CGRect artFrame = CGRectMake(TGCenteredOrigin(width, artSide), artY, artSide, artSide);
	if (isCollectible) {
		int32_t centerColor = [gift[@"backdropCenterColor"] intValue];
		int32_t edgeColor = [gift[@"backdropEdgeColor"] intValue];
		UIImageView *bg = [[UIImageView alloc] initWithFrame:artFrame];
		bg.image = TGGiftCollectibleBackdrop(centerColor, edgeColor, artSide);
		bg.layer.cornerRadius = TGMetricCornerCard;
		bg.layer.masksToBounds = YES;
		[_card addSubview:bg];
	}

	UIImageView *art = [[UIImageView alloc] initWithFrame:artFrame];
	art.contentMode = UIViewContentModeScaleAspectFit;
	if (!isCollectible) {
		art.image = TGGiftArtworkGlyph(emoji, artSide);
	}
	art.clipsToBounds = YES;
	[_card addSubview:art];

	NSNumber *thumbId = isCollectible ? gift[@"modelThumbFileId"] : gift[@"thumbFileId"];
	if ([thumbId isKindOfClass:NSNumber.class] && thumbId.integerValue > 0){
		[[TGMediaStore shared] downloadFile:thumbId.integerValue
							   completion:^(NSString *path){
			if (!path.length)
				return;
			dispatch_async(dispatch_get_global_queue(
					DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
				UIImage *photo = [TGIcons decodedImage:
						[UIImage imageWithContentsOfFile:path]
						fittingSize:CGSizeMake(artSide, artSide)
						fill:NO scale:[UIScreen mainScreen].scale];
				if (!photo)
					return;
				dispatch_async(dispatch_get_main_queue(), ^{
					if (art.superview)
						art.image = photo;
				});
			});
		}];
	}

	UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(
			kSide, titleY, inner, kTitleLine)];
	if (isCollectible) {
		NSString *title = gift[@"title"] ?: @"";
		NSInteger number = [gift[@"number"] integerValue];
		titleLabel.text = title.length
				? [NSString stringWithFormat:@"%@ #%ld", title, (long)number]
				: [NSString stringWithFormat:@"#%ld", (long)number];
	} else {
		titleLabel.text = @"Gift";
	}
	titleLabel.font = TGFontTitle();
	titleLabel.textColor = [theme primaryTextColour];
	titleLabel.textAlignment = NSTextAlignmentCenter;
	titleLabel.backgroundColor = [UIColor clearColor];
	[_card addSubview:titleLabel];

	[self addTableAtY:tableY width:width gift:gift stars:stars isCollectible:isCollectible];

	if (note.length){
		// A note comes with the gift the way a service plate carries text
		// in a chat: the same colours, so a theme reaches it too.
		UIView *noteBubble = [[UIView alloc] initWithFrame:CGRectMake(
				kSide, messageY, inner, messageH)];
		noteBubble.backgroundColor = [theme serviceBubbleColour];
		noteBubble.layer.cornerRadius = TGMetricCornerCard;
		noteBubble.layer.masksToBounds = YES;
		[_card addSubview:noteBubble];

		UILabel *text = [[UILabel alloc] initWithFrame:CGRectMake(
				kNotePadH, kNotePadV, inner - TGDoubled(kNotePadH),
				messageH - TGDoubled(kNotePadV))];
		text.text = note;
		text.font = messageFont;
		text.textColor = [theme serviceTextColour];
		text.numberOfLines = 0;
		text.textAlignment = NSTextAlignmentCenter;
		text.backgroundColor = [UIColor clearColor];
		[noteBubble addSubview:text];
	}

	UIButton *ok = [UIButton buttonWithType:UIButtonTypeCustom];
	ok.frame = CGRectMake(kSide, okY, inner, kButton);
	ok.backgroundColor = [theme accentColour];
	ok.layer.cornerRadius = TGMetricCornerCard;
	ok.layer.masksToBounds = YES;
	[ok setTitle:@"OK" forState:UIControlStateNormal];
	ok.titleLabel.font = TGFontHeader();
	[ok setTitleColor:[[TGTheme shared] onAccentColour] forState:UIControlStateNormal];
	[ok addTarget:self action:@selector(dismiss)
		  forControlEvents:UIControlEventTouchUpInside];
	[_card addSubview:ok];
}

/// Rows are read as settings rows do: the caption grey on the left, the value
/// on the right, a hairline between them. Regular gifts show From / Date / Value;
/// collectibles show From / Date / Model / Symbol / Backdrop.
- (void)addTableAtY:(CGFloat)tableY
			  width:(CGFloat)width
			   gift:(NSDictionary *)gift
			  stars:(NSInteger)stars
	  isCollectible:(BOOL)isCollectible {
	TGTheme *theme = [TGTheme shared];
	CGFloat inner = width - TGDoubled(kSide);
	NSArray *labels = isCollectible
			? @[@"From", @"Date", @"Model", @"Symbol", @"Backdrop"]
			: @[@"From", @"Date", @"Value"];

	for (NSInteger i = 0; i < (NSInteger)labels.count; i++){
		CGFloat y = tableY + kRow * i;

		UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(
				kSide, y, kCaptionW, kRow)];
		name.text = labels[i];
		name.font = TGFontBody();
		name.textColor = [theme secondaryTextColour];
		name.backgroundColor = [UIColor clearColor];
		[_card addSubview:name];

		if (i > 0){
			UIView *hair = [[UIView alloc] initWithFrame:CGRectMake(
					kSide, y - TGMetricHairline, inner, TGMetricHairline)];
			hair.backgroundColor = [theme separatorColour];
			[_card addSubview:hair];
		}

		// The value hugs the right edge; its width is whatever the text needs.
		CGFloat right = width - kSide;
		if (i == 0){
			[self addFromRowAtY:y right:right gift:gift];
		} else if (i == 1){
			[self addRightLabel:TGGiftStamp(gift[@"date"])
							 at:CGPointMake(right, y + TGHalf(kRow))
						   bold:NO
						 colour:[theme primaryTextColour]];
		} else if (isCollectible){
			NSString *val = @"";
			if (i == 2)
				val = gift[@"modelName"] ?: @"";
			else if (i == 3)
				val = gift[@"symbolName"] ?: @"";
			else if (i == 4)
				val = gift[@"backdropName"] ?: @"";
			[self addRightLabel:val
							 at:CGPointMake(right, y + TGHalf(kRow))
						   bold:YES
						 colour:[theme primaryTextColour]];
		} else {
			UIFont *font = TGFontBodyStrong();
			NSString *count = [NSString stringWithFormat:@"%ld", (long)stars];
			CGFloat countW = ceilf(TGGiftTextSize(count, font).width);
			[self addRightLabel:count
							 at:CGPointMake(right, y + TGHalf(kRow))
						   bold:YES
						 colour:[theme primaryTextColour]];
			// Telegram Stars are gold wherever they appear, theme or not.
			UIImageView *star = [[UIImageView alloc] initWithFrame:CGRectMake(
					right - countW - kStarGap - kStar, y + TGCenteredOrigin(kRow, kStar),
					kStar, kStar)];
			star.image = [TGIcons glyphNamed:@"star"
									  colour:[[TGTheme shared] giftStarColour]
										side:kStar];
			[_card addSubview:star];
		}
	}
}

- (UILabel *)addRightLabel:(NSString *)text
						at:(CGPoint)rightCentre
					  bold:(BOOL)bold
					colour:(UIColor *)colour {
	UIFont *font = bold ? TGFontBodyStrong()
						: TGFontBody();
	CGFloat w = ceilf(TGGiftTextSize(text, font).width) + 1;
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(
			rightCentre.x - w, rightCentre.y - TGHalf(kValueLine), w, kValueLine)];
	label.text = text;
	label.font = font;
	label.textColor = colour;
	label.textAlignment = NSTextAlignmentRight;
	label.backgroundColor = [UIColor clearColor];
	[_card addSubview:label];
	return label;
}

/// The sender rides the right of the From row: their face beside their name
/// in the accent colour, the face downloaded like every other avatar here.
- (void)addFromRowAtY:(CGFloat)y right:(CGFloat)right gift:(NSDictionary *)gift {
	BOOL isPrivate = [gift[@"isPrivate"] boolValue];
	NSInteger userId = [gift[@"senderUserId"] longLongValue];
	NSString *name = nil;
	if (isPrivate)
		name = @"Anonymous";
	else if (userId > 0)
		name = [[TGMediaStore shared] nameForUserId:userId];
	if (!name.length)
		name = isPrivate ? @"Anonymous" : @"Unknown";

	UIFont *font = TGFontBodyStrong();
	CGFloat available = right - kSide - kCaptionW - kAvatar - kValueGap;
	CGFloat nameW = MIN(ceilf(TGGiftTextSize(name, font).width) + 1, available);
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(
			right - nameW, y + TGHalf(kRow) - TGHalf(kValueLine), nameW, kValueLine)];
	label.text = name;
	label.font = font;
	label.textColor = [[TGTheme shared] accentColour];
	label.textAlignment = NSTextAlignmentRight;
	label.lineBreakMode = NSLineBreakByTruncatingTail;
	label.backgroundColor = [UIColor clearColor];
	[_card addSubview:label];

	UIImageView *face = [[UIImageView alloc] initWithFrame:CGRectMake(
			right - nameW - kValueGap - kAvatar, y + TGCenteredOrigin(kRow, kAvatar),
			kAvatar, kAvatar)];
	face.layer.cornerRadius = TGHalf(kAvatar);
	face.clipsToBounds = YES;
	NSString *first = [TGIcons initialsForTitle:name];
	face.image = [TGIcons avatarWithInitials:first size:kAvatar colourId:userId];
	[_card addSubview:face];

	// The cached initials give way to the photo when it lands, unless anonymous.
	if (!isPrivate && userId > 0){
		NSNumber *fileId = [[TGMediaStore shared] photoFileIdForUserId:userId];
		if ([fileId isKindOfClass:NSNumber.class] && fileId.integerValue > 0){
			__weak UIImageView *weakFace = face;
			[[TGMediaStore shared] downloadFile:fileId.integerValue
								   completion:^(NSString *path){
				if (!path.length)
					return;
				dispatch_async(dispatch_get_global_queue(
						DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
					UIImage *photo = [TGIcons decodedImage:
							[UIImage imageWithContentsOfFile:path]
							fittingSize:CGSizeMake(kAvatar, kAvatar)
							fill:YES scale:[UIScreen mainScreen].scale];
					if (!photo)
						return;
					dispatch_async(dispatch_get_main_queue(), ^{
						weakFace.image = photo;
					});
				});
			}];
		}
	}
}

@end
