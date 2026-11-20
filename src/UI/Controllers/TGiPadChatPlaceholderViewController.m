//
// TGiPadChatPlaceholderViewController.m
// LegacyTG - Telegram client for legacy iOS
//
// The detail pane with no chat open. Official (TelegramRootController's
// DetailsChatPlaceholderNode) draws the chat wallpaper with one service plate,
// "Select a chat to start messaging", and no navigation bar; an icon, a title
// and an empty bar over a grey list background read as a broken screen.
//
#import "TGiPadChatPlaceholderViewController.h"
#import "TGCapabilities.h"
#import "TGLocalization.h"
#import "TGMessageLayout.h"
#import "TGTheme.h"
#import "TGStyle.h"

@interface TGiPadChatPlaceholderViewController ()
@property (nonatomic, strong) UIImageView *wallpaperView;
@property (nonatomic, strong) UIView *plate;
@property (nonatomic, strong) UILabel *label;
@end

@implementation TGiPadChatPlaceholderViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"";

	// Same picture and fill as the chat behind it, so opening a chat does not
	// change the background under the user's eyes.
	self.wallpaperView = [[UIImageView alloc] initWithFrame:self.view.bounds];
	self.wallpaperView.contentMode = UIViewContentModeScaleAspectFill;
	self.wallpaperView.clipsToBounds = YES;
	self.wallpaperView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:self.wallpaperView];

	self.plate = [[UIView alloc] init];
	self.label = [[UILabel alloc] init];
	self.label.backgroundColor = [UIColor clearColor];
	self.label.textAlignment = NSTextAlignmentCenter;
	self.label.font = TGFontMeta();
	self.label.text = TGLocalized(@"Select a chat to start messaging");
	[self.plate addSubview:self.label];
	[self.view addSubview:self.plate];

	[self applyTheme];
}

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];
	CGSize size = self.view.bounds.size;
	CGFloat textW = MIN(TGTextSize(self.label.text, self.label.font, 0).width,
			size.width - TGDoubled(TGMetricPadWide));
	CGFloat plateW = ceilf(textW + TGDoubled(TGMetricPadMedium));
	CGFloat plateH = TGMetricLineHeader;
	self.plate.frame = CGRectMake(floorf(TGCenteredOrigin(size.width, plateW)),
			floorf(TGCenteredOrigin(size.height, plateH)), plateW, plateH);
	self.label.frame = self.plate.bounds;
}

- (void)applyTheme {
	[super applyTheme];
	TGTheme *theme = [TGTheme shared];
	self.view.backgroundColor = [theme chatBackgroundColour];
	self.wallpaperView.backgroundColor = [theme chatBackgroundColour];
	self.wallpaperView.image = [TGCapabilities canShowWallpaper] ? [theme wallpaper] : nil;
	self.plate.backgroundColor = [theme serviceBubbleColour];
	self.plate.layer.cornerRadius = [theme bubbleCornerRadius];
	self.label.textColor = [theme serviceTextColour];
}

@end
