//
// TGTLottie.m - see TGTLottie.h.
//
#import "TGTLottie.h"
#import "TGCrashGuard.h"
#include "tlottie.h"
#include <pthread.h>

struct TGTLottie {
	TLottieInstance *instance;
	uint32_t width, height;
	char name[256];
};

static pthread_mutex_t sLock = PTHREAD_MUTEX_INITIALIZER;
static NSMutableSet *sRefused;   // file names tlottie crashed on; under sLock

void TGTLottieUseCrashLog(NSString *directory) {
	if (!directory.length)
		return;
	NSString *marker = [directory stringByAppendingPathComponent:@"tlottie.crashed"];
	NSString *refusedPath = [directory stringByAppendingPathComponent:@"tlottie.refused"];
	[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES
			attributes:nil error:NULL];

	NSString *known = [NSString stringWithContentsOfFile:refusedPath encoding:NSUTF8StringEncoding error:NULL] ?: @"";
	NSMutableSet *refused = [NSMutableSet set];
	for (NSString *line in [known componentsSeparatedByString:@"\n"])
		if (line.length)
			[refused addObject:line];
	NSString *crashed = [[NSString stringWithContentsOfFile:marker encoding:NSUTF8StringEncoding error:NULL]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (crashed.length && ![refused containsObject:crashed]) {
		[refused addObject:crashed];
		NSString *list = [[refused.allObjects componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
		[list writeToFile:refusedPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
		NSLog(@"TGLottie: tlottie crashed on %@ last run; TGLottieRender draws it from now on", crashed);
	}
	[[NSFileManager defaultManager] removeItemAtPath:marker error:NULL];

	pthread_mutex_lock(&sLock);
	sRefused = refused;
	TGCrashGuardInstall(marker.fileSystemRepresentation);
	pthread_mutex_unlock(&sLock);
}

TGTLottie *TGTLottieCreate(NSData *json, NSString *name) {
	if (!json.length)
		return NULL;
	const char *cname = name.UTF8String ?: "";
	pthread_mutex_lock(&sLock);
	if ([sRefused containsObject:name ?: @""]) {
		pthread_mutex_unlock(&sLock);
		return NULL;
	}
	TGCrashGuardEnter(cname);
	TLottieInstance *instance = tlottie_new((const uint8_t *)json.bytes, json.length);
	TGCrashGuardLeave();
	uint32_t width = instance ? tlottie_width(instance) : 0;
	uint32_t height = instance ? tlottie_height(instance) : 0;
	uint32_t frames = instance ? tlottie_frame_count(instance) : 0;
	pthread_mutex_unlock(&sLock);

	TGTLottie *animation = (instance && width && height && frames) ? calloc(1, sizeof(TGTLottie)) : NULL;
	if (!animation) {
		if (instance)
			tlottie_drop(instance);
		return NULL;
	}
	animation->instance = instance;
	animation->width = width;
	animation->height = height;
	strlcpy(animation->name, cname, sizeof(animation->name));
	return animation;
}

void TGTLottieFree(TGTLottie *animation) {
	if (!animation)
		return;
	tlottie_drop(animation->instance);
	free(animation);
}

NSUInteger TGTLottieFrameCount(const TGTLottie *animation) {
	return animation ? tlottie_frame_count(animation->instance) : 0;
}

double TGTLottieFrameRate(const TGTLottie *animation) {
	return animation ? tlottie_frame_rate(animation->instance) : 0;
}

static void TGTLottieReleasePixels(void *info, const void *data, size_t size) {
	free((void *)data);
}

CGImageRef TGTLottieRender(TGTLottie *animation, double frame, CGSize pixelSize) {
	if (!animation || pixelSize.width < 1 || pixelSize.height < 1)
		return NULL;
	// tlottie stretches to the size it is given; fit the canvas instead, as
	// TGLottieRender does, and the layer's aspect gravity centres it.
	double scale = MIN(pixelSize.width / animation->width, pixelSize.height / animation->height);
	size_t w = (size_t)MAX(1.0, floor(animation->width * scale));
	size_t h = (size_t)MAX(1.0, floor(animation->height * scale));
	uint32_t *pixels = malloc(w * h * sizeof(uint32_t));
	if (!pixels)
		return NULL;
	pthread_mutex_lock(&sLock);
	TGCrashGuardEnter(animation->name);
	int32_t status = tlottie_render(animation->instance, (float)frame, (uint32_t)w, (uint32_t)h,
			pixels, w * h, 1);
	TGCrashGuardLeave();
	pthread_mutex_unlock(&sLock);
	if (status != TLOTTIE_OK) {
		free(pixels);
		return NULL;
	}
	// [R, G, B, A] premultiplied bytes, whatever the word order.
	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, w * h * sizeof(uint32_t),
			TGTLottieReleasePixels);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGImageRef image = CGImageCreate(w, h, 8, 32, w * 4, space,
			(CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big,
			provider, NULL, false, kCGRenderingIntentDefault);
	CGColorSpaceRelease(space);
	CGDataProviderRelease(provider);
	return image;
}
