//
// TGChatGeometry.h - the chat screen's own dimensions.
//
// These belong to no other screen: a call bubble's width allowance means
// nothing to the settings list. They live here instead of in TGStyle
// because a name in TGStyle that only one file reads is how the token
// layer came to hold more names than values. What they are built from is
// TGStyle's, so a change to the spacing or the line scale reaches them.
//
#ifndef TGCHATGEOMETRY_H
#define TGCHATGEOMETRY_H

#import "TGChatViewController.h"
#import "TGBubbleCell.h"
#import "TGStyle.h"
#import "TGMessageMetrics.h"
#import "TGChatActionMenuModel.h"

static const CGFloat kInputHeight = TGMetricInputBarHeight;
/// The channel bottom bar: button height and icon sizes.
static const CGFloat kChannelBarIconSide     = TGMetricMenuGlyph;

// ── the chat's own geometry ──────────────────────────────────────────────────
// This screen's own dimensions, which no other screen has any use for: a call
// bubble's width allowance means nothing to the settings list. They live here
// instead of in TGStyle because a name in TGStyle that only one file reads is
// how the token layer came to hold more names than values. What they are built
// from is TGStyle's, so a change to the spacing or the line scale reaches them.

/// A call bubble's arrow, and the button on its right.
static const CGFloat kCallArrow       = 16.0f;
static const CGFloat kCallButton      = 32.0f;
/// A contact bubble: the initials disc, and where its two buttons begin.
static const CGFloat kContactDisc     = 42.0f;
static const CGFloat kContactDiscTop  = TGMetricPad;
static const CGFloat kContactButtons  = TGMetricPersonRow;
/// A file or contact bubble's text column, which clears the tile beside it.
static const CGFloat kTileTextGap     = TGMetricPadMedium;
/// A file bubble's name, which may wrap to two lines, and its meta line.
static const CGFloat kFileNameBlock   = TGMetricLineBody + TGMetricLineBody;
static const CGFloat kFileMetaTop     = TGMetricPad + TGMetricLineBody + TGMetricLineBody
		+ TGMetricPadTiny;
/// A location bubble: the pin over the map, and the attribution strip.
static const CGFloat kMapPinWidth     = 28.0f;
static const CGFloat kMapPinHeight    = 36.0f;
static const CGFloat kMapPinLift      = TGMetricPadSmall;
static const CGFloat kMapCreditWidth  = 68.0f;
/// A voice note: the play disc, the waveform, and the duration under it.
static const CGFloat kVoiceDisc       = 36.0f;
static const CGFloat kVoiceWaveHeight = TGMetricLineBody;
static const CGFloat kVoiceWaveTop    = TGMetricPadMedium;
static const CGFloat kVoiceClockMinimum = 44.0f;
/// The play disc over a video, and the one over an animation.
static const CGFloat kVideoDisc       = 48.0f;
static const CGFloat kGifDisc         = 42.0f;
/// A caption plate on a picture: how far in it sits, and the room it keeps.
static const CGFloat kCaptionInset    = TGMetricPadSmall;

// ── the record bar and the player bar ───────────────────────────────────────
// The two strips that take the composer's place: one while a voice note is
// being recorded, one while a track is playing.

/// The "slide to cancel" line, over TGRecordBar.
static const CGFloat kRecordSlideX    = 100.0f;
static const CGFloat kRecordSlideRoom = 180.0f;
/// The lock pill above the mic: a padlock over an arrow.
static const CGFloat kRecordLockGlyph = 18.0f;
static const CGFloat kRecordLockArrow = 16.0f;
static const CGFloat kRecordLockArrowY = 36.0f;
static const CGFloat kRecordLockRest  = TGMetricPadMedium;
static const CGFloat kRecordLockLift  = TGMetricPadLarge;
/// The player bar: artwork, a play button, two lines of text, a clock, and
/// the transport buttons that only a music track gets.
static const CGFloat kPlayerArtX      = TGMetricPad;
static const CGFloat kPlayerArtLift   = 1.0f;
static const CGFloat kPlayerButton    = 28.0f;
static const CGFloat kPlayerButtonGap = TGMetricPadSmall;
static const CGFloat kPlayerArtGap    = 6.0f;
static const CGFloat kPlayerCloseW    = TGMetricCloseSide;
static const CGFloat kPlayerRightEdge = 38.0f;
static const CGFloat kPlayerClockW    = 72.0f;
static const CGFloat kPlayerClockDrop = TGMetricPad;
static const CGFloat kPlayerSpeedW    = 40.0f;
static const CGFloat kPlayerTextMin   = 40.0f;
static const CGFloat kPlayerProgressH = TGMetricPadTiny;
/// The bar's two lines are packed into the height of the button beside them,
/// so they are tighter than the line scale and say so here rather than
/// borrowing a name from it.
static const CGFloat kPlayerTitleLine  = 15.0f;
static const CGFloat kPlayerDetailLine = 13.0f;
/// The mode the recording button was left in, written by the chat that changed
/// it and read back by whichever chat opens next - Telegram keeps the choice
/// made in one chat for every other one.
static NSString *const kRecordVideoModeKey = @"currentModeVideo";
/// The little plate that says a file is being fetched.
static const CGFloat kHUDWidth        = 110.0f;
static const CGFloat kHUDHeight       = TGMetricListAvatar;
// The percent label and the progress bar ride inside downloadHUD; cells use
// this tag range too.
static const NSInteger kHUDPercentTag = 0x9102;
static const NSInteger kHUDBarTag     = 0x9103;
/// The title view in the navigation bar: the chat's name over who is there.
static const CGFloat kTitleWidth      = 200.0f;
static const CGFloat kTitleRow        = TGMetricListAvatar;
/// The pinned-message strip under the navigation bar.
static const CGFloat kPinnedBanner    = 50.0f;
/// The cross that dismisses the banner.
static const CGFloat kBannerCloseGlyph = 16.0f;

// The three placers a cell configure uses; pure functions over the cell's
// own parts.

static inline void TGPlaceStamp(TGBubbleCell *cell, CGRect bubbleFrame,
								CGFloat timeWidth, BOOL mine) {
	CGFloat eyeRoom = 0;
	if (cell.viewsEye && !cell.viewsEye.hidden) {
		eyeRoom = kStampEyeSide + kStampEyePad - TGMetricPadTiny;
		CGFloat textRight = bubbleFrame.size.width - kPadH - (mine ? TGMetricStampTicksRoom : 0);
		CGFloat stampY = bubbleFrame.size.height - TGMetricStampBottomInset;
		cell.viewsEye.frame = CGRectMake(
				TGStampEyeX(textRight, cell.time.text),
				stampY + TGCenteredOrigin(TGMetricStampHeight, kStampEyeSide),
				kStampEyeSide,
				kStampEyeSide);
	}
	cell.time.frame = CGRectMake(
			bubbleFrame.size.width - timeWidth - kPadH + eyeRoom,
			bubbleFrame.size.height - TGMetricStampBottomInset,
			timeWidth - (mine ? TGMetricStampTicksRoom : 0) - eyeRoom,
			TGMetricStampHeight);
}

static inline void TGPlaceTicks(TGBubbleCell *cell, CGRect bubbleFrame) {
	CGFloat stampTop = cell.time.frame.origin.y > 0 ? cell.time.frame.origin.y : (bubbleFrame.size.height - TGMetricStampBottomInset);
	cell.ticks.frame = CGRectMake(
			bubbleFrame.size.width - kPadH - TGMetricTicksWidth,
			stampTop + TGCenteredOrigin(TGMetricStampHeight, TGMetricTicksHeight),
			TGMetricTicksWidth, TGMetricTicksHeight);
}

static inline void TGPlaceTitleDetail(TGBubbleCell *cell, CGFloat x, CGFloat top,
									  CGFloat width) {
	cell.body.frame = CGRectMake(x, top + TGMetricBubbleTitleTop, width,
								 TGMetricBubbleTitleHeight);
	cell.subtitle.frame = CGRectMake(x, top + TGMetricBubbleDetailTop, width,
									 TGMetricBubbleDetailHeight);
}

UIColor *TGSenderColour(int64_t userId);


#endif // TGCHATGEOMETRY_H
