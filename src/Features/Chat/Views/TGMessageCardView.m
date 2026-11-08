#import "TGMessageCardView.h"
#import "TGNameWithStatus.h"
#import "TGStyle.h"
#import "TGTheme.h"
#import "TGMediaStore.h"
#import "UIImage+WebP.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static const size_t kCardBitsPerComponent = 8;
static const size_t kCardBytesPerPixel = 4;
static const NSUInteger kCardLineViewsCount = 4;

@interface TGMessageCardView ()
@property (nonatomic, strong) TGMessageCard *card;
@property (nonatomic, strong) UIImageView *picture;
@property (nonatomic, strong) UILabel *kicker;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) NSArray *lineLabels;
@property (nonatomic, strong) UIButton *button;
@end

@implementation TGMessageCardView

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor clearColor];

		// Picture
		_picture = [[UIImageView alloc] initWithFrame:CGRectZero];
		_picture.contentMode = UIViewContentModeScaleAspectFill;
		_picture.clipsToBounds = YES;
		[self addSubview:_picture];

		// Kicker
		_kicker = [[UILabel alloc] initWithFrame:CGRectZero];
		_kicker.font = TGFontCaptionStrong();
		_kicker.textColor = [[TGTheme shared] accentColour];
		_kicker.backgroundColor = [UIColor clearColor];
		[self addSubview:_kicker];

		// Title
		_title = [[UILabel alloc] initWithFrame:CGRectZero];
		_title.font = TGFontBodyStrong();
		_title.textColor = [[TGTheme shared] primaryTextColour];
		_title.numberOfLines = 2;
		_title.lineBreakMode = NSLineBreakByTruncatingTail;
		_title.backgroundColor = [UIColor clearColor];
		[self addSubview:_title];

		// Four line labels
		NSMutableArray *lines = [NSMutableArray arrayWithCapacity:kCardLineViewsCount];
		for (NSUInteger i = 0; i < kCardLineViewsCount; i++) {
			UILabel *lineLabel = [[UILabel alloc] initWithFrame:CGRectZero];
			lineLabel.font = TGFontSubhead();
			lineLabel.textColor = [[TGTheme shared] secondaryTextColour];
			lineLabel.numberOfLines = 2;
			lineLabel.lineBreakMode = NSLineBreakByTruncatingTail;
			lineLabel.backgroundColor = [UIColor clearColor];
			[self addSubview:lineLabel];
			[lines addObject:lineLabel];
		}
		_lineLabels = lines;

		// Action button
		_button = [UIButton buttonWithType:UIButtonTypeCustom];
		_button.titleLabel.font = TGFontBodyStrong();
		[_button setTitleColor:[[TGTheme shared] accentColour] forState:UIControlStateNormal];
		_button.layer.borderWidth = TGMetricBorderWidth;
		_button.layer.borderColor = [[TGTheme shared] accentColour].CGColor;
		_button.layer.cornerRadius = TGMetricCornerControl;
		_button.backgroundColor = [UIColor clearColor];
		[_button addTarget:self action:@selector(actionButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
		[self addSubview:_button];
	}
	return self;
}

- (void)actionButtonTapped:(id)sender {
	if (self.onAction) {
		self.onAction(self.card);
	}
}

- (void)applyCardLayout {
	TGMessageCard *card = self.card;
	if (!card) {
		self.picture.hidden = YES;
		self.kicker.hidden = YES;
		self.title.hidden = YES;
		for (UILabel *lineLabel in self.lineLabels) {
			lineLabel.hidden = YES;
		}
		self.button.hidden = YES;
		return;
	}

	CGFloat width = self.bounds.size.width;
	TGMessageCardFrames frames = TGMessageCardLayout(card, width);

	// Picture
	self.picture.frame = frames.image;
	self.picture.hidden = CGRectIsEmpty(frames.image);

	// Kicker
	self.kicker.frame = frames.kicker;
	self.kicker.hidden = CGRectIsEmpty(frames.kicker);
	self.kicker.text = card.kicker ?: @"";

	// Title
	self.title.frame = frames.title;
	self.title.hidden = CGRectIsEmpty(frames.title);
	if (card.titleStatusEmojiId != 0) {
		self.title.attributedText = TGNameWithStatus(card.title ?: @"", card.titleStatusEmojiId, self.title.font, [[TGTheme shared] primaryTextColour]);
	} else {
		self.title.text = card.title ?: @"";
	}

	// Lines
	NSUInteger lineCount = [card.lines isKindOfClass:NSArray.class] ? card.lines.count : 0;
	for (NSUInteger i = 0; i < kCardLineViewsCount; i++) {
		UILabel *lineLabel = self.lineLabels[i];
		lineLabel.frame = frames.lines[i];
		lineLabel.hidden = CGRectIsEmpty(frames.lines[i]);
		if (i < lineCount && [card.lines[i] isKindOfClass:NSString.class]) {
			lineLabel.text = card.lines[i];
		} else {
			lineLabel.text = @"";
		}
	}

	// Button
	self.button.frame = frames.button;
	self.button.hidden = CGRectIsEmpty(frames.button);
	[self.button setTitle:(card.buttonTitle ?: @"") forState:UIControlStateNormal];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	[self applyCardLayout];
}

- (void)showCard:(TGMessageCard *)card {
	// A row rebuilds its card on every reload; the same file already drawn
	// stays, or each reload would blank and re-decode the picture.
	BOOL samePicture = card && self.card && card.imageFileId == self.card.imageFileId &&
			card.imageIsRound == self.card.imageIsRound && self.picture.image;
	self.card = card;
	[self applyCardLayout];

	if (!card || card.imageFileId <= 0) {
		self.picture.image = nil;
		return;
	}
	if (samePicture)
		return;

	self.picture.image = nil;

	int64_t fileId = card.imageFileId;
	__weak typeof(self) weakSelf = self;
	TGMessageCard *thatCard = card;
	BOOL isRound = card.imageIsRound;
	CGFloat picSide = self.picture.frame.size.width;
	CGFloat screenScale = [UIScreen mainScreen].scale;

	[[TGMediaStore shared] downloadFile:(NSInteger)fileId completion:^(NSString *path) {
		if (!path || path.length == 0) {
			return;
		}

		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			NSData *data = [NSData dataWithContentsOfFile:path];
			if (!data || data.length < 2) {
				return;
			}

			const unsigned char *bytes = (const unsigned char *)data.bytes;
			UIImage *image = nil;
			if (data.length >= 4 && bytes[0] == 'R' && bytes[1] == 'I' && bytes[2] == 'F' && bytes[3] == 'F') {
				image = [UIImage convertFromWebP:path compressedData:NULL error:NULL];
			} else if (bytes[0] == 0x1F && bytes[1] == 0x8B) {
				// Gzip indicates an animated sticker, which cannot be displayed in a static card.
				return;
			} else {
				image = [UIImage imageWithData:data];
			}

			if (!image) {
				return;
			}

			if (isRound) {
				CGFloat scale = screenScale > 0.0f ? screenScale : 1.0f;
				CGFloat sidePt = picSide > 0.0f ? picSide : TGMetricPersonRow;
				size_t px = (size_t)ceil(sidePt * scale);
				if (px > 0 && image.CGImage) {
					CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
					CGContextRef ctx = CGBitmapContextCreate(NULL,
															 px,
															 px,
															 kCardBitsPerComponent,
															 kCardBytesPerPixel * px,
															 colorSpace,
															 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
					CGColorSpaceRelease(colorSpace);
					if (ctx) {
						CGRect rect = CGRectMake(0, 0, px, px);
						CGContextAddEllipseInRect(ctx, rect);
						CGContextClip(ctx);
						// A bitmap context already draws a CGImage upright; flipping
						// here would turn every face upside down.

						CGFloat imgW = (CGFloat)CGImageGetWidth(image.CGImage);
						CGFloat imgH = (CGFloat)CGImageGetHeight(image.CGImage);
						CGRect drawRect = rect;
						if (imgW > 0.0f && imgH > 0.0f) {
							if (imgW > imgH) {
								CGFloat scaledW = (imgW / imgH) * px;
								drawRect = CGRectMake(TGHalf(px - scaledW), 0, scaledW, px);
							} else if (imgH > imgW) {
								CGFloat scaledH = (imgH / imgW) * px;
								drawRect = CGRectMake(0, TGHalf(px - scaledH), px, scaledH);
							}
						}
						CGContextDrawImage(ctx, drawRect, image.CGImage);

						CGImageRef roundImageRef = CGBitmapContextCreateImage(ctx);
						if (roundImageRef) {
							image = [UIImage imageWithCGImage:roundImageRef scale:scale orientation:UIImageOrientationUp];
							CGImageRelease(roundImageRef);
						}
						CGContextRelease(ctx);
					}
				}
			}

			dispatch_async(dispatch_get_main_queue(), ^{
				__strong typeof(weakSelf) strongSelf = weakSelf;
				if (strongSelf && strongSelf.card == thatCard) {
					strongSelf.picture.image = image;
				}
			});
		});
	}];
}

@end
