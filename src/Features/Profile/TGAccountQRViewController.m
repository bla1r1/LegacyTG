//
// TGAccountQRViewController.m
//
#import "TGAccountQRViewController.h"
#import "TGQRCode.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGLabel.h"
#import "TGLocalization.h"

static const CGFloat kAccountQRSide = 220.0f;
static const CGFloat kAccountQRTopOffset = 36.0f;

@implementation TGAccountQRViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"QR Code");
	self.view.backgroundColor = [[TGTheme shared] groupedBackgroundColour];
	CGFloat side = kAccountQRSide;
	NSString *displayCode = self.code.length ? self.code : @"https://t.me/telegram";
	UIImageView *image = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, side, side)];
	image.center = CGPointMake(CGRectGetMidX(self.view.bounds),
			CGRectGetMidY(self.view.bounds) - kAccountQRTopOffset);
	image.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
			UIViewAutoresizingFlexibleRightMargin;
	image.image = TGQRCodeImage(displayCode, side);
	[self.view addSubview:image];
	UILabel *caption = TGLabelWith(TGLabelBodySecondary, CGRectMake(TGMetricPadLarge,
			CGRectGetMaxY(image.frame) + TGMetricPadLarge,
			self.view.bounds.size.width - TGDoubled(TGMetricPadLarge), TGMetricLineRow), nil);
	caption.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	caption.textAlignment = NSTextAlignmentCenter;
	caption.text = displayCode;
	[self.view addSubview:caption];
}

@end
