//
// TGLottieView.mm - plays Telegram stickers: Lottie loops rasterised by
// TGLottieRender in the background, WebM through TGWebMDecoder.
//
#import "TGAppActivity.h"
#import "TGLottieSupport.h"
#import "TGLottieRender.h"
#import "TGTLottie.h"
#import "TGLottieView.h"
#include <pthread.h>
#import "TGStyle.h"
#import "TGJson.h"
#import "TGWebMDecoder.h"
#import "TGCapabilities.h"
#import "TGStickerBudget.h"
#import "TGChatThemeStore.h"
#import "TGPerf.h"
#include <zlib.h>
#include <cmath>

#ifndef typeof
#define typeof __typeof__
#endif

#pragma mark - gunzip

/// .tgs is gzip, and NSData has no unzip on iOS 7, so inflate with zlib.
static NSData *TGGunzip(NSData *input) {
	if (!input.length)
		return nil;

	z_stream stream;
	memset(&stream, 0, sizeof(stream));
	stream.next_in = (Bytef *)input.bytes;
	stream.avail_in = (uInt)input.length;

	if (inflateInit2(&stream, 15 + 32) != Z_OK)
		return nil;

	NSMutableData *out = [NSMutableData dataWithLength:input.length * 8];
	int status;
	do {
		if (stream.total_out >= out.length)
			[out increaseLengthBy:input.length * 4];
		stream.next_out = (Bytef *)out.mutableBytes + stream.total_out;
		stream.avail_out = (uInt)(out.length - stream.total_out);
		status = inflate(&stream, Z_SYNC_FLUSH);
	} while (status == Z_OK);

	inflateEnd(&stream);
	if (status != Z_STREAM_END)
		return nil;

	[out setLength:stream.total_out];
	return out;
}

#pragma mark - model & cache

@interface TGLottieModel : NSObject
@property (nonatomic, copy) NSString *path;
/// tlottie's instance, or, for a file it would not take, TGLottieRender's
/// layer tree; owned, freed with the model. Frames are drawn on one queue at a
/// time (the build, then the loop pass), which is all tlottie asks.
@property (nonatomic, assign) TGTLottie *tlottie;
@property (nonatomic, assign) TGLottieScene *scene;
@property (nonatomic, assign) double inPoint;
@property (nonatomic, assign) double outPoint;
@property (nonatomic, assign) double frameRate;
@property (nonatomic, assign) CGSize canvas;

// Cached decoded/rasterized frames (NSArray of CGImageRef wrapped in id)
@property (nonatomic, strong) NSArray *cachedFrames;
// First frame shown while the rest of the loop rasterises in the background.
// Kept on the model so a budget-capped device paints the sticker from it on
// every reuse without rasterising or VP9-decoding again on the main thread.
@property (nonatomic, strong) UIImage *firstFrame;
@property (nonatomic, assign) BOOL isRasterizing;
/// Every frame of the loop came out fully transparent: this renderer cannot
/// draw the file. The view answers NO for it and the still picture stays.
@property (nonatomic, assign) BOOL blank;
@property (nonatomic, assign) BOOL isWebM;
@end

@implementation TGLottieModel
- (void)dealloc {
	TGTLottieFree(_tlottie);
	TGLottieSceneFree(_scene);
}

- (CGImageRef)newFrame:(double)frame size:(CGSize)size CF_RETURNS_RETAINED {
	if (_tlottie)
		return TGTLottieRender(_tlottie, frame - _inPoint, size);
	return TGLottieSceneRender(_scene, frame, size);
}

- (const char *)kind {
	return _isWebM ? "webm" : _tlottie ? "tlottie" : "tgs";
}
@end

#pragma mark - View Implementation

/// Where sticker models are built (`loop` NO) and loops rasterised (YES). On a
/// multi-core phone the global queue, as before. On one core (A4, 3GS) ten
/// builds at once shared the core with the scroll: each took 2-3 s of wall
/// time on the iPod touch 4 and the chat scroll lost 63% of its frames, while
/// tlottie's own lock ran them one at a time anyway. There a serial queue per
/// kind: builds at LOW, so a sticker's first frame does not wait behind a
/// loop, and loops at BACKGROUND, so they run when the main thread is idle.
static dispatch_queue_t TGLottieRasterQueue(BOOL loop) {
	static dispatch_queue_t builds, loops;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		if ([NSProcessInfo processInfo].processorCount < 2) {
			builds = dispatch_queue_create("org.legacy.itg.lottie-build", DISPATCH_QUEUE_SERIAL);
			dispatch_set_target_queue(builds, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
			loops = dispatch_queue_create("org.legacy.itg.lottie-loop", DISPATCH_QUEUE_SERIAL);
			dispatch_set_target_queue(loops, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
		} else {
			builds = loops = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		}
	});
	return loop ? loops : builds;
}

/// One serial queue builds every WebM player: the A4 has one core, and a
/// screen of emoji asking at once would only add context switches.
static dispatch_queue_t TGLottiePlayerQueue(void) {
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("org.legacy.itg.webm-open", DISPATCH_QUEUE_SERIAL);
	});
	return queue;
}

/// YES when no frame has a single lit pixel. Premultiplied, so a transparent
/// pixel is four zero bytes whatever the channel order.
static BOOL TGLottieFramesAreBlank(NSArray *frames) {
	if (!frames.count)
		return NO;
	for (id frame in frames) {
		CFDataRef data = CGDataProviderCopyData(
				CGImageGetDataProvider((__bridge CGImageRef)frame));
		if (!data)
			return NO;
		const uint8_t *bytes = CFDataGetBytePtr(data);
		CFIndex length = CFDataGetLength(data);
		BOOL lit = NO;
		for (CFIndex i = 0; i < length && !lit; i++)
			lit = bytes[i] != 0;
		CFRelease(data);
		if (lit)
			return NO;
	}
	return YES;
}

/// The cache key: the file and the side it is rastered for. Keyed by the file
/// alone, a sticker whose file had first been built for a 17 pt custom emoji
/// got that emoji's 34 px frames, stretched over 130 pt.
static NSString *TGLottieKey(NSString *path, CGSize viewSize) {
	return [NSString stringWithFormat:@"%@|%.0f", path,
			viewSize.width > 0 ? viewSize.width : 130.0];
}

@interface TGLottieView ()
@property (nonatomic, copy) NSString *loadedPath;
/// The file this view asked for while its model was still being built.
@property (nonatomic, copy) NSString *waitingPath;
@property (nonatomic, strong) TGLottieModel *model;
@property (nonatomic, strong) TGWebMStreamPlayer *webMPlayer;
/// The file a player is being built for off the main thread.
@property (nonatomic, copy) NSString *webMPlayerPendingPath;
@property (nonatomic, assign) NSUInteger currentFrameIndex;
@property (nonatomic, assign) double currentFrame;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL isPlaying;
/// Stop after the loop now running.
@property (nonatomic, assign) BOOL once;
/// showLastFrame was asked before the loop was rasterised.
@property (nonatomic, assign) BOOL wantsLastFrame;
@end


@implementation TGLottieView (ChatTheme)
/// Snapshots a .tgs file at `side` points and hands the still to `completion`.
/// The store installs this on +load; the store itself never builds a view.
+ (void)load {
	[TGChatThemeStore shared].tgsPatternRenderer =
			^(NSString *path, CGFloat side, void (^completion)(id image)){
		TGLottieView *view = [[TGLottieView alloc] initWithFrame:
				CGRectMake(0, 0, side, side)];
		__weak TGLottieView *weakView = view;
		void (^ready)(void) = ^{
			TGLottieView *strongView = weakView;
			UIImage *image = nil;
			if (strongView){
				CGImageRef content = (__bridge CGImageRef)strongView.layer.contents;
				if (content && CFGetTypeID(content) == CGImageGetTypeID()){
					image = [UIImage imageWithCGImage:content];
				} else {
					UIGraphicsBeginImageContextWithOptions(strongView.bounds.size, NO, 1);
					[strongView.layer renderInContext:UIGraphicsGetCurrentContext()];
					image = UIGraphicsGetImageFromCurrentImageContext();
					UIGraphicsEndImageContext();
				}
				strongView.onStickerReady = nil;
			}
			if (completion)
				completion(image);
		};
		view.onStickerReady = ready;
		if ([view loadStickerFile:path])
			ready();
	};
}
@end

@implementation TGLottieView

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self){
		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
		self.layer.contentsGravity = kCAGravityResizeAspect;
		[[NSNotificationCenter defaultCenter] addObserver:self
				selector:@selector(appActivityChanged)
					name:TGAppActivityChangedNotification object:nil];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self
			name:TGAppActivityChangedNotification object:nil];
	[_webMPlayer stop];
	_webMPlayer = nil;
	[_timer invalidate];
}

- (void)startTimer {
	if (self.timer || !self.loaded || TGAppInBackground()) return;
	double fps = self.model.isWebM ? self.model.frameRate : 20.0;
	if (fps < 10.0) fps = 15.0;
	if (fps > 30.0) fps = 30.0;

	self.timer = [NSTimer timerWithTimeInterval:1.0 / fps
										 target:self
									   selector:@selector(tick)
									   userInfo:nil
										repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

/// The window stays when the app leaves the screen, so a loop kept a 30 fps
/// timer and a VP9 decode running behind the Home screen with Background
/// Connection on. It holds its frame and picks up where it was.
- (void)appActivityChanged {
	[self syncPlaybackWithScreen];
}

- (void)didMoveToWindow {
	[super didMoveToWindow];
	[self syncPlaybackWithScreen];
}

- (void)syncPlaybackWithScreen {
	if (self.window && !TGAppInBackground()) {
		if (self.isPlaying && self.webMPlayer) {
			[self.webMPlayer play];
		} else if (self.isPlaying && self.loaded && self.model.isWebM) {
			[self ensureWebMPlayer];
			[self.webMPlayer play];
		} else if (self.isPlaying && self.loaded && !self.timer) {
			[self startTimer];
		}
	} else {
		if (self.webMPlayer) {
			[self.webMPlayer pause];
		}
		[self.timer invalidate];
		self.timer = nil;
	}
}

- (BOOL)loadTGSFile:(NSString *)path {
	return [self loadStickerFile:path];
}

// File-scope, because the background first-frame decode of a .webm fills the
// same cache and the same decoding-set that load time consults.
static NSCache *TGLottieStickerCache(void) {
	static NSCache *cache = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		cache = [[NSCache alloc] init];
		cache.countLimit = 32;
		// Frames count their bytes as cost: without a ceiling the cache paid
		// 15 MB for one long .tgs loop, more than the whole 32-bit budget.
		cache.totalCostLimit = TGStickerBudgetForMemory(
				[TGCapabilities memoryMB]).cacheTotalBytes;
	});
	return cache;
}

/// Views that asked for a file while it was being built, by path. Each gets
/// the file the moment the build lands, not only the view that started it:
/// a grid that rebuilt its tiles mid-build left every new tile blank.
static NSMapTable *TGLottieWaiters(void) {
	static NSMapTable *table = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{ table = [NSMapTable strongToStrongObjectsMapTable]; });
	return table;
}

static NSMutableSet *TGLottieBuilding(void) {
	static NSMutableSet *set = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{ set = [NSMutableSet set]; });
	return set;
}

/// Held while a scroll is in flight on a single-core device. Only the first
/// build of a sticker is gated: a cached model still paints at once, because
/// it costs one layer contents assignment and no CPU.
static BOOL sBuildsDeferred = NO;

+ (void)setBuildsDeferred:(BOOL)deferred {
	sBuildsDeferred = deferred;
}

/// One sticker reuse must cost nothing over a background raster pass: on the
/// iPod touch 4 every cell that showed the .webm dev sticker re-opened the
/// demuxer and re-decoded the VP9 keyframe, 33-100 ms per row visible as
/// stepping while the chat scrolled (device log 2026-10-31).
- (BOOL)loadStickerFile:(NSString *)path {
	double start = TGPerfNow();
	BOOL ok = [self loadStickerFileInner:path];
	const char *kind = self.model ? [self.model kind] : "?";
	TGPerfReport("sticker load", kind, start, 16.0);
	return ok;
}

/// The parse and the first raster of a sticker cost tens of ms against the
/// scroll on this hardware, so none of it runs on the main thread. The model
/// lands in the cache when it is ready; a load call before then answers NO.
- (void)buildStickerModelForFile:(NSString *)path {
	NSCache *cache = TGLottieStickerCache();
	NSMutableSet *building = TGLottieBuilding();
	NSString *key = TGLottieKey(path, self.bounds.size);
	if ([building containsObject:key])
		return;
	[building addObject:key];
	double buildStart = TGPerfNow();

	BOOL isWebM = [path.pathExtension.lowercaseString isEqualToString:@"webm"];
	// The raster target belongs to this view; the budgeted sides keep a long
	// loop inside the memory the device has.
	CGSize viewSize = self.bounds.size;
	if (viewSize.width <= 0) viewSize = CGSizeMake(130, 130);
	TGStickerBudget budget = TGStickerBudgetForMemory([TGCapabilities memoryMB]);
	CGFloat scale = [UIScreen mainScreen].scale;
	CGSize targetPxSize = CGSizeMake(
			MIN((CGFloat)budget.pixelSideCap, viewSize.width * scale),
			MIN((CGFloat)budget.pixelSideCap, viewSize.height * scale));

	__weak typeof(self) weakSelf = self;
	dispatch_async(TGLottieRasterQueue(NO), ^{
		// Named for the bench's per-thread CPU line; a pool thread keeps
		// the name after, so it reads "last ran a sticker build".
		pthread_setname_np("tg.sticker-build");
		TGLottieModel *model = [[TGLottieModel alloc] init];
		model.path = path;
		model.isWebM = isWebM;
		BOOL ok = NO;

		if (isWebM) {
			model.frameRate = 30.0;
			model.canvas = CGSizeMake(256, 256);
			UIImage *firstFrame = [TGWebMDecoder firstFrameFromFile:path];
			model.firstFrame = firstFrame;
			ok = (firstFrame != nil);
		} else {
			NSData *gz = [NSData dataWithContentsOfFile:path];
			NSData *json = TGGunzip(gz);
			// tlottie first, as the official client draws: it takes every
			// feature the stickers use and never builds the JSON into
			// dictionaries. Frame 0 comes from the same queue: the sticker's
			// very first appearance on the A4 was a synchronous raster inside
			// the push burst.
			static dispatch_once_t crashLogOnce;
			dispatch_once(&crashLogOnce, ^{
				NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
				TGTLottieUseCrashLog([caches stringByAppendingPathComponent:@"tlottie"]);
			});
			TGTLottie *tlottie = TGTLottieCreate(json, path.lastPathComponent);
			CGImageRef tlottieFirst = tlottie ? TGTLottieRender(tlottie, 0, targetPxSize) : NULL;
			if (tlottieFirst) {
				model.tlottie = tlottie;
				model.inPoint = 0;
				model.outPoint = TGTLottieFrameCount(tlottie);
				model.frameRate = TGTLottieFrameRate(tlottie) ?: 60.0;
				model.firstFrame = [UIImage imageWithCGImage:tlottieFirst];
				CGImageRelease(tlottieFirst);
				ok = YES;
			} else {
				TGTLottieFree(tlottie);
				if (json.length)
					NSLog(@"TGLottie: tlottie refused %@, trying TGLottieRender", path.lastPathComponent);
			}
			NSError *err = nil;
			NSDictionary *anim = nil;
			if (!ok && json.length)
				anim = TGJsonParse((const char *)json.bytes, json.length, &err);
			if (!ok && [anim isKindOfClass:NSDictionary.class]) {
				model.inPoint = [anim[@"ip"] doubleValue];
				model.outPoint = [anim[@"op"] doubleValue];
				model.frameRate = [anim[@"fr"] doubleValue] ?: 60.0;
				model.canvas = CGSizeMake([anim[@"w"] doubleValue], [anim[@"h"] doubleValue]);
				model.scene = TGLottieSceneCreate(anim);
				ok = model.scene != NULL;
				// Drawn without what it needs, the file is a wrong picture
				// rather than none; the still is the right one.
				NSString *missing = ok ? TGLottieUnsupportedFeature(anim) : nil;
				if (missing) {
					model.blank = YES;
					NSLog(@"TGLottie: %@ needs a %@, keeping the still",
							path.lastPathComponent, missing);
				}
				if (ok && !model.blank) {
					CGImageRef f0 = [model newFrame:model.inPoint size:targetPxSize];
					if (f0) {
						model.firstFrame = [UIImage imageWithCGImage:f0];
						CGImageRelease(f0);
					}
				}
			}
		}

		NSString *ext = path.pathExtension.lowercaseString;
		dispatch_async(dispatch_get_main_queue(), ^{
			[building removeObject:key];
			const char *kind = [model kind];
			TGPerfReport("sticker build", kind, buildStart, 50.0);
			if (!ok) {
				NSLog(@"TGLottie: cannot parse %@ (%s)",
						path.lastPathComponent, kind);
				return;
			}
			size_t cost = 0;
			if (model.firstFrame)
				cost = TGStickerFrameBytes(
						(size_t)(model.firstFrame.size.width * model.firstFrame.scale),
						(size_t)(model.firstFrame.size.height * model.firstFrame.scale), 1);
			[cache setObject:model forKey:key cost:cost];
			// Every view still waiting for this file loads it now from the
			// cache and hears it is ready; one reused for another file since
			// has a different waitingPath and is skipped.
			NSHashTable *waiters = [TGLottieWaiters() objectForKey:key];
			[TGLottieWaiters() removeObjectForKey:key];
			for (TGLottieView *view in waiters.allObjects){
				if (![view.waitingPath isEqualToString:path])
					continue;
				view.waitingPath = nil;
				[view loadStickerFileInner:path];
				if (view.onStickerReady)
					view.onStickerReady();
			}
			(void)weakSelf;
		});
	});
}

- (BOOL)loadStickerFileInner:(NSString *)path {
	if (!path.length) return NO;
	if ([self.loadedPath isEqualToString:path] && self.loaded && !self.model.blank) {
		TGLottieModel *shown = self.model;
		if (!shown.isWebM && !shown.cachedFrames.count && !shown.isRasterizing && !sBuildsDeferred) {
			// Its loop was held while the table scrolled: the reload after
			// the scroll settles is the time to raster it. The rest of the
			// load is idempotent; only the held last frame must survive it.
			BOOL wantsLast = self.wantsLastFrame;
			self.loadedPath = nil;
			BOOL ok = [self loadStickerFileInner:path];
			self.wantsLastFrame = wantsLast;
			return ok;
		}
		if (self.isPlaying) {
			if (self.model.isWebM) {
				[self ensureWebMPlayer];
				if (!TGAppInBackground())
					[self.webMPlayer play];
			} else if (!self.timer) {
				[self startTimer];
			}
		}
		return YES;
	}

	if (self.webMPlayer) {
		[self.webMPlayer stop];
		self.webMPlayer = nil;
	}

	NSCache *cache = TGLottieStickerCache();
	NSString *key = TGLottieKey(path, self.bounds.size);
	TGLottieModel *model = [cache objectForKey:key];

	if (!model){
		// Remember who asked, whether this call starts the build or one is
		// already running for another view.
		self.waitingPath = path;
		NSHashTable *waiters = [TGLottieWaiters() objectForKey:key];
		if (!waiters){
			waiters = [NSHashTable weakObjectsHashTable];
			[TGLottieWaiters() setObject:waiters forKey:key];
		}
		[waiters addObject:self];
	}
	if (!model && ![TGLottieBuilding() containsObject:key]) {
		// First look at this file: the parse and the first raster never run
		// on the main thread, so the scroll is not held by them. Until they
		// answer, this call is NO and the cell shows the emoji it stands for.
		// While the table is scrolling on a single core, hold the build too:
		// the raster would fight the scroll for the one core; the row reload
		// after the scroll settles starts it then.
		if (sBuildsDeferred)
			return NO;
		[self buildStickerModelForFile:path];
		return NO;
	}
	if (!model)
		// Building in the background right now.
		return NO;
	if (model.blank) {
		self.loaded = NO;
		self.loadedPath = nil;
		return NO;
	}

	self.loadedPath = path;
	self.model = model;
	self.wantsLastFrame = NO;
	self.currentFrame = model.inPoint;
	self.currentFrameIndex = 0;
	self.loaded = YES;

	// Target pixel rasterization size - the view's own pixels, clamped by the
	// device's memory budget rather than by however many the display might
	// want: one 256x256 RGBA frame against a 60-frame loop was 15 MB alone.
	TGStickerBudget budget = TGStickerBudgetForMemory([TGCapabilities memoryMB]);
	CGSize viewSize = self.bounds.size;
	if (viewSize.width <= 0) viewSize = CGSizeMake(130, 130);
	CGFloat screenScale = [UIScreen mainScreen].scale;
	CGSize targetPxSize = CGSizeMake(
			MIN((CGFloat)budget.pixelSideCap, viewSize.width * screenScale),
			MIN((CGFloat)budget.pixelSideCap, viewSize.height * screenScale));

	if (model.isWebM) {
		// The demuxer and the codec initialise only when the sticker is told
		// to play (-play), not on every cell the file happened to pass
		// through - including the reuse of a cell that had just shown it.
		if (model.firstFrame)
			self.layer.contents = (__bridge id)model.firstFrame.CGImage;
	} else if (model.cachedFrames.count > 0) {
		// Instantly show frame 0 with hardware layer
		CGImageRef first = (__bridge CGImageRef)model.cachedFrames[0];
		self.layer.contents = (__bridge id)first;
	} else {
		// Rasterize frame 0 synchronously so the user sees the sticker
		// immediately - but only once: it was recomputed on every reuse for
		// as long as the background pass ran, because nothing kept it.
		// Frame 0 comes from the background build; without it the loop
		// below fills the layer, never a raster on this thread.
		if (model.firstFrame)
			self.layer.contents = (__bridge id)model.firstFrame.CGImage;

		// Asynchronously pre-rasterize the animation loop on a background thread.
		// Not while a single core scrolls: each loop is 0.5 s or more of
		// raster, and the stickers coming into view during the first scroll
		// of a chat took ~2 s of the CPU the scroll and backboardd needed.
		// Frame 0 shows meanwhile; the row reload after the scroll settles
		// comes back here.
		if (!model.isRasterizing && !sBuildsDeferred) {
			model.isRasterizing = YES;
			__weak typeof(self) weakSelf = self;
			dispatch_async(TGLottieRasterQueue(YES), ^{
				pthread_setname_np("tg.sticker-loop");
				double targetFps = 18.0;
				double duration = (model.outPoint - model.inPoint) / (model.frameRate ?: 60.0);
				if (duration <= 0.05) duration = 2.0;
				int totalFrames = (int)ceil(duration * targetFps);
				if (totalFrames < 1) totalFrames = 1;
				// The budget, not a guess, name the biggest loop this device
				// may hold: the frame count is what decides the bytes.
				if (totalFrames > budget.frameCap) totalFrames = budget.frameCap;
				// tlottie counts a file that never moves as one frame: one
				// picture, not 36 copies of it.
				if (model.tlottie && model.outPoint - model.inPoint <= 1.0) totalFrames = 1;

				double frameStep = (model.outPoint - model.inPoint) / (double)totalFrames;
				NSMutableArray *rendered = [NSMutableArray arrayWithCapacity:totalFrames];
				double loopStart = TGPerfNow();

				for (int i = 0; i < totalFrames; i++) {
					double f = model.inPoint + i * frameStep;
					CGImageRef img = [model newFrame:f size:targetPxSize];
					if (img) {
						[rendered addObject:CFBridgingRelease(img)];
					}
				}

				TGPerfReport("sticker loop", [model kind], loopStart, 500.0);
				BOOL blank = TGLottieFramesAreBlank(rendered);
				dispatch_async(dispatch_get_main_queue(), ^{
					model.cachedFrames = rendered;
					model.isRasterizing = NO;
					if (blank) {
						// A pin emoji drew nothing in any of its frames and
						// sat in the message as an empty space, looping.
						model.blank = YES;
						NSLog(@"TGLottie: %@ renders blank, keeping the still",
								path.lastPathComponent);
						TGLottieView *me = weakSelf;
						if ([me.loadedPath isEqualToString:path]) {
							[me stop];
							me.loaded = NO;
							me.loadedPath = nil;
							if (me.onStickerReady)
								me.onStickerReady();
						}
						return;
					}
					// The real cost is known only now that the loop is done:
					// re-inserting lets the cache evict what it overpaid for.
					if (rendered.count > 0) {
						CGImageRef f0 = (__bridge CGImageRef)rendered[0];
						size_t cost = TGStickerFrameBytes(CGImageGetWidth(f0),
														  CGImageGetHeight(f0),
														  (int)rendered.count);
						[TGLottieStickerCache() setObject:model forKey:key cost:cost];
					}
					if ([weakSelf.loadedPath isEqualToString:path]) {
						if (rendered.count > 0 && weakSelf.wantsLastFrame && !weakSelf.isPlaying)
							weakSelf.layer.contents = rendered.lastObject;
						else if (rendered.count > 0 && !weakSelf.layer.contents) {
							weakSelf.layer.contents = (__bridge id)(__bridge CGImageRef)rendered[0];
						}
					}
				});
			});
		}
	}

	if (self.isPlaying) {
		if (self.webMPlayer && !TGAppInBackground()) [self.webMPlayer play];
		else if (!self.timer) [self startTimer];
	}

	return self.loaded;
}

- (void)play {
	self.once = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(finishOnce) object:nil];
	[self startPlaying];
}

- (void)showLastFrame {
	if (self.isPlaying)
		return;
	self.wantsLastFrame = YES;
	NSArray *frames = self.model.cachedFrames;
	if (frames.count > 0) {
		self.currentFrameIndex = frames.count - 1;
		self.layer.contents = frames.lastObject;
	}
}

- (void)playOnce {
	self.wantsLastFrame = NO;
	// Already on its one loop: a table reload must not start it over.
	if (self.once && self.isPlaying)
		return;
	self.once = YES;
	self.currentFrameIndex = 0;
	[self startPlaying];
}

/// The stream player loops by itself and reports nothing, so its one loop is
/// timed. ponytail: a clock, not a frame count - ends up to a frame early or
/// late; give the player an end callback if that ever shows.
- (void)armOnceTimer {
	if (!self.once)
		return;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(finishOnce) object:nil];
	NSTimeInterval loop = self.webMPlayer.duration;
	[self performSelector:@selector(finishOnce) withObject:nil
			   afterDelay:loop > 0.2 ? loop : 3.0];
}

- (void)finishOnce {
	if (!self.once)
		return;
	[self stop];
	self.currentFrameIndex = 0;
	NSArray *frames = self.model.cachedFrames;
	if (frames.count > 0 && self.holdsLastFrame) {
		self.currentFrameIndex = frames.count - 1;
		self.layer.contents = frames.lastObject;
	} else if (frames.count > 0)
		self.layer.contents = frames[0];
	else if (self.model.firstFrame)
		self.layer.contents = (__bridge id)self.model.firstFrame.CGImage;
	if (self.onPlayedOnce)
		self.onPlayedOnce();
}

- (void)startPlaying {
	self.isPlaying = YES;
	if (self.loaded && self.model.isWebM && !self.webMPlayer) {
		[self ensureWebMPlayer];
		return;
	}
	if (self.webMPlayer) {
		if (!TGAppInBackground())
			[self.webMPlayer play];
		[self armOnceTimer];
	} else if (self.loaded && !self.model.isWebM && !self.timer) {
		[self startTimer];
	}
}

/// The fopen, nestegg_init, vpx_codec_dec_init and the first VP9 frame cost
/// tens of ms on the A4; a screen of custom emoji did them all on the main
/// thread and froze the chat. The player is built on a background queue and
/// handed back to the view only if it still shows the same file.
- (void)ensureWebMPlayer {
	NSString *path = self.model.path;
	if (self.webMPlayer || !self.model.isWebM ||
			[self.webMPlayerPendingPath isEqualToString:path])
		return;
	self.webMPlayerPendingPath = path;
	__weak typeof(self) weakSelf = self;
	dispatch_async(TGLottiePlayerQueue(), ^{
		TGWebMStreamPlayer *player = [[TGWebMStreamPlayer alloc] initWithPath:path];
		dispatch_async(dispatch_get_main_queue(), ^{
			TGLottieView *me = weakSelf;
			if (!me)
				return;
			if ([me.webMPlayerPendingPath isEqualToString:path])
				me.webMPlayerPendingPath = nil;
			if (!player || ![me.model.path isEqualToString:path] || me.webMPlayer)
				return;
			me.webMPlayer = player;
			player.targetLayer = me.layer;
			if (me.isPlaying && !TGAppInBackground()) {
				[player play];
				[me armOnceTimer];
			}
		});
	});
}

- (void)stop {
	self.isPlaying = NO;
	self.once = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(finishOnce) object:nil];
	if (self.webMPlayer) {
		[self.webMPlayer stop];
	}
	[self.timer invalidate];
	self.timer = nil;
}

- (void)tick {
	if (!self.window || self.hidden || !self.loaded)
		return;

	NSArray *frames = self.model.cachedFrames;
	if (frames.count > 0) {
		self.currentFrameIndex = (self.currentFrameIndex + 1) % frames.count;
		if (self.once && self.currentFrameIndex == 0) {
			[self finishOnce];
			return;
		}
		CGImageRef img = (__bridge CGImageRef)frames[self.currentFrameIndex];
		if (img) {
			self.layer.contents = (__bridge id)img;
		}
		return;
	}

	// Until the background pass delivers the loop, frame 0 stays up. The
	// old fallback re-rendered the vector frame in drawRect: 18 times a
	// second on the main thread - the custom emoji freeze.
}

@end
