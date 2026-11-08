//
// TGInAppNotificationBanner.m - in-app notification banner for incoming messages.
//
#import "TGInAppNotificationBanner.h"
#import <AudioToolbox/AudioToolbox.h>
#import "TGStyle.h"
#import "TGTheme.h"
#import "TGIcons.h"

static TGInAppNotificationBanner *sCurrentBanner = nil;
static const NSTimeInterval kBannerDisplayDuration = 3.5;

@interface TGInAppNotificationBanner ()
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) void (^onTappedBlock)(int64_t);
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *textLabel;
@end

@implementation TGInAppNotificationBanner

+ (void)showForChatId:(int64_t)chatId
                title:(NSString *)title
                 text:(NSString *)text
               avatar:(UIImage *)avatar
             onTapped:(void (^)(int64_t))onTapped {
	UIWindow *window = [UIApplication sharedApplication].keyWindow;
	if (!window) return;

	[self dismissCurrentAnimated:NO];

	CGFloat width = window.bounds.size.width;
	CGFloat statusH = [UIApplication sharedApplication].statusBarHidden ? 0.0f :
			MIN([UIApplication sharedApplication].statusBarFrame.size.width,
				[UIApplication sharedApplication].statusBarFrame.size.height);
	CGFloat height = TGMetricRow + statusH;
	TGInAppNotificationBanner *banner = [[TGInAppNotificationBanner alloc]
			initWithFrame:CGRectMake(TGMetricZero, TGMetricZero, width, height)];
	banner.chatId = chatId;
	banner.onTappedBlock = onTapped;
	banner.backgroundColor = [[TGTheme shared] barColour];
	banner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;

	CGFloat pad = TGMetricPad;
	CGFloat avatarSide = TGMetricListAvatar;
	CGFloat avatarY = statusH + TGCenteredOrigin(TGMetricRow, avatarSide);

	banner.avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(pad, avatarY, avatarSide, avatarSide)];
	banner.avatarView.layer.cornerRadius = TGHalf(avatarSide);
	banner.avatarView.clipsToBounds = YES;
	banner.avatarView.image = avatar ?: [TGIcons avatarWithInitials:[TGIcons initialsForTitle:title]
															   size:avatarSide
														   colourId:chatId];
	[banner addSubview:banner.avatarView];

	CGFloat textX = pad + avatarSide + TGMetricPadSmall;
	CGFloat textW = width - textX - pad;
	CGFloat lineH = TGMetricLineCaption;

	banner.titleLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(textX, statusH + TGMetricPadTiny, textW, lineH)];
	banner.titleLabel.font = TGFontCaptionStrong();
	banner.titleLabel.textColor = [[TGTheme shared] barTitleColour];
	banner.titleLabel.backgroundColor = [UIColor clearColor];
	banner.titleLabel.text = title.length ? title : @"Telegram";
	[banner addSubview:banner.titleLabel];

	banner.textLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(textX, statusH + lineH + TGMetricPadTiny, textW, lineH)];
	banner.textLabel.font = TGFontCaption();
	banner.textLabel.textColor = [[TGTheme shared] barSubtitleColour];
	banner.textLabel.backgroundColor = [UIColor clearColor];
	banner.textLabel.text = text.length ? text : @"";
	[banner addSubview:banner.textLabel];

	UIView *hairline = [[UIView alloc] initWithFrame:
			CGRectMake(TGMetricZero, height - TGMetricHairline, width, TGMetricHairline)];
	hairline.backgroundColor = [[TGTheme shared] separatorColour];
	hairline.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	[banner addSubview:hairline];

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
			initWithTarget:banner action:@selector(handleTap)];
	[banner addGestureRecognizer:tap];

	UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc]
			initWithTarget:banner action:@selector(handleSwipe)];
	swipe.direction = UISwipeGestureRecognizerDirectionUp;
	[banner addGestureRecognizer:swipe];

	banner.transform = CGAffineTransformMakeTranslation(TGMetricZero, -height);
	[window addSubview:banner];
	sCurrentBanner = banner;

	// Slide in
	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		banner.transform = CGAffineTransformIdentity;
	}];

	// Play standard iOS message sound (1007)
	AudioServicesPlaySystemSound(1007);

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismissCurrentAnimated:) object:nil];
	[self performSelector:@selector(dismissCurrentAfterDelay) withObject:nil afterDelay:kBannerDisplayDuration];
}

+ (void)dismissCurrentAfterDelay {
	[self dismissCurrentAnimated:YES];
}

+ (void)dismissCurrentAnimated:(BOOL)animated {
	TGInAppNotificationBanner *banner = sCurrentBanner;
	if (!banner) return;
	sCurrentBanner = nil;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismissCurrentAfterDelay) object:nil];

	if (!animated) {
		[banner removeFromSuperview];
		return;
	}

	CGFloat height = banner.bounds.size.height;
	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		banner.transform = CGAffineTransformMakeTranslation(TGMetricZero, -height);
	} completion:^(BOOL finished){
		[banner removeFromSuperview];
	}];
}

- (void)handleTap {
	int64_t cid = self.chatId;
	void (^cb)(int64_t) = self.onTappedBlock;
	[[self class] dismissCurrentAnimated:YES];
	if (cb) {
		cb(cid);
	}
}

- (void)handleSwipe {
	[[self class] dismissCurrentAnimated:YES];
}

@end
