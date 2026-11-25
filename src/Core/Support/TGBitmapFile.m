//
// TGBitmapFile.m - see TGBitmapFile.h.
//
#import "TGBitmapFile.h"

typedef struct { uint32_t magic, width, height, bytesPerRow; } TGBitmapHeader;
static const uint32_t kTGBitmapMagic = 0x31424754; // "TGB1"

CGBitmapInfo TGBitmapFileInfo(void) {
	return kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little;
}

BOOL TGBitmapWrite(CGImageRef image, NSString *path) {
	size_t w = image ? CGImageGetWidth(image) : 0, h = image ? CGImageGetHeight(image) : 0;
	if (!w || !h)
		return NO;
	NSMutableData *data = [NSMutableData dataWithLength:sizeof(TGBitmapHeader) + w * 4 * h];
	TGBitmapHeader *header = (TGBitmapHeader *)data.mutableBytes;
	*header = (TGBitmapHeader){ kTGBitmapMagic, (uint32_t)w, (uint32_t)h, (uint32_t)(w * 4) };
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate((uint8_t *)data.mutableBytes + sizeof(TGBitmapHeader),
			w, h, 8, w * 4, space, TGBitmapFileInfo());
	CGColorSpaceRelease(space);
	if (!ctx)
		return NO;
	CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), image);
	CGContextRelease(ctx);
	[[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
			withIntermediateDirectories:YES attributes:nil error:NULL];
	return [data writeToFile:path atomically:YES];
}

/// +1 image over the file's bytes, NULL when it is not one of ours.
CGImageRef TGBitmapCreate(NSString *path) {
	NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:NULL];
	if (data.length < sizeof(TGBitmapHeader))
		return NULL;
	TGBitmapHeader header;
	memcpy(&header, data.bytes, sizeof(header));
	if (header.magic != kTGBitmapMagic || !header.width || !header.height ||
			header.width > 4096 || header.height > 4096)
		return NULL;
	uint64_t minRow = (uint64_t)header.width * 4ULL;
	uint64_t pixelBytes = (uint64_t)header.bytesPerRow * (uint64_t)header.height;
	if ((uint64_t)header.bytesPerRow < minRow ||
			pixelBytes > (64ULL * 1024ULL * 1024ULL) ||
			(uint64_t)data.length - sizeof(header) < pixelBytes)
		return NULL;
	CFDataRef pixels = CFDataCreate(NULL, (const UInt8 *)data.bytes + sizeof(header),
			(CFIndex)pixelBytes);
	CGDataProviderRef provider = CGDataProviderCreateWithCFData(pixels);
	CFRelease(pixels);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGImageRef image = CGImageCreate(header.width, header.height, 8, 32, header.bytesPerRow, space,
			TGBitmapFileInfo(), provider, NULL, false, kCGRenderingIntentDefault);
	CGColorSpaceRelease(space);
	CGDataProviderRelease(provider);
	return image;
}

