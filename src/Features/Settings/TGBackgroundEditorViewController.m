//
// TGBackgroundEditorViewController.m - custom color and gradient wallpaper editor.
//
#import "TGBackgroundEditorViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGRows.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kPreviewHeight = 130.0f;
static const CGFloat kPreviewBoxTop = 10.0f;
static const CGFloat kPreviewBubbleLeft = 14.0f;
static const CGFloat kPreviewBubbleTop = 20.0f;
static const CGFloat kPreviewBubbleHeight = 40.0f;
static const CGFloat kPreviewBubbleInset = 50.0f;
static const CGFloat kPreviewLabelTop = 4.0f;
static const CGFloat kPreviewLabelHeight = 32.0f;
static const CGFloat kPreviewSwatchSide = 26.0f;
static const CGFloat kWallpaperDefaultWidth = 320.0f;
static const CGFloat kWallpaperDefaultHeight = 480.0f;

@interface TGBackgroundEditorViewController ()
@property (nonatomic, strong) NSArray *presets;
@property (nonatomic, assign) NSInteger selectedPresetIndex;
@property (nonatomic, strong) UIView *previewContainer;
@property (nonatomic, strong) CAGradientLayer *previewGradient;
@end

@implementation TGBackgroundEditorViewController

- (instancetype)init {
	self = [super init];
	if (self) {
		_presets = TGWallpaperPalettePresets();
		_selectedPresetIndex = 0;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Set a Color");
	self.navigationItem.rightBarButtonItem =
			[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Apply")
											 style:UIBarButtonItemStyleDone
											target:self
											action:@selector(applyTapped)];
	[self setupHeaderPreview];
	[self rebuildSections];
	[self applyTheme];
}

- (void)setupHeaderPreview {
	CGFloat width = self.tableView.bounds.size.width ?: kWallpaperDefaultWidth;
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, kPreviewHeight)];
	header.backgroundColor = [UIColor clearColor];

	UIView *box = [[UIView alloc] initWithFrame:CGRectMake(TGMetricGutter, kPreviewBoxTop,
			width - TGDoubled(TGMetricGutter), kPreviewHeight - TGMetricPadLarge)];
	box.layer.cornerRadius = TGMetricCornerCard;
	box.layer.masksToBounds = YES;
	box.layer.borderColor = [TGTheme shared].separatorColour.CGColor;
	box.layer.borderWidth = 1.0f;

	self.previewGradient = [CAGradientLayer layer];
	self.previewGradient.frame = box.bounds;
	[box.layer addSublayer:self.previewGradient];

	// Sample chat bubble inside preview
	UIView *bubble = [[UIView alloc] initWithFrame:CGRectMake(kPreviewBubbleLeft, kPreviewBubbleTop,
			box.bounds.size.width - kPreviewBubbleInset, kPreviewBubbleHeight)];
	bubble.backgroundColor = [[TGTheme shared] isDark]
			? [[TGTheme shared] cardBackgroundColour]
			: [[TGTheme shared] onAccentColour];
	bubble.layer.cornerRadius = TGMetricCornerBubbleFlat;
	bubble.layer.masksToBounds = YES;

	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(TGMetricPadSmall, kPreviewLabelTop,
			bubble.bounds.size.width - TGDoubled(TGMetricPadSmall), kPreviewLabelHeight)];
	label.text = TGLocalized(@"Preview of your chat wallpaper");
	label.font = TGFontRow();
	label.textColor = [[TGTheme shared] primaryTextColour];
	label.backgroundColor = [UIColor clearColor];
	[bubble addSubview:label];
	[box addSubview:bubble];

	self.previewContainer = box;
	[header addSubview:box];
	self.tableView.tableHeaderView = header;
	[self updatePreview];
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:self.presets.count];
	for (NSUInteger i = 0; i < self.presets.count; i++){
		TGWallpaperPreset *preset = self.presets[i];
		NSMutableDictionary *row = TGRow(TGKindImageCheck, preset.name);
		row[TGRowImage] = [self swatchImageForPreset:preset];
		row[TGRowChecked] = @((NSInteger)i == self.selectedPresetIndex);
		row[TGRowTap] = ^{
			weakSelf.selectedPresetIndex = (NSInteger)i;
			[weakSelf updatePreview];
			[weakSelf rebuildSections];
			[weakSelf reloadRows];
		};
		[rows addObject:row];
	}
	self.sections = @[TGSection(@"COLORS & GRADIENTS", nil, rows)];
}

- (void)updatePreview {
	if (!self.presets.count) return;
	TGWallpaperPreset *p = self.presets[self.selectedPresetIndex];
	self.previewGradient.colors = @[(id)p.topColor.CGColor, (id)p.bottomColor.CGColor];
}

- (UIImage *)renderedWallpaperImage {
	CGSize size = CGSizeMake(kWallpaperDefaultWidth, kWallpaperDefaultHeight);
	if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
		CGFloat s = [UIScreen mainScreen].scale;
		size = CGSizeMake(kWallpaperDefaultWidth * s, kWallpaperDefaultHeight * s);
	}
	UIGraphicsBeginImageContextWithOptions(size, YES, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	TGWallpaperPreset *p = self.presets[self.selectedPresetIndex];

	if (p.isGradient) {
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		CGFloat locations[2] = {0.0f, 1.0f};
		CFArrayRef colors = (__bridge CFArrayRef)@[ (id)p.topColor.CGColor, (id)p.bottomColor.CGColor ];
		CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colors, locations);
		CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(0, size.height), 0);
		CGGradientRelease(gradient);
		CGColorSpaceRelease(colorSpace);
	} else {
		[p.topColor setFill];
		UIRectFill(CGRectMake(0, 0, size.width, size.height));
	}
	UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return img;
}

- (void)applyTapped {
	UIImage *wallpaper = [self renderedWallpaperImage];
	[[TGTheme shared] setWallpaperImage:wallpaper];
	[TGAlertSheet showMessage:TGLocalized(@"Wallpaper applied successfully.")
						title:TGLocalized(@"Chat Wallpaper")
					   inView:self.view];
	[self.navigationController popViewControllerAnimated:YES];
}

- (UIImage *)swatchImageForPreset:(TGWallpaperPreset *)preset {
	CGFloat side = kPreviewSwatchSide;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, side, side)];
	[circle addClip];

	if (preset.isGradient) {
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		CGFloat locations[2] = {0.0f, 1.0f};
		CFArrayRef colors = (__bridge CFArrayRef)@[ (id)preset.topColor.CGColor, (id)preset.bottomColor.CGColor ];
		CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colors, locations);
		CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(0, side), 0);
		CGGradientRelease(gradient);
		CGColorSpaceRelease(colorSpace);
	} else {
		[preset.topColor setFill];
		UIRectFill(CGRectMake(0, 0, side, side));
	}
	UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return img;
}

@end
