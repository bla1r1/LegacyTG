// TGMediaHardeningTests.m — tests for media parser hardening against crafted inputs.
#import "TGTestRunner.h"
#import <UIKit/UIKit.h>
#import <zlib.h>

// UIImage+WebP.m is compiled into this host binary below; on the Mac its
// UIImage is NSImage, given the one UIKit constructor the decoder calls.
#if !TARGET_OS_IPHONE && defined(__APPLE__)
#import <AppKit/AppKit.h>
#ifndef UIImage
#define UIImage NSImage
#endif
@interface NSImage (TGWebPHostShim)
+ (instancetype)imageWithCGImage:(CGImageRef)cgImage;
@end
@implementation NSImage (TGWebPHostShim)
+ (instancetype)imageWithCGImage:(CGImageRef)cgImage {
	return [[NSImage alloc] initWithCGImage:cgImage size:NSZeroSize];
}
@end
#endif

#import "UIImage+WebP.h"
#import "TGWebMDecoder.h"
#import "TGStickerImage.h"
#import "TGLottieSupport.h"
#import "TGTLottie.h"
#import "TGPatternImage.h"
#import "TGVoiceDecoder.h"
#import "TGSoftVideoPlayer.h"

// Forward declarations for helpers
FOUNDATION_EXPORT NSData *TGLottieGunzip(NSData *data);
void TGSoftCopyPlane(uint8_t *dst, const uint8_t *src, int stride, int width, int height);
BOOL TGSoftVideoValidateDimensions(int width, int height);

// Bring in implementations for the single-binary test runner
#include "nestegg/nestegg.c"
#include "nanosvg/nanosvg.c"
#import "TGStickerImage.m"
#import "UIImage+WebP.m"
#import "TGWebMDecoder.m"
#import "TGPatternImage.m"
#import "TGLottieSupport.m"
#import "TGTLottie.m"
#import "TGVoiceDecoder.m"
#import "TGSoftVideoPlayer.m"

// Stubs for libraries not linked into TGCallTests
__attribute__((weak)) OggOpusFile *op_open_file(const char *_path, int *_error) {
	if (_error) *_error = -1;
	return NULL;
}
__attribute__((weak)) int op_read_stereo(OggOpusFile *_of, opus_int16 *_pcm, int _buf_size) {
	return 0;
}
__attribute__((weak)) void op_free(OggOpusFile *_of) {}

__attribute__((weak)) TLottieInstance *tlottie_new(const uint8_t *data, size_t len) {
	return NULL;
}
__attribute__((weak)) void tlottie_drop(TLottieInstance *instance) {}
__attribute__((weak)) uint32_t tlottie_width(const TLottieInstance *instance) { return 0; }
__attribute__((weak)) uint32_t tlottie_height(const TLottieInstance *instance) { return 0; }
__attribute__((weak)) uint32_t tlottie_frame_count(const TLottieInstance *instance) { return 0; }
__attribute__((weak)) float tlottie_frame_rate(const TLottieInstance *instance) { return 0.0f; }
__attribute__((weak)) int32_t tlottie_render(TLottieInstance *renderer, float frame, uint32_t width, uint32_t height, uint32_t *out, size_t out_len, uint32_t antialias) { return -1; }

__attribute__((weak)) int TGCrashGuardInstall(const char *path) { return 0; }
__attribute__((weak)) void TGCrashGuardEnter(const char *name) {}
__attribute__((weak)) void TGCrashGuardLeave(void) {}

@interface TGMediaHardeningTests : XCTestCase @end

static NSString *TGWriteTempFile(NSData *data) {
	NSString *filename = [NSString stringWithFormat:@"tg_harden_%@.bin", [[NSUUID UUID] UUIDString]];
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
	[data writeToFile:path atomically:YES];
	return path;
}

static NSData *TGCreateGzip(NSData *source) {
	if (!source.length)
		return nil;
	z_stream stream;
	memset(&stream, 0, sizeof(stream));
	if (deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY) != Z_OK)
		return nil;
	stream.next_in = (Bytef *)source.bytes;
	stream.avail_in = (uInt)source.length;
	NSMutableData *output = [NSMutableData dataWithCapacity:source.length];
	uint8_t chunk[16384];
	int status = Z_OK;
	while (status == Z_OK) {
		stream.next_out = chunk;
		stream.avail_out = (uInt)sizeof(chunk);
		status = deflate(&stream, Z_FINISH);
		NSUInteger produced = sizeof(chunk) - stream.avail_out;
		if (produced)
			[output appendBytes:chunk length:produced];
	}
	deflateEnd(&stream);
	return (status == Z_STREAM_END) ? output : nil;
}

@implementation TGMediaHardeningTests

#pragma mark - WebP Hardening

- (void)testWebPTruncatedHeaderReturnsNil {
	// Truncated file smaller than minimal RIFF/WEBP header (12 bytes)
	NSData *data = [NSData dataWithBytes:"RIFF" length:4];
	NSString *path = TGWriteTempFile(data);
	UIImage *img = [UIImage convertFromWebP:path compressedData:NULL error:NULL];
	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	XCTAssertNil(img);
}

- (void)testWebPLengthFieldLargerThanFileReturnsNil {
	// RIFF header claims length 0xFFFFFF00 (4 GB) in a 16-byte file
	uint8_t bytes[16] = {
		'R', 'I', 'F', 'F',
		0x00, 0xFF, 0xFF, 0xFF,
		'W', 'E', 'B', 'P',
		'V', 'P', '8', ' '
	};
	NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
	NSString *path = TGWriteTempFile(data);
	UIImage *img = [UIImage convertFromWebP:path compressedData:NULL error:NULL];
	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	XCTAssertNil(img);
}

- (void)testWebPRandomBytesReturnNil {
	// 256 random bytes passed to WebP converter
	uint8_t randomBytes[256];
	arc4random_buf(randomBytes, sizeof(randomBytes));
	NSData *data = [NSData dataWithBytes:randomBytes length:sizeof(randomBytes)];
	NSString *path = TGWriteTempFile(data);
	UIImage *img = [UIImage convertFromWebP:path compressedData:NULL error:NULL];
	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	XCTAssertNil(img);
}

- (void)testWebPZeroLengthFileReturnsNil {
	NSString *path = TGWriteTempFile([NSData data]);
	UIImage *img = [UIImage convertFromWebP:path compressedData:NULL error:NULL];
	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	XCTAssertNil(img);
}

#pragma mark - Sticker Image Hardening

- (void)testStickerPaddedRefusesSideOver4096 {
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	uint8_t pixel[4] = {255, 0, 0, 255};
	CGContextRef ctx = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space,
			kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
	CGImageRef tiny = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
	CGColorSpaceRelease(space);

	// Side = 65535 or 65536 overflows integer multiplication on 32-bit into tiny buffer
	CGImageRef paddedOverMax = TGStickerImageCreatePadded(tiny, 65535);
	XCTAssertTrue(paddedOverMax == NULL);

	CGImageRef padded4097 = TGStickerImageCreatePadded(tiny, 4097);
	XCTAssertTrue(padded4097 == NULL);

	CGImageRef paddedZero = TGStickerImageCreatePadded(tiny, 0);
	XCTAssertTrue(paddedZero == NULL);

	CGImageRelease(tiny);
}

- (void)testStickerWebPDataRefusesSideOverLimit {
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	uint8_t pixel[4] = {255, 0, 0, 255};
	CGContextRef ctx = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space,
			kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
	CGImageRef tiny = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
	CGColorSpaceRelease(space);

	NSData *data = TGStickerImageWebPData(tiny, 65536, 0.9f);
	XCTAssertNil(data);

	CGImageRelease(tiny);
}

#pragma mark - WebM Hardening

- (void)testWebMTruncatedFileReturnsNil {
	uint8_t bytes[8] = { 0x1A, 0x45, 0xDF, 0xA3, 0x01, 0x00, 0x00, 0x00 };
	NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
	NSString *path = TGWriteTempFile(data);

	NSArray *frames = [TGWebMDecoder decodeFramesFromFile:path fps:NULL duration:NULL];
	XCTAssertNil(frames);

	UIImage *first = [TGWebMDecoder firstFrameFromFile:path];
	XCTAssertNil(first);

	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

- (void)testWebMRandomBytesReturnNil {
	uint8_t randomBytes[512];
	arc4random_buf(randomBytes, sizeof(randomBytes));
	NSData *data = [NSData dataWithBytes:randomBytes length:sizeof(randomBytes)];
	NSString *path = TGWriteTempFile(data);

	NSArray *frames = [TGWebMDecoder decodeFramesFromFile:path fps:NULL duration:NULL];
	XCTAssertNil(frames);

	UIImage *first = [TGWebMDecoder firstFrameFromFile:path];
	XCTAssertNil(first);

	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

- (void)testWebMConvertYUV420HandlesNullPlanesSafely {
	vpx_image_t img;
	memset(&img, 0, sizeof(img));
	uint8_t dst[128];
	// Must not crash when plane pointers are NULL
	ConvertYUV420ToRGBA(&img, NULL, dst, 16, 16, 64);
}

#pragma mark - Lottie Hardening

- (void)testLottieGzipBombRefusedPast4MB {
	// 5 MB of zeroes decompresses past the 4 MB limit
	size_t payloadSize = 5 * 1024 * 1024;
	uint8_t *raw = calloc(payloadSize, 1);
	memset(raw, ' ', payloadSize);
	NSData *bombRaw = [NSData dataWithBytesNoCopy:raw length:payloadSize freeWhenDone:YES];
	NSData *bombGzip = TGCreateGzip(bombRaw);
	XCTAssertNotNil(bombGzip);

	// TGLottieGunzip must abort and return nil on data exceeding 4 MB
	NSData *decompressed = TGLottieGunzip(bombGzip);
	XCTAssertNil(decompressed);

	// TGTLottieCreate must also refuse the gzip bomb
	TGTLottie *anim = TGTLottieCreate(bombGzip, @"bomb.tgs");
	XCTAssertTrue(anim == NULL);
}

- (void)testLottieTruncatedGzipReturnsNil {
	uint8_t truncated[10] = { 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03 };
	NSData *data = [NSData dataWithBytes:truncated length:sizeof(truncated)];
	XCTAssertNil(TGLottieGunzip(data));
	XCTAssertTrue(TGTLottieCreate(data, @"trunc.tgs") == NULL);
}

- (void)testLottieRandomBytesReturnNil {
	uint8_t randomBytes[256];
	arc4random_buf(randomBytes, sizeof(randomBytes));
	NSData *data = [NSData dataWithBytes:randomBytes length:sizeof(randomBytes)];
	XCTAssertNil(TGLottieGunzip(data));
	XCTAssertTrue(TGTLottieCreate(data, @"rand.tgs") == NULL);
}

- (void)testLottieDeeplyNestedGroupsDoNotBlowStack {
	// Build 50 levels of nested groups
	NSMutableArray *innermost = [NSMutableArray arrayWithObject:@{ @"ty": @"tr" }];
	NSDictionary *current = @{ @"ty": @"gr", @"it": innermost };
	for (int i = 0; i < 50; i++) {
		current = @{ @"ty": @"gr", @"it": @[ current ] };
	}
	NSString *unsupported = TGLottieUnsupportedFeature(@{ @"layers": @[ @{ @"ty": @4, @"shapes": @[ current ] } ] });
	XCTAssertNotNil(unsupported);
}

- (void)testLottieGradientStopsRejectsInvalidCounts {
	// Count of 65535 stops must be refused
	NSDictionary *badGradient = @{ @"p": @65535, @"k": @[ @0, @1, @0, @0 ] };
	XCTAssertNil(TGLottieGradientStops(badGradient, 0));

	// Count < 2 must be refused
	NSDictionary *zeroGradient = @{ @"p": @0, @"k": @[] };
	XCTAssertNil(TGLottieGradientStops(zeroGradient, 0));
}

#pragma mark - Pattern Hardening

- (void)testPatternGzipBombRefusedPast8MB {
	// 9 MB of spaces decompresses past the 8 MB pattern limit
	size_t payloadSize = 9 * 1024 * 1024;
	uint8_t *raw = calloc(payloadSize, 1);
	memset(raw, ' ', payloadSize);
	NSData *bombRaw = [NSData dataWithBytesNoCopy:raw length:payloadSize freeWhenDone:YES];
	NSData *bombGzip = TGCreateGzip(bombRaw);
	XCTAssertNotNil(bombGzip);

	NSData *decompressed = TGPatternGunzip(bombGzip);
	XCTAssertNil(decompressed);
}

- (void)testPatternTruncatedGzipReturnsNil {
	uint8_t truncated[10] = { 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03 };
	NSData *data = [NSData dataWithBytes:truncated length:sizeof(truncated)];
	XCTAssertNil(TGPatternGunzip(data));
	CGImageRef mask = TGPatternCreateMask(data, CGSizeMake(32, 32));
	XCTAssertTrue(mask == NULL);
}

- (void)testPatternRandomBytesReturnNull {
	uint8_t randomBytes[256];
	arc4random_buf(randomBytes, sizeof(randomBytes));
	NSData *data = [NSData dataWithBytes:randomBytes length:sizeof(randomBytes)];
	CGImageRef mask = TGPatternCreateMask(data, CGSizeMake(32, 32));
	XCTAssertTrue(mask == NULL);
}

- (void)testPatternContextRefusesOver4096AndOver16MB {
	CGImageRef fill65535 = TGPatternCreateFill(CGSizeMake(65535, 65535), @[], @"", 0);
	XCTAssertTrue(fill65535 == NULL);

	CGImageRef fill4097 = TGPatternCreateFill(CGSizeMake(4097, 100), @[], @"", 0);
	XCTAssertTrue(fill4097 == NULL);

	CGImageRef fillOver16MB = TGPatternCreateFill(CGSizeMake(3000, 3000), @[], @"", 0);
	XCTAssertTrue(fillOver16MB == NULL);
}

- (void)testPatternCreateMaskRefusesSVGWidth65535 {
	const char *svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"65535\" height=\"65535\"></svg>";
	NSData *data = [NSData dataWithBytes:svg length:strlen(svg)];
	CGImageRef mask = TGPatternCreateMask(data, CGSizeZero);
	XCTAssertTrue(mask == NULL);
}

#pragma mark - Voice Decoder Hardening

- (void)testVoiceTruncatedFileReturnsNil {
	uint8_t bytes[3] = { 'O', 'g', 'g' };
	NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
	NSString *path = TGWriteTempFile(data);
	NSString *wav = [TGVoiceDecoder wavFromOpusFile:path];
	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	XCTAssertNil(wav);
}

- (void)testVoiceRandomBytesReturnNil {
	uint8_t randomBytes[256];
	arc4random_buf(randomBytes, sizeof(randomBytes));
	NSData *data = [NSData dataWithBytes:randomBytes length:sizeof(randomBytes)];
	NSString *path = TGWriteTempFile(data);
	NSString *wav = [TGVoiceDecoder wavFromOpusFile:path];
	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	XCTAssertNil(wav);
}

- (void)testVoiceNonExistentFileReturnsNil {
	NSString *wav = [TGVoiceDecoder wavFromOpusFile:@"/nonexistent/file.ogg"];
	XCTAssertNil(wav);
}

#pragma mark - Soft Video Player Hardening

- (void)testSoftVideoValidateDimensions65535Refused {
	XCTAssertFalse(TGSoftVideoValidateDimensions(65535, 65535));
	XCTAssertFalse(TGSoftVideoValidateDimensions(65535, 1));
	XCTAssertFalse(TGSoftVideoValidateDimensions(1, 65535));
}

- (void)testSoftVideoValidateDimensionsOver16MBRefused {
	XCTAssertFalse(TGSoftVideoValidateDimensions(4096, 4096));
	XCTAssertFalse(TGSoftVideoValidateDimensions(3000, 3000));
}

- (void)testSoftVideoValidateDimensionsZeroOrNegativeRefused {
	XCTAssertFalse(TGSoftVideoValidateDimensions(0, 100));
	XCTAssertFalse(TGSoftVideoValidateDimensions(100, 0));
	XCTAssertFalse(TGSoftVideoValidateDimensions(-1, 100));
	XCTAssertFalse(TGSoftVideoValidateDimensions(100, -1));
}

- (void)testSoftVideoValidateDimensionsNormalAccepted {
	XCTAssertTrue(TGSoftVideoValidateDimensions(480, 480));
	XCTAssertTrue(TGSoftVideoValidateDimensions(1280, 720));
	XCTAssertTrue(TGSoftVideoValidateDimensions(1920, 1080));
}

- (void)testSoftVideoCopyPlaneInvalidStrideSafe {
	uint8_t dst[64] = {0};
	uint8_t src[64] = {0};
	// stride < width must return safely without reading out of bounds
	TGSoftCopyPlane(dst, src, 4, 8, 2);
	TGSoftCopyPlane(NULL, src, 8, 8, 2);
	TGSoftCopyPlane(dst, NULL, 8, 8, 2);
}

@end
