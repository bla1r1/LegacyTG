//
// TGChatPreviewRowCell.m - the Appearance sample conversation, moved out of
// the Settings controller so the page describes a row and nothing else.
//
#import "TGChatPreviewRowCell.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGIcons.h"
#import "TGBubbleBackImage.h"
#import "TGSettingsFormatting.h"

/// The theme preview: a strip of wallpaper carrying the same four things
/// ThemeSettingsChatPreviewItem lays out - a sender, a reply, the incoming
/// message and your answer - plus the time. One bitmap per theme, size and
/// wallpaper, so scrolling creates no gradient layer.
static const CGFloat kPreviewInset      = TGMetricPadMedium;
static const CGFloat kPreviewTop        = TGMetricPadLarge;
static const CGFloat kPreviewGap        = TGMetricPad;
static const CGFloat kPreviewTextLeft   = TGMetricBubblePadH;
static const CGFloat kPreviewStampRoom  = 46.0f;
static const CGFloat kPreviewStampW     = 30.0f;
static const CGFloat kPreviewTicksRoom  = 18.0f;
static const CGFloat kPreviewTextMaxW   = 230.0f;
static const CGFloat kPreviewTextMaxH   = 80.0f;
static const CGFloat kPreviewBubbleMinH = 34.0f;
static const CGFloat kPreviewFallbackW  = 320.0f;
static const CGFloat kPreviewReplyPad   = TGMetricPadSmall;

static NSCache *TGPreviewImageCache;

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

/// The wallpaper behind the sample chat. A theme may carry a picture; without
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

UIImage *TGAppearancePreviewImage(CGFloat width) {
	TGTheme *theme = [TGTheme shared];
	CGFloat fontSize = theme.messageFontSize;
	UIImage *paper = theme.wallpaper;
	NSDictionary *texts = TGSettingsAppearancePreviewTexts();
	NSString *author = texts[@"author"];
	NSString *reply = texts[@"reply"];
	NSString *incoming = texts[@"incoming"];
	NSString *outgoing = texts[@"outgoing"];
	NSString *key = [NSString stringWithFormat:@"%@|%d|%.1f|%.1f|%lu|%@|%@",
			[theme currentThemeId], [theme isDark], width, fontSize,
			(unsigned long)paper.hash, TGAppLanguage(),
			[texts.allValues componentsJoinedByString:@"|"]];
	UIImage *cached = [TGPreviewImageCache objectForKey:key];
	if (cached)
		return cached;
	// The bubble pictures are flushed by an open chat on a theme change; with
	// no chat open they would still be the previous theme's.
	TGBubbleFlushCache();

	UIFont *body = TGFontAtSize(fontSize);
	UIFont *nameFont = TGFontMetaStrong();
	UIFont *metaFont = TGFontMeta();

	CGFloat room = width - TGDoubled(kPreviewInset);
	CGFloat incomingW = MIN(TGMetricBubbleMaxW, room);
	CGFloat textW = incomingW - TGDoubled(kPreviewTextLeft) - kPreviewStampRoom;
	CGSize replySize = [reply sizeWithFont:metaFont
						 constrainedToSize:CGSizeMake(textW - TGDoubled(kPreviewReplyPad),
								 TGMetricLineCaption * TGMetricPad)];
	CGFloat replyH = replySize.height + TGMetricLineMicro + TGDoubled(kPreviewReplyPad);
	CGSize inTextSize = [incoming sizeWithFont:body
							 constrainedToSize:CGSizeMake(textW, kPreviewTextMaxH)];
	CGFloat incomingH = kPreviewGap + replyH + kPreviewGap +
			inTextSize.height + TGMetricLineCaption + kPreviewGap;

	CGSize outTextSize = [outgoing sizeWithFont:body
							  constrainedToSize:CGSizeMake(kPreviewTextMaxW, kPreviewTextMaxH)];
	CGFloat outgoingW = MIN(room, ceilf(outTextSize.width + TGDoubled(kPreviewTextLeft) +
			kPreviewStampRoom + kPreviewTicksRoom));
	CGFloat outgoingH = MAX(kPreviewBubbleMinH, outTextSize.height +
			TGMetricLineCaption + TGDoubled(kPreviewGap));
	CGFloat totalH = kPreviewTop + incomingH + kPreviewGap + outgoingH + kPreviewTop;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, totalH), YES, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	[theme.chatBackgroundColour setFill];
	UIRectFill(CGRectMake(0, 0, width, totalH));
	TGDrawAppearanceWallpaper(paper, theme.chatBackgroundColour,
			CGRectMake(0, 0, width, totalH), [theme isDark]);

	// Incoming: the reply quote at the top, then the message and its time.
	CGRect incomingRect = CGRectMake(kPreviewInset, kPreviewTop, incomingW, incomingH);
	// The chat's own bubble picture, so corners, tail and rim match a real
	// conversation; it hangs the tail TGMetricBubbleTailWidth outside.
	[TGBubbleBackImage(theme, NO, YES, YES) drawInRect:CGRectMake(
			CGRectGetMinX(incomingRect) - TGMetricBubbleTailWidth,
			CGRectGetMinY(incomingRect),
			CGRectGetWidth(incomingRect) + TGMetricBubbleTailWidth,
			CGRectGetHeight(incomingRect))];

	CGRect replyRect = CGRectMake(CGRectGetMinX(incomingRect) + kPreviewTextLeft,
			CGRectGetMinY(incomingRect) + kPreviewGap,
			incomingW - TGDoubled(kPreviewTextLeft), replyH);
	UIBezierPath *replyPath = [UIBezierPath bezierPathWithRoundedRect:replyRect
			cornerRadius:TGMetricCornerSmall];
	[theme.serviceBubbleColour setFill];
	[replyPath fill];
	[theme.accentColour setFill];
	UIRectFill(CGRectMake(CGRectGetMinX(replyRect), CGRectGetMinY(replyRect),
			TGMetricBorderThick, CGRectGetHeight(replyRect)));
	CGRect replyTextRect = CGRectInset(replyRect, TGMetricPadSmall, 0);
	[theme.bubbleTheirsTextColour setFill];
	[author drawInRect:CGRectMake(CGRectGetMinX(replyTextRect),
			CGRectGetMinY(replyTextRect) + kPreviewReplyPad,
			CGRectGetWidth(replyTextRect), TGMetricLineMicro)
			 withFont:nameFont
		lineBreakMode:NSLineBreakByTruncatingTail
			alignment:NSTextAlignmentLeft];
	[reply drawInRect:CGRectMake(CGRectGetMinX(replyTextRect),
			CGRectGetMinY(replyTextRect) + kPreviewReplyPad + TGMetricLineMicro,
			CGRectGetWidth(replyTextRect), replySize.height)
			withFont:metaFont
	   lineBreakMode:NSLineBreakByTruncatingTail
		   alignment:NSTextAlignmentLeft];

	[theme.bubbleTheirsTextColour setFill];
	[incoming drawInRect:CGRectMake(CGRectGetMinX(incomingRect) + kPreviewTextLeft,
			CGRectGetMaxY(replyRect) + kPreviewGap,
			textW, inTextSize.height)
			   withFont:body
		  lineBreakMode:NSLineBreakByWordWrapping
			  alignment:NSTextAlignmentLeft];
	NSString *stamp = @"19:20";
	[theme.timeColour setFill];
	[stamp drawInRect:CGRectMake(CGRectGetMaxX(incomingRect) - kPreviewStampW -
			kPreviewTextLeft, CGRectGetMaxY(incomingRect) -
			TGMetricLineCaption - kPreviewGap, kPreviewStampW, TGMetricLineCaption)
			 withFont:TGFontMicro()
		lineBreakMode:NSLineBreakByClipping
			alignment:NSTextAlignmentRight];

	// Outgoing: the same gradient official draws, with the time and two ticks.
	CGFloat outgoingX = width - kPreviewInset - outgoingW;
	CGFloat outgoingY = CGRectGetMaxY(incomingRect) + kPreviewGap;
	CGRect outgoingRect = CGRectMake(outgoingX, outgoingY, outgoingW, outgoingH);
	[TGBubbleBackImage(theme, YES, YES, YES) drawInRect:CGRectMake(
			CGRectGetMinX(outgoingRect), CGRectGetMinY(outgoingRect),
			CGRectGetWidth(outgoingRect) + TGMetricBubbleTailWidth,
			CGRectGetHeight(outgoingRect))];
	[theme.bubbleMineTextColour setFill];
	[outgoing drawInRect:CGRectMake(CGRectGetMinX(outgoingRect) + kPreviewTextLeft,
			CGRectGetMinY(outgoingRect) + kPreviewGap,
			outgoingW - TGDoubled(kPreviewTextLeft) - kPreviewStampRoom -
					kPreviewTicksRoom, outTextSize.height)
			   withFont:body
		  lineBreakMode:NSLineBreakByWordWrapping
			  alignment:NSTextAlignmentLeft];
	[theme.timeMineColour setFill];
	[stamp drawInRect:CGRectMake(CGRectGetMaxX(outgoingRect) - kPreviewStampW -
			kPreviewTextLeft - kPreviewTicksRoom - TGMetricPad,
			CGRectGetMaxY(outgoingRect) - TGMetricLineCaption - kPreviewGap,
			kPreviewStampW, TGMetricLineCaption)
			 withFont:TGFontMicro()
		lineBreakMode:NSLineBreakByClipping
			alignment:NSTextAlignmentRight];
	UIImage *ticks = [TGIcons ticksColour:[theme timeMineColour] read:YES];
	[ticks drawInRect:CGRectMake(CGRectGetMaxX(outgoingRect) - kPreviewTicksRoom -
			TGMetricPad, CGRectGetMaxY(outgoingRect) - TGMetricLineCaption -
			kPreviewGap + TGMetricPadTiny, TGMetricTicksWidth, TGMetricTicksHeight)];

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (!TGPreviewImageCache){
		TGPreviewImageCache = [[NSCache alloc] init];
		TGPreviewImageCache.totalCostLimit = TGAppearanceImageCacheLimit();
	}
	if (image)
		[TGPreviewImageCache setObject:image forKey:key];
	return image;
}

@interface TGChatPreviewRowCell ()
@property (nonatomic, strong) NSDictionary *row;
@property (nonatomic, strong) UIImageView *previewView;
@property (nonatomic, assign) CGFloat previewWidth;
@end

@implementation TGChatPreviewRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	(void)row;
	CGFloat width = tableView.bounds.size.width ?: kPreviewFallbackW;
	return TGAppearancePreviewImage(width).size.height;
}

+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row {
	static NSString *reuse = @"TGChatPreviewRowCell";
	TGChatPreviewRowCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGChatPreviewRowCell alloc]
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
	self.backgroundColor = [UIColor clearColor];
	self.contentView.backgroundColor = [UIColor clearColor];
	_previewView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_previewView.contentMode = UIViewContentModeTop;
	_previewView.clipsToBounds = YES;
	[self.contentView addSubview:_previewView];
	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.row = nil;
	self.previewView.image = nil;
	self.previewWidth = 0;
}

- (void)configureWithRow:(NSDictionary *)row {
	self.row = row;
	[self applyTheme];
	[self setNeedsLayout];
}

- (void)applyTheme {
	if (!self.row)
		return;
	self.previewWidth = 0;
	self.previewView.image = nil;
	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat width = self.contentView.bounds.size.width;
	if (width <= 0)
		return;
	if (width != self.previewWidth || !self.previewView.image){
		self.previewWidth = width;
		UIImage *image = TGAppearancePreviewImage(width);
		self.previewView.frame = CGRectMake(0, 0, width, image.size.height);
		self.previewView.image = image;
	}
}

@end

// vim:ft=objc
