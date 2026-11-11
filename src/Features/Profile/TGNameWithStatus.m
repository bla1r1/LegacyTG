//
// TGNameWithStatus.m - name string unified with emoji status attachment.
//
#import "TGNameWithStatus.h"
#import "TGCustomEmojiStore.h"
#import "TGStyle.h"
#import "TGTheme.h"
#import <math.h>

@interface NSAttributedString (TGNameWithStatusAttachment)
+ (NSAttributedString *)attributedStringWithAttachment:(id)attachment;
@end

@interface NSObject (TGNameWithStatusAttachmentProtocol)
- (void)setImage:(UIImage *)image;
- (void)setBounds:(CGRect)bounds;
@end

NSAttributedString *TGNameWithStatus(NSString *name, int64_t statusEmojiId, UIFont *font, UIColor *colour) {
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

	if (statusEmojiId == 0) {
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
	UIImage *image = [[TGCustomEmojiStore shared] imageForId:statusEmojiId side:side];
	if (!image) {
		return [[NSAttributedString alloc] initWithString:name attributes:baseAttrs];
	}

	id attachment = [[attachmentClass alloc] init];
	if ([attachment respondsToSelector:@selector(setImage:)]) {
		[attachment setImage:image];
	}
	if ([attachment respondsToSelector:@selector(setBounds:)]) {
		CGFloat descender = font ? roundf(font.descender) : TGMetricZero;
		[attachment setBounds:CGRectMake(TGMetricZero, descender, side, side)];
	}

	NSMutableAttributedString *res = [[NSMutableAttributedString alloc] initWithString:name attributes:baseAttrs];
	[res appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:baseAttrs]];
	NSAttributedString *attachStr = [NSAttributedString attributedStringWithAttachment:attachment];
	if (attachStr) {
		[res appendAttributedString:attachStr];
	}
	return res;
}
