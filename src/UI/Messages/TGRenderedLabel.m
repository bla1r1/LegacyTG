//
// TGRenderedLabel.m - see TGRenderedLabel.h.
//
#import "TGRenderedLabel.h"
#import "TGTextRender.h"
#import "TGMessageLayout.h"
#import <QuartzCore/QuartzCore.h>

@implementation TGRenderedLabel

+ (BOOL)wanted {
	return !TGCustomEmojiInlineSupported();
}

- (void)setRenderKey:(NSString *)renderKey {
	if (renderKey == _renderKey || [renderKey isEqualToString:_renderKey])
		return;
	_renderKey = [renderKey copy];
	[self.layer setNeedsDisplay];
}

/// CALayer asks this instead of drawing through drawRect:. A keyed body takes
/// its picture from the cache or draws it now with the same engine; anything
/// else is drawn by UILabel's own drawRect: into an image, as UIKit would.
- (void)displayLayer:(CALayer *)layer {
	CGSize size = self.bounds.size;
	CGFloat scale = [UIScreen mainScreen].scale;
	if (size.width <= 0 || size.height <= 0) {
		layer.contents = nil;
		return;
	}
	NSAttributedString *text = self.renderKey ? self.attributedText : nil;
	if (text && TGTextRenderCan(text)) {
		CGImageRef image = TGTextRenderCached(self.renderKey);
		if (!image) {
			image = TGTextRenderCreateImage(text, size, scale);
			TGTextRenderStore(self.renderKey, image);
			CGImageRelease(image);
			image = TGTextRenderCached(self.renderKey);
		}
		layer.contentsScale = scale;
		layer.contents = (__bridge id)image;
		return;
	}
	UIGraphicsBeginImageContextWithOptions(size, NO, scale);
	[self drawRect:self.bounds];
	UIImage *drawn = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	layer.contentsScale = scale;
	layer.contents = (__bridge id)drawn.CGImage;
}

@end
