// The blur, apart from the view so the host tests can run it.
#import "TGMediaVeil.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

NSString *TGMediaVeilTitle(TGMediaVeilKind kind, int64_t starCount) {
	switch (kind) {
		case TGMediaVeilKindSpoiler:
			return nil;
		case TGMediaVeilKindViewOnce:
			return @"Tap to view";
		case TGMediaVeilKindPaid:
			if (starCount == 1) {
				return @"Unlock for 1 Star";
			}
			return [NSString stringWithFormat:@"Unlock for %lld Stars", (long long)starCount];
		case TGMediaVeilKindNone:
		default:
			return nil;
	}
}

CGImageRef TGMediaVeilBlurCreate(CGImageRef image, CGFloat radius) {
	if (!image) {
		return NULL;
	}

	size_t sourceWidth = CGImageGetWidth(image);
	size_t sourceHeight = CGImageGetHeight(image);
	if (sourceWidth == 0 || sourceHeight == 0) {
		return NULL;
	}

	size_t sourceLong = sourceWidth > sourceHeight ? sourceWidth : sourceHeight;
	size_t smallWidth = sourceWidth;
	size_t smallHeight = sourceHeight;

	// Scale down large images so the long dimension never exceeds 48 px.
	if (sourceLong > 48) {
		if (sourceWidth >= sourceHeight) {
			smallWidth = 48;
			smallHeight = (size_t)round((double)sourceHeight * 48.0 / (double)sourceWidth);
			if (smallHeight < 1) {
				smallHeight = 1;
			}
		} else {
			smallHeight = 48;
			smallWidth = (size_t)round((double)sourceWidth * 48.0 / (double)sourceHeight);
			if (smallWidth < 1) {
				smallWidth = 1;
			}
		}
	}

	size_t smallLong = smallWidth > smallHeight ? smallWidth : smallHeight;

	// Map radius in source pixels to small pixels: clamp to at least 1 and at most 8.
	int r = (int)round((double)radius * (double)smallLong / (double)sourceLong);
	if (r < 1) {
		r = 1;
	}
	if (r > 8) {
		r = 8;
	}

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	if (!colorSpace) {
		return NULL;
	}

	size_t bytesPerRow = smallWidth * 4;
	CGContextRef ctx = CGBitmapContextCreate(NULL,
	                                         smallWidth,
	                                         smallHeight,
	                                         8,
	                                         bytesPerRow,
	                                         colorSpace,
	                                         kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(colorSpace);

	if (!ctx) {
		return NULL;
	}

	CGContextSetInterpolationQuality(ctx, kCGInterpolationMedium);
	CGContextDrawImage(ctx, CGRectMake(0, 0, (CGFloat)smallWidth, (CGFloat)smallHeight), image);

	uint8_t *bytes = (uint8_t *)CGBitmapContextGetData(ctx);
	if (!bytes) {
		CGContextRelease(ctx);
		return NULL;
	}

	size_t actualBytesPerRow = CGBitmapContextGetBytesPerRow(ctx);
	size_t maxDim = smallWidth > smallHeight ? smallWidth : smallHeight;
	uint8_t *temp = (uint8_t *)malloc(maxDim * 4);
	if (!temp) {
		CGContextRelease(ctx);
		return NULL;
	}

	int divisor = 2 * r + 1;

	// Three box blur passes approximate a Gaussian blur while keeping CPU cost low.
	for (int pass = 0; pass < 3; pass++) {
		// Horizontal pass over each row
		for (size_t y = 0; y < smallHeight; y++) {
			uint8_t *row = bytes + y * actualBytesPerRow;
			for (size_t x = 0; x < smallWidth; x++) {
				for (int c = 0; c < 4; c++) {
					int sum = 0;
					for (int k = -r; k <= r; k++) {
						int ix = (int)x + k;
						if (ix < 0) {
							ix = 0;
						} else if (ix >= (int)smallWidth) {
							ix = (int)smallWidth - 1;
						}
						sum += row[ix * 4 + c];
					}
					temp[x * 4 + c] = (uint8_t)((sum + r) / divisor);
				}
			}
			memcpy(row, temp, smallWidth * 4);
		}

		// Vertical pass over each column
		for (size_t x = 0; x < smallWidth; x++) {
			for (size_t y = 0; y < smallHeight; y++) {
				for (int c = 0; c < 4; c++) {
					int sum = 0;
					for (int k = -r; k <= r; k++) {
						int iy = (int)y + k;
						if (iy < 0) {
							iy = 0;
						} else if (iy >= (int)smallHeight) {
							iy = (int)smallHeight - 1;
						}
						sum += bytes[(size_t)iy * actualBytesPerRow + x * 4 + c];
					}
					temp[y * 4 + c] = (uint8_t)((sum + r) / divisor);
				}
			}
			for (size_t y = 0; y < smallHeight; y++) {
				for (int c = 0; c < 4; c++) {
					bytes[y * actualBytesPerRow + x * 4 + c] = temp[y * 4 + c];
				}
			}
		}
	}

	free(temp);

	CGImageRef resultImage = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);

	return resultImage;
}
