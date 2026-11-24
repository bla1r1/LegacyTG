#import "TGQRCode.h"
#import "qrcodegen.h"

UIImage *TGQRCodeImage(NSString *string, CGFloat size) {
	if (!string.length || size <= 0)
		return nil;

	uint8_t qrcode[qrcodegen_BUFFER_LEN_MAX];
	uint8_t tempBuffer[qrcodegen_BUFFER_LEN_MAX];
	bool ok = qrcodegen_encodeText([string UTF8String], tempBuffer, qrcode,
								   qrcodegen_Ecc_MEDIUM,
								   qrcodegen_VERSION_MIN, qrcodegen_VERSION_MAX,
								   qrcodegen_Mask_AUTO, true);
	if (!ok)
		return nil;

	int qrSize = qrcodegen_getSize(qrcode);
	if (qrSize <= 0)
		return nil;

	int margin = 2; // quiet zone
	int totalModules = qrSize + margin * 2;
	CGFloat scale = floorf(size / (CGFloat)totalModules);
	if (scale < 1.0f)
		scale = 1.0f;
	CGFloat actualDim = (CGFloat)totalModules * scale;
	size_t pixelDim = (size_t)actualDim;

	CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
	CGContextRef bitmap = CGBitmapContextCreate(NULL, pixelDim, pixelDim, 8, 0, gray,
												(CGBitmapInfo)kCGImageAlphaNone);
	CGColorSpaceRelease(gray);
	if (!bitmap)
		return nil;

	// Fill background white
	CGContextSetGrayFillColor(bitmap, 1.0f, 1.0f);
	CGContextFillRect(bitmap, CGRectMake(0, 0, actualDim, actualDim));

	// Draw black modules
	CGContextSetGrayFillColor(bitmap, 0.0f, 1.0f);
	for (int y = 0; y < qrSize; y++) {
		for (int x = 0; x < qrSize; x++) {
			if (qrcodegen_getModule(qrcode, x, y)) {
				// CoreGraphics coordinate space has origin at bottom-left:
				CGRect r = CGRectMake((x + margin) * scale,
									  (qrSize - 1 - y + margin) * scale,
									  scale, scale);
				CGContextFillRect(bitmap, r);
			}
		}
	}

	CGImageRef imgRef = CGBitmapContextCreateImage(bitmap);
	CGContextRelease(bitmap);
	UIImage *image = imgRef ? [UIImage imageWithCGImage:imgRef] : nil;
	if (imgRef)
		CGImageRelease(imgRef);
	return image;
}
