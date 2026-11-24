//
// TGNameWithStatus.m - name string unified with emoji status attachment.
//
#import "TGNameWithStatus.h"
#import "TGCustomEmojiStore.h"
#import "TGStyle.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import <math.h>

@interface NSAttributedString (TGNameWithStatusAttachment)
+ (NSAttributedString *)attributedStringWithAttachment:(id)attachment;
@end

@interface NSObject (TGNameWithStatusAttachmentProtocol)
- (void)setImage:(UIImage *)image;
- (void)setBounds:(CGRect)bounds;
@end

NSAttributedString *TGNameWithStatus(NSString *name, int64_t statusEmojiId, UIFont *font, UIColor *colour) {
	return TGNameWithBadges(name, statusEmojiId, NO, NO, font, colour);
}

NSAttributedString *TGNameWithBadges(NSString *name, int64_t statusEmojiId, BOOL verified, BOOL premium, UIFont *font, UIColor *colour) {
	if (!name) {
		name = @"";
	}
	if (!font) {
		font = TGFontBody();
	}
	if (!colour) {
		colour = [[TGTheme shared] primaryTextColour];
	}

	NSDictionary *baseAttrs = @{
		NSFontAttributeName: font,
		NSForegroundColorAttributeName: colour
	};

	if (statusEmojiId == 0 && !verified && !premium) {
		return [[NSAttributedString alloc] initWithString:name attributes:baseAttrs];
	}

	Class attachmentClass = NSClassFromString(@"NSTextAttachment");
	// iOS 6's private NSTextAttachment has no -setBounds:, so the picture
	// would be laid out at its own size; the name alone reads better.
	if (!attachmentClass ||
		![attachmentClass instancesRespondToSelector:@selector(setBounds:)] ||
		![NSAttributedString respondsToSelector:@selector(attributedStringWithAttachment:)]) {
		return [[NSAttributedString alloc] initWithString:name attributes:baseAttrs];
	}

	CGFloat side = font ? ceilf(font.lineHeight) : TGMetricLineBody;
	CGFloat descender = font ? roundf(font.descender) : TGMetricZero;

	NSMutableAttributedString *res = [[NSMutableAttributedString alloc] initWithString:name attributes:baseAttrs];

	if (verified) {
		UIImage *badge = [TGIcons verifiedBadge];
		if (badge) {
			id attachment = [[attachmentClass alloc] init];
			if ([attachment respondsToSelector:@selector(setImage:)])
				[attachment setImage:badge];
			if ([attachment respondsToSelector:@selector(setBounds:)])
				[attachment setBounds:CGRectMake(TGMetricZero, descender, side, side)];
			[res appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:baseAttrs]];
			NSAttributedString *attachStr = [NSAttributedString attributedStringWithAttachment:attachment];
			if (attachStr)
				[res appendAttributedString:attachStr];
		}
	}

	if (statusEmojiId != 0) {
		UIImage *image = [[TGCustomEmojiStore shared] imageForId:statusEmojiId side:side];
		if (image) {
			id attachment = [[attachmentClass alloc] init];
			if ([attachment respondsToSelector:@selector(setImage:)])
				[attachment setImage:image];
			if ([attachment respondsToSelector:@selector(setBounds:)])
				[attachment setBounds:CGRectMake(TGMetricZero, descender, side, side)];
			[res appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:baseAttrs]];
			NSAttributedString *attachStr = [NSAttributedString attributedStringWithAttachment:attachment];
			if (attachStr)
				[res appendAttributedString:attachStr];
		}
	} else if (premium && !verified) {
		UIImage *star = [TGIcons glyphNamed:@"star" colour:colour side:side];
		if (star) {
			id attachment = [[attachmentClass alloc] init];
			if ([attachment respondsToSelector:@selector(setImage:)])
				[attachment setImage:star];
			if ([attachment respondsToSelector:@selector(setBounds:)])
				[attachment setBounds:CGRectMake(TGMetricZero, descender, side, side)];
			[res appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:baseAttrs]];
			NSAttributedString *attachStr = [NSAttributedString attributedStringWithAttachment:attachment];
			if (attachStr)
				[res appendAttributedString:attachStr];
		}
	}

	return res;
}
