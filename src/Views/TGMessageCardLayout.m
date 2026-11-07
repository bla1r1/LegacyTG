// The card's geometry, apart from the view so host tests can measure it.
#import "TGMessageCardView.h"
#import "TGMessageLayout.h"
#import "TGStyle.h"
#import <dlfcn.h>
#import <math.h>
#import <string.h>

static const CGFloat kCardThumb = TGMetricPersonRow;   // square picture side
static const CGFloat kCardGap = TGMetricPad;           // picture to text, text to button
static const CGFloat kCardLineGap = TGMetricPadTiny;   // between text rows
static const CGFloat kWideAspectThreshold = 1.01f;

TGMessageCardFrames TGMessageCardLayout(TGMessageCard *card, CGFloat width) {
	TGMessageCardFrames frames;
	memset(&frames, 0, sizeof(frames));

	if (!card || width <= 0.0f) {
		return frames;
	}

	width = ceil(width);

	// 1. Picture
	CGFloat columnX = 0.0f;
	CGFloat columnWidth = width;
	CGFloat textStartY = 0.0f;

	if (card.imageFileId > 0) {
		if (card.imageAspect > kWideAspectThreshold && !card.imageIsRound) {
			CGFloat imageHeight = ceil(width / card.imageAspect);
			frames.image = CGRectMake(0, 0, width, imageHeight);
			columnX = 0.0f;
			columnWidth = width;
			textStartY = imageHeight + kCardGap;
		} else {
			frames.image = CGRectMake(0, 0, kCardThumb, kCardThumb);
			columnX = kCardThumb + kCardGap;
			columnWidth = MAX(0.0f, width - columnX);
			textStartY = 0.0f;
		}
	}

	// 2. Kicker
	CGFloat currentY = textStartY;
	if (card.kicker.length > 0 && columnWidth > 0.0f) {
		frames.kicker = CGRectMake(columnX, currentY, columnWidth, TGMetricLineCaption);
		currentY = CGRectGetMaxY(frames.kicker) + kCardLineGap;
	}

	// 3. Title
	if (card.title.length > 0 && columnWidth > 0.0f) {
		CGFloat titleHeight = 0.0f;
		if (card.titleStatusEmojiId != 0) {
			typedef NSAttributedString *(*TGNameWithStatusFn)(NSString *, int64_t, UIFont *, UIColor *);
			static TGNameWithStatusFn sTGNameWithStatus = NULL;
			static dispatch_once_t onceToken;
			dispatch_once(&onceToken, ^{
				sTGNameWithStatus = (TGNameWithStatusFn)dlsym(RTLD_DEFAULT, "TGNameWithStatus");
			});
			if (sTGNameWithStatus) {
				NSAttributedString *attr = sTGNameWithStatus(card.title, card.titleStatusEmojiId, TGFontBodyStrong(), nil);
				if (attr && [attr respondsToSelector:@selector(boundingRectWithSize:options:context:)]) {
					CGRect r = [attr boundingRectWithSize:CGSizeMake(columnWidth, CGFLOAT_MAX)
												  options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
												  context:nil];
					titleHeight = ceil(MIN(r.size.height, 2.0f * TGMetricLineBody));
				}
			}
		}
		if (titleHeight <= 0.0f) {
			CGSize measured = TGTextSize(card.title, TGFontBodyStrong(), columnWidth);
			titleHeight = ceil(MIN(measured.height, 2.0f * TGMetricLineBody));
		}
		frames.title = CGRectMake(columnX, currentY, columnWidth, titleHeight);
		currentY = CGRectGetMaxY(frames.title) + kCardLineGap;
	}

	// 4. Lines (up to 4)
	NSUInteger lineCount = [card.lines isKindOfClass:NSArray.class] ? card.lines.count : 0;
	NSUInteger maxLines = sizeof(frames.lines) / sizeof(frames.lines[0]);
	NSUInteger limit = MIN(lineCount, maxLines);
	for (NSUInteger i = 0; i < limit; i++) {
		id lineObj = card.lines[i];
		if ([lineObj isKindOfClass:NSString.class] && [lineObj length] > 0 && columnWidth > 0.0f) {
			// A prize or a description wraps once, as official does; a third
			// line is cut.
			CGFloat measured = TGTextSize(lineObj, TGFontSubhead(), columnWidth).height;
			CGFloat lineHeight = ceil(MAX(TGMetricLineSubhead, MIN(measured, 2.0f * TGMetricLineSubhead)));
			frames.lines[i] = CGRectMake(columnX, currentY, columnWidth, lineHeight);
			currentY = CGRectGetMaxY(frames.lines[i]) + kCardLineGap;
		}
	}

	// 5. Content bottom
	CGFloat textBottom = 0.0f;
	if (!CGRectIsEmpty(frames.kicker)) {
		textBottom = MAX(textBottom, CGRectGetMaxY(frames.kicker));
	}
	if (!CGRectIsEmpty(frames.title)) {
		textBottom = MAX(textBottom, CGRectGetMaxY(frames.title));
	}
	for (NSUInteger i = 0; i < maxLines; i++) {
		if (!CGRectIsEmpty(frames.lines[i])) {
			textBottom = MAX(textBottom, CGRectGetMaxY(frames.lines[i]));
		}
	}

	CGFloat contentBottom = textBottom;
	if (card.imageFileId > 0) {
		if (card.imageAspect > kWideAspectThreshold && !card.imageIsRound) {
			contentBottom = MAX(textBottom, CGRectGetMaxY(frames.image));
		} else {
			contentBottom = MAX(textBottom, kCardThumb);
		}
	}

	// 6. Button
	if (card.buttonTitle.length > 0 && width > 0.0f) {
		CGFloat buttonY = contentBottom + kCardGap;
		frames.button = CGRectMake(0, buttonY, width, TGMetricButtonHeightSmall);
	}

	// 7. Size
	CGFloat lowestBottom = 0.0f;
	if (!CGRectIsEmpty(frames.button)) {
		lowestBottom = CGRectGetMaxY(frames.button);
	} else {
		lowestBottom = contentBottom;
	}

	if (lowestBottom > 0.0f) {
		frames.size = CGSizeMake(width, lowestBottom);
	}

	return frames;
}
