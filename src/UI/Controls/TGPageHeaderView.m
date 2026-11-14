//
// TGPageHeaderView.m
//
#import "TGPageHeaderView.h"
#import "TGRowGeometry.h"
#import "TGStyle.h"
#import "TGTextDraw.h"
#import "TGTheme.h"

static UILabel *TGPageHeaderLabel(CGRect frame, NSString *text, UIFont *font) {
	UILabel *label = [[UILabel alloc] initWithFrame:frame];
	label.text = text;
	label.font = font;
	label.numberOfLines = 0;
	label.textAlignment = NSTextAlignmentCenter;
	label.backgroundColor = [UIColor clearColor];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	return label;
}

/// Nil leaves the part out; an empty string keeps one line for text that
/// arrives later (a gift's sender name loads after the page opens).
static CGFloat TGPageHeaderPartHeight(NSString *text, UIFont *font, CGFloat width) {
	if (!text)
		return 0;
	return TGTextHeight(text.length ? text : @" ", font, width);
}

@implementation TGPageHeaderView

static TGCentredStack TGPageHeaderPlace(CGFloat width, CGFloat artSide,
		NSString *title, NSString *subtitle, NSString *text) {
	CGFloat line = TGCentredStackTextWidth(width);
	return TGCentredStackPlace(width, TGMetricPadLarge, artSide,
			TGPageHeaderPartHeight(title, TGFontTitle(), line),
			TGPageHeaderPartHeight(subtitle, TGFontSubhead(), line),
			TGPageHeaderPartHeight(text, TGFontBody(), line), CGSizeZero);
}

+ (CGFloat)heightForWidth:(CGFloat)width artSide:(CGFloat)artSide
		title:(NSString *)title subtitle:(NSString *)subtitle text:(NSString *)text {
	return TGMetricPadLarge + TGPageHeaderPlace(width, artSide, title, subtitle, text).height;
}

- (instancetype)initWithWidth:(CGFloat)width artSide:(CGFloat)artSide
		title:(NSString *)title subtitle:(NSString *)subtitle text:(NSString *)text {
	TGCentredStack place = TGPageHeaderPlace(width, artSide, title, subtitle, text);
	self = [super initWithFrame:CGRectMake(0, 0, width, TGMetricPadLarge + place.height)];
	if (!self)
		return nil;
	self.backgroundColor = [UIColor clearColor];
	self.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	_artView = [[UIView alloc] initWithFrame:place.art];
	_artView.backgroundColor = [UIColor clearColor];
	_artView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
			UIViewAutoresizingFlexibleRightMargin;
	_artView.hidden = artSide <= 0;
	[self addSubview:_artView];
	_imageView = [[UIImageView alloc] initWithFrame:_artView.bounds];
	_imageView.contentMode = UIViewContentModeScaleAspectFit;
	_imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleHeight;
	[_artView addSubview:_imageView];

	_titleLabel = TGPageHeaderLabel(place.title, title, TGFontTitle());
	_subtitleLabel = TGPageHeaderLabel(place.subtitle, subtitle, TGFontSubhead());
	_textLabel = TGPageHeaderLabel(place.text, text, TGFontBody());
	[self addSubview:_titleLabel];
	[self addSubview:_subtitleLabel];
	[self addSubview:_textLabel];
	[self applyTheme];
	return self;
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	self.titleLabel.textColor = [theme primaryTextColour];
	self.subtitleLabel.textColor = [theme secondaryTextColour];
	self.textLabel.textColor = [theme secondaryTextColour];
}

@end
