#import "TGPerf.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGForwardPicker.h"
#import "TGVoiceRecorder.h"
#import "TGProfileViewController.h"
#import "TGThemeFile.h"
#import "TGCapabilities.h"
#import "TGDevice.h"
#import <AddressBookUI/AddressBookUI.h>
#import <CoreLocation/CoreLocation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#import <MapKit/MapKit.h>
#import <AVFoundation/AVFoundation.h>
#import "TGVoiceDecoder.h"
#import "TGEmojiData.h"
#import "TGCustomEmojiStore.h"
#import "UIImage+WebP.h"
#import "TGLottieView.h"
#import "TGDevShowcase.h"
#import "TGCallViewController.h"
#import "TGPopupMenu.h"
#import "TGSnackbar.h"
#import "TGMediaViewer.h"
#import "TGPollPresentation.h"
#import "TGChecklistPresentation.h"
#import "TGGiftViewController.h"
#import "TGStoryViewerViewController.h"
#import "TGCommunityViewController.h"
#import "TGMusicPlayer.h"
#import "TGDevShowcase.h"
#import "TGMessageLayout.h"
#import "TGBubbleCell.h"
#import "TGChatViewControllerInternal.h"
#import "TGMessageStreamStore.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGDMTopicsViewController.h"

#if TG_DEV
#endif



/// The pin in the strip under the bar, and where its two lines begin after it.
static const CGFloat kPinnedGlyph = 14.0f;
static const CGFloat kPinnedThumbSide = TGMetricPinnedThumb;
static const CGFloat kPinnedTextX = TGMetricPadLarge + kPinnedGlyph + TGMetricPadSmall;
/// The message line when the strip already exists and only its text changes.
static const NSInteger kPinnedBodyTag = 0x9010;
static const NSInteger kPinnedThumbTag = 0x9011;
/// The bar that stands in for the composer: mute for a channel you follow,
/// join for one you have not joined yet. One tag per state, so a second answer
/// replaces the bar instead of stacking another one on top.
static const NSInteger kChatMuteBarTag = 0x9020;
static const NSInteger kChatJoinGroupBarTag = 0x9021;
static const NSInteger kChatJoinChannelBarTag = 0x9022;
static const NSInteger kChatDiscussBarTag = 0x9023;
static const NSInteger kChatChannelBottomBarTag = 0x9024;

#pragma mark - controller


@implementation TGChatViewController (TGChatViewPinned)

#pragma mark - pinned message

/// A strip under the navigation bar, the way clients surface what is pinned.
- (void)loadPinnedMessage {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] pinnedMessageForChat:self.chatId completion:^(NSDictionary *m){
		TGChatViewController *me = weakSelf;
		me.pinnedMessageId = [m[@"id"] longLongValue];
		NSString *text = [m[@"text"] isKindOfClass:NSString.class] ? m[@"text"] : nil;
		if (!text.length && me.pinnedMessageId)
			text = TGDescribeMessageContent(m);
		if (!text.length){
			[me hidePinnedBanner];
			return;
		}
		NSArray *entities = [m[@"entities"] isKindOfClass:NSArray.class] ? m[@"entities"] : nil;
		NSNumber *thumb = [m[@"photoId"] isKindOfClass:NSNumber.class] ? m[@"photoId"]
				: ([m[@"thumbFileId"] isKindOfClass:NSNumber.class] ? m[@"thumbFileId"] : nil);
		me.pinnedThumbnailFileId = thumb.longLongValue;
		[me showPinnedBanner:text entities:entities];
	}];
}

/// Takes the strip away and gives the list back the room it had. Reached
/// when the pinned message is unpinned from the message menu.
- (void)hidePinnedBanner {
	UIView *banner = self.pinnedBannerView;
	if (!banner)
		return;

	// A show bumps the tag, so even a hide that finishes late can tell that
	// a newer pin has taken the strip back over.
	NSInteger generation = banner.tag;
	[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
		banner.alpha = TGAlphaTransparent;
		banner.transform = CGAffineTransformMakeTranslation(0, -kPinnedBanner);
	} completion:^(BOOL finished){
		// A show that overtook this hide keeps the banner and restores it;
		// only the hide that still owns it may take it down and give the
		// table its room back.
		if (self.pinnedBannerView != banner || banner.tag != generation)
			return;
		[banner removeFromSuperview];
		self.pinnedBannerView = nil;
		self.pinnedBannerHair = nil;

		UIEdgeInsets insets = self.table.contentInset;
		insets.top = MAX(0, insets.top - kPinnedBanner);
		self.table.contentInset = insets;
		self.table.scrollIndicatorInsets = insets;
	}];
}

- (void)pinnedCloseTapped {
	int64_t pinnedId = self.pinnedMessageId;
	if (pinnedId)
		[[TGClient shared] unpinMessage:pinnedId inChat:self.chatId];
	self.pinnedMessageId = 0;
	[self hidePinnedBanner];
}

- (void)showPinnedBanner:(NSString *)text {	[self showPinnedBanner:text entities:nil];
}

- (void)showPinnedBanner:(NSString *)text entities:(NSArray *)entities {
	// A second pin updates the strip in place: recreating it would blink the
	// whole banner and churn the table inset.
	if (self.pinnedBannerView) {
		self.pinnedBannerView.tag++;
		UILabel *body = (UILabel *)[self.pinnedBannerView viewWithTag:kPinnedBodyTag];
		if ([body isKindOfClass:UILabel.class]) {
			BOOL textChanged = ![body.text isEqualToString:text];
			if (textChanged) {
				CATransition *fade = [CATransition animation];
				fade.type = kCATransitionFade;
				fade.duration = TGAnimationDurationFast;
				[body.layer addAnimation:fade forKey:@"pinnedTextFade"];
			}
			if (entities.count && text.length) {
				body.attributedText = TGAttributedMessageText(text, entities, body.font, body.textColor);
			} else {
				body.text = text;
			}
		}
		// This pin may have arrived while the strip was sliding away. A fresh
		// animation on the same two properties cancels that hide and puts the
		// strip back, even when the hide had not started yet.
		UIImageView *thumb = (UIImageView *)[self.pinnedBannerView viewWithTag:kPinnedThumbTag];
		if (thumb && self.pinnedThumbnailFileId){
			int64_t fileId = self.pinnedThumbnailFileId;
			__weak typeof(self) weakSelf = self;
			[[TGClient shared] downloadFile:fileId completion:^(NSString *path){
				if (!path.length || !weakSelf.pinnedBannerView)
					return;
				UIImage *photo = [UIImage imageWithContentsOfFile:path];
				if (!photo)
					return;
				dispatch_async(dispatch_get_main_queue(), ^{
					UIImageView *view = (UIImageView *)[weakSelf.pinnedBannerView
							viewWithTag:kPinnedThumbTag];
					view.image = photo;
				});
			}];
		}
		[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
			self.pinnedBannerView.alpha = TGAlphaOpaque;
			self.pinnedBannerView.transform = CGAffineTransformIdentity;
		}];
		return;
	}

	CGRect b = self.view.bounds;
	TGTheme *theme = [TGTheme shared];
	UIView *banner = [[UIView alloc] initWithFrame:CGRectMake(0, 0, b.size.width,
			kPinnedBanner)];
	banner.backgroundColor = [theme inputBarColour];
	banner.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	UIView *stripe = [[UIView alloc] initWithFrame:CGRectMake(TGMetricPad,
			TGMetricPadSmall, kQuoteBarWidth, kPinnedBanner - TGMetricPadMedium)];
	stripe.backgroundColor = [theme accentColour];
	[banner addSubview:stripe];

	// The pin says what the strip is before the words are read. When the
	// message has a picture, the picture takes the mark's place, as official
	// shows a 36 pt thumbnail before the text.
	BOOL hasThumb = self.pinnedThumbnailFileId != 0;
	CGFloat textX = hasThumb ? TGMetricPadLarge + kPinnedThumbSide + TGMetricPad
							 : kPinnedTextX;
	if (hasThumb){
		UIImageView *thumb = [[UIImageView alloc] initWithFrame:CGRectMake(
				TGMetricPadLarge, TGCenteredOrigin(kPinnedBanner, kPinnedThumbSide),
				kPinnedThumbSide, kPinnedThumbSide)];
		thumb.tag = kPinnedThumbTag;
		thumb.contentMode = UIViewContentModeScaleAspectFill;
		thumb.clipsToBounds = YES;
		thumb.layer.cornerRadius = TGMetricCornerSmall;
		[banner addSubview:thumb];
		int64_t fileId = self.pinnedThumbnailFileId;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] downloadFile:fileId completion:^(NSString *path){
			if (!path.length || !weakSelf.pinnedBannerView)
				return;
			UIImage *photo = [UIImage imageWithContentsOfFile:path];
			if (!photo)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				UIImageView *view = (UIImageView *)[weakSelf.pinnedBannerView
						viewWithTag:kPinnedThumbTag];
				view.image = photo;
			});
		}];
	} else {
		UIImageView *pin = [[UIImageView alloc] initWithFrame:CGRectMake(
				TGMetricPadLarge, TGCenteredOrigin(kPinnedBanner, kPinnedGlyph),
				kPinnedGlyph, kPinnedGlyph)];
		pin.image = [TGIcons glyphNamed:@"pin" colour:[theme accentColour]
								  side:kPinnedGlyph];
		pin.contentMode = UIViewContentModeCenter;
		[banner addSubview:pin];
	}

	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(textX, TGMetricPadSmall,
			b.size.width - textX - TGMetricPad, TGMetricLineBody)];
	label.text = @"Pinned Message";
	label.font = TGFontBodyStrong();
	label.textColor = [theme accentColour];
	label.backgroundColor = [UIColor clearColor];
	[banner addSubview:label];

	UILabel *body = [[UILabel alloc] initWithFrame:CGRectMake(textX,
			TGMetricPadSmall + TGMetricLineBody,
			b.size.width - textX - TGMetricPad, TGMetricLineBody)];
	body.tag = kPinnedBodyTag;
	body.font = TGFontBody();
	body.textColor = [theme primaryTextColour];
	body.backgroundColor = [UIColor clearColor];
	body.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	if (entities.count && text.length) {
		body.attributedText = TGAttributedMessageText(text, entities, body.font, body.textColor);
	} else {
		body.text = text;
	}
	[banner addSubview:body];

	// The X unpins, as the official strip's close control does.
	CGFloat closeSide = TGMetricButtonMediumH;
	UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
	close.frame = CGRectMake(b.size.width - closeSide, TGCenteredOrigin(kPinnedBanner,
			closeSide), closeSide, closeSide);
	close.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[close setImage:[TGIcons glyphNamed:@"close" colour:[theme secondaryTextColour]
								   side:TGMetricMenuGlyph] forState:UIControlStateNormal];
	[close addTarget:self action:@selector(pinnedCloseTapped)
			forControlEvents:UIControlEventTouchUpInside];
	[banner addSubview:close];
	label.frame = CGRectMake(textX, TGMetricPadSmall,
			b.size.width - textX - closeSide - TGMetricPad, TGMetricLineBody);
	body.frame = CGRectMake(textX, TGMetricPadSmall + TGMetricLineBody,
			b.size.width - textX - closeSide - TGMetricPad, TGMetricLineBody);

	UIView *hair = [[UIView alloc] initWithFrame:CGRectMake(0,
			kPinnedBanner - TGMetricBorderWidth, b.size.width, TGMetricBorderWidth)];
	hair.backgroundColor = [theme separatorColour];
	hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[banner addSubview:hair];

	// It starts under the bar and slides down into place; only transform and
	// alpha move, because the frame is the table's business.
	banner.alpha = TGAlphaTransparent;
	banner.transform = CGAffineTransformMakeTranslation(0, -kPinnedBanner);
	[self.view addSubview:banner];
	// Tapping the strip goes to what is pinned, which is the whole reason a
	// client shows it. It had no tap handler at all.
	banner.userInteractionEnabled = YES;
	[banner addGestureRecognizer:[[UITapGestureRecognizer alloc]
			initWithTarget:self action:@selector(pinnedBannerTapped)]];
	[banner addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(pinnedBannerHeld:)]];

	self.pinnedBannerView = banner;
	self.pinnedBannerHair = hair;

	// Push the message list down so the banner does not cover the first row.
	UIEdgeInsets insets = self.table.contentInset;
	insets.top += kPinnedBanner;
	self.table.contentInset = insets;
	self.table.scrollIndicatorInsets = insets;

	[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
		banner.alpha = TGAlphaOpaque;
		banner.transform = CGAffineTransformIdentity;
	}];
}


@end
