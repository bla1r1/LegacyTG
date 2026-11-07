#import "TGTestRunner.h"
#import "TGMediaVeil.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

static uint8_t *mvPixels(CGImageRef image, size_t *outW, size_t *outH) {
	if (!image) {
		if (outW) *outW = 0;
		if (outH) *outH = 0;
		return NULL;
	}
	size_t w = CGImageGetWidth(image);
	size_t h = CGImageGetHeight(image);
	if (outW) *outW = w;
	if (outH) *outH = h;
	if (w == 0 || h == 0) {
		return NULL;
	}
	size_t bytesPerRow = w * 4;
	size_t byteCount = bytesPerRow * h;
	uint8_t *buffer = (uint8_t *)malloc(byteCount);
	if (!buffer) {
		return NULL;
	}
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(buffer,
	                                         w,
	                                         h,
	                                         8,
	                                         bytesPerRow,
	                                         cs,
	                                         kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(cs);
	if (!ctx) {
		free(buffer);
		return NULL;
	}
	CGContextDrawImage(ctx, CGRectMake(0, 0, (CGFloat)w, (CGFloat)h), image);
	CGContextRelease(ctx);
	return buffer;
}

static CGImageRef mvCreateTestImage(size_t w, size_t h, void (^fill)(uint8_t *bytes, size_t bytesPerRow)) {
	if (w == 0 || h == 0) {
		return NULL;
	}
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	size_t bytesPerRow = w * 4;
	CGContextRef ctx = CGBitmapContextCreate(NULL,
	                                         w,
	                                         h,
	                                         8,
	                                         bytesPerRow,
	                                         cs,
	                                         kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(cs);
	if (!ctx) {
		return NULL;
	}
	if (fill) {
		uint8_t *bytes = (uint8_t *)CGBitmapContextGetData(ctx);
		size_t actualBytesPerRow = CGBitmapContextGetBytesPerRow(ctx);
		fill(bytes, actualBytesPerRow);
	}
	CGImageRef img = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
	return img;
}

@interface TGMediaVeilBlurTests : XCTestCase @end

@implementation TGMediaVeilBlurTests

- (void)testBlur_NullInputReturnsNull {
	CGImageRef result = TGMediaVeilBlurCreate(NULL, 16.0f);
	XCTAssertTrue(result == NULL);
}

- (void)testBlur_ZeroWidthImageReturnsNull {
	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, NULL, 0, NULL);
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGImageRef zeroImg = CGImageCreate(0, 10, 8, 32, 0, cs, kCGImageAlphaPremultipliedLast, provider, NULL, false, kCGRenderingIntentDefault);
	CGColorSpaceRelease(cs);
	CGDataProviderRelease(provider);
	CGImageRef result = TGMediaVeilBlurCreate(zeroImg, 16.0f);
	XCTAssertTrue(result == NULL);
	if (zeroImg) {
		CGImageRelease(zeroImg);
	}
}

- (void)testBlur_ZeroHeightImageReturnsNull {
	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, NULL, 0, NULL);
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGImageRef zeroImg = CGImageCreate(10, 0, 8, 32, 0, cs, kCGImageAlphaPremultipliedLast, provider, NULL, false, kCGRenderingIntentDefault);
	CGColorSpaceRelease(cs);
	CGDataProviderRelease(provider);
	CGImageRef result = TGMediaVeilBlurCreate(zeroImg, 16.0f);
	XCTAssertTrue(result == NULL);
	if (zeroImg) {
		CGImageRelease(zeroImg);
	}
}

- (void)testBlur_ScaleDownLandscape400x200Yields48x24 {
	CGImageRef src = mvCreateTestImage(400, 200, ^(uint8_t *bytes, size_t bytesPerRow) {
		memset(bytes, 120, 200 * bytesPerRow);
	});
	XCTAssertTrue(src != NULL);
	CGImageRef blurred = TGMediaVeilBlurCreate(src, 16.0f);
	CGImageRelease(src);
	XCTAssertTrue(blurred != NULL);

	size_t outW = 0, outH = 0;
	uint8_t *pixels = mvPixels(blurred, &outW, &outH);
	CGImageRelease(blurred);
	XCTAssertEqual(outW, (size_t)48);
	XCTAssertEqual(outH, (size_t)24);
	if (pixels) free(pixels);
}

- (void)testBlur_ScaleDownPortrait200x400Yields24x48 {
	CGImageRef src = mvCreateTestImage(200, 400, ^(uint8_t *bytes, size_t bytesPerRow) {
		memset(bytes, 120, 400 * bytesPerRow);
	});
	XCTAssertTrue(src != NULL);
	CGImageRef blurred = TGMediaVeilBlurCreate(src, 16.0f);
	CGImageRelease(src);
	XCTAssertTrue(blurred != NULL);

	size_t outW = 0, outH = 0;
	uint8_t *pixels = mvPixels(blurred, &outW, &outH);
	CGImageRelease(blurred);
	XCTAssertEqual(outW, (size_t)24);
	XCTAssertEqual(outH, (size_t)48);
	if (pixels) free(pixels);
}

- (void)testBlur_SmallImageNeverScaledUp10x10 {
	CGImageRef src = mvCreateTestImage(10, 10, ^(uint8_t *bytes, size_t bytesPerRow) {
		memset(bytes, 140, 10 * bytesPerRow);
	});
	XCTAssertTrue(src != NULL);
	CGImageRef blurred = TGMediaVeilBlurCreate(src, 16.0f);
	CGImageRelease(src);
	XCTAssertTrue(blurred != NULL);

	size_t outW = 0, outH = 0;
	uint8_t *pixels = mvPixels(blurred, &outW, &outH);
	CGImageRelease(blurred);
	XCTAssertEqual(outW, (size_t)10);
	XCTAssertEqual(outH, (size_t)10);
	if (pixels) free(pixels);
}

- (void)testBlur_ExtremeAspectWideAtLeastOnePxHeight1000x10 {
	CGImageRef src = mvCreateTestImage(1000, 10, ^(uint8_t *bytes, size_t bytesPerRow) {
		memset(bytes, 160, 10 * bytesPerRow);
	});
	XCTAssertTrue(src != NULL);
	CGImageRef blurred = TGMediaVeilBlurCreate(src, 16.0f);
	CGImageRelease(src);
	XCTAssertTrue(blurred != NULL);

	size_t outW = 0, outH = 0;
	uint8_t *pixels = mvPixels(blurred, &outW, &outH);
	CGImageRelease(blurred);
	XCTAssertEqual(outW, (size_t)48);
	XCTAssertEqual(outH, (size_t)1);
	if (pixels) free(pixels);
}

- (void)testBlur_ExtremeAspectTallAtLeastOnePxWidth10x1000 {
	CGImageRef src = mvCreateTestImage(10, 1000, ^(uint8_t *bytes, size_t bytesPerRow) {
		memset(bytes, 160, 1000 * bytesPerRow);
	});
	XCTAssertTrue(src != NULL);
	CGImageRef blurred = TGMediaVeilBlurCreate(src, 16.0f);
	CGImageRelease(src);
	XCTAssertTrue(blurred != NULL);

	size_t outW = 0, outH = 0;
	uint8_t *pixels = mvPixels(blurred, &outW, &outH);
	CGImageRelease(blurred);
	XCTAssertEqual(outW, (size_t)1);
	XCTAssertEqual(outH, (size_t)48);
	if (pixels) free(pixels);
}

- (void)testBlur_ExactBoundary48x48NotResized {
	CGImageRef src = mvCreateTestImage(48, 48, ^(uint8_t *bytes, size_t bytesPerRow) {
		memset(bytes, 100, 48 * bytesPerRow);
	});
	XCTAssertTrue(src != NULL);
	CGImageRef blurred = TGMediaVeilBlurCreate(src, 16.0f);
	CGImageRelease(src);
	XCTAssertTrue(blurred != NULL);

	size_t outW = 0, outH = 0;
	uint8_t *pixels = mvPixels(blurred, &outW, &outH);
	CGImageRelease(blurred);
	XCTAssertEqual(outW, (size_t)48);
	XCTAssertEqual(outH, (size_t)48);
	if (pixels) free(pixels);
}

- (void)testBlur_SolidColorPreservedWithinTolerance {
	const uint8_t targetR = 200;
	const uint8_t targetG = 100;
	const uint8_t targetB = 50;
	const uint8_t targetA = 255;
	CGImageRef src = mvCreateTestImage(48, 48, ^(uint8_t *bytes, size_t bytesPerRow) {
		for (size_t y = 0; y < 48; y++) {
			uint8_t *row = bytes + y * bytesPerRow;
			for (size_t x = 0; x < 48; x++) {
				row[x * 4 + 0] = targetR;
				row[x * 4 + 1] = targetG;
				row[x * 4 + 2] = targetB;
				row[x * 4 + 3] = targetA;
			}
		}
	});
	XCTAssertTrue(src != NULL);
	CGImageRef blurred = TGMediaVeilBlurCreate(src, 8.0f);
	CGImageRelease(src);
	XCTAssertTrue(blurred != NULL);

	size_t outW = 0, outH = 0;
	uint8_t *pixels = mvPixels(blurred, &outW, &outH);
	CGImageRelease(blurred);
	XCTAssertTrue(pixels != NULL);
	XCTAssertEqual(outW, (size_t)48);
	XCTAssertEqual(outH, (size_t)48);

	BOOL matches = YES;
	for (size_t i = 0; i < outW * outH; i++) {
		int diffR = abs((int)pixels[i * 4 + 0] - (int)targetR);
		int diffG = abs((int)pixels[i * 4 + 1] - (int)targetG);
		int diffB = abs((int)pixels[i * 4 + 2] - (int)targetB);
		int diffA = abs((int)pixels[i * 4 + 3] - (int)targetA);
		if (diffR > 2 || diffG > 2 || diffB > 2 || diffA > 2) {
			matches = NO;
			break;
		}
	}
	XCTAssertTrue(matches);
	if (pixels) free(pixels);
}

- (void)testBlur_CheckerboardConvergesNearMidGrey {
	CGImageRef src = mvCreateTestImage(48, 48, ^(uint8_t *bytes, size_t bytesPerRow) {
		for (size_t y = 0; y < 48; y++) {
			uint8_t *row = bytes + y * bytesPerRow;
			for (size_t x = 0; x < 48; x++) {
				uint8_t val = ((x + y) % 2 == 0) ? 0 : 255;
				row[x * 4 + 0] = val;
				row[x * 4 + 1] = val;
				row[x * 4 + 2] = val;
				row[x * 4 + 3] = 255;
			}
		}
	});
	XCTAssertTrue(src != NULL);
	CGImageRef blurred = TGMediaVeilBlurCreate(src, 16.0f);
	CGImageRelease(src);
	XCTAssertTrue(blurred != NULL);

	size_t outW = 0, outH = 0;
	uint8_t *pixels = mvPixels(blurred, &outW, &outH);
	CGImageRelease(blurred);
	XCTAssertTrue(pixels != NULL);
	XCTAssertEqual(outW, (size_t)48);
	XCTAssertEqual(outH, (size_t)48);

	const double midGrey = 127.5;
	const double maxDelta = 255.0 * 0.25;
	BOOL withinTolerance = YES;
	for (size_t i = 0; i < outW * outH; i++) {
		double r = (double)pixels[i * 4 + 0];
		if (fabs(r - midGrey) > maxDelta) {
			withinTolerance = NO;
			break;
		}
	}
	XCTAssertTrue(withinTolerance);
	if (pixels) free(pixels);
}

- (void)testBlur_EdgeClampingDoesNotWrapAround {
	CGImageRef src = mvCreateTestImage(48, 48, ^(uint8_t *bytes, size_t bytesPerRow) {
		for (size_t y = 0; y < 48; y++) {
			uint8_t *row = bytes + y * bytesPerRow;
			for (size_t x = 0; x < 48; x++) {
				uint8_t val = (x < 24) ? 0 : 255;
				row[x * 4 + 0] = val;
				row[x * 4 + 1] = val;
				row[x * 4 + 2] = val;
				row[x * 4 + 3] = 255;
			}
		}
	});
	XCTAssertTrue(src != NULL);
	CGImageRef blurred = TGMediaVeilBlurCreate(src, 16.0f);
	CGImageRelease(src);
	XCTAssertTrue(blurred != NULL);

	size_t outW = 0, outH = 0;
	uint8_t *pixels = mvPixels(blurred, &outW, &outH);
	CGImageRelease(blurred);
	XCTAssertTrue(pixels != NULL);
	XCTAssertEqual(outW, (size_t)48);
	XCTAssertEqual(outH, (size_t)48);

	size_t midY = 24;
	uint8_t col0Val = pixels[(midY * outW + 0) * 4 + 0];
	uint8_t midVal = pixels[(midY * outW + 23) * 4 + 0];
	uint8_t col47Val = pixels[(midY * outW + 47) * 4 + 0];

	XCTAssertTrue(col0Val < col47Val);
	XCTAssertTrue(col0Val < midVal);
	XCTAssertTrue(midVal < col47Val);
	if (pixels) free(pixels);
}

- (void)testBlur_RadiusZeroDoesNotCrashAndReturnsValidImage {
	CGImageRef src = mvCreateTestImage(32, 32, ^(uint8_t *bytes, size_t bytesPerRow) {
		memset(bytes, 180, 32 * bytesPerRow);
	});
	XCTAssertTrue(src != NULL);
	CGImageRef blurred = TGMediaVeilBlurCreate(src, 0.0f);
	CGImageRelease(src);
	XCTAssertTrue(blurred != NULL);

	size_t outW = 0, outH = 0;
	uint8_t *pixels = mvPixels(blurred, &outW, &outH);
	CGImageRelease(blurred);
	XCTAssertEqual(outW, (size_t)32);
	XCTAssertEqual(outH, (size_t)32);
	if (pixels) free(pixels);
}

- (void)testBlur_RadiusOneThousandClampedAndDoesNotCrash {
	CGImageRef src = mvCreateTestImage(48, 48, ^(uint8_t *bytes, size_t bytesPerRow) {
		memset(bytes, 200, 48 * bytesPerRow);
	});
	XCTAssertTrue(src != NULL);
	CGImageRef blurred = TGMediaVeilBlurCreate(src, 1000.0f);
	CGImageRelease(src);
	XCTAssertTrue(blurred != NULL);

	size_t outW = 0, outH = 0;
	uint8_t *pixels = mvPixels(blurred, &outW, &outH);
	CGImageRelease(blurred);
	XCTAssertEqual(outW, (size_t)48);
	XCTAssertEqual(outH, (size_t)48);
	if (pixels) free(pixels);
}

- (void)testBlur_NegativeRadiusClampedToMin {
	CGImageRef src = mvCreateTestImage(24, 24, ^(uint8_t *bytes, size_t bytesPerRow) {
		memset(bytes, 90, 24 * bytesPerRow);
	});
	XCTAssertTrue(src != NULL);
	CGImageRef blurred = TGMediaVeilBlurCreate(src, -10.0f);
	CGImageRelease(src);
	XCTAssertTrue(blurred != NULL);

	size_t outW = 0, outH = 0;
	uint8_t *pixels = mvPixels(blurred, &outW, &outH);
	CGImageRelease(blurred);
	XCTAssertEqual(outW, (size_t)24);
	XCTAssertEqual(outH, (size_t)24);
	if (pixels) free(pixels);
}

- (void)testTitle_SpoilerReturnsNil {
	NSString *title = TGMediaVeilTitle(TGMediaVeilKindSpoiler, 0);
	XCTAssertTrue(title == nil);
}

- (void)testTitle_ViewOnceReturnsTapToView {
	NSString *title = TGMediaVeilTitle(TGMediaVeilKindViewOnce, 0);
	XCTAssertEqualObjects(title, @"Tap to view");
}

- (void)testTitle_PaidFiftyStars {
	NSString *title = TGMediaVeilTitle(TGMediaVeilKindPaid, 50);
	XCTAssertEqualObjects(title, @"Unlock for 50 Stars");
}

- (void)testTitle_PaidSingleStar {
	NSString *title = TGMediaVeilTitle(TGMediaVeilKindPaid, 1);
	XCTAssertEqualObjects(title, @"Unlock for 1 Star");
}

- (void)testTitle_PaidLargeStarCount {
	NSString *title = TGMediaVeilTitle(TGMediaVeilKindPaid, 5000);
	XCTAssertEqualObjects(title, @"Unlock for 5000 Stars");
}

- (void)testTitle_NoneReturnsNil {
	NSString *title = TGMediaVeilTitle(TGMediaVeilKindNone, 0);
	XCTAssertTrue(title == nil);
}

- (void)testTitle_InvalidKindReturnsNil {
	NSString *title = TGMediaVeilTitle((TGMediaVeilKind)999, 10);
	XCTAssertTrue(title == nil);
}

@end
