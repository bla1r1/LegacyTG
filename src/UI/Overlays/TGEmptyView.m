//
// TGEmptyView.m - Tactile Empty State Presentation
// Centered vector iconography, embossed typography, and action buttons.
//
#import "TGEmptyView.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGTextDraw.h"
#import "TGRowGeometry.h"


@implementation TGEmptyView

+ (instancetype)emptyViewWithFrame:(CGRect)frame
                             image:(UIImage *)image
                             title:(NSString *)title
                          subtitle:(NSString *)subtitle
                       buttonTitle:(NSString *)buttonTitle
                            target:(id)target
                            action:(SEL)action {
	TGEmptyView *view = [[self alloc] initWithFrame:frame];
	[view configureWithImage:image
	                   title:title
	                subtitle:subtitle
	             buttonTitle:buttonTitle
	                  target:target
	                  action:action];
	return view;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self) return nil;

	self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.backgroundColor = [UIColor clearColor];
	self.userInteractionEnabled = YES;

	return self;
}

- (void)configureWithImage:(UIImage *)image
                     title:(NSString *)title
                  subtitle:(NSString *)subtitle
               buttonTitle:(NSString *)buttonTitle
                    target:(id)target
                    action:(SEL)action {
	// Remove previous subviews if any
	for (UIView *v in self.subviews) {
		[v removeFromSuperview];
	}

	TGTheme *theme = [TGTheme shared];
	CGFloat width = self.bounds.size.width;
	CGFloat lineWidth = TGCentredStackTextWidth(width);
	CGFloat titleH = title.length ? TGTextHeight(title, TGFontTitle(), lineWidth) : 0;
	CGFloat subH = subtitle.length ? TGTextHeight(subtitle, TGFontBody(), lineWidth) : 0;
	CGSize button = buttonTitle.length
			? CGSizeMake(TGMetricEmptyButtonWidth, TGMetricButtonHeightSmall) : CGSizeZero;
	TGCentredStack place = TGEmptyStatePlace(self.bounds.size,
			image ? TGMetricEmptyIconSide : 0, titleH, subH, button);

	if (image){
		_iconView = [[UIImageView alloc] initWithFrame:place.art];
		_iconView.image = image;
		_iconView.contentMode = UIViewContentModeScaleAspectFit;
		[TGIcons tintImageView:_iconView colour:[theme secondaryTextColour]];
		_iconView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		[self addSubview:_iconView];
	}

	_titleLabel = [[UILabel alloc] initWithFrame:place.title];
	_titleLabel.font = TGFontTitle();
	_titleLabel.textColor = [theme primaryTextColour];
	_titleLabel.textAlignment = NSTextAlignmentCenter;
	_titleLabel.numberOfLines = 0;
	_titleLabel.text = title;
	_titleLabel.backgroundColor = [UIColor clearColor];
	_titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self addSubview:_titleLabel];

	_subtitleLabel = [[UILabel alloc] initWithFrame:place.subtitle];
	_subtitleLabel.font = TGFontBody();
	_subtitleLabel.textColor = [theme secondaryTextColour];
	_subtitleLabel.textAlignment = NSTextAlignmentCenter;
	_subtitleLabel.numberOfLines = 0;
	_subtitleLabel.text = subtitle;
	_subtitleLabel.backgroundColor = [UIColor clearColor];
	_subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self addSubview:_subtitleLabel];

	if (buttonTitle.length) {
		_actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
		_actionButton.frame = place.button;
		_actionButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		[_actionButton setTitle:buttonTitle forState:UIControlStateNormal];
		[TGTheme applySkeuomorphicStyleToButton:_actionButton style:TGButtonStyleAction];
		if (target && action) {
			[_actionButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
		}
		[self addSubview:_actionButton];
	}
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	_titleLabel.textColor = [theme primaryTextColour];
	_subtitleLabel.textColor = [theme secondaryTextColour];
	if (_iconView)
		[TGIcons tintImageView:_iconView colour:[theme secondaryTextColour]];
}

- (void)didMoveToWindow {
	[super didMoveToWindow];
	// The factory finishes configuring before the view joins a window, so that
	// is the first moment the fade can actually be seen.
	if (self.window && !self.hidden)
		[self fadeIn];
}

- (void)setHidden:(BOOL)hidden {
	if (hidden == self.hidden) {
		[super setHidden:hidden];
		return;
	}
	if (!hidden) {
		[super setHidden:NO];
		[self fadeIn];
	} else {
		[super setHidden:YES];
		// Reset so the next show starts its fade from clear.
		self.alpha = TGAlphaOpaque;
	}
}

- (void)fadeIn {
	self.alpha = TGAlphaTransparent;
	__weak typeof(self) weakSelf = self;
	[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
		weakSelf.alpha = TGAlphaOpaque;
	}];
}

@end
