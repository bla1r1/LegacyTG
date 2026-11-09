// TGPatternTests.m - the .tgv pipeline, pinned on the host.
//
// A .tgv is gzip around SVG. These tests feed a tiny gzip SVG through zlib,
// nanosvg and the CoreGraphics renderer, then read the bitmap back: coverage
// must exist, inversion must change the composite, and a four-colour freeform
// fill must put each colour in its own corner.
#import "TGTestRunner.h"
#import "TGPatternImage.h"
#import <UIKit/UIKit.h>
#include <zlib.h>

static NSData *TGPatternDeflate(NSData *source) {
	uLongf bound = compressBound((uLong)source.length);
	NSMutableData *output = [NSMutableData dataWithLength:(NSUInteger)bound];
	if (compress2((Bytef *)output.mutableBytes, &bound,
			(const Bytef *)source.bytes, (uLong)source.length,
			Z_DEFAULT_COMPRESSION) != Z_OK)
		return nil;
	output.length = (NSUInteger)bound;
	return output;
}

static const char *TGPatternFixture =
		"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"32\" "
		"viewBox=\"0 0 32 32\">"
		"<style>.block{fill:#ffffff}</style>"
		"<rect class=\"block\" x=\"4\" y=\"4\" width=\"24\" height=\"24\"/>"
		"<circle cx=\"16\" cy=\"16\" r=\"6\"/>"
		"</svg>";

static void TGPatternPixel(CGImageRef image, size_t x, size_t y, uint8_t out[4]) {
	out[0] = out[1] = out[2] = out[3] = 0;
	CGDataProviderRef provider = CGImageGetDataProvider(image);
	CFDataRef data = provider ? CGDataProviderCopyData(provider) : NULL;
	if (!data)
		return;
	const uint8_t *bytes = CFDataGetBytePtr(data);
	size_t stride = CGImageGetBytesPerRow(image);
	size_t width = CGImageGetWidth(image);
	size_t height = CGImageGetHeight(image);
	if (x < width && y < height){
		const uint8_t *pixel = bytes + y * stride + x * 4;
		out[0] = pixel[0];
		out[1] = pixel[1];
		out[2] = pixel[2];
		out[3] = pixel[3];
	}
	CFRelease(data);
}

static size_t TGPatternOpaquePixels(CGImageRef image) {
	size_t count = 0;
	size_t width = CGImageGetWidth(image);
	size_t height = CGImageGetHeight(image);
	CGDataProviderRef provider = CGImageGetDataProvider(image);
	CFDataRef data = provider ? CGDataProviderCopyData(provider) : NULL;
	if (!data)
		return 0;
	const uint8_t *bytes = CFDataGetBytePtr(data);
	size_t stride = CGImageGetBytesPerRow(image);
	for (size_t y = 0; y < height; y++)
		for (size_t x = 0; x < width; x++)
			if (bytes[y * stride + x * 4 + 3] > 0)
				count++;
	CFRelease(data);
	return count;
}

static BOOL TGPatternClose(uint8_t value, uint8_t expected) {
	int delta = (int)value - (int)expected;
	return delta >= -3 && delta <= 3;
}

@interface TGPatternTests : XCTestCase @end

@implementation TGPatternTests

- (void)testGunzipAndMaskHaveCoverage {
	NSData *svg = [NSData dataWithBytes:TGPatternFixture
								 length:strlen(TGPatternFixture)];
	NSData *gzip = TGPatternDeflate(svg);
	XCTAssertNotNil(gzip);
	NSData *unpacked = TGPatternGunzip(gzip);
	XCTAssertNotNil(unpacked);
	XCTAssertEqualObjects(unpacked, svg);

	CGImageRef mask = TGPatternCreateMask(gzip, CGSizeMake(32.0f, 32.0f));
	XCTAssertTrue(mask != NULL, "a few SVG paths must rasterise");
	if (!mask)
		return;
	XCTAssertEqual(CGImageGetWidth(mask), (size_t)32);
	XCTAssertEqual(CGImageGetHeight(mask), (size_t)32);
	XCTAssertGreaterThan(TGPatternOpaquePixels(mask), (size_t)0,
			"the mask must cover some of the bitmap");
	CGImageRelease(mask);
}

- (void)testInvertedCompositeChangesTheFill {
	NSData *gzip = TGPatternDeflate([NSData dataWithBytes:TGPatternFixture
			length:strlen(TGPatternFixture)]);
	CGImageRef mask = TGPatternCreateMask(gzip, CGSizeMake(32.0f, 32.0f));
	XCTAssertTrue(mask != NULL);
	if (!mask)
		return;

	NSArray *white = @[[UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:1.0f]];
	CGImageRef normal = TGPatternCreateWallpaper(CGSizeMake(32.0f, 32.0f),
			white, @"backgroundFillSolid", 0.0f, mask, 0.5f, NO);
	CGImageRef inverted = TGPatternCreateWallpaper(CGSizeMake(32.0f, 32.0f),
			white, @"backgroundFillSolid", 0.0f, mask, 0.5f, YES);
	XCTAssertTrue(normal != NULL && inverted != NULL);
	if (normal && inverted){
		uint8_t normalCorner[4], invertedCorner[4];
		// (1,1) is outside the rect at 4,4: the light variant keeps the white
		// fill, the inverted one covers it with the black sheet.
		TGPatternPixel(normal, 1, 1, normalCorner);
		TGPatternPixel(inverted, 1, 1, invertedCorner);
		XCTAssertTrue(TGPatternClose(normalCorner[0], 255),
				"light pattern must leave the fill alone, got %d", normalCorner[0]);
		XCTAssertTrue(TGPatternClose(invertedCorner[0], 0),
				"inverted pattern must be black outside a shape, got %d",
				invertedCorner[0]);
		XCTAssertNotEqual(normalCorner[0], invertedCorner[0]);
	}
	if (normal)
		CGImageRelease(normal);
	if (inverted)
		CGImageRelease(inverted);
	CGImageRelease(mask);
}

- (void)testFreeformFillHasFourCornerColours {
	NSArray *colours = @[
		[UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:1.0f],
		[UIColor colorWithRed:0.0f green:1.0f blue:0.0f alpha:1.0f],
		[UIColor colorWithRed:0.0f green:0.0f blue:1.0f alpha:1.0f],
		[UIColor colorWithRed:1.0f green:1.0f blue:0.0f alpha:1.0f],
	];
	CGImageRef image = TGPatternCreateFill(CGSizeMake(16.0f, 16.0f), colours,
			@"backgroundFillFreeformGradient", 0.0f);
	XCTAssertTrue(image != NULL);
	if (!image)
		return;
	size_t width = CGImageGetWidth(image);
	size_t height = CGImageGetHeight(image);
	uint8_t topLeft[4], topRight[4], bottomLeft[4], bottomRight[4];
	// Bitmap rows are stored bottom-up: row 0 is the visual bottom.
	TGPatternPixel(image, 0, 0, bottomLeft);
	TGPatternPixel(image, width - 1, 0, bottomRight);
	TGPatternPixel(image, 0, height - 1, topLeft);
	TGPatternPixel(image, width - 1, height - 1, topRight);
	XCTAssertTrue(TGPatternClose(topLeft[0], 255) && TGPatternClose(topLeft[1], 0),
			"top-left must be the first colour");
	XCTAssertTrue(TGPatternClose(topRight[0], 0) && TGPatternClose(topRight[1], 255),
			"top-right must be the second colour");
	XCTAssertTrue(TGPatternClose(bottomLeft[0], 0) && TGPatternClose(bottomLeft[2], 255),
			"bottom-left must be the third colour");
	XCTAssertTrue(TGPatternClose(bottomRight[0], 255) && TGPatternClose(bottomRight[1], 255),
			"bottom-right must be the fourth colour");
	CGImageRelease(image);
}

@end
