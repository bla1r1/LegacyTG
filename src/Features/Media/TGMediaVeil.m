#import "TGMediaVeil.h"
#import "TGTheme.h"
#import "TGStyle+Metrics.h"
#import "TGStyle+Typography.h"
#import "TGStyle+Decorations.h"
#import "TGMessageLayout.h"
#import <QuartzCore/QuartzCore.h>
#include <math.h>

@interface TGMediaVeilView ()
@property (nonatomic, strong) UIImageView *blurredView;
@property (nonatomic, strong) UIView *plateView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *paidButton;
@property (nonatomic, strong) UIImage *picture;
@end

@implementation TGMediaVeilView

@synthesize kind = _kind;
@synthesize starCount = _starCount;
@synthesize onTap = _onTap;

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		[self mv_setupSubviews];
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	if (self) {
		[self mv_setupSubviews];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)mv_setupSubviews {
	self.userInteractionEnabled = YES;
	self.clipsToBounds = YES;

	_blurredView = [[UIImageView alloc] initWithFrame:self.bounds];
	_blurredView.contentMode = UIViewContentModeScaleAspectFill;
	_blurredView.clipsToBounds = YES;
	_blurredView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_blurredView.userInteractionEnabled = NO;
	[self addSubview:_blurredView];

	_plateView = [[UIView alloc] initWithFrame:self.bounds];
	_plateView.backgroundColor = [[TGTheme shared] mediaOverlayColour];
	_plateView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_plateView.userInteractionEnabled = NO;
	[self addSubview:_plateView];

	_titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_titleLabel.font = TGFontBodyStrong();
	_titleLabel.textColor = [[TGTheme shared] onMediaColour];
	_titleLabel.textAlignment = NSTextAlignmentCenter;
	_titleLabel.backgroundColor = [UIColor clearColor];
	_titleLabel.userInteractionEnabled = NO;
	[self addSubview:_titleLabel];

	_paidButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_paidButton.titleLabel.font = TGFontBodyStrong();
	[_paidButton setTitleColor:[[TGTheme shared] onAccentColour] forState:UIControlStateNormal];
	_paidButton.backgroundColor = [[TGTheme shared] accentColour];
	_paidButton.layer.cornerRadius = TGHalf(TGMetricButtonHeightSmall);
	[_paidButton addTarget:self action:@selector(mv_buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
	[self addSubview:_paidButton];

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mv_handleTap:)];
	[self addGestureRecognizer:tap];

	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(mv_themeChanged:)
	                                             name:TGThemeChangedNotification
	                                           object:nil];

	[self mv_updateVisibility];
}

- (void)mv_themeChanged:(NSNotification *)notification {
	_plateView.backgroundColor = [[TGTheme shared] mediaOverlayColour];
	_titleLabel.textColor = [[TGTheme shared] onMediaColour];
	[_paidButton setTitleColor:[[TGTheme shared] onAccentColour] forState:UIControlStateNormal];
	_paidButton.backgroundColor = [[TGTheme shared] accentColour];
}

- (void)setKind:(TGMediaVeilKind)kind {
	_kind = kind;
	[self mv_updateVisibility];
}

- (void)setStarCount:(int64_t)starCount {
	_starCount = starCount;
	if (_kind == TGMediaVeilKindPaid) {
		[self mv_updateVisibility];
	}
}

- (void)mv_updateVisibility {
	if (_kind == TGMediaVeilKindNone) {
		self.hidden = YES;
		_titleLabel.hidden = YES;
		_paidButton.hidden = YES;
		return;
	}

	self.hidden = NO;
	if (_kind == TGMediaVeilKindSpoiler) {
		_titleLabel.hidden = YES;
		_paidButton.hidden = YES;
	} else if (_kind == TGMediaVeilKindViewOnce) {
		_titleLabel.hidden = NO;
		_titleLabel.text = TGMediaVeilTitle(_kind, _starCount);
		_paidButton.hidden = YES;
	} else if (_kind == TGMediaVeilKindPaid) {
		_titleLabel.hidden = YES;
		_paidButton.hidden = NO;
		[_paidButton setTitle:TGMediaVeilTitle(_kind, _starCount) forState:UIControlStateNormal];
	}
	[self setNeedsLayout];
}

- (void)setPicture:(UIImage *)picture {
	_picture = picture;
	if (!picture) {
		_blurredView.image = nil;
		return;
	}

	CGImageRef srcImage = picture.CGImage;
	if (!srcImage) {
		_blurredView.image = nil;
		return;
	}

	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// An eighth of the picture's long side: a fixed radius in source
		// pixels vanishes on a 1280 px photo and leaves the spoiler readable.
		size_t longSide = MAX(CGImageGetWidth(srcImage), CGImageGetHeight(srcImage));
		CGImageRef blurredCG = TGMediaVeilBlurCreate(srcImage, (CGFloat)longSide / TGMetricPad);
		if (!blurredCG) {
			return;
		}
		UIImage *blurredImage = [UIImage imageWithCGImage:blurredCG];
		CGImageRelease(blurredCG);

		dispatch_async(dispatch_get_main_queue(), ^{
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf) {
				return;
			}
			// Cell reuse guard: only apply if the picture hasn't changed while blurring.
			if (strongSelf.picture == picture) {
				strongSelf->_blurredView.image = blurredImage;
			}
		});
	});
}

- (void)mv_handleTap:(UITapGestureRecognizer *)recognizer {
	if (self.onTap) {
		self.onTap(self.kind);
	}
}

- (void)mv_buttonTapped:(id)sender {
	if (self.onTap) {
		self.onTap(self.kind);
	}
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect bounds = self.bounds;
	_blurredView.frame = bounds;
	_plateView.frame = bounds;

	if (!_titleLabel.hidden) {
		NSString *titleText = _titleLabel.text ?: @"";
		CGSize titleSize = TGTextSize(titleText, TGFontBodyStrong(), bounds.size.width);
		CGFloat titleW = ceil(titleSize.width);
		CGFloat titleH = ceil(titleSize.height);
		_titleLabel.frame = CGRectMake(TGCenteredOrigin(bounds.size.width, titleW),
		                               TGCenteredOrigin(bounds.size.height, titleH),
		                               titleW,
		                               titleH);
	}

	if (!_paidButton.hidden) {
		NSString *buttonTitle = [_paidButton titleForState:UIControlStateNormal] ?: @"";
		CGSize textSize = TGTextSize(buttonTitle, TGFontBodyStrong(), bounds.size.width);
		CGFloat buttonWidth = ceil(textSize.width) + TGDoubled(TGMetricPadLarge);
		CGFloat buttonHeight = TGMetricButtonHeightSmall;
		_paidButton.frame = CGRectMake(TGCenteredOrigin(bounds.size.width, buttonWidth),
		                              TGCenteredOrigin(bounds.size.height, buttonHeight),
		                              buttonWidth,
		                              buttonHeight);
	}
}

@end
