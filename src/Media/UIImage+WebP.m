//
// UIImage+WebP - decode WebP images with libwebp.
//
#import "UIImage+WebP.h"
#import "TGStickerImage.h"
#import "TGStyle.h"
#import "WebP.framework/Headers/decode.h"

static const uint64_t kTGWebPMaxDecodedBytes = 16ull * 1024 * 1024;

/// CGDataProvider owns the buffer once created and frees it through this.
static void tgFreePixels(void *info, const void *data, size_t size) {
	free((void *)data);
}

@implementation UIImage (WebP)

+ (UIImage *)convertFromWebP:(NSString *)filePath
			  compressedData:(__autoreleasing NSData **)compressedData
					   error:(NSError **)error
{
	NSData *data = [NSData dataWithContentsOfFile:filePath];
	if (!data.length)
		return nil;
	if (compressedData)
		*compressedData = data;

	int width = 0, height = 0;
	if (!WebPGetInfo(data.bytes, data.length, &width, &height) ||
		width <= 0 || height <= 0)
		return nil;

	// The header is the sender's claim. 16383 x 16383 is a valid WebP and a
	// 1 GB bitmap; nothing this app draws from WebP is past 512 px, so a
	// picture over the 16 MB cache ceiling is refused, not decoded.
	if ((uint64_t)width * (uint64_t)height * 4 > kTGWebPMaxDecodedBytes)
		return nil;

	// RGBA, 4 bytes per pixel, straight into a buffer CGImage can own.
	size_t stride = (size_t)width * 4;
	size_t size = stride * (size_t)height;
	uint8_t *pixels = malloc(size);
	if (!pixels)
		return nil;

	if (!WebPDecodeRGBAInto(data.bytes, data.length, pixels, size, (int)stride)){
		free(pixels);
		return nil;
	}

	CGDataProviderRef provider =
		CGDataProviderCreateWithData(NULL, pixels, size, tgFreePixels);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGImageRef cgImage = CGImageCreate(width, height, 8, 32, stride, space,
			// WebPDecodeRGBAInto writes straight alpha. Labelled premultiplied,
			// every half-transparent edge pixel drew too bright - a pale rim
			// round a sticker on a dark bubble.
			kCGBitmapByteOrderDefault | kCGImageAlphaLast,
			provider, NULL, NO, kCGRenderingIntentDefault);

	UIImage *image = cgImage ? [UIImage imageWithCGImage:cgImage] : nil;

	if (cgImage) CGImageRelease(cgImage);
	CGColorSpaceRelease(space);
	CGDataProviderRelease(provider);

	return image;
}

+ (UIImage *)convertFromGZippedData:(NSString *)filePath size:(CGSize)size {
	// .tgs stickers are gzipped Lottie JSON - vector animation. Rendering that
	// needs a Lottie player, which this app does not have, so the caller falls
	// back to the sticker's emoji.
	return nil;
}

/// Drawing through UIKit first, rather than handing `CGImage` straight to
/// the encoder, applies the EXIF orientation a camera roll picture carries:
/// `CGImage` has no such field, and a sideways sticker is the bug that
/// follows from ignoring it. The bitmap is already the square Telegram
/// wants, so the encoder only has to compress it.
+ (NSData *)webPDataFromImage:(UIImage *)image quality:(CGFloat)quality {
	if (!image)
		return nil;
	CGSize size = image.size;
	if (size.width <= 0 || size.height <= 0)
		return nil;

	CGFloat side = TGMetricStickerSide;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 1.0f);
	if (!UIGraphicsGetCurrentContext())
		return nil;
	CGFloat scale = MIN(side / size.width, side / size.height);
	CGFloat drawWidth = size.width * scale;
	CGFloat drawHeight = size.height * scale;
	[image drawInRect:CGRectMake((side - drawWidth) / 2.0f,
								 (side - drawHeight) / 2.0f,
								 drawWidth, drawHeight)];
	UIImage *padded = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (!padded)
		return nil;
	return TGStickerImageWebPData(padded.CGImage, (size_t)side, (float)quality);
}

@end

// vim:ft=objc
