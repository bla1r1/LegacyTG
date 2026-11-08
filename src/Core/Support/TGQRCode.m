#import "TGQRCode.h"
#import <CoreImage/CoreImage.h>

UIImage *TGQRCodeImage(NSString *string, CGFloat size) {
	if (!string.length || size <= 0)
		return nil;
	CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
	// iOS 6 ships this filter unannounced and without a correction-level
	// input: setting that key raises NSUnknownKeyException. Only keys the
	// filter lists are set.
	NSArray *keys = filter.inputKeys;
	if (![keys containsObject:@"inputMessage"])
		return nil;
	[filter setValue:[string dataUsingEncoding:NSUTF8StringEncoding]
			  forKey:@"inputMessage"];
	if ([keys containsObject:@"inputCorrectionLevel"])
		[filter setValue:@"M" forKey:@"inputCorrectionLevel"];
	CIImage *output = filter.outputImage;
	if (!output)
		return nil;

	CGRect extent = CGRectIntegral(output.extent);
	if (CGRectIsEmpty(extent))
		return nil;
	CGFloat scale = MIN(size / CGRectGetWidth(extent), size / CGRectGetHeight(extent));
	size_t width = (size_t)(CGRectGetWidth(extent) * scale);
	size_t height = (size_t)(CGRectGetHeight(extent) * scale);
	// The software renderer: a GPU-backed CIContext faulted on the A4, and a
	// QR code is a few hundred black squares.
	CIContext *context = [CIContext contextWithOptions:
			@{kCIContextUseSoftwareRenderer : @YES}];
	CGImageRef code = [context createCGImage:output fromRect:extent];
	if (!code)
		return nil;
	CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
	CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, 0, gray,
			(CGBitmapInfo)kCGImageAlphaNone);
	CGColorSpaceRelease(gray);
	if (!bitmap){
		CGImageRelease(code);
		return nil;
	}
	// Nearest-neighbour keeps the modules sharp when scaled up.
	CGContextSetInterpolationQuality(bitmap, kCGInterpolationNone);
	CGContextScaleCTM(bitmap, scale, scale);
	CGContextDrawImage(bitmap, extent, code);
	CGImageRef scaled = CGBitmapContextCreateImage(bitmap);
	CGContextRelease(bitmap);
	CGImageRelease(code);
	UIImage *image = scaled ? [UIImage imageWithCGImage:scaled] : nil;
	if (scaled)
		CGImageRelease(scaled);
	return image;
}
